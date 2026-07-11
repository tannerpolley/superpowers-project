"""Fail-closed premerge validation against current provider and Git state."""
from __future__ import annotations

from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from .gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, review_rules, source_artifact_rule, workflow_binding_rule
    from .gate_receipts import build_receipt
except ImportError:  # pragma: no cover
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, review_rules, source_artifact_rule, workflow_binding_rule
    from gate_receipts import build_receipt


PREMERGE_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "review_result", "authorization_event", "github_state"}
PASSING_CHECK_CONCLUSIONS = frozenset({"success", "neutral", "skipped"})


def _provider_rules(grouped: Mapping[str, list[object]], envelope: EvidenceEnvelope, current_head: str) -> list[RuleResult]:
    payload = grouped.get("github_state", [None])[0]
    if not isinstance(payload, Mapping):
        return [RuleResult("provider_state", False, "provider state is missing")]
    if payload.get("provider_available") is not True:
        raise EvidenceError("provider_state_unavailable", "GitHub provider state is unavailable", "provider_state")

    checks = payload.get("checks")
    checks_ok = isinstance(checks, list) and bool(checks) and all(
        isinstance(check, Mapping)
        and isinstance(check.get("name"), str)
        and bool(check.get("name"))
        and check.get("conclusion") in PASSING_CHECK_CONCLUSIONS
        for check in checks
    )
    repository_ok = isinstance(payload.get("repository"), str) and bool(payload.get("repository"))
    pr_ok = isinstance(payload.get("pr_id"), int) and not isinstance(payload.get("pr_id"), bool) and payload.get("pr_id") > 0 and repository_ok
    base_ok = payload.get("base_ref") == envelope.target["branch"]
    head_ok = isinstance(payload.get("head_ref"), str) and bool(payload.get("head_ref")) and payload.get("head_sha") == current_head
    strategy_ok = payload.get("strategy") in {"ff-only", "squash", "merge"}
    return [
        RuleResult("provider_state", True, "provider state is available"),
        RuleResult("pr_identity", pr_ok, "PR identity is authenticated" if pr_ok else "PR identity is incomplete"),
        RuleResult("required_checks", checks_ok, "required checks are passing" if checks_ok else "required checks are not all passing"),
        RuleResult("base_identity", base_ok, "base ref matches target" if base_ok else "base ref does not match target"),
        RuleResult("head_identity", head_ok, "head ref and SHA match current checkout" if head_ok else "head ref or SHA is stale"),
        RuleResult("merge_strategy", strategy_ok, "merge strategy is supported" if strategy_ok else "merge strategy is unsupported"),
    ]


def validate_premerge(envelope: EvidenceEnvelope, repo_root: Path):
    if envelope.gate != "premerge":
        raise EvidenceError("schema_invalid", "envelope gate must be premerge")
    root = Path(repo_root).resolve()
    grouped = require_evidence(envelope, PREMERGE_REQUIRED_KINDS)
    current = current_git_state(root)
    rules = identity_rules(envelope, root)
    rules.extend([
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, root),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *review_rules(grouped),
        *_provider_rules(grouped, envelope, str(current["head"])),
    ])
    require_all_rules(rules)
    return build_receipt(envelope, "premerge-validator@1", {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"]}, rules)
