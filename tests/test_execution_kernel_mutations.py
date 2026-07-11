from __future__ import annotations

import dataclasses
import unittest

from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.evidence_schema import RuleResult
from scripts.lib.gate_receipts import EXPECTED_VALIDATORS, REQUIRED_RECEIPT_RULES, build_receipt, verify_receipt
from tests.execution_kernel_fixtures import envelope, make_repo, remove_repo


class ExecutionKernelMutationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(remove_repo, self.repo)

    def test_every_required_pr_ready_rule_survives_receipt_authentication(self):
        parsed = parse_envelope(envelope(self.repo, "pr_ready"), self.repo)
        receipt = validate_pr_ready(parsed, self.repo)
        for removed in (rule.rule_id for rule in receipt.rules):
            with self.subTest(removed_rule=removed):
                mutated = dataclasses.replace(receipt, rules=tuple(rule for rule in receipt.rules if rule.rule_id != removed))
                mutated = dataclasses.replace(mutated, receipt_hash=hash_ref(mutated.unsigned_dict()))
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    verify_receipt(mutated, parsed, "pr_ready")

    def test_every_gate_rejects_each_removed_required_rule(self):
        base = parse_envelope(envelope(self.repo, "pr_ready"), self.repo)
        for gate, required in REQUIRED_RECEIPT_RULES.items():
            gate_envelope = dataclasses.replace(base, gate=gate)
            complete = [RuleResult(rule_id, True, "observed") for rule_id in sorted(required)]
            receipt = build_receipt(gate_envelope, EXPECTED_VALIDATORS[gate], {}, complete)
            for removed in required:
                with self.subTest(gate=gate, removed_rule=removed):
                    mutated = dataclasses.replace(receipt, rules=tuple(rule for rule in receipt.rules if rule.rule_id != removed))
                    mutated = dataclasses.replace(mutated, receipt_hash=hash_ref(mutated.unsigned_dict()))
                    with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                        verify_receipt(mutated, gate_envelope, gate)


if __name__ == "__main__":
    unittest.main()
