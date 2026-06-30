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

function Normalize-Text {
    param([string]$Text)
    (($Text -replace "\r\n", "`n") -replace "\r", "`n").Trim()
}

try {
    $summaryPath = Join-Path $RepoRoot "docs\superpowers\OUTCOME_WORKFLOW.md"
    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        throw "outcome workflow is missing"
    }

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("outcome-workflow-summary-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $generatedPath = Join-Path $tempDir "OUTCOME_WORKFLOW.md"
    $resultRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\generate-outcome-workflow-summary.ps1") -RepoRoot $RepoRoot -OutputPath $generatedPath
    if ($LASTEXITCODE -ne 0) { throw "generator failed: $($resultRaw | Out-String)" }
    $current = Get-Content -LiteralPath $summaryPath -Raw
    $generated = Get-Content -LiteralPath $generatedPath -Raw
    Add-Check -Name "generated summary is current" -Ok ((Normalize-Text $current) -eq (Normalize-Text $generated)) -Reason "docs/superpowers/OUTCOME_WORKFLOW.md is stale; run scripts/generate-outcome-workflow-summary.ps1"

    foreach ($needle in @(
        '$superpowers-project:*',
        'project_brainstorm_visual_companion',
        'project_brainstorm_plan_route',
        'project_merge_final_health_gate',
        'debug_question_mode',
        'scripts/sync-live.ps1 -Validate',
        'Task # Use Cases',
        'validate-plan-task-use-cases.ps1',
        'Outcome Proof And Readiness Review',
        'validate-plan-outcome-proof.ps1',
        'Outcome Summary',
        'outcome_proof',
        'readiness_review',
        'plan_alignment',
        'reality_evidence',
        'get-agent-plugin-version.ps1',
        '-Banner -RequireCurrent',
        'Startup Version Check',
        'contract_hash',
        'ObservedSkillRoot',
        'matching local plugin cache roots',
        'Plugin cache paths are not durable contracts',
        'project_workflow_mode',
        'Workflow Modes',
        'Manual Mode',
        'Looping Mode',
        'selected_mode',
        'validate-workflow-mode-ledger.ps1',
        '<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1',
        'GitHub Milestones And Sub-Issues',
        'Hierarchy modes are `flat`, `issue-set`, and `sub-milestone`',
        'Sub-Issue Role: leaf',
        'Executable: true',
        'hierarchy_rollup',
        'subIssuesSummary',
        'parent/sub-issue drift',
        'clean-title migration candidates',
        'rollup, alignment, or tracker repair'
    )) {
        Add-Check -Name "summary contains $needle" -Ok $current.Contains($needle) -Reason "outcome workflow missing $needle"
    }

    $auditRowPattern = '(?m)^\| `audit-project` \| .+ \| .*`project_auto_mode_authorization`'
    Add-Check -Name "audit-project summary lists Auto Mode authorization" -Ok ([regex]::IsMatch($current, $auditRowPattern)) -Reason "audit-project summary row missing project_auto_mode_authorization"
    $brainstormRowPattern = '(?m)^\| `brainstorm-spec` \| .+ \| (?!.*`project_auto_mode_authorization`).*`project_brainstorm_plan_route`'
    Add-Check -Name "brainstorm summary excludes Auto Mode authorization" -Ok ([regex]::IsMatch($current, $brainstormRowPattern)) -Reason "brainstorm-spec summary row must list planning routes without project_auto_mode_authorization"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "outcome-workflow-summary"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "outcome-workflow-summary"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempDir)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
