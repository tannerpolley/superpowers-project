from __future__ import annotations

import json
import unittest
from pathlib import Path

from tests.execution_kernel_fixtures import git, make_repo, remove_repo, run_local_lifecycle, run_provider_lifecycle
from tests.execution_kernel_acceptance import execute_acceptance_row


ROOT = Path(__file__).resolve().parents[1]


class ExecutionKernelLifecycleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(remove_repo, self.repo)

    def test_lifecycle_receipts_match_independent_git_state(self):
        provider_repo, trace = run_provider_lifecycle()
        self.addCleanup(remove_repo, provider_repo)
        self.assertEqual(["pr_ready", "premerge", "merge_decision", "closeout"], [item["gate"] for item in trace])
        self.assertEqual(git(provider_repo, "rev-parse", "HEAD"), trace[-1]["observations"]["head"])
        for previous, current in zip(trace, trace[1:]):
            self.assertEqual(previous["receipt_hash"], current["prior_receipt_hash"])
        self.assertTrue(all(str(item["envelope_hash"]).startswith("sha256:") for item in trace))

    def test_acceptance_matrix_executes_every_adversarial_row(self):
        matrix = json.loads((ROOT / "tests/fixtures/execution-kernel/acceptance-matrix.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(matrix["rows"]), 20)
        for row in matrix["rows"]:
            with self.subTest(row=row["id"]):
                error = execute_acceptance_row(row)
                self.assertEqual(row["expected_error"], error.code)
                self.assertEqual(row["expected_rule"], error.rule)


if __name__ == "__main__":
    unittest.main()
