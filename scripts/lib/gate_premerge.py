"""Fail-closed premerge validation against current provider and Git state."""
from __future__ import annotations

from pathlib import Path
import subprocess
from typing import Mapping

try:
    from .evidence_collectors import collect_github_state
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, is_hash_ref
    from .gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, review_rules, source_artifact_rule, workflow_binding_rule
    from .gate_receipts import build_receipt
except ImportError:  # pragma: no cover
    from evidence_collectors import collect_github_state
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, is_hash_ref
    from gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, review_rules, source_artifact_rule, workflow_binding_rule
    from gate_receipts import build_receipt


PREMERGE_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "review_result", "authorization_event", "github_state"}
PASSING_CHECK_CONCLUSIONS = frozenset({"success", "neutral", "skipped"})


def _provider_rules(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope, current_head: str, current_branch: str, repo_root: Path) -> list[RuleResult]:
    payload = grouped.get("github_state", [None])[0]
    if not isinstance(payload, Mapping):
        return [RuleResult("provider_state", False, "provider state is missing")]
    if payload.get("provider_available") is not True:
        raise EvidenceError("provider_state_unavailable", "GitHub provider state is unavailable", "provider_state")
    observation_id = payload.get("observation_id")
    observation_hash = payload.get("observation_hash")
    observation_ok = isinstance(observation_id, str) and observation_id == "github_pr_state" and is_hash_ref(observation_hash)
    if observation_ok:
        fresh = collect_github_state(repo_root, observation_id)
        if fresh.payload.get("provider_available") is not True:
            raise EvidenceError("provider_state_unavailable", "GitHub provider state is unavailable", "provider_state")
        observation_ok = fresh.payload.get("observation_hash") == observation_hash

    checks = payload.get("checks")
    checks_ok = isinstance(checks, list) and bool(checks) and all(
        isinstance(check, Mapping)
        and isinstance(check.get("name"), str)
        and bool(check.get("name"))
        and check.get("conclusion") in PASSING_CHECK_CONCLUSIONS
        for check in checks
    )
    remote_identity = envelope.repository.get("remote_identity")
    repository_ok = isinstance(payload.get("repository"), str) and bool(payload.get("repository")) and isinstance(payload.get("repository_id"), str) and bool(payload.get("repository_id")) and (not remote_identity or payload.get("repository") == remote_identity)
    pr_ok = isinstance(payload.get("pr_id"), int) and not isinstance(payload.get("pr_id"), bool) and payload.get("pr_id") > 0 and repository_ok
    base_ref = payload.get("base_ref")
    base_observation = subprocess.run(["git", "rev-parse", str(base_ref)], cwd=repo_root, stdin=subprocess.DEVNULL, text=True, capture_output=True, check=False, timeout=10) if isinstance(base_ref, str) and base_ref else None
    base_ok = payload.get("base_ref") == envelope.target["branch"] and isinstance(payload.get("base_sha"), str) and bool(payload.get("base_sha")) and base_observation is not None and base_observation.returncode == 0 and payload.get("base_sha") == base_observation.stdout.strip()
    head_ok = isinstance(payload.get("head_ref"), str) and bool(payload.get("head_ref")) and payload.get("head_ref") == current_branch and payload.get("head_ref") != payload.get("base_ref") and payload.get("head_sha") == current_head and payload.get("source_branch") == payload.get("head_ref") and payload.get("source_sha") == payload.get("head_sha")
    mergeability_ok = payload.get("mergeable") is True
    provider_reviews = payload.get("reviews")
    blocking_states = {"CHANGES_REQUESTED", "REQUEST_CHANGES", "REQUESTED", "REVIEW_REQUIRED", "BLOCKED"}
    reviews_ok = payload.get("review_decision") not in blocking_states and isinstance(provider_reviews, list) and not any(isinstance(review, Mapping) and (review.get("blocking") is True or str(review.get("state", "")).upper() in blocking_states) for review in provider_reviews)
    return [
        RuleResult("provider_state", True, "provider state is available"),
        RuleResult("provider_observation", observation_ok, "provider observation is trusted and current" if observation_ok else "provider observation is missing, malformed, or stale"),
        RuleResult("pr_identity", pr_ok, "PR identity is authenticated" if pr_ok else "PR identity is incomplete"),
        RuleResult("required_checks", checks_ok, "required checks are passing" if checks_ok else "required checks are not all passing"),
        RuleResult("base_identity", base_ok, "base ref matches target" if base_ok else "base ref does not match target"),
        RuleResult("head_identity", head_ok, "head ref and SHA match current checkout" if head_ok else "head ref or SHA is stale"),
        RuleResult("mergeability", mergeability_ok, "provider reports mergeable" if mergeability_ok else "provider reports a non-mergeable change"),
        RuleResult("provider_reviews", reviews_ok, "provider reviews contain no blocker" if reviews_ok else "provider reviews contain a blocker or are unavailable"),
    ]


def validate_premerge(envelope: EvidenceEnvelope, repo_root: Path):
    if envelope.gate != "premerge":
        raise EvidenceError("schema_invalid", "envelope gate must be premerge")
    root = Path(repo_root).resolve()
    grouped = require_evidence(envelope, PREMERGE_REQUIRED_KINDS)
    current = current_git_state(root)
    rules = identity_rules(envelope, root, check_target_branch=False)
    rules.extend([
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, root),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *review_rules(grouped),
        *_provider_rules(grouped, envelope, str(current["head"]), str(current["branch"]), root),
    ])
    require_all_rules(rules)
    provider = grouped["github_state"][0]
    authorization = grouped["authorization_event"][0]
    authorization_event = authorization.get("event") if isinstance(authorization, Mapping) else None
    observations = {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"], "provider_observation_hash": provider.get("observation_hash") if isinstance(provider, Mapping) else None, "source_branch": provider.get("source_branch") if isinstance(provider, Mapping) else None, "source_head": provider.get("source_sha") if isinstance(provider, Mapping) else None, "base_sha": provider.get("base_sha") if isinstance(provider, Mapping) else None, "strategy": authorization_event.get("strategy") if isinstance(authorization_event, Mapping) else None, "source_plan_hash": envelope.source["plan_hash"]}
    return build_receipt(envelope, "premerge-validator@1", observations, rules)
