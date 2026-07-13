from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
import contextlib
import io
from pathlib import Path

from scripts.lib.command_support import Context
from scripts.lib.commands.gates import command_validate_pr_ready
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


def valid_pr_ready_envelope(repo: Path, *, isolation: bool = False, workspace: dict[str, object] | None = None) -> dict[str, object]:
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
        target={
            "task_id": "task-1" if isolation else None,
            "workspace_id": "workspace-1" if isolation else "local",
            "branch": "main",
            "isolation_required": isolation,
            **({"workspace_provider": "codex_managed_worktree", "workspace_thread_id": "thread-1", "workspace_owner": "codex_app", "cleanup_actor": "codex_app"} if isolation else {}),
        },
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": {"authorized": True},
            "cleanup": {"status_exit_code": 0, "dirty": False, "owner": "fixture", "task_owned_paths": []},
            **({"workspace_receipt": workspace} if workspace is not None else {}),
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

    def test_pr_ready_rejects_dirty_state_created_after_collection(self):
        envelope = valid_pr_ready_envelope(self.repo)
        (self.repo / "untracked-after-collection.txt").write_text("untrusted\n", encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_pr_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_pr_ready_rejects_tampered_cleanup_observation(self):
        envelope = valid_pr_ready_envelope(self.repo)
        cleanup = next(item for item in envelope["evidence"] if item["kind"] == "cleanup_state")
        cleanup["payload"]["status_hash"] = hash_ref({"forged": True})
        cleanup["payload_hash"] = hash_ref(cleanup["payload"])
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_pr_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_pr_ready_rejects_incomplete_command_observation(self):
        envelope = valid_pr_ready_envelope(self.repo)
        command = next(item for item in envelope["evidence"] if item["kind"] == "command_result")
        command["payload"] = {"exit_code": 0, "timed_out": False}
        command["payload_hash"] = hash_ref(command["payload"])
        envelope["envelope_hash"] = build_envelope_hash(envelope)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_pr_ready(parse_envelope(envelope, self.repo), self.repo)

    def test_public_pr_ready_rejects_duplicate_json_keys(self):
        envelope = valid_pr_ready_envelope(self.repo)
        raw = json.dumps(envelope).replace('"schema_version": 1,', '"schema_version": 1, "schema_version": 1,', 1)
        root = Path(__file__).parents[1]
        ctx = Context(root / "skills/resolve-issue/scripts/validate-pr-ready.sh", self.repo, "skills/resolve-issue/scripts/validate-pr-ready.sh", "validate-pr-ready.sh", [], root, self.repo)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = command_validate_pr_ready(ctx, {"RepoRoot": str(self.repo), "EvidenceEnvelopeJson": raw})
        self.assertNotEqual(0, status)
        self.assertEqual("schema_invalid", json.loads(output.getvalue())["error"]["code"])

    def test_isolation_workspace_receipt_binds_provider_owner_and_fresh_head(self):
        head = git(self.repo, "rev-parse", "HEAD")
        workspace = {"schema_version": 1, "provider": "codex_managed_worktree", "workspace_id": "workspace-1", "repository_root": str(self.repo.resolve()), "git_common_dir": str((self.repo / ".git").resolve()), "run_id": "run-1", "candidate_id": "candidate-1", "task_id": "task-1", "thread_id": "thread-1", "observed_head": head, "head_mode": "branch", "branch": "main", "owner": "codex_app", "disposition": "active"}
        receipt = validate_pr_ready(parse_envelope(valid_pr_ready_envelope(self.repo, isolation=True, workspace=workspace), self.repo), self.repo)
        self.assertEqual("passed", receipt.disposition)

    def test_isolation_workspace_receipt_rejects_detached_publication(self):
        head = git(self.repo, "rev-parse", "HEAD")
        workspace = {"schema_version": 1, "provider": "codex_managed_worktree", "workspace_id": "workspace-1", "repository_root": str(self.repo.resolve()), "git_common_dir": str((self.repo / ".git").resolve()), "run_id": "run-1", "candidate_id": "candidate-1", "task_id": "task-1", "thread_id": "thread-1", "observed_head": head, "head_mode": "detached", "branch": None, "owner": "codex_app", "disposition": "active"}
        with self.assertRaisesRegex(EvidenceError, "branch-bound"):
            validate_pr_ready(parse_envelope(valid_pr_ready_envelope(self.repo, isolation=True, workspace=workspace), self.repo), self.repo)

    def test_isolation_workspace_receipt_rejects_missing_duplicate_or_mismatched_bindings(self):
        head = git(self.repo, "rev-parse", "HEAD")
        workspace = {"schema_version": 1, "provider": "codex_managed_worktree", "workspace_id": "workspace-1", "repository_root": str(self.repo.resolve()), "git_common_dir": str((self.repo / ".git").resolve()), "run_id": "run-1", "candidate_id": "candidate-1", "task_id": "task-1", "thread_id": "thread-1", "observed_head": head, "head_mode": "branch", "branch": "main", "owner": "codex_app", "disposition": "active"}
        for mutation in ("missing", "duplicate", "provider", "thread", "task", "candidate", "head", "owner", "branch", "schema", "cleanup"):
            with self.subTest(mutation=mutation):
                envelope = valid_pr_ready_envelope(self.repo, isolation=True, workspace=workspace)
                if mutation == "missing":
                    envelope["evidence"] = [item for item in envelope["evidence"] if item["kind"] != "workspace_receipt"]
                elif mutation == "duplicate":
                    envelope["evidence"].append(dict(next(item for item in envelope["evidence"] if item["kind"] == "workspace_receipt")))
                elif mutation == "cleanup":
                    item = next(item for item in envelope["evidence"] if item["kind"] == "cleanup_state")
                    item["payload"]["cleanup_actor"] = "untrusted"
                    item["payload_hash"] = hash_ref(item["payload"])
                else:
                    item = next(item for item in envelope["evidence"] if item["kind"] == "workspace_receipt")
                    key = {
                        "provider": "provider",
                        "thread": "thread_id",
                        "task": "task_id",
                        "candidate": "candidate_id",
                        "head": "observed_head",
                        "owner": "owner",
                        "branch": "branch",
                        "schema": "schema_version",
                    }[mutation]
                    item["payload"][key] = 2 if mutation == "schema" else ("fixture" if mutation == "provider" else "forged")
                    item["payload_hash"] = hash_ref(item["payload"])
                envelope["envelope_hash"] = build_envelope_hash(envelope)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    validate_pr_ready(parse_envelope(envelope, self.repo), self.repo)


if __name__ == "__main__":
    unittest.main()
