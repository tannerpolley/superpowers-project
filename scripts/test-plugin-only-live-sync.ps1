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
    if (-not (Test-Path -LiteralPath $projectSkillsPath -PathType Leaf)) { throw "missing shared project skill registry: $projectSkillsPath" }
    if (-not (Test-Path -LiteralPath $liveInstallPath -PathType Leaf)) { throw "missing live install comparer: $liveInstallPath" }
    . $projectSkillsPath
    . $liveInstallPath

    $syncText = Get-Content -LiteralPath $syncPath -Raw
    foreach ($needle in @(
        'plugins\superpowers-project',
        'assets',
        'scripts\lib',
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

        $drift = @(Compare-SuperpowersProjectLiveInstall -SourceRoot $repoRoot -LivePluginRoot $livePluginRoot -UserSkillsRoot $userSkillsRoot -MarketplacePath $marketplacePath -RetiredLivePluginRoots @())
        $labels = @($drift | ForEach-Object { $_.label })
        if ($labels -notcontains "plugin skill merge-changes") { throw "live comparer missed merge-changes plugin drift: $($labels -join ', ')" }
        if ($labels -notcontains "user skill advanced-user-input") { throw "live comparer missed advanced-user-input user skill drift: $($labels -join ', ')" }
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
    Add-Check -Name "full live install comparer detects drift" -Ok $true -Reason "passed"

    [pscustomobject]@{ ok = $true; phase = "plugin-only-live-sync"; checks = $checks } | ConvertTo-Json -Depth 8
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "plugin-only-live-sync"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
