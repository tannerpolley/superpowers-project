from __future__ import annotations

import json
import unittest
from pathlib import Path

from tests.execution_kernel_fixtures import git, make_repo, remove_repo, run_local_lifecycle


ROOT = Path(__file__).resolve().parents[1]


class ExecutionKernelLifecycleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(remove_repo, self.repo)

    def test_lifecycle_receipts_match_independent_git_state(self):
        trace = run_local_lifecycle(self.repo)
        self.assertEqual(["pr_ready", "closeout"], [item["gate"] for item in trace])
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), trace[-1]["observations"]["head"])
        self.assertEqual(trace[0]["receipt_hash"], trace[1]["prior_receipt_hash"])
        self.assertTrue(all(str(item["envelope_hash"]).startswith("sha256:") for item in trace))

    def test_acceptance_matrix_names_existing_behavioral_tests(self):
        matrix = json.loads((ROOT / "tests/fixtures/execution-kernel/acceptance-matrix.json").read_text(encoding="utf-8"))
        discovered = {path.stem: path.read_text(encoding="utf-8") for path in ROOT.glob("tests/test_*.py")}
        self.assertGreaterEqual(len(matrix["rows"]), 12)
        for row in matrix["rows"]:
            with self.subTest(row=row["id"]):
                self.assertIn(row["test_module"], discovered)
                self.assertIn(f"def {row['test_name']}", discovered[row["test_module"]])
                self.assertIn(row["expected_error"], {"schema_invalid", "evidence_missing", "artifact_hash_mismatch", "collector_untrusted", "required_rule_failed", "receipt_stale", "provider_unavailable"})


if __name__ == "__main__":
    unittest.main()
