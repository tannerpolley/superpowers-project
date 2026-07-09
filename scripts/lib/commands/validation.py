"""Cross-surface validation command handlers."""
from __future__ import annotations

import json
from typing import Any

try:
    from ..agent_usability import validate_trial_receipt, validate_trial_set
    from ..command_support import Context, ScriptError, arg_value, emit, normalize_rel, project_path_for, project_root_for, read_text
except ImportError:
    from agent_usability import validate_trial_receipt, validate_trial_set
    from command_support import Context, ScriptError, arg_value, emit, normalize_rel, project_path_for, project_root_for, read_text


def command_validate_agent_usability_receipt(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    receipt_path = arg_value(args, "ReceiptPath")
    receipt_dir = arg_value(args, "ReceiptDir")
    if bool(receipt_path) == bool(receipt_dir):
        raise ScriptError("provide exactly one of ReceiptPath or ReceiptDir")
    if receipt_path:
        path = project_path_for(root, str(receipt_path), "ReceiptPath")
        validate_trial_receipt(json.loads(read_text(path)), ctx.plugin_root or ctx.repo_root)
        return emit({"ok": True, "phase": "agent-usability-receipt", "receipt": normalize_rel(path, root)})
    directory = project_path_for(root, str(receipt_dir), "ReceiptDir")
    receipts = [json.loads(read_text(path)) for path in sorted(directory.glob("**/receipt.json"))]
    metrics = validate_trial_set(receipts, ctx.plugin_root or ctx.repo_root)
    return emit({"ok": True, "phase": "agent-usability-receipt", "receipt_count": len(receipts), "metrics": metrics})


HANDLERS = {"command_validate_agent_usability_receipt": command_validate_agent_usability_receipt}
