# Workflow Golden Paths

These examples show the common project workflow routes with their question IDs, artifacts, validators, and explicit stop points. The workflow contract remains the source of truth for route definitions.

## Idea To Local Merge

**Example ID:** idea-to-local-merge
**Route sequence:** brainstorm-spec -> write-plan -> implement-plan -> merge-changes
**Question IDs:** project_brainstorm_next_step, project_brainstorm_plan_route, project_plan_next_step, project_plan_work_route, implement_plan_topology, implement_plan_push_permission, project_implement_next_step, project_merge_approval, project_merge_final_health_gate
**Artifacts:** docs/superpowers/specs/<idea-spec>.md; docs/superpowers/plans/<implementation-plan>.md; pull request; closeout ledger
**Validators:** scripts/validate-plan-outcome-proof.sh; scripts/validate-plan-task-use-cases.sh; scripts/validate.sh
**Stop point:** project_merge_final_health_gate after clean local merge closeout.

Flow:

1. Shape the idea into a spec with `brainstorm-spec`.
2. Turn the spec into an implementation plan with `write-plan`.
3. Execute the branch-backed plan with `implement-plan`.
4. Integrate with `merge-changes` and stop at verified merge closeout.

## Spec To Issues To Merge

**Example ID:** spec-to-issues-to-merge
**Route sequence:** write-plan -> create-issues -> resolve-issue -> merge-changes
**Question IDs:** project_plan_next_step, project_plan_work_route, project_plan_issue_count, project_issue_next_step, project_issue_execution_route, project_resolve_push_permission, project_resolve_next_step, project_resolve_integration_route, project_merge_approval, project_merge_final_health_gate
**Artifacts:** docs/superpowers/plans/<approved-plan>.md; docs/superpowers/issues/<issue>.md; pull request; milestone summary
**Validators:** skills/create-issues/scripts/validate-issue-mirror.sh; skills/resolve-issue/scripts/validate-pr-ready.sh; skills/merge-changes/scripts/closeout.sh
**Stop point:** project_merge_final_health_gate after the linked issue is closed.

Flow:

1. Use `write-plan` to choose issue-backed execution.
2. Use `create-issues` to create the issue mirror and GitHub issue.
3. Use `resolve-issue` for the selected ready issue.
4. Use `merge-changes` to merge, verify issue closure, remove the closed mirror, and preserve milestone history.

## Sub-Issue Hierarchy To Parent Rollup

**Example ID:** sub-issue-hierarchy-to-parent-rollup
**Route sequence:** write-plan -> create-issues -> resolve-issue -> merge-changes -> align-project -> loop-controller
**Question IDs:** project_plan_next_step, project_plan_issue_count, project_issue_hierarchy_mode, project_issue_hierarchy_parent, project_issue_hierarchy_children, project_issue_hierarchy_publish, project_resolve_push_permission, project_resolve_next_step, project_merge_approval, project_merge_final_health_gate, project_align_next_step, project_loop_final_health_gate
**Artifacts:** docs/superpowers/plans/<approved-plan>.md; docs/superpowers/issues/<parent>.md; docs/superpowers/issues/<leaf>.md; GitHub Sub-issues section; hierarchy_rollup closeout ledger; parent progress count
**Validators:** skills/create-issues/scripts/validate-issue-hierarchy.sh; skills/merge-changes/scripts/closeout.sh; skills/align-project/scripts/align-project.sh; skills/loop-controller/scripts/select-candidate.sh; scripts/validate-workflow-examples.sh
**Stop point:** project_loop_final_health_gate after leaf closeout records parent progress, parent rollup remains approval-gated, and loop selection skips non-leaf implementation candidates.

Flow:

1. Use `write-plan` to identify grouped work that should stay inside one GitHub Milestone.
2. Use `create-issues` to create a clean-title parent plus executable leaf issues linked through GitHub sub-issues.
3. Use `resolve-issue` only on `Sub-Issue Role: leaf` mirrors with `Executable: true`.
4. Use `merge-changes` to close the leaf and record parent progress without closing the parent automatically.
5. Use `align-project` and `loop-controller` to report hierarchy drift and route remaining parent or wrapper records to rollup, alignment, or tracker repair.

## Audit To Auto Mode Outcome

**Example ID:** audit-to-auto-mode-outcome
**Route sequence:** initiate-workflow -> audit-project -> write-plan -> implement-plan -> merge-changes
**Question IDs:** project_workflow_mode, project_audit_next_step, project_audit_progress_route, project_plan_next_step, project_plan_work_route, implement_plan_topology, implement_plan_push_permission, project_implement_next_step, project_merge_approval, project_merge_final_health_gate
**Artifacts:** docs/superpowers/specs/<audit-findings>.md; docs/superpowers/plans/<repair-plan>.md; implementation branch; merge closeout ledger
**Validators:** scripts/validate-auto-mode-authorization.sh; scripts/validate-plan-outcome-proof.sh; scripts/validate.sh; skills/merge-changes/scripts/validate-terminal-closeout.sh
**Stop point:** project_merge_final_health_gate after verified merge closeout.

Flow:

1. Select Auto Mode once at `project_workflow_mode` for one bounded outcome.
2. Use `audit-project` to save evidence-backed findings, then continue through planning without another user decision.
3. Choose issue-backed or direct implementation from evidence and keep the same run active across route boundaries.
4. Implement, verify, integrate, and finish only at verified merge closeout; do not start another outcome.

## Looping Mode Candidate Selection

**Example ID:** looping-mode-candidate-selection
**Route sequence:** initiate-workflow -> loop-controller -> resolve-issue -> merge-changes -> loop-controller
**Question IDs:** project_workflow_mode, project_resolve_push_permission, project_resolve_next_step, project_resolve_integration_route, project_merge_approval, project_merge_final_health_gate, project_loop_final_health_gate
**Artifacts:** docs/superpowers/loop-mode-contract.yml; .superpowers/runs/<run-id>/run-ledger.json; .superpowers/runs/<run-id>/budget-ledger.json; .superpowers/runs/<run-id>/loop-state-machine.json; docs/superpowers/backlog/ACTIVE.md; closeout ledger
**Validators:** skills/loop-controller/scripts/validate-run-ledger.sh; skills/loop-controller/scripts/validate-budget.sh; skills/loop-controller/scripts/select-candidate.sh; skills/loop-controller/scripts/validate-loop-state-machine.sh
**Stop point:** project_loop_final_health_gate after terminal loop proof and a clean worktree.

Flow:

1. Select Looping Mode at `project_workflow_mode`.
2. Let `loop-controller` select exactly one ready candidate from the active backlog.
3. Route that candidate to its owner and then through `merge-changes` when a PR is ready.
4. Return to `loop-controller`, validate the run ledger, budget ledger, verifier proof, and loop state-machine ledger; continue by policy within budget or resolve `project_loop_final_health_gate` when the loop is terminal.
