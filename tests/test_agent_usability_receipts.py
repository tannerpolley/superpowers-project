import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.lib.agent_usability import TrialReceiptError, validate_trial_receipt
from scripts.lib.package_provenance import runtime_contract_hash
from scripts.lib.workflow_state import append_event


ROOT = Path(__file__).resolve().parents[1]


class AgentUsabilityReceiptTests(unittest.TestCase):
    def test_codex_output_schemas_are_strict_objects(self):
        schemas = [
            ROOT / "tests" / "workflow-trials" / "worker-output.schema.json",
            ROOT / "tests" / "workflow-trials" / "verifier-output.schema.json",
        ]

        def assert_strict_objects(schema: dict) -> None:
            if schema.get("type") == "object":
                self.assertIs(schema.get("additionalProperties"), False)
                self.assertEqual(set(schema.get("properties", {})), set(schema.get("required", [])))
            for value in schema.values():
                if isinstance(value, dict):
                    assert_strict_objects(value)
                elif isinstance(value, list):
                    for item in value:
                        if isinstance(item, dict):
                            assert_strict_objects(item)

        for path in schemas:
            assert_strict_objects(json.loads(path.read_text(encoding="utf-8")))

    def fixture(self, root: Path):
        project = root / "project"
        run = project / ".superpowers" / "runs" / "trial"
        project.mkdir(parents=True)
        result = project / "result.txt"
        result.write_text("complete\n", encoding="utf-8")
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
            "repository_evidence": [{"path": "result.txt", "sha256": hashlib.sha256(result.read_bytes()).hexdigest()}],
            "event_ledger": {"path": str(run / "events.jsonl"), "last_hash": last["hash"]},
            "worker_claim": {"result": "complete"},
            "verifier_decision": "pass",
        }

    def test_valid_receipt_and_five_adversarial_classes(self):
        with tempfile.TemporaryDirectory() as tmp:
            receipt = self.fixture(Path(tmp))
            validate_trial_receipt(receipt, ROOT)
            variants = []
            missing = copy.deepcopy(receipt); missing.pop("friction"); variants.append(missing)
            self_verified = copy.deepcopy(receipt); self_verified["verifier"]["id"] = "worker-1"; variants.append(self_verified)
            scope = copy.deepcopy(receipt); scope["project_root"] = "/tmp/outside"; variants.append(scope)
            stale = copy.deepcopy(receipt); stale["package_hash"] = "0" * 64; variants.append(stale)
            tampered = copy.deepcopy(receipt); tampered["repository_evidence"][0]["sha256"] = "0" * 64; variants.append(tampered)
            for variant in variants:
                with self.assertRaises(TrialReceiptError):
                    validate_trial_receipt(variant, ROOT)


if __name__ == "__main__":
    unittest.main()
