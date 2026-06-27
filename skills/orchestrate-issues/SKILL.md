---
name: orchestrate-issues
description: Use when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread while the current thread acts as orchestrator and reviewer.
---

# Project Orchestrate

This skill is the delegated Superpowers Project adapter for `superpowers:subagent-driven-development`. Use it when one ready GitHub issue mirror should be implemented by a separate Codex worker thread or worktree while the current thread owns orchestration, review, PR handoff intake, and routing to `$superpowers-project:merge-changes`.

`$superpowers-project:orchestrate-issues` does not replace `$superpowers-project:resolve-issue`. `$superpowers-project:resolve-issue` is the direct current-thread route. `$superpowers-project:orchestrate-issues` is the delegated worker-thread route.

**Announce at start:** "I'm using the orchestrate-issues skill with superpowers:subagent-driven-development for delegated issue execution."

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
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

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with the plugin-provided Auto Mode validator from the loaded Superpowers Project plugin root (`<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `route_policy.issue_route: direct-inline-resolve-issue`, and `stop_outside_policy: true`.

Auto Mode uses `$superpowers-project:resolve-issue` for direct current-thread issue execution. `$superpowers-project:orchestrate-issues` is the explicit delegated worker-thread route, not an Auto Mode default or requirement. If Auto Mode reaches this skill without separate user approval for delegated worker execution, stop outside policy and route the ready issue mirror to `$superpowers-project:resolve-issue` instead. If worker recovery, reassignment, GitHub auth, missing proof, failed validation, or scope expansion needs a decision outside recorded defaults, stop outside policy and report the resume target.

## Worker Identity Contract

Use `scripts/derive-worker-identity.ps1 -RepoRoot . -IssueFile <docs/superpowers/issues/<issue>.md>` before creating the worker. The derived identity is canonical for the worker run:

- thread title: `Resolve #<issue-number>: <issue title>`
- branch name: `codex/issue-<issue-number>-<slug>`
- evidence folder: `orchestrate-issues-issue-<issue-number>-<slug>`
- PR title hint: `Resolve #<issue-number>: <issue title>`

Do not hand-edit these names after derivation. If the issue title or slug is wrong, fix the issue mirror first and rerun the script.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not create real worker threads, mutate GitHub, merge PRs, or pretend a live user approved delegated execution.
## Worker Handoff

Run `scripts/prepare-worker-handoff.ps1 -RepoRoot . -IssueFile <docs/superpowers/issues/<issue>.md> -OutputPath <temp-or-handoff-json>` before starting a worker. It validates the issue mirror, source plan, proof oracle, and derived worker identity, then emits a handoff ledger.

Run `scripts/validate-worker-handoff.ps1 -RepoRoot . -HandoffPath <handoff-json>` before sending the handoff to the worker.

Use `docs/superpowers/examples/worker-handoff-packets.md` as the canonical packet example for orchestrator-to-worker handoffs and worker-to-orchestrator PR-ready returns. Validate packet examples and fixtures with `scripts/validate-worker-packets.ps1 -RepoRoot . -PacketPath <packet-json-or-md>` and `scripts/test-worker-packets.ps1`. Worker handoff packets must include source plan, issue mirror, goal command, branch/worktree policy, proof oracle, validation commands, reviewer role, and merge handoff. PR-ready return packets must include branch, diff scope, validation receipt, issue mirror, source plan, proof oracle, and merge route.

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

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before asking any route continuation or permission question, with this route-specific artifact inventory: the issue mirror, derived branch, worker thread title, evidence folder, PR URL if available, worker-changed artifact inventory, verification evidence status, exact test values/results when provided by the worker, and machine-readable handoff ledgers.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

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
