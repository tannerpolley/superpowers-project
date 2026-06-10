[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$skillPath = Join-Path $skillRoot "SKILL.md"
$agentPath = Join-Path $skillRoot "agents\openai.yaml"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } })
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Reason)
    if (-not $Text.Contains($Needle)) { throw $Reason }
}

try {
    $skillText = Get-Content -LiteralPath $skillPath -Raw
    $agentText = Get-Content -LiteralPath $agentPath -Raw

    foreach ($needle in @(
        "name: audit-project",
        "# Project Audit",
        "findings-first sibling",
        "docs/superpowers/specs/YYYY-MM-DD-<slug>-audit-findings.md",
        "P0",
        "P1",
        "P2",
        "P3",
        "diagnose",
        "thermo-nuclear-code-quality-review",
        "improve-codebase-architecture",
        "react-doctor",
        "project_audit_next_step",
        "project_audit_progress_route",
        "project_audit_revisit_route",
        "Native Question Debug Ledger",
        "debug_question_mode",
        "recommended-default",
        "user-provided-debug-answer"
    )) {
        Assert-Contains -Text $skillText -Needle $needle -Reason "SKILL.md missing required text: $needle"
    }
    Add-Check -Name "skill contract" -Ok $true -Reason "passed"

    foreach ($needle in @(
        "display_name: `"Audit Project`"",
        "P0",
        "P1",
        "P2",
        "P3",
        "diagnose",
        "thermo-nuclear-code-quality-review",
        "improve-codebase-architecture",
        "react-doctor",
        "project_audit_next_step",
        "Yes Prepare Repair Work",
        "Revisit Review Or Extend Findings",
        "Nested Yes-route menus must not include terminal options",
        "Custom Other never terminates a workflow directly"
    )) {
        Assert-Contains -Text $agentText -Needle $needle -Reason "openai.yaml missing required text: $needle"
    }
    Add-Check -Name "metadata contract" -Ok $true -Reason "passed"

    [pscustomobject]@{ ok = $true; phase = "audit-project-scenarios"; checks = $checks } | ConvertTo-Json -Depth 8
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "audit-project-scenarios"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
