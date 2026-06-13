$ErrorActionPreference = "Stop"

function Resolve-CompanionRepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
    }
    (Resolve-Path -LiteralPath $RepoRoot).Path
}

function ConvertTo-CompanionRelativePath {
    param([string]$RepoRoot, [string]$Path)
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "path is outside repo root: $candidate"
    }
    ([IO.Path]::GetRelativePath($root, $candidate) -replace "\\", "/")
}

function Assert-CompanionReportRoot {
    param([string]$RepoRoot, [string]$ReportRoot)
    $relative = ConvertTo-CompanionRelativePath -RepoRoot $RepoRoot -Path $ReportRoot
    if (-not $relative.StartsWith(".superpowers/reports/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "report root must be under .superpowers/reports: $relative"
    }
    $relative
}

function New-CompanionRunId {
    param([string]$WorkflowName)
    $safeWorkflow = ($WorkflowName.ToLowerInvariant() -replace "[^a-z0-9-]", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeWorkflow)) { throw "workflow name is required" }
    "$safeWorkflow-" + (Get-Date -Format "HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
}

function Get-CompanionReportRoot {
    param([string]$RepoRoot, [string]$RunId)
    $date = Get-Date -Format "yyyy-MM-dd"
    Join-Path $RepoRoot (Join-Path ".superpowers\reports" (Join-Path $date $RunId))
}

function Write-CompanionJson {
    param([string]$Path, [object]$Value)
    $json = $Value | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $Path -Encoding utf8NoBOM -Value $json
}

function ConvertTo-CompanionJsonLine {
    param([object]$Value)
    $Value | ConvertTo-Json -Depth 20 -Compress
}
