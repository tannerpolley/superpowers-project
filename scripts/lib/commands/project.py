"""Project artifact and candidate command handlers."""
from __future__ import annotations

import json
from typing import Any

try:
    from ..command_support import Context, arg_value, emit, project_root_for, read_json_arg, read_text, resolve_under
    from ..workspace_isolation import resolve_workspace_isolation
except ImportError:
    from command_support import Context, arg_value, emit, project_root_for, read_json_arg, read_text, resolve_under
    from workspace_isolation import resolve_workspace_isolation


def command_select_candidate(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    inventory_arg = arg_value(args, "InventoryPath")
    candidates = []
    if inventory_arg:
        inventory = json.loads(read_text(resolve_under(root, str(inventory_arg), "InventoryPath")))
        candidates = inventory.get("candidates", inventory if isinstance(inventory, list) else [])
    selected = next((candidate for candidate in candidates if candidate.get("ready") is True), None) if isinstance(candidates, list) else None
    return emit({"ok": selected is not None, "phase": "select-candidate", "selected_candidate": selected, "reason": "candidate selected" if selected else "no ready candidates"}, 0 if selected else 1)


def command_workspace_isolation(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    request, _ = read_json_arg(root, args, "RequestJson", "RequestPath")
    capabilities, _ = read_json_arg(root, args, "CapabilitiesJson", "CapabilitiesPath")
    if not isinstance(request, dict) or not isinstance(capabilities, dict):
        raise ValueError("workspace isolation request and capabilities must be JSON objects")
    decision = resolve_workspace_isolation(request, capabilities)
    return emit({"ok": True, "phase": "workspace-isolation-decision", "untrusted_request": True, "decision": decision})


HANDLERS = {
    "command_select_candidate": command_select_candidate,
    "command_workspace_isolation": command_workspace_isolation,
}
