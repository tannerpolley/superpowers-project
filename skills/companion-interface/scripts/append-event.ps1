[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$ReportRoot,
    [Parameter(Mandatory = $true)][ValidateSet("artifact_added", "artifact_changed", "markdown_rendered", "plot_added", "table_added", "command_result", "validation_result", "test_result", "file_inventory", "risk_added", "summary_added", "decision_needed", "decision_recorded", "cleanup_result", "run_completed")][string]$Type,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Summary = "",
    [string]$ArtifactPath = "",
    [string]$PayloadJson = "{}"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\companion-report.ps1")

try {
    $root = Resolve-CompanionRepoRoot -RepoRoot $RepoRoot
    $relativeReportRoot = Assert-CompanionReportRoot -RepoRoot $root -ReportRoot $ReportRoot
    $resolvedReportRoot = [IO.Path]::GetFullPath((Join-Path $root $relativeReportRoot))
    if (-not (Test-Path -LiteralPath $resolvedReportRoot -PathType Container)) {
        throw "report root does not exist: $relativeReportRoot"
    }

    $eventsPath = Join-Path $resolvedReportRoot "events.jsonl"
    $manifestPath = Join-Path $resolvedReportRoot "manifest.json"
    if (-not (Test-Path -LiteralPath $eventsPath -PathType Leaf)) { throw "events.jsonl is missing: $relativeReportRoot" }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "manifest.json is missing: $relativeReportRoot" }

    try {
        $payload = $PayloadJson | ConvertFrom-Json
    } catch {
        throw "PayloadJson is not valid JSON: $($_.Exception.Message)"
    }

    $relativeArtifactPath = ""
    if (-not [string]::IsNullOrWhiteSpace($ArtifactPath)) {
        $relativeArtifactPath = ConvertTo-CompanionRelativePath -RepoRoot $root -Path $ArtifactPath
    }

    $event = [ordered]@{
        id = [guid]::NewGuid().ToString("N")
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        type = $Type
        title = $Title
        summary = $Summary
        artifact_path = $relativeArtifactPath
        payload = $payload
    }

    Add-Content -LiteralPath $eventsPath -Encoding utf8NoBOM -Value (ConvertTo-CompanionJsonLine -Value $event)

    $eventCount = @((Get-Content -LiteralPath $eventsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })).Count
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifest.event_count = $eventCount
    $manifest.latest_event_id = $event.id
    $manifest.updated_at = $event.timestamp
    if (-not [string]::IsNullOrWhiteSpace($Summary)) {
        $manifest.latest_summary = $Summary
    }
    Write-CompanionJson -Path $manifestPath -Value $manifest

    [ordered]@{
        ok = $true
        event_id = $event.id
        event_count = $eventCount
        manifest_path = $manifestPath
    } | ConvertTo-Json -Depth 20
} catch {
    [ordered]@{ ok = $false; phase = "append-event"; reason = $_.Exception.Message } | ConvertTo-Json -Depth 8
    exit 1
}
