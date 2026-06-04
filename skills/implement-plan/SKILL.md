---
name: implement-plan
description: Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof.
---

# Implement Plan

Implement Plan is the non-issue execution route for an approved plan under `docs/superpowers/plans`. It does not create issue mirrors and must not claim GitHub issue closure.

**Announce at start:** "I'm using the implement-plan skill to execute this approved plan without creating a GitHub issue."

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A local merge, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Required Inputs

Require an approved plan path under `docs/superpowers/plans`. If the request names a loose idea, spec, issue mirror, or external document instead of an approved plan, route to `$superpowers-project:write-plan` or `$superpowers-project:create-issues` as appropriate before execution.

Require native `/goal` activation before code changes. The goal must name the approved plan path and the intended execution route. Record proof as structured evidence, not a prose claim.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization` before execution. Validate it with `the repo-root Auto Mode contract helper`; the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `merge_permission.selected_mode: preauthorized-after-clean-premerge`, and `stop_outside_policy: true`.

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

## Implementation Discipline

Use `superpowers:test-driven-development` for feature and bug work unless the approved plan explicitly opted out. Use `superpowers:executing-plans` to execute the plan task-by-task, and use `superpowers:verification-before-completion` before any success claim, commit, or local merge.

Follow the approved plan's proof oracle. If a task needs a decision that the plan did not make, ask through native UI when callable and stop until the decision is answered. Do not invent broad policy during implementation.

## Local Merge Permission Gate

After focused verification and cleanup evidence exist, ask native local merge permission before preparing local merge-ready output or holding the branch:

Question id: `implement_plan_publish_permission`

Prompt: `How should I finish this implemented plan?`

Options:

- `Local Merge Ready`: keep the development branch local and produce merge-ready evidence.
- `Hold`: stop with the branch preserved.

Only `Local Merge Ready` records `selected_action: local-merge-ready`. Only `Hold` records `selected_action: hold`.

## Merge-Ready Output

Produce a merge-ready handoff that includes:

- approved plan path
- branch name and commit list
- verification commands and results
- cleanup hook result
- publish permission ledger
- merge mode `local-branch`
- explicit statement that no issue mirror was created, no pull request was opened, and no GitHub issue closure is claimed

Route merge-ready output to `$superpowers-project:merge-changes` or another approved merge route in `local-branch` mode only.

## Native Continuation Gate

After focused verification, cleanup, local merge permission, and merge-ready proof exist, summarize the branch result in chat before asking the continuation question. The summary must name the approved plan path, branch, commit list, verification status, cleanup hook status, local merge decision, merge mode, and the fact that no issue mirror was created and no pull request was opened. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and No in the same top-level question. Do not show Continue children as peer top-level options. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include Stop / Done; they include only real forward routes. Nested Revisit-route menus must not include Stop / Done; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Recommend No / Stop / Done only for explicit terminal, blocker, or user-requested stop states. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_implement_next_step`

Prompt: `How should I continue from this implemented plan?`

Options:

- Down: `Merge Implemented Plan`: start `$superpowers-project:merge-changes` with the merge-ready proof.
- Left: `Revise / Review Branch`: review, fix, rerun verification, or update publish permission.
- Right: `Stop`: break the continuation loop.

If the user selects `Revise / Review Branch`, ask:

Question id: `project_implement_reiteration_route`

Prompt: `How should I revisit this implemented plan?`

Options:

- Down: `Revise Branch`: continue implementation on the current development branch.
- Left: `Review Evidence`: show the rendered handoff and verification evidence, then return to `project_implement_next_step`.
- Right: `Stop`: break the continuation loop.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the approved plan path, branch, verification evidence, local merge permission ledger, and merge-ready proof. Do not only tell the user what to prompt next.

## Contract Helper

Use `skills/implement-plan/scripts/lib/contract.ps1` to validate structured handoff ledgers in tests or worker closeout automation. The helper requires the approved plan, native `/goal` activation, a development branch, topology selection, passed verification, native publish permission, merge-ready evidence, and no issue closure claim.
