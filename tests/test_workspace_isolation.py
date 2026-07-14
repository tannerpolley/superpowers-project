from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.lib.evidence_schema import hash_ref
from scripts.lib.workspace_isolation import WorkspaceIsolationError, resolve_workspace_isolation, validate_workspace_receipt


ROOT = Path(__file__).resolve().parents[1]
REQUEST = {
    "requirement": "required",
    "repository_identity": "repo:superpowers",
    "workflow_run_id": "run-1",
    "candidate_id": "candidate-1",
}
FIXTURE_ISSUE = "docs/superpowers/issues/115-workspace-fixture.md"
FIXTURE_PLAN = "docs/superpowers/plans/workspace-fixture-plan.md"
FIXTURE_BRANCH = "codex/issue-115-workspace-fixture"


class WorkspaceIsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._fixture_dir = tempfile.TemporaryDirectory()
        cls.fixture_root = Path(cls._fixture_dir.name)
        issue = cls.fixture_root / FIXTURE_ISSUE
        plan = cls.fixture_root / FIXTURE_PLAN
        issue.parent.mkdir(parents=True)
        plan.parent.mkdir(parents=True)
        plan.write_text("# Workspace Fixture Plan\n", encoding="utf-8")
        issue.write_text(
            "# Workspace Fixture\n\n"
            "**GitHub Issue:** https://github.com/example/project/issues/115\n"
            f"**Source Plan:** `{FIXTURE_PLAN}`\n"
            "**Sub-Issue Role:** leaf\n"
            "**Executable:** true\n"
            "**Goal Command:** `/goal run fixture`\n\n"
            "## Proof Oracle\n\n- `./scripts/validate.sh`\n",
            encoding="utf-8",
        )
        for command in (
            ["git", "init", "-b", FIXTURE_BRANCH],
            ["git", "config", "user.name", "Fixture"],
            ["git", "config", "user.email", "fixture@example.invalid"],
            ["git", "add", "."],
            ["git", "commit", "-m", "fixture"],
        ):
            subprocess.run(command, cwd=cls.fixture_root, check=True, text=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls._fixture_dir.cleanup()

    def native_receipt(self, **overrides):
        receipt = {
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
            "head_mode": "branch",
            "branch": "codex/issue-115",
            "owner": "codex_app",
            "disposition": "active",
        }
        return {**receipt, **overrides}

    def expected_receipt(self, **overrides):
        expected = {key: self.native_receipt()[key] for key in (
            "provider", "workspace_id", "repository_root", "git_common_dir", "run_id",
            "candidate_id", "task_id", "thread_id", "owner",
        )}
        return {**expected, **overrides}

    def validate_native(self, receipt=None, expected=None, **options):
        validate_workspace_receipt(
            receipt or self.native_receipt(),
            expected or self.expected_receipt(),
            current_head="a" * 40,
            current_branch="codex/issue-115",
            publication=True,
            **options,
        )

    def git_value(self, *args):
        return subprocess.run(["git", *args], cwd=self.fixture_root, text=True, capture_output=True, check=True).stdout.strip()

    def fixture_receipt(self):
        root = self.fixture_root
        branch = self.git_value("branch", "--show-current")
        common = Path(self.git_value("rev-parse", "--git-common-dir"))
        if not common.is_absolute():
            common = root / common
        return {
            **self.native_receipt(),
            "repository_root": str(root.resolve()),
            "git_common_dir": str(common.resolve()),
            "candidate_id": "issue-115",
            "observed_head": self.git_value("rev-parse", "HEAD"),
            "head_mode": "branch" if branch else "detached",
            "branch": branch or None,
        }

    def handoff(self, receipt):
        return {
            "issue_mirror": FIXTURE_ISSUE,
            "source_plan": FIXTURE_PLAN,
            "worker_identity": {
                "issue_number": 115,
                "issue_slug": "workspace-fixture",
                "thread_title": "Resolve #115",
                "branch": FIXTURE_BRANCH,
                "evidence_folder": "issue-115",
                "pr_title": "Resolve #115",
            },
            "branch": FIXTURE_BRANCH,
            "branch_worktree_policy": "provider-selected isolated workspace",
            "workspace_provider": receipt["provider"],
            "workspace_receipt": receipt,
            "workspace_receipt_ref": str(hash_ref(receipt)),
            "workflow_binding": {"run_id": "run-1", "candidate_id": "issue-115"},
            "reviewer_role": "main-thread-orchestrator",
            "proof_oracle": ["./scripts/validate.sh"],
            "validation": {"required_commands": ["./scripts/validate.sh"]},
            "topology_handoff": {"worker_must_not_merge": True},
            "merge_handoff": {"merge_owner": "merge-changes"},
            "required_skills": [
                "superpowers:executing-plans",
                "superpowers:verification-before-completion",
                "superpowers:finishing-a-development-branch",
            ],
        }

    def validate_handoff(self, handoff):
        return subprocess.run(
            ["bash", str(ROOT / "skills/orchestrate-issues/scripts/validate-worker-handoff.sh"),
             "-RepoRoot", str(self.fixture_root), "-HandoffJson", json.dumps(handoff)],
            text=True,
            capture_output=True,
        )

    def test_provider_resolution_routes(self):
        cases = (
            ({"codex_project_tasks": True, "local_git_worktrees": True, "native_task_status": "created",
              "current_workspace": {"provider": "codex_managed_worktree", "repository_identity": "repo:superpowers",
                                    "candidate_id": "candidate-1", "workspace_id": "workspace-1"}},
             REQUEST, {"provider": "codex_managed_worktree", "operation": "adopt", "workspace_id": "workspace-1"}),
            ({"codex_project_tasks": True, "local_git_worktrees": True, "source_task_id": "task-1", "native_task_status": "not_started"},
             REQUEST, {"provider": "codex_managed_worktree", "operation": "fork_task"}),
            ({"codex_project_tasks": False, "local_git_worktrees": True, "native_task_status": "not_started"},
             REQUEST, {"provider": "local_git_worktree", "operation": "invoke_vanilla_worktree_skill"}),
            ({"codex_project_tasks": False, "local_git_worktrees": False, "delegation_provider": "shared_subagent", "native_task_status": "not_started"},
             {**REQUEST, "requirement": "preferred"}, {"provider": "current_checkout"}),
        )
        for capabilities, request, expected in cases:
            with self.subTest(expected=expected):
                decision = resolve_workspace_isolation(request, capabilities)
                self.assertEqual(expected, {key: decision[key] for key in expected})

    def test_invalid_provider_resolution_fails_closed(self):
        cases = (
            (REQUEST, {"codex_project_tasks": False, "local_git_worktrees": False, "delegation_provider": "shared_subagent", "native_task_status": "not_started"}),
            (REQUEST, {"codex_project_tasks": False, "local_git_worktrees": True, "native_task_status": "created"}),
            (REQUEST, {"codex_project_tasks": False, "local_git_worktrees": False, "native_task_status": "not_started"}),
            ({**REQUEST, "observed_head": "0" * 40}, {"codex_project_tasks": True, "native_task_status": "not_started"}),
            (REQUEST, {"codex_project_tasks": False, "local_git_worktrees": True}),
        )
        for request, capabilities in cases:
            with self.subTest(request=request, capabilities=capabilities), self.assertRaises(WorkspaceIsolationError):
                resolve_workspace_isolation(request, capabilities)

    def test_native_receipt_publication_and_detached_execution(self):
        self.validate_native()
        detached = self.native_receipt(head_mode="detached", branch=None)
        validate_workspace_receipt(detached, self.expected_receipt(), current_head="a" * 40, current_branch="", publication=False)
        with self.assertRaisesRegex(WorkspaceIsolationError, "branch-bound"):
            validate_workspace_receipt(detached, self.expected_receipt(), current_head="a" * 40, current_branch="", publication=True)

    def test_invalid_native_receipts_fail_closed(self):
        mutations = (
            {"provider": "shared_subagent"}, {"owner": "plugin"}, {"schema_version": 2},
            {"schema_version": True}, {"run_id": ""}, {"candidate_id": ""},
            {"candidate_id": "other"}, {"observed_head": "b" * 40}, {"workspace_path": "/caller/selected"},
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation), self.assertRaises(WorkspaceIsolationError):
                self.validate_native({**self.native_receipt(), **mutation})

    def test_local_receipt_identity_and_closeout_disposition(self):
        receipt = self.native_receipt(provider="local_git_worktree", owner="plugin", task_id=None, thread_id="local-worktree")
        expected = self.expected_receipt(provider="local_git_worktree", owner="plugin", task_id=None, thread_id="local-worktree")
        self.validate_native(receipt, expected)
        for mutation in ({"task_id": "task-1"}, {"thread_id": ""}):
            with self.subTest(mutation=mutation), self.assertRaises(WorkspaceIsolationError):
                self.validate_native({**receipt, **mutation}, expected)
        with self.assertRaisesRegex(WorkspaceIsolationError, "disposition"):
            validate_workspace_receipt(self.native_receipt(), self.expected_receipt(), current_head="a" * 40,
                                       current_branch="codex/issue-115", publication=False,
                                       allowed_dispositions={"integrated", "preserved"})
        validate_workspace_receipt(self.native_receipt(disposition="integrated"), self.expected_receipt(),
                                   current_head="a" * 40, current_branch="codex/issue-115", publication=False,
                                   allowed_dispositions={"integrated", "preserved"})

    def test_public_launcher_returns_untrusted_action_decision(self):
        process = subprocess.run(
            ["bash", str(ROOT / "scripts/workspace-isolation.sh"), "-RepoRoot", str(ROOT),
             "-RequestJson", json.dumps(REQUEST),
             "-CapabilitiesJson", json.dumps({"codex_project_tasks": True, "source_task_id": "task-1", "native_task_status": "not_started"})],
            cwd="/tmp",
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, process.returncode, process.stdout + process.stderr)
        payload = json.loads(process.stdout)
        self.assertEqual((True, True, "workspace-isolation-decision", "fork_task"),
                         (payload["ok"], payload["untrusted_request"], payload["phase"], payload["decision"]["operation"]))

    def test_worker_handoff_requires_bound_workspace_receipt(self):
        handoff = self.handoff(self.fixture_receipt())
        self.assertEqual(0, self.validate_handoff(handoff).returncode)
        variants = []
        forged = json.loads(json.dumps(handoff))
        forged["workspace_receipt_ref"] = "sha256:" + "b" * 64
        variants.append(forged)
        mismatch = json.loads(json.dumps(handoff))
        mismatch["workspace_receipt"]["candidate_id"] = "other"
        mismatch["workspace_receipt_ref"] = str(hash_ref(mismatch["workspace_receipt"]))
        variants.append(mismatch)
        missing_binding = json.loads(json.dumps(handoff))
        missing_binding["workflow_binding"] = {}
        variants.append(missing_binding)
        invalid_local = json.loads(json.dumps(handoff))
        invalid_local["workspace_provider"] = "local_git_worktree"
        invalid_local["workspace_receipt"].update(
            {"provider": "local_git_worktree", "owner": "plugin", "task_id": "task-1", "thread_id": ""}
        )
        invalid_local["workspace_receipt_ref"] = str(hash_ref(invalid_local["workspace_receipt"]))
        invalid_local["required_skills"].append("superpowers:using-git-worktrees")
        variants.append(invalid_local)
        missing_ref = json.loads(json.dumps(handoff))
        missing_ref.pop("workspace_receipt_ref")
        variants.append(missing_ref)
        for variant in variants:
            with self.subTest(variant=variant):
                self.assertNotEqual(0, self.validate_handoff(variant).returncode)

    def test_worker_handoff_preparation_binds_workspace_reference(self):
        receipt = self.fixture_receipt()
        process = subprocess.run(
            ["bash", str(ROOT / "skills/orchestrate-issues/scripts/prepare-worker-handoff.sh"),
             "-RepoRoot", str(self.fixture_root), "-IssueFile", FIXTURE_ISSUE,
             "-WorkspaceReceiptJson", json.dumps(receipt), "-WorkflowRunId", "run-1", "-CandidateId", "issue-115"],
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, process.returncode, process.stdout + process.stderr)
        handoff = json.loads(process.stdout)["handoff"]
        self.assertEqual(("codex_managed_worktree", str(hash_ref(receipt))),
                         (handoff["workspace_provider"], handoff["workspace_receipt_ref"]))
        self.assertNotIn("superpowers:using-git-worktrees", handoff["required_skills"])


if __name__ == "__main__":
    unittest.main()
