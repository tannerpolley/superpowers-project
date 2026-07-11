from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_premerge import validate_premerge


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
    git(root, "commit", "-qm", "fixture")
    return root


def envelope(root: Path, *, conclusion: str = "success", available: bool = True) -> dict[str, object]:
    head = git(root, "rev-parse", "HEAD")
    return build_evidence_envelope(CollectionRequest(
        gate="premerge",
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref({"authorized": True})},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": {"authorized": True},
            "github": {
                "provider_available": available,
                "pr_id": 113,
                "repository": "fixture/repo",
                "base_ref": "main",
                "head_ref": "main",
                "head_sha": head,
                "checks": [{"name": "ci", "conclusion": conclusion}],
                "strategy": "ff-only",
            },
        },
    ))


class PremergeGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))

    def test_public_premerge_launcher_fails_without_evidence(self):
        root = Path(__file__).parents[1]
        process = subprocess.run(["bash", str(root / "skills/merge-changes/scripts/premerge.sh")], cwd=root, text=True, capture_output=True)
        self.assertNotEqual(0, process.returncode)
        self.assertEqual("evidence_missing", json.loads(process.stdout)["error"]["code"])

    def test_premerge_rejects_nonpassing_or_unavailable_provider(self):
        for conclusion in ("queued", "pending", "in_progress", "failure", "cancelled", "timed_out"):
            with self.subTest(conclusion=conclusion):
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    validate_premerge(parse_envelope(envelope(self.repo, conclusion=conclusion), self.repo), self.repo)
        with self.assertRaisesRegex(EvidenceError, "provider"):
            validate_premerge(parse_envelope(envelope(self.repo, available=False), self.repo), self.repo)

    def test_premerge_rejects_changed_head_and_accepts_current_proof(self):
        collected = envelope(self.repo)
        receipt = validate_premerge(parse_envelope(collected, self.repo), self.repo)
        self.assertEqual("passed", receipt.disposition)
        (self.repo / "changed.txt").write_text("changed\n", encoding="utf-8")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "changed")
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_premerge(parse_envelope(collected, self.repo), self.repo)


if __name__ == "__main__":
    unittest.main()
