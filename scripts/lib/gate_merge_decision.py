"""Fail-closed merge authorization consuming a current premerge receipt."""
from __future__ import annotations

from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from .gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule
    from .gate_premerge import _provider_rules
    from .gate_receipts import build_receipt, parse_receipt, verify_receipt
except ImportError:  # pragma: no cover
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule
    from gate_premerge import _provider_rules
    from gate_receipts import build_receipt, parse_receipt, verify_receipt


MERGE_DECISION_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "authorization_event", "github_state"}


def validate_merge_decision(envelope: EvidenceEnvelope, repo_root: Path, premerge_receipt) :
    if envelope.gate != "merge_decision":
        raise EvidenceError("schema_invalid", "envelope gate must be merge_decision")
    root = Path(repo_root).resolve()
    current = current_git_state(root)
    if isinstance(premerge_receipt, Mapping):
        premerge_receipt = parse_receipt(premerge_receipt)
    verify_receipt(premerge_receipt, envelope, "premerge", allow_transition=True)
    if premerge_receipt.observations.get("head") != current["head"] or premerge_receipt.observations.get("branch") != current["branch"]:
        raise EvidenceError("receipt_stale", "premerge receipt Git state is stale")
    grouped = require_evidence(envelope, MERGE_DECISION_REQUIRED_KINDS)
    provider = grouped.get("github_state", [None])[0]
    if premerge_receipt.observations.get("provider_observation_hash") != (provider.get("observation_hash") if isinstance(provider, Mapping) else None):
        raise EvidenceError("receipt_stale", "premerge provider observation is stale")
    rules = identity_rules(envelope, root, check_target_branch=False)
    rules.extend([
        RuleResult("event_chain", True, "current premerge receipt is consumed"),
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, root),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *_provider_rules(grouped, envelope, str(current["head"]), str(current["branch"]), root),
    ])
    require_all_rules(rules)
    observations = {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"], "provider_observation_hash": provider.get("observation_hash") if isinstance(provider, Mapping) else None, "source_branch": provider.get("source_branch") if isinstance(provider, Mapping) else None, "source_head": provider.get("source_sha") if isinstance(provider, Mapping) else None, "base_sha": provider.get("base_sha") if isinstance(provider, Mapping) else None, "strategy": provider.get("strategy") if isinstance(provider, Mapping) else None, "source_plan_hash": envelope.source["plan_hash"]}
    return build_receipt(envelope, "merge-decision-validator@1", observations, rules)
