[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

function New-FixtureRepo {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("skill-metadata-contract-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root "skills\write-plan\agents") -Force | Out-Null
    @"
version: 1
workflow_skills:
  write-plan:
    purpose: Turn approved specs or issue mirrors into detailed implementation plans.
    question_ids:
      - project_plan_issue_execution_route
    final_health_gate:
    top_level_options: [Yes, Revisit, Stop]
    nested_routes:
      - question_id: project_plan_issue_execution_route
        parent_option: Yes
        options: [Resolve Issue, Orchestrate Issues]
    validators: [scripts/validate-plan-outcome-proof.ps1]
    artifacts: [docs/superpowers/plans]
    next_routes: [resolve-issue, orchestrate-issues]
"@ | Set-Content -LiteralPath (Join-Path $root "docs\superpowers\workflow-contract.yml") -Encoding utf8NoBOM
    @"
---
name: write-plan
description: Test fixture.
---

# Write Plan

Question id: ``project_plan_issue_execution_route``
"@ | Set-Content -LiteralPath (Join-Path $root "skills\write-plan\SKILL.md") -Encoding utf8NoBOM
    $root
}

function Set-FixtureMetadata {
    param([string]$Root, [string]$Prompt)
    $indentedPrompt = ($Prompt -split "`r?`n" | ForEach-Object { "    $_" }) -join "`n"
    @"
interface:
  display_name: "Write Plan"
  short_description: "Fixture metadata."
  default_prompt: >-
$indentedPrompt
"@ | Set-Content -LiteralPath (Join-Path $Root "skills\write-plan\agents\openai.yaml") -Encoding utf8NoBOM
}

function Invoke-Validator {
    param([string]$Root)
    $validator = Join-Path $RepoRoot "scripts\validate-skill-metadata-contract.ps1"
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $Root 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = ($output | Out-String).Trim()
    }
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Add-Check -Name $Name -Ok $true -Reason "passed"
    } catch {
        Add-Check -Name $Name -Ok $false -Reason $_.Exception.Message
    }
}

Invoke-Scenario "metadata route contradiction fails" {
    $fixture = New-FixtureRepo
    try {
        Set-FixtureMetadata -Root $fixture -Prompt "Use write-plan. Read SKILL.md and docs/superpowers/workflow-contract.yml. Ask project_plan_issue_execution_route with Resolve Issue, Orchestrate Issues, and Stop."
        $result = Invoke-Validator -Root $fixture
        if ($result.exit_code -eq 0) { throw "validator accepted metadata that advertises Stop in project_plan_issue_execution_route" }
        if ($result.output -notmatch "project_plan_issue_execution_route" -or $result.output -notmatch "Stop") {
            throw "failure did not name the contradictory route and option: $($result.output)"
        }
    } finally {
        if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
}

Invoke-Scenario "duplicated global policy fails" {
    $fixture = New-FixtureRepo
    try {
        Set-FixtureMetadata -Root $fixture -Prompt "Use write-plan. Read SKILL.md and docs/superpowers/workflow-contract.yml. Strict artifact display is mandatory before every closeout or permission question. Ask project_plan_issue_execution_route with Resolve Issue and Orchestrate Issues."
        $result = Invoke-Validator -Root $fixture
        if ($result.exit_code -eq 0) { throw "validator accepted duplicated global policy in metadata" }
        if ($result.output -notmatch "duplicated global policy") {
            throw "failure did not name duplicated global policy: $($result.output)"
        }
    } finally {
        if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
}

Invoke-Scenario "compact fixture passes" {
    $fixture = New-FixtureRepo
    try {
        Set-FixtureMetadata -Root $fixture -Prompt "Use write-plan for implementation planning from approved Superpowers Project specs or issue mirrors. Read SKILL.md for exact gates and docs/superpowers/workflow-contract.yml for route question ids and child options. Preserve request_user_input gates; project_plan_issue_execution_route has Resolve Issue and Orchestrate Issues only."
        $result = Invoke-Validator -Root $fixture
        if ($result.exit_code -ne 0) { throw "compact metadata was rejected: $($result.output)" }
    } finally {
        if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
}

Invoke-Scenario "current repo metadata contract passes" {
    $result = Invoke-Validator -Root $RepoRoot
    if ($result.exit_code -ne 0) { throw $result.output }
}

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "skill-metadata-contract"
    checks = $checks
} | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
