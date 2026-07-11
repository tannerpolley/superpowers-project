from __future__ import annotations

import contextlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.lib.command_support import Context
from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, RuleResult, hash_ref, parse_envelope
from scripts.lib.gate_merge_decision import validate_merge_decision
from scripts.lib.gate_premerge import validate_premerge
from scripts.lib.gate_receipts import build_receipt
sys.path.insert(0, str(Path(__file__).parents[1] / "scripts" / "lib"))
from scripts.lib.superpowers_project_cli import command_apply_local_branch_closeout


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def make_repo() -> Path:
    root = Path(tempfile.mkdtemp())
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "fixture@example.com")
    git(root, "config", "user.name", "Fixture")
    plan = root / "docs" / "superpowers" / "plans" / "plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("# Plan\n", encoding="utf-8")
    git(root, "add", ".")
    git(root, "commit", "-qm", "base")
    return root


def envelope(root: Path, gate: str, prior: str | None = None) -> dict[str, object]:
    head = git(root, "rev-parse", "HEAD")
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
            "github": {"provider_available": True, "pr_id": 113, "repository": "fixture/repo", "base_ref": "main", "head_ref": "main", "head_sha": head, "checks": [{"name": "ci", "conclusion": "success"}], "strategy": "ff-only"},
        },
        prior_event_hash=prior,
    ))


class MergeDecisionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))

    def test_merge_decision_requires_current_premerge_receipt(self):
        decision = parse_envelope(envelope(self.repo, "merge_decision"), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_merge_decision(decision, self.repo, None)

    def test_public_merge_decision_launcher_fails_without_evidence(self):
        root = Path(__file__).parents[1]
        process = subprocess.run(["bash", str(root / "skills/merge-changes/scripts/validate-merge-decision.sh")], cwd=root, text=True, capture_output=True)
        self.assertNotEqual(0, process.returncode)
        self.assertEqual("evidence_missing", json.loads(process.stdout)["error"]["code"])

    def test_merge_decision_accepts_matching_premerge_receipt(self):
        premerge = validate_premerge(parse_envelope(envelope(self.repo, "premerge"), self.repo), self.repo)
        decision = parse_envelope(envelope(self.repo, "merge_decision", premerge.receipt_hash), self.repo)
        receipt = validate_merge_decision(decision, self.repo, premerge)
        self.assertEqual("merge_decision", receipt.gate)
        self.assertEqual("passed", receipt.disposition)

    def test_local_merge_rejects_bare_success_object(self):
        ctx = Context(Path(__file__).parents[1] / "skills/merge-changes/scripts/apply-local-branch-closeout.sh", self.repo, "skills/merge-changes/scripts/apply-local-branch-closeout.sh", "apply-local-branch-closeout.sh", [], Path(__file__).parents[1], self.repo)
        with self.assertRaisesRegex(Exception, "legacy_evidence_unsupported|receipt"):
            command_apply_local_branch_closeout(ctx, {"RepoRoot": str(self.repo), "SetupLedgerJson": json.dumps({"merge_mode": "local-branch", "branch": "codex/fixture", "source_plan": "docs/superpowers/plans/plan.md"}), "PremergeResultJson": json.dumps({"ok": True}), "MergeDecisionJson": json.dumps({"selected_action": "merge"}), "DryRun": True})


if __name__ == "__main__":
    unittest.main()
