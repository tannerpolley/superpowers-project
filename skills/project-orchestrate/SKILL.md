---
name: project-orchestrate
description: Use when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread while the current thread acts as orchestrator and reviewer.
---

# Project Orchestrate

Use this skill when one ready GitHub issue mirror should be implemented by a separate Codex worker thread or worktree while the current thread owns orchestration, review, PR handoff intake, and routing to `$project-merge`.

`$project-orchestrate` does not replace `$project-resolve`. `$project-resolve` is the direct current-thread route. `$project-orchestrate` is the delegated worker-thread route.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or `Done`. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` or `Done` option is terminal. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

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
- The worker asks the orchestrator to merge without `$project-merge`.

## Runtime Order

1. `issue intake`: inspect one ready issue mirror under `docs/superpowers/issues`.
2. `route confirmation`: if the user did not already choose worker mode, ask native question `project_issue_resolution_route`.
3. `goal ownership`: create or verify the native goal in the orchestrator thread when the issue is AFK or goal-backed.
4. `worker identity`: run `scripts/derive-worker-identity.ps1`.
5. `handoff preparation`: run `scripts/prepare-worker-handoff.ps1`.
6. `worker thread creation`: create the Codex worktree worker with the derived thread title and branch name.
7. `worker instructions`: send the topology handoff and require Superpowers execution, TDD, verification, and branch finishing.
8. `progress monitoring`: wait for worker handoff, bounded heartbeat, or user resume.
9. `PR-ready intake`: validate worker PR-ready evidence and route the PR URL to `$project-merge`.
10. `closeout`: summarize the worker route and ask `project_orchestrate_next_step`.

## Worker Identity Contract

Use `scripts/derive-worker-identity.ps1 -RepoRoot . -IssueFile <docs/superpowers/issues/<issue>.md>` before creating the worker. The derived identity is canonical for the worker run:

- thread title: `Resolve #<issue-number>: <issue title>`
- branch name: `codex/issue-<issue-number>-<slug>`
- evidence folder: `project-orchestrate-issue-<issue-number>-<slug>`
- PR title hint: `Resolve #<issue-number>: <issue title>`

Do not hand-edit these names after derivation. If the issue title or slug is wrong, fix the issue mirror first and rerun the script.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger entry. Each entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not create real worker threads, mutate GitHub, merge PRs, or pretend a live user approved delegated execution.

## Worker Handoff

Run `scripts/prepare-worker-handoff.ps1 -RepoRoot . -IssueFile <docs/superpowers/issues/<issue>.md> -OutputPath <temp-or-handoff-json>` before starting a worker. It validates the issue mirror, source plan, proof oracle, and derived worker identity, then emits a handoff ledger.

Run `scripts/validate-worker-handoff.ps1 -RepoRoot . -HandoffPath <handoff-json>` before sending the handoff to the worker.

The worker handoff must instruct the worker to use:

- `superpowers:using-git-worktrees`
- `superpowers:test-driven-development`
- `superpowers:executing-plans` or `superpowers:subagent-driven-development`
- `superpowers:verification-before-completion`
- `superpowers:finishing-a-development-branch`

The worker must not merge the PR. The worker finishes by pushing the derived branch, opening a PR that closes the linked issue, and returning PR-ready handoff evidence to the orchestrator.

## External GitHub Issue Hydration

If the user gives only a GitHub issue URL, no local mirror exists, or the local mirror still has an unresolved source plan, hydrate the issue through `$project-issue` before orchestration. Do not create a worker from raw GitHub issue text without a local mirror, source plan, and passing mirror validation.

## Native Continuation Gate

After PR-ready handoff intake, summarize the worker route before asking the continuation question. `$project-orchestrate` can only close out when all owned worktrees have permission to push their commits to the open PR or the user explicitly routes to recovery. The summary must name the issue mirror, derived branch, worker thread title, evidence folder, PR URL if available, verification evidence status, and the recommended next route. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions with `request_user_input` when callable. Use flowchart geometry: Down is default progress, Left is revise/review/repair/rerun/recover, and Right is `Stop / Done`. Use as many native questions and options as the decision requires. Prefer the simple Down / Left / Right shape for generic continuation gates, but show all real peer routes when that is clearer. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree.

Question id: `project_orchestrate_next_step`

Prompt: `How should I continue from this worker route?`

Options:

- Down: `Integrate Worker Output`: merge or continue worker-backed issue execution.
- Left: `Recover / Review Worker Route`: recover, ask worker/orchestrator questions, or reassign work.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Integrate Worker Output`, ask:

Question id: `project_orchestrate_integration_route`

Prompt: `What should happen with the worker output?`

Options:

- Down: `Merge`: start `$project-merge` for the PR-ready handoff.
- Left: `Start More Worker Work`: choose another worker-backed issue route.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Start More Worker Work`, ask:

Question id: `project_orchestrate_more_worker_route`

Prompt: `What worker-backed work should start next?`

Options:

- Down: `Resolve Another Worker Issue`: start another worker-backed issue route when one is ready.
- Left: `Start Another Worker`: create another worker thread for a selected ready issue.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Recover / Review Worker Route`, ask:

Question id: `project_orchestrate_reiteration_route`

Prompt: `How should I revisit this worker route?`

Options:

- Down: `Recover Audit Workers`: audit and recover workers and worktrees.
- Left: `Worker Communication`: ask the worker or reassign work.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Worker Communication`, ask:

Question id: `project_orchestrate_worker_communication_route`

Prompt: `How should worker communication continue?`

Options:

- Down: `Ask Worker`: use `request_agent_input` when the current thread is orchestrating a worker.
- Left: `Reassign Work`: stop the current worker route and reassign the issue through an approved route.
- Right: `Stop / Done`: break the continuation loop.

Treat selected native answers as executable routing, not advisory text. Start the selected next skill in the same turn when tools and state allow it.
