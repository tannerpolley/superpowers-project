[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Validate,
    [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\milestones"),
    [string]$UserSkillsRoot = (Join-Path $env:USERPROFILE ".agents\skills")
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$sourcePluginManifest = Join-Path $repoRoot ".codex-plugin\plugin.json"
$sourceSkillsRoot = Join-Path $repoRoot "canonical-skills"
$sourcePluginSkillsRoot = Join-Path $repoRoot "skills"
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
    throw "missing canonical source skills root: $sourceSkillsRoot"
}
if (-not (Test-Path -LiteralPath $sourcePluginSkillsRoot -PathType Container)) {
    throw "missing source plugin wrapper skills root: $sourcePluginSkillsRoot"
}

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

$deployedPluginSkills = [System.Collections.Generic.List[object]]::new()
foreach ($sourcePluginSkill in (Get-ChildItem -LiteralPath $sourcePluginSkillsRoot -Directory | Sort-Object Name)) {
    $pluginTarget = Join-Path $livePluginSkillsRoot $sourcePluginSkill.Name
    $resolvedParent = [IO.Path]::GetFullPath((Split-Path $pluginTarget -Parent))
    if ($resolvedParent -ne $livePluginSkillsRoot) {
        throw "refusing to deploy outside approved plugin skills root: $pluginTarget"
    }
    if (Test-Path -LiteralPath $pluginTarget) {
        Remove-Item -LiteralPath $pluginTarget -Recurse -Force
    }
    Copy-Item -LiteralPath $sourcePluginSkill.FullName -Destination $pluginTarget -Recurse
    $deployedPluginSkills.Add([pscustomobject]@{
        skill = $sourcePluginSkill.Name
        plugin_target = $pluginTarget
    })
}

$deployedUserSkills = [System.Collections.Generic.List[object]]::new()
foreach ($sourceSkill in (Get-ChildItem -LiteralPath $sourceSkillsRoot -Directory | Sort-Object Name)) {
    $userSkillTarget = Join-Path $userSkillsRootResolved $sourceSkill.Name

    $resolvedParent = [IO.Path]::GetFullPath((Split-Path $userSkillTarget -Parent))
    if ($resolvedParent -ne $userSkillsRootResolved) {
        throw "refusing to deploy outside approved user skills root: $userSkillTarget"
    }
    if (Test-Path -LiteralPath $userSkillTarget) {
        Remove-Item -LiteralPath $userSkillTarget -Recurse -Force
    }
    Copy-Item -LiteralPath $sourceSkill.FullName -Destination $userSkillTarget -Recurse

    $deployedUserSkills.Add([pscustomobject]@{
        skill = $sourceSkill.Name
        user_skill_target = $userSkillTarget
    })
}

[pscustomobject]@{
    ok = $true
    source = $repoRoot
    live_plugin_root = $livePluginRootResolved
    user_skills_root = $userSkillsRootResolved
    deployed_plugin_skills = $deployedPluginSkills
    deployed_user_skills = $deployedUserSkills
} | ConvertTo-Json -Depth 8
