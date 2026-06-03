[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Validate,
    [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\milestones"),
    [string]$UserSkillsRoot = (Join-Path $env:USERPROFILE ".agents\skills")
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\sync-tree.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$sourcePluginManifest = Join-Path $repoRoot ".codex-plugin\plugin.json"
$sourceSkillsRoot = Join-Path $repoRoot "skills"
$livePluginRootResolved = [IO.Path]::GetFullPath($LivePluginRoot)
$userSkillsRootResolved = [IO.Path]::GetFullPath($UserSkillsRoot)
$expectedLivePluginRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\milestones"))
$expectedUserSkillsRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE ".agents\skills"))

if ($livePluginRootResolved -ne $expectedLivePluginRoot) {
    throw "LivePluginRoot must be the Milestones live plugin path: $expectedLivePluginRoot"
}
if ($userSkillsRootResolved -ne $expectedUserSkillsRoot) {
    throw "UserSkillsRoot must be the user skills path: $expectedUserSkillsRoot"
}
if (-not (Test-Path -LiteralPath $sourcePluginManifest -PathType Leaf)) {
    throw "missing source plugin manifest: $sourcePluginManifest"
}
if (-not (Test-Path -LiteralPath $sourceSkillsRoot -PathType Container)) {
    throw "missing source skills root: $sourceSkillsRoot"
}

$activeSkillNames = @(Get-SkillDirectoryNames -Root $sourceSkillsRoot)
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
    "project-context"
)

if ($Validate) {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate.ps1")
    if ($LASTEXITCODE -ne 0) { throw "validation failed before sync" }
}

$livePluginManifestDir = Join-Path $livePluginRootResolved ".codex-plugin"
$livePluginSkillsRoot = Join-Path $livePluginRootResolved "skills"
New-Item -ItemType Directory -Path $livePluginManifestDir -Force | Out-Null
New-Item -ItemType Directory -Path $livePluginSkillsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $userSkillsRootResolved -Force | Out-Null

Copy-Item -LiteralPath $sourcePluginManifest -Destination (Join-Path $livePluginManifestDir "plugin.json") -Force

Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $livePluginSkillsRoot
$removedPluginSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $livePluginSkillsRoot -ActiveSkillNames $activeSkillNames -RetiredSkillNames $retiredSkillNames)

Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $userSkillsRootResolved
$removedUserSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $userSkillsRootResolved -ActiveSkillNames $activeSkillNames -RetiredSkillNames $retiredSkillNames)

Assert-NoTreeDrift -SourceRoot (Split-Path $sourcePluginManifest -Parent) -TargetRoot $livePluginManifestDir -Label "plugin manifest"
foreach ($skillName in $activeSkillNames) {
    Assert-NoTreeDrift -SourceRoot (Join-Path $sourceSkillsRoot $skillName) -TargetRoot (Join-Path $livePluginSkillsRoot $skillName) -Label "plugin skill $skillName"
}
foreach ($skillName in $activeSkillNames) {
    Assert-NoTreeDrift -SourceRoot (Join-Path $sourceSkillsRoot $skillName) -TargetRoot (Join-Path $userSkillsRootResolved $skillName) -Label "user skill $skillName"
}

$deployedPluginSkills = @($activeSkillNames | ForEach-Object {
    [pscustomobject]@{
        skill = $_
        plugin_target = Join-Path $livePluginSkillsRoot $_
    }
})
$deployedUserSkills = @($activeSkillNames | ForEach-Object {
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
    deployed_plugin_skills = $deployedPluginSkills
    deployed_user_skills = $deployedUserSkills
    removed_plugin_skills = $removedPluginSkills
    removed_user_skills = $removedUserSkills
} | ConvertTo-Json -Depth 8
