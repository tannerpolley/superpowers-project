import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
import scripts.lib.evidence_collectors as evidence_collectors
import scripts.lib.gate_premerge as gate_premerge
from superpowers_project_cli import (
    Context,
    command_apply_local_branch_closeout,
    command_prepare_local_branch_closeout,
    command_resolve_preflight,
)
from scripts.lib.evidence_collectors import CollectionRequest, CollectorResult, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_merge_decision import validate_merge_decision
from scripts.lib.gate_premerge import validate_premerge


def git(root: Path, *args: str):
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True)


def github_observation(payload: dict[str, object]) -> CollectorResult:
    observed = {"observation_id": "github_pr_state", **payload}
    observed["observation_hash"] = hash_ref({"mock": observed})
    return CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", observed)


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
            authorization_hash = hash_ref({"authorized": True, "strategy": "ff-only"})

            def collected(gate, prior=None):
                request = CollectionRequest(
                    gate=gate,
                    repository_root=repo,
                    workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": authorization_hash},
                    source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
                    target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False},
                    commands=("git_status",),
                    provider_inputs={
                        "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
                        "authorization": {"authorized": True, "strategy": "ff-only"},
                        "github_observation_id": "github_pr_state",
                        "github_fixture_payload": {"provider_available": True, "pr_id": 113, "repository": "fixture/repo", "repository_id": "fixture/repository-id", "base_ref": "main", "base_sha": target_head, "head_ref": "codex/fixture", "head_sha": source_head, "source_branch": "codex/fixture", "source_sha": source_head, "mergeable": True, "reviews": [], "checks": [{"name": "ci", "conclusion": "success"}]},
                    },
                    prior_event_hash=prior,
                )
                fixture = github_observation(request.provider_inputs["github_fixture_payload"])
                with patch.object(evidence_collectors, "collect_github_state", return_value=fixture):
                    return build_evidence_envelope(request)

            premerge_envelope = collected("premerge")
            provider = next(item for item in premerge_envelope["evidence"] if item["kind"] == "github_state")["payload"]
            fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider)
            with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
                premerge_receipt = validate_premerge(parse_envelope(premerge_envelope, repo), repo)
            merge_envelope = collected("merge_decision", premerge_receipt.receipt_hash)
            provider = next(item for item in merge_envelope["evidence"] if item["kind"] == "github_state")["payload"]
            fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider)
            with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
                merge_decision_receipt = validate_merge_decision(parse_envelope(merge_envelope, repo), repo, premerge_receipt)
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
