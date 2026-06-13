[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$WorkflowName,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$SourcePath = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\companion-report.ps1")

try {
    $root = Resolve-CompanionRepoRoot -RepoRoot $RepoRoot
    $runId = New-CompanionRunId -WorkflowName $WorkflowName
    $reportRoot = Get-CompanionReportRoot -RepoRoot $root -RunId $runId
    $artifactRoot = Join-Path $reportRoot "artifacts"
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

    $relativeReportRoot = ConvertTo-CompanionRelativePath -RepoRoot $root -Path $reportRoot
    $relativeArtifactRoot = ConvertTo-CompanionRelativePath -RepoRoot $root -Path $artifactRoot
    $manifestPath = Join-Path $reportRoot "manifest.json"
    $eventsPath = Join-Path $reportRoot "events.jsonl"
    $indexPath = Join-Path $reportRoot "index.html"
    $now = (Get-Date).ToUniversalTime().ToString("o")
    $sourceRelativePath = ""
    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        $sourceRelativePath = ConvertTo-CompanionRelativePath -RepoRoot $root -Path $SourcePath
    }

    $event = [ordered]@{
        id = [guid]::NewGuid().ToString("N")
        timestamp = $now
        type = "run_started"
        title = $Title
        summary = "Report session created."
        artifact_path = ""
        payload = [ordered]@{
            workflow_name = $WorkflowName
            source_path = $sourceRelativePath
        }
    }

    Set-Content -LiteralPath $eventsPath -Encoding utf8NoBOM -Value (ConvertTo-CompanionJsonLine -Value $event)

    $manifest = [ordered]@{
        title = $Title
        workflow_name = $WorkflowName
        source_path = $sourceRelativePath
        run_id = $runId
        created_at = $now
        updated_at = $now
        status = "active"
        report_root = $relativeReportRoot
        artifact_root = $relativeArtifactRoot
        event_count = 1
        latest_event_id = $event.id
        latest_summary = $event.summary
    }
    Write-CompanionJson -Path $manifestPath -Value $manifest
    Set-Content -LiteralPath $indexPath -Encoding utf8NoBOM -Value "<!doctype html><html><body><h1>$([System.Net.WebUtility]::HtmlEncode($Title))</h1><p>Report session created. Render the report to refresh this page.</p></body></html>"

    [ordered]@{
        ok = $true
        report_root = $reportRoot
        relative_report_root = $relativeReportRoot
        manifest_path = $manifestPath
        events_path = $eventsPath
        index_path = $indexPath
        artifact_root = $artifactRoot
    } | ConvertTo-Json -Depth 20
} catch {
    [ordered]@{ ok = $false; phase = "new-report-session"; reason = $_.Exception.Message } | ConvertTo-Json -Depth 8
    exit 1
}
