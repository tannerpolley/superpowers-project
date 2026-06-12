---
name: implement-plan
description: Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof.
---

# Implement Plan

Implement Plan is the Superpowers Project adapter for `superpowers:executing-plans` on non-issue approved plans. Use it when an approved plan under `docs/superpowers/plans` should be executed without creating a GitHub issue. It does not create issue mirrors and must not claim GitHub issue closure.

**Announce at start:** "I'm using the implement-plan skill with superpowers:executing-plans to execute this approved plan without creating a GitHub issue."

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A local merge, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question. Final completion must use an explicit final health gate with `Done`, not a `Yes` option. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Required Inputs

Require an approved plan path under `docs/superpowers/plans`. If the request names a loose idea, spec, issue mirror, or external document instead of an approved plan, route to `$superpowers-project:write-plan` or `$superpowers-project:create-issues` as appropriate before execution.

Require native `/goal` activation before code changes. The goal must name the approved plan path and the intended execution route. Record proof as structured evidence, not a prose claim.

## Task # Use Cases Gate

Task # Use Cases are a strict requirement before actual plan implementation. Before creating branches, activating worker handoffs, or editing code, run the repo-root validator against the approved plan:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <approved-plan-path>
```

Every numbered `Task N` in the approved plan MUST include a non-empty `**Use Cases:**` block with concrete user, system, acceptance, failure/recovery, validation, or workflow cases. If validation fails, stop before implementation and route back to `$superpowers-project:write-plan` with `Revise Plan`. Do not convert missing use cases into an implementation assumption, worker note, or deferred cleanup item.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization` before execution. Validate it with the plugin-provided Auto Mode validator (`scripts/validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `merge_permission.selected_mode: preauthorized-after-clean-premerge`, and `stop_outside_policy: true`.

Auto Mode may select inline execution, create or verify native goal proof, use the approved plan proof oracle, run verification, run the cleanup hook, and prepare merge-ready output without additional user input when those actions stay inside the ledger policy. Auto Mode must still record the topology, verification receipts, cleanup evidence, and merge-ready proof. If the plan needs a decision outside the recorded defaults policy, verification fails, the repo is dirty in an unsafe way, or merge-ready proof is missing, stop outside policy before code changes, publish, or merge handoff.

## Non-Issue Boundary

This route is for branch-backed plan implementation without a GitHub issue. Do not create issue mirrors, do not hydrate GitHub issues, do not open pull requests, and do not claim issue closure in commits, ledgers, or handoffs. Pull request routes are allowed only for issue-backed work with a companion issue mirror.

Use the issue-backed `$superpowers-project:create-issues` and `$superpowers-project:resolve-issue` route when the work should close a GitHub issue, needs tracker ownership, or should be split into multiple issue mirrors.

## Execution Gate

Before edits, create or switch to a development branch. Never implement this route directly on `main`.

When `request_user_input` is callable, ask native execution topology before starting implementation:

Question id: `implement_plan_topology`

Prompt: `How should this approved plan be implemented?`

Options:

- `Inline`: implement in this thread on a development branch.
- `Worker`: delegate to a worker thread with an explicit plan handoff and reporting path.
- `Stop`: stop without edits.

Only use worker mode when the worker handoff names the orchestrator, role, plan path, branch, reporting path, and reason the worker may ask for `request_agent_input`. Otherwise fail loudly and use inline execution only after native approval.

## Superpowers Method Contract

This skill is the Superpowers Project adapter for `superpowers:executing-plans` on non-issue approved plans. The method pairing is mandatory:

- Always use `superpowers:executing-plans` as the base implementation workflow.
- Require `superpowers:test-driven-development` for feature and bug work unless the approved plan records an explicit opt-out.
- Require `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, CI failures, performance work, or unclear failure modes.
- Require `superpowers:verification-before-completion` before any success claim, commit, or local merge.
- If worker topology is selected, require `superpowers:subagent-driven-development` for delegation and reporting discipline.

Do not treat these companion skills as optional suggestions. If a required companion skill cannot be applied, stop and report the blocker instead of silently continuing with ad hoc execution.

## Implementation Discipline

Follow the approved plan's proof oracle. If a task needs a decision that the plan did not make, ask through native UI when callable and stop until the decision is answered. Do not invent broad policy during implementation.

## Push Permission Gate

After focused verification and cleanup evidence exist, complete the artifact review gate before asking native push permission. Strict artifact display is mandatory before push. Do not merely say something changed or that tests passed. Show the full changed-artifact inventory, exact paths, changed sections or representative diffs/snippets, verification commands, exact test values/results, cleanup evidence, branch state, and any merge-ready drafts before asking whether to push. If a changed artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative diff or snippet, and why the full render is omitted. After artifacts are shown, add a separate findings summary that states what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and why push is or is not the next safe step. Do not ask for push approval first and explain later. After that review, ask native push permission before pushing the branch, preparing merge-ready output, or holding the branch:

Question id: `implement_plan_push_permission`

Prompt: `Should I push this implementation branch before merge routing?`

Options:

- `Push Branch`: push the development branch and continue toward merge-ready evidence.
- `Hold`: stop with the branch preserved.

Only `Push Branch` records `selected_action: push-branch`. Only `Hold` records `selected_action: hold`. Merge routing is unavailable until this push gate is answered and, when approved, the branch push proof exists.

## Merge-Ready Output

Produce a merge-ready handoff that includes:

- approved plan path
- branch name and commit list
- verification commands and results
- cleanup hook result
- push permission ledger
- branch push proof
- merge mode `local-branch`
- explicit statement that no issue mirror was created, no pull request was opened, and no GitHub issue closure is claimed

Route merge-ready output to `$superpowers-project:merge-changes` or another approved merge route in `local-branch` mode only.

## Native Continuation Gate

After focused verification, cleanup, push permission, branch push proof, and merge-ready proof exist, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed implementation artifact, including the approved plan path, changed files, changed sections or representative diffs/snippets, branch, commit list, verification commands, exact test values/results, cleanup hook status, push decision, branch push status, merge-ready proof, merge mode, and the fact that no issue mirror was created and no pull request was opened. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative diff or snippet, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names the approved plan path, branch, commit list, verification status, cleanup hook status, push decision, branch push status, merge mode, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Do not recommend Stop merely because the branch is clean, validated, or already pushed when merge-ready routing is the authorized next step and the user has not asked to stop. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_implement_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: start `$superpowers-project:merge-changes` with the merge-ready proof.
- Revisit: review, fix, rerun verification, or update push permission.
- Stop: break the continuation loop.

If the user selects `Revise / Review Branch`, ask:

Question id: `project_implement_reiteration_route`

Prompt: `How should I revisit this implemented plan?`

Options:

- `Revise Branch`: continue implementation on the current development branch.
- `Review Evidence`: show the rendered handoff and verification evidence, then return to `project_implement_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the approved plan path, branch, verification evidence, push permission ledger, branch push proof, and merge-ready proof. Do not only tell the user what to prompt next.

## Contract Helper

Use `skills/implement-plan/scripts/lib/contract.ps1` to validate structured handoff ledgers in tests or worker closeout automation. The helper requires the approved plan, native `/goal` activation, a development branch, topology selection, passed verification, native push permission, branch push proof, merge-ready evidence, and no issue closure claim.
