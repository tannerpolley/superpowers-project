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
    $syncText = Get-Content -LiteralPath $syncPath -Raw
    foreach ($needle in @(
        'plugins\project',
        'assets',
        '$userSkillNames = @("advanced-user-input")',
        'Assert-NoTreeDrift -SourceRoot $sourceAssetsRoot -TargetRoot $livePluginAssetsRoot -Label "plugin assets"',
        'Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $userSkillsRootResolved -SkillNames $userSkillNames',
        'Assert-NoTreeDrift -SourceRoot (Join-Path $sourceSkillsRoot $skillName) -TargetRoot (Join-Path $userSkillsRootResolved $skillName) -Label "user skill $skillName"',
        '"superpowers-project"',
        '"project-setup"',
        '"project-doctor"',
        '"workflow"',
        '"initiate-workflow"',
        '"setup-project"',
        '"merge-changes"'
    )) {
        if (-not $syncText.Contains($needle)) { throw "sync-live.ps1 missing policy text: $needle" }
    }
    Add-Check -Name "sync policy text" -Ok $true -Reason "passed"

    $helperText = Get-Content -LiteralPath (Join-Path $repoRoot "scripts/lib/sync-tree.ps1") -Raw
    foreach ($needle in @('[string[]]$SkillNames = @()', 'missing selected skill source', '$sourceSkills = @($sourceSkills | Where-Object { $SkillNames -contains $_.Name })')) {
        if (-not $helperText.Contains($needle)) { throw "sync-tree.ps1 missing selected-copy support: $needle" }
    }
    Add-Check -Name "selected skill copy support" -Ok $true -Reason "passed"

    [pscustomobject]@{ ok = $true; phase = "plugin-only-live-sync"; checks = $checks } | ConvertTo-Json -Depth 8
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "plugin-only-live-sync"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
