---
name: resolve-issue
description: Use when one ready GitHub issue mirror under docs/superpowers/issues must be implemented directly in the current thread through native goal activation, Superpowers execution, pushed branch, opened PR, and PR-ready handoff.
---

# Project Resolve

This skill is the issue-backed Superpowers Project adapter for `superpowers:executing-plans`. It owns direct current-thread implementation for one ready GitHub issue. It starts from a synced issue mirror under `docs/superpowers/issues`, validates the linked source plan, activates a native `/goal`, executes with Superpowers discipline, and ends with PR-ready evidence for the main thread orchestrator: covered acceptance criteria, passed verification, pushed branch, opened PR that closes the linked issue, native goal completion proof, and a handoff to `$superpowers-project:merge-changes`.

If the user wants delegated worker-thread implementation, route to `$superpowers-project:orchestrate-issues` before setup. `$superpowers-project:resolve-issue` must not create worker threads or worker handoff ledgers.

**Announce at start:** "I'm using the resolve-issue skill with superpowers:executing-plans for direct issue implementation."

GoalBuddy boards are outside the default execution model. Do not create `docs/goals`, GoalBuddy board files, GoalBuddy state, or local live boards from this skill unless the user explicitly requests separate GoalBuddy work outside this default issue-resolution path.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with `the repo-root Auto Mode contract helper`; the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy and `stop_outside_policy: true`.

Auto Mode may choose direct current-thread issue resolution, create or verify native goal proof, execute the source plan, run verification, push PR-ready work, and route to merge without additional user input when the ready issue mirror came from the authorized source spec or derived plan. Carry the Auto Mode authorization ledger into PR-ready handoff evidence. If the issue mirror is not ready, proof is missing, checks fail, branch state is unsafe, or implementation needs a decision outside recorded defaults, stop outside policy before pushing or handoff.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Artifact Source Of Truth

Project Resolve executes the `spec -> plan -> issue` lifecycle from flat canonical roots. It accepts one issue mirror from `docs/superpowers/issues`, requires a source plan from `docs/superpowers/plans`, and may read upstream loose specs from `docs/superpowers/specs`. Milestone pages are index views: they link to the flat canonical artifacts and do not own nested implementation records.

Before implementation, block or route to `$superpowers-project:audit-project` when an issue mirror, source plan, or related spec is presented from `docs/superpowers/milestones/<milestone>/issues`, `docs/superpowers/milestones/<milestone>/plans`, or `docs/superpowers/milestones/<milestone>/specs`. Those nested canonical milestone artifact folders are drift unless explicitly marked as generated index/view output. Keep milestone identity in frontmatter plus milestone indexes, filenames where applicable, and GitHub milestone fields.

## Hard Failures

Stop immediately when any of these are true:

- No single GitHub issue or issue mirror is named.
- The target is only a raw GitHub issue URL, an external intake issue, or a mirror with `Source Plan: TBD`.
- The issue mirror is outside `docs/superpowers/issues`.
- The issue mirror has no linked source plan under `docs/superpowers/plans`.
- The linked source plan does not exist.
- The issue mirror lacks acceptance criteria, proof oracle, or AFK/HITL classification.
- Native goal proof is missing, a plain string, inactive, or not from `get_goal`.
- Setup ledger contains `goal_board_path`, `goalbuddy_checker`, or `docs/goals`.
- Code edits or implementation tests begin before setup validation passes.
- PR-ready evidence does not close the exact linked GitHub issue.
- PR-ready evidence does not show acceptance coverage, verification proof, branch push proof, handoff proof, and native goal completion proof.
- A terminal success or final closeout is attempted without a structured continuation decision ledger that records explicit `Stop`.

## State Machine

Follow this order exactly:

1. `repo gate`: verify the active repo and explicit target when needed.
2. `issue mirror validation`: inspect `docs/superpowers/issues/<issue>.md`.
3. `source plan validation`: read the linked `docs/superpowers/plans/<plan>.md`.
4. `preflight`: verify the repo is ready for one issue execution.
5. `route check`: if worker-thread execution is requested, stop and route to `$superpowers-project:orchestrate-issues`.
6. `native goal activation`: call `get_goal`, create or activate the native `/goal`, then call `get_goal` again and capture structured proof.
7. `setup validation`: write and validate the setup ledger for direct current-thread execution.
8. `worktree and branch setup`: create or verify the current-thread worktree/branch.
9. `Superpowers execution`: use Superpowers execution, TDD, debugging, dynamic workflow, and verification skills as applicable.
10. `development branch finish`: use `superpowers:finishing-a-development-branch`, with PR as the default finish path.
11. `PR-ready validation`: validate branch push, PR URL, closing issue reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
12. `handoff`: send or record the worker/main-thread handoff and route final integration to `$superpowers-project:merge-changes`.
13. `terminal closeout`: before ending this skill as complete, collect a continuation decision ledger and validate that the user explicitly selected `Stop`. Any non-terminal route must keep the workflow running.

## Route Check

`$superpowers-project:resolve-issue` is the direct current-thread route. If the user wants a worker thread, use `$superpowers-project:orchestrate-issues`.

If the user gives only a GitHub issue URL, no local mirror exists, or the mirror has an unresolved source plan, use `$superpowers-project:create-issues` hydration first. `$superpowers-project:resolve-issue` starts only after the local mirror and source plan exist and mirror validation passes.

When the requested route is ambiguous and `request_user_input` is callable, the router should ask native question `project_issue_resolution_route` before starting either skill. If `$superpowers-project:resolve-issue` receives an execution decision whose selected mode is `orchestrated-worker`, stop immediately with the reason: `orchestrated worker execution is owned by orchestrate-issues; use resolve-issue only for direct current-thread execution`.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry in the setup ledger with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal issue execution or to pretend a live user chose the execution topology.

## Worker Route Boundary

Worker-thread orchestration is owned by `$superpowers-project:orchestrate-issues`. That skill derives the canonical worker thread title, branch name, evidence folder, and worker handoff, then routes PR-ready output to `$superpowers-project:merge-changes`.

## Scripted Gates

Run bundled scripts from this skill package with explicit `-RepoRoot`:

- `scripts/prepare-execution.ps1 -Mode Inspect`: reads the issue mirror, validates the source plan, and emits handoff JSON plus the exact native goal objective.
- `scripts/preflight.ps1`: validates issue mirror, source plan, branch, proof oracle, and clean starting state.
- `scripts/prepare-execution.ps1 -Mode ApplySetup`: creates or verifies the implementation branch and prints the native goal objective.
- `scripts/prepare-execution.ps1 -Mode FinalizeSetup`: accepts structured `get_goal` proof and writes the native setup ledger.
- `scripts/validate-setup.ps1`: rejects GoalBuddy board fields and requires issue mirror, source plan, branch, proof oracle, goal id or thread goal proof, and structured native goal proof.
- `scripts/collect-pr-ready-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrJson <json> -VerificationCommands <commands> -AcceptanceCoverageJson <json> -HandoffProofJson <json> -GoalCompletionProofJson <json> -OutputDir <temp-or-handoff-dir>`: generates the PR-ready ledger from PR evidence, acceptance coverage, verification receipts, handoff proof, and native goal completion proof.
- `scripts/validate-pr-ready.ps1`: validates branch push proof, PR closing reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
- `scripts/collect-continuation-ledger.ps1 -RepoRoot . -QuestionId <id> -Prompt <text> -Source <request_user_input|debug_question_mode> -SelectedOptionId <id> -RecommendedOptionId <id> -TerminalState <stop|continue|revisit> -OptionIds <id1,id2,id3> -OutputDir <temp-or-handoff-dir>`: records the structured continuation decision after a PR-ready native route question.
- `scripts/validate-terminal-closeout.ps1 -RepoRoot . -PrReadyResultJson <json-or-path> -ContinuationDecisionJson <json-or-path>`: blocks terminal success unless the PR-ready gate passed and the continuation decision records explicit `Stop`.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Temp Plus Evidence

Normal runs should use `scripts/collect-pr-ready-ledger.ps1` before `scripts/validate-pr-ready.ps1`. The collector writes generated ledgers to a temp directory by default, or to an explicit output directory when the final handoff needs selected evidence artifacts. This keeps generated ledgers passed to existing gates without making agents hand-build JSON during ordinary resolution. The validator remains authoritative; collector output is convenience evidence, not a replacement for the PR-ready gate.

Terminal closeout is separate from PR-ready proof. If the thread is about to stop after PR-ready, collect the continuation decision with `scripts/collect-continuation-ledger.ps1` and pass it to `scripts/validate-terminal-closeout.ps1`. That terminal validator is authoritative for whether `resolve-issue` may end the workflow; PR-ready proof alone is not terminal permission.

There is no hand-authored JSON requirement for normal runs. Hand-authored JSON is acceptable only for fixture tests, debug smoke tests, or unusual recovery work where the collector cannot access the source evidence.

## Setup Ledger Shape

The setup ledger must include:

```json
{
  "issue_url": "https://github.com/<owner>/<repo>/issues/<n>",
  "issue_mirror": "docs/superpowers/issues/<issue-number>-<slug>.md",
  "source_plan": "docs/superpowers/plans/<date>-<slug>-plan.md",
  "branch": "codex/<slug>",
  "goal_id": "<native goal id or thread goal proof id>",
  "goal_objective": "<exact native goal objective>",
  "goal_activation_proof": {
    "source": "get_goal",
    "active": true,
    "goal_id": "<id>",
    "objective": "<active objective>"
  },
  "execution_decision": {
    "question_id": "resolve_execution_topology",
    "source": "request_user_input",
    "selected_mode": "inline",
    "recommended_mode": "inline",
    "options": ["orchestrated-worker", "inline"]
  },
  "workflow_policy": {
    "worktree_policy": "Native Codex worktree thread first",
    "integration_policy": "Current thread owns PR",
    "tdd_policy": "Required",
    "reviewer_role": "Main thread orchestrator",
    "script_gate_mode": "Safety only"
  },
  "worker_handoff": null,
  "dynamic_work_packet_map": null,
  "proof_oracle": ["<commands, artifacts, review state, or visible behavior>"],
  "branch_inventory_before": {
    "local": ["main"],
    "remote": ["main"]
  }
}
```

Plain strings do not count as native goal, verification, or completion proof.

## Native Goal Policy

If native goal tools are callable, use them:

- Call `get_goal` before activation. If an unrelated active goal exists, block.
- Activate the exact `/goal` objective from `prepare-execution.ps1`.
- Call `get_goal` again and pass that structured proof to `FinalizeSetup`.
- At PR-ready, call native goal completion when tool support exists and record the structured result in the PR-ready ledger.

If the run uses a slash-command flow instead of tools, record the exact `/goal` activation and completion evidence in ledgers. Do not continue from a plain-text claim.

## Superpowers Method Contract

This skill is the issue-backed Superpowers Project adapter for `superpowers:executing-plans`. The companion method contract is mandatory inside this GitHub lifecycle:

- Always use `superpowers:using-git-worktrees` before implementation work begins.
- Always use `superpowers:executing-plans` as the base execution workflow for the linked source plan.
- Require `superpowers:test-driven-development` for feature or bug code unless the source plan records an explicit opt-out.
- Require `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes.
- `$superpowers-project:orchestrate-issues` when the issue needs an orchestrator/worker split.
- `codex-dynamic-workflows` only through `$superpowers-project:orchestrate-issues` when the issue meets the heavier orchestration decision rule or the user explicitly requests it.
- `superpowers:dispatching-parallel-agents` only when independent packets can run in parallel and the selected route supports delegation.
- Require `superpowers:verification-before-completion` before PR-ready claims.
- Require `superpowers:finishing-a-development-branch` after verification and before PR creation.

Do not collapse this into generic "Superpowers execution". If a required companion skill cannot be applied, stop and surface the blocker instead of continuing with ad hoc execution.

GitHub specialists can be used for CI or review-thread work, but bundled gate scripts remain authoritative.

## Native Continuation Gate

After PR-ready handoff proof passes, summarize the resolved issue in chat before asking the continuation question. The summary must name the PR URL, branch, issue mirror, source plan, acceptance coverage, verification proof, branch push proof, handoff proof, and native goal completion proof. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and No in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include Stop / Done; they include only real forward routes. Nested Revisit-route menus must not include Stop / Done; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Recommend Stop only for explicit mid-loop terminal or blocker states. Recommend Done only at a verified final Done gate. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If it appears to ask for Stop or Done, ask a fresh confirmation question instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_resolve_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Down: `Integrate Resolved Issue`: merge this work or continue issue execution.
- Left: `Review / Revise PR-Ready Work`: review, revise, fix checks, or re-run verification.
- Right: `Stop`: break the continuation loop.

If the user selects `Integrate Resolved Issue`, ask:

Question id: `project_resolve_integration_route`

Prompt: `What should happen with this PR-ready issue?`

Options:

- Down: `Merge`: start `$superpowers-project:merge-changes` from the PR URL or worker handoff.
- Left: `Continue Another Issue`: choose direct resolve or worker orchestration for another issue.
- Right: `Stop`: break the continuation loop.

If the user selects `Continue Another Issue`, ask:

Question id: `project_resolve_another_issue_route`

Prompt: `How should the next issue be executed?`

Options:

- Down: `Resolve Another`: start `$superpowers-project:resolve-issue` for another ready issue mirror.
- Left: `Orchestrate Another`: start `$superpowers-project:orchestrate-issues` for another worker-suitable issue.
- Right: `Stop`: break the continuation loop.

If the user selects `Review / Revise PR-Ready Work`, ask:

Question id: `project_resolve_reiteration_route`

Prompt: `How should I revisit this PR-ready work?`

Options:

- Down: `Review First`: show PR-ready evidence for main-thread review, then return to `project_resolve_next_step`.
- Left: `Revise Or Fix Branch`: choose branch revision or CI/check repair.
- Right: `Stop`: break the continuation loop.

If the user selects `Revise Or Fix Branch`, ask:

Question id: `project_resolve_fix_route`

Prompt: `Should I revise the branch or address checks?`

Options:

- Down: `Revise Branch`: continue implementation on the branch, then return to `project_resolve_next_step`.
- Left: `Address CI / Checks`: inspect and fix checks, then return to `project_resolve_next_step`.
- Right: `Stop`: break the continuation loop.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

Record the selected route in a structured continuation decision ledger. If the answer is `Stop`, collect the ledger and run `scripts/validate-terminal-closeout.ps1` before any final success-style response. If the answer is any non-terminal route such as `Merge`, `Resolve Another`, `Orchestrate Another`, `Review First`, `Revise Branch`, or `Address CI / Checks`, the ledger must still be recorded, and the thread must continue into that route instead of terminating.

## Completion Rule

Do not send a success-style final response until PR-ready proof shows:

- Acceptance criteria are covered.
- Verification passed.
- Branch is pushed.
- PR is opened and closes the exact linked issue.
- Native resolve goal is marked complete.
- PR-ready handoff was sent or recorded for `$superpowers-project:merge-changes`.
- A structured continuation decision ledger was collected for the last native continuation answer.
- `scripts/validate-terminal-closeout.ps1` passes with explicit `Stop`.



