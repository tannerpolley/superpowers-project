---
name: merge-changes
description: Use when a Superpowers Project issue-backed PR, worker handoff, or approved local branch must be reviewed, approved, merged, cleaned up, and recorded with clean repo proof.
---

# Project Merge

This skill owns integration after `$superpowers-project:resolve-issue` creates issue-backed PR-ready evidence or after approved plan work produces local branch merge-ready evidence. It supports two closeout modes:

- `pr-issue`: issue-backed PRs that must verify exact GitHub issue closure and issue mirror cleanup.
- `local-branch`: approved local branch merges linked to a source plan, with clean synced main proof, validation proof, native merge approval, branch/worktree cleanup, cleanup hook proof, and clean repo proof.

It starts from an issue-backed PR URL, issue-backed worker handoff, or local branch, verifies the issue mirror when the mode is `pr-issue`, verifies the source plan, requires readiness review proof, runs premerge checks, asks native UI merge approval, merges only after approval, cleans up the owned branch and worktree, runs `git fetch --prune`, runs the cleanup hook, and records final clean repo proof. PR options are allowed only when there is a companion issue mirror.

`$superpowers-project:merge-changes` is normally run by the main orchestrator thread. Workers do not merge their own PR by default.

## Superpowers Method Contract

This skill is the closeout Superpowers Project adapter for `superpowers:finishing-a-development-branch`.

Merge-changes requires upstream `superpowers:verification-before-completion` proof and does not replace it. Use this skill as the repo-specific closeout wrapper around `superpowers:finishing-a-development-branch`; do not treat merge-time judgment as a substitute for missing execution-time verification or branch-finish discipline.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with the plugin-provided Auto Mode validator from the loaded Superpowers Project plugin root (`<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `merge_permission.selected_mode: preauthorized-after-clean-premerge`, and `stop_outside_policy: true`.

Auto Mode merge approval is satisfied only after premerge proof passes cleanly and the ledger includes `preauthorized-after-clean-premerge`. Record that ledger as the merge approval source, then merge, run branch/worktree cleanup, prune, cleanup hook, closeout proof, and final clean repo proof without additional user input. If premerge proof fails, checks are pending or missing, issue closure evidence is wrong, local branch proof is incomplete, cleanup proof is missing, or any merge decision falls outside recorded defaults, stop outside policy before merging or final Done.

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
## Hard Failures

Stop immediately when any of these are true:

- No PR URL, worker handoff, or local branch is named.
- Mode is missing or is not `pr-issue` or `local-branch`.
- Mode is `pr-issue` and no linked issue mirror under `docs/superpowers/issues` can be identified.
- No linked source plan under `docs/superpowers/plans` can be identified.
- Mode is `pr-issue` and PR evidence does not close the exact linked GitHub issue.
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
- A terminal success or final closeout is attempted without a structured continuation decision ledger that records explicit `Stop` or verified final `Done`.

## State Machine

Follow this order exactly:

1. `merge intake`: read the issue-backed PR URL, worker handoff, or local branch.
2. `source linkage`: read the issue mirror, source plan, setup ledger, PR-ready handoff ledger, and verification ledger.
3. `premerge`: run `scripts/premerge.ps1` with real GitHub evidence or local fixtures.
4. `merge approval`: explain the clean premerge evidence, then ask native UI question `project_merge_approval`.
5. `merge`: merge the PR only when the user selects `Merge`.
6. `issue closure`: for `pr-issue`, verify the exact linked GitHub issue is closed; skip issue-close verification for `local-branch`.
7. `default sync`: sync the default branch.
8. `branch cleanup`: delete only the owned implementation branch locally and remotely.
9. `worktree cleanup`: remove only the owned worktree when one exists.
10. `prune`: run `git fetch --prune`.
11. `cleanup hook`: run the repo cleanup hook.
12. `closed mirror cleanup`: for `pr-issue`, delete the closed issue mirror by default, or retain it only with `**Mirror Retention:** Keep`; preserve the milestone history as a closed issue summary with GitHub issue and PR links. Do not require issue mirror cleanup for `local-branch`.
13. `clean state`: verify clean repo state and record closeout proof through `scripts/closeout.ps1`.
14. `terminal closeout`: before ending this skill as complete, collect a continuation decision ledger and validate explicit `Stop` or verified final `Done`. Any non-terminal route must keep the workflow running.

## Native Merge Approval

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` before asking this route's native continuation or permission question. Route-specific artifact inventory must include premerge proof, readiness review proof, linked issue or source-plan evidence, changed-artifact inventory from the branch being merged, verification commands, exact test values/results, and any cleanup or closeout drafts already assembled. Add the helper-required findings summary with route-specific status for the route result, remaining risks, active-goal impact, broader project context, and recommended next route.

Question id: `project_merge_approval`

Prompt shape:

```text
Premerge proof is clean for <PR URL or local branch>. Merge now?
```

Options:

- `Merge`: merge the issue-backed PR or local branch and continue closeout cleanup.
- `Decline`: stop without merging and report the exact pending state.

Use `Merge` as the recommended option only after premerge proof is clean. Do not merge without native UI approval.

## Reassessment Routing

If merge approval is declined, ask native follow-up through `advanced-user-input` when callable:

- `User Review`: stop with the PR or branch evidence.
- `Reassess Plan`: route to `$superpowers-project:write-plan` for strict execution, testing, acceptance, or branch strategy revision.
- `Reassess Spec`: route to `$superpowers-project:brainstorm-spec` for loose idea or scope reassessment.

When this thread is a worker/subagent and the merge decision belongs to the orchestrator, use the `request_agent_input` protocol instead of native `request_user_input`.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not merge, push, delete branches or worktrees, or pretend a live user approved merge work.
## Native Continuation Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` before asking this route's native continuation or permission question. Route-specific artifact inventory must include the merged issue-backed PR URL and closed issue for `pr-issue`, or the merged local branch for `local-branch`, plus synced default branch, branch and worktree cleanup proof, prune proof, cleanup hook proof, clean repo proof, verification commands, exact test values/results, and any machine-readable closeout ledgers. Add the helper-required findings summary with route-specific status for the merged issue-backed PR URL and closed issue for `pr-issue`, or the merged local branch for `local-branch`, plus synced default branch, branch and worktree cleanup proof, prune proof, cleanup hook proof, clean repo proof.

Done is valid only at a verified final Done gate. For `merge-changes`, that means clean closeout proof passed and `git status --short` is empty at the final health gate. If the repo worktree is still dirty after merge or cleanup, `Done` is invalid and the workflow must revisit cleanup instead. Stop remains the terminal option when premerge or closeout proof is incomplete. If closeout proof passes, ask:

Question id: `project_merge_final_health_gate`

Prompt: `Closeout proof is clean. Mark this workflow done?`

Options:

- Done: end the workflow as complete.
- Revisit: review closeout evidence, then return to `project_merge_next_step`.
- Stop: stop with clean closeout proof recorded.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

Question id: `project_merge_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: continue issue execution or start planning the next work.
- Revisit: review evidence, audit drift, repair closeout, or rerun cleanup.
- Stop: break the continuation loop.

If the user selects `Continue Project Execution`, ask:

Question id: `project_merge_continue_group`

Prompt: `Which kind of work should continue after this merge?`

Options:

- `Continue Issues`: resolve or orchestrate another ready issue.
- `Start Planning`: plan or brainstorm next work.

If the user selects `Continue Issues`, ask:

Question id: `project_merge_issue_route`

Prompt: `How should the next issue be executed?`

Options:

- `Resolve Another`: start `$superpowers-project:resolve-issue` for another ready issue mirror.
- `Orchestrate Another`: start `$superpowers-project:orchestrate-issues` for another worker-suitable issue.

If the user selects `Start Planning`, ask:

Question id: `project_merge_planning_route`

Prompt: `How should the next work be shaped?`

Options:

- `Plan Next`: start `$superpowers-project:write-plan` from an approved spec or issue mirror.
- `Brainstorm Next`: start `$superpowers-project:brainstorm-spec` for the next idea, spec, or architecture direction.

If the user selects `Review / Repair Closeout`, ask:

Question id: `project_merge_reiteration_group`

Prompt: `How should I revisit this merge closeout?`

Options:

- `Review Closeout`: show closeout evidence and rendered artifacts, then return to `project_merge_next_step`.
- `Repair / Audit Closeout`: choose a repair or audit route.

If the user selects `Repair / Audit Closeout`, ask:

Question id: `project_merge_repair_route`

Prompt: `Which closeout repair route should run?`

Options:

- `Run Align`: start `$superpowers-project:align-project` for post-merge drift alignment or live sync review.
- `Repair Or Cleanup`: choose drift repair or cleanup rerun.

If the user selects `Repair Or Cleanup`, ask:

Question id: `project_merge_repair_cleanup_route`

Prompt: `Should I repair drift or rerun cleanup?`

Options:

- `Repair Drift`: repair exact closeout drift after approval.
- `Re-run Cleanup`: rerun cleanup and closeout proof.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

Record the selected route in a structured continuation decision ledger. If the answer is `Stop`, or if `project_merge_final_health_gate` records verified `Done`, collect the ledger and run `scripts/validate-terminal-closeout.ps1` before any final success-style response. If the answer is any non-terminal route such as `Continue Project Execution`, `Continue Issues`, `Start Planning`, `Review Closeout`, `Run Align`, `Repair Drift`, or `Re-run Cleanup`, the ledger must still be recorded, and the thread must continue into that route instead of terminating.

## Scripted Gates

Run bundled scripts with explicit `-RepoRoot`:

- `scripts/collect-premerge-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrNumber <n> -IssueNumber <n> -VerificationCommands <commands> -ChangedFilesCovered <paths> -ReadinessReviewJson <json-or-path> -OutputDir <temp-or-handoff-dir>`: collects PR, issue, changed-file, check, readiness review, and verification evidence into the verification ledger consumed by `scripts/premerge.ps1`.
- `scripts/premerge.ps1`: validates mode-specific evidence. `pr-issue` validates readiness review, PR closing reference, checks, issue acceptance state, changed-file coverage, and proof commands. `local-branch` validates readiness review, source plan linkage, clean synced main proof, validation proof, branch linkage, and proof commands.
- `scripts/validate-merge-decision.ps1`: validates the native merge approval ledger and blocks declined decisions.
- `scripts/collect-closeout-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrNumber <n> -IssueNumber <n> -MergeDecisionJson <json> -CleanupHookOutput <text> -ResolveGoalCompletionProofJson <json> -MirrorCleanupJson <json> -OutputDir <temp-or-handoff-dir>`: collects merged issue-backed PR, closed issue, cleanup, clean repo, native goal completion, mirror cleanup confirmation, and milestone closed-summary evidence into the completion ledger consumed by `scripts/closeout.ps1`. When no explicit `MirrorCleanupJson` is supplied for a closed issue, it deletes the mirror unless the mirror is marked `**Mirror Retention:** Keep`, and updates the milestone closed summary with GitHub issue and PR links.
- `scripts/closeout.ps1`: validates mode-specific closeout. `pr-issue` validates merged PR proof, linked issue closure proof, branch cleanup, worktree cleanup, prune proof, cleanup hook proof, closed mirror deletion or retention evidence, milestone closed-summary issue and PR links, and clean repo proof. `local-branch` validates native approval, local merge proof, validation proof, branch/worktree cleanup, prune proof, cleanup hook proof, and clean repo proof.
- `scripts/collect-continuation-ledger.ps1 -RepoRoot . -QuestionId <id> -Prompt <text> -Source <request_user_input|debug_question_mode> -SelectedOptionId <id> -RecommendedOptionId <id> -TerminalState <stop|done|continue|revisit> -OptionIds <id1,id2,id3> -OutputDir <temp-or-handoff-dir>`: records the structured continuation decision after a merge closeout native route question.
- `scripts/validate-terminal-closeout.ps1 -RepoRoot . -CloseoutResultJson <json-or-path> -ContinuationDecisionJson <json-or-path>`: blocks terminal success unless clean closeout proof passed and the continuation decision records explicit `Stop` or verified final `Done` from `project_merge_final_health_gate`.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Temp Plus Evidence

Normal runs should use `scripts/collect-premerge-ledger.ps1` before `scripts/premerge.ps1`, and `scripts/collect-closeout-ledger.ps1` before `scripts/closeout.ps1`. The collectors write generated ledgers to temp directories by default, or to explicit output directories when selected final evidence should be preserved.

This keeps generated ledgers passed to existing gates while avoiding a no hand-authored JSON requirement for ordinary merge work. The gate scripts remain authoritative; collectors only assemble evidence from GitHub, Git, cleanup output, native merge approval, and native goal completion proof.

Premerge requires structured `readiness_review` proof with `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` all true. Missing or false readiness review blocks merge approval even when GitHub checks and local validation passed.

Terminal closeout is separate from merge closeout proof. If the thread is about to stop after merge closeout, collect the continuation decision with `scripts/collect-continuation-ledger.ps1` and pass it to `scripts/validate-terminal-closeout.ps1`. That terminal validator is authoritative for whether `merge-changes` may end the workflow; merge closeout proof alone is not terminal permission.

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
