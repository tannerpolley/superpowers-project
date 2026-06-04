---
name: merge-changes
description: Use when a Superpowers Project PR URL or worker handoff must be reviewed, approved, merged, linked issue closure verified, worktree and branch cleanup completed, and clean repo proof recorded.
---

# Project Merge

This skill owns integration after `$superpowers-project:resolve-issue` creates PR-ready evidence or after approved plan work produces merge-ready local or PR evidence. It supports three closeout modes:

- `pr-issue`: issue-backed PRs that must verify exact GitHub issue closure and issue mirror cleanup.
- `pr-no-issue`: non-issue PRs linked to a source plan that must not claim GitHub issue closure.
- `local-branch`: approved local branch merges linked to a source plan, with clean synced main proof, validation proof, native merge approval, branch/worktree cleanup, cleanup hook proof, and clean repo proof.

It starts from a PR URL, local branch, or worker handoff, verifies the issue mirror when the mode is `pr-issue`, verifies the source plan, runs premerge checks, asks native UI merge approval, merges only after approval, cleans up the owned branch and worktree, runs `git fetch --prune`, runs the cleanup hook, and records final clean repo proof.

`$superpowers-project:merge-changes` is normally run by the main orchestrator thread. Workers do not merge their own PR by default.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with `the repo-root Auto Mode contract helper`; the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `merge_permission.selected_mode: preauthorized-after-clean-premerge`, and `stop_outside_policy: true`.

Auto Mode merge approval is satisfied only after premerge proof passes cleanly and the ledger includes `preauthorized-after-clean-premerge`. Record that ledger as the merge approval source, then merge, run branch/worktree cleanup, prune, cleanup hook, closeout proof, and final clean repo proof without additional user input. If premerge proof fails, checks are pending or missing, issue closure evidence is wrong, local branch proof is incomplete, cleanup proof is missing, or any merge decision falls outside recorded defaults, stop outside policy before merging or final Done.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Hard Failures

Stop immediately when any of these are true:

- No PR URL or worker handoff is named.
- Mode is missing or is not `pr-issue`, `pr-no-issue`, or `local-branch`.
- Mode is `pr-issue` and no linked issue mirror under `docs/superpowers/issues` can be identified.
- No linked source plan under `docs/superpowers/plans` can be identified.
- Mode is `pr-issue` and PR evidence does not close the exact linked GitHub issue.
- Mode is `pr-no-issue` and PR evidence or completion evidence claims GitHub issue closure.
- Mode is `local-branch` and clean synced main proof, validation proof, local merge proof, or native approval proof is missing.
- Required checks fail, are pending, or are missing while policy requires existing checks.
- PR changed files are not covered by verification receipts tied to the source plan.
- Premerge proof has not passed.
- Native UI merge approval is missing, malformed, or declined.
- Branch cleanup attempts to delete anything other than the owned implementation branch.
- Worktree cleanup targets a path outside the owned worktree.
- Cleanup hook proof is missing or failed.
- Final repo state is dirty.
- Closed issue mirror cleanup evidence is missing: closed mirrors are deleted by default, or explicitly retained only when marked `**Mirror Retention:** Keep`.
- Milestone closed-summary evidence is missing the GitHub issue link or PR link.

## State Machine

Follow this order exactly:

1. `merge intake`: read the PR URL or worker handoff.
2. `source linkage`: read the issue mirror, source plan, setup ledger, PR-ready handoff ledger, and verification ledger.
3. `premerge`: run `scripts/premerge.ps1` with real GitHub evidence or local fixtures.
4. `merge approval`: explain the clean premerge evidence, then ask native UI question `project_merge_approval`.
5. `merge`: merge the PR only when the user selects `Merge`.
6. `issue closure`: for `pr-issue`, verify the exact linked GitHub issue is closed; skip issue-close verification for `pr-no-issue` and `local-branch`.
7. `default sync`: sync the default branch.
8. `branch cleanup`: delete only the owned implementation branch locally and remotely.
9. `worktree cleanup`: remove only the owned worktree when one exists.
10. `prune`: run `git fetch --prune`.
11. `cleanup hook`: run the repo cleanup hook.
12. `closed mirror cleanup`: for `pr-issue`, delete the closed issue mirror by default, or retain it only with `**Mirror Retention:** Keep`; preserve the milestone history as a closed issue summary with GitHub issue and PR links. Do not require issue mirror cleanup for `pr-no-issue` or `local-branch`.
13. `clean state`: verify clean repo state and record closeout proof through `scripts/closeout.ps1`.

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

## Reassessment Routing

If merge approval is declined, ask native follow-up through `advanced-user-input` when callable:

- `User Review`: stop with the PR or branch evidence.
- `Reassess Plan`: route to `$superpowers-project:write-plan` for strict execution, testing, acceptance, or branch strategy revision.
- `Reassess Spec`: route to `$superpowers-project:brainstorm-spec` for loose idea or scope reassessment.

When this thread is a worker/subagent and the merge decision belongs to the orchestrator, use the `request_agent_input` protocol instead of native `request_user_input`.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger in the merge evidence or final smoke report. Each ledger entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used as a substitute for native UI in normal merge work; it is test-only evidence and never counts as a live user decision.

## Native Continuation Gate

After closeout proof passes, summarize the merge closeout in chat before asking the continuation question. The summary must name the merged PR URL, closed issue, synced default branch, branch and worktree cleanup proof, prune proof, cleanup hook proof, and clean repo proof. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Done is valid only at a verified final Done gate. Stop remains the terminal option when premerge or closeout proof is incomplete. If closeout proof passes, ask:

Question id: `project_merge_final_health_gate`

Prompt: `Closeout proof is clean. Mark this workflow done?`

Options:

- Down: `Done`: end the workflow as complete.
- Left: `Revisit`: review closeout evidence, then return to `project_merge_next_step`.
- Right: `Stop`: stop with clean closeout proof recorded.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and No in the same top-level question. Do not show Continue children as peer top-level options. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_merge_next_step`

Prompt: `How should I continue from this merge closeout?`

Options:

- Down: `Continue Project Execution`: continue issue execution or start planning the next work.
- Left: `Review / Repair Closeout`: review evidence, audit drift, repair closeout, or rerun cleanup.
- Right: `Stop`: break the continuation loop.

If the user selects `Continue Project Execution`, ask:

Question id: `project_merge_continue_group`

Prompt: `Which kind of work should continue after this merge?`

Options:

- Down: `Continue Issues`: resolve or orchestrate another ready issue.
- Left: `Start Planning`: plan or brainstorm next work.
- Right: `Stop`: break the continuation loop.

If the user selects `Continue Issues`, ask:

Question id: `project_merge_issue_route`

Prompt: `How should the next issue be executed?`

Options:

- Down: `Resolve Another`: start `$superpowers-project:resolve-issue` for another ready issue mirror.
- Left: `Orchestrate Another`: start `$superpowers-project:orchestrate-issues` for another worker-suitable issue.
- Right: `Stop`: break the continuation loop.

If the user selects `Start Planning`, ask:

Question id: `project_merge_planning_route`

Prompt: `How should the next work be shaped?`

Options:

- Down: `Plan Next`: start `$superpowers-project:write-plan` from an approved spec or issue mirror.
- Left: `Brainstorm Next`: start `$superpowers-project:brainstorm-spec` for the next idea, spec, or architecture direction.
- Right: `Stop`: break the continuation loop.

If the user selects `Review / Repair Closeout`, ask:

Question id: `project_merge_reiteration_group`

Prompt: `How should I revisit this merge closeout?`

Options:

- Down: `Review Closeout`: show closeout evidence and rendered artifacts, then return to `project_merge_next_step`.
- Left: `Repair / Audit Closeout`: choose a repair or audit route.
- Right: `Stop`: break the continuation loop.

If the user selects `Repair / Audit Closeout`, ask:

Question id: `project_merge_repair_route`

Prompt: `Which closeout repair route should run?`

Options:

- Down: `Run Doctor`: start `$superpowers-project:audit-project` for post-merge drift audit or live sync review.
- Left: `Repair Or Cleanup`: choose drift repair or cleanup rerun.
- Right: `Stop`: break the continuation loop.

If the user selects `Repair Or Cleanup`, ask:

Question id: `project_merge_repair_cleanup_route`

Prompt: `Should I repair drift or rerun cleanup?`

Options:

- Down: `Repair Drift`: repair exact closeout drift after approval.
- Left: `Re-run Cleanup`: rerun cleanup and closeout proof.
- Right: `Stop`: break the continuation loop.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

## Scripted Gates

Run bundled scripts with explicit `-RepoRoot`:

- `scripts/collect-premerge-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrNumber <n> -IssueNumber <n> -VerificationCommands <commands> -ChangedFilesCovered <paths> -OutputDir <temp-or-handoff-dir>`: collects PR, issue, changed-file, check, and verification evidence into the verification ledger consumed by `scripts/premerge.ps1`.
- `scripts/premerge.ps1`: validates mode-specific evidence. `pr-issue` validates PR closing reference, checks, issue acceptance state, changed-file coverage, and proof commands. `pr-no-issue` validates source plan linkage, PR checks, changed-file coverage, proof commands, and absence of issue closure claims. `local-branch` validates source plan linkage, clean synced main proof, validation proof, branch linkage, and proof commands.
- `scripts/validate-merge-decision.ps1`: validates the native merge approval ledger and blocks declined decisions.
- `scripts/collect-closeout-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrNumber <n> -IssueNumber <n> -MergeDecisionJson <json> -CleanupHookOutput <text> -ResolveGoalCompletionProofJson <json> -MirrorCleanupJson <json> -OutputDir <temp-or-handoff-dir>`: collects merged PR, closed issue, cleanup, clean repo, native goal completion, mirror cleanup confirmation, and milestone closed-summary evidence into the completion ledger consumed by `scripts/closeout.ps1`. When no explicit `MirrorCleanupJson` is supplied for a closed issue, it deletes the mirror unless the mirror is marked `**Mirror Retention:** Keep`, and updates the milestone closed summary with GitHub issue and PR links.
- `scripts/closeout.ps1`: validates mode-specific closeout. `pr-issue` validates merged PR proof, linked issue closure proof, branch cleanup, worktree cleanup, prune proof, cleanup hook proof, closed mirror deletion or retention evidence, milestone closed-summary issue and PR links, and clean repo proof. `pr-no-issue` validates merged PR proof, native approval, branch/worktree cleanup, prune proof, cleanup hook proof, clean repo proof, and absence of issue closure claims. `local-branch` validates native approval, local merge proof, validation proof, branch/worktree cleanup, prune proof, cleanup hook proof, and clean repo proof.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Temp Plus Evidence

Normal runs should use `scripts/collect-premerge-ledger.ps1` before `scripts/premerge.ps1`, and `scripts/collect-closeout-ledger.ps1` before `scripts/closeout.ps1`. The collectors write generated ledgers to temp directories by default, or to explicit output directories when selected final evidence should be preserved.

This keeps generated ledgers passed to existing gates while avoiding a no hand-authored JSON requirement for ordinary merge work. The gate scripts remain authoritative; collectors only assemble evidence from GitHub, Git, cleanup output, native merge approval, and native goal completion proof.

## Completion Rule

Do not send a success-style final response until closeout proof shows:

- PR merged, or local branch merged in `local-branch` mode.
- Exact linked issue closed only in `pr-issue` mode.
- Default branch synced.
- Only the owned implementation branch deleted.
- Owned worktree removed or proven absent.
- `git fetch --prune` passed.
- Repo cleanup hook passed.
- Closed issue mirror was deleted by default or explicitly retained with `Mirror Retention: Keep` in `pr-issue` mode.
- Milestone page kept a closed issue summary with GitHub issue and PR links in `pr-issue` mode.
- Repo state is clean.




