[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repoRoot "scripts\lib\github-checks.ps1"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Add-Result -Name $Name -Ok $true -Reason "passed"
    } catch {
        Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message
    }
}

Invoke-Scenario "shared helper exists" {
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
        throw "missing scripts/lib/github-checks.ps1"
    }
}

Invoke-Scenario "project merge premerge uses shared helper" {
    $premergePath = Join-Path $repoRoot "skills\merge-changes\scripts\premerge.ps1"
    $contractPath = Join-Path $repoRoot "skills\merge-changes\scripts\lib\contract.ps1"
    $premerge = Get-Content -LiteralPath $premergePath -Raw
    $contract = Get-Content -LiteralPath $contractPath -Raw
    if (-not ($premerge.Contains("Test-GitHubRequiredChecks") -or $contract.Contains("Test-GitHubRequiredChecks"))) {
        throw "premerge must use shared GitHub check helper"
    }
    if ($premerge.Contains("SUCCESS|PASS|COMPLETED") -or $contract.Contains("SUCCESS|PASS|COMPLETED")) {
        throw "premerge must not use loose success regex matching"
    }
}

if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
    . $helperPath
}

Invoke-Scenario "successful required check passes" {
    $checks = @(@{ name = "unit"; status = "COMPLETED"; conclusion = "SUCCESS" })
    $result = Test-GitHubRequiredChecks -Checks $checks -Policy "require-existing" -RequiredCheckNames @("unit")
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "failed required check blocks" {
    $checks = @(@{ name = "unit"; status = "COMPLETED"; conclusion = "FAILURE" })
    $result = Test-GitHubRequiredChecks -Checks $checks -Policy "require-existing" -RequiredCheckNames @("unit")
    if ($result.ok -or $result.reason -notmatch "unit") { throw "expected failed required check to block" }
}

Invoke-Scenario "pending required check blocks" {
    $checks = @(@{ name = "unit"; status = "IN_PROGRESS"; conclusion = "" })
    $result = Test-GitHubRequiredChecks -Checks $checks -Policy "require-existing" -RequiredCheckNames @("unit")
    if ($result.ok -or $result.reason -notmatch "pending") { throw "expected pending required check to block" }
}

Invoke-Scenario "missing required check blocks when policy requires existing" {
    $result = Test-GitHubRequiredChecks -Checks @() -Policy "require-existing" -RequiredCheckNames @("unit")
    if ($result.ok -or $result.reason -notmatch "missing") { throw "expected missing required check to block" }
}

Invoke-Scenario "skipped optional check passes only when explicitly optional" {
    $checks = @(@{ name = "docs"; status = "COMPLETED"; conclusion = "SKIPPED" })
    $optional = Test-GitHubRequiredChecks -Checks $checks -Policy "require-existing" -OptionalCheckNames @("docs")
    if (-not $optional.ok) { throw $optional.reason }
    $required = Test-GitHubRequiredChecks -Checks $checks -Policy "require-existing" -RequiredCheckNames @("docs")
    if ($required.ok -or $required.reason -notmatch "skipped") { throw "expected skipped required check to block" }
}

Invoke-Scenario "cancelled and timed-out required checks block" {
    foreach ($state in @("CANCELLED", "TIMED_OUT")) {
        $checks = @(@{ name = "unit"; status = "COMPLETED"; conclusion = $state })
        $result = Test-GitHubRequiredChecks -Checks $checks -Policy "require-existing" -RequiredCheckNames @("unit")
        if ($result.ok -or $result.reason -notmatch "unit") { throw "expected $state required check to block" }
    }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }

