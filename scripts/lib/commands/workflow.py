"""Production workflow command handlers."""
from __future__ import annotations

import json
from typing import Any

try:
    from ..command_support import Context, ScriptError, arg_value, emit, project_path_for, project_root_for
    from ..workflow_runtime import execute_workflow_action
except ImportError:
    from command_support import Context, ScriptError, arg_value, emit, project_path_for, project_root_for
    from workflow_runtime import execute_workflow_action


def command_workflow_run(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    run_root_value = arg_value(args, "RunRoot")
    authorization_value = arg_value(args, "AuthorizationPath")
    action = str(arg_value(args, "Action", default=""))
    if not run_root_value or not authorization_value or not action:
        raise ScriptError("RunRoot, AuthorizationPath, and Action are required")
    receipt = execute_workflow_action(
        ctx.plugin_root or ctx.repo_root,
        root,
        project_path_for(root, str(run_root_value), "RunRoot"),
        project_path_for(root, str(authorization_value), "AuthorizationPath"),
        action,
        run_id=str(arg_value(args, "RunId", default="")),
        mode=str(arg_value(args, "Mode", default="")),
        candidate=str(arg_value(args, "Candidate", default="")),
        claim=str(arg_value(args, "Claim", default="")),
        reason=str(arg_value(args, "Reason", default="")),
        gate_id=str(arg_value(args, "GateId", default="")),
        options=json.loads(str(arg_value(args, "OptionsJson", default="[]"))),
        recommendation=str(arg_value(args, "Recommendation", default="")),
        selected_option=(str(arg_value(args, "SelectedOption")) if arg_value(args, "SelectedOption") is not None else None),
        authorized=str(arg_value(args, "Authorized", default="true")).lower() not in {"false", "0", "no"},
    )
    return emit(receipt)


HANDLERS = {"command_workflow_run": command_workflow_run}
