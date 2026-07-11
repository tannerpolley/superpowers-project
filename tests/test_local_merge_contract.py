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
from scripts.lib.evidence_collectors import CollectionRequest, build_evidence_envelope
from scripts.lib.evidence_schema import hash_ref, parse_envelope
from scripts.lib.gate_merge_decision import validate_merge_decision
from scripts.lib.gate_premerge import validate_premerge


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
            head = git(repo, "rev-parse", "HEAD").stdout.strip()

            def collected(gate, prior=None):
                return build_evidence_envelope(CollectionRequest(
                    gate=gate,
                    repository_root=repo,
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

            premerge_receipt = validate_premerge(parse_envelope(collected("premerge"), repo), repo)
            merge_decision_receipt = validate_merge_decision(parse_envelope(collected("merge_decision", premerge_receipt.receipt_hash), repo), repo, premerge_receipt)
            ctx.script_rel = "skills/merge-changes/scripts/apply-local-branch-closeout.sh"
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = command_apply_local_branch_closeout(ctx, {"RepoRoot": str(repo), "SetupLedgerJson": json.dumps(setup), "MergeDecisionReceiptJson": json.dumps(merge_decision_receipt.to_dict()), "DryRun": True})
            self.assertEqual(0, status)
            result = json.loads(output.getvalue())
            self.assertFalse(result["evidence"]["remote_publication"])
            self.assertEqual(merge_decision_receipt.receipt_hash, result["evidence"]["consumed_receipt_hash"])


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
