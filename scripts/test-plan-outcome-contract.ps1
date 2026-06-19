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
    $scriptPath = Join-Path $RepoRoot "scripts\validate-plan-outcome-contract.ps1"
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return [pscustomobject]@{
            exit_code = 127
            json = [pscustomobject]@{ ok = $false; reason = "missing plan outcome contract validator: $scriptPath" }
            raw = "missing plan outcome contract validator: $scriptPath"
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

function New-PlanText {
    param(
        [string]$OutcomeContract,
        [string]$ArchitectureSlice,
        [string]$TaskUseCase = "Contract fixture passes with target-perspective acceptance evidence and cutover coverage."
    )
@"
# Fixture Implementation Plan

$OutcomeContract

$ArchitectureSlice

### Task 1: Add Validator

**Use Cases:**
- $TaskUseCase

**Files:**
- Create: ``scripts/lib/outcome-contract.ps1``

- [ ] **Step 1: Add helper**
"@
}

try {
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("plan-outcome-contract-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $fixtureRepo = Join-Path $tempDir "repo"
    New-Item -ItemType Directory -Path (Join-Path $fixtureRepo "docs\superpowers\plans") -Force | Out-Null

    $validOutcome = @'
## Outcome Contract

**Intent:** Make contract adoption enforceable.
**Current Behavior:** Plans require use cases but do not require contract ownership.
**Expected Outcome:** Plans carry ownership, cutover, and evidence gates.
**Target-Perspective Output:** Maintainer sees a validator pass only when contract fields are present.
**Truth Owner:** `scripts/lib/outcome-contract.ps1`
**Contract Interface:** Markdown fields consumed by validator scripts.
**Cutover Decision:** Extend the existing plan readiness path.
**Displaced Path:** Plan readiness based only on Task # Use Cases.
**Evidence Lane:** CLI validator output.
**Acceptance Evidence:** `validate-plan-outcome-contract.ps1` returns `ok: true`.
**Kill Criteria:** Reject plans that omit required ownership or proof fields.
**Forbidden Moves:** Do not create a separate `docs/goals` route.
**Risk If Wrong:** Agents can ship plausible work with weak ownership proof.
'@

    $validArchitecture = @'
## Architecture Slice

**Files To Create:** `scripts/lib/outcome-contract.ps1`
**Files To Modify:** `scripts/validate.ps1`
**Files To Avoid:** `skills/krypton-*`
**Source Of Truth:** plan outcome contract section
**Read Path:** plan markdown -> validator helper
**Write Path:** `$superpowers-project:write-plan` writes the section
**Integration Points:** plan validation and issue validation
**Migration Or Cutover:** old plan readiness is extended, not replaced
**Displaced Path Handling:** Task-only readiness no longer stands alone
**Acceptance Evidence Gate:** focused validator test passes
'@

    $validPlan = "docs/superpowers/plans/valid-contract-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $validPlan) -Encoding utf8NoBOM -Value (New-PlanText -OutcomeContract $validOutcome -ArchitectureSlice $validArchitecture)
    $valid = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $validPlan
    Add-Check -Name "valid outcome contract passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason ([string]$valid.json.reason)

    $missingSection = "docs/superpowers/plans/missing-outcome-contract-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $missingSection) -Encoding utf8NoBOM -Value (New-PlanText -OutcomeContract "" -ArchitectureSlice $validArchitecture)
    $missingSectionResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $missingSection
    Add-Check -Name "missing outcome contract section fails" -Ok ($missingSectionResult.exit_code -ne 0 -and [string]$missingSectionResult.json.reason -match "Outcome Contract") -Reason "missing outcome contract section should fail"

    $missingField = "docs/superpowers/plans/missing-truth-owner-plan.md"
    $missingTruthOwner = $validOutcome -replace "\*\*Truth Owner:\*\*.+\r?\n", ""
    Set-Content -LiteralPath (Join-Path $fixtureRepo $missingField) -Encoding utf8NoBOM -Value (New-PlanText -OutcomeContract $missingTruthOwner -ArchitectureSlice $validArchitecture)
    $missingFieldResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $missingField
    Add-Check -Name "missing required field fails" -Ok ($missingFieldResult.exit_code -ne 0 -and [string]$missingFieldResult.json.reason -match "Truth Owner") -Reason "missing Truth Owner should fail"

    $weakEvidence = "docs/superpowers/plans/weak-evidence-plan.md"
    $weakOutcome = $validOutcome -replace "\*\*Acceptance Evidence:\*\*.+", "**Acceptance Evidence:** Tests pass"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $weakEvidence) -Encoding utf8NoBOM -Value (New-PlanText -OutcomeContract $weakOutcome -ArchitectureSlice $validArchitecture)
    $weakEvidenceResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $weakEvidence
    Add-Check -Name "weak acceptance evidence fails" -Ok ($weakEvidenceResult.exit_code -ne 0 -and [string]$weakEvidenceResult.json.reason -match "Acceptance Evidence") -Reason "weak acceptance evidence should fail"

    $cutoverDebt = "docs/superpowers/plans/cutover-debt-plan.md"
    $cutoverOutcome = $validOutcome -replace "\*\*Kill Criteria:\*\*.+\r?\n", ""
    Set-Content -LiteralPath (Join-Path $fixtureRepo $cutoverDebt) -Encoding utf8NoBOM -Value (New-PlanText -OutcomeContract $cutoverOutcome -ArchitectureSlice $validArchitecture -TaskUseCase "Contract fixture covers target-perspective acceptance evidence only.")
    $cutoverResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $cutoverDebt
    Add-Check -Name "cutover debt without kill criteria fails" -Ok ($cutoverResult.exit_code -ne 0 -and [string]$cutoverResult.json.reason -match "Kill Criteria") -Reason "missing kill criteria should fail"

    $missingTaskCoverage = "docs/superpowers/plans/missing-task-coverage-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $missingTaskCoverage) -Encoding utf8NoBOM -Value (New-PlanText -OutcomeContract $validOutcome -ArchitectureSlice $validArchitecture -TaskUseCase "Contract fixture covers setup only.")
    $missingCoverageResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -PlanPath $missingTaskCoverage
    Add-Check -Name "task use cases must cover evidence and cutover" -Ok ($missingCoverageResult.exit_code -ne 0 -and [string]$missingCoverageResult.json.reason -match "Task # Use Cases") -Reason "task use cases should cover evidence and cutover"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "plan-outcome-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "plan-outcome-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
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
