"""Terminal closeout gate bound to a current prior receipt."""
from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, canonical_json
    from .gate_common import authorization_rule, cleanup_rule, command_rule, current_git_state, finalize_gate_rules, git_state_rule, identity_rules, require_evidence, require_gate, source_artifact_rule, workflow_binding_rule, workspace_rule
    from .gate_receipts import GateReceipt, build_receipt, parse_receipt, verify_transition_receipt
except ImportError:  # pragma: no cover - CLI top-level import fallback
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, canonical_json
    from gate_common import authorization_rule, cleanup_rule, command_rule, current_git_state, finalize_gate_rules, git_state_rule, identity_rules, require_evidence, require_gate, source_artifact_rule, workflow_binding_rule, workspace_rule
    from gate_receipts import GateReceipt, build_receipt, parse_receipt, verify_transition_receipt


CLOSEOUT_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "authorization_event", "cleanup_state", "integration_state"}


def validate_terminal_decision(decision: Mapping[str, object], envelope: EvidenceEnvelope) -> None:
    required = {"terminal_state", "run_id", "candidate_id", "authorization_hash"}
    if set(decision) != required:
        raise EvidenceError("schema_invalid", "terminal decision must bind terminal state and workflow identity")
    if decision["terminal_state"] not in {"stop", "done"}:
        raise EvidenceError("schema_invalid", "terminal decision must be stop or done")
    if decision["run_id"] != envelope.workflow["run_id"]:
        raise EvidenceError("candidate_mismatch", "terminal decision run_id does not match envelope")
    if decision["candidate_id"] != envelope.workflow["candidate_id"]:
        raise EvidenceError("candidate_mismatch", "terminal decision candidate_id does not match envelope")
    if decision["authorization_hash"] != envelope.workflow["authorization_hash"]:
        raise EvidenceError("authorization_mismatch", "terminal decision authorization does not match envelope")


def _prior_receipt_rule(envelope: EvidenceEnvelope, prior_receipt: GateReceipt | Mapping[str, object] | None) -> RuleResult:
    if prior_receipt is None:
        raise EvidenceError("receipt_stale", "a current merge-decision receipt is required", "event_chain")
    if isinstance(prior_receipt, Mapping):
        prior_receipt = parse_receipt(prior_receipt)
    verify_transition_receipt(prior_receipt, envelope, "merge_decision")
    return RuleResult("event_chain", True, "current merge-decision receipt is bound to closeout")


def _integration_rules(grouped: Mapping[str, list[object]], current_head: object) -> tuple[RuleResult, RuleResult]:
    payload = grouped.get("integration_state", [None])[0]
    integrated = isinstance(payload, Mapping) and payload.get("integrated") is True
    head = isinstance(payload, Mapping) and payload.get("head") == current_head
    return (
        RuleResult("integration_proof", integrated and head, "integration proof matches current HEAD" if integrated and head else "integration proof is incomplete or stale"),
        RuleResult("completion_state", integrated, "completion state is observed" if integrated else "completion state is incomplete"),
    )


def validate_closeout(envelope: EvidenceEnvelope, repo_root: Path, prior_receipt: GateReceipt | Mapping[str, object] | None) -> GateReceipt:
    require_gate(envelope, "closeout")
    grouped = require_evidence(envelope, CLOSEOUT_REQUIRED_KINDS)
    current = current_git_state(Path(repo_root).resolve())
    rules: list[RuleResult] = identity_rules(envelope, Path(repo_root).resolve())
    rules.extend([
        _prior_receipt_rule(envelope, prior_receipt),
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, Path(repo_root).resolve()),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *_integration_rules(grouped, current["head"]),
        replace(workspace_rule(grouped, envelope), rule_id="workspace_disposition"),
        cleanup_rule(grouped, Path(repo_root).resolve(), envelope.target.get("cleanup_actor")),
    ])
    finalize_gate_rules("closeout", rules)
    return build_receipt(envelope, "closeout-validator@1", {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"]}, rules)
