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

function Copy-RuntimeSurface {
    param([string]$SourceRoot, [string]$TargetRoot)
    New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    foreach ($relative in @(".codex-plugin", "skills", "assets")) {
        $source = Join-Path $SourceRoot $relative
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $TargetRoot $relative) -Recurse
        }
    }
    $sourceLib = Join-Path $SourceRoot "scripts\lib"
    if (Test-Path -LiteralPath $sourceLib -PathType Container) {
        New-Item -ItemType Directory -Path (Join-Path $TargetRoot "scripts") -Force | Out-Null
        Copy-Item -LiteralPath $sourceLib -Destination (Join-Path $TargetRoot "scripts\lib") -Recurse
    }
    $checker = Join-Path $SourceRoot "scripts\get-agent-plugin-version.ps1"
    if (Test-Path -LiteralPath $checker -PathType Leaf) {
        New-Item -ItemType Directory -Path (Join-Path $TargetRoot "scripts") -Force | Out-Null
        Copy-Item -LiteralPath $checker -Destination (Join-Path $TargetRoot "scripts\get-agent-plugin-version.ps1")
    }
    $validator = Join-Path $SourceRoot "scripts\validate-auto-mode-authorization.ps1"
    if (Test-Path -LiteralPath $validator -PathType Leaf) {
        New-Item -ItemType Directory -Path (Join-Path $TargetRoot "scripts") -Force | Out-Null
        Copy-Item -LiteralPath $validator -Destination (Join-Path $TargetRoot "scripts\validate-auto-mode-authorization.ps1")
    }
    $planTaskUseCaseValidator = Join-Path $SourceRoot "scripts\validate-plan-task-use-cases.ps1"
    if (Test-Path -LiteralPath $planTaskUseCaseValidator -PathType Leaf) {
        New-Item -ItemType Directory -Path (Join-Path $TargetRoot "scripts") -Force | Out-Null
        Copy-Item -LiteralPath $planTaskUseCaseValidator -Destination (Join-Path $TargetRoot "scripts\validate-plan-task-use-cases.ps1")
    }
}

function Invoke-VersionCheck {
    param([string[]]$Arguments)
    $scriptPath = Join-Path $RepoRoot "scripts\get-agent-plugin-version.ps1"
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "missing version checker: $scriptPath"
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
    $text = ($raw | Out-String).Trim()
    try {
        [pscustomobject]@{ exit_code = $LASTEXITCODE; json = ($text | ConvertFrom-Json); raw = $text }
    } catch {
        [pscustomobject]@{ exit_code = $LASTEXITCODE; json = [pscustomobject]@{ ok = $false; reason = $text }; raw = $text }
    }
}

function Invoke-VersionCheckRaw {
    param([string[]]$Arguments)
    $scriptPath = Join-Path $RepoRoot "scripts\get-agent-plugin-version.ps1"
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "missing version checker: $scriptPath"
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = (($raw | Out-String).Trim()) }
}

try {
    $manifest = Get-Content -LiteralPath (Join-Path $RepoRoot ".codex-plugin\plugin.json") -Raw | ConvertFrom-Json
    $startupPrompt = (($manifest.interface.defaultPrompt | ForEach-Object { [string]$_ }) -join "`n")
    Add-Check -Name "plugin startup prompt requires version banner" -Ok (
        $startupPrompt.Contains("At Superpowers Project startup") -and
        $startupPrompt.Contains("get-agent-plugin-version.ps1 -Banner -RequireCurrent") -and
        $startupPrompt.Contains("print the banner")
    ) -Reason "plugin defaultPrompt must require agents to print a startup version banner"

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("agent-plugin-version-" + [guid]::NewGuid().ToString("N"))
    $liveRoot = Join-Path $tempRoot "live\superpowers-project"
    $cacheRoot = Join-Path $tempRoot "cache"
    $freshCacheRoot = Join-Path $cacheRoot "tanner-local\project\fresh"
    $staleCacheRoot = Join-Path $cacheRoot "tanner-local\project\stale"
    Copy-RuntimeSurface -SourceRoot $RepoRoot -TargetRoot $liveRoot
    Copy-RuntimeSurface -SourceRoot $RepoRoot -TargetRoot $freshCacheRoot
    Copy-RuntimeSurface -SourceRoot $RepoRoot -TargetRoot $staleCacheRoot
    Add-Content -LiteralPath (Join-Path $staleCacheRoot "skills\brainstorm-spec\SKILL.md") -Value "`n# stale fixture"

    $fresh = Invoke-VersionCheck -Arguments @(
        "-RepoRoot", $RepoRoot,
        "-LivePluginRoot", $liveRoot,
        "-CacheRoot", $cacheRoot,
        "-ObservedPluginRoot", $freshCacheRoot,
        "-RequireCurrent"
    )
    Add-Check -Name "fresh observed plugin passes" -Ok ($fresh.exit_code -eq 0 -and $fresh.json.ok -eq $true -and $fresh.json.observed.matches_source -eq $true) -Reason ([string]$fresh.json.reason)
    Add-Check -Name "cache candidates are reported" -Ok (@($fresh.json.cache_candidates).Count -eq 2) -Reason "expected fresh and stale cache candidates"
    Add-Check -Name "stale unobserved cache is visible" -Ok (@($fresh.json.cache_candidates | Where-Object { $_.matches_source -eq $false }).Count -eq 1) -Reason "expected stale cache candidate to be reported"

    $banner = Invoke-VersionCheckRaw -Arguments @(
        "-RepoRoot", $RepoRoot,
        "-LivePluginRoot", $liveRoot,
        "-CacheRoot", $cacheRoot,
        "-ObservedPluginRoot", $freshCacheRoot,
        "-Banner",
        "-RequireCurrent"
    )
    Add-Check -Name "startup banner prints exact current version" -Ok (
        $banner.exit_code -eq 0 -and
        $banner.raw.Contains("Superpowers Project plugin") -and
        $banner.raw.Contains("manifest_version:") -and
        $banner.raw.Contains("contract_hash:") -and
        $banner.raw.Contains("source/live: current") -and
        $banner.raw.Contains("observed: current")
    ) -Reason "expected -Banner to print current human-readable startup status"

    $staleObserved = Invoke-VersionCheck -Arguments @(
        "-RepoRoot", $RepoRoot,
        "-LivePluginRoot", $liveRoot,
        "-CacheRoot", $cacheRoot,
        "-ObservedPluginRoot", $staleCacheRoot,
        "-RequireCurrent"
    )
    Add-Check -Name "stale observed plugin fails strict check" -Ok ($staleObserved.exit_code -ne 0 -and $staleObserved.json.ok -eq $false -and [string]$staleObserved.json.reason -match "observed") -Reason "stale observed plugin should fail"

    $validatorDriftRoot = Join-Path $cacheRoot "tanner-local\project\validator-drift"
    Copy-RuntimeSurface -SourceRoot $RepoRoot -TargetRoot $validatorDriftRoot
    Add-Content -LiteralPath (Join-Path $validatorDriftRoot "scripts\validate-plan-task-use-cases.ps1") -Value "`n# validator drift fixture"
    $validatorDrift = Invoke-VersionCheck -Arguments @(
        "-RepoRoot", $RepoRoot,
        "-LivePluginRoot", $liveRoot,
        "-CacheRoot", $cacheRoot,
        "-ObservedPluginRoot", $validatorDriftRoot,
        "-RequireCurrent"
    )
    Add-Check -Name "observed validator drift fails strict check" -Ok ($validatorDrift.exit_code -ne 0 -and $validatorDrift.json.ok -eq $false -and [string]$validatorDrift.json.reason -match "observed") -Reason "observed plugin with validator drift should fail"

    Add-Content -LiteralPath (Join-Path $liveRoot "skills\brainstorm-spec\SKILL.md") -Value "`n# live drift fixture"
    $staleLive = Invoke-VersionCheck -Arguments @(
        "-RepoRoot", $RepoRoot,
        "-LivePluginRoot", $liveRoot,
        "-CacheRoot", $cacheRoot,
        "-RequireCurrent"
    )
    Add-Check -Name "stale live plugin fails strict check" -Ok ($staleLive.exit_code -ne 0 -and $staleLive.json.ok -eq $false -and [string]$staleLive.json.reason -match "live") -Reason "stale live plugin should fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "agent-plugin-version-tests"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "agent-plugin-version-tests"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
