# resolve-issue can stop at PR-ready without forced merge-changes gate

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/44
**GitHub Milestone:** M0 - Governance
**Issue Type:** bug
**Source Plan:** docs/superpowers/plans/2026-06-15-issue-44-resolve-terminal-closeout-plan.md
**Classification:** AFK
**Labels:** type:bug, status:ready
**Goal Command:** /goal Resolve GitHub issue 44 by making resolve-issue terminal closeout mechanically reject PR-ready success without a continuation ledger, preserve Merge as a non-terminal route, and prove the behavior with regression tests.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Current thread owns PR
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** No worktree created
**Orchestrator Wakeup Policy:** Inline run

## What To Build

Tighten the resolver terminal-closeout regression coverage so PR-ready output cannot be reported as terminal unless the explicit Stop continuation ledger validates. Preserve the existing Merge route as a non-terminal continuation that must start `merge-changes`, not end `resolve-issue`.

## Feedback Loop

During ePC-SAFT issue #247 resolution, the `resolve-issue` workflow reached PR-ready state for PR #249 and returned a success-style closeout before `merge-changes` approval, merge, issue closure, branch cleanup, and closeout proof. The corrective workflow had to resume `merge-changes` manually afterward.

## Acceptance Criteria

- [ ] A resolve-issue run with PR-ready proof but no continuation ledger fails terminal closeout.
- [ ] A resolve-issue run with continuation decision `Merge` cannot produce terminal success until `merge-changes` has started or completed according to the workflow mode.
- [ ] A resolve-issue run with explicit `Stop` passes only when `validate-terminal-closeout.ps1` sees the Stop ledger.
- [ ] Resolver scenario tests cover the invalid PR-ready terminal path so this gap does not recur.
- [ ] The PR body includes `Closes #44`.

## Blocked by

- None

## Non-goals

- Do not merge resolved issue PRs from `resolve-issue`.
- Do not weaken `merge-changes` closeout gates.
- Do not allow `Done` as a terminal resolve-issue option.
- Do not add GoalBuddy board state.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\validate-issue-mirror.ps1 -IssueFile docs/superpowers/issues/44-resolve-issue-can-stop-at-pr-ready-without-forced-merge-changes-gate.md -MilestoneRequired`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-15-issue-44-resolve-terminal-closeout-plan.md`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
