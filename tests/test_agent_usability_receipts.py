import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.lib.agent_usability import TrialReceiptError, validate_trial_receipt
from scripts.lib.package_provenance import runtime_contract_hash
from scripts.run_agent_usability_trials_support import summarize_observed_events


ROOT = Path(__file__).resolve().parents[1]


class AgentUsabilityReceiptTests(unittest.TestCase):
    def test_trial_metrics_are_derived_from_observed_events(self):
        events = [
            {"kind": "tool_call", "name": "worker"},
            {"kind": "tool_call", "name": "verifier"},
            {"kind": "external_mutation", "name": "provider-write"},
            {"kind": "receipt", "receipt_hash": "sha256:" + "a" * 64},
        ]
        self.assertEqual({"tool_calls": 2, "external_mutations": 1, "receipt_identities": ["sha256:" + "a" * 64]}, summarize_observed_events(events))

    def test_codex_output_schemas_are_strict_objects(self):
        def assert_strict(schema: dict) -> None:
            if schema.get("type") == "object":
                self.assertIs(schema.get("additionalProperties"), False)
                self.assertEqual(set(schema.get("properties", {})), set(schema.get("required", [])))
            for value in schema.values():
                if isinstance(value, dict):
                    assert_strict(value)
                elif isinstance(value, list):
                    for item in value:
                        if isinstance(item, dict):
                            assert_strict(item)

        for name in ("worker-output.schema.json", "verifier-output.schema.json"):
            assert_strict(json.loads((ROOT / "tests" / "workflow-trials" / name).read_text(encoding="utf-8")))

    def fixture(self, root: Path):
        project = root / "project"
        project.mkdir()
        result = project / "result.txt"
        result.write_text("complete\n", encoding="utf-8")
        return {
            "schema_version": 1,
            "trial_id": "trial-1",
            "scenario": "governed-core",
            "repetition": 1,
            "worker": {"id": "00000000-0000-4000-8000-000000000001"},
            "verifier": {"id": "00000000-0000-4000-8000-000000000002"},
            "package_hash": runtime_contract_hash(ROOT),
            "oracle_sha256": "a" * 64,
            "trial_root": str(root),
            "project_root": str(project),
            "expected_outcome": "pass",
            "observed_outcome": "pass",
            "friction": 2,
            "user_input_calls": 0,
            "external_mutations": 0,
            "repository_evidence": [{"path": "result.txt", "sha256": hashlib.sha256(result.read_bytes()).hexdigest()}],
            "worker_claim": {"summary": "complete"},
            "verifier_decision": "pass",
        }

    def test_valid_receipt_and_seven_adversarial_classes(self):
        with tempfile.TemporaryDirectory() as tmp:
            receipt = self.fixture(Path(tmp))
            validate_trial_receipt(receipt, ROOT)
            variants = []
            missing = copy.deepcopy(receipt); missing.pop("friction"); variants.append(missing)
            self_verified = copy.deepcopy(receipt); self_verified["verifier"]["id"] = receipt["worker"]["id"]; variants.append(self_verified)
            scope = copy.deepcopy(receipt); scope["project_root"] = "/tmp/outside"; variants.append(scope)
            stale = copy.deepcopy(receipt); stale["package_hash"] = "0" * 64; variants.append(stale)
            tampered = copy.deepcopy(receipt); tampered["repository_evidence"][0]["sha256"] = "0" * 64; variants.append(tampered)
            wrong_outcome = copy.deepcopy(receipt); wrong_outcome["observed_outcome"] = "blocked"; variants.append(wrong_outcome)
            invalid_oracle = copy.deepcopy(receipt); invalid_oracle["oracle_sha256"] = "short"; variants.append(invalid_oracle)
            for variant in variants:
                with self.assertRaises(TrialReceiptError):
                    validate_trial_receipt(variant, ROOT)


if __name__ == "__main__":
    unittest.main()
