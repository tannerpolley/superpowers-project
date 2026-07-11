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


def envelope(root: Path, gate: str, *, prior_event_hash: str | None = None) -> dict[str, object]:
    return build_evidence_envelope(CollectionRequest(
        gate=gate,
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref({"authorized": True})},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": {"authorized": True},
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


def remove_repo(root: Path) -> None:
    shutil.rmtree(root, ignore_errors=True)
