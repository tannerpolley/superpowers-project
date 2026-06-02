---
name: project-merge
description: Use when a Superpowers Project PR URL or worker handoff must be reviewed, approved, merged, linked issue closure verified, worktree and branch cleanup completed, and clean repo proof recorded.
---

# Project Merge

This skill owns integration after `$project-resolve` creates PR-ready evidence. It starts from a PR URL or worker handoff, verifies the issue mirror and source plan, runs premerge checks, asks native UI merge approval, merges only after approval, verifies linked issue closure, cleans up the owned branch and worktree, runs `git fetch --prune`, runs the cleanup hook, and records final clean repo proof.

`$project-merge` is normally run by the main orchestrator thread. Workers do not merge their own PR by default.

## Hard Failures

Stop immediately when any of these are true:

- No PR URL or worker handoff is named.
- No linked issue mirror under `docs/superpowers/issues` can be identified.
- No linked source plan under `docs/superpowers/plans` can be identified.
- PR evidence does not close the exact linked GitHub issue.
- Required checks fail, are pending, or are missing while policy requires existing checks.
- PR changed files are not covered by verification receipts tied to the source plan.
- Premerge proof has not passed.
- Native UI merge approval is missing, malformed, or declined.
- Branch cleanup attempts to delete anything other than the owned implementation branch.
- Worktree cleanup targets a path outside the owned worktree.
- Cleanup hook proof is missing or failed.
- Final repo state is dirty.

## State Machine

Follow this order exactly:

1. `merge intake`: read the PR URL or worker handoff.
2. `source linkage`: read the issue mirror, source plan, setup ledger, PR-ready handoff ledger, and verification ledger.
3. `premerge`: run `scripts/premerge.ps1` with real GitHub evidence or local fixtures.
4. `merge approval`: explain the clean premerge evidence, then ask native UI question `project_merge_approval`.
5. `merge`: merge the PR only when the user selects `Merge`.
6. `issue closure`: verify the exact linked GitHub issue is closed.
7. `default sync`: sync the default branch.
8. `branch cleanup`: delete only the owned implementation branch locally and remotely.
9. `worktree cleanup`: remove only the owned worktree when one exists.
10. `prune`: run `git fetch --prune`.
11. `cleanup hook`: run the repo cleanup hook.
12. `clean state`: verify clean repo state and record closeout proof through `scripts/closeout.ps1`.

## Native Merge Approval

After premerge proof passes and before any merge command, ask with `request_user_input` when callable.

Question id: `project_merge_approval`

Prompt shape:

```text
Premerge proof is clean for <PR URL>. Merge this PR now?
```

Options:

- `Merge`: merge the PR and continue issue closure plus cleanup.
- `Decline`: stop without merging and report the exact pending state.

Use `Merge` as the recommended option only after premerge proof is clean. Do not merge without native UI approval.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger in the merge evidence or final smoke report. Each ledger entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used as a substitute for native UI in normal merge work; it is test-only evidence and never counts as a live user decision.

## Native Continuation Gate

After closeout proof passes, summarize the merge closeout in chat before asking the continuation question. The summary must name the merged PR URL, closed issue, synced default branch, branch and worktree cleanup proof, prune proof, cleanup hook proof, and clean repo proof.

Ask a native continuation question with `request_user_input` when callable.

Question id: `project_merge_next_step`

Prompt: `How should I continue from this merge closeout?`

Options:

- `Project Doctor`: start `$project-doctor` for post-merge drift audit or live sync review.
- `Resolve Another`: start `$project-resolve` for another ready issue mirror.
- `Review First`: stop for user review after merge closeout.
- `Stop`: stop after clean closeout.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

## Scripted Gates

Run bundled scripts with explicit `-RepoRoot`:

- `scripts/premerge.ps1`: validates PR closing reference, checks, issue acceptance state, changed-file coverage, and proof commands.
- `scripts/validate-merge-decision.ps1`: validates the native merge approval ledger and blocks declined decisions.
- `scripts/closeout.ps1`: validates merged PR proof, linked issue closure proof, branch cleanup, worktree cleanup, prune proof, cleanup hook proof, and clean repo proof.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Completion Rule

Do not send a success-style final response until closeout proof shows:

- PR merged.
- Exact linked issue closed.
- Default branch synced.
- Only the owned implementation branch deleted.
- Owned worktree removed or proven absent.
- `git fetch --prune` passed.
- Repo cleanup hook passed.
- Repo state is clean.
