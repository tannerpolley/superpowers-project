---
name: resolve-issue-with-goal
description: Use when one ready GitHub issue mirror under docs/superpowers/issues must be resolved through native goal activation, Superpowers execution, PR, merge, issue closure, and cleanup.
---

# Resolve Issue With Goal

This skill owns execution for one ready GitHub issue. It starts from a synced issue mirror under `docs/superpowers/issues`, validates the linked source plan, activates a native `/goal`, executes with Superpowers discipline, and ends with a merged PR, closed issue, native goal completion, synced default branch, goal branch cleanup, and cleanup proof.

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
- PR evidence does not close the exact linked GitHub issue.
- Required checks fail, are pending, or are missing while policy requires existing checks.
- PR changed files are not covered by verification receipts tied to the source plan.
- Issue acceptance criteria are unchecked and no closeout proof covers them.
- Closeout lacks merged PR proof, closed issue proof, native goal completion proof, branch cleanup proof, or cleanup hook proof.

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
11. `main thread review`: review worker or inline PR evidence before merge.
12. `premerge`: validate PR closure, checks, issue criteria, changed-file coverage, and proof receipts.
13. `merge`: squash-merge the approved PR.
14. `issue close`: verify the exact linked GitHub issue is closed.
15. `goal complete`: call native goal completion with tool support or record exact slash-command completion evidence.
16. `cleanup`: sync default branch, delete only the goal branch, remove owned temporary scaffolding, and run the repo cleanup hook.

## Execution Topology Question

Before branch setup or implementation, ask the user how to resolve the issue when `request_user_input` is callable.

Question id: `resolve_execution_topology`

Prompt: `How should this issue be resolved?`

Options:

- `Open worker thread`: create a Codex worktree thread for implementation while this thread acts as main thread orchestrator and reviewer.
- `Current thread`: resolve the issue in this thread using worktree isolation.

Recommend `Open worker thread` for non-trivial AFK issues, source plans with multiple independent tasks, risky shared-code changes, or work naturally ending in a PR. Recommend `Current thread` for small, single-step, low-risk issues.

For explicit smoke tests, use `debug_question_mode` instead of `request_user_input` and record the Native Question Debug Ledger entry in the setup ledger.

## Orchestrated Worker Mode

When the selected mode is `orchestrated-worker`, this thread remains the lifecycle owner. It creates the native goal, prepares the worker handoff, opens a Codex worktree thread when native thread tools are callable, reviews the worker PR, handles CI or review feedback, merges, closes the linked issue, completes the native goal, syncs default, deletes the owned branch, and records cleanup proof.

The worker thread must use `superpowers:using-git-worktrees`, `superpowers:test-driven-development`, `superpowers:executing-plans` or `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`. Use `codex-dynamic-workflows` and `superpowers:dispatching-parallel-agents` when the source plan contains independent packets.

If native thread tools are absent, stop after producing the worker handoff and ask the user to open the worker thread. Do not silently convert the run to inline execution.

## Scripted Gates

Run bundled scripts from this skill package with explicit `-RepoRoot`:

- `scripts/prepare-execution.ps1 -Mode Inspect`: reads the issue mirror, validates the source plan, and emits handoff JSON plus the exact native goal objective.
- `scripts/preflight.ps1`: validates issue mirror, source plan, branch, proof oracle, and clean starting state.
- `scripts/prepare-execution.ps1 -Mode ApplySetup`: creates or verifies the implementation branch and prints the native goal objective.
- `scripts/prepare-execution.ps1 -Mode FinalizeSetup`: accepts structured `get_goal` proof and writes the native setup ledger.
- `scripts/validate-setup.ps1`: rejects GoalBuddy board fields and requires issue mirror, source plan, branch, proof oracle, goal id or thread goal proof, and structured native goal proof.
- `scripts/premerge.ps1`: validates PR closing reference, required checks, issue acceptance state, and source-plan verification receipts for changed files.
- `scripts/closeout.ps1`: validates merged PR, closed issue, native goal completion proof, branch cleanup, and cleanup hook result.

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
- At closeout, call native goal completion when tool support exists and record the structured result.

If the run uses a slash-command flow instead of tools, record the exact `/goal` activation and completion evidence in ledgers. Do not continue from a plain-text claim.

## Superpowers Routing

Use Superpowers for the engineering method inside this GitHub lifecycle:

- `superpowers:executing-plans` when the source plan is ready for inline execution.
- `superpowers:subagent-driven-development` when independent plan tasks can be delegated safely.
- `superpowers:using-git-worktrees` before implementation work begins.
- `superpowers:test-driven-development` for feature or bug code unless the plan records an explicit opt-out.
- `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes.
- `codex-dynamic-workflows` when the issue needs an orchestrator/worker split or work packet map.
- `superpowers:dispatching-parallel-agents` when independent packets can run in parallel.
- `superpowers:verification-before-completion` before PR-ready, merge-ready, or complete claims.
- `superpowers:finishing-a-development-branch` after verification and before integration.

GitHub specialists can be used for CI or review-thread work, but bundled gate scripts remain authoritative.

## Completion Rule

Do not send a success-style final response until closeout proof shows:

- PR merged.
- Exact linked issue closed.
- Native goal marked complete.
- Default branch synced.
- Only the goal branch deleted.
- Owned temporary scaffolding removed.
- Repo cleanup hook passed.
