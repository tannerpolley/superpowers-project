import unittest
from scripts.lib.workflow_policy import PolicyError, resolve_gate, validate_governance


class GovernancePolicyTests(unittest.TestCase):
    def test_auto_is_noninteractive_and_one_outcome(self):
        profile = validate_governance("auto", {"source": "trial-fixture", "candidate_scope": ["a"]}, noninteractive_trial=True)
        self.assertFalse(profile.interactive)

    def test_auto_accepts_the_real_startup_selection_provenance(self):
        profile = validate_governance("auto", {"source": "request_user_input", "candidate_scope": ["a"]})
        self.assertFalse(profile.interactive)

    def test_loop_rejects_multiple_candidates(self):
        with self.assertRaises(PolicyError):
            validate_governance("looping", {"source": "trial-fixture", "candidate_scope": ["a", "b"], "selected_candidates": ["a", "b"]}, noninteractive_trial=True)

    def test_auto_rejects_continuation(self):
        with self.assertRaises(PolicyError):
            validate_governance("auto", {"source": "trial-fixture", "candidate_scope": ["a"], "continuation_grant": True}, noninteractive_trial=True)

    def test_manual_asks_and_records_only_a_user_selection(self):
        profile = validate_governance("manual", {"source": "request_user_input", "candidate_scope": ["a"]})
        pending = resolve_gate(profile, "route", ["direct", "issue"], "direct")
        self.assertEqual("ask", pending.action)
        decided = resolve_gate(profile, "route", ["direct", "issue"], "direct", selected="issue")
        self.assertEqual(("decide", "issue", "user"), (decided.action, decided.selected_option, decided.source))

    def test_auto_and_loop_choose_the_safe_recommendation(self):
        for mode in ("auto", "looping"):
            with self.subTest(mode=mode):
                profile = validate_governance(
                    mode,
                    {"source": "trial-fixture", "candidate_scope": ["a"]},
                    noninteractive_trial=True,
                )
                decision = resolve_gate(profile, "route", ["direct", "issue"], "issue")
                self.assertEqual(("decide", "issue", "policy"), (decision.action, decision.selected_option, decision.source))

    def test_noninteractive_gate_rejects_caller_selection_and_blocks_unsafe_choice(self):
        profile = validate_governance(
            "auto",
            {"source": "trial-fixture", "candidate_scope": ["a"]},
            noninteractive_trial=True,
        )
        with self.assertRaises(PolicyError):
            resolve_gate(profile, "route", ["direct", "issue"], "direct", selected="issue")
        blocked = resolve_gate(profile, "route", ["direct", "issue"], "direct", authorized=False)
        self.assertEqual("block", blocked.action)


if __name__ == "__main__":
    unittest.main()
