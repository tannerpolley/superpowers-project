from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import hash_ref, parse_envelope
from scripts.lib.gate_closeout import validate_closeout
from scripts.lib.gate_pr_ready import validate_pr_ready


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


def run_local_lifecycle(root: Path) -> list[dict[str, object]]:
    pr_envelope = parse_envelope(envelope(root, "pr_ready"), root)
    pr_receipt = validate_pr_ready(pr_envelope, root)
    closeout_envelope = parse_envelope(envelope(root, "closeout", prior_event_hash=pr_receipt.receipt_hash), root)
    closeout_receipt = validate_closeout(closeout_envelope, root, pr_receipt)
    return [
        {"gate": pr_receipt.gate, "envelope_hash": pr_receipt.envelope_hash, "receipt_hash": pr_receipt.receipt_hash, "prior_receipt_hash": None, "observations": dict(pr_receipt.observations)},
        {"gate": closeout_receipt.gate, "envelope_hash": closeout_receipt.envelope_hash, "receipt_hash": closeout_receipt.receipt_hash, "prior_receipt_hash": pr_receipt.receipt_hash, "observations": dict(closeout_receipt.observations)},
    ]


def run_provider_lifecycle() -> tuple[Path, list[dict[str, object]]]:
    from tests.test_gate_merge_decision import MergeDecisionTests, envelope as provider_envelope, make_repo as make_provider_repo

    root = make_provider_repo()
    helper = MergeDecisionTests()
    helper.repo = root
    authorization = {"authorized": True, "merge_strategy": "ff-only"}
    pr_envelope = parse_envelope(envelope(root, "pr_ready", authorization=authorization), root)
    pr_receipt = validate_pr_ready(pr_envelope, root)
    premerge_data = provider_envelope(root, "premerge", pr_receipt.receipt_hash)
    premerge_receipt = helper.validate_premerge_fixture(premerge_data, pr_receipt)
    merge_receipt = helper.validate_merge_fixture(provider_envelope(root, "merge_decision", premerge_receipt.receipt_hash), premerge_receipt)
    closeout_target = dict(merge_receipt.bindings["target"])
    closeout_target["branch"] = git(root, "branch", "--show-current")
    closeout_envelope = parse_envelope(envelope(root, "closeout", prior_event_hash=merge_receipt.receipt_hash, authorization=authorization, target=closeout_target), root)
    closeout_receipt = validate_closeout(closeout_envelope, root, merge_receipt)
    receipts = (pr_receipt, premerge_receipt, merge_receipt, closeout_receipt)
    prior = (None, pr_receipt.receipt_hash, premerge_receipt.receipt_hash, merge_receipt.receipt_hash)
    return root, [
        {"gate": receipt.gate, "envelope_hash": receipt.envelope_hash, "receipt_hash": receipt.receipt_hash, "prior_receipt_hash": prior_hash, "observations": dict(receipt.observations)}
        for receipt, prior_hash in zip(receipts, prior)
    ]


def remove_repo(root: Path) -> None:
    shutil.rmtree(root, ignore_errors=True)
