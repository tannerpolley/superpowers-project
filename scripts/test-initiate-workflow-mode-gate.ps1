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

function Read-RepoText {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $RepoRoot $RelativePath) -Raw
}

try {
    $skill = Read-RepoText "skills/initiate-workflow/SKILL.md"
    $metadata = Read-RepoText "skills/initiate-workflow/agents/openai.yaml"
    $readme = Read-RepoText "README.md"
    $summary = Read-RepoText "docs/superpowers/OUTCOME_WORKFLOW.md"
    $mermaid = Read-RepoText "docs/assets/native-qa-main-flow-mermaid.md"

    foreach ($textCase in @(
        @{ name = "skill"; text = $skill },
        @{ name = "metadata"; text = $metadata },
        @{ name = "README"; text = $readme },
        @{ name = "summary"; text = $summary },
        @{ name = "Mermaid"; text = $mermaid }
    )) {
        foreach ($needle in @("project_workflow_mode", "Manual Mode", "Auto Mode", "Looping Mode")) {
            Add-Check "$($textCase.name) contains $needle" $textCase.text.Contains($needle) "$($textCase.name) missing $needle"
        }
    }

    Add-Check "router names mode ledger" $skill.Contains("workflow mode ledger") "router must require a workflow mode ledger"
    Add-Check "router names root validator" $skill.Contains("scripts/validate-workflow-mode-ledger.ps1") "router must name the root mode-ledger validator"
    Add-Check "auto mode is one-route only" $skill.Contains("one-route autonomy") "Auto Mode must be one-route only"
    Add-Check "looping mode delegates to loop controller" $skill.Contains('$superpowers-project:loop-controller') "Looping Mode must delegate to Loop Controller"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "initiate-workflow-mode-gate"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check "fatal" $false $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "initiate-workflow-mode-gate"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}

