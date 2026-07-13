from __future__ import annotations

import json
import unittest
import contextlib
import io
from pathlib import Path

from scripts.lib.evidence_schema import EvidenceError, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_closeout import validate_closeout
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.command_support import Context
from scripts.lib.commands.gates import command_validate_resolve_terminal_closeout
from tests.execution_kernel_fixtures import envelope, make_repo, remove_repo, synthetic_merge_prior


class CloseoutGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(remove_repo, self.repo)

    def test_closeout_requires_prior_pr_ready_receipt(self):
        closeout = parse_envelope(envelope(self.repo, "closeout"), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_closeout(closeout, self.repo, None)

    def test_closeout_accepts_current_prior_receipt_and_emits_rules(self):
        prior = synthetic_merge_prior(self.repo)
        closeout = parse_envelope(envelope(self.repo, "closeout", prior_event_hash=prior.receipt_hash), self.repo)
        receipt = validate_closeout(closeout, self.repo, prior)
        self.assertEqual("closeout", receipt.gate)
        self.assertEqual("passed", receipt.disposition)
        self.assertTrue({rule.rule_id for rule in receipt.rules} >= {"integration_proof", "completion_state", "workspace_disposition", "cleanup_state"})

    def test_closeout_rejects_forged_prior_validator_and_bindings(self):
        pr_request = envelope(self.repo, "pr_ready")
        pr_envelope = parse_envelope(pr_request, self.repo)
        pr_receipt = validate_pr_ready(pr_envelope, self.repo)
        forged = __import__("dataclasses").replace(pr_receipt, validator_id="arbitrary-validator@999")
        forged = __import__("dataclasses").replace(forged, receipt_hash=hash_ref(forged.unsigned_dict()))
        closeout = parse_envelope(envelope(self.repo, "closeout", prior_event_hash=forged.receipt_hash), self.repo)
        with self.assertRaisesRegex(EvidenceError, "receipt"):
            validate_closeout(closeout, self.repo, forged)

    def test_closeout_rejects_stale_integration_head(self):
        prior = synthetic_merge_prior(self.repo)
        closeout = envelope(self.repo, "closeout", prior_event_hash=prior.receipt_hash)
        integration = next(item for item in closeout["evidence"] if item["kind"] == "integration_state")
        integration["payload"]["head"] = "stale-head"
        integration["payload_hash"] = hash_ref(integration["payload"])
        closeout["envelope_hash"] = build_envelope_hash(closeout)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            validate_closeout(parse_envelope(closeout, self.repo), self.repo, prior)

    def test_terminal_decision_is_bound_to_run_candidate_and_authorization(self):
        pr_receipt = validate_pr_ready(parse_envelope(envelope(self.repo, "pr_ready"), self.repo), self.repo)
        closeout = envelope(self.repo, "closeout", prior_event_hash=pr_receipt.receipt_hash)
        root = Path(__file__).parents[1]
        ctx = Context(root / "skills/resolve-issue/scripts/validate-terminal-closeout.sh", self.repo, "skills/resolve-issue/scripts/validate-terminal-closeout.sh", "validate-terminal-closeout.sh", [], root, self.repo)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = command_validate_resolve_terminal_closeout(ctx, {"RepoRoot": str(self.repo), "EvidenceEnvelopeJson": json.dumps(closeout), "PriorReceiptJson": json.dumps(pr_receipt.to_dict()), "ContinuationDecisionJson": json.dumps({"terminal_state": "done", "run_id": "run-1", "candidate_id": "wrong-candidate", "authorization_hash": hash_ref({"authorized": True})})})
        self.assertNotEqual(0, status)
        self.assertEqual("candidate_mismatch", json.loads(output.getvalue())["error"]["code"])


if __name__ == "__main__":
    unittest.main()
