from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_pr_ready import validate_pr_ready


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def fixture_repo() -> Path:
    repo = Path(tempfile.mkdtemp())
    git(repo, "init", "-q", "-b", "main")
    git(repo, "config", "user.email", "fixture@example.com")
    git(repo, "config", "user.name", "Fixture")
    plan = repo / "docs" / "superpowers" / "plans" / "plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("# Plan\n", encoding="utf-8")
    git(repo, "add", ".")
    git(repo, "commit", "-qm", "fixture")
    return repo


def valid_pr_ready_envelope(repo: Path) -> dict[str, object]:
    request = CollectionRequest(
        gate="pr_ready",
        repository_root=repo,
        workflow={
            "run_id": "run-1",
            "candidate_id": "candidate-1",
            "mode": "manual",
            "authorization_hash": hash_ref({"authorized": True}),
        },
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": {"authorized": True},
            "cleanup": {"status_exit_code": 0, "dirty": False, "owner": "fixture", "task_owned_paths": []},
        },
    )
    return build_evidence_envelope(request)


class PrReadyGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = fixture_repo()
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))

    def test_public_pr_ready_launcher_fails_without_evidence(self):
        result = subprocess.run(
            ["bash", str(Path(__file__).parents[1] / "skills/resolve-issue/scripts/validate-pr-ready.sh")],
            cwd=Path(__file__).parents[1],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("evidence_missing", json.loads(result.stdout)["error"]["code"])

    def test_pr_ready_rejects_forged_success_and_stale_source(self):
        envelope = valid_pr_ready_envelope(self.repo)
        envelope["evidence"].append({
            "kind": "command_result",
            "collector": "command-result@1",
            "observed_at": "2026-07-10T12:00:00Z",
            "payload_hash": hash_ref({"ok": True}),
            "payload": {"ok": True},
        })
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "collector_untrusted"):
            validate_pr_ready(parse_envelope(envelope, self.repo), self.repo)
        envelope = valid_pr_ready_envelope(self.repo)
        (self.repo / "docs" / "superpowers" / "plans" / "plan.md").write_text("changed\n", encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "artifact_hash_mismatch"):
            validate_pr_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_valid_pr_ready_emits_rule_level_receipt(self):
        receipt = validate_pr_ready(parse_envelope(valid_pr_ready_envelope(self.repo), self.repo), self.repo)
        self.assertEqual("pr_ready", receipt.gate)
        self.assertEqual("passed", receipt.disposition)
        self.assertTrue({rule.rule_id for rule in receipt.rules} >= {"repository_identity", "implementation_verification", "review_disposition", "plan_conformance", "cleanup_state"})


if __name__ == "__main__":
    unittest.main()
