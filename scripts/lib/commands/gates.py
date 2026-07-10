"""Compatibility adapters for evidence collection and focused gates."""
from __future__ import annotations

import json
from typing import Any

try:
    from ..command_support import Context, arg_value, emit, project_path_for, project_root_for, read_json_arg, write_text
    from ..evidence_collectors import CollectionRequest, build_evidence_envelope
    from ..evidence_schema import EvidenceError
except ImportError:  # pragma: no cover - direct module execution fallback
    from command_support import Context, arg_value, emit, project_path_for, project_root_for, read_json_arg, write_text
    from evidence_collectors import CollectionRequest, build_evidence_envelope
    from evidence_schema import EvidenceError


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
    except EvidenceError as exc:
        return _error(phase, exc)


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
}
