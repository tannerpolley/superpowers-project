# Superpowers Project Outcome Workflow

> Generated from repo source by `scripts/generate-outcome-workflow-summary.ps1`. Do not edit by hand.

## Canonical Identity

- Plugin manifest name: `superpowers-project`
- User-facing prompt namespace: `$superpowers-project:*`
- Source repo: `tannerpolley/superpowers-project`

## Artifact Roots

- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone index pages: `docs/superpowers/milestones/`

## Plan Task Use Cases

- `Task # Use Cases` is a strict requirement for plan making, plan implementation, and issue resolution.
- Every numbered `Task N` in an implementation plan must include a non-empty `**Use Cases:**` block before files and steps.
- `scripts/validate-plan-task-use-cases.ps1 -PlanPath <plan>` is mandatory before a plan is ready, before `$superpowers-project:implement-plan` edits code, and before `$superpowers-project:resolve-issue` executes a linked source plan.

## Outcome Proof And Readiness Review

- Plans require an `Outcome Proof` and `Implementation Boundaries` before implementation.
- `scripts/validate-plan-outcome-proof.ps1 -PlanPath <plan>` validates intent, owner, interface, cutover, replaced path, evidence, acceptance proof, stop criteria, avoid, risk, and implementation boundary fields.
- Issue mirrors must include an `Outcome Summary` derived from the approved source plan.
- `$superpowers-project:implement-plan` and `$superpowers-project:resolve-issue` carry structured `outcome_proof` proof through execution ledgers.
- `$superpowers-project:merge-changes` requires structured `readiness_review` proof before merge approval.
- `readiness_review` must show `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` all true.

## Terminal Model

- Intermediate workflow gates use `Yes`, `Revisit`, and `Stop`.
- Verified final health gates use `Done`, `Revisit`, and `Stop`.
- `Done` is valid only after final proof and a clean worktree.
- Custom Other never terminates directly; re-ask with built-in terminal labels when needed.
- A saved spec, saved plan, created issue set, pushed branch, merged branch, completed audit, or synced live plugin is not terminal by itself.

## Workflow Modes

- `project_workflow_mode` is mandatory in `$superpowers-project:initiate-workflow` before task routing.
- `Manual Mode` asks at each material route, mutation, and closeout decision.
- `Auto Mode` is one-route autonomy only; it must stop at route closeout and must not continue to another candidate.
- `Looping Mode` is bounded repeated maintenance autonomy; it routes through `$superpowers-project:loop-controller` to select one ready candidate at a time, route the actual work to the owning skill, and re-check budget before another candidate.
- Workflow mode ledgers record `selected_mode`, repo identity, plugin manifest version, `contract_hash`, autonomy scope, mutation scope, route policy, proof policy, stop conditions, and downstream ledger paths.
- Validate workflow mode ledgers with `scripts/validate-workflow-mode-ledger.ps1 -RepoRoot <active repo> -ModeLedgerPath <ledger>`.

## Workflow Skills

| Skill | Purpose | Native Question IDs | Final Health Gate |
|---|---|---|---|
| `align-project` | Use when a Superpowers Project repo needs structure alignment, migration review, tracker alignment, live sync verification, or repair planning. | `project_align_final_health_gate`<br>`project_align_next_step`<br>`project_align_plan_issue_route`<br>`project_align_prepare_route`<br>`project_align_reiteration_route`<br>`project_align_repair_group`<br>`project_align_review_evidence_route` | `project_align_final_health_gate` |
| `audit-project` | Use when code, workflows, tests, skills, or repo behavior need evidence-backed review findings before repair planning. | `project_audit_next_step`<br>`project_audit_progress_route`<br>`project_audit_revisit_route`<br>`project_auto_mode_authorization` | `None` |
| `brainstorm-spec` | Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need Superpowers brainstorming plus project context and native user-input grilling. | `project_brainstorm_multi_spec_route`<br>`project_brainstorm_next_step`<br>`project_brainstorm_plan_route`<br>`project_brainstorm_reiteration_route`<br>`project_brainstorm_review_restart_route` | `None` |
| `companion-interface` | Use when a Superpowers Project workflow should create or update repo-owned Agent-Native visual-plan or visual-recap MDX artifacts for rich review. | None | `None` |
| `create-issues` | Use when a Superpowers Project spec, plan, PRD, or approved scope needs vertical-slice GitHub issues and synced issue mirrors. | `project_issue_execution_route`<br>`project_issue_next_step`<br>`project_issue_orchestrate_route`<br>`project_issue_reiteration_route`<br>`project_issue_resolve_route`<br>`project_issue_review_repair_route` | `None` |
| `implement-plan` | Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof. | `implement_plan_push_permission`<br>`implement_plan_topology`<br>`project_implement_next_step`<br>`project_implement_reiteration_route` | `None` |
| `initiate-workflow` | Route Superpowers Project extension requests to project setup, brainstorming, audits, planning, issue creation, issue triage, alignment, or goal-backed resolution workflows. | `project_auto_mode_authorization`<br>`project_workflow_mode` | `None` |
| `loop-controller` | Use when Superpowers Project should coordinate repeated workflow runs across candidates while preserving Auto Mode authorization and native approval gates. | `project_loop_final_health_gate`<br>`project_loop_next_step` | `project_loop_final_health_gate` |
| `merge-changes` | Use when a Superpowers Project issue-backed PR, worker handoff, or approved local branch must be reviewed, approved, merged, cleaned up, and recorded with clean repo proof. | `project_merge_approval`<br>`project_merge_continue_group`<br>`project_merge_final_health_gate`<br>`project_merge_issue_route`<br>`project_merge_next_step`<br>`project_merge_planning_route`<br>`project_merge_reiteration_group`<br>`project_merge_repair_cleanup_route`<br>`project_merge_repair_route` | `project_merge_final_health_gate` |
| `orchestrate-issues` | Use when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread while the current thread acts as orchestrator and reviewer. | `project_orchestrate_integration_route`<br>`project_orchestrate_more_worker_route`<br>`project_orchestrate_next_step`<br>`project_orchestrate_reiteration_route`<br>`project_orchestrate_worker_communication_route` | `None` |
| `resolve-issue` | Use when one ready GitHub issue mirror under docs/superpowers/issues must be implemented directly in the current thread through native goal activation, Superpowers execution, pushed branch, opened PR, and PR-ready handoff. | `project_resolve_another_issue_route`<br>`project_resolve_fix_route`<br>`project_resolve_integration_route`<br>`project_resolve_next_step`<br>`project_resolve_push_permission`<br>`project_resolve_reiteration_route` | `None` |
| `setup-project` | Create or maintain the Superpowers Project setup, milestone map, GitHub tracker configuration, GitHub Project board configuration, and roadmap artifacts under docs/superpowers. | `project_setup_next_step`<br>`project_setup_reiteration_group`<br>`project_setup_reiteration_route`<br>`project_setup_work_route` | `None` |
| `write-plan` | Use when an approved Superpowers Project spec or issue mirror needs a detailed implementation plan before code changes. | `project_plan_issue_count`<br>`project_plan_issue_count_multiple`<br>`project_plan_issue_execution_route`<br>`project_plan_next_step`<br>`project_plan_review_grill_route`<br>`project_plan_review_route`<br>`project_plan_work_route` | `None` |

## Approval Boundaries

- Push, publish, merge, board creation, GitHub mutation, and final `Done` require explicit proof and the owning native gate.
- `project_merge_approval` is the merge approval gate.
- `project_auto_mode_authorization` can authorize bounded Auto Mode only when the plugin-provided Auto Mode validator passes.
- Validate Auto Mode ledgers with `<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>` from the loaded Superpowers Project plugin root.
- Helper scripts may prepare evidence, but they must not convert missing approval into approval.

## Debug Mode

- `debug_question_mode` is only for explicit non-interactive smoke tests or proven stuck background prompts.
- Required ledger fields include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source`, `no_answer_tool_available: true`, and `mutation_allowed: false`.
- Debug mode must not approve mutation.

## Live Sync

- Source repo is authoritative.
- Live deployed plugin copy is checked by `scripts/sync-live.ps1 -Validate`.
- Plugin cache paths are not durable contracts.
- Validated live sync refreshes matching local plugin cache roots when they already exist, so existing threads can see updated files when they re-read plugin skill bodies.
- Already-loaded prompt text cannot be rewritten inside an existing agent context; a stale observed root after sync still requires a fresh agent session.

## Startup Version Check

- At Superpowers Project startup, agents must run `scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent` and print the banner before selecting a project workflow route.
- If the active agent knows its loaded plugin or skill root, it must also pass `-ObservedPluginRoot` or `-ObservedSkillRoot`.
- The banner reports the manifest version, source commit, source dirty state, `contract_hash`, source/live freshness, observed-root freshness, and stale cache candidate count.

## Agent Version Tracking

- Exact runtime identity is the plugin manifest version plus the runtime `contract_hash`.
- `scripts/get-agent-plugin-version.ps1 -RequireCurrent` compares source, live install, optional observed plugin or skill root, and local cache candidates.
- Use `-ObservedPluginRoot` or `-ObservedSkillRoot` when an agent needs to prove the exact loaded copy it is using.
- If source and live are current but the observed surface differs, run validated live sync to refresh live install and matching local plugin cache roots, then start a fresh agent session if the observed surface still differs.

## Validation Commands

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-outcome-workflow-summary.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -RequireCurrent`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\detect-stale-skill-contract.ps1 -SkillName brainstorm-spec -ExpectedQuestionId project_brainstorm_plan_route`
