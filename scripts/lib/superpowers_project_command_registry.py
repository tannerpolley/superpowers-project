from __future__ import annotations

from pathlib import Path


class ScriptError(Exception):
    pass


_COMMANDS: dict[str, str] = {
    'scripts/detect-stale-skill-contract.sh': 'command_unimplemented',
    'scripts/generate-outcome-workflow-summary.sh': 'command_unimplemented',
    'scripts/get-agent-plugin-version.sh': 'command_get_agent_plugin_version',
    'scripts/install.sh': 'command_install',
    'scripts/prepare-release.sh': 'command_prepare_release',
    'scripts/sync-live.sh': 'command_sync_live',
    'scripts/test-active-backlog.sh': 'command_validate_active_backlog',
    'scripts/test-auto-loop-trials.sh': 'command_test_auto_loop_trials',
    'scripts/test-advanced-user-input-policy.sh': 'command_validate_advanced_user_input_policy',
    'scripts/test-auto-loop-trials.sh': 'command_test_auto_loop_trials',
    'scripts/test-agent-native-companion-preview.sh': 'command_test_agent_native_companion_preview',
    'scripts/test-agent-plugin-version.sh': 'command_test_agent_plugin_version',
    'scripts/test-artifact-review-card.sh': 'command_test_artifact_review_card',
    'scripts/test-auto-mode-contract.sh': 'command_test_auto_mode_contract',
    'scripts/test-companion-interface.sh': 'command_test_agent_native_companion_preview',
    'scripts/test-cross-repo-runtime.sh': 'command_unimplemented',
    'scripts/test-codex-marketplace-lifecycle.sh': 'command_unimplemented',
    'scripts/test-decision-ledger.sh': 'command_test_decision_ledger',
    'scripts/test-install-transaction.sh': 'command_unimplemented',
    'scripts/test-e2e-project-workflow.sh': 'command_unimplemented',
    'scripts/test-flat-artifact-roots.sh': 'command_unimplemented',
    'scripts/test-generated-state.sh': 'command_unimplemented',
    'scripts/test-github-checks.sh': 'command_unimplemented',
    'scripts/test-global-policy-deduplication.sh': 'command_unimplemented',
    'scripts/test-initiate-workflow-mode-gate.sh': 'command_unimplemented',
    'scripts/test-linux-migration.sh': 'command_unimplemented',
    'scripts/test-loop-controller.sh': 'command_unimplemented',
    'scripts/test-native-continuation-loop.sh': 'command_unimplemented',
    'scripts/test-native-qa-svg.sh': 'command_unimplemented',
    'scripts/test-outcome-workflow-summary.sh': 'command_unimplemented',
    'scripts/test-plan-outcome-proof.sh': 'command_validate_plan_outcome_proof',
    'scripts/test-plan-task-use-cases.sh': 'command_validate_plan_task_use_cases',
    'scripts/test-plugin-only-live-sync.sh': 'command_unimplemented',
    'scripts/test-prepare-release.sh': 'command_unimplemented',
    'scripts/test-project-namespace-migration.sh': 'command_unimplemented',
    'scripts/test-release-proof.sh': 'command_unimplemented',
    'scripts/test-scorecard-proof.sh': 'command_unimplemented',
    'scripts/test-skill-metadata-contract.sh': 'command_unimplemented',
    'scripts/test-skill-metadata-readability.sh': 'command_unimplemented',
    'scripts/test-stale-skill-contract.sh': 'command_unimplemented',
    'scripts/test-superpowers-method-contract.sh': 'command_unimplemented',
    'scripts/test-superpowers-project-dummy-repo.sh': 'command_unimplemented',
    'scripts/test-superpowers-project-repo-contract.sh': 'command_unimplemented',
    'scripts/test-sync-live.sh': 'command_unimplemented',
    'scripts/test-tracker-roadmap-proof.sh': 'command_unimplemented',
    'scripts/test-worker-packets.sh': 'command_unimplemented',
    'scripts/test-workflow-contract.sh': 'command_unimplemented',
    'scripts/test-workflow-examples.sh': 'command_unimplemented',
    'scripts/test-workflow-mode-ledger.sh': 'command_validate_workflow_mode',
    'scripts/test-workflow-runtime.sh': 'command_test_workflow_runtime',
    'scripts/test-workflow-normalization-proof.sh': 'command_unimplemented',
    'scripts/validate-active-backlog.sh': 'command_unimplemented',
    'scripts/validate-artifact-review-card.sh': 'command_validate_artifact_review_card',
    'scripts/validate-auto-mode-authorization.sh': 'command_validate_auto_mode',
    'scripts/validate-decision-ledger.sh': 'command_validate_decision_ledger',
    'scripts/validate-flat-artifact-roots.sh': 'command_unimplemented',
    'scripts/validate-generated-state.sh': 'command_unimplemented',
    'scripts/validate-global-policy-deduplication.sh': 'command_unimplemented',
    'scripts/validate-plan-outcome-proof.sh': 'command_validate_plan_outcome_proof',
    'scripts/validate-plan-task-use-cases.sh': 'command_validate_plan_task_use_cases',
    'scripts/validate-scorecard-proof.sh': 'command_unimplemented',
    'scripts/validate-skill-metadata-contract.sh': 'command_unimplemented',
    'scripts/validate-skill-script-contract.sh': 'command_unimplemented',
    'scripts/validate-tracker-roadmap-proof.sh': 'command_unimplemented',
    'scripts/validate-worker-packets.sh': 'command_unimplemented',
    'scripts/validate-workflow-contract.sh': 'command_unimplemented',
    'scripts/validate-workflow-examples.sh': 'command_unimplemented',
    'scripts/validate-workflow-mode-ledger.sh': 'command_validate_workflow_mode',
    'scripts/validate-workflow-normalization-proof.sh': 'command_unimplemented',
    'scripts/validate.sh': 'command_validate',
    'skills/align-project/scripts/align-project.sh': 'command_unimplemented',
    'skills/align-project/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/audit-project/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/brainstorm-spec/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/create-issues/scripts/build-issue-hierarchy-plan.sh': 'command_unimplemented',
    'skills/create-issues/scripts/hydrate-external-issue.sh': 'command_unimplemented',
    'skills/create-issues/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/create-issues/scripts/validate-issue-hierarchy.sh': 'command_unimplemented',
    'skills/create-issues/scripts/validate-issue-mirror.sh': 'command_unimplemented',
    'skills/create-issues/scripts/validate-issue-title-policy.sh': 'command_unimplemented',
    'skills/implement-plan/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/initiate-workflow/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/select-candidate.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/validate-budget.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/validate-loop-state-machine.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/validate-run-ledger.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/validate-terminal-closeout.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/validate-verifier-ledger.sh': 'command_unimplemented',
    'skills/loop-controller/scripts/write-metrics-report.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/apply-local-branch-closeout.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/closeout.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/collect-closeout-ledger.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/collect-continuation-ledger.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/collect-premerge-ledger.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/premerge.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/prepare-local-branch-closeout.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/validate-merge-decision.sh': 'command_unimplemented',
    'skills/merge-changes/scripts/validate-terminal-closeout.sh': 'command_unimplemented',
    'skills/orchestrate-issues/scripts/derive-worker-identity.sh': 'command_unimplemented',
    'skills/orchestrate-issues/scripts/prepare-worker-handoff.sh': 'command_unimplemented',
    'skills/orchestrate-issues/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/orchestrate-issues/scripts/validate-worker-handoff.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/collect-continuation-ledger.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/collect-pr-ready-ledger.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/preflight.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/prepare-execution.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/repo-gate.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/validate-pr-ready.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/validate-setup.sh': 'command_unimplemented',
    'skills/resolve-issue/scripts/validate-terminal-closeout.sh': 'command_unimplemented',
    'skills/setup-project/scripts/prepare-github-project-board.sh': 'command_unimplemented',
    'skills/setup-project/scripts/test-scenarios.sh': 'command_unimplemented',
    'skills/write-plan/scripts/test-scenarios.sh': 'command_unimplemented',
}


_REGISTRY: dict[str, str] = {}


def build_command_registry(plugin_root: Path) -> dict[str, str]:
    """Return the literal command map after checking shipped launchers for drift."""
    global _REGISTRY
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
        raise ScriptError(f"command registry drift: missing={missing}, extra={extra}")
    _REGISTRY = dict(_COMMANDS)
    return dict(_REGISTRY)


def resolve_command(script_rel: str) -> str:
    command = _REGISTRY.get(script_rel)
    if command is None:
        raise ScriptError(f"unregistered script path: {script_rel}")
    return command
