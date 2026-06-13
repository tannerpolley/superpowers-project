[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$session = $null

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Remove-FixtureReport {
    param($Session)
    if ($null -eq $Session -or [string]::IsNullOrWhiteSpace([string]$Session.report_root)) { return }
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $reportRoot = [IO.Path]::GetFullPath([string]$Session.report_root)
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $root ".superpowers\reports"))
    if ($reportRoot.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $reportRoot)) {
        Remove-Item -LiteralPath $reportRoot -Recurse -Force
        $dateRoot = Split-Path -Parent $reportRoot
        $reportsRoot = Split-Path -Parent $dateRoot
        $superpowersRoot = Split-Path -Parent $reportsRoot
        foreach ($path in @($dateRoot, $reportsRoot, $superpowersRoot)) {
            if ((Test-Path -LiteralPath $path -PathType Container) -and -not (Get-ChildItem -LiteralPath $path -Force | Select-Object -First 1)) {
                Remove-Item -LiteralPath $path -Force
            }
        }
    }
}

try {
    $sessionScript = Join-Path $RepoRoot "skills\companion-interface\scripts\new-report-session.ps1"
    $appendScript = Join-Path $RepoRoot "skills\companion-interface\scripts\append-event.ps1"
    $renderScript = Join-Path $RepoRoot "skills\companion-interface\scripts\render-report.ps1"
    $session = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $sessionScript -RepoRoot $RepoRoot -WorkflowName "brainstorm-spec" -Title "Fixture Report" | ConvertFrom-Json
    Add-Check -Name "session creates manifest" -Ok (Test-Path -LiteralPath $session.manifest_path) -Reason "manifest missing"
    Add-Check -Name "session creates events file" -Ok (Test-Path -LiteralPath $session.events_path) -Reason "events file missing"
    Add-Check -Name "session creates index file" -Ok (Test-Path -LiteralPath $session.index_path) -Reason "index.html missing"
    Add-Check -Name "session creates artifact root" -Ok (Test-Path -LiteralPath $session.artifact_root -PathType Container) -Reason "artifact root missing"
    Add-Check -Name "session stays under .superpowers reports" -Ok ($session.relative_report_root -like ".superpowers/reports/*") -Reason "wrong report root"

    $event = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $appendScript -RepoRoot $RepoRoot -ReportRoot $session.relative_report_root -Type "summary_added" -Title "Fixture Summary" -Summary "Report evidence was added." | ConvertFrom-Json
    Add-Check -Name "append event succeeds" -Ok ($event.ok -eq $true) -Reason "append failed"
    Add-Check -Name "manifest event count increments" -Ok ($event.event_count -eq 2) -Reason "unexpected event count"

    $validationPayload = '{"command":"pwsh -File test.ps1","working_directory":".","exit_code":0,"status":"passed","excerpt":"fixture validation passed"}'
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $appendScript -RepoRoot $RepoRoot -ReportRoot $session.relative_report_root -Type "validation_result" -Title "Fixture Validation" -Summary "Validation passed." -PayloadJson $validationPayload | ConvertFrom-Json | Out-Null
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $appendScript -RepoRoot $RepoRoot -ReportRoot $session.relative_report_root -Type "decision_needed" -Title "Next Decision" -Summary "Review the report." | ConvertFrom-Json | Out-Null
    $rendered = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $renderScript -RepoRoot $RepoRoot -ReportRoot $session.relative_report_root | ConvertFrom-Json
    Add-Check -Name "render report succeeds" -Ok ($rendered.ok -eq $true) -Reason "render failed"
    Add-Check -Name "index exists" -Ok (Test-Path -LiteralPath $rendered.index_path) -Reason "index.html missing"
    $html = Get-Content -LiteralPath $rendered.index_path -Raw
    foreach ($section in @("Run Overview", "Workflow Timeline", "Artifact Browser", "Evidence Feed", "Decision Dock", "Interpretation Summary")) {
        Add-Check -Name "html contains $section" -Ok $html.Contains($section) -Reason "missing section $section"
    }
    Add-Check -Name "html has no network dependencies" -Ok (-not ($html.Contains("https://") -or $html.Contains("http://"))) -Reason "html contains external URL"

    $failedAppend = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $appendScript -RepoRoot $RepoRoot -ReportRoot "..\outside" -Type "summary_added" -Title "Bad" -Summary "Bad" 2>&1
    Add-Check -Name "outside report root is rejected" -Ok ($LASTEXITCODE -ne 0 -and (($failedAppend | Out-String) -match "outside repo root|report root")) -Reason "outside root was accepted"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "companion-interface-scenarios"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "companion-interface-scenarios"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    Remove-FixtureReport -Session $session
}
