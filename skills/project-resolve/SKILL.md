---
name: project-resolve
description: Use when one ready GitHub issue mirror under docs/superpowers/issues must be implemented directly in the current thread through native goal activation, Superpowers execution, pushed branch, opened PR, and PR-ready handoff.
---

# Project Resolve

This skill owns direct current-thread implementation for one ready GitHub issue. It starts from a synced issue mirror under `docs/superpowers/issues`, validates the linked source plan, activates a native `/goal`, executes with Superpowers discipline, and ends with PR-ready evidence for the main thread orchestrator: covered acceptance criteria, passed verification, pushed branch, opened PR that closes the linked issue, native goal completion proof, and a handoff to `$project-merge`.

If the user wants delegated worker-thread implementation, route to `$project-orchestrate` before setup. `$project-resolve` must not create worker threads or worker handoff ledgers.

GoalBuddy boards are outside the default execution model. Do not create `docs/goals`, GoalBuddy board files, GoalBuddy state, or local live boards from this skill unless the user explicitly requests separate GoalBuddy work outside this default issue-resolution path.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or `Done`. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` or `Done` option is terminal. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Artifact Source Of Truth

Project Resolve executes the `spec -> plan -> issue` lifecycle from flat canonical roots. It accepts one issue mirror from `docs/superpowers/issues`, requires a source plan from `docs/superpowers/plans`, and may read upstream loose specs from `docs/superpowers/specs`. Milestone pages are index views: they link to the flat canonical artifacts and do not own nested implementation records.

Before implementation, block or route to `$project-doctor` when an issue mirror, source plan, or related spec is presented from `docs/superpowers/milestones/<milestone>/issues`, `docs/superpowers/milestones/<milestone>/plans`, or `docs/superpowers/milestones/<milestone>/specs`. Those nested canonical milestone artifact folders are drift unless explicitly marked as generated index/view output. Keep milestone identity in frontmatter plus milestone indexes, filenames where applicable, and GitHub milestone fields.

## Hard Failures

Stop immediately when any of these are true:

- No single GitHub issue or issue mirror is named.
- The issue mirror is outside `docs/superpowers/issues`.
- The issue mirror has no linked source plan under `docs/superpowers/plans`.
- The linked source plan does not exist.
- The issue mirror lacks acceptance criteria, proof oracle, or AFK/HITL classification.
- Native goal proof is missing, a plain string, inactive, or not from `get_goal`.
- Setup ledger contains `goal_board_path`, `goalbuddy_checker`, or `docs/goals`.
- Code edits or implementation tests begin before setup validation passes.
- PR-ready evidence does not close the exact linked GitHub issue.
- PR-ready evidence does not show acceptance coverage, verification proof, branch push proof, handoff proof, and native goal completion proof.

## State Machine

Follow this order exactly:

1. `repo gate`: verify the active repo and explicit target when needed.
2. `issue mirror validation`: inspect `docs/superpowers/issues/<issue>.md`.
3. `source plan validation`: read the linked `docs/superpowers/plans/<plan>.md`.
4. `preflight`: verify the repo is ready for one issue execution.
5. `route check`: if worker-thread execution is requested, stop and route to `$project-orchestrate`.
6. `native goal activation`: call `get_goal`, create or activate the native `/goal`, then call `get_goal` again and capture structured proof.
7. `setup validation`: write and validate the setup ledger for direct current-thread execution.
8. `worktree and branch setup`: create or verify the current-thread worktree/branch.
9. `Superpowers execution`: use Superpowers execution, TDD, debugging, dynamic workflow, and verification skills as applicable.
10. `development branch finish`: use `superpowers:finishing-a-development-branch`, with PR as the default finish path.
11. `PR-ready validation`: validate branch push, PR URL, closing issue reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
12. `handoff`: send or record the worker/main-thread handoff and route final integration to `$project-merge`.

## Route Check

`$project-resolve` is the direct current-thread route. If the user wants a worker thread, use `$project-orchestrate`.

When the requested route is ambiguous and `request_user_input` is callable, the router should ask native question `project_issue_resolution_route` before starting either skill. If `$project-resolve` receives an execution decision whose selected mode is `orchestrated-worker`, stop immediately with the reason: `orchestrated worker execution is owned by project-orchestrate; use project-resolve only for direct current-thread execution`.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry in the setup ledger with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal issue execution or to pretend a live user chose the execution topology.

## Worker Route Boundary

Worker-thread orchestration is owned by `$project-orchestrate`. That skill derives the canonical worker thread title, branch name, evidence folder, and worker handoff, then routes PR-ready output to `$project-merge`.

## Scripted Gates

Run bundled scripts from this skill package with explicit `-RepoRoot`:

- `scripts/prepare-execution.ps1 -Mode Inspect`: reads the issue mirror, validates the source plan, and emits handoff JSON plus the exact native goal objective.
- `scripts/preflight.ps1`: validates issue mirror, source plan, branch, proof oracle, and clean starting state.
- `scripts/prepare-execution.ps1 -Mode ApplySetup`: creates or verifies the implementation branch and prints the native goal objective.
- `scripts/prepare-execution.ps1 -Mode FinalizeSetup`: accepts structured `get_goal` proof and writes the native setup ledger.
- `scripts/validate-setup.ps1`: rejects GoalBuddy board fields and requires issue mirror, source plan, branch, proof oracle, goal id or thread goal proof, and structured native goal proof.
- `scripts/collect-pr-ready-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrJson <json> -VerificationCommands <commands> -AcceptanceCoverageJson <json> -HandoffProofJson <json> -GoalCompletionProofJson <json> -OutputDir <temp-or-handoff-dir>`: generates the PR-ready ledger from PR evidence, acceptance coverage, verification receipts, handoff proof, and native goal completion proof.
- `scripts/validate-pr-ready.ps1`: validates branch push proof, PR closing reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Temp Plus Evidence

Normal runs should use `scripts/collect-pr-ready-ledger.ps1` before `scripts/validate-pr-ready.ps1`. The collector writes generated ledgers to a temp directory by default, or to an explicit output directory when the final handoff needs selected evidence artifacts. This keeps generated ledgers passed to existing gates without making agents hand-build JSON during ordinary resolution. The validator remains authoritative; collector output is convenience evidence, not a replacement for the PR-ready gate.

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

## Superpowers Routing

Use Superpowers for the engineering method inside this GitHub lifecycle:

- `superpowers:executing-plans` when the source plan is ready for inline execution.
- `superpowers:subagent-driven-development` when independent plan tasks can be delegated safely.
- `superpowers:using-git-worktrees` before implementation work begins.
- `superpowers:test-driven-development` for feature or bug code unless the plan records an explicit opt-out.
- `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes.
- `$project-orchestrate` when the issue needs an orchestrator/worker split.
- `codex-dynamic-workflows` only through `$project-orchestrate` when the issue meets the heavier orchestration decision rule or the user explicitly requests it.
- `superpowers:dispatching-parallel-agents` only when independent packets can run in parallel and the selected route supports delegation.
- `superpowers:verification-before-completion` before PR-ready claims.
- `superpowers:finishing-a-development-branch` after verification and before PR creation.

GitHub specialists can be used for CI or review-thread work, but bundled gate scripts remain authoritative.

## Native Continuation Gate

After PR-ready handoff proof passes, summarize the resolved issue in chat before asking the continuation question. The summary must name the PR URL, branch, issue mirror, source plan, acceptance coverage, verification proof, branch push proof, handoff proof, and native goal completion proof. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions with `request_user_input` when callable. Use flowchart geometry: Down is default progress, Left is revise/review/repair/rerun/recover, and Right is `Stop / Done`. Use as many native questions and options as the decision requires. Prefer the simple Down / Left / Right shape for generic continuation gates, but show all real peer routes when that is clearer. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree.

Question id: `project_resolve_next_step`

Prompt: `How should I continue from this PR-ready issue?`

Options:

- Down: `Integrate Resolved Issue`: merge this work or continue issue execution.
- Left: `Review / Revise PR-Ready Work`: review, revise, fix checks, or re-run verification.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Integrate Resolved Issue`, ask:

Question id: `project_resolve_integration_route`

Prompt: `What should happen with this PR-ready issue?`

Options:

- Down: `Merge`: start `$project-merge` from the PR URL or worker handoff.
- Left: `Continue Another Issue`: choose direct resolve or worker orchestration for another issue.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Continue Another Issue`, ask:

Question id: `project_resolve_another_issue_route`

Prompt: `How should the next issue be executed?`

Options:

- Down: `Resolve Another`: start `$project-resolve` for another ready issue mirror.
- Left: `Orchestrate Another`: start `$project-orchestrate` for another worker-suitable issue.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Review / Revise PR-Ready Work`, ask:

Question id: `project_resolve_reiteration_route`

Prompt: `How should I revisit this PR-ready work?`

Options:

- Down: `Review First`: show PR-ready evidence for main-thread review, then return to `project_resolve_next_step`.
- Left: `Revise Or Fix Branch`: choose branch revision or CI/check repair.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Revise Or Fix Branch`, ask:

Question id: `project_resolve_fix_route`

Prompt: `Should I revise the branch or address checks?`

Options:

- Down: `Revise Branch`: continue implementation on the branch, then return to `project_resolve_next_step`.
- Left: `Address CI / Checks`: inspect and fix checks, then return to `project_resolve_next_step`.
- Right: `Stop / Done`: break the continuation loop.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

## Completion Rule

Do not send a success-style final response until PR-ready proof shows:

- Acceptance criteria are covered.
- Verification passed.
- Branch is pushed.
- PR is opened and closes the exact linked issue.
- Native resolve goal is marked complete.
- PR-ready handoff was sent or recorded for `$project-merge`.
