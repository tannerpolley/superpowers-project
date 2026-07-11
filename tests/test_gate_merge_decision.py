from __future__ import annotations

import contextlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import scripts.lib.evidence_collectors as evidence_collectors
import scripts.lib.gate_premerge as gate_premerge
from scripts.lib.command_support import Context
from scripts.lib.evidence_collectors import CollectionRequest, CollectorResult, build_evidence_envelope
from scripts.lib.evidence_schema import EvidenceError, RuleResult, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_merge_decision import validate_merge_decision
from scripts.lib.gate_premerge import validate_premerge
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.gate_receipts import build_receipt
sys.path.insert(0, str(Path(__file__).parents[1] / "scripts" / "lib"))
from scripts.lib.superpowers_project_cli import command_apply_local_branch_closeout


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=True).stdout.strip()


def github_observation(payload: dict[str, object]) -> CollectorResult:
    observed = {"observation_id": "github_pr_state", **payload}
    observed["observation_hash"] = hash_ref({"mock": observed})
    return CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", observed)


def make_repo() -> Path:
    root = Path(tempfile.mkdtemp())
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "fixture@example.com")
    git(root, "config", "user.name", "Fixture")
    plan = root / "docs" / "superpowers" / "plans" / "plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text("# Plan\n", encoding="utf-8")
    git(root, "add", ".")
    git(root, "commit", "-qm", "base")
    git(root, "switch", "-qc", "codex/fixture")
    (root / "feature.txt").write_text("feature\n", encoding="utf-8")
    git(root, "add", "feature.txt")
    git(root, "commit", "-qm", "feature")
    return root


def envelope(root: Path, gate: str, prior: str | None = None, *, target_strategy: str = "ff-only", authorization_strategy: str = "ff-only") -> dict[str, object]:
    head = git(root, "rev-parse", "HEAD")
    base = git(root, "rev-parse", "main")
    request = CollectionRequest(
        gate=gate,
        repository_root=root,
        workflow={"run_id": "run-1", "candidate_id": "candidate-1", "mode": "manual", "authorization_hash": hash_ref({"authorized": True, "merge_strategy": authorization_strategy})},
        source={"spec_path": None, "plan_path": "docs/superpowers/plans/plan.md"},
        target={"task_id": None, "workspace_id": "local", "branch": "main", "isolation_required": False, "merge_strategy": target_strategy},
        commands=("git_status",),
        provider_inputs={
            "reviews": [{"approved": True, "blocking": False, "plan_conformance": True}],
            "authorization": {"authorized": True, "merge_strategy": authorization_strategy},
            "github_observation_id": "github_pr_state",
            "github_fixture_payload": {"provider_available": True, "pr_id": 113, "repository": "fixture/repo", "repository_id": "fixture/repository-id", "base_ref": "main", "base_sha": base, "head_ref": "codex/fixture", "head_sha": head, "source_branch": "codex/fixture", "source_sha": head, "mergeable": True, "reviews": [], "checks": [{"name": "ci", "conclusion": "success"}]},
        },
        prior_event_hash=prior,
    )
    fixture = github_observation(request.provider_inputs["github_fixture_payload"])
    with patch.object(evidence_collectors, "collect_github_state", return_value=fixture):
        return build_evidence_envelope(request)


class MergeDecisionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(lambda: shutil.rmtree(self.repo, ignore_errors=True))

    def validate_premerge_fixture(self, data, prior=None):
        if prior is None:
            authorization = next(item for item in data["evidence"] if item["kind"] == "authorization_event")["payload"]["event"]
            pr_data = build_evidence_envelope(CollectionRequest(
                gate="pr_ready", repository_root=self.repo, workflow={**data["workflow"]},
                source={"spec_path": data["source"]["spec_path"], "plan_path": data["source"]["plan_path"]},
                target={"task_id": None, "workspace_id": "local", "branch": git(self.repo, "branch", "--show-current"), "isolation_required": False},
                commands=("git_status",), provider_inputs={"reviews": [{"approved": True, "blocking": False, "plan_conformance": True}], "authorization": authorization, "cleanup": {"status_exit_code": 0, "dirty": False, "task_owned_paths": []}},
            ))
            prior = validate_pr_ready(parse_envelope(pr_data, self.repo), self.repo)
            data["prior_event_hash"] = prior.receipt_hash
            data["envelope_hash"] = build_envelope_hash(data)
        provider = next(item for item in data["evidence"] if item["kind"] == "github_state")["payload"]
        fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider)
        with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
            return validate_premerge(parse_envelope(data, self.repo), self.repo, prior)

    def validate_merge_fixture(self, data, prior):
        provider = next(item for item in data["evidence"] if item["kind"] == "github_state")["payload"]
        fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider)
        with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
            return validate_merge_decision(parse_envelope(data, self.repo), self.repo, prior)

    def test_merge_decision_requires_current_premerge_receipt(self):
        decision = parse_envelope(envelope(self.repo, "merge_decision"), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_merge_decision(decision, self.repo, None)

    def test_public_merge_decision_launcher_fails_without_evidence(self):
        root = Path(__file__).parents[1]
        process = subprocess.run(["bash", str(root / "skills/merge-changes/scripts/validate-merge-decision.sh")], cwd=root, text=True, capture_output=True)
        self.assertNotEqual(0, process.returncode)
        self.assertEqual("evidence_missing", json.loads(process.stdout)["error"]["code"])

    def test_merge_decision_accepts_matching_premerge_receipt(self):
        premerge = self.validate_premerge_fixture(envelope(self.repo, "premerge"))
        decision = parse_envelope(envelope(self.repo, "merge_decision", premerge.receipt_hash), self.repo)
        receipt = self.validate_merge_fixture(envelope(self.repo, "merge_decision", premerge.receipt_hash), premerge)
        self.assertEqual("merge_decision", receipt.gate)
        self.assertEqual("passed", receipt.disposition)

    def test_merge_decision_rejects_stale_premerge_head(self):
        premerge = self.validate_premerge_fixture(envelope(self.repo, "premerge"))
        (self.repo / "changed-after-premerge.txt").write_text("changed\n", encoding="utf-8")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "changed after premerge")
        with self.assertRaisesRegex(EvidenceError, "stale"):
            self.validate_merge_fixture(envelope(self.repo, "merge_decision", premerge.receipt_hash), premerge)

    def test_merge_decision_rejects_missing_authorization_strategy(self):
        premerge = self.validate_premerge_fixture(envelope(self.repo, "premerge"))
        data = envelope(self.repo, "merge_decision", premerge.receipt_hash)
        authorization = next(item for item in data["evidence"] if item["kind"] == "authorization_event")
        authorization["payload"]["event"].pop("merge_strategy")
        authorization["payload_hash"] = hash_ref(authorization["payload"])
        data["envelope_hash"] = build_envelope_hash(data)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            self.validate_merge_fixture(data, premerge)

    def test_merge_strategy_must_match_target_in_both_directions(self):
        for target_strategy, authorization_strategy in (("ff-only", "squash"), ("squash", "ff-only")):
            with self.subTest(target_strategy=target_strategy, authorization_strategy=authorization_strategy):
                data = envelope(self.repo, "premerge", target_strategy=target_strategy, authorization_strategy=authorization_strategy)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    self.validate_premerge_fixture(data)

    def test_local_merge_rejects_bare_success_object(self):
        ctx = Context(Path(__file__).parents[1] / "skills/merge-changes/scripts/apply-local-branch-closeout.sh", self.repo, "skills/merge-changes/scripts/apply-local-branch-closeout.sh", "apply-local-branch-closeout.sh", [], Path(__file__).parents[1], self.repo)
        with self.assertRaisesRegex(Exception, "legacy_evidence_unsupported|receipt"):
            command_apply_local_branch_closeout(ctx, {"RepoRoot": str(self.repo), "SetupLedgerJson": json.dumps({"merge_mode": "local-branch", "branch": "codex/fixture", "source_plan": "docs/superpowers/plans/plan.md"}), "PremergeResultJson": json.dumps({"ok": True}), "MergeDecisionJson": json.dumps({"selected_action": "merge"}), "DryRun": True})


if __name__ == "__main__":
    unittest.main()
