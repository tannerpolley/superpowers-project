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

try {
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("prepare-release-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $receiptPath = Join-Path $tempDir "release-receipt.json"
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\prepare-release.ps1") -RepoRoot $RepoRoot -CheckOnly -OutputPath $receiptPath
    if ($LASTEXITCODE -ne 0) { throw "prepare-release check failed: $($raw | Out-String)" }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    Add-Check -Name "receipt reports ok" -Ok ($receipt.ok -eq $true) -Reason "release receipt should be ok in check-only mode"
    Add-Check -Name "manifest version recorded" -Ok (-not [string]::IsNullOrWhiteSpace([string]$receipt.manifest_version)) -Reason "manifest_version missing"
    Add-Check -Name "changelog evidence recorded" -Ok ($receipt.changelog.has_unreleased -eq $true -or $receipt.changelog.has_version_entry -eq $true) -Reason "changelog evidence missing"
    Add-Check -Name "required gates recorded" -Ok (@($receipt.required_gates | Where-Object { [string]$_ -like "*validate.ps1*" }).Count -gt 0 -and @($receipt.required_gates | Where-Object { [string]$_ -like "*sync-live.ps1 -Validate*" }).Count -gt 0) -Reason "release receipt missing required gates"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "prepare-release-tests"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "prepare-release-tests"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
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
