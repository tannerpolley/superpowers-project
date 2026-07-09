from __future__ import annotations

from pathlib import Path


class ScriptError(Exception):
    pass


_COMMANDS: dict[str, str] = {
    'scripts/detect-stale-skill-contract.sh': 'command_validate_skill_script_contract',
    'scripts/generate-outcome-workflow-summary.sh': 'command_generate_outcome_workflow_summary',
    'scripts/get-agent-plugin-version.sh': 'command_get_agent_plugin_version',
    'scripts/install.sh': 'command_install',
    'scripts/prepare-release.sh': 'command_prepare_release',
    'scripts/sync-live.sh': 'command_sync_live',
    'scripts/test-active-backlog.sh': 'command_validate_active_backlog',
    'scripts/test-auto-loop-trials.sh': 'command_test_auto_loop_trials',
    'scripts/test-advanced-user-input-policy.sh': 'command_validate_advanced_user_input_policy',
    'scripts/test-agent-native-companion-preview.sh': 'command_test_agent_native_companion_preview',
    'scripts/test-agent-plugin-version.sh': 'command_test_agent_plugin_version',
    'scripts/test-artifact-review-card.sh': 'command_test_artifact_review_card',
    'scripts/test-auto-mode-contract.sh': 'command_test_auto_mode_contract',
    'scripts/test-companion-interface.sh': 'command_test_agent_native_companion_preview',
    'scripts/test-cross-repo-runtime.sh': 'command_test_cross_repo_runtime',
    'scripts/test-codex-marketplace-lifecycle.sh': 'command_test_codex_marketplace_lifecycle',
    'scripts/test-decision-ledger.sh': 'command_test_decision_ledger',
    'scripts/test-install-transaction.sh': 'command_test_install_transaction',
    'scripts/test-e2e-project-workflow.sh': 'command_test_e2e_project_workflow',
    'scripts/test-flat-artifact-roots.sh': 'command_validate_flat_roots',
    'scripts/test-generated-state.sh': 'command_validate_generated_state',
    'scripts/test-github-checks.sh': 'command_test_github_checks',
    'scripts/test-global-policy-deduplication.sh': 'command_test_global_policy_deduplication',
    'scripts/test-initiate-workflow-mode-gate.sh': 'command_test_initiate_workflow_mode_gate',
    'scripts/test-linux-migration.sh': 'command_test_linux_migration',
    'scripts/test-loop-controller.sh': 'command_test_workflow_runtime',
    'scripts/test-native-continuation-loop.sh': 'command_validate_advanced_user_input_policy',
    'scripts/test-native-qa-svg.sh': 'command_test_native_qa_svg',
    'scripts/test-outcome-workflow-summary.sh': 'command_test_outcome_workflow_summary',
    'scripts/test-plan-outcome-proof.sh': 'command_test_plan_outcome_proof',
    'scripts/test-plan-task-use-cases.sh': 'command_test_plan_task_use_cases',
    'scripts/test-plugin-only-live-sync.sh': 'command_test_plugin_only_live_sync',
    'scripts/test-prepare-release.sh': 'command_test_prepare_release',
    'scripts/test-project-namespace-migration.sh': 'command_test_project_namespace_migration',
    'scripts/test-release-proof.sh': 'command_test_prepare_release',
    'scripts/test-scorecard-proof.sh': 'command_test_scorecard_proof',
    'scripts/test-skill-metadata-contract.sh': 'command_validate_skill_metadata_contract',
    'scripts/test-skill-slimming.sh': 'command_test_skill_slimming',
    'scripts/test-skill-metadata-readability.sh': 'command_validate_skill_metadata_contract',
    'scripts/test-stale-skill-contract.sh': 'command_validate_skill_script_contract',
    'scripts/test-superpowers-method-contract.sh': 'command_validate_advanced_user_input_policy',
    'scripts/test-superpowers-project-dummy-repo.sh': 'command_test_e2e_project_workflow',
    'scripts/test-superpowers-project-repo-contract.sh': 'command_repo_gate',
    'scripts/test-sync-live.sh': 'command_test_plugin_only_live_sync',
    'scripts/test-tracker-roadmap-proof.sh': 'command_test_tracker_roadmap_proof',
    'scripts/test-worker-packets.sh': 'command_validate_worker_packets',
    'scripts/test-workflow-contract.sh': 'command_validate_workflow_contract',
    'scripts/test-workflow-examples.sh': 'command_validate_workflow_contract',
    'scripts/test-workflow-mode-ledger.sh': 'command_test_initiate_workflow_mode_gate',
    'scripts/test-workflow-runtime.sh': 'command_test_workflow_runtime',
    'scripts/test-workflow-graph.sh': 'command_test_workflow_graph',
    'scripts/test-workflow-normalization-proof.sh': 'command_validate_workflow_contract',
    'scripts/validate-active-backlog.sh': 'command_validate_active_backlog',
    'scripts/validate-artifact-review-card.sh': 'command_validate_artifact_review_card',
    'scripts/validate-auto-mode-authorization.sh': 'command_validate_auto_mode',
    'scripts/validate-decision-ledger.sh': 'command_validate_decision_ledger',
    'scripts/validate-flat-artifact-roots.sh': 'command_validate_flat_roots',
    'scripts/validate-generated-state.sh': 'command_validate_generated_state',
    'scripts/validate-global-policy-deduplication.sh': 'command_validate_global_policy_deduplication',
    'scripts/validate-plan-outcome-proof.sh': 'command_validate_plan_outcome_proof',
    'scripts/validate-plan-task-use-cases.sh': 'command_validate_plan_task_use_cases',
    'scripts/validate-scorecard-proof.sh': 'command_validate_scorecard_proof',
    'scripts/validate-skill-metadata-contract.sh': 'command_validate_skill_metadata_contract',
    'scripts/validate-skill-script-contract.sh': 'command_validate_skill_script_contract',
    'scripts/validate-tracker-roadmap-proof.sh': 'command_validate_tracker_roadmap',
    'scripts/validate-worker-packets.sh': 'command_validate_worker_packets',
    'scripts/validate-workflow-contract.sh': 'command_validate_workflow_contract',
    'scripts/validate-workflow-examples.sh': 'command_validate_workflow_examples',
    'scripts/validate-workflow-mode-ledger.sh': 'command_validate_workflow_mode',
    'scripts/validate-workflow-normalization-proof.sh': 'command_validate_workflow_contract',
    'scripts/validate.sh': 'command_validate',
    'scripts/workflow-run.sh': 'command_workflow_run',
    'skills/align-project/scripts/align-project.sh': 'command_align_project',
    'skills/align-project/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/audit-project/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/brainstorm-spec/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/create-issues/scripts/build-issue-hierarchy-plan.sh': 'command_build_issue_hierarchy_plan',
    'skills/create-issues/scripts/hydrate-external-issue.sh': 'command_hydrate_external_issue',
    'skills/create-issues/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/create-issues/scripts/validate-issue-hierarchy.sh': 'command_validate_issue_hierarchy',
    'skills/create-issues/scripts/validate-issue-mirror.sh': 'command_validate_issue_mirror',
    'skills/create-issues/scripts/validate-issue-title-policy.sh': 'command_validate_issue_title_policy',
    'skills/implement-plan/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/initiate-workflow/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/loop-controller/scripts/select-candidate.sh': 'command_select_candidate',
    'skills/loop-controller/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
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
    'skills/merge-changes/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/merge-changes/scripts/validate-merge-decision.sh': 'command_validate_merge_decision',
    'skills/merge-changes/scripts/validate-terminal-closeout.sh': 'command_validate_merge_terminal_closeout',
    'skills/orchestrate-issues/scripts/derive-worker-identity.sh': 'command_derive_worker_identity',
    'skills/orchestrate-issues/scripts/prepare-worker-handoff.sh': 'command_prepare_worker_handoff',
    'skills/orchestrate-issues/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/orchestrate-issues/scripts/validate-worker-handoff.sh': 'command_validate_worker_handoff',
    'skills/resolve-issue/scripts/collect-continuation-ledger.sh': 'command_collect_resolve_continuation',
    'skills/resolve-issue/scripts/collect-pr-ready-ledger.sh': 'command_collect_pr_ready',
    'skills/resolve-issue/scripts/preflight.sh': 'command_resolve_preflight',
    'skills/resolve-issue/scripts/prepare-execution.sh': 'command_prepare_execution',
    'skills/resolve-issue/scripts/repo-gate.sh': 'command_repo_gate',
    'skills/resolve-issue/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/resolve-issue/scripts/validate-pr-ready.sh': 'command_validate_pr_ready',
    'skills/resolve-issue/scripts/validate-setup.sh': 'command_validate_resolve_setup',
    'skills/resolve-issue/scripts/validate-terminal-closeout.sh': 'command_validate_resolve_terminal_closeout',
    'skills/setup-project/scripts/prepare-github-project-board.sh': 'command_prepare_github_project_board',
    'skills/setup-project/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
    'skills/write-plan/scripts/test-scenarios.sh': 'command_validate_skill_scenario',
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
