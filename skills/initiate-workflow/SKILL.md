---
name: initiate-workflow
description: Route Superpowers Project extension requests to project setup, brainstorming, planning, issue creation, issue triage, doctor, or goal-backed resolution workflows.
---

# Initiate Workflow

This skill is the router for the Superpowers Project extension. It does not replace Superpowers. It routes project-backed work to extension skills and routes method work to Superpowers skills.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Routing

- Project setup, roadmap context, tracker board setup, or large-scope project map: `$project:setup-project`
- Brainstorming, specs, PRDs, broad product design, architecture design, or any unresolved early project decision: `$project:brainstorm-spec`
- Implementation planning from a spec, issue mirror, or approved direct request: `$project:write-plan`
- Branch-backed implementation of an approved plan without a GitHub issue: `$project:implement-plan`
- Issue decomposition, GitHub issue creation, issue mirror creation, or milestone assignment: `$project:create-issues`
- External GitHub issue hydration, `Source Plan: TBD`, or a GitHub issue that exists before a local mirror and source plan: `$project:create-issues`
- One ready issue execution in the current thread with native `/goal` proof: `$project:resolve-issue`
- Worker-thread implementation of one ready issue: `$project:orchestrate-issues`
- PR URL, worker handoff, merge approval, issue close verification, branch/worktree cleanup, or clean repo proof: `$project:merge-changes`
- Drift audit, migration, label review, milestone review, or live sync review: `$project:audit-project`

The issue-backed `$project:create-issues` plus `$project:resolve-issue` or `$project:orchestrate-issues` execution path remains the default for non-trivial work, risky changes, multi-issue scope, and anything that needs GitHub issue or milestone backbone. Use `$project:implement-plan` for approved plan implementation that should use a development branch but should not create issue mirrors.

After `$project:brainstorm-spec` saves a spec, Auto Mode may be authorized only through native question `project_auto_mode_authorization` with `Bounded Auto Merge`. That route records an Auto Mode authorization ledger validated by `scripts/lib/auto-mode-contract.ps1`; the agent then chooses between planning, issue-backed orchestration, direct plan implementation, verification, merge, and closeout proof within the recorded defaults. If proof is missing, validation fails, GitHub state is unsafe, or the needed decision falls outside the ledger policy, stop outside policy instead of inventing a new approval.

External GitHub issues are intake, not ready execution mirrors. If the user asks to resolve or orchestrate a GitHub issue URL whose local mirror or source plan does not exist, route through `$project:create-issues` hydration first and block execution until mirror validation passes.

When the user asks to resolve an issue without naming a route, ask native question `project_issue_resolution_route` with `Project Resolve`, `Project Orchestrate`, and `Review First` options. Route direct current-thread implementation to `$project:resolve-issue`; route delegated worker worktree implementation to `$project:orchestrate-issues`.

## Artifact Root

Canonical project artifacts live under `docs/superpowers`.

- Project context: `docs/superpowers/PROJECT_CONTEXT.md`
- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

## Method Routing

Use Superpowers skills for method: `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:subagent-driven-development`, and `superpowers:verification-before-completion`.

## Continuation Routing

At major handoffs, use native continuation questions and treat the selected answer as executable routing. The agent should start the selected next skill in the same turn when possible instead of ending with a prompt suggestion.

## Native Continuation Gate

Every Superpowers Project skill must summarize its artifact or result in chat before a closeout continuation question. The summary should name created or changed artifacts, validation or proof status, unresolved decisions, and the recommended next route. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when they were created or changed and are reasonably sized.

When `request_user_input` is callable, ask the skill-specific native continuation question using flowchart geometry. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and No in the same top-level question. Do not show Continue children as peer top-level options. After Yes, ask the nested progress route question when multiple next skills are possible. After Revisit, show evidence or rendered artifacts, ask the nested review/revision question when needed, and return to the originating continuation gate. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Use `advanced-user-input` sequential branching when the first answer changes which follow-up questions matter.

Custom Other is not terminal unless it explicitly asks to stop or be done. Otherwise treat Custom Other as input for the next best follow-up question, a custom child question, or the baseline nested route tree. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate. Treat selected native answers as executable routing: start the selected next skill in the same turn when tools and state allow it.

If routing cannot continue because tools, permissions, GitHub state, or user approval are missing, ask the next native question when one can resolve it, or stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests and never counts as live approval.

## Native User Input

When the task needs user choices and the `request_user_input` tool is callable, use it from Default mode for concise, decision-oriented questions. Batch independent questions together. Use more than three options only for nested branch menus, data-backed selections, or independent bulk gates where the larger menu preserves the real decision. Ask dependent questions one step at a time after the prior answer changes the branch.

For `$project:brainstorm-spec`, use native UI more aggressively: if there is any unresolved idea, naming, scope, tradeoff, route, or assumption decision, inspect project context and relevant code first, then ask through `request_user_input` instead of resolving the decision in prose.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger in the active smoke issue mirror or final smoke report. Each ledger entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults. Debug mode must not be used as a substitute for native UI in normal work; it is test-only evidence and never counts as a live user decision.

## Goal Routing

Issue implementation must use `$project:resolve-issue` and native `/goal` activation or goal-tool proof before implementation begins. Goal success criteria come from the issue mirror acceptance checklist and the linked source plan. After `$project:resolve-issue` creates PR-ready evidence, final integration must route to `$project:merge-changes`.






