import unittest

from tests.execution_kernel_fixtures import git, remove_repo, run_provider_lifecycle


class ExecutionKernelLifecycleTests(unittest.TestCase):
    def test_lifecycle_receipts_match_independent_git_state(self):
        provider_repo, trace = run_provider_lifecycle()
        self.addCleanup(remove_repo, provider_repo)
        self.assertEqual(["pr_ready", "premerge", "merge_decision", "closeout"], [item["gate"] for item in trace])
        self.assertEqual(git(provider_repo, "rev-parse", "HEAD"), trace[-1]["observations"]["head"])
        for previous, current in zip(trace, trace[1:]):
            self.assertEqual(previous["receipt_hash"], current["prior_receipt_hash"])
        self.assertTrue(all(str(item["envelope_hash"]).startswith("sha256:") for item in trace))

if __name__ == "__main__":
    unittest.main()
