import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.lib.agent_usability import TrialReceiptError, validate_trial_receipt
from scripts.lib.package_provenance import runtime_contract_hash
from scripts.lib.workflow_state import append_event
from scripts.run_agent_usability_trials_support import summarize_observed_events


ROOT = Path(__file__).resolve().parents[1]


class AgentUsabilityReceiptTests(unittest.TestCase):
    def test_generated_trial_corpus_is_runtime_evidence_not_source(self):
        source_receipts = ROOT / "tests/workflow-trials/receipts/current"
        self.assertFalse((source_receipts / "receipt-index.json").exists())
        self.assertFalse(any(source_receipts.glob("**/receipt.json")))
        distribution = (ROOT / "scripts/lib/commands/distribution.py").read_text(encoding="utf-8")
        self.assertIn('.superpowers/runs/agent-trials/current', distribution)
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("--output-dir .superpowers/runs/agent-trials/current", readme)
        validator = (ROOT / "scripts/lib/superpowers_project_cli.py").read_text(encoding="utf-8")
        self.assertIn('root / ".superpowers" / "runs" / "agent-trials" / "current"', validator)

    def test_trial_metrics_are_derived_from_observed_events(self):
        events = [
            {"kind": "tool_call", "name": "worker"},
            {"kind": "tool_call", "name": "verifier"},
            {"kind": "external_mutation", "name": "provider-write"},
            {"kind": "receipt", "receipt_hash": "sha256:" + "a" * 64},
        ]
        self.assertEqual(
            {"tool_calls": 2, "external_mutations": 1, "receipt_identities": ["sha256:" + "a" * 64]},
            summarize_observed_events(events),
        )

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

    def test_verifier_prompt_distinguishes_route_outcome_from_verdict(self):
        runner = (ROOT / "scripts" / "run-agent-usability-trials.py").read_text(encoding="utf-8")
        self.assertIn("decision` field names the observed route outcome", runner)
        self.assertIn("otherwise use `reject`", runner)

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
            "worker": {"id": "00000000-0000-4000-8000-000000000001"},
            "verifier": {"id": "00000000-0000-4000-8000-000000000002"},
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
            self_verified = copy.deepcopy(receipt); self_verified["verifier"]["id"] = receipt["worker"]["id"]; variants.append(self_verified)
            scope = copy.deepcopy(receipt); scope["project_root"] = "/tmp/outside"; variants.append(scope)
            stale = copy.deepcopy(receipt); stale["package_hash"] = "0" * 64; variants.append(stale)
            tampered = copy.deepcopy(receipt); tampered["repository_evidence"][0]["sha256"] = "0" * 64; variants.append(tampered)
            for variant in variants:
                with self.assertRaises(TrialReceiptError):
                    validate_trial_receipt(variant, ROOT)


if __name__ == "__main__":
    unittest.main()
