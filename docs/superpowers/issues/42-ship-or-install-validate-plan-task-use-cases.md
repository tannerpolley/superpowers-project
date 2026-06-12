# Ship or install validate-plan-task-use-cases.ps1 for planning workflows

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/42
**GitHub Milestone:** M2 - Distribution
**Issue Type:** bug
**Source Spec:** docs/superpowers/specs/2026-06-11-plan-task-use-cases-strict-contract.md
**Source Plan:** docs/superpowers/plans/2026-06-12-issue-42-plan-task-validator-runtime-plan.md
**Classification:** AFK
**Labels:** type:bug, status:ready
**Goal Command:** /goal Resolve GitHub issue 42 by shipping validate-plan-task-use-cases.ps1 in Superpowers Project runtime surfaces, validating live/cache sync coverage, and opening PR-ready work that closes https://github.com/tannerpolley/superpowers-project/issues/42.
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

Ship `scripts\validate-plan-task-use-cases.ps1` with the plugin runtime surface and make live install, cache refresh, and version freshness checks track it.

## Feedback Loop

The GitHub issue reports that Superpowers Project skills require:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <saved-plan-path>
```

The source repo contains the validator, but the plugin runtime sync path currently copies only selected scripts and `scripts\lib`, so a live or cached plugin bundle can reference the validator without shipping it.

## Acceptance Criteria

- [ ] `scripts\sync-live.ps1` copies `scripts\validate-plan-task-use-cases.ps1` into the live plugin runtime.
- [ ] `scripts\lib\plugin-cache.ps1` copies `scripts\validate-plan-task-use-cases.ps1` into refreshed local plugin cache roots.
- [ ] `scripts\lib\live-install.ps1` detects missing or drifted live validator files.
- [ ] `scripts\get-agent-plugin-version.ps1` includes the validator in runtime contract hashing.
- [ ] Focused tests cover live sync, cache sync, live drift detection, and observed-root freshness for the validator.
- [ ] `scripts\validate.ps1` and `scripts\sync-live.ps1 -Validate` pass.
- [ ] The PR body includes `Closes #42`.

## Blocked by

- None

## Non-goals

- Do not change validator behavior.
- Do not change the task use-case contract.
- Do not directly edit plugin cache files.
- Do not implement external issue hydration in this issue.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\validate-issue-mirror.ps1 -IssueFile docs/superpowers/issues/42-ship-or-install-validate-plan-task-use-cases.md`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-12-issue-42-plan-task-validator-runtime-plan.md`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-task-use-cases.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plugin-only-live-sync.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-agent-plugin-version.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
