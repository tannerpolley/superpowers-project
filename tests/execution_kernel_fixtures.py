from __future__ import annotations

import shutil
import subprocess
import tempfile
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

import scripts.lib.evidence_collectors as evidence_collectors
import scripts.lib.gate_premerge as gate_premerge
from scripts.lib.evidence_collectors import CollectionRequest, CollectorResult, build_evidence_envelope
from scripts.lib.evidence_schema import RuleResult, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_closeout import validate_closeout
from scripts.lib.gate_merge_decision import validate_merge_decision
from scripts.lib.gate_premerge import validate_premerge
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.gate_receipts import EXPECTED_VALIDATORS, REQUIRED_RECEIPT_RULES, build_receipt


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def make_repo() -> Path:
    root = Path(tempfile.mkdtemp())
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "fixture@example.com")
    git(root, "config", "user.name", "Fixture")
    plan = root / "docs/superpowers/plans/plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("# Plan\n", encoding="utf-8")
    git(root, "add", ".")
    git(root, "commit", "-qm", "fixture")
    return root


def make_provider_repo() -> Path:
    root = make_repo()
    git(root, "switch", "-qc", "codex/fixture")
    (root / "feature.txt").write_text("feature\n", encoding="utf-8")
    git(root, "add", "feature.txt")
    git(root, "commit", "-qm", "feature")
    return root


def github_observation(payload: dict[str, object]) -> CollectorResult:
    observed = {"observation_id": "github_pr_state", **payload}
    observed["observation_hash"] = hash_ref({"mock": observed})
    return CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", observed)


def envelope(root: Path, gate: str, *, prior_event_hash: str | None = None, authorization: dict[str, object] | None = None, target: dict[str, object] | None = None) -> dict[str, object]:
    authorization = authorization or {"authorized": True}
    return build_evidence_envelope(CollectionRequest(
        gate=gate,
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref(authorization)},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target=target or {"task_id": None, "workspace_id": "local", "branch": git(root, "branch", "--show-current"), "isolation_required": False},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": authorization,
            "integration": {"integrated": True, "head": git(root, "rev-parse", "HEAD")},
            "cleanup": {"status_exit_code": 0, "dirty": False, "owner": "fixture", "task_owned_paths": []},
        },
        prior_event_hash=prior_event_hash,
    ))


def provider_envelope(
    root: Path,
    gate: str,
    prior_event_hash: str | None = None,
    *,
    conclusion: str = "success",
    available: bool = True,
    target_strategy: str = "ff-only",
    authorization_strategy: str = "ff-only",
) -> dict[str, object]:
    head = git(root, "rev-parse", "HEAD")
    base = git(root, "rev-parse", "main")
    authorization = {"authorized": True, "merge_strategy": authorization_strategy}
    request = CollectionRequest(
        gate=gate,
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref(authorization)},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False, "merge_strategy": target_strategy},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": authorization,
            "github_observation_id": "github_pr_state",
            "github_fixture_payload": {
                "provider_available": available,
                "pr_id": 113,
                "repository": "fixture/repo",
                "repository_id": "fixture/repository-id",
                "base_ref": "main",
                "base_sha": base,
                "head_ref": "codex/fixture",
                "head_sha": head,
                "source_branch": "codex/fixture",
                "source_sha": head,
                "mergeable": True,
                "reviews": [],
                "checks": [{"name": "ci", "conclusion": conclusion}],
            },
        },
        prior_event_hash=prior_event_hash,
    )
    with patch.object(evidence_collectors, "collect_github_state", return_value=github_observation(request.provider_inputs["github_fixture_payload"])):
        return build_evidence_envelope(request)


def validate_provider_premerge(root: Path, data: dict[str, object], prior=None, fresh_provider=None):
    if prior is None:
        authorization = next(item for item in data["evidence"] if item["kind"] == "authorization_event")["payload"]["event"]
        prior = validate_pr_ready(parse_envelope(envelope(root, "pr_ready", authorization=authorization), root), root)
        data["prior_event_hash"] = prior.receipt_hash
        data["envelope_hash"] = build_envelope_hash(data)
    provider = fresh_provider or next(item for item in data["evidence"] if item["kind"] == "github_state")["payload"]
    fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider)
    with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
        return validate_premerge(parse_envelope(data, root), root, prior)


def validate_provider_merge(root: Path, data: dict[str, object], prior):
    provider = next(item for item in data["evidence"] if item["kind"] == "github_state")["payload"]
    fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider)
    with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
        return validate_merge_decision(parse_envelope(data, root), root, prior)


def synthetic_merge_prior(root: Path):
    merged = replace(parse_envelope(envelope(root, "pr_ready"), root), gate="merge_decision")
    rules = [RuleResult(rule_id, True, "observed") for rule_id in sorted(REQUIRED_RECEIPT_RULES["merge_decision"])]
    observations = {"head": git(root, "rev-parse", "HEAD"), "branch": "main"}
    return build_receipt(merged, EXPECTED_VALIDATORS["merge_decision"], observations, rules)


def run_provider_lifecycle() -> tuple[Path, list[dict[str, object]]]:
    root = make_provider_repo()
    authorization = {"authorized": True, "merge_strategy": "ff-only"}
    pr_envelope = parse_envelope(envelope(root, "pr_ready", authorization=authorization), root)
    pr_receipt = validate_pr_ready(pr_envelope, root)
    premerge_data = provider_envelope(root, "premerge", pr_receipt.receipt_hash)
    premerge_receipt = validate_provider_premerge(root, premerge_data, pr_receipt)
    merge_data = provider_envelope(root, "merge_decision", premerge_receipt.receipt_hash)
    merge_receipt = validate_provider_merge(root, merge_data, premerge_receipt)
    closeout_target = dict(merge_receipt.bindings["target"])
    closeout_target["branch"] = git(root, "branch", "--show-current")
    closeout_data = envelope(
        root,
        "closeout",
        prior_event_hash=merge_receipt.receipt_hash,
        authorization=authorization,
        target=closeout_target,
    )
    closeout_envelope = parse_envelope(closeout_data, root)
    closeout_receipt = validate_closeout(closeout_envelope, root, merge_receipt)
    receipts = (pr_receipt, premerge_receipt, merge_receipt, closeout_receipt)
    prior = (None, pr_receipt.receipt_hash, premerge_receipt.receipt_hash, merge_receipt.receipt_hash)
    return root, [
        {"gate": receipt.gate, "envelope_hash": receipt.envelope_hash, "receipt_hash": receipt.receipt_hash, "prior_receipt_hash": prior_hash, "observations": dict(receipt.observations)}
        for receipt, prior_hash in zip(receipts, prior)
    ]


def remove_repo(root: Path) -> None:
    shutil.rmtree(root, ignore_errors=True)
