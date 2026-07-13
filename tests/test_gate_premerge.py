from __future__ import annotations

import unittest

from scripts.lib.evidence_schema import EvidenceError, build_envelope_hash, hash_ref
from tests.execution_kernel_fixtures import git, make_provider_repo, provider_envelope, remove_repo, validate_provider_premerge


class PremergeGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_provider_repo()
        self.addCleanup(remove_repo, self.repo)

    def validate(self, data, fresh_provider=None):
        return validate_provider_premerge(self.repo, data, fresh_provider=fresh_provider)

    def test_premerge_rejects_nonpassing_or_unavailable_provider(self):
        for conclusion in ("queued", "pending", "in_progress", "failure", "cancelled", "timed_out"):
            with self.subTest(conclusion=conclusion):
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    self.validate(provider_envelope(self.repo, "premerge", conclusion=conclusion))
        with self.assertRaisesRegex(EvidenceError, "provider"):
            self.validate(provider_envelope(self.repo, "premerge", available=False))

    def test_premerge_rejects_unapproved_authorization_snapshot(self):
        data = provider_envelope(self.repo, "premerge")
        authorization = next(item for item in data["evidence"] if item["kind"] == "authorization_event")
        authorization["payload"]["event"]["authorized"] = False
        authorization["payload_hash"] = hash_ref(authorization["payload"])
        data["envelope_hash"] = build_envelope_hash(data)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            self.validate(data)

    def test_premerge_rejects_stale_provider_observation_hash(self):
        data = provider_envelope(self.repo, "premerge")
        fresh_provider = dict(next(item for item in data["evidence"] if item["kind"] == "github_state")["payload"])
        provider = next(item for item in data["evidence"] if item["kind"] == "github_state")
        provider["payload"]["observation_hash"] = hash_ref({"forged": True})
        provider["payload_hash"] = hash_ref(provider["payload"])
        data["envelope_hash"] = build_envelope_hash(data)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            self.validate(data, fresh_provider)

    def test_premerge_rejects_base_sha_mismatch(self):
        data = provider_envelope(self.repo, "premerge")
        provider = next(item for item in data["evidence"] if item["kind"] == "github_state")
        provider["payload"]["base_sha"] = "forged-base"
        provider["payload_hash"] = hash_ref(provider["payload"])
        data["envelope_hash"] = build_envelope_hash(data)
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            self.validate(data)

    def test_premerge_rejects_blocking_provider_review(self):
        for decision in ("CHANGES_REQUESTED", "REVIEW_REQUIRED"):
            with self.subTest(decision=decision):
                data = provider_envelope(self.repo, "premerge")
                provider = next(item for item in data["evidence"] if item["kind"] == "github_state")
                provider["payload"]["review_decision"] = decision
                provider["payload_hash"] = hash_ref(provider["payload"])
                data["envelope_hash"] = build_envelope_hash(data)
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    self.validate(data)

    def test_premerge_rejects_changed_head_and_accepts_current_proof(self):
        collected = provider_envelope(self.repo, "premerge")
        receipt = self.validate(collected)
        self.assertEqual("passed", receipt.disposition)
        (self.repo / "changed.txt").write_text("changed\n", encoding="utf-8")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "changed")
        with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
            self.validate(collected)


if __name__ == "__main__":
    unittest.main()
