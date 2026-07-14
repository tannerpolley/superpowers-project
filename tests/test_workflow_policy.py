import unittest
from pathlib import Path

from scripts.lib.workflow_policy import CompletionError, PolicyError, load_governance_profiles, resolve_gate, validate_completion_claim, validate_governance
from scripts.lib.workflow_state import RunProjection


PROFILES = Path(__file__).resolve().parents[1] / "docs" / "superpowers" / "governance-profiles.yml"


def proven() -> RunProjection:
    return RunProjection(
        run_id="run",
        status="running",
        selected_candidate="one",
        accepted_candidates=["one"],
        verified_candidates=["one"],
    )


class GovernancePolicyTests(unittest.TestCase):
    def test_completion_claims_follow_profile_and_replayed_evidence(self):
        profiles = load_governance_profiles(PROFILES)
        self.assertEqual({"manual", "auto", "looping", "trial.local"}, set(profiles))
        self.assertEqual(("outcome",), profiles["auto"].completion_claims)

        projection = proven()
        validate_completion_claim(profiles["manual"], "candidate", projection, {})
        validate_completion_claim(profiles["auto"], "outcome", projection, {"candidate_scope": ["one"]})
        projection.verified_candidates.clear()
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["auto"], "outcome", projection, {"candidate_scope": ["one"]})

        projection = proven()
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["looping"], "iteration", projection, {})
        projection.budget_rechecks.append("one")
        projection.continuation_grants.append("one")
        validate_completion_claim(profiles["looping"], "iteration", projection, {})

        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["manual"], "project", projection, {})
        projection.project_health_verified = True
        validate_completion_claim(profiles["manual"], "project", projection, {})
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["auto"], "project", projection, {})

    def test_auto_is_noninteractive_and_one_outcome(self):
        profile = validate_governance("auto", {"source": "trial-fixture", "candidate_scope": ["a"]}, noninteractive_trial=True)
        self.assertFalse(profile.interactive)

    def test_auto_accepts_the_real_startup_selection_provenance(self):
        profile = validate_governance("auto", {"source": "request_user_input", "candidate_scope": ["a"]})
        self.assertFalse(profile.interactive)

    def test_loop_rejects_multiple_candidates(self):
        with self.assertRaises(PolicyError):
            validate_governance("looping", {"source": "trial-fixture", "candidate_scope": ["a", "b"], "selected_candidates": ["a", "b"]}, noninteractive_trial=True)

    def test_every_mode_requires_a_bounded_candidate_scope(self):
        for mode in ("manual", "auto", "looping"):
            for scope in ([], [""], ["same", "same"]):
                with self.subTest(mode=mode, scope=scope), self.assertRaises(PolicyError):
                    validate_governance(mode, {"source": "request_user_input", "candidate_scope": scope})

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
