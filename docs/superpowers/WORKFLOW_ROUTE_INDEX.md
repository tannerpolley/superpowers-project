# Workflow Route Index

> Generated from `docs/superpowers/workflow-contract.yml`. Do not edit by hand.

## `$superpowers-project:align-project`

Structure alignment, migration review, tracker alignment, live sync verification, and repair planning.

Owner: `align-project`

Gates:
- `project_align_final_health_gate` (final_health): Done, Revisit, Stop
- `project_align_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_align_plan_issue_route` (data_selection): Plan Repair, Create Issue
- `project_align_prepare_route` (data_selection): Create Planning Spec, Plan Or Issue Repair
- `project_align_reiteration_route` (nested_revisit_route): Run Align Again, Review Or Gather Evidence
- `project_align_repair_group` (nested_yes_route): Apply Repair, Prepare Repair Work
- `project_align_review_evidence_route` (nested_revisit_route): Review First, Gather More Evidence

Next routes: `write-plan`, `create-issues`, `merge-changes`

## `$superpowers-project:audit-project`

Evidence-backed code, workflow, test, skill, or repo behavior audit findings before repair planning.

Owner: `audit-project`

Gates:
- `project_audit_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_audit_progress_route` (data_selection): Write Plan, Auto Mode, Create Issues
- `project_audit_revisit_route` (nested_revisit_route): Review First, Gather More Evidence, Rerun Focused Audit

Next routes: `write-plan`, `create-issues`

## `$superpowers-project:brainstorm-spec`

Repo-backed ideas, specs, PRDs, architecture concepts, and broad feature requests.

Owner: `brainstorm-spec`

Gates:
- `project_brainstorm_multi_spec_route` (data_selection): Plan Multiple Specs, Create Multiple Plans
- `project_brainstorm_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_brainstorm_plan_route` (data_selection): Create One Plan, Multi-Spec Planning
- `project_brainstorm_reiteration_route` (nested_revisit_route): Revise Spec, Review Or Restart
- `project_brainstorm_review_restart_route` (nested_revisit_route): Review First, Re-run Brainstorm
- `project_brainstorm_visual_companion` (data_selection): Use Visual Companion, Skip Visual Companion

Next routes: `companion-interface`, `write-plan`

## `$superpowers-project:companion-interface`

Optional Agent-Native visual-plan or visual-recap review surface.

Owner: `companion-interface`

Gates:

Next routes: `brainstorm-spec`, `write-plan`, `merge-changes`

## `$superpowers-project:create-issues`

Vertical-slice GitHub issues and synced local issue mirrors.

Owner: `create-issues`

Gates:
- `project_issue_execution_route` (data_selection): Resolve Issues, Orchestrate Issues
- `project_issue_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_issue_orchestrate_route` (data_selection): Orchestrate First Ready, Orchestrate Selected
- `project_issue_hierarchy_children` (data_selection): Use Proposed Children, Revise Children
- `project_issue_hierarchy_mode` (data_selection): Flat Issues, Issue Set, Sub-Milestone
- `project_issue_hierarchy_parent` (data_selection): Use Proposed Parent, Use Existing Parent, Revise Parent
- `project_issue_hierarchy_publish` (approval): Publish Approved Commands, Revise Before Publish
- `project_issue_hierarchy_tracker_fields` (data_selection): Use Proposed Tracker Fields, Revise Tracker Fields
- `project_issue_hierarchy_wrapper` (data_selection): No Wrapper, Use Wrappers
- `project_issue_resolve_route` (data_selection): Resolve First Ready, Resolve Selected
- `project_issue_reiteration_route` (nested_revisit_route): Revise Or Reslice Issues, Review Or Repair Issues
- `project_issue_review_repair_route` (nested_revisit_route): Review First, Repair Issue Mirrors

Next routes: `resolve-issue`, `orchestrate-issues`

## `$superpowers-project:implement-plan`

Approved non-issue implementation plan execution with branch-backed proof.

Owner: `implement-plan`

Gates:
- `implement_plan_push_permission` (permission): Push Branch, Hold
- `implement_plan_topology` (topology): Inline, Worker, Stop
- `project_implement_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_implement_reiteration_route` (nested_revisit_route): Revise Branch, Review Evidence

Next routes: `merge-changes`

## `$superpowers-project:initiate-workflow`

Route setup, brainstorming, audits, planning, issue creation, issue resolution, orchestration, merge cleanup, and alignment checks.

Owner: `initiate-workflow`

Gates:
- `project_workflow_mode` (workflow_mode): Manual Mode, Auto Mode, Looping Mode
- `project_issue_resolution_route` (data_selection): Project Resolve, Project Orchestrate, Review First

Next routes: `setup-project`, `brainstorm-spec`, `audit-project`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, `align-project`, `loop-controller`

## `$superpowers-project:loop-controller`

Repeated workflow coordination across candidates with run ledgers, budgets, verifier proof, metrics, and policy continuation.

Owner: `loop-controller`

Gates:
- `project_loop_final_health_gate` (final_health): Done, Revisit, Stop

Next routes: `brainstorm-spec`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, `audit-project`, `align-project`

## `$superpowers-project:merge-changes`

Review, approve, merge, clean up, close linked issues, and record final proof for PR-ready or local branch work.

Owner: `merge-changes`

Gates:
- `project_merge_approval` (approval): Merge, Decline
- `project_merge_continue_group` (data_selection): Continue Issues, Start Planning
- `project_merge_final_health_gate` (final_health): Done, Revisit, Stop
- `project_merge_issue_route` (data_selection): Resolve Another, Orchestrate Another
- `project_merge_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_merge_planning_route` (data_selection): Plan Next, Brainstorm Next
- `project_merge_reiteration_group` (nested_revisit_route): Review Closeout, Repair / Audit Closeout
- `project_merge_repair_cleanup_route` (nested_revisit_route): Repair Drift, Re-run Cleanup
- `project_merge_repair_route` (nested_revisit_route): Run Align, Repair Or Cleanup

Next routes: `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `align-project`

## `$superpowers-project:orchestrate-issues`

Delegate a ready issue to a Codex worktree worker while the current thread reviews and integrates.

Owner: `orchestrate-issues`

Gates:
- `project_orchestrate_integration_route` (data_selection): Merge, Start More Worker Work
- `project_orchestrate_more_worker_route` (data_selection): Resolve Another Worker Issue, Start Another Worker
- `project_orchestrate_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_orchestrate_reiteration_route` (nested_revisit_route): Recover Audit Workers, Worker Communication
- `project_orchestrate_worker_communication_route` (nested_revisit_route): Ask Worker, Reassign Work

Next routes: `merge-changes`, `resolve-issue`

## `$superpowers-project:resolve-issue`

Direct current-thread implementation for one ready GitHub issue mirror.

Owner: `resolve-issue`

Gates:
- `project_resolve_another_issue_route` (data_selection): Resolve Another, Orchestrate Another
- `project_resolve_fix_route` (nested_revisit_route): Revise Branch, Address CI / Checks
- `project_resolve_integration_route` (data_selection): Merge, Continue Another Issue
- `project_resolve_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_resolve_push_permission` (permission): Push And Open PR, Hold
- `project_resolve_reiteration_route` (nested_revisit_route): Review First, Revise Or Fix Branch

Next routes: `merge-changes`, `resolve-issue`, `orchestrate-issues`

## `$superpowers-project:setup-project`

Create or maintain setup, milestone map, tracker config, project board configuration, and roadmap artifacts.

Owner: `setup-project`

Gates:
- `project_setup_board_approval` (approval): Create Board, Verify Only, Stop
- `project_setup_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_setup_reiteration_group` (nested_revisit_route): Review / Revise Setup, Run Align
- `project_setup_reiteration_route` (nested_revisit_route): Review Setup, Revise Setup
- `project_setup_work_route` (data_selection): Brainstorm New Spec, Write Plan, Create Issues

Next routes: `brainstorm-spec`, `align-project`

## `$superpowers-project:write-plan`

Turn approved specs or issue mirrors into detailed implementation plans.

Owner: `write-plan`

Gates:
- `project_plan_issue_count` (data_selection): One Issue, Multiple Issues
- `project_plan_issue_count_multiple` (data_selection): Two Issues, Three Or More
- `project_plan_issue_execution_route` (data_selection): Resolve Issue, Orchestrate Issues
- `project_plan_next_step` (top_level_continuation): Yes, Revisit, Stop
- `project_plan_review_grill_route` (nested_revisit_route): Review First, Re-run Planning Grill
- `project_plan_review_route` (nested_revisit_route): Revise Plan, Review Or Grill
- `project_plan_work_route` (data_selection): Project Issue First, Project Implement, Use Ready Issue

Next routes: `create-issues`, `implement-plan`, `resolve-issue`, `orchestrate-issues`
