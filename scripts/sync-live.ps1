[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Validate,
    [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\superpowers-project"),
    [string]$UserSkillsRoot = (Join-Path $env:USERPROFILE ".agents\skills"),
    [string]$MarketplacePath = (Join-Path $env:USERPROFILE ".agents\plugins\marketplace.json")
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\sync-tree.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$sourcePluginManifest = Join-Path $repoRoot ".codex-plugin\plugin.json"
$sourceSkillsRoot = Join-Path $repoRoot "skills"
$sourceAssetsRoot = Join-Path $repoRoot "assets"
$livePluginRootResolved = [IO.Path]::GetFullPath($LivePluginRoot)
$userSkillsRootResolved = [IO.Path]::GetFullPath($UserSkillsRoot)
$marketplacePathResolved = [IO.Path]::GetFullPath($MarketplacePath)
$expectedLivePluginRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\superpowers-project"))
$expectedMarketplacePath = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE ".agents\plugins\marketplace.json"))
$retiredLivePluginRoots = @(
    [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\milestones")),
    [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\project"))
)
$expectedUserSkillsRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE ".agents\skills"))

if ($livePluginRootResolved -ne $expectedLivePluginRoot) {
    throw "LivePluginRoot must be the Superpowers Project live plugin path: $expectedLivePluginRoot"
}
if ($userSkillsRootResolved -ne $expectedUserSkillsRoot) {
    throw "UserSkillsRoot must be the user skills path: $expectedUserSkillsRoot"
}
if ($marketplacePathResolved -ne $expectedMarketplacePath) {
    throw "MarketplacePath must be the personal plugin marketplace path: $expectedMarketplacePath"
}
if (-not (Test-Path -LiteralPath $sourcePluginManifest -PathType Leaf)) {
    throw "missing source plugin manifest: $sourcePluginManifest"
}
if (-not (Test-Path -LiteralPath $sourceSkillsRoot -PathType Container)) {
    throw "missing source skills root: $sourceSkillsRoot"
}

$activeSkillNames = @(Get-SkillDirectoryNames -Root $sourceSkillsRoot)
$userSkillNames = @("advanced-user-input")
$retiredSkillNames = @(
    "using-milestones",
    "setup-project-milestones",
    "explore-ideas",
    "milestone-writing-issue-plan",
    "convert-idea-to-issue",
    "project-writing-plan",
    "plan-to-issue",
    "resolve-issue-with-goal",
    "milestones-doctor",
    "project-context",
    "superpowers-project",
    "project-setup",
    "project-orchestrate",
    "project-brainstorm",
    "project-plan",
    "project-issue",
    "project-resolve",
    "project-merge",
    "project-doctor",
    "workflow",
    "setup",
    "initiate-workflow",
    "setup-project",
    "orchestrate-issues",
    "brainstorm-spec",
    "write-plan",
    "implement-plan",
    "create-issues",
    "resolve-issue",
    "merge-changes",
    "align-project",
    "audit-project"
)

function Remove-RetiredLivePluginRoot {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }

    $pluginsRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins"))
    $resolved = [IO.Path]::GetFullPath($Path)
    if ($retiredLivePluginRoots -notcontains $resolved) {
        throw "refusing to remove unexpected retired live plugin path: $resolved"
    }
    if (-not $resolved.StartsWith($pluginsRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to remove retired live plugin path outside plugins root: $resolved"
    }

    $manifestPath = Join-Path $resolved ".codex-plugin\plugin.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "retired live plugin path exists but has no ownership manifest: $resolved"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.name -notin @("superpowers-project", "project")) {
        throw "retired live plugin path is not owned by Superpowers Project: $resolved"
    }

    Remove-Item -LiteralPath $resolved -Recurse -Force
    $true
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Sync-PersonalMarketplaceEntry {
    param([Parameter(Mandatory = $true)][string]$Path)

    $entry = [pscustomobject]@{
        name = "superpowers-project"
        source = [pscustomobject]@{
            source = "local"
            path = "./plugins/superpowers-project"
        }
        policy = [pscustomobject]@{
            installation = "AVAILABLE"
            authentication = "ON_INSTALL"
        }
        category = "Productivity"
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $marketplace = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $marketplace -or -not ($marketplace -is [psobject])) {
            throw "marketplace.json must contain a JSON object"
        }
    } else {
        $marketplace = [pscustomobject]@{
            name = "personal"
            interface = [pscustomobject]@{ displayName = "Personal" }
            plugins = @()
        }
    }

    if (-not ($marketplace.name -is [string]) -or [string]::IsNullOrWhiteSpace($marketplace.name)) {
        throw "marketplace.json must contain a non-empty name"
    }
    if (-not $marketplace.interface) {
        Set-JsonProperty -Object $marketplace -Name "interface" -Value ([pscustomobject]@{ displayName = "Personal" })
    }
    if (-not ($marketplace.interface -is [psobject])) {
        throw "marketplace.json interface must be an object"
    }
    if (-not $marketplace.plugins) {
        Set-JsonProperty -Object $marketplace -Name "plugins" -Value @()
    }
    if (-not ($marketplace.plugins -is [array])) {
        throw "marketplace.json plugins must be an array"
    }

    $retiredMarketplaceNames = @("milestones", "project")
    $plugins = @($marketplace.plugins | Where-Object {
        $_.name -ne "superpowers-project" -and $retiredMarketplaceNames -notcontains $_.name
    })
    Set-JsonProperty -Object $marketplace -Name "plugins" -Value @($plugins + $entry)

    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $marketplace | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8

    [pscustomobject]@{
        marketplace_path = $Path
        marketplace_name = $marketplace.name
        plugin_name = "superpowers-project"
        source_path = "./plugins/superpowers-project"
    }
}

if ($Validate) {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate.ps1")
    if ($LASTEXITCODE -ne 0) { throw "validation failed before sync" }
}

$livePluginManifestDir = Join-Path $livePluginRootResolved ".codex-plugin"
$livePluginSkillsRoot = Join-Path $livePluginRootResolved "skills"
$livePluginAssetsRoot = Join-Path $livePluginRootResolved "assets"
New-Item -ItemType Directory -Path $livePluginManifestDir -Force | Out-Null
New-Item -ItemType Directory -Path $livePluginSkillsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $userSkillsRootResolved -Force | Out-Null

Copy-Item -LiteralPath $sourcePluginManifest -Destination (Join-Path $livePluginManifestDir "plugin.json") -Force

Assert-ChildDirectory -Parent $livePluginRootResolved -Child $livePluginAssetsRoot
if (Test-Path -LiteralPath $sourceAssetsRoot -PathType Container) {
    if (Test-Path -LiteralPath $livePluginAssetsRoot -PathType Container) {
        Remove-Item -LiteralPath $livePluginAssetsRoot -Recurse -Force
    }
    Copy-Item -LiteralPath $sourceAssetsRoot -Destination $livePluginAssetsRoot -Recurse
} elseif (Test-Path -LiteralPath $livePluginAssetsRoot -PathType Container) {
    Remove-Item -LiteralPath $livePluginAssetsRoot -Recurse -Force
}

Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $livePluginSkillsRoot
$removedPluginSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $livePluginSkillsRoot -ActiveSkillNames $activeSkillNames -RetiredSkillNames $retiredSkillNames)

Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $userSkillsRootResolved -SkillNames $userSkillNames
$removedUserSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $userSkillsRootResolved -ActiveSkillNames $userSkillNames -RetiredSkillNames $retiredSkillNames)

Assert-NoTreeDrift -SourceRoot (Split-Path $sourcePluginManifest -Parent) -TargetRoot $livePluginManifestDir -Label "plugin manifest"
if (Test-Path -LiteralPath $sourceAssetsRoot -PathType Container) {
    Assert-NoTreeDrift -SourceRoot $sourceAssetsRoot -TargetRoot $livePluginAssetsRoot -Label "plugin assets"
}
foreach ($skillName in $activeSkillNames) {
    Assert-NoTreeDrift -SourceRoot (Join-Path $sourceSkillsRoot $skillName) -TargetRoot (Join-Path $livePluginSkillsRoot $skillName) -Label "plugin skill $skillName"
}
foreach ($skillName in $userSkillNames) {
    Assert-NoTreeDrift -SourceRoot (Join-Path $sourceSkillsRoot $skillName) -TargetRoot (Join-Path $userSkillsRootResolved $skillName) -Label "user skill $skillName"
}

$removedRetiredLivePluginRoots = @($retiredLivePluginRoots | ForEach-Object { Remove-RetiredLivePluginRoot -Path $_ })
$marketplaceEntry = Sync-PersonalMarketplaceEntry -Path $marketplacePathResolved

$deployedPluginSkills = @($activeSkillNames | ForEach-Object {
    [pscustomobject]@{
        skill = $_
        plugin_target = Join-Path $livePluginSkillsRoot $_
    }
})
$deployedUserSkills = @($userSkillNames | ForEach-Object {
    [pscustomobject]@{
        skill = $_
        user_skill_target = Join-Path $userSkillsRootResolved $_
    }
})

[pscustomobject]@{
    ok = $true
    source = $repoRoot
    live_plugin_root = $livePluginRootResolved
    user_skills_root = $userSkillsRootResolved
    marketplace = $marketplaceEntry
    assets_target = if (Test-Path -LiteralPath $livePluginAssetsRoot -PathType Container) { $livePluginAssetsRoot } else { $null }
    deployed_plugin_skills = $deployedPluginSkills
    deployed_user_skills = $deployedUserSkills
    removed_plugin_skills = $removedPluginSkills
    removed_user_skills = $removedUserSkills
    retired_live_plugin_roots = $retiredLivePluginRoots
    removed_retired_live_plugin_roots = $removedRetiredLivePluginRoots
} | ConvertTo-Json -Depth 8
