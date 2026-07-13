from __future__ import annotations

import dataclasses
import unittest
from unittest.mock import patch

import scripts.lib.gate_closeout as gate_closeout
import scripts.lib.gate_merge_decision as gate_merge_decision
import scripts.lib.gate_premerge as gate_premerge
import scripts.lib.gate_pr_ready as gate_pr_ready
import scripts.lib.gate_publish_ready as gate_publish_ready
from scripts.lib.evidence_schema import EvidenceError, hash_ref, parse_envelope
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.gate_receipts import REQUIRED_RECEIPT_RULES, verify_receipt
from scripts.lib.gate_common import evidence_by_kind, current_git_state
from tests import test_gate_publish_ready as publish_fixtures
from tests.execution_kernel_mutation_support import mutate_gate_rule
from tests.execution_kernel_fixtures import (
    envelope,
    make_provider_repo,
    make_repo,
    provider_envelope,
    remove_repo,
    synthetic_merge_prior,
    validate_provider_merge,
    validate_provider_premerge,
)


class ExecutionKernelMutationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = make_repo()
        self.addCleanup(remove_repo, self.repo)

    def test_every_required_pr_ready_rule_survives_receipt_authentication(self):
        parsed = parse_envelope(envelope(self.repo, "pr_ready"), self.repo)
        receipt = validate_pr_ready(parsed, self.repo)
        for removed in (rule.rule_id for rule in receipt.rules):
            with self.subTest(removed_rule=removed):
                mutated = dataclasses.replace(receipt, rules=tuple(rule for rule in receipt.rules if rule.rule_id != removed))
                mutated = dataclasses.replace(mutated, receipt_hash=hash_ref(mutated.unsigned_dict()))
                with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                    verify_receipt(mutated, parsed, "pr_ready")

    def test_every_gate_rejects_rule_deletion_and_inversion_in_actual_validator(self):
        merge_repo = make_provider_repo()
        self.addCleanup(remove_repo, merge_repo)
        publish_helper = publish_fixtures.PublishReadyGateTests("test_publish_ready_accepts_current_package_installation_and_trial_proof")
        publish_helper.setUp()
        self.addCleanup(publish_helper.doCleanups)

        pr_parsed = parse_envelope(envelope(self.repo, "pr_ready"), self.repo)
        authorization = {"authorized": True, "merge_strategy": "ff-only"}
        transition_pr = validate_pr_ready(parse_envelope(envelope(merge_repo, "pr_ready", authorization=authorization), merge_repo), merge_repo)
        pre_data = provider_envelope(merge_repo, "premerge", transition_pr.receipt_hash)
        pre_provider = next(item for item in pre_data["evidence"] if item["kind"] == "github_state")["payload"]
        pre_receipt = validate_provider_premerge(merge_repo, pre_data, transition_pr, pre_provider)
        merge_data = provider_envelope(merge_repo, "merge_decision", pre_receipt.receipt_hash)
        closeout_prior = synthetic_merge_prior(self.repo)
        closeout_parsed = parse_envelope(envelope(self.repo, "closeout", prior_event_hash=closeout_prior.receipt_hash), self.repo)
        publish_parsed = parse_envelope(publish_fixtures.release_envelope(publish_helper.repo), publish_helper.repo)
        publish_grouped = evidence_by_kind(publish_parsed)
        publish_head = str(current_git_state(publish_helper.repo)["head"])
        publish_release_rules = gate_publish_ready._release_rules(publish_grouped, publish_parsed, publish_helper.repo, publish_head)
        publish_fresh_rules = gate_publish_ready._fresh_observation_rules(publish_grouped, publish_parsed, publish_helper.repo)
        publish_package = gate_publish_ready._current_package(publish_helper.repo)

        def invoke(gate):
            if gate == "pr_ready":
                return gate_pr_ready.validate_pr_ready(pr_parsed, self.repo)
            if gate == "premerge":
                return validate_provider_premerge(merge_repo, pre_data, transition_pr, pre_provider)
            if gate == "merge_decision":
                return validate_provider_merge(merge_repo, merge_data, pre_receipt)
            if gate == "closeout":
                return gate_closeout.validate_closeout(closeout_parsed, self.repo, closeout_prior)
            with patch.object(gate_publish_ready, "_release_rules", return_value=publish_release_rules), patch.object(gate_publish_ready, "_fresh_observation_rules", return_value=publish_fresh_rules), patch.object(gate_publish_ready, "_current_package", return_value=publish_package):
                return gate_publish_ready.validate_publish_ready(publish_parsed, publish_helper.repo)

        modules = {"pr_ready": gate_pr_ready, "premerge": gate_premerge, "merge_decision": gate_merge_decision, "closeout": gate_closeout, "publish_ready": gate_publish_ready}
        for gate, required in REQUIRED_RECEIPT_RULES.items():
            for rule_id in required:
                for mutation in ("remove", "invert"):
                    with self.subTest(gate=gate, rule=rule_id, mutation=mutation):
                        with mutate_gate_rule(modules[gate], gate, rule_id, mutation):
                            with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
                                invoke(gate)


if __name__ == "__main__":
    unittest.main()
