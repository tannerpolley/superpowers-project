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
    $inputPath = if ([IO.Path]::IsPathRooted($MetricsInputPath)) { $MetricsInputPath } else { Join-Path $repo $MetricsInputPath }
    $metrics = Read-LoopControllerJson -Path $inputPath
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
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $target -Encoding utf8NoBOM
    $report | ConvertTo-Json -Depth 20
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-metrics" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
