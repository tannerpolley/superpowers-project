[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } })
}

function Invoke-Validator {
    param([string]$ValidatorRepoRoot, [string]$PlanPath)
    $scriptPath = Join-Path $RepoRoot "scripts\validate-plan-task-use-cases.ps1"
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return [pscustomobject]@{
            exit_code = 127
            json = [pscustomobject]@{ ok = $false; reason = "missing plan task use-case validator: $scriptPath" }
            raw = "missing plan task use-case validator: $scriptPath"
        }
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RepoRoot $ValidatorRepoRoot -PlanPath $PlanPath 2>&1
    $text = ($raw | Out-String).Trim()
    try {
        [pscustomobject]@{ exit_code = $LASTEXITCODE; json = ($text | ConvertFrom-Json); raw = $text }
    } catch {
        [pscustomobject]@{ exit_code = $LASTEXITCODE; json = [pscustomobject]@{ ok = $false; reason = $text }; raw = $text }
    }
}

try {
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("plan-task-use-cases-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $fixtureRepo = Join-Path $tempDir "repo"
    New-Item -ItemType Directory -Path (Join-Path $fixtureRepo "docs\superpowers\plans") -Force | Out-Null

    $validPlan = "docs/superpowers/plans/valid-plan.md"
    $validPath = Join-Path $fixtureRepo $validPlan
    Set-Content -LiteralPath $validPath -Encoding utf8NoBOM -Value @'
# Valid Implementation Plan

## Task 1: Add The Validator

**Use Cases:**
- User asks for a strict plan implementation contract and the saved plan must prove each task has concrete behavioral coverage.

**Files:**
- Create: `scripts/validate-plan-task-use-cases.ps1`

- [ ] **Step 1: Write the failing test**
'@
    $valid = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $validPlan
    Add-Check -Name "valid numbered task use cases pass" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true -and $valid.json.task_count -eq 1) -Reason ([string]$valid.json.reason)

    $missingPlan = "docs/superpowers/plans/missing-use-cases-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $missingPlan) -Encoding utf8NoBOM -Value @'
# Missing Use Cases Plan

## Task 1: Implement Without Use Cases

**Files:**
- Modify: `src/app.ts`

- [ ] **Step 1: Make the change**
'@
    $missing = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $missingPlan
    Add-Check -Name "numbered task without use cases fails" -Ok ($missing.exit_code -ne 0 -and $missing.json.ok -eq $false -and [string]$missing.json.reason -match "Task 1") -Reason "missing use cases should fail"

    $emptyPlan = "docs/superpowers/plans/empty-use-cases-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $emptyPlan) -Encoding utf8NoBOM -Value @'
# Empty Use Cases Plan

## Task 1: Empty Use Cases

**Use Cases:**

**Files:**
- Modify: `src/app.ts`
'@
    $empty = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $emptyPlan
    Add-Check -Name "empty use cases fail" -Ok ($empty.exit_code -ne 0 -and $empty.json.ok -eq $false -and [string]$empty.json.reason -match "Task 1") -Reason "empty use cases should fail"

    $latePlan = "docs/superpowers/plans/late-use-cases-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $latePlan) -Encoding utf8NoBOM -Value @'
# Late Use Cases Plan

## Task 1: Put Use Cases After Files

**Files:**
- Modify: `src/app.ts`

**Use Cases:**
- This comes too late because implementation scope has already started with file inventory.
'@
    $late = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $latePlan
    Add-Check -Name "use cases after files fail" -Ok ($late.exit_code -ne 0 -and $late.json.ok -eq $false -and [string]$late.json.reason -match "after files or steps") -Reason "late use cases should fail"

    foreach ($relative in @(
        "skills\write-plan\SKILL.md",
        "skills\write-plan\agents\openai.yaml",
        "skills\implement-plan\SKILL.md",
        "skills\implement-plan\agents\openai.yaml",
        "skills\resolve-issue\SKILL.md",
        "skills\resolve-issue\agents\openai.yaml"
    )) {
        $text = Get-Content -LiteralPath (Join-Path $RepoRoot $relative) -Raw
        foreach ($needle in @("Task # Use Cases", "validate-plan-task-use-cases.ps1", "strict requirement")) {
            Add-Check -Name "$relative contains $needle" -Ok $text.Contains($needle) -Reason "$relative missing $needle"
        }
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "plan-task-use-cases"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "plan-task-use-cases"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        $resolvedTempDir = [IO.Path]::GetFullPath($tempDir)
        $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTempDir.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempDir -Recurse -Force
        }
    }
}
