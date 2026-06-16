---
name: initiate-workflow
description: Route Superpowers Project extension requests to project setup, brainstorming, audits, planning, issue creation, issue triage, alignment, or goal-backed resolution workflows.
---

# Initiate Workflow

This skill is the router for the Superpowers Project extension. It does not replace Superpowers. It routes project-backed work to extension skills and routes method work to Superpowers skills.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question. Final completion must use an explicit final health gate with `Done`, not a `Yes` option. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Workflow Mode Gate

Before task routing, ask native question `project_workflow_mode`.

Prompt: `How should I run this Superpowers Project workflow?`

Options:

- `Manual Mode`: ask at each material route, mutation, and closeout decision.
- `Auto Mode`: one-route autonomy using recorded defaults and validator-backed proof; it must stop at route closeout and must not continue to another candidate.
- `Looping Mode`: bounded repeated maintenance autonomy; create or validate a workflow mode ledger, then route to `$superpowers-project:loop-controller`.

Record a workflow mode ledger under `.superpowers/runs/<run-id>/workflow-mode-ledger.json` and validate it with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-mode-ledger.ps1 -RepoRoot <active repo> -ModeLedgerPath <ledger>
```

Canonical marker: `scripts/validate-workflow-mode-ledger.ps1`.

Recommend `Manual Mode` when the user has not asked for autonomy. Recommend `Auto Mode` only when one route is clear and source evidence is already strong. Recommend `Looping Mode` when the user asks to operate, maintain, drain issues, keep going, resolve a queue, or run broad project maintenance.

## Routing

- Project setup, roadmap context, tracker board setup, or large-scope project map: `$superpowers-project:setup-project`
- Brainstorming, specs, PRDs, broad product design, architecture design, or any unresolved early project decision for new work: `$superpowers-project:brainstorm-spec`
- Codebase audit, workflow review, diagnosis findings, maintainability findings, architecture findings, or existing behavior that should become a repair spec: `$superpowers-project:audit-project`
- Implementation planning from a spec, issue mirror, or approved direct request: `$superpowers-project:write-plan`
- Branch-backed implementation of an approved plan without a GitHub issue: `$superpowers-project:implement-plan`
- Issue decomposition, GitHub issue creation, issue mirror creation, or milestone assignment: `$superpowers-project:create-issues`
- External GitHub issue hydration, `Source Plan: TBD`, or a GitHub issue that exists before a local mirror and source plan: `$superpowers-project:create-issues`
- One ready issue execution in the current thread with native `/goal` proof: `$superpowers-project:resolve-issue`
- Worker-thread implementation of one ready issue: `$superpowers-project:orchestrate-issues`
- PR URL, worker handoff, merge approval, issue close verification, branch/worktree cleanup, or clean repo proof: `$superpowers-project:merge-changes`
- Structure alignment, migration, label review, milestone review, tracker alignment, issue mirror alignment, or live sync review: `$superpowers-project:align-project`
- Broad repeated maintenance, issue queue draining, stale-version repair loops, audit/align candidate queues, or "operate this project" requests in `Looping Mode`: `$superpowers-project:loop-controller`

The issue-backed `$superpowers-project:create-issues` plus `$superpowers-project:resolve-issue` or `$superpowers-project:orchestrate-issues` execution path remains the default for non-trivial work, risky changes, multi-issue scope, and anything that needs GitHub issue or milestone backbone. Use `$superpowers-project:implement-plan` for approved plan implementation that should use a development branch but should not create issue mirrors.

After `$superpowers-project:brainstorm-spec` saves a spec, Auto Mode may be authorized only through native question `project_auto_mode_authorization` with `Bounded Auto Merge`. That route records an Auto Mode authorization ledger validated by the plugin-provided Auto Mode validator (`scripts/validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the agent then chooses between planning, direct inline issue resolution through `$superpowers-project:resolve-issue`, direct plan implementation, verification, merge, and closeout proof within the recorded defaults. Auto Mode is one-route autonomy: if proof is missing, validation fails, GitHub state is unsafe, the route reaches closeout, the route needs a decision outside the ledger policy, or the agent would need to continue to another candidate, stop outside policy instead of inventing a new approval.

External GitHub issues are intake, not ready execution mirrors. If the user asks to resolve or orchestrate a GitHub issue URL whose local mirror or source plan does not exist, route through `$superpowers-project:create-issues` hydration first and block execution until mirror validation passes.

When the user asks to resolve an issue without naming a route, ask native question `project_issue_resolution_route` with `Project Resolve`, `Project Orchestrate`, and `Review First` options. Route direct current-thread implementation to `$superpowers-project:resolve-issue`; route delegated worker worktree implementation to `$superpowers-project:orchestrate-issues`.

## Artifact Root

Canonical project artifacts live under `docs/superpowers`.

- Project context: `docs/superpowers/PROJECT_CONTEXT.md`
- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

## Method Routing

Routing is not complete until the project skill and its required Superpowers companion skills are both selected. These pairings are mandatory, not suggestions:

- `$superpowers-project:brainstorm-spec` -> `superpowers:brainstorming`
- `$superpowers-project:audit-project` -> `diagnose` for bugs, regressions, CI failures, performance work, or unclear failure modes; `thermo-nuclear-code-quality-review` for strict maintainability findings; `improve-codebase-architecture` for architecture and module-boundary findings; and framework doctors such as `react-doctor` when applicable
- `$superpowers-project:write-plan` -> `superpowers:writing-plans`
- `$superpowers-project:implement-plan` -> `superpowers:executing-plans` as the base workflow, plus `superpowers:test-driven-development` for feature or bug work unless the approved plan records an explicit opt-out, `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, CI failures, performance work, or unclear failure modes, `superpowers:verification-before-completion` before any success claim, commit, or merge-ready handoff, and `superpowers:subagent-driven-development` when worker topology is selected
- `$superpowers-project:create-issues` -> emit issue metadata that keeps downstream routing compatible with the mandatory Superpowers companion skills used by `$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues`
- `$superpowers-project:resolve-issue` -> `superpowers:using-git-worktrees`, `superpowers:executing-plans`, `superpowers:test-driven-development` unless the source plan records an explicit opt-out, `superpowers:systematic-debugging` or `diagnose` when the issue is a bug, regression, CI, performance, or unclear failure case, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`
- `$superpowers-project:orchestrate-issues` -> `superpowers:subagent-driven-development` for delegated orchestration, with worker handoffs that require `superpowers:using-git-worktrees`, `superpowers:executing-plans` or `superpowers:subagent-driven-development`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`
- `$superpowers-project:merge-changes` -> `superpowers:finishing-a-development-branch` as the closeout method, with upstream `superpowers:verification-before-completion` proof already satisfied
- `$superpowers-project:loop-controller` -> existing project skills and their required Superpowers companion methods; Loop Controller coordinates the run but does not replace the work-owning skill or its proof gate

Do not claim a project route is active if the required Superpowers companion method is omitted.

## Continuation Routing

At major handoffs, use native continuation questions and treat the selected answer as executable routing. The agent should start the selected next skill in the same turn when possible instead of ending with a prompt suggestion.

## Native Continuation Gate

After routing or preparing the next project workflow, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed routing artifact, including saved specs, plans, issue mirrors, route-decision evidence, and any machine-readable artifacts when present. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names the changed or verified artifacts, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

When `request_user_input` is callable, ask the skill-specific native continuation question using flowchart geometry. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. After Yes, ask the nested progress route question when multiple next skills are possible. After Revisit, show evidence or rendered artifacts, ask the nested review/revision question when needed, and return to the originating continuation gate. Nested Yes-route menus must not include terminal options and should list only forward routes. Nested Revisit-route menus must not include terminal options and should list only revisit, repair, rerun, recovery, review, or evidence routes. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Use `advanced-user-input` sequential branching when the first answer changes which follow-up questions matter.

Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other. Otherwise treat Custom Other as input for the next best follow-up question, a custom child question, or the baseline nested route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate. Treat selected native answers as executable routing: start the selected next skill in the same turn when tools and state allow it.

If routing cannot continue because tools, permissions, GitHub state, or user approval are missing, ask the next native question when one can resolve it, or stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests and never counts as live approval.

## Native User Input

When the task needs user choices and the `request_user_input` tool is callable, use it from Default mode for concise, decision-oriented questions. Batch independent questions together. Use more than three options only for nested branch menus, data-backed selections, or independent bulk gates where the larger menu preserves the real decision. Ask dependent questions one step at a time after the prior answer changes the branch.

For `$superpowers-project:brainstorm-spec`, use native UI more aggressively: if there is any unresolved idea, naming, scope, tradeoff, route, or assumption decision, inspect project context and relevant code first, then ask through `request_user_input` instead of resolving the decision in prose.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not route into mutation or pretend a live user approved workflow scope, publication, execution, or setup.
## Goal Routing

Issue implementation must use `$superpowers-project:resolve-issue` and native `/goal` activation or goal-tool proof before implementation begins. Goal success criteria come from the issue mirror acceptance checklist and the linked source plan. After `$superpowers-project:resolve-issue` creates PR-ready evidence, final integration must route to `$superpowers-project:merge-changes`.
