import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from superpowers_project_cli import (
    Context,
    command_apply_local_branch_closeout,
    command_prepare_local_branch_closeout,
    command_resolve_preflight,
)


def git(root: Path, *args: str):
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True)


class LocalMergeContractTests(unittest.TestCase):
    def test_local_premerge_and_dry_run_need_no_push_or_pr_proof(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            git(repo, "init", "-q", "-b", "main")
            git(repo, "config", "user.email", "fixture@example.com")
            git(repo, "config", "user.name", "Fixture")
            plan = repo / "docs" / "superpowers" / "plans" / "plan.md"
            plan.parent.mkdir(parents=True)
            plan.write_text("# Plan\n")
            git(repo, "add", ".")
            git(repo, "commit", "-qm", "base")
            git(repo, "switch", "-qc", "codex/fixture")
            (repo / "result.txt").write_text("complete\n")
            git(repo, "add", ".")
            git(repo, "commit", "-qm", "result")
            git(repo, "switch", "-q", "main")
            setup = {"merge_mode": "local-branch", "branch": "codex/fixture", "source_plan": "docs/superpowers/plans/plan.md"}
            readiness = {"plan_alignment": True, "correctness": True, "maintainability": True, "reality_evidence": True}
            ctx = Context(ROOT / "skills/merge-changes/scripts/prepare-local-branch-closeout.sh", repo, "skills/merge-changes/scripts/prepare-local-branch-closeout.sh", "prepare-local-branch-closeout.sh", [], ROOT, repo)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = command_prepare_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "ReadinessReviewJson": json.dumps(readiness)})
            self.assertEqual(0, status)
            receipt = json.loads(output.getvalue())
            self.assertFalse(receipt["evidence"]["remote_publication_required"])
            self.assertNotIn("push", json.dumps(receipt).lower())
            ctx.script_rel = "skills/merge-changes/scripts/apply-local-branch-closeout.sh"
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "PremergeResultJson": json.dumps({"ok": True}), "MergeDecisionJson": json.dumps({"selected_action": "merge"}), "DryRun": True})
            self.assertEqual(0, status)
            self.assertFalse(json.loads(output.getvalue())["evidence"]["remote_publication"])


class ResolvePreflightTests(unittest.TestCase):
    def test_preflight_accepts_bold_source_plan_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            mirror = repo / "docs" / "superpowers" / "issues" / "113-trust.md"
            plan = repo / "docs" / "superpowers" / "plans" / "trust-plan.md"
            plan.parent.mkdir(parents=True)
            mirror.parent.mkdir(parents=True)
            plan.write_text("# Plan\n", encoding="utf-8")
            mirror.write_text(
                "# Issue\n\n"
                "**Source Plan:** `docs/superpowers/plans/trust-plan.md`\n"
                "**Sub-Issue Role:** leaf\n"
                "**Executable:** true\n",
                encoding="utf-8",
            )
            ctx = Context(
                ROOT / "skills/resolve-issue/scripts/preflight.sh",
                repo,
                "skills/resolve-issue/scripts/preflight.sh",
                "preflight.sh",
                [],
                ROOT,
                repo,
            )
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = command_resolve_preflight(
                    ctx,
                    {
                        "RepoRoot": str(repo),
                        "IssueMirrorPath": "docs/superpowers/issues/113-trust.md",
                    },
                )
            self.assertEqual(0, status, output.getvalue())
            self.assertEqual(
                "docs/superpowers/plans/trust-plan.md",
                json.loads(output.getvalue())["source_plan"],
            )


if __name__ == "__main__":
    unittest.main()
