"""PR-ready fail-closed gate."""
from __future__ import annotations

from pathlib import Path

try:
    from .evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from .gate_common import authorization_rule, cleanup_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_evidence, require_gate, require_all_rules, review_rules, source_artifact_rule, workflow_binding_rule, workspace_rule
    from .gate_receipts import GateReceipt, build_receipt
except ImportError:  # pragma: no cover - CLI top-level import fallback
    from evidence_schema import EvidenceEnvelope, EvidenceError, RuleResult
    from gate_common import authorization_rule, cleanup_rule, command_rule, current_git_state, git_state_rule, identity_rules, require_evidence, require_gate, require_all_rules, review_rules, source_artifact_rule, workflow_binding_rule, workspace_rule
    from gate_receipts import GateReceipt, build_receipt


PR_READY_REQUIRED_KINDS = {"git_state", "artifact_hashes", "command_result", "review_result", "authorization_event", "cleanup_state"}


def validate_pr_ready(envelope: EvidenceEnvelope, repo_root: Path) -> GateReceipt:
    require_gate(envelope, "pr_ready")
    grouped = require_evidence(envelope, PR_READY_REQUIRED_KINDS)
    current = current_git_state(Path(repo_root).resolve())
    rules: list[RuleResult] = identity_rules(envelope, Path(repo_root).resolve())
    rules.extend([
        RuleResult("event_chain", envelope.prior_event_hash is None, "initial PR-ready event has no prior receipt" if envelope.prior_event_hash is None else "PR-ready cannot start from a prior event"),
        workflow_binding_rule(grouped, envelope),
        git_state_rule(grouped, Path(repo_root).resolve()),
        authorization_rule(grouped, envelope),
        source_artifact_rule(grouped, envelope),
        command_rule(grouped),
        *review_rules(grouped),
        workspace_rule(grouped, envelope),
        cleanup_rule(grouped),
    ])
    require_all_rules(rules)
    return build_receipt(envelope, "pr-ready-validator@1", {"head": current["head"], "branch": current["branch"], "status_exit_code": current["status_exit_code"]}, rules)
