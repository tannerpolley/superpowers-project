"""Terminal closeout gate bound to a current prior receipt."""
from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Mapping

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, canonical_json
    from .gate_common import authorization_rule, cleanup_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_evidence, require_gate, require_all_rules, source_artifact_rule, workflow_binding_rule, workspace_rule
    from .gate_receipts import GateReceipt, build_receipt, parse_receipt
except ImportError:  # pragma: no cover - CLI top-level import fallback
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult, canonical_json
    from gate_common import authorization_rule, cleanup_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_evidence, require_gate, require_all_rules, source_artifact_rule, workflow_binding_rule, workspace_rule
    from gate_receipts import GateReceipt, build_receipt, parse_receipt


CLOSEOUT_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "authorization_event", "cleanup_state", "integration_state"}


def _prior_receipt_rule(envelope: EvidenceEnvelope, prior_receipt: GateReceipt | Mapping[str, object] | None) -> RuleResult:
    if prior_receipt is None:
        raise EvidenceError("receipt_stale", "a current PR-ready receipt is required", "event_chain")
    if isinstance(prior_receipt, Mapping):
        prior_receipt = parse_receipt(prior_receipt)
    if prior_receipt.gate != "pr_ready" or prior_receipt.disposition != "passed":
        raise EvidenceError("receipt_stale", "prior receipt is not a passing PR-ready receipt", "event_chain")
    if envelope.prior_event_hash != prior_receipt.receipt_hash:
        raise EvidenceError("receipt_stale", "closeout prior event does not match the PR-ready receipt", "event_chain")
    workflow = prior_receipt.bindings.get("workflow") if isinstance(prior_receipt.bindings, Mapping) else None
    if not isinstance(workflow, Mapping) or workflow.get("run_id") != envelope.workflow.get("run_id") or workflow.get("candidate_id") != envelope.workflow.get("candidate_id"):
        raise EvidenceError("candidate_mismatch", "prior receipt workflow identity does not match closeout", "event_chain")
    return RuleResult("event_chain", True, "current PR-ready receipt is bound to closeout")


def _integration_rules(grouped: Mapping[str, list[object]]) -> tuple[RuleResult, RuleResult]:
    payload = grouped.get("integration_state", [None])[0]
    integrated = isinstance(payload, Mapping) and payload.get("integrated") is True
    head = isinstance(payload, Mapping) and bool(payload.get("head"))
    return (
        RuleResult("integration_proof", integrated and head, "integration proof is observed" if integrated and head else "integration proof is incomplete"),
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
        *_integration_rules(grouped),
        replace(workspace_rule(grouped, envelope), rule_id="workspace_disposition"),
        cleanup_rule(grouped),
    ])
    require_all_rules(rules)
    return build_receipt(envelope, "closeout-validator@1", {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"]}, rules)
