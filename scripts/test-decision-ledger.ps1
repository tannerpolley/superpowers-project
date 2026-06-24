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
    param([string]$ValidatorRepoRoot, [string]$ArtifactPath, [string]$Kind)
    $scriptPath = Join-Path $RepoRoot "scripts\validate-decision-ledger.ps1"
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return [pscustomobject]@{
            exit_code = 127
            json = [pscustomobject]@{ ok = $false; reason = "missing decision-ledger validator: $scriptPath" }
            raw = "missing decision-ledger validator: $scriptPath"
        }
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RepoRoot $ValidatorRepoRoot -Path $ArtifactPath -Kind $Kind 2>&1
    $text = ($raw | Out-String).Trim()
    try {
        [pscustomobject]@{ exit_code = $LASTEXITCODE; json = ($text | ConvertFrom-Json); raw = $text }
    } catch {
        [pscustomobject]@{ exit_code = $LASTEXITCODE; json = [pscustomobject]@{ ok = $false; reason = $text }; raw = $text }
    }
}

function New-FixtureText {
    param([string]$Ledger)
@"
# Fixture Artifact

## Outcome Proof

**Intent:** Prove decision ledger parsing.

$Ledger

## Next Section

Regular body.
"@
}

try {
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("decision-ledger-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $fixtureRepo = Join-Path $tempDir "repo"
    New-Item -ItemType Directory -Path (Join-Path $fixtureRepo "docs\superpowers\specs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $fixtureRepo "docs\superpowers\plans") -Force | Out-Null

    $validLedger = @'
## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
| --- | --- | --- | --- | --- | --- |
| Scope | user grill | Limit work to Task 4. | Keeps the issue branch focused on Decision Ledger contracts. | No | Maintainer |
| Schema owner | repo evidence | Root validator owns Markdown table checks. | Downstream planning and issue execution read one contract. | Yes | Superpowers maintainer |
'@

    $validSpec = "docs/superpowers/specs/valid-decision-ledger-spec.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $validSpec) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger $validLedger)
    $validSpecResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $validSpec -Kind "spec"
    Add-Check -Name "valid spec decision ledger passes" -Ok ($validSpecResult.exit_code -eq 0 -and $validSpecResult.json.ok -eq $true -and $validSpecResult.json.row_count -eq 2) -Reason ([string]$validSpecResult.json.reason)

    $validPlan = "docs/superpowers/plans/valid-decision-ledger-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $validPlan) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger $validLedger)
    $validPlanResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $validPlan -Kind "plan"
    Add-Check -Name "valid plan decision ledger passes" -Ok ($validPlanResult.exit_code -eq 0 -and $validPlanResult.json.ok -eq $true -and $validPlanResult.json.kind -eq "plan") -Reason ([string]$validPlanResult.json.reason)

    $missingLedger = "docs/superpowers/plans/missing-decision-ledger-plan.md"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $missingLedger) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger "")
    $missingLedgerResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $missingLedger -Kind "plan"
    Add-Check -Name "missing decision ledger fails" -Ok ($missingLedgerResult.exit_code -ne 0 -and [string]$missingLedgerResult.json.reason -match "Decision Ledger") -Reason "missing Decision Ledger should fail"

    $missingColumn = "docs/superpowers/plans/missing-column-plan.md"
    $missingColumnLedger = @'
## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? |
| --- | --- | --- | --- | --- |
| Scope | user grill | Limit work to Task 4. | Keeps branch focused. | No |
'@
    Set-Content -LiteralPath (Join-Path $fixtureRepo $missingColumn) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger $missingColumnLedger)
    $missingColumnResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $missingColumn -Kind "plan"
    Add-Check -Name "missing required column fails" -Ok ($missingColumnResult.exit_code -ne 0 -and [string]$missingColumnResult.json.reason -match "Risk owner") -Reason "missing Risk owner column should fail"

    $emptyAnswer = "docs/superpowers/plans/empty-answer-plan.md"
    $emptyAnswerLedger = $validLedger -replace "Limit work to Task 4\.", ""
    Set-Content -LiteralPath (Join-Path $fixtureRepo $emptyAnswer) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger $emptyAnswerLedger)
    $emptyAnswerResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $emptyAnswer -Kind "plan"
    Add-Check -Name "empty required answer fails" -Ok ($emptyAnswerResult.exit_code -ne 0 -and [string]$emptyAnswerResult.json.reason -match "Answer") -Reason "empty Answer should fail"

    $deferredNoOwner = "docs/superpowers/plans/deferred-no-owner-plan.md"
    $deferredNoOwnerLedger = $validLedger -replace "Superpowers maintainer", "TBD"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $deferredNoOwner) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger $deferredNoOwnerLedger)
    $deferredNoOwnerResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $deferredNoOwner -Kind "plan"
    Add-Check -Name "deferred decision without concrete risk owner fails" -Ok ($deferredNoOwnerResult.exit_code -ne 0 -and [string]$deferredNoOwnerResult.json.reason -match "risk owner") -Reason "deferred decision without concrete risk owner should fail"

    $deferredNoImpact = "docs/superpowers/plans/deferred-no-impact-plan.md"
    $deferredNoImpactLedger = $validLedger -replace "Downstream planning and issue execution read one contract\.", "TBD"
    Set-Content -LiteralPath (Join-Path $fixtureRepo $deferredNoImpact) -Encoding utf8NoBOM -Value (New-FixtureText -Ledger $deferredNoImpactLedger)
    $deferredNoImpactResult = Invoke-Validator -ValidatorRepoRoot $fixtureRepo -ArtifactPath $deferredNoImpact -Kind "plan"
    Add-Check -Name "deferred decision without downstream impact fails" -Ok ($deferredNoImpactResult.exit_code -ne 0 -and [string]$deferredNoImpactResult.json.reason -match "downstream impact") -Reason "deferred decision without downstream impact should fail"

    foreach ($relative in @("skills\brainstorm-spec\SKILL.md", "skills\write-plan\SKILL.md")) {
        $text = Get-Content -LiteralPath (Join-Path $RepoRoot $relative) -Raw
        foreach ($needle in @("## Decision Ledger", "Decision", "Source", "Answer", "Impact", "Deferred?", "Risk owner", "validate-decision-ledger.ps1")) {
            Add-Check -Name "$relative contains $needle" -Ok $text.Contains($needle) -Reason "$relative missing $needle"
        }
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "decision-ledger"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "decision-ledger"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
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
