from __future__ import annotations

import unittest
import json
import subprocess
from pathlib import Path

from scripts.lib.workspace_isolation import (
    WorkspaceIsolationError,
    resolve_workspace_isolation,
    validate_workspace_receipt,
)


REQUEST = {
    "requirement": "required",
    "repository_identity": "repo:superpowers",
    "workflow_run_id": "run-1",
    "candidate_id": "candidate-1",
}


class WorkspaceIsolationTests(unittest.TestCase):
    def native_receipt(self, *, head_mode: str = "branch", branch: str | None = "codex/issue-115"):
        return {
            "schema_version": 1,
            "provider": "codex_managed_worktree",
            "workspace_id": "workspace-1",
            "repository_root": "/repo",
            "git_common_dir": "/repo/.git",
            "run_id": "run-1",
            "candidate_id": "candidate-1",
            "task_id": "task-1",
            "thread_id": "thread-1",
            "observed_head": "a" * 40,
            "head_mode": head_mode,
            "branch": branch,
            "owner": "codex_app",
            "disposition": "active",
        }

    def expected_receipt(self):
        return {
            "provider": "codex_managed_worktree",
            "workspace_id": "workspace-1",
            "repository_root": "/repo",
            "git_common_dir": "/repo/.git",
            "run_id": "run-1",
            "candidate_id": "candidate-1",
            "task_id": "task-1",
            "thread_id": "thread-1",
            "owner": "codex_app",
        }

    def test_matching_current_codex_worktree_is_adopted(self):
        decision = resolve_workspace_isolation(
            REQUEST,
            {
                "codex_project_tasks": True,
                "local_git_worktrees": True,
                "current_workspace": {
                    "provider": "codex_managed_worktree",
                    "repository_identity": "repo:superpowers",
                    "candidate_id": "candidate-1",
                    "workspace_id": "workspace-1",
                },
            },
        )

        self.assertEqual("codex_managed_worktree", decision["provider"])
        self.assertEqual("adopt", decision["operation"])
        self.assertEqual("workspace-1", decision["workspace_id"])

    def test_native_provider_prefers_fork_when_source_task_exists(self):
        decision = resolve_workspace_isolation(
            REQUEST,
            {"codex_project_tasks": True, "local_git_worktrees": True, "source_task_id": "task-1"},
        )

        self.assertEqual(
            {"provider": "codex_managed_worktree", "operation": "fork_task"},
            {key: decision[key] for key in ("provider", "operation")},
        )

    def test_terminal_host_uses_unchanged_vanilla_fallback(self):
        decision = resolve_workspace_isolation(
            REQUEST,
            {"codex_project_tasks": False, "local_git_worktrees": True},
        )

        self.assertEqual("local_git_worktree", decision["provider"])
        self.assertEqual("invoke_vanilla_worktree_skill", decision["operation"])
        self.assertNotIn("workspace_path", decision)

    def test_shared_subagent_cannot_satisfy_required_isolation(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "shared_subagent.*delegation"):
            resolve_workspace_isolation(
                REQUEST,
                {
                    "codex_project_tasks": False,
                    "local_git_worktrees": False,
                    "delegation_provider": "shared_subagent",
                },
            )

    def test_local_fallback_is_forbidden_after_native_task_creation(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "native task.*fallback"):
            resolve_workspace_isolation(
                REQUEST,
                {
                    "codex_project_tasks": False,
                    "local_git_worktrees": True,
                    "native_task_created": True,
                },
            )

    def test_required_isolation_without_provider_fails_closed(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "required isolation"):
            resolve_workspace_isolation(
                REQUEST,
                {"codex_project_tasks": False, "local_git_worktrees": False},
            )

    def test_caller_cannot_supply_workspace_observations(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "unsupported request field"):
            resolve_workspace_isolation(
                {**REQUEST, "observed_head": "0" * 40},
                {"codex_project_tasks": True},
            )

    def test_branch_bound_native_receipt_passes_publication(self):
        validate_workspace_receipt(
            self.native_receipt(),
            self.expected_receipt(),
            current_head="a" * 40,
            current_branch="codex/issue-115",
            publication=True,
        )

    def test_detached_native_receipt_can_execute_but_cannot_publish(self):
        receipt = self.native_receipt(head_mode="detached", branch=None)
        validate_workspace_receipt(
            receipt,
            self.expected_receipt(),
            current_head="a" * 40,
            current_branch="",
            publication=False,
        )
        with self.assertRaisesRegex(WorkspaceIsolationError, "branch-bound"):
            validate_workspace_receipt(
                receipt,
                self.expected_receipt(),
                current_head="a" * 40,
                current_branch="",
                publication=True,
            )

    def test_shared_subagent_and_invalid_owner_pairs_are_rejected(self):
        for mutation in (
            {"provider": "shared_subagent"},
            {"owner": "plugin"},
            {"schema_version": 2},
        ):
            with self.subTest(mutation=mutation), self.assertRaises(WorkspaceIsolationError):
                validate_workspace_receipt(
                    {**self.native_receipt(), **mutation},
                    self.expected_receipt(),
                    current_head="a" * 40,
                    current_branch="codex/issue-115",
                    publication=True,
                )

    def test_stale_or_mismatched_receipt_is_rejected(self):
        for mutation in ({"candidate_id": "other"}, {"observed_head": "b" * 40}):
            with self.subTest(mutation=mutation), self.assertRaises(WorkspaceIsolationError):
                validate_workspace_receipt(
                    {**self.native_receipt(), **mutation},
                    self.expected_receipt(),
                    current_head="a" * 40,
                    current_branch="codex/issue-115",
                    publication=True,
                )

    def test_public_launcher_returns_only_an_untrusted_action_decision(self):
        root = Path(__file__).resolve().parents[1]
        process = subprocess.run(
            [
                "bash",
                str(root / "scripts/workspace-isolation.sh"),
                "-RepoRoot",
                str(root),
                "-RequestJson",
                json.dumps(REQUEST),
                "-CapabilitiesJson",
                json.dumps({"codex_project_tasks": True, "source_task_id": "task-1"}),
            ],
            cwd="/tmp",
            text=True,
            capture_output=True,
        )

        self.assertEqual(0, process.returncode, process.stdout + process.stderr)
        payload = json.loads(process.stdout)
        self.assertTrue(payload["ok"])
        self.assertTrue(payload["untrusted_request"])
        self.assertEqual("workspace-isolation-decision", payload["phase"])
        self.assertEqual("fork_task", payload["decision"]["operation"])


if __name__ == "__main__":
    unittest.main()
