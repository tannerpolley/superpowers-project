$ErrorActionPreference = "Stop"

if (-not (Get-Command Assert-ChildDirectory -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot "sync-tree.ps1")
}
if (-not (Get-Command Get-ProjectActiveSkillNames -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot "project-skills.ps1")
}

function Read-ProjectPluginManifest {
    param([Parameter(Mandatory = $true)][string]$PluginRoot)

    $manifestPath = Join-Path $PluginRoot ".codex-plugin\plugin.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
    Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
}

function Get-ProjectPluginCacheRoots {
    param(
        [string]$CacheRoot = (Join-Path $env:USERPROFILE ".codex\plugins\cache"),
        [string]$ExpectedManifestName = "superpowers-project"
    )

    if ([string]::IsNullOrWhiteSpace($CacheRoot) -or -not (Test-Path -LiteralPath $CacheRoot -PathType Container)) {
        return @()
    }

    $cacheRootResolved = [IO.Path]::GetFullPath($CacheRoot)
    $roots = [System.Collections.Generic.List[string]]::new()
    $manifestFiles = @(Get-ChildItem -LiteralPath $cacheRootResolved -Recurse -Filter "plugin.json" -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -match [regex]::Escape(".codex-plugin")
    })

    foreach ($file in $manifestFiles) {
        try {
            $pluginRoot = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $file.FullName)))
            Assert-ChildDirectory -Parent $cacheRootResolved -Child $pluginRoot

            $manifest = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            $relative = [IO.Path]::GetRelativePath($cacheRootResolved, $pluginRoot).Replace('\', '/')
            $manifestName = [string]$manifest.name
            $isLegacyLocalProjectCache = $manifestName -eq "project" -and $relative -match '(^|/)tanner-local/project/'
            $isLocalProjectCache = $manifestName -eq $ExpectedManifestName -and $relative -match '(^|/)tanner-local/(project|superpowers-project)/'

            if ($manifestName -eq $ExpectedManifestName -or $isLegacyLocalProjectCache -or $isLocalProjectCache) {
                $roots.Add($pluginRoot) | Out-Null
            }
        } catch {
            continue
        }
    }

    @($roots | Sort-Object -Unique)
}

function Copy-ProjectPluginRuntimeSurface {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot
    )

    $sourceRootResolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
    $targetRootResolved = [IO.Path]::GetFullPath($TargetRoot)
    $sourceManifest = Join-Path $sourceRootResolved ".codex-plugin\plugin.json"
    $sourceSkillsRoot = Join-Path $sourceRootResolved "skills"
    $sourceAssetsRoot = Join-Path $sourceRootResolved "assets"
    $sourceVersionChecker = Join-Path $sourceRootResolved "scripts\get-agent-plugin-version.ps1"
    $sourceAutoModeValidator = Join-Path $sourceRootResolved "scripts\validate-auto-mode-authorization.ps1"
    $sourcePlanTaskUseCasesValidator = Join-Path $sourceRootResolved "scripts\validate-plan-task-use-cases.ps1"
    $sourceScriptsLibRoot = Join-Path $sourceRootResolved "scripts\lib"

    foreach ($requiredPath in @($sourceManifest, $sourceSkillsRoot, $sourceVersionChecker, $sourceAutoModeValidator, $sourcePlanTaskUseCasesValidator, $sourceScriptsLibRoot)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "missing source runtime surface: $requiredPath"
        }
    }

    New-Item -ItemType Directory -Path $targetRootResolved -Force | Out-Null

    $targetManifestDir = Join-Path $targetRootResolved ".codex-plugin"
    $targetScriptsRoot = Join-Path $targetRootResolved "scripts"
    $targetScriptsLibRoot = Join-Path $targetRootResolved "scripts\lib"
    $targetAssetsRoot = Join-Path $targetRootResolved "assets"
    $targetSkillsRoot = Join-Path $targetRootResolved "skills"

    New-Item -ItemType Directory -Path $targetManifestDir -Force | Out-Null
    New-Item -ItemType Directory -Path $targetScriptsRoot -Force | Out-Null
    Copy-Item -LiteralPath $sourceManifest -Destination (Join-Path $targetManifestDir "plugin.json") -Force
    Copy-Item -LiteralPath $sourceVersionChecker -Destination (Join-Path $targetScriptsRoot "get-agent-plugin-version.ps1") -Force
    Copy-Item -LiteralPath $sourceAutoModeValidator -Destination (Join-Path $targetScriptsRoot "validate-auto-mode-authorization.ps1") -Force
    Copy-Item -LiteralPath $sourcePlanTaskUseCasesValidator -Destination (Join-Path $targetScriptsRoot "validate-plan-task-use-cases.ps1") -Force

    Assert-ChildDirectory -Parent $targetRootResolved -Child $targetScriptsLibRoot
    if (Test-Path -LiteralPath $targetScriptsLibRoot -PathType Container) {
        Remove-Item -LiteralPath $targetScriptsLibRoot -Recurse -Force
    }
    Copy-Item -LiteralPath $sourceScriptsLibRoot -Destination $targetScriptsLibRoot -Recurse

    Assert-ChildDirectory -Parent $targetRootResolved -Child $targetAssetsRoot
    if (Test-Path -LiteralPath $sourceAssetsRoot -PathType Container) {
        if (Test-Path -LiteralPath $targetAssetsRoot -PathType Container) {
            Remove-Item -LiteralPath $targetAssetsRoot -Recurse -Force
        }
        Copy-Item -LiteralPath $sourceAssetsRoot -Destination $targetAssetsRoot -Recurse
    } elseif (Test-Path -LiteralPath $targetAssetsRoot -PathType Container) {
        Remove-Item -LiteralPath $targetAssetsRoot -Recurse -Force
    }

    Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $targetSkillsRoot
    $removedSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $targetSkillsRoot -ActiveSkillNames @(Get-ProjectActiveSkillNames -RepoRoot $sourceRootResolved) -RetiredSkillNames @(Get-ProjectRetiredSkillNames))

    [pscustomobject]@{
        path = $targetRootResolved
        removed_stale_skill_directories = $removedSkills
    }
}

function Sync-ProjectPluginCacheCandidates {
    param(
        [string]$SourceRoot = (Resolve-ProjectPluginRoot),
        [string]$CacheRoot = (Join-Path $env:USERPROFILE ".codex\plugins\cache")
    )

    if ([string]::IsNullOrWhiteSpace($CacheRoot) -or -not (Test-Path -LiteralPath $CacheRoot -PathType Container)) {
        return @()
    }

    $sourceRootResolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
    $sourceManifest = Read-ProjectPluginManifest -PluginRoot $sourceRootResolved
    if ($null -eq $sourceManifest) { throw "source plugin manifest is missing" }

    $cacheRootResolved = [IO.Path]::GetFullPath($CacheRoot)
    $refreshed = [System.Collections.Generic.List[object]]::new()
    foreach ($cachePluginRoot in @(Get-ProjectPluginCacheRoots -CacheRoot $cacheRootResolved -ExpectedManifestName ([string]$sourceManifest.name))) {
        Assert-ChildDirectory -Parent $cacheRootResolved -Child $cachePluginRoot
        $before = Read-ProjectPluginManifest -PluginRoot $cachePluginRoot
        $result = Copy-ProjectPluginRuntimeSurface -SourceRoot $sourceRootResolved -TargetRoot $cachePluginRoot
        $refreshed.Add([pscustomobject]@{
            path = [string]$result.path
            manifest_name_before = if ($null -eq $before) { "" } else { [string]$before.name }
            manifest_version_before = if ($null -eq $before) { "" } else { [string]$before.version }
            removed_stale_skill_directories = $result.removed_stale_skill_directories
        }) | Out-Null
    }

    @($refreshed)
}
