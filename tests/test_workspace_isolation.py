from __future__ import annotations

import unittest
import json
import subprocess
from pathlib import Path
from scripts.lib.evidence_schema import hash_ref

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
                "native_task_status": "created",
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
            {"codex_project_tasks": True, "local_git_worktrees": True, "source_task_id": "task-1", "native_task_status": "not_started"},
        )

        self.assertEqual(
            {"provider": "codex_managed_worktree", "operation": "fork_task"},
            {key: decision[key] for key in ("provider", "operation")},
        )

    def test_terminal_host_uses_unchanged_vanilla_fallback(self):
        decision = resolve_workspace_isolation(
            REQUEST,
            {"codex_project_tasks": False, "local_git_worktrees": True, "native_task_status": "not_started"},
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
                    "native_task_status": "not_started",
                },
            )

    def test_shared_subagent_is_ignored_when_isolation_is_only_preferred(self):
        decision = resolve_workspace_isolation(
            {**REQUEST, "requirement": "preferred"},
            {
                "codex_project_tasks": False,
                "local_git_worktrees": False,
                "delegation_provider": "shared_subagent",
                "native_task_status": "not_started",
            },
        )
        self.assertEqual("current_checkout", decision["provider"])

    def test_local_fallback_is_forbidden_after_native_task_creation(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "native task.*fallback"):
            resolve_workspace_isolation(
                REQUEST,
                {
                    "codex_project_tasks": False,
                    "local_git_worktrees": True,
                    "native_task_status": "created",
                },
            )

    def test_required_isolation_without_provider_fails_closed(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "required isolation"):
            resolve_workspace_isolation(
                REQUEST,
                {"codex_project_tasks": False, "local_git_worktrees": False, "native_task_status": "not_started"},
            )

    def test_caller_cannot_supply_workspace_observations(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "unsupported request field"):
            resolve_workspace_isolation(
                {**REQUEST, "observed_head": "0" * 40},
                {"codex_project_tasks": True, "native_task_status": "not_started"},
            )

    def test_native_task_status_is_required(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "native_task_status"):
            resolve_workspace_isolation(
                REQUEST,
                {"codex_project_tasks": False, "local_git_worktrees": True},
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
            {"schema_version": True},
            {"run_id": ""},
            {"candidate_id": ""},
        ):
            with self.subTest(mutation=mutation), self.assertRaises(WorkspaceIsolationError):
                validate_workspace_receipt(
                    {**self.native_receipt(), **mutation},
                    self.expected_receipt(),
                    current_head="a" * 40,
                    current_branch="codex/issue-115",
                    publication=True,
                )

    def test_local_receipt_requires_local_identity_shape(self):
        receipt = {
            **self.native_receipt(),
            "provider": "local_git_worktree",
            "owner": "plugin",
            "task_id": None,
            "thread_id": "local-worktree",
        }
        expected = {
            **self.expected_receipt(),
            "provider": "local_git_worktree",
            "owner": "plugin",
            "task_id": None,
            "thread_id": "local-worktree",
        }
        validate_workspace_receipt(
            receipt,
            expected,
            current_head="a" * 40,
            current_branch="codex/issue-115",
            publication=True,
        )
        for mutation in ({"task_id": "task-1"}, {"thread_id": ""}):
            with self.subTest(mutation=mutation), self.assertRaises(WorkspaceIsolationError):
                validate_workspace_receipt(
                    {**receipt, **mutation},
                    expected,
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

    def test_receipt_rejects_unvalidated_workspace_path(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "unknown"):
            validate_workspace_receipt(
                {**self.native_receipt(), "workspace_path": "/caller/selected"},
                self.expected_receipt(),
                current_head="a" * 40,
                current_branch="codex/issue-115",
                publication=True,
            )

    def test_closeout_policy_rejects_active_workspace_disposition(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "disposition"):
            validate_workspace_receipt(
                self.native_receipt(),
                self.expected_receipt(),
                current_head="a" * 40,
                current_branch="codex/issue-115",
                publication=False,
                allowed_dispositions={"integrated", "preserved"},
            )
        validate_workspace_receipt(
            {**self.native_receipt(), "disposition": "integrated"},
            self.expected_receipt(),
            current_head="a" * 40,
            current_branch="codex/issue-115",
            publication=False,
            allowed_dispositions={"integrated", "preserved"},
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
                json.dumps({"codex_project_tasks": True, "source_task_id": "task-1", "native_task_status": "not_started"}),
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

    def test_owner_skills_share_the_provider_contract(self):
        root = Path(__file__).resolve().parents[1]
        for skill in ("implement-plan", "resolve-issue", "orchestrate-issues"):
            with self.subTest(skill=skill):
                text = (root / "skills" / skill / "SKILL.md").read_text(encoding="utf-8")
                self.assertIn("scripts/workspace-isolation.sh", text)
                self.assertIn("codex_managed_worktree", text)
                self.assertIn("local_git_worktree", text)
                self.assertIn("workspace_receipt", text)
                self.assertRegex(text, r"shared subagent.*delegation")
                self.assertRegex(text, r"fallback.*native task")

        merge = (root / "skills/merge-changes/SKILL.md").read_text(encoding="utf-8")
        for phrase in ("workspace_receipt", "codex_app", "plugin-owned", "user-owned"):
            self.assertIn(phrase, merge)
        self.assertRegex(merge, r"physical.*remov")

        orchestrate = (root / "skills/orchestrate-issues/SKILL.md").read_text(encoding="utf-8")
        isolation_step = orchestrate.index("Satisfy Workspace Isolation")
        handoff_step = orchestrate.index("prepare-worker-handoff.sh")
        self.assertLess(isolation_step, handoff_step)

    def test_startup_metadata_exposes_workspace_routing(self):
        root = Path(__file__).resolve().parents[1]
        for skill in ("implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes"):
            with self.subTest(skill=skill):
                text = (root / "skills" / skill / "agents/openai.yaml").read_text(encoding="utf-8")
                self.assertIn("workspace_receipt", text)
                self.assertIn("Codex", text)

    def test_worker_handoff_requires_workspace_receipt_reference(self):
        root = Path(__file__).resolve().parents[1]
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, text=True, capture_output=True, check=True).stdout.strip()
        current_branch = subprocess.run(["git", "branch", "--show-current"], cwd=root, text=True, capture_output=True, check=True).stdout.strip()
        common_value = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=root, text=True, capture_output=True, check=True).stdout.strip()
        common = Path(common_value)
        if not common.is_absolute():
            common = root / common
        receipt = {
            "schema_version": 1,
            "provider": "codex_managed_worktree",
            "workspace_id": "workspace-1",
            "repository_root": str(root.resolve()),
            "git_common_dir": str(common.resolve()),
            "run_id": "run-1",
            "candidate_id": "issue-115",
            "task_id": "task-1",
            "thread_id": "thread-1",
            "observed_head": head,
            "head_mode": "branch" if current_branch else "detached",
            "branch": current_branch or None,
            "owner": "codex_app",
            "disposition": "active",
        }
        handoff = {
            "issue_mirror": "docs/superpowers/issues/115-codex-native-workspace-isolation.md",
            "source_plan": "docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md",
            "worker_identity": {
                "issue_number": 115,
                "issue_slug": "codex-native-workspace-isolation",
                "thread_title": "Resolve #115",
                "branch": "codex/issue-115-codex-native-workspace-isolation",
                "evidence_folder": "issue-115",
                "pr_title": "Resolve #115",
            },
            "branch": "codex/issue-115-codex-native-workspace-isolation",
            "branch_worktree_policy": "provider-selected isolated workspace",
            "workspace_provider": "codex_managed_worktree",
            "workspace_receipt": receipt,
            "workspace_receipt_ref": str(hash_ref(receipt)),
            "workflow_binding": {"run_id": "run-1", "candidate_id": "issue-115"},
            "reviewer_role": "main-thread-orchestrator",
            "proof_oracle": ["./scripts/validate.sh"],
            "validation": {"required_commands": ["./scripts/validate.sh"]},
            "topology_handoff": {"worker_must_not_merge": True},
            "merge_handoff": {"merge_owner": "merge-changes"},
            "required_skills": [
                "superpowers:test-driven-development",
                "superpowers:executing-plans",
                "superpowers:verification-before-completion",
                "superpowers:finishing-a-development-branch",
            ],
        }
        script = root / "skills/orchestrate-issues/scripts/validate-worker-handoff.sh"
        valid = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(root), "-HandoffJson", json.dumps(handoff)],
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, valid.returncode, valid.stdout + valid.stderr)

        forged = json.loads(json.dumps(handoff))
        forged["workspace_receipt_ref"] = "sha256:" + "b" * 64
        forged_result = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(root), "-HandoffJson", json.dumps(forged)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, forged_result.returncode)

        mismatched = json.loads(json.dumps(handoff))
        mismatched["workspace_receipt"]["candidate_id"] = "other"
        mismatched["workspace_receipt_ref"] = str(hash_ref(mismatched["workspace_receipt"]))
        mismatch_result = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(root), "-HandoffJson", json.dumps(mismatched)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, mismatch_result.returncode)

        missing_binding = json.loads(json.dumps(handoff))
        missing_binding["workflow_binding"] = {}
        missing_binding_result = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(root), "-HandoffJson", json.dumps(missing_binding)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, missing_binding_result.returncode)

        invalid_local = json.loads(json.dumps(handoff))
        invalid_local["workspace_provider"] = "local_git_worktree"
        invalid_local["workspace_receipt"].update(
            {"provider": "local_git_worktree", "owner": "plugin", "task_id": "task-1", "thread_id": ""}
        )
        invalid_local["workspace_receipt_ref"] = str(hash_ref(invalid_local["workspace_receipt"]))
        invalid_local["required_skills"].append("superpowers:using-git-worktrees")
        invalid_local_result = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(root), "-HandoffJson", json.dumps(invalid_local)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, invalid_local_result.returncode)

        handoff.pop("workspace_receipt_ref")
        missing = subprocess.run(
            ["bash", str(script), "-RepoRoot", str(root), "-HandoffJson", json.dumps(handoff)],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(0, missing.returncode)
        self.assertIn("workspace_receipt_ref", missing.stdout)

    def test_worker_handoff_preparation_binds_workspace_reference(self):
        root = Path(__file__).resolve().parents[1]
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, text=True, capture_output=True, check=True).stdout.strip()
        current_branch = subprocess.run(["git", "branch", "--show-current"], cwd=root, text=True, capture_output=True, check=True).stdout.strip()
        common_value = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=root, text=True, capture_output=True, check=True).stdout.strip()
        common = Path(common_value)
        if not common.is_absolute():
            common = root / common
        receipt = {
            "schema_version": 1,
            "provider": "codex_managed_worktree",
            "workspace_id": "workspace-1",
            "repository_root": str(root.resolve()),
            "git_common_dir": str(common.resolve()),
            "run_id": "run-1",
            "candidate_id": "issue-115",
            "task_id": "task-1",
            "thread_id": "thread-1",
            "observed_head": head,
            "head_mode": "branch" if current_branch else "detached",
            "branch": current_branch or None,
            "owner": "codex_app",
            "disposition": "active",
        }
        process = subprocess.run(
            [
                "bash",
                str(root / "skills/orchestrate-issues/scripts/prepare-worker-handoff.sh"),
                "-RepoRoot",
                str(root),
                "-IssueFile",
                "docs/superpowers/issues/115-codex-native-workspace-isolation.md",
                "-WorkspaceReceiptJson",
                json.dumps(receipt),
                "-WorkflowRunId",
                "run-1",
                "-CandidateId",
                "issue-115",
            ],
            text=True,
            capture_output=True,
        )

        self.assertEqual(0, process.returncode, process.stdout + process.stderr)
        handoff = json.loads(process.stdout)["handoff"]
        self.assertEqual("codex_managed_worktree", handoff["workspace_provider"])
        self.assertEqual(str(hash_ref(receipt)), handoff["workspace_receipt_ref"])
        self.assertNotIn("superpowers:using-git-worktrees", handoff["required_skills"])


if __name__ == "__main__":
    unittest.main()
