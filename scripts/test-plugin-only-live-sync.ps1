[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$syncPath = Join-Path $repoRoot "scripts/sync-live.ps1"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

try {
    $projectSkillsPath = Join-Path $repoRoot "scripts/lib/project-skills.ps1"
    $liveInstallPath = Join-Path $repoRoot "scripts/lib/live-install.ps1"
    $pluginCachePath = Join-Path $repoRoot "scripts/lib/plugin-cache.ps1"
    if (-not (Test-Path -LiteralPath $projectSkillsPath -PathType Leaf)) { throw "missing shared project skill registry: $projectSkillsPath" }
    if (-not (Test-Path -LiteralPath $liveInstallPath -PathType Leaf)) { throw "missing live install comparer: $liveInstallPath" }
    if (-not (Test-Path -LiteralPath $pluginCachePath -PathType Leaf)) { throw "missing plugin cache sync helper: $pluginCachePath" }
    . $projectSkillsPath
    . $liveInstallPath
    . $pluginCachePath

    $syncText = Get-Content -LiteralPath $syncPath -Raw
    foreach ($needle in @(
        'plugins\superpowers-project',
        'assets',
        'scripts\lib',
        'get-agent-plugin-version.ps1',
        'validate-auto-mode-authorization.ps1',
        'plugin-cache.ps1',
        'Sync-ProjectPluginCacheCandidates',
        'refreshed_cache_plugin_roots',
        '$userSkillNames = @(Get-ProjectUserSkillNames)',
        'Assert-SuperpowersProjectLiveInstallInSync',
        'Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $userSkillsRootResolved -SkillNames $userSkillNames'
    )) {
        if (-not $syncText.Contains($needle)) { throw "sync-live.ps1 missing policy text: $needle" }
    }
    Add-Check -Name "sync policy text" -Ok $true -Reason "passed"

    $active = @(Get-ProjectActiveSkillNames -RepoRoot $repoRoot)
    $retired = @(Get-ProjectRetiredSkillNames)
    $intersection = @($active | Where-Object { $retired -contains $_ })
    if ($intersection.Count -ne 0) {
        throw "active skills must not be retired: $($intersection -join ', ')"
    }
    foreach ($ownedRetired in @("superpowers-project", "project-setup", "project-doctor", "workflow")) {
        if ($retired -notcontains $ownedRetired) { throw "retired registry missing owned skill: $ownedRetired" }
    }
    $sourceSkills = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "skills") -Directory | Select-Object -ExpandProperty Name | Sort-Object)
    $activeText = (($active | Sort-Object) -join "`n")
    $sourceText = ($sourceSkills -join "`n")
    if ($activeText -ne $sourceText) {
        throw "active skill registry must match skills directory"
    }
    Add-Check -Name "shared skill registry" -Ok $true -Reason "passed"

    $helperText = Get-Content -LiteralPath (Join-Path $repoRoot "scripts/lib/sync-tree.ps1") -Raw
    foreach ($needle in @('[string[]]$SkillNames = @()', 'missing selected skill source', '$sourceSkills = @($sourceSkills | Where-Object { $SkillNames -contains $_.Name })')) {
        if (-not $helperText.Contains($needle)) { throw "sync-tree.ps1 missing selected-copy support: $needle" }
    }
    Add-Check -Name "selected skill copy support" -Ok $true -Reason "passed"

    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("plugin-live-sync-" + [guid]::NewGuid().ToString("N"))
    try {
        $livePluginRoot = Join-Path $fixtureRoot "plugins\superpowers-project"
        $userSkillsRoot = Join-Path $fixtureRoot "user-skills"
        $marketplacePath = Join-Path $fixtureRoot "marketplace.json"
        New-Item -ItemType Directory -Path $livePluginRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $userSkillsRoot -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $repoRoot ".codex-plugin") -Destination (Join-Path $livePluginRoot ".codex-plugin") -Recurse
        if (Test-Path -LiteralPath (Join-Path $repoRoot "assets") -PathType Container) {
            Copy-Item -LiteralPath (Join-Path $repoRoot "assets") -Destination (Join-Path $livePluginRoot "assets") -Recurse
        }
        New-Item -ItemType Directory -Path (Join-Path $livePluginRoot "scripts") -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\get-agent-plugin-version.ps1") -Destination (Join-Path $livePluginRoot "scripts\get-agent-plugin-version.ps1")
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\validate-auto-mode-authorization.ps1") -Destination (Join-Path $livePluginRoot "scripts\validate-auto-mode-authorization.ps1")
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\lib") -Destination (Join-Path $livePluginRoot "scripts\lib") -Recurse
        Copy-SkillDirectories -SourceRoot (Join-Path $repoRoot "skills") -TargetRoot (Join-Path $livePluginRoot "skills")
        Copy-SkillDirectories -SourceRoot (Join-Path $repoRoot "skills") -TargetRoot $userSkillsRoot -SkillNames @(Get-ProjectUserSkillNames)

        [pscustomobject]@{
            name = "personal"
            interface = [pscustomobject]@{ displayName = "Personal" }
            plugins = @(
                [pscustomobject]@{
                    name = "superpowers-project"
                    source = [pscustomobject]@{ source = "local"; path = "./plugins/superpowers-project" }
                    policy = [pscustomobject]@{ installation = "AVAILABLE"; authentication = "ON_INSTALL" }
                    category = "Productivity"
                }
            )
        } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $marketplacePath -Encoding utf8NoBOM

        Add-Content -LiteralPath (Join-Path $livePluginRoot "skills\merge-changes\agents\openai.yaml") -Value "# fixture drift"
        Add-Content -LiteralPath (Join-Path $userSkillsRoot "advanced-user-input\SKILL.md") -Value "# fixture drift"
        Add-Content -LiteralPath (Join-Path $livePluginRoot "scripts\get-agent-plugin-version.ps1") -Value "# fixture drift"
        Add-Content -LiteralPath (Join-Path $livePluginRoot "scripts\validate-auto-mode-authorization.ps1") -Value "# fixture drift"

        $drift = @(Compare-SuperpowersProjectLiveInstall -SourceRoot $repoRoot -LivePluginRoot $livePluginRoot -UserSkillsRoot $userSkillsRoot -MarketplacePath $marketplacePath -RetiredLivePluginRoots @())
        $labels = @($drift | ForEach-Object { $_.label })
        if ($labels -notcontains "plugin skill merge-changes") { throw "live comparer missed merge-changes plugin drift: $($labels -join ', ')" }
        if ($labels -notcontains "user skill advanced-user-input") { throw "live comparer missed advanced-user-input user skill drift: $($labels -join ', ')" }
        if ($labels -notcontains "plugin version checker") { throw "live comparer missed version checker drift: $($labels -join ', ')" }
        if ($labels -notcontains "plugin Auto Mode validator") { throw "live comparer missed Auto Mode validator drift: $($labels -join ', ')" }
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
    Add-Check -Name "full live install comparer detects drift" -Ok $true -Reason "passed"

    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("plugin-cache-sync-" + [guid]::NewGuid().ToString("N"))
    try {
        $livePluginRoot = Join-Path $fixtureRoot "plugins\superpowers-project"
        $cacheRoot = Join-Path $fixtureRoot "cache"
        $cachedPluginRoot = Join-Path $cacheRoot "tanner-local\project\0.2.0+fixture"
        New-Item -ItemType Directory -Path $livePluginRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $cachedPluginRoot -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $repoRoot ".codex-plugin") -Destination (Join-Path $livePluginRoot ".codex-plugin") -Recurse
        Copy-Item -LiteralPath (Join-Path $repoRoot ".codex-plugin") -Destination (Join-Path $cachedPluginRoot ".codex-plugin") -Recurse
        if (Test-Path -LiteralPath (Join-Path $repoRoot "assets") -PathType Container) {
            Copy-Item -LiteralPath (Join-Path $repoRoot "assets") -Destination (Join-Path $livePluginRoot "assets") -Recurse
            Copy-Item -LiteralPath (Join-Path $repoRoot "assets") -Destination (Join-Path $cachedPluginRoot "assets") -Recurse
        }
        New-Item -ItemType Directory -Path (Join-Path $livePluginRoot "scripts") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $cachedPluginRoot "scripts") -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\get-agent-plugin-version.ps1") -Destination (Join-Path $livePluginRoot "scripts\get-agent-plugin-version.ps1")
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\get-agent-plugin-version.ps1") -Destination (Join-Path $cachedPluginRoot "scripts\get-agent-plugin-version.ps1")
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\validate-auto-mode-authorization.ps1") -Destination (Join-Path $livePluginRoot "scripts\validate-auto-mode-authorization.ps1")
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\validate-auto-mode-authorization.ps1") -Destination (Join-Path $cachedPluginRoot "scripts\validate-auto-mode-authorization.ps1")
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\lib") -Destination (Join-Path $livePluginRoot "scripts\lib") -Recurse
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\lib") -Destination (Join-Path $cachedPluginRoot "scripts\lib") -Recurse
        Copy-SkillDirectories -SourceRoot (Join-Path $repoRoot "skills") -TargetRoot (Join-Path $livePluginRoot "skills")
        Copy-SkillDirectories -SourceRoot (Join-Path $repoRoot "skills") -TargetRoot (Join-Path $cachedPluginRoot "skills")
        Add-Content -LiteralPath (Join-Path $cachedPluginRoot "skills\brainstorm-spec\SKILL.md") -Value "# fixture cache drift"

        $staleRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\get-agent-plugin-version.ps1") `
            -RepoRoot $repoRoot `
            -LivePluginRoot $livePluginRoot `
            -CacheRoot $cacheRoot `
            -ObservedPluginRoot $cachedPluginRoot `
            -RequireCurrent 2>&1
        if ($LASTEXITCODE -eq 0) { throw "stale cached observed plugin should fail before refresh: $($staleRaw | Out-String)" }

        $refreshed = @(Sync-ProjectPluginCacheCandidates -SourceRoot $repoRoot -CacheRoot $cacheRoot)
        if ($refreshed.Count -ne 1) { throw "expected one refreshed cache root, got $($refreshed.Count)" }
        if ([IO.Path]::GetFullPath($refreshed[0].path) -ne [IO.Path]::GetFullPath($cachedPluginRoot)) {
            throw "refreshed wrong cache root: $($refreshed[0].path)"
        }

        $freshRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\get-agent-plugin-version.ps1") `
            -RepoRoot $repoRoot `
            -LivePluginRoot $livePluginRoot `
            -CacheRoot $cacheRoot `
            -ObservedPluginRoot $cachedPluginRoot `
            -RequireCurrent 2>&1
        $fresh = (($freshRaw | Out-String).Trim() | ConvertFrom-Json)
        if ($LASTEXITCODE -ne 0 -or $fresh.ok -ne $true -or $fresh.observed.matches_source -ne $true) {
            throw "refreshed cached observed plugin should pass: $($freshRaw | Out-String)"
        }
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
    Add-Check -Name "cache candidate refresh updates observed threads" -Ok $true -Reason "passed"

    [pscustomobject]@{ ok = $true; phase = "plugin-only-live-sync"; checks = $checks } | ConvertTo-Json -Depth 8
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "plugin-only-live-sync"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
