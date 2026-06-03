[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $PSScriptRoot "validate-flat-artifact-roots.ps1"
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $results.Add([pscustomobject]@{ name = $Name; ok = $true; reason = "passed" })
    } catch {
        $results.Add([pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message })
    }
}

function Invoke-Validator {
    param([string]$Root)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $Root 2>&1
    $raw = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{ ok = $false; reason = "empty validator output" } }
    try { return ($raw | ConvertFrom-Json) } catch { return [pscustomobject]@{ ok = $false; reason = $raw } }
}

Invoke-Scenario "repo has flat artifact roots validator" {
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw "missing validate-flat-artifact-roots.ps1" }
}

Invoke-Scenario "nested milestone canonical artifact folders are rejected" {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("flat-artifacts-" + [guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\milestones\M1\issues") -Force | Out-Null
        $result = Invoke-Validator -Root $root
        if ($result.ok -or $result.reason -notmatch "nested canonical milestone artifact") { throw "expected nested canonical milestone artifact rejection" }
    } finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

Invoke-Scenario "flat canonical roots are accepted" {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("flat-artifacts-" + [guid]::NewGuid().ToString("N"))
    try {
        foreach ($path in @(
            "docs\superpowers\specs",
            "docs\superpowers\plans",
            "docs\superpowers\issues",
            "docs\superpowers\milestones"
        )) {
            New-Item -ItemType Directory -Path (Join-Path $root $path) -Force | Out-Null
        }
        Set-Content -LiteralPath (Join-Path $root "docs\superpowers\milestones\M1-source-of-truth.md") -Value "# M1`n" -Encoding utf8NoBOM
        $result = Invoke-Validator -Root $root
        if (-not $result.ok) { throw $result.reason }
    } finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
