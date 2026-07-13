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
from tests.execution_kernel_fixtures import provider_envelope, validate_provider_merge, validate_provider_premerge
from superpowers_project_cli import (
    Context,
    command_apply_local_branch_closeout,
    command_prepare_local_branch_closeout,
    command_resolve_preflight,
)
from scripts.lib.evidence_schema import hash_ref


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
            source_head = git(repo, "rev-parse", "HEAD").stdout.strip()
            target_head = git(repo, "rev-parse", "main").stdout.strip()
            authorization_hash = hash_ref({"authorized": True, "merge_strategy": "ff-only"})

            premerge_receipt = validate_provider_premerge(repo, provider_envelope(repo, "premerge"))
            merge_decision_receipt = validate_provider_merge(
                repo,
                provider_envelope(repo, "merge_decision", premerge_receipt.receipt_hash),
                premerge_receipt,
            )
            git(repo, "switch", "-q", "main")
            setup = {"merge_mode": "local-branch", "branch": "codex/fixture", "source_plan": "docs/superpowers/plans/plan.md", "repository_root": str(repo.resolve()), "run_id": "run-1", "candidate_id": "candidate-1", "authorization_hash": authorization_hash, "strategy": "ff-only", "source_head": source_head, "target_head": target_head}
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
                status = command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "MergeDecisionReceiptJson": json.dumps(merge_decision_receipt.to_dict()), "DryRun": True})
            self.assertEqual(0, status)
            result = json.loads(output.getvalue())
            self.assertFalse(result["evidence"]["remote_publication"])
            self.assertEqual(merge_decision_receipt.receipt_hash, result["evidence"]["consumed_receipt_hash"])
            for field in ("branch", "source_head", "source_plan", "run_id", "candidate_id", "authorization_hash", "strategy", "repository_root", "target_head"):
                with self.subTest(field=field):
                    forged = dict(setup)
                    forged[field] = "forged"
                    with self.assertRaisesRegex(Exception, "receipt|repository|artifact|target|local branch"):
                        command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(forged), "MergeDecisionReceiptJson": json.dumps(merge_decision_receipt.to_dict()), "DryRun": True})
            git(repo, "switch", "-q", "codex/fixture")
            (repo / "source-changed.txt").write_text("changed\n")
            git(repo, "add", "source-changed.txt")
            git(repo, "commit", "-qm", "source changed")
            git(repo, "switch", "-q", "main")
            with self.assertRaisesRegex(Exception, "source branch HEAD changed"):
                command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "MergeDecisionReceiptJson": json.dumps(merge_decision_receipt.to_dict()), "DryRun": True})
            plan_bytes = plan.read_bytes()
            plan.write_text("changed plan\n")
            with self.assertRaisesRegex(Exception, "source plan changed"):
                command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "MergeDecisionReceiptJson": json.dumps(merge_decision_receipt.to_dict()), "DryRun": True})
            plan.write_bytes(plan_bytes)
            (repo / "dirty-main.txt").write_text("dirty\n")
            with self.assertRaisesRegex(Exception, "target_state_changed"):
                command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "MergeDecisionReceiptJson": json.dumps(merge_decision_receipt.to_dict()), "DryRun": True})


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
