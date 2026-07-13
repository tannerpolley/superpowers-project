from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

from scripts.lib.command_support import Context
from scripts.lib.evidence_schema import EvidenceError, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_merge_decision import validate_merge_decision
from tests.execution_kernel_fixtures import (
    git,
    make_provider_repo,
    provider_envelope,
    remove_repo,
    validate_provider_merge,
    validate_provider_premerge,
)
sys.path.insert(0, str(Path(__file__).parents[1] / "scripts" / "lib"))
from scripts.lib.superpowers_project_cli import command_apply_local_branch_closeout


class MergeDecisionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_provider_repo()
        self.addCleanup(remove_repo, self.repo)

    def test_merge_decision_requires_current_premerge_receipt(self):
        decision = parse_envelope(provider_envelope(self.repo, "merge_decision"), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_merge_decision(decision, self.repo, None)

    def test_merge_decision_accepts_matching_premerge_receipt(self):
        premerge = validate_provider_premerge(self.repo, provider_envelope(self.repo, "premerge"))
        receipt = validate_provider_merge(self.repo, provider_envelope(self.repo, "merge_decision", premerge.receipt_hash), premerge)
        self.assertEqual("merge_decision", receipt.gate)
        self.assertEqual("passed", receipt.disposition)

    def test_merge_decision_rejects_stale_premerge_head(self):
        premerge = validate_provider_premerge(self.repo, provider_envelope(self.repo, "premerge"))
        (self.repo / "changed-after-premerge.txt").write_text("changed\n", encoding="utf-8")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "changed after premerge")
        with self.assertRaisesRegex(EvidenceError, "stale"):
            validate_provider_merge(self.repo, provider_envelope(self.repo, "merge_decision", premerge.receipt_hash), premerge)

    def test_merge_decision_rejects_missing_authorization_strategy(self):
        premerge = validate_provider_premerge(self.repo, provider_envelope(self.repo, "premerge"))
        data = provider_envelope(self.repo, "merge_decision", premerge.receipt_hash)
        authorization = next(item for item in data["evidence"] if item["kind"] == "authorization_event")
        authorization["payload"]["event"].pop("merge_strategy")
        authorization["payload_hash"] = hash_ref(authorization["payload"])
        data["envelope_hash"] = build_envelope_hash(data)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_provider_merge(self.repo, data, premerge)

    def test_merge_strategy_must_match_target_in_both_directions(self):
        for target_strategy, authorization_strategy in (("ff-only", "squash"), ("squash", "ff-only")):
            with self.subTest(target_strategy=target_strategy, authorization_strategy=authorization_strategy):
                data = provider_envelope(self.repo, "premerge", target_strategy=target_strategy, authorization_strategy=authorization_strategy)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    validate_provider_premerge(self.repo, data)

    def test_local_merge_rejects_bare_success_object(self):
        ctx = Context(Path(__file__).parents[1] / "skills/merge-changes/scripts/apply-local-branch-closeout.sh", self.repo, "skills/merge-changes/scripts/apply-local-branch-closeout.sh", "apply-local-branch-closeout.sh", [], Path(__file__).parents[1], self.repo)
        with self.assertRaisesRegex(Exception, "legacy_evidence_unsupported|receipt"):
            command_apply_local_branch_closeout(ctx, {"RepoRoot": str(self.repo), "SetupLedgerJson": json.dumps({"merge_mode": "local-branch", "branch": "codex/fixture", "source_plan": "docs/superpowers/plans/plan.md"}), "PremergeResultJson": json.dumps({"ok": True}), "MergeDecisionJson": json.dumps({"selected_action": "merge"}), "DryRun": True})


if __name__ == "__main__":
    unittest.main()
