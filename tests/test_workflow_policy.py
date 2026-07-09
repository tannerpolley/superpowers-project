import unittest
from scripts.lib.workflow_policy import PolicyError, validate_governance


class GovernancePolicyTests(unittest.TestCase):
    def test_auto_is_noninteractive_and_one_route(self):
        profile = validate_governance("auto", {"source": "trial-fixture", "candidate_scope": ["a"]}, noninteractive_trial=True)
        self.assertFalse(profile.interactive)

    def test_loop_rejects_multiple_candidates(self):
        with self.assertRaises(PolicyError):
            validate_governance("looping", {"source": "trial-fixture", "candidate_scope": ["a", "b"], "selected_candidates": ["a", "b"]}, noninteractive_trial=True)

    def test_auto_rejects_continuation(self):
        with self.assertRaises(PolicyError):
            validate_governance("auto", {"source": "trial-fixture", "candidate_scope": ["a"], "continuation_grant": True}, noninteractive_trial=True)


if __name__ == "__main__":
    unittest.main()
