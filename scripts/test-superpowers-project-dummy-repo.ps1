[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$phase = "dummy-repo"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("superpowers-project-dummy-" + [guid]::NewGuid().ToString("N"))
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Complete {
    param([bool]$Ok, [string]$Reason)
    [pscustomobject]@{ ok = $Ok; phase = $phase; reason = $Reason; checks = $checks } | ConvertTo-Json -Depth 8
    if ($Ok) { exit 0 }
    exit 1
}

function Invoke-JsonScript {
    param([string]$ScriptPath, [string[]]$Arguments)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $raw = ($output | Out-String).Trim()
    try {
        if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty output" }
        return ($raw | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{ ok = $false; phase = [IO.Path]::GetFileNameWithoutExtension($ScriptPath); reason = $raw }
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    & git -C $tempRoot init -b main | Out-Null
    & git -C $tempRoot config user.email tests@example.invalid | Out-Null
    & git -C $tempRoot config user.name "Superpowers Project Dummy" | Out-Null
    & git -C $tempRoot config core.autocrlf false | Out-Null
    & git -C $tempRoot remote add origin https://github.com/example/superpowers-project-dummy.git | Out-Null

    Set-Content -LiteralPath (Join-Path $tempRoot "AGENTS.md") -Value "# Dummy Repo`n`n## Agent skills`n" -Encoding utf8NoBOM
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "docs\superpowers\milestones") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "docs\superpowers\specs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "docs\superpowers\plans") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "docs\superpowers\issues") -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $tempRoot "docs\superpowers\PROJECT_CONTEXT.md") -Value @"
# Superpowers Project Context

## Durable Intent

Dummy repo proves Superpowers Project artifacts.

## Artifact Model

- Specs: docs/superpowers/specs
- Plans: docs/superpowers/plans
- Issue mirrors: docs/superpowers/issues
- Milestone pages: docs/superpowers/milestones
"@ -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $tempRoot "docs\superpowers\milestones\README.md") -Value "# Milestones`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $tempRoot "docs\superpowers\specs\2026-06-02-dummy-design.md") -Value "# Dummy Design`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $tempRoot "docs\superpowers\plans\2026-06-02-dummy-plan.md") -Value "# Dummy Implementation Plan`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $tempRoot "docs\superpowers\issues\12-dummy.md") -Value @"
# Dummy Issue

**GitHub Issue:** https://github.com/example/superpowers-project-dummy/issues/12
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-02-dummy-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-dummy-plan.md
**Classification:** AFK
**Goal Command:** /goal Resolve dummy issue
**Branch:** codex/dummy
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Acceptance Criteria

- [ ] Dummy issue is resolved through native goal setup

## Proof Oracle

- pwsh -NoProfile -Command 'exit 0'
"@ -Encoding utf8NoBOM

    & git -C $tempRoot add . | Out-Null
    & git -C $tempRoot commit -m "seed dummy superpowers project" | Out-Null
    Add-Check -Name "dummy repo seeded" -Ok $true -Reason "passed"

    $mirrorValidator = Join-Path $repoRoot "skills\create-issues\scripts\validate-issue-mirror.ps1"
    $mirrorResult = Invoke-JsonScript -ScriptPath $mirrorValidator -Arguments @("-RepoRoot", $tempRoot, "-IssueFile", "docs/superpowers/issues/12-dummy.md", "-MilestoneRequired")
    if (-not $mirrorResult.ok) { throw "issue mirror validation failed: $($mirrorResult.reason)" }
    Add-Check -Name "issue mirror validator" -Ok $true -Reason "passed"

    $prepareScript = Join-Path $repoRoot "skills\resolve-issue\scripts\prepare-execution.ps1"
    $inspect = Invoke-JsonScript -ScriptPath $prepareScript -Arguments @("-Mode", "Inspect", "-RepoRoot", $tempRoot, "-IssueMirror", "docs/superpowers/issues/12-dummy.md")
    if (-not $inspect.ok) { throw "resolve inspect failed: $($inspect.reason)" }
    Add-Check -Name "resolve inspect" -Ok $true -Reason "passed"

    $inlineDecision = @{
        question_id = "resolve_execution_topology"
        source = "debug_question_mode"
        selected_mode = "inline"
        recommended_mode = "inline"
        options = @("orchestrated-worker", "inline")
    } | ConvertTo-Json -Depth 8 -Compress

    $workerDecision = @{
        question_id = "resolve_execution_topology"
        source = "debug_question_mode"
        selected_mode = "orchestrated-worker"
        recommended_mode = "orchestrated-worker"
        options = @("orchestrated-worker", "inline")
    } | ConvertTo-Json -Depth 8 -Compress

    $missingGoal = Invoke-JsonScript -ScriptPath $prepareScript -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $tempRoot, "-HandoffJson", ($inspect.evidence.handoff_json), "-ExecutionDecisionJson", $inlineDecision)
    if ($missingGoal.ok -or $missingGoal.reason -notmatch "goal proof|GoalProof") { throw "missing native goal proof did not block" }
    Add-Check -Name "missing native goal proof blocks" -Ok $true -Reason "passed"

    $goalProof = @{
        source = "get_goal"
        active = $true
        goal_id = "dummy-thread-goal"
        objective = [string]$inspect.evidence.handoff.goal_objective
    } | ConvertTo-Json -Depth 8 -Compress
    $finalize = Invoke-JsonScript -ScriptPath $prepareScript -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $tempRoot, "-HandoffJson", ($inspect.evidence.handoff_json), "-GoalProofJson", $goalProof, "-ExecutionDecisionJson", $inlineDecision)
    if (-not $finalize.ok) { throw "structured native goal proof failed: $($finalize.reason)" }
    Add-Check -Name "structured native goal proof passes" -Ok $true -Reason "passed"

    $workerFinalize = Invoke-JsonScript -ScriptPath $prepareScript -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $tempRoot, "-HandoffJson", ($inspect.evidence.handoff_json), "-GoalProofJson", $goalProof, "-ExecutionDecisionJson", $workerDecision)
    if ($workerFinalize.ok -or $workerFinalize.reason -notmatch "orchestrate-issues") { throw "worker mode should route away from resolve-issue" }
    Add-Check -Name "resolve rejects worker mode" -Ok $true -Reason "passed"

    $orchestratePrepare = Join-Path $repoRoot "skills\orchestrate-issues\scripts\prepare-worker-handoff.ps1"
    $orchestrateValidate = Join-Path $repoRoot "skills\orchestrate-issues\scripts\validate-worker-handoff.ps1"
    $workerHandoff = Invoke-JsonScript -ScriptPath $orchestratePrepare -Arguments @("-RepoRoot", $tempRoot, "-IssueFile", "docs/superpowers/issues/12-dummy.md", "-OutputPath", "handoff/worker-handoff.json")
    if (-not $workerHandoff.ok) { throw "worker handoff preparation failed: $($workerHandoff.reason)" }
    $workerValidation = Invoke-JsonScript -ScriptPath $orchestrateValidate -Arguments @("-RepoRoot", $tempRoot, "-HandoffPath", "handoff/worker-handoff.json")
    if (-not $workerValidation.ok) { throw "worker handoff validation failed: $($workerValidation.reason)" }
    Add-Check -Name "orchestrate-issues worker handoff" -Ok $true -Reason "passed"

    $setupValidator = Join-Path $repoRoot "skills\resolve-issue\scripts\validate-setup.ps1"
    $setupResult = Invoke-JsonScript -ScriptPath $setupValidator -Arguments @("-RepoRoot", $tempRoot, "-SetupLedgerJson", ($finalize.setup_ledger_json))
    if (-not $setupResult.ok) { throw "setup validation failed: $($setupResult.reason)" }
    Add-Check -Name "setup validator" -Ok $true -Reason "passed"

    if (Test-Path -LiteralPath (Join-Path $tempRoot "docs\goals")) { throw "docs/goals should not be created" }
    if (Test-Path -LiteralPath (Join-Path $tempRoot ".goalbuddy-board")) { throw ".goalbuddy-board should not be created" }
    Add-Check -Name "no GoalBuddy board files" -Ok $true -Reason "passed"

    Complete -Ok $true -Reason "passed"
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    Complete -Ok $false -Reason $_.Exception.Message
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolved = [IO.Path]::GetFullPath($tempRoot)
        $base = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

