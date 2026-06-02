---
name: project-resolve
description: Use when one ready GitHub issue mirror under docs/superpowers/issues must be implemented through native goal activation, Superpowers execution, pushed branch, opened PR, and PR-ready handoff.
---

# Project Resolve

This skill owns implementation for one ready GitHub issue. It starts from a synced issue mirror under `docs/superpowers/issues`, validates the linked source plan, activates a native `/goal`, executes with Superpowers discipline, and ends with PR-ready evidence: covered acceptance criteria, passed verification, pushed branch, opened PR that closes the linked issue, native goal completion proof, and a handoff to `$project-merge`.

GoalBuddy boards are outside the default execution model. Do not create `docs/goals`, GoalBuddy board files, GoalBuddy state, or local live boards from this skill unless the user explicitly requests separate GoalBuddy work outside this default issue-resolution path.

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
5. `execution topology question`: ask whether to open a worker thread or resolve in the current thread.
6. `native goal activation`: call `get_goal`, create or activate the native `/goal`, then call `get_goal` again and capture structured proof.
7. `setup validation`: write and validate the setup ledger, including the execution decision.
8. `worktree and branch setup`: create or verify inline worktree/branch, or create the worker handoff for a worker worktree thread.
9. `Superpowers execution`: use Superpowers execution, TDD, debugging, dynamic workflow, and verification skills as applicable.
10. `development branch finish`: use `superpowers:finishing-a-development-branch`, with PR as the default finish path.
11. `PR-ready validation`: validate branch push, PR URL, closing issue reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
12. `handoff`: send or record the worker/main-thread handoff and route final integration to `$project-merge`.

## Execution Topology Question

Before branch setup or implementation, ask the user how to resolve the issue when `request_user_input` is callable.

Question id: `resolve_execution_topology`

Prompt: `How should this issue be resolved?`

Options:

- `Open worker thread`: create a Codex worktree thread for implementation while this thread acts as main thread orchestrator and reviewer.
- `Current thread`: resolve the issue in this thread using worktree isolation.

Recommend `Open worker thread` for non-trivial AFK issues, source plans with multiple independent tasks, risky shared-code changes, or work naturally ending in a PR. Recommend `Current thread` for small, single-step, low-risk issues.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry in the setup ledger with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal issue execution or to pretend a live user chose the execution topology.

## Orchestrated Worker Mode

When the selected mode is `orchestrated-worker`, this thread remains the implementation lifecycle owner. It creates the native goal, prepares the worker handoff, opens a Codex worktree thread when native thread tools are callable, validates PR-ready evidence, completes the native goal, and routes final integration to `$project-merge`.

The worker thread must use `superpowers:using-git-worktrees`, `superpowers:test-driven-development`, `superpowers:executing-plans` or `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`. Worker mode must record a lightweight Dynamic Work Packet Map in the setup ledger or worker handoff. Use full `codex-dynamic-workflows` and `superpowers:dispatching-parallel-agents` only when scope, risk, independent packets, separate verification, reusable workflow value, or explicit user request justifies it.

If native thread tools are absent, stop after producing the worker handoff and ask the user to open the worker thread. Do not silently convert the run to inline execution.

## Scripted Gates

Run bundled scripts from this skill package with explicit `-RepoRoot`:

- `scripts/prepare-execution.ps1 -Mode Inspect`: reads the issue mirror, validates the source plan, and emits handoff JSON plus the exact native goal objective.
- `scripts/preflight.ps1`: validates issue mirror, source plan, branch, proof oracle, and clean starting state.
- `scripts/prepare-execution.ps1 -Mode ApplySetup`: creates or verifies the implementation branch and prints the native goal objective.
- `scripts/prepare-execution.ps1 -Mode FinalizeSetup`: accepts structured `get_goal` proof and writes the native setup ledger.
- `scripts/validate-setup.ps1`: rejects GoalBuddy board fields and requires issue mirror, source plan, branch, proof oracle, goal id or thread goal proof, and structured native goal proof.
- `scripts/validate-pr-ready.ps1`: validates branch push proof, PR closing reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

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
- a lightweight Dynamic Work Packet Map when the issue needs an orchestrator/worker split.
- `codex-dynamic-workflows` only when the issue meets the heavier orchestration decision rule or the user explicitly requests it.
- `superpowers:dispatching-parallel-agents` when independent packets can run in parallel.
- `superpowers:verification-before-completion` before PR-ready claims.
- `superpowers:finishing-a-development-branch` after verification and before PR creation.

GitHub specialists can be used for CI or review-thread work, but bundled gate scripts remain authoritative.

## Native Continuation Gate

After PR-ready handoff proof passes, summarize the resolved issue in chat before asking the continuation question. The summary must name the PR URL, branch, issue mirror, source plan, acceptance coverage, verification proof, branch push proof, handoff proof, and native goal completion proof.

Ask a native continuation question with `request_user_input` when callable.

Question id: `project_resolve_next_step`

Prompt: `How should I continue from this PR-ready issue?`

Options:

- `Project Merge`: start `$project-merge` from the PR URL or worker handoff.
- `Resolve Another`: start `$project-resolve` for another ready issue mirror.
- `Review First`: stop for main-thread review before merge.
- `Stop`: stop at PR-ready handoff.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

## Completion Rule

Do not send a success-style final response until PR-ready proof shows:

- Acceptance criteria are covered.
- Verification passed.
- Branch is pushed.
- PR is opened and closes the exact linked issue.
- Native resolve goal is marked complete.
- PR-ready handoff was sent or recorded for `$project-merge`.
