from __future__ import annotations

import dataclasses
import unittest

from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.gate_receipts import verify_receipt
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


if __name__ == "__main__":
    unittest.main()
