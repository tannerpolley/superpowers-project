"""Typed ownership catalog for every public Superpowers Project launcher."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CommandSpec:
    path: str
    handler: str
    kind: str
    mutation: str


_PROJECT_MUTATIONS = {
    "command_hydrate_external_issue",
    "command_collect_premerge",
    "command_collect_closeout",
    "command_collect_merge_continuation",
    "command_collect_resolve_continuation",
    "command_collect_pr_ready",
    "command_prepare_worker_handoff",
    "command_write_metrics",
}

_GIT_MUTATIONS = {"command_apply_local_branch_closeout"}
_DEPLOYMENT_MUTATIONS = {"command_install", "command_sync_live"}
_EXTERNAL_MUTATIONS = {"command_prepare_github_project_board"}


def _kind(path: str) -> str:
    name = Path(path).name
    if name.startswith("test-") or name == "test-scenarios.sh":
        return "test"
    if name.startswith(("validate-", "detect-")):
        return "validator"
    if path.startswith("scripts/") and name in {
        "get-agent-plugin-version.sh",
        "install.sh",
        "prepare-release.sh",
        "sync-live.sh",
    }:
        return "distribution"
    if "loop-controller" in path or "workflow" in name:
        return "workflow"
    return "project"


def _mutation(handler: str) -> str:
    if handler in _PROJECT_MUTATIONS:
        return "project"
    if handler in _GIT_MUTATIONS:
        return "git"
    if handler in _DEPLOYMENT_MUTATIONS:
        return "deployment"
    if handler in _EXTERNAL_MUTATIONS:
        return "external"
    return "none"


def load_command_catalog(plugin_root: Path) -> dict[str, CommandSpec]:
    """Load typed command ownership after registry drift validation."""
    try:
        from .superpowers_project_command_registry import build_command_registry
    except ImportError:
        from superpowers_project_command_registry import build_command_registry

    handlers = build_command_registry(plugin_root)
    return {
        path: CommandSpec(path=path, handler=handler, kind=_kind(path), mutation=_mutation(handler))
        for path, handler in handlers.items()
    }
