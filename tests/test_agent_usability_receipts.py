import copy
import json
import tempfile
import unittest
from pathlib import Path

from scripts.lib.agent_usability import TrialReceiptError, validate_trial_receipt
from scripts.lib.package_provenance import runtime_contract_hash
from scripts.lib.workflow_state import append_event


ROOT = Path(__file__).resolve().parents[1]


class AgentUsabilityReceiptTests(unittest.TestCase):
    def fixture(self, root: Path):
        project = root / "project"
        run = project / ".superpowers" / "runs" / "trial"
        project.mkdir(parents=True)
        append_event(run, {"type": "run_started", "run_id": "trial"})
        last = json.loads((run / "events.jsonl").read_text().splitlines()[-1])
        return {
            "schema_version": 1,
            "trial_id": "trial-1",
            "scenario": "auto-golden",
            "repetition": 1,
            "worker": {"id": "worker-1"},
            "verifier": {"id": "verifier-1"},
            "package_hash": runtime_contract_hash(ROOT),
            "trial_root": str(root),
            "project_root": str(project),
            "expected_outcome": "pass",
            "observed_outcome": "pass",
            "friction": 2,
            "user_input_calls": 0,
            "external_mutations": 0,
            "repository_evidence": [{"path": "result.txt", "sha256": "fixture"}],
            "event_ledger": {"path": str(run / "events.jsonl"), "last_hash": last["hash"]},
            "worker_claim": {"result": "complete"},
            "verifier_decision": "pass",
        }

    def test_valid_receipt_and_four_adversarial_classes(self):
        with tempfile.TemporaryDirectory() as tmp:
            receipt = self.fixture(Path(tmp))
            validate_trial_receipt(receipt, ROOT)
            variants = []
            missing = copy.deepcopy(receipt); missing.pop("friction"); variants.append(missing)
            self_verified = copy.deepcopy(receipt); self_verified["verifier"]["id"] = "worker-1"; variants.append(self_verified)
            scope = copy.deepcopy(receipt); scope["project_root"] = "/tmp/outside"; variants.append(scope)
            stale = copy.deepcopy(receipt); stale["package_hash"] = "0" * 64; variants.append(stale)
            for variant in variants:
                with self.assertRaises(TrialReceiptError):
                    validate_trial_receipt(variant, ROOT)


if __name__ == "__main__":
    unittest.main()
