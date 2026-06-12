# Issue 42 Plan Task Validator Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `scripts\validate-plan-task-use-cases.ps1` as a tracked Superpowers Project plugin runtime script so planning and implementation gates can run from synced live and cached plugin surfaces.

**Architecture:** Treat the plan task use-case validator like the existing runtime scripts that the plugin ships outside skill folders. Copy it during live sync and cache refresh, compare it during live drift checks, and include it in the agent plugin version contract hash.

**Tech Stack:** PowerShell sync scripts, plugin runtime surface hashing, live install drift checks, local scenario tests.

---

## Source And Scope

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/42

**Source Spec:** `docs/superpowers/specs/2026-06-11-plan-task-use-cases-strict-contract.md`

**Issue Mirror:** `docs/superpowers/issues/42-ship-or-install-validate-plan-task-use-cases.md`

## Acceptance Criteria

- `scripts\sync-live.ps1` copies `scripts\validate-plan-task-use-cases.ps1` into the live plugin `scripts` directory.
- `scripts\lib\plugin-cache.ps1` copies `scripts\validate-plan-task-use-cases.ps1` into refreshed local plugin cache roots.
- `scripts\lib\live-install.ps1` detects missing or drifted live validator files.
- `scripts\get-agent-plugin-version.ps1` includes the validator in the runtime contract hash.
- Focused tests prove live sync, cache refresh, live drift detection, and version freshness include the validator.
- Full validation and `scripts\sync-live.ps1 -Validate` pass.

## Non-Goals

- Do not change the validator behavior.
- Do not replace repo-root validation commands in skills.
- Do not edit plugin cache files directly.
- Do not implement the missing external issue hydration helper as part of this issue.

## Proof Oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-12-issue-42-plan-task-validator-runtime-plan.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-task-use-cases.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plugin-only-live-sync.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-agent-plugin-version.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

## Test Complete

Testing is complete when the proof oracle passes and the cleanup hook reports no leftover processes owned by this repo. No numerical engineering metric applies; this issue is pass/fail based on runtime file presence, drift detection, contract hash coverage, full validation, and live sync validation.

## Task 1: Ship The Validator In Runtime Surfaces

**Use Cases:**
- A live plugin install contains `scripts\validate-plan-task-use-cases.ps1` after sync.
- A refreshed local plugin cache root contains `scripts\validate-plan-task-use-cases.ps1`.
- A missing live validator is reported as drift before an agent claims the plugin is current.
- A changed live validator changes the runtime contract comparison.

**Files:**
- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/lib/plugin-cache.ps1`
- Modify: `scripts/lib/live-install.ps1`
- Modify: `scripts/get-agent-plugin-version.ps1`

- [ ] **Step 1: Add the runtime validator path to sync-live**
  Add `$sourcePlanTaskUseCasesValidator = Join-Path $repoRoot "scripts\validate-plan-task-use-cases.ps1"` near the other source runtime script variables.

- [ ] **Step 2: Require and copy the validator in sync-live**
  Validate that `$sourcePlanTaskUseCasesValidator` exists, then copy it to `Join-Path $livePluginScriptsRoot "validate-plan-task-use-cases.ps1"` with `-Force`.

- [ ] **Step 3: Add the validator to cache runtime copying**
  In `scripts/lib/plugin-cache.ps1`, add `$sourcePlanTaskUseCasesValidator`, include it in the required runtime surface list, and copy it to the target plugin `scripts` directory.

- [ ] **Step 4: Add live install drift detection**
  In `scripts/lib/live-install.ps1`, compare the source validator and live validator with label `plugin plan task use-case validator`.

- [ ] **Step 5: Add version hash coverage**
  In `scripts/get-agent-plugin-version.ps1`, include `scripts\validate-plan-task-use-cases.ps1` in `Get-RuntimeContractEntries`.

## Task 2: Prove Runtime Coverage With Tests

**Use Cases:**
- Existing plugin-only sync tests fail if sync-live stops mentioning or copying the validator.
- Live drift tests fail if the validator is altered in the live plugin fixture.
- Cache refresh tests fail if the validator is missing from the cached plugin fixture after refresh.
- Version freshness tests fail when observed plugin roots differ only by the validator.

**Files:**
- Modify: `scripts/test-plugin-only-live-sync.ps1`
- Modify: `scripts/test-agent-plugin-version.ps1`

- [ ] **Step 1: Extend sync policy text assertions**
  Add `validate-plan-task-use-cases.ps1` to the required sync-live policy text needles in `scripts/test-plugin-only-live-sync.ps1`.

- [ ] **Step 2: Extend live fixture copying**
  Copy `scripts\validate-plan-task-use-cases.ps1` into live and cached fixture plugin roots wherever the tests already copy the version checker and Auto Mode validator.

- [ ] **Step 3: Extend drift fixture assertions**
  Append fixture drift to the live validator in the full live install comparer test and assert the labels include `plugin plan task use-case validator`.

- [ ] **Step 4: Extend version runtime fixture copying**
  In `scripts/test-agent-plugin-version.ps1`, copy the validator in `Copy-RuntimeSurface` so version tests model the real runtime surface.

- [ ] **Step 5: Add observed validator drift coverage**
  In `scripts/test-agent-plugin-version.ps1`, alter only the observed plugin validator in a fixture and assert `-RequireCurrent` fails with an observed freshness reason.

## Task 3: Validate, Sync, And Close Issue 42

**Use Cases:**
- The issue mirror validates before execution closeout.
- Focused tests pass before full validation.
- Live sync validation proves the validator is present in live and refreshed cache runtime surfaces.
- The PR body can close GitHub issue #42 with clear proof.

**Files:**
- Create: `docs/superpowers/issues/42-ship-or-install-validate-plan-task-use-cases.md`
- Create: `docs/superpowers/plans/2026-06-12-issue-42-plan-task-validator-runtime-plan.md`
- Modify: live deployed plugin copy through `scripts\sync-live.ps1 -Validate`
- No direct edits to plugin cache paths

- [ ] **Step 1: Validate issue artifacts**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\validate-issue-mirror.ps1 -IssueFile docs/superpowers/issues/42-ship-or-install-validate-plan-task-use-cases.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-12-issue-42-plan-task-validator-runtime-plan.md
```

  Expected result: both commands return `ok: true`.

- [ ] **Step 2: Run focused tests**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-task-use-cases.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plugin-only-live-sync.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-agent-plugin-version.ps1
```

  Expected result: every command exits `0`.

- [ ] **Step 3: Run full validation and sync**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

  Expected result: every command exits `0`; sync output includes the live plugin root and refreshed cache plugin roots.

- [ ] **Step 4: Prepare closeout evidence**
  Confirm the branch diff includes runtime surface copying, drift detection, version hash coverage, tests, this source plan, and the issue mirror. Use a PR body that includes `Closes #42`.

## Self-Review

- The issue source is linked.
- Every task has concrete use cases before files and steps.
- Acceptance criteria map to tasks.
- Proof oracle includes focused tests, full validation, and live sync validation.
- The plan does not require direct plugin cache edits.
