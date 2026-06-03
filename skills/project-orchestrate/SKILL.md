---
name: project-orchestrate
description: Use when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread while the current thread acts as orchestrator and reviewer.
---

# Project Orchestrate

Use this skill when one ready GitHub issue mirror should be implemented by a separate Codex worker thread or worktree while the current thread owns orchestration, review, PR handoff intake, and routing to `$project-merge`.

`$project-orchestrate` does not replace `$project-resolve`. `$project-resolve` is the direct current-thread route. `$project-orchestrate` is the delegated worker-thread route.

## Hard Failures

Stop before creating a worker thread when any of these are true:

- The issue mirror is missing or outside `docs/superpowers/issues`.
- The source plan is missing.
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

If the user gives only a GitHub issue URL and no local mirror exists, hydrate the issue through `$project-issue` before orchestration. Do not create a worker from raw GitHub issue text without a local mirror and source plan.

## Native Continuation Gate

After PR-ready handoff intake, summarize the worker route before asking the continuation question. The summary must name the issue mirror, derived branch, worker thread title, evidence folder, PR URL if available, verification evidence status, and the recommended next route.

Ask native question `project_orchestrate_next_step` with these options:

- `Project Merge`: start `$project-merge` for the PR-ready handoff.
- `Review First`: stop for user review before merge routing.
- `Recover Worker`: ask for approved recovery action if the worker is blocked or stale.
- `Stop`: stop after the orchestration handoff.

Treat selected native answers as executable routing, not advisory text. Start the selected next skill in the same turn when tools and state allow it.
