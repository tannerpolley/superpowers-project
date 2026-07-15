"""Typed ownership catalog for every public Superpowers Project launcher."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


class ScriptError(Exception):
    pass


_COMMANDS: dict[str, str] = {
    'scripts/generate-outcome-workflow-summary.sh': 'command_generate_outcome_workflow_summary',
    'scripts/get-agent-plugin-version.sh': 'command_get_agent_plugin_version',
    'scripts/install.sh': 'command_install',
    'scripts/prepare-release.sh': 'command_prepare_release',
    'scripts/project-truss.sh': 'command_project_truss',
    'scripts/run-agent-usability-trials.sh': 'command_run_agent_usability_trials',
    'scripts/sync-live.sh': 'command_sync_live',
    'scripts/validate-agent-usability-receipt.sh': 'command_validate_agent_usability_receipt',
    'scripts/validate-auto-mode-authorization.sh': 'command_validate_auto_mode',
    'scripts/validate-decision-ledger.sh': 'command_validate_decision_ledger',
    'scripts/validate-plan-outcome-proof.sh': 'command_validate_plan_outcome_proof',
    'scripts/validate-plan-task-use-cases.sh': 'command_validate_plan_task_use_cases',
    'scripts/validate-skill-metadata-contract.sh': 'command_validate_skill_metadata_contract',
    'scripts/validate-tracker-roadmap-proof.sh': 'command_validate_tracker_roadmap',
    'scripts/validate-worker-packets.sh': 'command_validate_worker_packets',
    'scripts/validate-workflow-contract.sh': 'command_validate_workflow_contract',
    'scripts/validate-workflow-examples.sh': 'command_validate_workflow_examples',
    'scripts/validate-workflow-mode-ledger.sh': 'command_validate_workflow_mode',
    'scripts/validate.sh': 'command_validate',
    'scripts/workspace-isolation.sh': 'command_workspace_isolation',
    'scripts/workflow-run.sh': 'command_workflow_run',
    'skills/align-project/scripts/align-project.sh': 'command_align_project',
    'skills/create-issues/scripts/build-issue-hierarchy-plan.sh': 'command_build_issue_hierarchy_plan',
    'skills/create-issues/scripts/hydrate-external-issue.sh': 'command_hydrate_external_issue',
    'skills/create-issues/scripts/validate-issue-hierarchy.sh': 'command_validate_issue_hierarchy',
    'skills/create-issues/scripts/validate-issue-mirror.sh': 'command_validate_issue_mirror',
    'skills/create-issues/scripts/validate-issue-title-policy.sh': 'command_validate_issue_title_policy',
    'skills/loop-controller/scripts/select-candidate.sh': 'command_select_candidate',
    'skills/loop-controller/scripts/validate-budget.sh': 'command_loop_budget',
    'skills/loop-controller/scripts/validate-loop-state-machine.sh': 'command_loop_state_machine',
    'skills/loop-controller/scripts/validate-run-ledger.sh': 'command_loop_run_ledger',
    'skills/loop-controller/scripts/validate-terminal-closeout.sh': 'command_loop_terminal_closeout',
    'skills/loop-controller/scripts/validate-verifier-ledger.sh': 'command_loop_verifier',
    'skills/loop-controller/scripts/write-metrics-report.sh': 'command_write_metrics',
    'skills/merge-changes/scripts/apply-local-branch-closeout.sh': 'command_apply_local_branch_closeout',
    'skills/merge-changes/scripts/closeout.sh': 'command_closeout',
    'skills/merge-changes/scripts/collect-closeout-ledger.sh': 'command_collect_closeout',
    'skills/merge-changes/scripts/collect-continuation-ledger.sh': 'command_collect_merge_continuation',
    'skills/merge-changes/scripts/collect-premerge-ledger.sh': 'command_collect_premerge',
    'skills/merge-changes/scripts/premerge.sh': 'command_premerge',
    'skills/merge-changes/scripts/prepare-local-branch-closeout.sh': 'command_prepare_local_branch_closeout',
    'skills/merge-changes/scripts/validate-merge-decision.sh': 'command_validate_merge_decision',
    'skills/merge-changes/scripts/validate-terminal-closeout.sh': 'command_validate_merge_terminal_closeout',
    'skills/orchestrate-issues/scripts/derive-worker-identity.sh': 'command_derive_worker_identity',
    'skills/orchestrate-issues/scripts/prepare-worker-handoff.sh': 'command_prepare_worker_handoff',
    'skills/orchestrate-issues/scripts/validate-worker-handoff.sh': 'command_validate_worker_handoff',
    'skills/resolve-issue/scripts/collect-continuation-ledger.sh': 'command_collect_resolve_continuation',
    'skills/resolve-issue/scripts/collect-pr-ready-ledger.sh': 'command_collect_pr_ready',
    'skills/resolve-issue/scripts/preflight.sh': 'command_resolve_preflight',
    'skills/resolve-issue/scripts/prepare-execution.sh': 'command_prepare_execution',
    'skills/resolve-issue/scripts/validate-pr-ready.sh': 'command_validate_pr_ready',
    'skills/resolve-issue/scripts/validate-setup.sh': 'command_validate_resolve_setup',
    'skills/resolve-issue/scripts/validate-terminal-closeout.sh': 'command_validate_resolve_terminal_closeout',
    'skills/setup-project/scripts/prepare-github-project-board.sh': 'command_prepare_github_project_board',
}


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
    """Load typed command ownership after public-launcher drift validation."""
    discovered = {
        path.relative_to(plugin_root).as_posix()
        for base in (plugin_root / "scripts", plugin_root / "skills")
        for path in base.rglob("*.sh")
        if "/lib/" not in path.relative_to(plugin_root).as_posix()
        and path.relative_to(plugin_root).as_posix() != "scripts/lib/run-script.sh"
    }
    configured = set(_COMMANDS)
    if configured != discovered:
        missing = sorted(discovered - configured)
        extra = sorted(configured - discovered)
        raise ScriptError(f"command catalog drift: missing={missing}, extra={extra}")
    return {
        path: CommandSpec(path=path, handler=handler, kind=_kind(path), mutation=_mutation(handler))
        for path, handler in _COMMANDS.items()
    }


def build_command_registry(plugin_root: Path) -> dict[str, str]:
    return {path: spec.handler for path, spec in load_command_catalog(plugin_root).items()}


def resolve_command(script_rel: str, plugin_root: Path) -> str:
    spec = load_command_catalog(plugin_root).get(script_rel)
    if spec is None:
        raise ScriptError(f"unregistered script path: {script_rel}")
    return spec.handler
