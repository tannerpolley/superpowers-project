from __future__ import annotations

import copy
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import scripts.lib.evidence_collectors as collectors
from scripts.lib.evidence_collectors import (
    CollectionRequest,
    build_evidence_envelope,
    collect_command_result,
    collect_git_state,
)
from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope


def git(root: Path, *args: str) -> str:
    process = subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True)
    return process.stdout.strip()


class EvidenceCollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "fixture@example.com")
        git(self.repo, "config", "user.name", "Fixture")
        plan = self.repo / "docs" / "superpowers" / "plans" / "plan.md"
        plan.parent.mkdir(parents=True)
        plan.write_text("# Plan\n", encoding="utf-8")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "fixture")

    def test_collectors_do_not_change_git_or_files(self):
        before_status = git(self.repo, "status", "--porcelain")
        before_files = {path.relative_to(self.repo).as_posix(): path.read_bytes() for path in self.repo.rglob("*") if path.is_file() and ".git" not in path.parts}
        result = collect_git_state(self.repo)
        after_status = git(self.repo, "status", "--porcelain")
        after_files = {path.relative_to(self.repo).as_posix(): path.read_bytes() for path in self.repo.rglob("*") if path.is_file() and ".git" not in path.parts}
        self.assertEqual(before_status, after_status)
        self.assertEqual(before_files, after_files)
        self.assertEqual(0, result.payload["status_exit_code"])

    def test_failed_command_is_observed_not_promoted(self):
        result = collect_command_result(self.repo, "git_missing_ref")
        self.assertNotEqual(0, result.payload["exit_code"])
        self.assertIn("stdout_hash", result.payload)
        self.assertIn("stderr_hash", result.payload)
        self.assertNotIn("ok", result.payload)

    def test_unregistered_commands_cannot_execute_or_mutate(self):
        marker = self.repo / "mutated.txt"
        for command in (
            ["sh", "-c", f"touch {marker}"],
            ["python3", "-c", f"open({str(marker)!r}, 'w').close()"],
            ["git", "commit", "--allow-empty", "-m", "forged"],
        ):
            with self.subTest(command=command):
                with self.assertRaisesRegex(EvidenceError, "collector_untrusted"):
                    collect_command_result(self.repo, command)  # type: ignore[arg-type]
        self.assertFalse(marker.exists())

    def test_git_observations_invoke_each_read_only_field_once(self):
        with patch.object(collectors, "_observe_process", wraps=collectors._observe_process) as observed:
            collect_git_state(self.repo)
        self.assertEqual(
            [call.args[1] for call in observed.call_args_list],
            [
                collectors.READ_ONLY_COMMANDS["git_status"],
                collectors.READ_ONLY_COMMANDS["git_head"],
                collectors.READ_ONLY_COMMANDS["git_branch"],
                collectors.READ_ONLY_COMMANDS["git_common_dir"],
                collectors.READ_ONLY_COMMANDS["git_remote_origin"],
            ],
        )

    def test_envelope_builder_binds_collected_evidence(self):
        request = CollectionRequest(
            gate="pr_ready",
            repository_root=self.repo,
            workflow={
                "run_id": "run-1",
                "candidate_id": "candidate-1",
                "mode": "manual",
                "authorization_hash": hash_ref({"authorized": True}),
            },
            source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
            target={"task_id": None, "workspace_id": "local", "branch": "main"},
            commands=("git_status",),
            provider_inputs={
                "reviews": [{"approved": True, "blocking": False}],
                "authorization": {"authorized": True},
                "cleanup": {"paths": [], "owner": "fixture"},
            },
        )
        envelope = build_evidence_envelope(request)
        parsed = parse_envelope(envelope, self.repo)
        self.assertEqual("pr_ready", parsed.gate)
        self.assertGreaterEqual(len(parsed.evidence), 5)
        self.assertEqual("main", parsed.target["branch"])

    def test_public_collection_without_request_fails_with_structured_error(self):
        root = Path(__file__).parents[1]
        for launcher in (
            "skills/resolve-issue/scripts/collect-pr-ready-ledger.sh",
            "skills/merge-changes/scripts/collect-premerge-ledger.sh",
            "skills/merge-changes/scripts/collect-closeout-ledger.sh",
        ):
            with self.subTest(launcher=launcher):
                process = subprocess.run(["bash", str(root / launcher)], cwd=root, text=True, capture_output=True)
                self.assertNotEqual(0, process.returncode)
                payload = json.loads(process.stdout)
                self.assertEqual("evidence_missing", payload["error"]["code"])


if __name__ == "__main__":
    unittest.main()
