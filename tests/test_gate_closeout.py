from __future__ import annotations

import shutil
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_closeout import validate_closeout
from scripts.lib.gate_pr_ready import validate_pr_ready


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def repo() -> Path:
    root = Path(tempfile.mkdtemp())
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "fixture@example.com")
    git(root, "config", "user.name", "Fixture")
    plan = root / "docs" / "superpowers" / "plans" / "plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("# Plan\n", encoding="utf-8")
    git(root, "add", ".")
    git(root, "commit", "-qm", "fixture")
    return root


def request(root: Path, gate: str, *, prior: str | None = None) -> dict[str, object]:
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
        prior_event_hash=prior,
    ))


class CloseoutGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = repo()
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))

    def test_closeout_requires_prior_pr_ready_receipt(self):
        envelope = parse_envelope(request(self.repo, "closeout"), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_closeout(envelope, self.repo, None)

    def test_public_closeout_launcher_fails_without_evidence(self):
        root = Path(__file__).parents[1]
        process = subprocess.run(["bash", str(root / "skills/merge-changes/scripts/closeout.sh")], cwd=root, text=True, capture_output=True)
        self.assertNotEqual(0, process.returncode)
        self.assertEqual("evidence_missing", json.loads(process.stdout)["error"]["code"])

    def test_closeout_accepts_current_prior_receipt_and_emits_rules(self):
        pr_request = request(self.repo, "pr_ready")
        pr_receipt = validate_pr_ready(parse_envelope(pr_request, self.repo), self.repo)
        closeout = parse_envelope(request(self.repo, "closeout", prior=pr_receipt.receipt_hash), self.repo)
        receipt = validate_closeout(closeout, self.repo, pr_receipt)
        self.assertEqual("closeout", receipt.gate)
        self.assertEqual("passed", receipt.disposition)
        self.assertTrue({rule.rule_id for rule in receipt.rules} >= {"integration_proof", "completion_state", "workspace_disposition", "cleanup_state"})


if __name__ == "__main__":
    unittest.main()
