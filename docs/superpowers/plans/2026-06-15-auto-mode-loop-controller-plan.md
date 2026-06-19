# Auto Mode Loop Controller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first contracts-first Loop Controller layer above Auto Mode so Superpowers Project can coordinate repeated workflow runs without weakening existing approval gates.

**Architecture:** Add a new source-owned `loop-controller` skill plus PowerShell validators for local run ledgers, budgets, candidate selection, verifier proof, terminal closeout, and metrics. Keep Auto Mode as route authorization only; Loop Controller records orchestration evidence and delegates actual work to the existing workflow skills.

**Tech Stack:** PowerShell 7, Markdown skill contracts, JSON ledgers, existing Superpowers Project validators, existing `scripts/validate.ps1`, existing `scripts/sync-live.ps1`.

---

## Source Evidence

- Source spec: `docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md`
- User-approved design: Design 1, layered Loop Controller over Auto Mode.
- User-approved first slice: `Contracts First`.
- User-approved run state: generated local runtime ledgers under `.superpowers/runs/<run-id>`.
- User-approved test-complete proof: focused Loop Controller tests, plan use-case validation, `scripts/validate.ps1`, `scripts/sync-live.ps1 -Validate`, and cleanup proof.
- Existing Auto Mode proof surface: `scripts/lib/auto-mode-contract.ps1`, `scripts/validate-auto-mode-authorization.ps1`, `scripts/test-auto-mode-contract.ps1`.
- Existing version proof surface: `scripts/get-agent-plugin-version.ps1`, `scripts/test-agent-plugin-version.ps1`.
- Existing continuation proof surface: `scripts/test-native-continuation-loop.ps1`, `docs/superpowers/OUTCOME_WORKFLOW.md`.

## Test-Complete Definition

This plan is test complete when:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md` passes.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1` passes.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1` passes.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` passes.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` passes before reporting live install readiness.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .` reports no matching leftover repo-owned processes.

No scientific or engineering numerical metrics are required. This is a workflow governance feature. Pass/fail is contract-based: required files exist, required question IDs exist, validators reject unsafe ledgers, fixture runs produce deterministic JSON, and native approval boundaries remain intact.

## Acceptance Criteria

- A new `$superpowers-project:loop-controller` skill exists under `skills/loop-controller`.
- Plugin docs and metadata expose Loop Controller without removing existing workflow routes.
- Loop Controller startup instructions require the existing plugin version banner before orchestration.
- Loop Controller skill text defines the boundary: Loop Controller coordinates runs, Auto Mode authorizes known routes, existing skills own work.
- Loop run ledgers validate required fields and live under `.superpowers/runs/<run-id>` by default.
- Budget validation rejects exhausted attempts, repeated same failure, candidate count, changed-file count, GitHub mutation count, validator rerun count, and diff-size cases.
- Candidate selection deterministically chooses a safe ready candidate from fixture inventories and records skipped candidates with reasons.
- Verifier ledger validation requires proof before merge-ready or final `Done`.
- Terminal closeout validation rejects missing verifier proof, dirty repo state when a clean state is required, missing metrics, and invalid continuation decisions.
- Metrics report generation records elapsed time, attempts, validation failures, retry count, human input count, PR/issue counts when present, final outcome, and accepted-change evidence.
- Focused tests and full validation are wired into `scripts/validate.ps1`.
- `docs/superpowers/OUTCOME_WORKFLOW.md` includes the Loop Controller route and native question IDs after regeneration.

## Non-Goals

- Do not change Auto Mode into the orchestration layer.
- Do not add real scheduled automations in this first slice.
- Do not perform real GitHub mutation in default tests.
- Do not create GitHub issues from this plan.
- Do not bypass push, merge, GitHub mutation, live sync, or final `Done` gates.
- Do not store default run ledgers as committed docs.
- Do not edit live deployed plugin copies directly.
- Do not require a localhost server or external service.

## File Map

- Create: `skills/loop-controller/SKILL.md`
- Create: `skills/loop-controller/agents/openai.yaml`
- Create: `skills/loop-controller/scripts/lib/loop-controller.ps1`
- Create: `skills/loop-controller/scripts/validate-run-ledger.ps1`
- Create: `skills/loop-controller/scripts/validate-budget.ps1`
- Create: `skills/loop-controller/scripts/select-candidate.ps1`
- Create: `skills/loop-controller/scripts/validate-verifier-ledger.ps1`
- Create: `skills/loop-controller/scripts/validate-terminal-closeout.ps1`
- Create: `skills/loop-controller/scripts/write-metrics-report.ps1`
- Create: `skills/loop-controller/scripts/test-scenarios.ps1`
- Create: `scripts/test-loop-controller.ps1`
- Modify: `.codex-plugin/plugin.json`
- Modify: `README.md`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`
- Modify: `scripts/lib/project-skills.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `CHANGELOG.md`

## Branch And Commit Strategy

- Use a development branch named `codex/loop-controller-contracts` when executing this plan.
- Commit after each task when its focused tests pass.
- Do not push, merge, sync live, or publish without the owning native permission gate.
- Prefer `Project Implement` after this plan if the work should remain branch-backed and not issue-backed.

## Task 1: Register Loop Controller Skill And Contract Test

**Use Cases:**
- User asks for loop behavior and the plugin exposes a canonical `$superpowers-project:loop-controller` route instead of overloading Auto Mode.
- A new agent starts Loop Controller and sees mandatory version-banner, run-ledger, native continuation, and approval-boundary instructions.
- Source validation treats `loop-controller` as an active source-owned skill.
- Contract summary generation lists Loop Controller native question IDs and final health gate status.

**Files:**
- Create: `scripts/test-loop-controller.ps1`
- Create: `skills/loop-controller/SKILL.md`
- Create: `skills/loop-controller/agents/openai.yaml`
- Modify: `.codex-plugin/plugin.json`
- Modify: `README.md`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `scripts/lib/project-skills.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Write the failing contract test**

Create `scripts/test-loop-controller.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Assert-Contains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Add-Check -Name $Name -Ok $false -Reason "$Path is missing"
        return
    }
    $text = Get-Content -LiteralPath $full -Raw
    Add-Check -Name $Name -Ok $text.Contains($Needle) -Reason "$Path missing $Needle"
}

try {
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "name: loop-controller" -Name "skill frontmatter exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "Question id: `project_loop_next_step`" -Name "next-step question id exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "Question id: `project_loop_final_health_gate`" -Name "final health gate question id exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "Auto Mode is a route permission ledger" -Name "auto mode boundary exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent" -Name "startup version check exists"
    Assert-Contains -Path "skills\loop-controller\agents\openai.yaml" -Needle "loop-controller" -Name "metadata exists"
    Assert-Contains -Path ".codex-plugin\plugin.json" -Needle '$superpowers-project:loop-controller' -Name "plugin prompt lists route"
    Assert-Contains -Path "README.md" -Needle '$superpowers-project:loop-controller' -Name "README lists route"
    Assert-Contains -Path "docs\superpowers\PROJECT_CONTEXT.md" -Needle "loop-controller" -Name "project context lists skill"
    Assert-Contains -Path "scripts\lib\project-skills.ps1" -Needle '"loop-controller"' -Name "final-capable list includes loop-controller"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "loop-controller-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "loop-controller-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 2: Run the contract test and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1
```

Expected: command exits nonzero because `skills/loop-controller/SKILL.md` does not exist yet.

- [ ] **Step 3: Create the Loop Controller skill contract**

Create `skills/loop-controller/SKILL.md`:

```markdown
---
name: loop-controller
description: Use when Superpowers Project should coordinate repeated workflow runs across candidates while preserving Auto Mode authorization and native approval gates.
---

# Loop Controller

Loop Controller is the Superpowers Project orchestration layer for repeated workflow runs. It creates or resumes a local run ledger, selects one safe candidate, enforces budgets, routes to existing skills, records verifier proof, writes metrics, and asks native continuation questions.

**Announce at start:** "I'm using the loop-controller skill."

## Startup Version Gate

Before selecting candidates, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent
```

If the loaded plugin or skill root is known, pass `-ObservedPluginRoot` or `-ObservedSkillRoot`. Print the banner before routing.

## Boundary

Auto Mode is a route permission ledger. Loop Controller is the run coordinator. Loop Controller may validate and carry an Auto Mode authorization path, but it must not treat Auto Mode as permission to select unrelated work, widen mutation scope, bypass proof, push, merge, mutate GitHub, sync live, or claim final Done.

Existing skills own work:

- `$superpowers-project:brainstorm-spec` owns idea shaping and specs.
- `$superpowers-project:write-plan` owns implementation plans.
- `$superpowers-project:create-issues` owns issue creation.
- `$superpowers-project:implement-plan` owns branch-backed plan execution.
- `$superpowers-project:resolve-issue` owns direct issue resolution.
- `$superpowers-project:orchestrate-issues` owns worker-thread issue execution.
- `$superpowers-project:merge-changes` owns merge closeout.
- `$superpowers-project:audit-project` owns evidence-backed audit findings.
- `$superpowers-project:align-project` owns source/live/tracker drift repair.

## Run State

Default generated run state lives under `.superpowers/runs/<run-id>`. Do not commit generated run ledgers unless a later approved plan explicitly requests durable committed run history.

## Required Gates

- Validate run ledgers with `skills/loop-controller/scripts/validate-run-ledger.ps1`.
- Validate budget ledgers with `skills/loop-controller/scripts/validate-budget.ps1`.
- Select candidates with `skills/loop-controller/scripts/select-candidate.ps1`.
- Validate verifier evidence with `skills/loop-controller/scripts/validate-verifier-ledger.ps1`.
- Validate terminal closeout with `skills/loop-controller/scripts/validate-terminal-closeout.ps1`.
- Write metrics with `skills/loop-controller/scripts/write-metrics-report.ps1`.

## Native Continuation Gate

Question id: `project_loop_next_step`

Prompt: `Should I continue on with the loop workflow?`

Options:

- Yes: select or run the next candidate route within budget and policy.
- Revisit: review evidence, repair run state, adjust candidate selection, or rerun validation.
- Stop: pause the loop with recorded run state.

If Yes has multiple route choices, ask a nested route question before starting the selected skill. Do not merge route children into the top-level question.

## Final Health Gate

Question id: `project_loop_final_health_gate`

Prompt: `Is this loop run fully complete?`

Options:

- Done: valid only after clean run ledger, verifier proof, metrics, and clean repo or explicitly scoped non-repo state.
- Revisit: review or repair evidence before terminal closeout.
- Stop: pause with run state recorded, without claiming final completion.

Terminal Done requires `validate-terminal-closeout.ps1` to pass. A saved plan, pushed branch, created issue, synced live plugin, or completed validator run is not terminal by itself.
```

- [ ] **Step 4: Create skill metadata**

Create `skills/loop-controller/agents/openai.yaml`:

```yaml
interface:
  display_name: "Loop Controller"
  short_description: "Coordinate repeated Superpowers Project workflow runs with run ledgers, budgets, verifier proof, and native gates."
  default_prompt: >-
    Use $superpowers-project:loop-controller when a Superpowers Project workflow should discover a safe candidate, enforce budget, route through existing skills, record verifier evidence, write metrics, and ask native continuation questions.
    Auto Mode is only route authorization; Loop Controller coordinates runs and must not bypass push, merge, GitHub mutation, live sync, or final Done gates.
    Generated run state lives under .superpowers/runs by default.
```

- [ ] **Step 5: Register the route in plugin-facing source**

Update `.codex-plugin/plugin.json` `interface.defaultPrompt` with:

```json
"Use $superpowers-project:loop-controller to coordinate repeated workflow runs with run ledgers, budgets, verifier proof, metrics, and native continuation gates."
```

Update `README.md` current skills with:

```markdown
- `$superpowers-project:loop-controller`: coordinates repeated workflow runs with local run ledgers, budgets, candidate selection, verifier proof, metrics, and native continuation gates.
```

Update `docs/superpowers/PROJECT_CONTEXT.md` extension skills with:

```markdown
- `loop-controller`
```

Update `scripts/lib/project-skills.ps1`:

```powershell
function Get-ProjectFinalCapableSkillNames {
    @("align-project", "loop-controller", "merge-changes")
}
```

Add a `CHANGELOG.md` unreleased entry:

```markdown
- Added the source contract for `$superpowers-project:loop-controller`.
```

- [ ] **Step 6: Wire the contract test into full validation**

Modify `scripts/validate.ps1` after the `Auto Mode authorization contract` check:

```powershell
$results.Add((Invoke-Step "Loop Controller contract" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-loop-controller.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Loop Controller contract failed" }
}))
```

- [ ] **Step 7: Run focused contract validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1
```

Expected: JSON output has `"ok": true`.

- [ ] **Step 8: Commit the skill shell**

Run:

```powershell
git add .codex-plugin\plugin.json README.md CHANGELOG.md docs\superpowers\PROJECT_CONTEXT.md scripts\lib\project-skills.ps1 scripts\test-loop-controller.ps1 scripts\validate.ps1 skills\loop-controller\SKILL.md skills\loop-controller\agents\openai.yaml
git commit -m "Add loop controller skill contract"
```

Expected: commit succeeds.

## Task 2: Add Run Ledger Schema And Validator

**Use Cases:**
- Loop Controller starts a run and records source version, candidate, route, budget, proof, and terminal fields in a machine-readable ledger.
- A resumed loop rejects a hand-edited ledger that is missing required fields.
- Generated run ledgers stay under `.superpowers/runs/<run-id>` and do not become canonical docs by accident.
- A stale observed plugin version blocks unattended continuation before work starts.

**Files:**
- Create: `skills/loop-controller/scripts/lib/loop-controller.ps1`
- Create: `skills/loop-controller/scripts/validate-run-ledger.ps1`
- Create: `skills/loop-controller/scripts/test-scenarios.ps1`

- [ ] **Step 1: Write failing scenario coverage for run ledgers**

Create `skills/loop-controller/scripts/test-scenarios.ps1` with a first scenario that writes a valid ledger, validates it, writes an invalid ledger missing `plugin_contract_hash`, and proves validation rejects it:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("loop-controller-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-JsonScript {
    param([string]$Path, [string[]]$Arguments)
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = ($raw | Out-String).Trim(); json = (($raw | Out-String).Trim() | ConvertFrom-Json) }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $runRoot = Join-Path $RepoRoot ".superpowers\runs\fixture-run"
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
    $validLedger = Join-Path $runRoot "loop-run-ledger.json"
    @{
        run_id = "fixture-run"
        trigger_source = "manual"
        repo_root = $RepoRoot
        plugin_manifest_version = "0.2.0+fixture"
        plugin_contract_hash = "abc123"
        started_at = "2026-06-15T00:00:00Z"
        updated_at = "2026-06-15T00:00:01Z"
        status = "running"
        current_phase = "candidate-selection"
        candidate_source = "fixture"
        candidate_id = "candidate-1"
        selected_route = "write-plan"
        route_reason = "approved spec needs plan"
        budget_policy = @{ max_candidates = 1; max_attempts_per_phase = 2; max_repeated_same_failure = 1; max_changed_files = 20; max_github_mutations = 0; max_validator_reruns = 5; max_unreviewed_diff_lines = 800 }
        attempts = @()
        last_blocker = $null
        branch = "codex/loop-controller-contracts"
        worktree_path = $null
        auto_mode_authorization_path = $null
        proof_artifacts = @()
        verifier_artifacts = @()
        metrics_artifacts = @()
        terminal_decision = $null
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $validLedger -Encoding utf8NoBOM

    $validator = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-run-ledger.ps1"
    $valid = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-RunLedgerPath", $validLedger)
    Add-Check -Name "valid run ledger passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason $valid.raw

    $invalidLedger = Join-Path $tempRoot "missing-contract-hash.json"
    $invalid = Get-Content -LiteralPath $validLedger -Raw | ConvertFrom-Json
    $invalid.PSObject.Properties.Remove("plugin_contract_hash")
    $invalid | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $invalidLedger -Encoding utf8NoBOM
    $invalidResult = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-RunLedgerPath", $invalidLedger)
    Add-Check -Name "missing contract hash fails" -Ok ($invalidResult.exit_code -ne 0 -and $invalidResult.json.ok -eq $false) -Reason "missing contract hash should fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "loop-controller-scenarios"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "loop-controller-scenarios"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    $fixtureRun = Join-Path $RepoRoot ".superpowers\runs\fixture-run"
    if (Test-Path -LiteralPath $fixtureRun) { Remove-Item -LiteralPath $fixtureRun -Recurse -Force }
}
```

- [ ] **Step 2: Run the scenario test and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: command exits nonzero because `validate-run-ledger.ps1` does not exist yet.

- [ ] **Step 3: Add the shared Loop Controller library**

Create `skills/loop-controller/scripts/lib/loop-controller.ps1`:

```powershell
$ErrorActionPreference = "Stop"

function Test-LoopControllerProperty {
    param([object]$Object, [string]$Name)
    $null -ne $Object.PSObject.Properties[$Name]
}

function Resolve-LoopControllerRepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
    }
    (Resolve-Path -LiteralPath $RepoRoot).Path
}

function ConvertTo-LoopControllerRelativePath {
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string]$Path)
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $candidate -ne $root) {
        throw "path is outside repo root: $candidate"
    }
    ([IO.Path]::GetRelativePath($root, $candidate) -replace "\\", "/")
}

function Read-LoopControllerJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "json file does not exist: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function New-LoopControllerResult {
    param([bool]$Ok, [string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    $result = [ordered]@{ ok = $Ok; phase = $Phase; reason = $Reason }
    foreach ($key in $Evidence.Keys) { $result[$key] = $Evidence[$key] }
    [pscustomobject]$result
}

function Assert-LoopRequiredProperties {
    param([object]$Object, [string[]]$Names)
    foreach ($name in $Names) {
        if (-not (Test-LoopControllerProperty -Object $Object -Name $name)) { throw "$name is required" }
        $value = $Object.$name
        if ($null -eq $value) { throw "$name is required" }
        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) { throw "$name is required" }
    }
}
```

- [ ] **Step 4: Add the run ledger validator**

Create `skills/loop-controller/scripts/validate-run-ledger.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$RunLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $ledgerFull = if ([IO.Path]::IsPathRooted($RunLedgerPath)) { [IO.Path]::GetFullPath($RunLedgerPath) } else { [IO.Path]::GetFullPath((Join-Path $repo $RunLedgerPath)) }
    $relative = ConvertTo-LoopControllerRelativePath -RepoRoot $repo -Path $ledgerFull
    if (-not $relative.StartsWith(".superpowers/runs/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "run ledger must live under .superpowers/runs by default: $relative"
    }
    $ledger = Read-LoopControllerJson -Path $ledgerFull
    Assert-LoopRequiredProperties -Object $ledger -Names @(
        "run_id", "trigger_source", "repo_root", "plugin_manifest_version", "plugin_contract_hash",
        "started_at", "updated_at", "status", "current_phase", "candidate_source", "candidate_id",
        "selected_route", "route_reason", "budget_policy", "attempts", "branch",
        "proof_artifacts", "verifier_artifacts", "metrics_artifacts"
    )
    if ([string]$ledger.status -notin @("created", "running", "paused", "blocked", "complete")) { throw "status is invalid: $($ledger.status)" }
    if ([string]$ledger.selected_route -notin @("brainstorm-spec", "write-plan", "create-issues", "implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes", "audit-project", "align-project")) {
        throw "selected_route is invalid: $($ledger.selected_route)"
    }
    $result = New-LoopControllerResult -Ok $true -Phase "loop-run-ledger" -Reason "run ledger is valid" -Evidence @{ run_ledger_path = $relative; status = [string]$ledger.status; selected_route = [string]$ledger.selected_route }
    $result | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-run-ledger" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 5: Run focused run-ledger tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: JSON output has `"ok": true` for the run-ledger scenarios.

- [ ] **Step 6: Commit run-ledger validation**

Run:

```powershell
git add skills\loop-controller\scripts
git commit -m "Validate loop controller run ledgers"
```

Expected: commit succeeds.

## Task 3: Add Budget Validation

**Use Cases:**
- Loop Controller stops before running another candidate when candidate, retry, mutation, or diff budgets are exhausted.
- A repeated same-failure loop stops loudly and records the blocker instead of continuing indefinitely.
- A low-risk doc-only fixture can proceed when all budgets are within policy.
- A future automation entrypoint can validate budget state without reading prose.

**Files:**
- Create: `skills/loop-controller/scripts/validate-budget.ps1`
- Modify: `skills/loop-controller/scripts/test-scenarios.ps1`

- [ ] **Step 1: Extend scenarios with budget pass and fail cases**

Add fixture ledgers to `skills/loop-controller/scripts/test-scenarios.ps1` that call `validate-budget.ps1` with:

```powershell
$budgetScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-budget.ps1"
$budgetOkPath = Join-Path $tempRoot "budget-ok.json"
@{
    max_candidates = 2
    candidates_completed = 1
    max_attempts_per_phase = 3
    current_phase_attempts = 1
    max_repeated_same_failure = 2
    repeated_same_failure_count = 0
    max_changed_files = 20
    changed_files = 3
    max_github_mutations = 0
    github_mutations = 0
    max_validator_reruns = 6
    validator_reruns = 2
    max_unreviewed_diff_lines = 800
    unreviewed_diff_lines = 120
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $budgetOkPath -Encoding utf8NoBOM
$budgetOk = Invoke-JsonScript -Path $budgetScript -Arguments @("-RepoRoot", $RepoRoot, "-BudgetLedgerPath", $budgetOkPath)
Add-Check -Name "budget within policy passes" -Ok ($budgetOk.exit_code -eq 0 -and $budgetOk.json.ok -eq $true) -Reason $budgetOk.raw

$budgetFailPath = Join-Path $tempRoot "budget-fail.json"
@{
    max_candidates = 1
    candidates_completed = 1
    max_attempts_per_phase = 2
    current_phase_attempts = 2
    max_repeated_same_failure = 1
    repeated_same_failure_count = 1
    max_changed_files = 4
    changed_files = 5
    max_github_mutations = 0
    github_mutations = 1
    max_validator_reruns = 3
    validator_reruns = 4
    max_unreviewed_diff_lines = 100
    unreviewed_diff_lines = 101
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $budgetFailPath -Encoding utf8NoBOM
$budgetFail = Invoke-JsonScript -Path $budgetScript -Arguments @("-RepoRoot", $RepoRoot, "-BudgetLedgerPath", $budgetFailPath)
Add-Check -Name "exhausted budget fails" -Ok ($budgetFail.exit_code -ne 0 -and $budgetFail.json.ok -eq $false) -Reason "exhausted budget should fail"
```

- [ ] **Step 2: Run the scenarios and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: command exits nonzero because `validate-budget.ps1` does not exist yet.

- [ ] **Step 3: Add the budget validator**

Create `skills/loop-controller/scripts/validate-budget.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$BudgetLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

function Assert-UnderLimit {
    param([object]$Ledger, [string]$Actual, [string]$Maximum)
    Assert-LoopRequiredProperties -Object $Ledger -Names @($Actual, $Maximum)
    if ([int]$Ledger.$Actual -ge [int]$Ledger.$Maximum) { throw "$Actual exhausted: $($Ledger.$Actual) >= $($Ledger.$Maximum)" }
}

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $budget = Read-LoopControllerJson -Path (if ([IO.Path]::IsPathRooted($BudgetLedgerPath)) { $BudgetLedgerPath } else { Join-Path $repo $BudgetLedgerPath })
    Assert-UnderLimit -Ledger $budget -Actual "candidates_completed" -Maximum "max_candidates"
    Assert-UnderLimit -Ledger $budget -Actual "current_phase_attempts" -Maximum "max_attempts_per_phase"
    Assert-UnderLimit -Ledger $budget -Actual "repeated_same_failure_count" -Maximum "max_repeated_same_failure"
    Assert-UnderLimit -Ledger $budget -Actual "changed_files" -Maximum "max_changed_files"
    Assert-UnderLimit -Ledger $budget -Actual "github_mutations" -Maximum "max_github_mutations"
    Assert-UnderLimit -Ledger $budget -Actual "validator_reruns" -Maximum "max_validator_reruns"
    Assert-UnderLimit -Ledger $budget -Actual "unreviewed_diff_lines" -Maximum "max_unreviewed_diff_lines"
    New-LoopControllerResult -Ok $true -Phase "loop-budget" -Reason "budget is within policy" | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-budget" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 4: Run budget scenarios**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: JSON output has `"ok": true` and includes both passing and failing budget checks.

- [ ] **Step 5: Commit budget validation**

Run:

```powershell
git add skills\loop-controller\scripts\validate-budget.ps1 skills\loop-controller\scripts\test-scenarios.ps1
git commit -m "Add loop controller budget validation"
```

Expected: commit succeeds.

## Task 4: Add Candidate Selector Contract

**Use Cases:**
- Loop Controller receives multiple ready and blocked candidates and selects the safest ready candidate deterministically.
- Skipped candidates are recorded with concrete reasons for user review.
- A candidate with missing source evidence is rejected before any workflow skill starts.
- The selector can run in local tests without GitHub network access or mutation.

**Files:**
- Create: `skills/loop-controller/scripts/select-candidate.ps1`
- Modify: `skills/loop-controller/scripts/test-scenarios.ps1`

- [ ] **Step 1: Extend scenarios with candidate inventory fixtures**

Add a candidate inventory fixture:

```powershell
$selectorScript = Join-Path $RepoRoot "skills\loop-controller\scripts\select-candidate.ps1"
$inventoryPath = Join-Path $tempRoot "candidate-inventory.json"
@{
    candidates = @(
        @{ id = "broad-audit"; source = "audit"; route = "audit-project"; ready = $true; risk = "medium"; source_path = "docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md"; reason = "broad follow-up" },
        @{ id = "approved-spec-plan"; source = "spec"; route = "write-plan"; ready = $true; risk = "low"; source_path = "docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md"; reason = "approved spec needs plan" },
        @{ id = "missing-source"; source = "issue"; route = "resolve-issue"; ready = $false; risk = "low"; source_path = "docs/superpowers/issues/missing.md"; reason = "source mirror missing" }
    )
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $inventoryPath -Encoding utf8NoBOM
$selection = Invoke-JsonScript -Path $selectorScript -Arguments @("-RepoRoot", $RepoRoot, "-InventoryPath", $inventoryPath)
Add-Check -Name "selector chooses low-risk ready candidate" -Ok ($selection.exit_code -eq 0 -and $selection.json.selected_candidate_id -eq "approved-spec-plan") -Reason $selection.raw
Add-Check -Name "selector records skipped candidates" -Ok ($selection.json.skipped.Count -ge 1) -Reason "skipped candidates missing"
```

- [ ] **Step 2: Run scenarios and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: command exits nonzero because `select-candidate.ps1` does not exist yet.

- [ ] **Step 3: Add the candidate selector**

Create `skills/loop-controller/scripts/select-candidate.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$InventoryPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

function Get-RiskScore {
    param([string]$Risk)
    switch ($Risk) {
        "low" { 0 }
        "medium" { 10 }
        "high" { 20 }
        default { 30 }
    }
}

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $inventory = Read-LoopControllerJson -Path (if ([IO.Path]::IsPathRooted($InventoryPath)) { $InventoryPath } else { Join-Path $repo $InventoryPath })
    Assert-LoopRequiredProperties -Object $inventory -Names @("candidates")
    $validRoutes = @("brainstorm-spec", "write-plan", "create-issues", "implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes", "audit-project", "align-project")
    $ready = [System.Collections.Generic.List[object]]::new()
    $skipped = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in @($inventory.candidates)) {
        try {
            Assert-LoopRequiredProperties -Object $candidate -Names @("id", "source", "route", "ready", "risk", "source_path", "reason")
            if ([string]$candidate.route -notin $validRoutes) { throw "invalid route" }
            $sourcePath = Join-Path $repo ([string]$candidate.source_path)
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "source path missing" }
            if ($candidate.ready -ne $true) { throw "candidate is not ready" }
            $ready.Add($candidate) | Out-Null
        } catch {
            $skipped.Add([pscustomobject]@{ id = [string]$candidate.id; reason = $_.Exception.Message }) | Out-Null
        }
    }
    if ($ready.Count -eq 0) { throw "no ready candidates" }
    $selected = @($ready | Sort-Object @{ Expression = { Get-RiskScore -Risk ([string]$_.risk) } }, @{ Expression = { [string]$_.id } } | Select-Object -First 1)[0]
    [pscustomobject]@{
        ok = $true
        phase = "candidate-selection"
        selected_candidate_id = [string]$selected.id
        selected_route = [string]$selected.route
        route_reason = [string]$selected.reason
        skipped = @($skipped)
    } | ConvertTo-Json -Depth 10
} catch {
    New-LoopControllerResult -Ok $false -Phase "candidate-selection" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 4: Run candidate selector scenarios**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: JSON output has `"ok": true`, selected candidate `approved-spec-plan`, and at least one skipped candidate reason.

- [ ] **Step 5: Commit candidate selection**

Run:

```powershell
git add skills\loop-controller\scripts\select-candidate.ps1 skills\loop-controller\scripts\test-scenarios.ps1
git commit -m "Add loop controller candidate selection"
```

Expected: commit succeeds.

## Task 5: Add Verifier Ledger And Terminal Closeout Validators

**Use Cases:**
- A high-risk loop route cannot reach final `Done` without verifier proof.
- A low-risk local fixture can use script-backed verification and still records that it is not independent human review.
- Terminal closeout rejects a dirty repo when the ledger says clean repo proof is required.
- Terminal closeout distinguishes paused `Stop` from verified final `Done`.

**Files:**
- Create: `skills/loop-controller/scripts/validate-verifier-ledger.ps1`
- Create: `skills/loop-controller/scripts/validate-terminal-closeout.ps1`
- Modify: `skills/loop-controller/scripts/test-scenarios.ps1`

- [ ] **Step 1: Extend scenarios with verifier and terminal fixtures**

Add verifier and terminal fixture calls:

```powershell
$verifierScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-verifier-ledger.ps1"
$terminalScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-terminal-closeout.ps1"
$verifierPath = Join-Path $tempRoot "verifier-ledger.json"
@{
    candidate_id = "approved-spec-plan"
    route = "write-plan"
    risk = "low"
    verifier_type = "script"
    independent = $false
    proof = @(
        @{ command = "pwsh -File scripts/validate-plan-task-use-cases.ps1"; ok = $true; artifact = "docs/superpowers/plans/fixture.md" }
    )
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $verifierPath -Encoding utf8NoBOM
$verifierOk = Invoke-JsonScript -Path $verifierScript -Arguments @("-RepoRoot", $RepoRoot, "-VerifierLedgerPath", $verifierPath)
Add-Check -Name "low-risk verifier proof passes" -Ok ($verifierOk.exit_code -eq 0 -and $verifierOk.json.ok -eq $true) -Reason $verifierOk.raw

$terminalPath = Join-Path $tempRoot "terminal-closeout.json"
@{
    run_ledger_valid = $true
    verifier_valid = $true
    metrics_valid = $true
    clean_repo_required = $false
    continuation_decision = @{
        question_id = "project_loop_final_health_gate"
        selected_option = "Done"
        terminal_state = "done"
    }
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $terminalPath -Encoding utf8NoBOM
$terminalOk = Invoke-JsonScript -Path $terminalScript -Arguments @("-RepoRoot", $RepoRoot, "-RunResultPath", $terminalPath)
Add-Check -Name "terminal done proof passes" -Ok ($terminalOk.exit_code -eq 0 -and $terminalOk.json.ok -eq $true) -Reason $terminalOk.raw
```

- [ ] **Step 2: Run scenarios and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: command exits nonzero because verifier and terminal validators do not exist yet.

- [ ] **Step 3: Add the verifier ledger validator**

Create `skills/loop-controller/scripts/validate-verifier-ledger.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$VerifierLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $ledger = Read-LoopControllerJson -Path (if ([IO.Path]::IsPathRooted($VerifierLedgerPath)) { $VerifierLedgerPath } else { Join-Path $repo $VerifierLedgerPath })
    Assert-LoopRequiredProperties -Object $ledger -Names @("candidate_id", "route", "risk", "verifier_type", "independent", "proof")
    if (@($ledger.proof).Count -eq 0) { throw "verifier proof is required" }
    if ([string]$ledger.risk -eq "high" -and $ledger.independent -ne $true) { throw "high-risk routes require independent verifier proof" }
    foreach ($proof in @($ledger.proof)) {
        Assert-LoopRequiredProperties -Object $proof -Names @("command", "ok", "artifact")
        if ($proof.ok -ne $true) { throw "verifier proof failed: $($proof.command)" }
    }
    New-LoopControllerResult -Ok $true -Phase "verifier-ledger" -Reason "verifier proof is valid" -Evidence @{ candidate_id = [string]$ledger.candidate_id; verifier_type = [string]$ledger.verifier_type } | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "verifier-ledger" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 4: Add the terminal closeout validator**

Create `skills/loop-controller/scripts/validate-terminal-closeout.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$RunResultPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $result = Read-LoopControllerJson -Path (if ([IO.Path]::IsPathRooted($RunResultPath)) { $RunResultPath } else { Join-Path $repo $RunResultPath })
    Assert-LoopRequiredProperties -Object $result -Names @("run_ledger_valid", "verifier_valid", "metrics_valid", "clean_repo_required", "continuation_decision")
    if ($result.run_ledger_valid -ne $true) { throw "run ledger proof is required" }
    if ($result.verifier_valid -ne $true) { throw "verifier proof is required" }
    if ($result.metrics_valid -ne $true) { throw "metrics proof is required" }
    Assert-LoopRequiredProperties -Object $result.continuation_decision -Names @("question_id", "selected_option", "terminal_state")
    if ([string]$result.continuation_decision.question_id -ne "project_loop_final_health_gate") { throw "final health gate question id is required" }
    if ([string]$result.continuation_decision.selected_option -notin @("Done", "Stop")) { throw "terminal option must be Done or Stop" }
    if ([string]$result.continuation_decision.selected_option -eq "Done" -and [string]$result.continuation_decision.terminal_state -ne "done") { throw "Done requires terminal_state done" }
    if ($result.clean_repo_required -eq $true) {
        $status = (& git -C $repo status --short 2>$null | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($status)) { throw "clean repo required but git status is not clean" }
    }
    New-LoopControllerResult -Ok $true -Phase "loop-terminal-closeout" -Reason "terminal closeout is valid" -Evidence @{ selected_option = [string]$result.continuation_decision.selected_option } | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-terminal-closeout" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 5: Run verifier and terminal scenarios**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: JSON output has `"ok": true` and includes passing verifier and terminal closeout checks.

- [ ] **Step 6: Commit verifier and terminal validation**

Run:

```powershell
git add skills\loop-controller\scripts\validate-verifier-ledger.ps1 skills\loop-controller\scripts\validate-terminal-closeout.ps1 skills\loop-controller\scripts\test-scenarios.ps1
git commit -m "Add loop controller verifier and terminal gates"
```

Expected: commit succeeds.

## Task 6: Add Metrics Report And End-To-End Fixture

**Use Cases:**
- Loop Controller records elapsed time, attempts, validations, retries, user-input count, mutation counts, final outcome, and accepted-change evidence.
- A local fixture proves the contracts can run in sequence without real GitHub mutation.
- Metrics avoid unsupported billing or token claims unless explicit runtime data is provided.
- Future automation templates can consume the same metrics JSON without parsing chat prose.

**Files:**
- Create: `skills/loop-controller/scripts/write-metrics-report.ps1`
- Modify: `skills/loop-controller/scripts/test-scenarios.ps1`

- [ ] **Step 1: Extend scenarios with metrics and a full local contract run**

Add a metrics fixture:

```powershell
$metricsScript = Join-Path $RepoRoot "skills\loop-controller\scripts\write-metrics-report.ps1"
$metricsInput = Join-Path $tempRoot "metrics-input.json"
$metricsOutput = Join-Path $tempRoot "metrics-output.json"
@{
    run_id = "fixture-run"
    started_at = "2026-06-15T00:00:00Z"
    completed_at = "2026-06-15T00:00:05Z"
    attempts_by_phase = @{ candidate_selection = 1; validation = 2; verification = 1 }
    validation_failures_by_phase = @{ validation = 1 }
    retry_count = 1
    human_input_count = 1
    github_mutation_count = 0
    created_pr_count = 0
    closed_issue_count = 0
    reverted_or_reopened_count = 0
    final_outcome = "done"
    accepted_change_evidence = @("skills/loop-controller/scripts/test-scenarios.ps1")
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metricsInput -Encoding utf8NoBOM
$metrics = Invoke-JsonScript -Path $metricsScript -Arguments @("-RepoRoot", $RepoRoot, "-MetricsInputPath", $metricsInput, "-OutputPath", $metricsOutput)
Add-Check -Name "metrics report writes json" -Ok ($metrics.exit_code -eq 0 -and $metrics.json.ok -eq $true -and (Test-Path -LiteralPath $metricsOutput)) -Reason $metrics.raw
```

- [ ] **Step 2: Run scenarios and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: command exits nonzero because `write-metrics-report.ps1` does not exist yet.

- [ ] **Step 3: Add metrics report generation**

Create `skills/loop-controller/scripts/write-metrics-report.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$MetricsInputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $metrics = Read-LoopControllerJson -Path (if ([IO.Path]::IsPathRooted($MetricsInputPath)) { $MetricsInputPath } else { Join-Path $repo $MetricsInputPath })
    Assert-LoopRequiredProperties -Object $metrics -Names @(
        "run_id", "started_at", "completed_at", "attempts_by_phase", "validation_failures_by_phase",
        "retry_count", "human_input_count", "github_mutation_count", "created_pr_count",
        "closed_issue_count", "reverted_or_reopened_count", "final_outcome", "accepted_change_evidence"
    )
    $started = [datetimeoffset]::Parse([string]$metrics.started_at)
    $completed = [datetimeoffset]::Parse([string]$metrics.completed_at)
    if ($completed -lt $started) { throw "completed_at must be after started_at" }
    $report = [pscustomobject]@{
        ok = $true
        phase = "loop-metrics"
        run_id = [string]$metrics.run_id
        elapsed_seconds = [int][Math]::Round(($completed - $started).TotalSeconds)
        attempts_by_phase = $metrics.attempts_by_phase
        validation_failures_by_phase = $metrics.validation_failures_by_phase
        retry_count = [int]$metrics.retry_count
        human_input_count = [int]$metrics.human_input_count
        github_mutation_count = [int]$metrics.github_mutation_count
        created_pr_count = [int]$metrics.created_pr_count
        closed_issue_count = [int]$metrics.closed_issue_count
        reverted_or_reopened_count = [int]$metrics.reverted_or_reopened_count
        final_outcome = [string]$metrics.final_outcome
        accepted_change_evidence = @($metrics.accepted_change_evidence)
    }
    $target = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) } else { [IO.Path]::GetFullPath((Join-Path $repo $OutputPath)) }
    $parent = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $target -Encoding utf8NoBOM
    $report | ConvertTo-Json -Depth 20
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-metrics" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 4: Run the full local fixture scenarios**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: JSON output has `"ok": true` and covers run ledger, budget, candidate selection, verifier proof, terminal closeout, and metrics.

- [ ] **Step 5: Commit metrics and e2e fixture**

Run:

```powershell
git add skills\loop-controller\scripts\write-metrics-report.ps1 skills\loop-controller\scripts\test-scenarios.ps1
git commit -m "Add loop controller metrics fixture"
```

Expected: commit succeeds.

## Task 7: Validate, Regenerate Outcome Workflow, Sync, And Close Out

**Use Cases:**
- Full repo validation proves the new skill does not break existing Superpowers Project contracts.
- Contract summary includes Loop Controller so future agents can discover its gates.
- Live sync validation proves the deployed copy can receive the new source skill.
- Cleanup proof shows the contracts-first implementation leaves no repo-owned background processes.

**Files:**
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`
- Modify: no other source files expected unless validation reports a specific broken contract.

- [ ] **Step 1: Validate this saved plan's Task # Use Cases**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md
```

Expected: JSON output has `"ok": true` and `task_count` is `7`.

- [ ] **Step 2: Run focused Loop Controller proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
```

Expected: both commands exit `0` and emit JSON with `"ok": true`.

- [ ] **Step 3: Regenerate and validate the outcome workflow**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-contract-summary.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
```

Expected: `docs/superpowers/OUTCOME_WORKFLOW.md` lists `loop-controller`, `project_loop_next_step`, and `project_loop_final_health_gate`; the outcome workflow test exits `0`.

- [ ] **Step 4: Run full source validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: final JSON output has `"ok": true`.

- [ ] **Step 5: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: command exits `0` and reports source/live validation success. Do not claim live plugin readiness without this proof.

- [ ] **Step 6: Run cleanup proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: output reports no matching leftover Codex processes under this repo.

- [ ] **Step 7: Commit validation closeout changes**

Run:

```powershell
git add docs\superpowers\OUTCOME_WORKFLOW.md
git commit -m "Update outcome workflow for loop controller"
```

Expected: commit succeeds if the generated outcome workflow changed. If no source file changed during closeout, record the validation receipts in the handoff instead of creating an empty commit.

## Risk And Dependency Notes

- The new skill adds orchestration vocabulary, but it must not replace existing workflow ownership.
- The default run state is generated local state under `.superpowers/runs`; tests must clean generated fixture runs.
- Terminal closeout validation that checks git cleanliness should allow fixture paths to set `clean_repo_required = false`; real run closeout should require clean repo proof when code or docs changed.
- The first slice intentionally defers real scheduled automations. Automation templates can be planned after the contract validators prove stable.
- High-risk route verification requires independent proof. Low-risk script-backed proof must record that it is non-independent.

## Execution Notes

- Use `superpowers:test-driven-development` for every code or script task.
- Use `superpowers:verification-before-completion` before reporting the feature complete.
- Use `superpowers:finishing-a-development-branch` before integration.
- Use `$superpowers-project:merge-changes` for local-branch merge closeout after implementation, validation, and native merge approval.
- Do not sync live until source validation passes.

## Plan Self-Review

- Spec coverage: Tasks 1 through 7 cover the selected contracts-first slice from the source spec: skill shell, run ledger, budget, candidate selection, verifier proof, terminal closeout, metrics, validation, and source/live proof.
- Acceptance coverage: every acceptance criterion maps to at least one numbered task.
- Placeholder scan: no placeholder markers remain.
- Task # Use Cases: every numbered task includes a non-empty `**Use Cases:**` block before files and steps.
- TDD policy: script and skill implementation tasks require `superpowers:test-driven-development`.
- Debug policy: no bug or regression repair is planned, so `superpowers:systematic-debugging` is not required for the first implementation unless a failing validator needs diagnosis during execution.
- Completion policy: final implementation completion requires `superpowers:verification-before-completion`, full validation, live-sync validation, and cleanup proof.

