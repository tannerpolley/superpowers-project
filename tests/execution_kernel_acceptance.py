from __future__ import annotations

from pathlib import Path

import scripts.lib.gate_premerge as gate_premerge
from scripts.lib.evidence_schema import EvidenceError, build_envelope_hash, hash_ref, parse_envelope
from scripts.lib.gate_closeout import validate_closeout
from scripts.lib.gate_pr_ready import validate_pr_ready
from scripts.lib.gate_publish_ready import validate_publish_ready
from tests.execution_kernel_fixtures import envelope as local_envelope, remove_repo
from tests.test_gate_closeout import merge_prior, repo as make_closeout_repo, request as closeout_request
from tests.test_gate_merge_decision import MergeDecisionTests, envelope as provider_envelope, make_repo
from tests.test_gate_premerge import PremergeGateTests
from tests.test_gate_publish_ready import PublishReadyGateTests, release_envelope


def _rehash_item(data, item):
    item["payload_hash"] = hash_ref(item["payload"])
    data["envelope_hash"] = build_envelope_hash(data)


def execute_acceptance_row(row: dict[str, object]) -> EvidenceError:
    gate = str(row["gate"])
    mutation = str(row["mutation"])
    if gate == "pr_ready":
        root = make_closeout_repo()
        try:
            data = local_envelope(root, "pr_ready")
            if mutation == "empty_evidence":
                data["evidence"] = []
                data["envelope_hash"] = build_envelope_hash(data)
            elif mutation == "forged_success":
                item = data["evidence"][0]
                item["payload"]["ok"] = True
                _rehash_item(data, item)
            elif mutation == "unsupported_collector":
                data["evidence"][0]["collector"] = "unsupported@9"
                data["envelope_hash"] = build_envelope_hash(data)
            elif mutation == "tampered_payload":
                data["evidence"][0]["payload"]["head"] = "forged"
                data["envelope_hash"] = build_envelope_hash(data)
            elif mutation == "stale_source":
                (root / "docs/superpowers/plans/plan.md").write_text("changed\n", encoding="utf-8")
            elif mutation == "stale_head":
                (root / "changed.txt").write_text("changed\n", encoding="utf-8")
            elif mutation == "bad_authorization":
                item = next(item for item in data["evidence"] if item["kind"] == "authorization_event")
                item["payload"]["event"]["authorized"] = False
                _rehash_item(data, item)
            elif mutation == "incomplete_command":
                item = next(item for item in data["evidence"] if item["kind"] == "command_result")
                item["payload"] = {"exit_code": 0}
                _rehash_item(data, item)
            return _capture(lambda: validate_pr_ready(parse_envelope(data, root), root))
        finally:
            remove_repo(root)
    elif gate == "premerge":
        root = make_repo()
        try:
            helper = PremergeGateTests(); helper.repo = root
            data = provider_envelope(root, "premerge")
            provider = next(item for item in data["evidence"] if item["kind"] == "github_state")
            if mutation == "provider_unavailable": provider["payload"]["provider_available"] = False
            elif mutation == "failed_check": provider["payload"]["checks"][0]["conclusion"] = "failure"
            elif mutation == "base_mismatch": provider["payload"]["base_sha"] = "forged"
            elif mutation == "head_mismatch": provider["payload"]["head_sha"] = "forged"
            elif mutation == "blocking_review": provider["payload"]["review_decision"] = "CHANGES_REQUESTED"
            if mutation in {"provider_unavailable", "failed_check", "base_mismatch", "head_mismatch", "blocking_review"}:
                _rehash_item(data, provider)
                return _capture(lambda: helper.validate(data))
            authorization = {"authorized": True, "merge_strategy": "ff-only"}
            prior_data = local_envelope(root, "pr_ready", authorization=authorization)
            prior = validate_pr_ready(parse_envelope(prior_data, root), root)
            data["prior_event_hash"] = prior.receipt_hash
            data["workflow"]["run_id" if mutation == "cross_run" else "candidate_id"] = "cross-boundary"
            data["envelope_hash"] = build_envelope_hash(data)
            provider_payload = provider["payload"]
            from scripts.lib.evidence_collectors import CollectorResult
            from unittest.mock import patch
            fixture = CollectorResult("github_state", "github-state@1", "2026-07-10T12:00:00Z", provider_payload)
            with patch.object(gate_premerge, "collect_github_state", return_value=fixture):
                return _capture(lambda: gate_premerge.validate_premerge(parse_envelope(data, root), root, prior))
        finally:
            remove_repo(root)
    elif gate == "merge_decision":
        root = make_repo()
        try:
            helper = MergeDecisionTests(); helper.repo = root
            prior = helper.validate_premerge_fixture(provider_envelope(root, "premerge"))
            data = provider_envelope(root, "merge_decision", hash_ref({"forged": True}))
            return _capture(lambda: helper.validate_merge_fixture(data, prior))
        finally:
            remove_repo(root)
    elif gate == "closeout":
        root = make_closeout_repo()
        try:
            prior = merge_prior(root)
            data = closeout_request(root, "closeout", prior=prior.receipt_hash)
            item = next(item for item in data["evidence"] if item["kind"] == "integration_state")
            item["payload"]["head"] = "stale"
            _rehash_item(data, item)
            return _capture(lambda: validate_closeout(parse_envelope(data, root), root, prior))
        finally:
            remove_repo(root)
    else:
        helper = PublishReadyGateTests("test_publish_ready_accepts_current_package_installation_and_trial_proof")
        helper.setUp()
        try:
            data = release_envelope(helper.repo)
            if mutation == "failed_validation":
                item = next(item for item in data["evidence"] if item["kind"] == "command_result")
                item["payload"]["exit_code"] = 1; _rehash_item(data, item)
            elif mutation == "missing_installation":
                data["evidence"] = [item for item in data["evidence"] if item["kind"] != "installation_state"]
                data["envelope_hash"] = build_envelope_hash(data)
            else:
                (helper.repo / "dirty.txt").write_text("dirty\n", encoding="utf-8")
            return _capture(lambda: validate_publish_ready(parse_envelope(data, helper.repo), helper.repo))
        finally:
            helper.doCleanups()
    raise AssertionError(f"acceptance row unexpectedly passed: {row['id']}")


def _capture(callable_):
    try:
        callable_()
    except EvidenceError as error:
        return error
    raise AssertionError("acceptance mutation unexpectedly passed")
