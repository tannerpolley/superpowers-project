[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [string]$Version,
    [string]$OutputPath,
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Invoke-GitCapture {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = ($output | Out-String).Trim()
    }
}

function Get-ReleaseBaseVersion {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    ([string]$Value -split '\+')[0].TrimStart("v")
}

function Write-Receipt {
    param([object]$Receipt)
    $json = $Receipt | ConvertTo-Json -Depth 16
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $target = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $RepoRoot $OutputPath }
        $targetDir = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Set-Content -LiteralPath $target -Value $json -Encoding utf8NoBOM
    }
    $json
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $manifestPath = Join-Path $root ".codex-plugin\plugin.json"
    $changelogPath = Join-Path $root "CHANGELOG.md"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "missing plugin manifest: $manifestPath" }
    if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) { throw "missing changelog: $changelogPath" }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$manifest.name -ne "superpowers-project") { throw "plugin manifest name must be superpowers-project" }
    $manifestVersion = [string]$manifest.version
    $releaseVersion = if ([string]::IsNullOrWhiteSpace($Version)) { $manifestVersion } else { $Version.TrimStart("v") }
    $releaseBaseVersion = Get-ReleaseBaseVersion -Value $releaseVersion
    $changelogText = Get-Content -LiteralPath $changelogPath -Raw
    $hasUnreleased = [bool]($changelogText -match '(?m)^##\s+Unreleased\s*$')
    $hasVersionEntry = [bool]($changelogText -match "(?m)^##\s+v?$([regex]::Escape($releaseBaseVersion))(\s|$)")
    $head = Invoke-GitCapture -Root $root -Arguments @("rev-parse", "HEAD")
    $status = Invoke-GitCapture -Root $root -Arguments @("status", "--short")
    $branch = Invoke-GitCapture -Root $root -Arguments @("branch", "--show-current")
    $dirty = -not [string]::IsNullOrWhiteSpace($status.output)

    $checks = [System.Collections.Generic.List[object]]::new()
    $checks.Add([pscustomobject]@{ name = "manifest name"; ok = $true; reason = "passed" })
    $checks.Add([pscustomobject]@{ name = "manifest version present"; ok = (-not [string]::IsNullOrWhiteSpace($manifestVersion)); reason = if ([string]::IsNullOrWhiteSpace($manifestVersion)) { "manifest version is empty" } else { "passed" } })
    $checks.Add([pscustomobject]@{ name = "changelog has release evidence"; ok = ($hasUnreleased -or $hasVersionEntry); reason = if ($hasUnreleased -or $hasVersionEntry) { "passed" } else { "CHANGELOG.md needs Unreleased or $releaseBaseVersion entry" } })
    $checks.Add([pscustomobject]@{ name = "git head available"; ok = ($head.exit_code -eq 0); reason = if ($head.exit_code -eq 0) { "passed" } else { $head.output } })
    if (-not $CheckOnly) {
        $checks.Add([pscustomobject]@{ name = "worktree clean"; ok = (-not $dirty); reason = if ($dirty) { "release publishing requires a clean worktree" } else { "passed" } })
        $checks.Add([pscustomobject]@{ name = "version entry exists"; ok = $hasVersionEntry; reason = if ($hasVersionEntry) { "passed" } else { "release publishing requires a versioned changelog entry" } })
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    $receipt = [ordered]@{
        ok = ($failed.Count -eq 0)
        phase = "prepare-release"
        check_only = [bool]$CheckOnly
        manifest_name = [string]$manifest.name
        manifest_version = $manifestVersion
        release_version = $releaseVersion
        release_base_version = $releaseBaseVersion
        branch = [string]$branch.output
        commit = if ($head.exit_code -eq 0) { [string]$head.output } else { "" }
        dirty = $dirty
        dirty_status = [string]$status.output
        changelog = [ordered]@{
            has_unreleased = $hasUnreleased
            has_version_entry = $hasVersionEntry
            path = "CHANGELOG.md"
        }
        required_gates = @(
            "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1",
            "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate",
            "git status --short"
        )
        publish_ready = ((-not $dirty) -and $hasVersionEntry -and $failed.Count -eq 0)
        checks = $checks
    }
    Write-Receipt -Receipt $receipt
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    $receipt = [ordered]@{
        ok = $false
        phase = "prepare-release"
        reason = $_.Exception.Message
    }
    Write-Receipt -Receipt $receipt
    exit 1
}
