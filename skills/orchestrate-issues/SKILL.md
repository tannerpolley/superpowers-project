---
name: orchestrate-issues
description: Use when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread while the current thread acts as orchestrator and reviewer.
---

# Project Orchestrate

This skill is the delegated Superpowers Project adapter for `superpowers:subagent-driven-development`. Use it when one ready GitHub issue mirror should be implemented by a separate Codex worker thread or worktree while the current thread owns orchestration, review, PR handoff intake, and routing to `$superpowers-project:merge-changes`.

`$superpowers-project:orchestrate-issues` does not replace `$superpowers-project:resolve-issue`. `$superpowers-project:resolve-issue` is the direct current-thread route. `$superpowers-project:orchestrate-issues` is the delegated worker-thread route.

**Announce at start:** "I'm using the orchestrate-issues skill with superpowers:subagent-driven-development for delegated issue execution."

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Hard Failures

Stop before creating a worker thread when any of these are true:

- The issue mirror is missing or outside `docs/superpowers/issues`.
- The source plan is missing.
- The target is only a raw GitHub issue URL, an external intake issue, or a mirror with `Source Plan: TBD`.
- The issue mirror is not ready for agent work.
- Native goal activation proof is missing in the orchestrator thread when the run is goal-backed.
- Worker identity cannot be derived from one canonical issue number and slug.
- A branch, thread title, evidence folder, or PR title would not match the derived worker identity.
- The user declines worker-thread execution, publication, recovery, or merge routing approval.
- The worker asks the orchestrator to merge without `$superpowers-project:merge-changes`.

## Runtime Order

1. `issue intake`: inspect one ready issue mirror under `docs/superpowers/issues`.
2. `route confirmation`: if the user did not already choose worker mode, ask native question `project_issue_resolution_route`.
3. `goal ownership`: create or verify the native goal in the orchestrator thread when the issue is AFK or goal-backed.
4. `worker identity`: run `scripts/derive-worker-identity.ps1`.
5. `handoff preparation`: run `scripts/prepare-worker-handoff.ps1`.
6. `worker thread creation`: create the Codex worktree worker with the derived thread title and branch name.
7. `worker instructions`: send the topology handoff and require Superpowers execution, TDD, verification, and branch finishing.
8. `progress monitoring`: wait for worker handoff, bounded heartbeat, or user resume.
9. `PR-ready intake`: validate worker PR-ready evidence and route the PR URL to `$superpowers-project:merge-changes`.
10. `closeout`: summarize the worker route and ask `project_orchestrate_next_step`.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with `the repo-root Auto Mode contract helper`; the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `route_policy.worker_route: issue-backed-orchestrate-only`, and `stop_outside_policy: true`.

Auto Mode may delegate worker-thread execution only for a ready issue mirror derived from the authorized source spec or plan. It may choose the first ready worker-suitable issue, derive worker identity, prepare the handoff, monitor the worker, validate PR-ready evidence, and route to merge without additional user input when the route stays inside the ledger policy. Do not create direct Auto Mode workers outside issue-backed orchestration. If worker recovery, reassignment, GitHub auth, missing proof, failed validation, or scope expansion needs a decision outside recorded defaults, stop outside policy and report the resume target.

## Worker Identity Contract

Use `scripts/derive-worker-identity.ps1 -RepoRoot . -IssueFile <docs/superpowers/issues/<issue>.md>` before creating the worker. The derived identity is canonical for the worker run:

- thread title: `Resolve #<issue-number>: <issue title>`
- branch name: `codex/issue-<issue-number>-<slug>`
- evidence folder: `orchestrate-issues-issue-<issue-number>-<slug>`
- PR title hint: `Resolve #<issue-number>: <issue title>`

Do not hand-edit these names after derivation. If the issue title or slug is wrong, fix the issue mirror first and rerun the script.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger entry. Each entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not create real worker threads, mutate GitHub, merge PRs, or pretend a live user approved delegated execution.

## Worker Handoff

Run `scripts/prepare-worker-handoff.ps1 -RepoRoot . -IssueFile <docs/superpowers/issues/<issue>.md> -OutputPath <temp-or-handoff-json>` before starting a worker. It validates the issue mirror, source plan, proof oracle, and derived worker identity, then emits a handoff ledger.

Run `scripts/validate-worker-handoff.ps1 -RepoRoot . -HandoffPath <handoff-json>` before sending the handoff to the worker.

## Superpowers Method Contract

This skill is the delegated Superpowers Project adapter for `superpowers:subagent-driven-development`. The orchestrator must use that delegation discipline, and the worker handoff must require this companion skill set:

- `superpowers:using-git-worktrees`
- `superpowers:test-driven-development`
- `superpowers:executing-plans` or `superpowers:subagent-driven-development`
- `superpowers:verification-before-completion`
- `superpowers:finishing-a-development-branch`

Do not create or launch a worker without this companion skill set in the handoff.

The worker must not merge the PR. The worker finishes by pushing the derived branch, opening a PR that closes the linked issue, and returning PR-ready handoff evidence to the orchestrator.

## External GitHub Issue Hydration

If the user gives only a GitHub issue URL, no local mirror exists, or the local mirror still has an unresolved source plan, hydrate the issue through `$superpowers-project:create-issues` before orchestration. Do not create a worker from raw GitHub issue text without a local mirror, source plan, and passing mirror validation.

## Native Continuation Gate

After PR-ready handoff intake, complete the artifact review gate before asking the continuation question. `$superpowers-project:orchestrate-issues` can only close out when all owned worktrees have permission to push their commits to the open PR or the user explicitly routes to recovery. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed orchestration artifact, including the issue mirror, derived branch, worker thread title, evidence folder, PR URL if available, worker-changed artifact inventory, verification evidence status, exact test values/results when provided by the worker, and machine-readable handoff ledgers. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names the issue mirror, derived branch, worker thread title, evidence folder, PR URL if available, verification evidence status, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If it appears to ask for Stop or Done, ask a fresh confirmation question instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_orchestrate_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: merge or continue worker-backed issue execution.
- Revisit: recover, ask worker/orchestrator questions, or reassign work.
- Stop: break the continuation loop.

If the user selects `Integrate Worker Output`, ask:

Question id: `project_orchestrate_integration_route`

Prompt: `What should happen with the worker output?`

Options:

- `Merge`: start `$superpowers-project:merge-changes` for the PR-ready handoff.
- `Start More Worker Work`: choose another worker-backed issue route.

If the user selects `Start More Worker Work`, ask:

Question id: `project_orchestrate_more_worker_route`

Prompt: `What worker-backed work should start next?`

Options:

- `Resolve Another Worker Issue`: start another worker-backed issue route when one is ready.
- `Start Another Worker`: create another worker thread for a selected ready issue.

If the user selects `Recover / Review Worker Route`, ask:

Question id: `project_orchestrate_reiteration_route`

Prompt: `How should I revisit this worker route?`

Options:

- `Recover Audit Workers`: audit and recover workers and worktrees.
- `Worker Communication`: ask the worker or reassign work.

If the user selects `Worker Communication`, ask:

Question id: `project_orchestrate_worker_communication_route`

Prompt: `How should worker communication continue?`

Options:

- `Ask Worker`: use `request_agent_input` when the current thread is orchestrating a worker.
- `Reassign Work`: stop the current worker route and reassign the issue through an approved route.

Treat selected native answers as executable routing, not advisory text. Start the selected next skill in the same turn when tools and state allow it.


