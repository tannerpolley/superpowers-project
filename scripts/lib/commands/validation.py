"""Cross-surface validation command handlers."""
from __future__ import annotations

import json
from typing import Any

try:
    from ..agent_usability import validate_trial_receipt, validate_trial_set
    from ..command_support import Context, ScriptError, arg_value, emit, normalize_rel, project_path_for, project_root_for, read_text
    from ..package_provenance import runtime_contract_hash
except ImportError:
    from agent_usability import validate_trial_receipt, validate_trial_set
    from command_support import Context, ScriptError, arg_value, emit, normalize_rel, project_path_for, project_root_for, read_text
    from package_provenance import runtime_contract_hash


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
    receipt_paths = sorted(directory.glob("**/receipt.json"))
    receipts = [json.loads(read_text(path)) for path in receipt_paths]
    metrics = validate_trial_set(receipts, ctx.plugin_root or ctx.repo_root)
    index_path = directory / "receipt-index.json"
    if not index_path.is_file():
        raise ScriptError("agent trial receipt index is missing")
    index = json.loads(read_text(index_path))
    plugin_root = ctx.plugin_root or ctx.repo_root
    expected_paths = [normalize_rel(path, plugin_root) for path in receipt_paths]
    if index.get("package_hash") != runtime_contract_hash(plugin_root):
        raise ScriptError("agent trial receipt index package hash is stale")
    if index.get("receipts") != expected_paths:
        raise ScriptError("agent trial receipt index must contain sorted plugin-relative paths")
    return emit({"ok": True, "phase": "agent-usability-receipt", "receipt_count": len(receipts), "metrics": metrics})


HANDLERS = {"command_validate_agent_usability_receipt": command_validate_agent_usability_receipt}
