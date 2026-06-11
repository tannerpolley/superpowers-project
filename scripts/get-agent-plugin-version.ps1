[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\superpowers-project"),
    [string]$CacheRoot = (Join-Path $env:USERPROFILE ".codex\plugins\cache"),
    [string]$ObservedPluginRoot,
    [string]$ObservedSkillRoot,
    [switch]$Banner,
    [switch]$RequireCurrent
)

$ErrorActionPreference = "Stop"

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    } finally {
        $sha.Dispose()
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Normalize-RelativePath {
    param([string]$Path)
    ($Path -replace '\\', '/').TrimStart("/")
}

function Get-RuntimeContractEntries {
    param([Parameter(Mandatory = $true)][string]$PluginRoot)

    $root = [IO.Path]::GetFullPath($PluginRoot)
    $entries = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @(".codex-plugin\plugin.json", "skills", "assets", "scripts\lib", "scripts\get-agent-plugin-version.ps1")) {
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $rel = Normalize-RelativePath ([IO.Path]::GetRelativePath($root, $path))
            $entries.Add("$rel`t$(Get-FileSha256 -Path $path)") | Out-Null
        } elseif (Test-Path -LiteralPath $path -PathType Container) {
            $files = @(Get-ChildItem -LiteralPath $path -File -Recurse | Sort-Object FullName)
            foreach ($file in $files) {
                $rel = Normalize-RelativePath ([IO.Path]::GetRelativePath($root, $file.FullName))
                $entries.Add("$rel`t$(Get-FileSha256 -Path $file.FullName)") | Out-Null
            }
        } else {
            $entries.Add("MISSING:$(Normalize-RelativePath $relative)") | Out-Null
        }
    }
    @($entries)
}

function Get-RuntimeContractHash {
    param([Parameter(Mandatory = $true)][string]$PluginRoot)
    $entries = @(Get-RuntimeContractEntries -PluginRoot $PluginRoot)
    Get-StringSha256 -Text (($entries | Sort-Object) -join "`n")
}

function Read-PluginManifest {
    param([Parameter(Mandatory = $true)][string]$PluginRoot)
    $manifestPath = Join-Path $PluginRoot ".codex-plugin\plugin.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return $null
    }
    Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
}

function Invoke-GitCapture {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>&1
    [pscustomobject]@{ exit_code = $LASTEXITCODE; output = ($output | Out-String).Trim() }
}

function Resolve-ObservedRoot {
    param([string]$PluginRoot, [string]$SkillRoot)
    if (-not [string]::IsNullOrWhiteSpace($PluginRoot)) {
        return [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PluginRoot).Path)
    }
    if ([string]::IsNullOrWhiteSpace($SkillRoot)) { return $null }

    $cursor = if (Test-Path -LiteralPath $SkillRoot -PathType Leaf) {
        Split-Path -Parent (Resolve-Path -LiteralPath $SkillRoot).Path
    } else {
        (Resolve-Path -LiteralPath $SkillRoot).Path
    }

    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath (Join-Path $cursor ".codex-plugin\plugin.json") -PathType Leaf) {
            return [IO.Path]::GetFullPath($cursor)
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    throw "could not resolve plugin root from observed skill root: $SkillRoot"
}

function New-VersionSurface {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$PluginRoot,
        [string]$SourceHash
    )

    $exists = -not [string]::IsNullOrWhiteSpace($PluginRoot) -and (Test-Path -LiteralPath $PluginRoot -PathType Container)
    $manifest = if ($exists) { Read-PluginManifest -PluginRoot $PluginRoot } else { $null }
    $hash = if ($exists) { Get-RuntimeContractHash -PluginRoot $PluginRoot } else { "" }
    [pscustomobject]@{
        name = $Name
        path = if ([string]::IsNullOrWhiteSpace($PluginRoot)) { "" } else { [IO.Path]::GetFullPath($PluginRoot) }
        exists = $exists
        manifest_name = if ($null -eq $manifest) { "" } else { [string]$manifest.name }
        manifest_version = if ($null -eq $manifest) { "" } else { [string]$manifest.version }
        contract_hash = $hash
        matches_source = ($exists -and $hash -eq $SourceHash)
    }
}

function Get-CachePluginRoots {
    param([string]$Root, [string]$ExpectedManifestName)
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root -PathType Container)) {
        return @()
    }
    $roots = [System.Collections.Generic.List[string]]::new()
    $manifestFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter "plugin.json" -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -match [regex]::Escape(".codex-plugin")
    })
    foreach ($file in $manifestFiles) {
        try {
            $manifest = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            $pluginRoot = Split-Path -Parent (Split-Path -Parent $file.FullName)
            $normalizedRoot = Normalize-RelativePath $pluginRoot
            if (
                [string]$manifest.name -eq $ExpectedManifestName -or
                $normalizedRoot -match '/tanner-local/project/' -or
                $normalizedRoot -match '/tanner-local/superpowers-project/'
            ) {
                $roots.Add([IO.Path]::GetFullPath($pluginRoot)) | Out-Null
            }
        } catch {
            continue
        }
    }
    @($roots | Sort-Object -Unique)
}

function Format-VersionBanner {
    param([Parameter(Mandatory = $true)]$Report)

    $sourceLiveStatus = if ($Report.live.matches_source -eq $true) { "current" } else { "stale" }
    $observedStatus = if ($null -eq $Report.observed) {
        "not supplied"
    } elseif ($Report.observed.matches_source -eq $true) {
        "current"
    } else {
        "stale"
    }
    @(
        "Superpowers Project plugin",
        "manifest_version: $($Report.source.manifest_version)",
        "git_commit: $($Report.source.git_commit)",
        "source_dirty: $($Report.source.dirty)",
        "contract_hash: $($Report.source.contract_hash)",
        "source/live: $sourceLiveStatus",
        "observed: $observedStatus",
        "cache_candidates: $(@($Report.cache_candidates).Count) total, $($Report.stale_cache_candidate_count) stale",
        "reason: $($Report.reason)"
    ) -join [Environment]::NewLine
}

try {
    $sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
    $sourceManifest = Read-PluginManifest -PluginRoot $sourceRoot
    if ($null -eq $sourceManifest) { throw "source plugin manifest is missing" }
    $sourceHash = Get-RuntimeContractHash -PluginRoot $sourceRoot
    $head = Invoke-GitCapture -Root $sourceRoot -Arguments @("rev-parse", "HEAD")
    $status = Invoke-GitCapture -Root $sourceRoot -Arguments @("status", "--short")

    $source = [pscustomobject]@{
        name = "source"
        path = $sourceRoot
        manifest_name = [string]$sourceManifest.name
        manifest_version = [string]$sourceManifest.version
        git_commit = if ($head.exit_code -eq 0) { [string]$head.output } else { "" }
        dirty = -not [string]::IsNullOrWhiteSpace([string]$status.output)
        contract_hash = $sourceHash
    }
    $live = New-VersionSurface -Name "live" -PluginRoot $LivePluginRoot -SourceHash $sourceHash
    $observedRoot = Resolve-ObservedRoot -PluginRoot $ObservedPluginRoot -SkillRoot $ObservedSkillRoot
    $observed = if ($null -eq $observedRoot) { $null } else { New-VersionSurface -Name "observed" -PluginRoot $observedRoot -SourceHash $sourceHash }
    $cacheCandidates = @(Get-CachePluginRoots -Root $CacheRoot -ExpectedManifestName ([string]$sourceManifest.name) | ForEach-Object {
        New-VersionSurface -Name "cache" -PluginRoot $_ -SourceHash $sourceHash
    })

    $failures = [System.Collections.Generic.List[string]]::new()
    if ($live.matches_source -ne $true) { $failures.Add("live plugin differs from source") | Out-Null }
    if ($null -ne $observed -and $observed.matches_source -ne $true) { $failures.Add("observed plugin differs from source") | Out-Null }
    if ($null -ne $observed -and [string]$observed.manifest_version -ne [string]$sourceManifest.version) { $failures.Add("observed plugin manifest version differs from source") | Out-Null }
    if ([string]$live.manifest_version -ne [string]$sourceManifest.version) { $failures.Add("live plugin manifest version differs from source") | Out-Null }

    $staleCacheCandidates = @($cacheCandidates | Where-Object { $_.matches_source -ne $true })
    $ok = if ($RequireCurrent) { $failures.Count -eq 0 } else { $true }
    $reason = if ($ok) {
        "source, live, and observed plugin surfaces are current"
    } elseif ($failures.Count -gt 0) {
        $failures -join "; "
    } else {
        "plugin version check failed"
    }

    $report = [pscustomobject]@{
        ok = $ok
        phase = "agent-plugin-version"
        reason = $reason
        source = $source
        live = $live
        observed = $observed
        cache_candidates = $cacheCandidates
        stale_cache_candidate_count = $staleCacheCandidates.Count
        current_agent_known = ($null -ne $observed)
        recommended_recovery = "Run scripts/sync-live.ps1 -Validate from source to refresh live install and matching local plugin cache roots. If the observed surface still differs, start a fresh agent session so it reloads the plugin cache."
    }

    if ($Banner) {
        Format-VersionBanner -Report $report
    } else {
        $report | ConvertTo-Json -Depth 16
    }
    if (-not $ok) { exit 1 }
} catch {
    $report = [pscustomobject]@{
        ok = $false
        phase = "agent-plugin-version"
        reason = $_.Exception.Message
        source = [pscustomobject]@{
            manifest_version = ""
            git_commit = ""
            contract_hash = ""
        }
        live = [pscustomobject]@{ matches_source = $false }
        observed = $null
        cache_candidates = @()
        stale_cache_candidate_count = 0
    }
    if ($Banner) {
        Format-VersionBanner -Report $report
    } else {
        $report | ConvertTo-Json -Depth 8
    }
    exit 1
}
