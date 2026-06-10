[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$checks = [System.Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot "lib\project-skills.ps1")

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Reason)
    if (-not $Text.Contains($Needle)) { throw $Reason }
}

try {
    $targetSkills = @(Get-ProjectActiveSkillNames -RepoRoot $repoRoot | Sort-Object)
    $sourceSkills = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "skills") -Directory | Select-Object -ExpandProperty Name | Sort-Object)
    $missing = @($targetSkills | Where-Object { $sourceSkills -notcontains $_ })
    $extra = @($sourceSkills | Where-Object { $targetSkills -notcontains $_ })
    if ($missing.Count -gt 0) { throw "missing migrated skill(s): $($missing -join ', ')" }
    if ($extra.Count -gt 0) { throw "unexpected skill(s): $($extra -join ', ')" }
    Add-Check -Name "target skill set" -Ok $true -Reason "passed"

    $manifest = Get-Content -LiteralPath (Join-Path $repoRoot ".codex-plugin/plugin.json") -Raw | ConvertFrom-Json
    if ([string]$manifest.name -ne "superpowers-project") { throw "plugin manifest name must be superpowers-project" }
    if ([string]$manifest.interface.displayName -ne "Superpowers Project") { throw "display name must remain Superpowers Project" }
    Add-Check -Name "plugin namespace" -Ok $true -Reason "passed"

    foreach ($skill in $targetSkills) {
        $skillPath = Join-Path $repoRoot "skills/$skill/SKILL.md"
        $text = Get-Content -LiteralPath $skillPath -Raw
        Assert-Contains -Text $text -Needle "name: $skill" -Reason "frontmatter mismatch for $skill"
    }
    Add-Check -Name "frontmatter names" -Ok $true -Reason "passed"

    $readme = Get-Content -LiteralPath (Join-Path $repoRoot "README.md") -Raw
    Assert-Contains -Text $readme -Needle 'prompt surface is `$superpowers-project:*`' -Reason "README must declare canonical prompt surface"
    foreach ($needle in @('$superpowers-project:initiate-workflow', '$superpowers-project:setup-project', '$superpowers-project:write-plan', '$superpowers-project:create-issues', '$superpowers-project:resolve-issue', '$superpowers-project:orchestrate-issues', '$superpowers-project:merge-changes', '$superpowers-project:audit-project', '$superpowers-project:align-project')) {
        Assert-Contains -Text $readme -Needle $needle -Reason "README missing migrated prompt: $needle"
    }
    Add-Check -Name "README prompt surface" -Ok $true -Reason "passed"

    foreach ($prompt in @($manifest.interface.defaultPrompt)) {
        if ($prompt -match '(?<!\$)superpowers-project:') {
            throw "manifest prompt must use canonical `$superpowers-project:* spelling: $prompt"
        }
        Assert-Contains -Text $prompt -Needle '$superpowers-project:' -Reason "manifest prompt missing canonical namespace: $prompt"
    }
    Add-Check -Name "manifest prompt surface" -Ok $true -Reason "passed"

    $activeSurfacePaths = @(
        (Join-Path $repoRoot "README.md"),
        (Join-Path $repoRoot ".codex-plugin/plugin.json")
    )
    $activeSurfacePaths += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs/superpowers/issues") -Recurse -File | Select-Object -ExpandProperty FullName)
    $activeSurfacePaths += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "skills") -Recurse -File -Include "SKILL.md", "openai.yaml" | Select-Object -ExpandProperty FullName)
    foreach ($path in $activeSurfacePaths) {
        $text = Get-Content -LiteralPath $path -Raw
        if ($text.Contains('$project:')) {
            throw "stale `$project:* namespace remains in active surface: $path"
        }
    }
    Add-Check -Name "stale project namespace absent" -Ok $true -Reason "passed"

    $retiredDirs = @("superpowers-project", "project-setup", "project-brainstorm", "project-plan", "project-issue", "project-resolve", "project-orchestrate", "project-merge", "project-doctor")
    foreach ($dir in $retiredDirs) {
        if (Test-Path -LiteralPath (Join-Path $repoRoot "skills/$dir") -PathType Container) {
            throw "retired source skill directory remains: $dir"
        }
    }
    Add-Check -Name "retired source directories absent" -Ok $true -Reason "passed"

    [pscustomobject]@{ ok = $true; phase = "project-namespace-migration"; checks = $checks } | ConvertTo-Json -Depth 8
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "project-namespace-migration"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
