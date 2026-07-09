import unittest
from pathlib import Path

from scripts.lib.workflow_completion import CompletionError, allowed_completion_claims, load_profiles, validate_completion_claim
from scripts.lib.workflow_state import RunProjection


ROOT = Path(__file__).resolve().parents[1]
PROFILES = ROOT / "docs" / "superpowers" / "governance-profiles.yml"


def proven() -> RunProjection:
    return RunProjection(
        run_id="run",
        status="running",
        selected_candidate="one",
        accepted_candidates=["one"],
        verified_candidates=["one"],
    )


class WorkflowCompletionTests(unittest.TestCase):
    def test_four_profiles_load_with_explicit_claims(self):
        profiles = load_profiles(PROFILES)
        self.assertEqual({"manual", "auto", "looping", "trial.local"}, set(profiles))
        self.assertEqual({"candidate", "route"}, allowed_completion_claims(profiles["auto"]))

    def test_candidate_and_auto_route_accept_proof_and_reject_missing_verifier(self):
        profiles = load_profiles(PROFILES)
        projection = proven()
        validate_completion_claim(profiles["manual"], "candidate", projection, {})
        validate_completion_claim(profiles["auto"], "route", projection, {"candidate_scope": ["one"]})
        projection.verified_candidates.clear()
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["auto"], "route", projection, {"candidate_scope": ["one"]})

    def test_loop_iteration_requires_budget_and_continuation(self):
        profiles = load_profiles(PROFILES)
        projection = proven()
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["looping"], "iteration", projection, {})
        projection.budget_rechecks.append("one")
        projection.continuation_grants.append("one")
        validate_completion_claim(profiles["looping"], "iteration", projection, {})

    def test_project_claim_requires_project_health_and_is_forbidden_in_auto(self):
        profiles = load_profiles(PROFILES)
        projection = proven()
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["manual"], "project", projection, {})
        projection.project_health_verified = True
        validate_completion_claim(profiles["manual"], "project", projection, {})
        with self.assertRaises(CompletionError):
            validate_completion_claim(profiles["auto"], "project", projection, {})


if __name__ == "__main__":
    unittest.main()
