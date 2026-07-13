"""Workspace-provider policy; provider observations remain execution-kernel evidence."""
from __future__ import annotations

from collections.abc import Mapping
import re
from typing import Any


class WorkspaceIsolationError(ValueError):
    pass


_REQUEST_FIELDS = {"requirement", "repository_identity", "workflow_run_id", "candidate_id"}
_REQUIREMENTS = {"none", "preferred", "required"}
_RECEIPT_FIELDS = {
    "schema_version",
    "provider",
    "workspace_id",
    "repository_root",
    "git_common_dir",
    "run_id",
    "candidate_id",
    "task_id",
    "thread_id",
    "observed_head",
    "head_mode",
    "branch",
    "owner",
    "disposition",
}
_OWNER_BY_PROVIDER = {
    "codex_managed_worktree": {"codex_app"},
    "local_git_worktree": {"plugin", "user"},
}


def _required_text(data: Mapping[str, Any], field: str) -> str:
    value = data.get(field)
    if not isinstance(value, str) or not value.strip():
        raise WorkspaceIsolationError(f"missing required field: {field}")
    return value.strip()


def resolve_workspace_isolation(
    request: Mapping[str, Any], capabilities: Mapping[str, Any]
) -> dict[str, Any]:
    """Return an action decision, never a claim that the action occurred."""
    unsupported = sorted(set(request) - _REQUEST_FIELDS)
    if unsupported:
        raise WorkspaceIsolationError("unsupported request field(s): " + ", ".join(unsupported))

    requirement = _required_text(request, "requirement")
    repository = _required_text(request, "repository_identity")
    _required_text(request, "workflow_run_id")
    candidate = _required_text(request, "candidate_id")
    if requirement not in _REQUIREMENTS:
        raise WorkspaceIsolationError(f"unsupported isolation requirement: {requirement}")
    if requirement == "none":
        return {"provider": "current_checkout", "operation": "adopt", "reason": "isolation is not required"}

    current = capabilities.get("current_workspace")
    if (
        isinstance(current, Mapping)
        and current.get("provider") == "codex_managed_worktree"
        and current.get("repository_identity") == repository
        and current.get("candidate_id") == candidate
        and isinstance(current.get("workspace_id"), str)
        and current.get("workspace_id")
    ):
        return {
            "provider": "codex_managed_worktree",
            "operation": "adopt",
            "workspace_id": current["workspace_id"],
            "reason": "matching Codex worktree is already active",
        }

    if capabilities.get("native_task_created") is True:
        raise WorkspaceIsolationError("native task already exists; local fallback is forbidden")
    if capabilities.get("codex_project_tasks") is True:
        return {
            "provider": "codex_managed_worktree",
            "operation": "fork_task" if capabilities.get("source_task_id") else "create_task",
            "reason": "native Codex project worktrees are available",
        }
    if capabilities.get("local_git_worktrees") is True:
        return {
            "provider": "local_git_worktree",
            "operation": "invoke_vanilla_worktree_skill",
            "reason": "native worktrees are unavailable",
        }
    if capabilities.get("delegation_provider") == "shared_subagent":
        raise WorkspaceIsolationError("shared_subagent is delegation, not an isolation provider")
    if requirement == "preferred":
        return {"provider": "current_checkout", "operation": "adopt", "reason": "no isolation provider is available"}
    raise WorkspaceIsolationError("required isolation has no available provider")


def validate_workspace_receipt(
    receipt: Mapping[str, Any],
    expected: Mapping[str, Any],
    *,
    current_head: str,
    current_branch: str,
    publication: bool,
) -> None:
    """Validate one cooperative provider observation against kernel-owned bindings."""
    missing = sorted(_RECEIPT_FIELDS - set(receipt))
    unknown = sorted(set(receipt) - _RECEIPT_FIELDS - {"workspace_path"})
    if missing or unknown:
        raise WorkspaceIsolationError(f"workspace receipt fields are invalid: missing={missing}, unknown={unknown}")
    if receipt["schema_version"] != 1:
        raise WorkspaceIsolationError("workspace receipt schema_version must be 1")

    provider = receipt["provider"]
    owner = receipt["owner"]
    if provider not in _OWNER_BY_PROVIDER or owner not in _OWNER_BY_PROVIDER[provider]:
        raise WorkspaceIsolationError("workspace provider and owner are incompatible")
    if receipt["disposition"] not in {"active", "integrated", "preserved"}:
        raise WorkspaceIsolationError("workspace disposition is invalid")
    if not isinstance(receipt["workspace_id"], str) or not receipt["workspace_id"]:
        raise WorkspaceIsolationError("workspace_id is required")
    if provider == "codex_managed_worktree" and (
        not isinstance(receipt["task_id"], str)
        or not receipt["task_id"]
        or not isinstance(receipt["thread_id"], str)
        or not receipt["thread_id"]
    ):
        raise WorkspaceIsolationError("Codex workspace receipt requires task and thread identity")
    if not isinstance(receipt["git_common_dir"], str) or not receipt["git_common_dir"]:
        raise WorkspaceIsolationError("git_common_dir is required")
    if not isinstance(receipt["observed_head"], str) or not re.fullmatch(r"[0-9a-f]{40}", receipt["observed_head"]):
        raise WorkspaceIsolationError("observed_head must be a 40-character Git commit")

    for field, value in expected.items():
        if receipt.get(field) != value:
            raise WorkspaceIsolationError(f"workspace receipt {field} does not match lifecycle binding")
    if receipt["observed_head"] != current_head:
        raise WorkspaceIsolationError("workspace receipt head is stale")

    mode = receipt["head_mode"]
    branch = receipt["branch"]
    if mode == "detached":
        if branch is not None:
            raise WorkspaceIsolationError("detached workspace receipt cannot name a branch")
    elif mode == "branch":
        if not isinstance(branch, str) or not branch or branch != current_branch:
            raise WorkspaceIsolationError("workspace receipt branch does not match current branch")
    else:
        raise WorkspaceIsolationError("workspace head_mode is invalid")
    if publication and mode != "branch":
        raise WorkspaceIsolationError("publication requires a branch-bound workspace receipt")
