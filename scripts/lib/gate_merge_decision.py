"""Fail-closed merge authorization consuming a current premerge receipt."""
from __future__ import annotations

from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from .gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule
    from .gate_premerge import _provider_rules
    from .gate_receipts import build_receipt, verify_receipt
except ImportError:  # pragma: no cover
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from gate_common import authorization_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_all_rules, require_evidence, source_artifact_rule, workflow_binding_rule
    from gate_premerge import _provider_rules
    from gate_receipts import build_receipt, verify_receipt


MERGE_DECISION_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "authorization_event", "github_state"}


def validate_merge_decision(envelope: EvidenceEnvelope, repo_root: Path, premerge_receipt) :
    if envelope.gate != "merge_decision":
        raise EvidenceError("schema_invalid", "envelope gate must be merge_decision")
    verify_receipt(premerge_receipt, envelope, "premerge", allow_transition=True)
    root = Path(repo_root).resolve()
    grouped = require_evidence(envelope, MERGE_DECISION_REQUIRED_KINDS)
    current = current_git_state(root)
    rules = identity_rules(envelope, root)
    rules.extend([
        RuleResult("event_chain", True, "current premerge receipt is consumed"),
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, root),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *_provider_rules(grouped, envelope, str(current["head"])),
    ])
    require_all_rules(rules)
    return build_receipt(envelope, "merge-decision-validator@1", {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"]}, rules)
