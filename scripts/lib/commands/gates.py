"""Compatibility adapters for evidence collection and focused gates."""
from __future__ import annotations

import json
from typing import Any

try:
    from ..command_support import Context, ScriptError, arg_value, emit, project_path_for, project_root_for, read_json_arg, write_text
    from ..evidence_collectors import CollectionRequest, build_evidence_envelope
    from ..evidence_schema import EvidenceError, parse_envelope
    from ..gate_closeout import validate_closeout, validate_terminal_decision
    from ..gate_merge_decision import validate_merge_decision
    from ..gate_pr_ready import validate_pr_ready
    from ..gate_premerge import validate_premerge
    from ..gate_receipts import parse_receipt
except ImportError:  # pragma: no cover - direct module execution fallback
    from command_support import Context, ScriptError, arg_value, emit, project_path_for, project_root_for, read_json_arg, write_text
    from evidence_collectors import CollectionRequest, build_evidence_envelope
    from evidence_schema import EvidenceError, parse_envelope
    from gate_closeout import validate_closeout, validate_terminal_decision
    from gate_merge_decision import validate_merge_decision
    from gate_pr_ready import validate_pr_ready
    from gate_premerge import validate_premerge
    from gate_receipts import parse_receipt


def _error(phase: str, error: EvidenceError) -> int:
    payload: dict[str, object] = {
        "ok": False,
        "phase": phase,
        "error": {"code": error.code, "message": error.message},
    }
    if error.rule is not None:
        payload["error"]["rule"] = error.rule  # type: ignore[index]
    return emit(payload, 1)


def _collect(ctx: Context, args: dict[str, Any], expected_gate: str) -> int:
    root = project_root_for(ctx, args)
    phase = f"collect-{expected_gate}"
    try:
        data, _ = read_json_arg(root, args, "CollectionRequestJson", "CollectionRequestPath", required=False)
        if data is None:
            return _error(phase, EvidenceError("evidence_missing", "CollectionRequestJson or CollectionRequestPath is required"))
        request = CollectionRequest.from_mapping(data, root)
        if request.gate != expected_gate:
            raise EvidenceError("schema_invalid", f"collection request gate must be {expected_gate}")
        envelope = build_evidence_envelope(request)
        output_path = arg_value(args, "OutputPath")
        output_rel = ""
        if output_path:
            output = project_path_for(root, str(output_path), "OutputPath")
            write_text(output, json.dumps(envelope, indent=2, ensure_ascii=False) + "\n")
            output_rel = str(output.relative_to(root))
        return emit({"ok": True, "phase": phase, "evidence_envelope": envelope, "output_path": output_rel})
    except Exception as exc:
        return _error(phase, _normalize_error(exc))


def _normalize_error(error: Exception) -> EvidenceError:
    if isinstance(error, EvidenceError):
        return error
    message = str(error)
    code = "repository_mismatch" if "outside repo" in message or "escapes repository" in message else "schema_invalid"
    return EvidenceError(code, message)


def _load_envelope(ctx: Context, args: dict[str, Any], phase: str):
    root = project_root_for(ctx, args)
    data, _ = read_json_arg(root, args, "EvidenceEnvelopeJson", "EvidenceEnvelopePath", required=False)
    if data is None:
        raise EvidenceError("evidence_missing", "EvidenceEnvelopeJson or EvidenceEnvelopePath is required")
    return root, parse_envelope(data, root)


def command_validate_pr_ready(ctx: Context, args: dict[str, Any]) -> int:
    phase = "validate-pr-ready"
    try:
        root, envelope = _load_envelope(ctx, args, phase)
        receipt = validate_pr_ready(envelope, root)
        return emit({"ok": True, "phase": phase, "receipt": receipt.to_dict(), "receipt_hash": receipt.receipt_hash})
    except Exception as exc:
        return _error(phase, _normalize_error(exc))


def command_premerge(ctx: Context, args: dict[str, Any]) -> int:
    phase = "premerge"
    try:
        root, envelope = _load_envelope(ctx, args, phase)
        receipt = validate_premerge(envelope, root)
        return emit({"ok": True, "phase": phase, "receipt": receipt.to_dict(), "receipt_hash": receipt.receipt_hash})
    except Exception as exc:
        return _error(phase, _normalize_error(exc))


def _load_prior_receipt(root, args: dict[str, Any]):
    data, _ = read_json_arg(root, args, "PriorReceiptJson", "PriorReceiptPath", required=False)
    if data is None:
        raise EvidenceError("evidence_missing", "PriorReceiptJson or PriorReceiptPath is required")
    return parse_receipt(data)


def command_closeout(ctx: Context, args: dict[str, Any]) -> int:
    phase = "closeout"
    try:
        root, envelope = _load_envelope(ctx, args, phase)
        prior = _load_prior_receipt(root, args)
        receipt = validate_closeout(envelope, root, prior)
        return emit({"ok": True, "phase": phase, "receipt": receipt.to_dict(), "receipt_hash": receipt.receipt_hash})
    except Exception as exc:
        return _error(phase, _normalize_error(exc))


def command_validate_merge_decision(ctx: Context, args: dict[str, Any]) -> int:
    phase = "validate-merge-decision"
    try:
        root, envelope = _load_envelope(ctx, args, phase)
        prior = _load_prior_receipt(root, args)
        receipt = validate_merge_decision(envelope, root, prior)
        return emit({"ok": True, "phase": phase, "receipt": receipt.to_dict(), "receipt_hash": receipt.receipt_hash})
    except Exception as exc:
        return _error(phase, _normalize_error(exc))


def command_validate_resolve_terminal_closeout(ctx: Context, args: dict[str, Any]) -> int:
    phase = "validate-resolve-terminal-closeout"
    try:
        root, envelope = _load_envelope(ctx, args, phase)
        decision, _ = read_json_arg(root, args, "ContinuationDecisionJson", "ContinuationDecisionPath", required=False)
        if decision is None:
            raise EvidenceError("evidence_missing", "ContinuationDecisionJson or ContinuationDecisionPath is required")
        validate_terminal_decision(decision, envelope)
        prior = _load_prior_receipt(root, args)
        receipt = validate_closeout(envelope, root, prior)
        return emit({"ok": True, "phase": phase, "receipt": receipt.to_dict(), "receipt_hash": receipt.receipt_hash})
    except Exception as exc:
        return _error(phase, _normalize_error(exc))


def command_collect_pr_ready(ctx: Context, args: dict[str, Any]) -> int:
    return _collect(ctx, args, "pr_ready")


def command_collect_premerge(ctx: Context, args: dict[str, Any]) -> int:
    return _collect(ctx, args, "premerge")


def command_collect_closeout(ctx: Context, args: dict[str, Any]) -> int:
    return _collect(ctx, args, "closeout")


HANDLERS = {
    "command_collect_pr_ready": command_collect_pr_ready,
    "command_collect_premerge": command_collect_premerge,
    "command_collect_closeout": command_collect_closeout,
    "command_validate_pr_ready": command_validate_pr_ready,
    "command_premerge": command_premerge,
    "command_closeout": command_closeout,
    "command_validate_merge_decision": command_validate_merge_decision,
    "command_validate_resolve_terminal_closeout": command_validate_resolve_terminal_closeout,
}
