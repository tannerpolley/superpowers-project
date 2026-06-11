[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SkillName,
    [string]$ExpectedQuestionId,
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\superpowers-project"),
    [string]$UserSkillsRoot = (Join-Path $env:USERPROFILE ".agents\skills")
)

$ErrorActionPreference = "Stop"

function Test-TextNeedle {
    param([string]$Path, [string]$Needle)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    (Get-Content -LiteralPath $Path -Raw).Contains($Needle)
}

function New-SurfaceEvidence {
    param([string]$Name, [string]$Path, [string[]]$Needles)
    $exists = -not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path -PathType Leaf)
    $missing = @()
    if ($exists) {
        $text = Get-Content -LiteralPath $Path -Raw
        foreach ($needle in $Needles) {
            if (-not $text.Contains($needle)) { $missing += $needle }
        }
    } else {
        $missing = @($Needles)
    }
    [pscustomobject]@{
        name = $Name
        path = $Path
        exists = $exists
        missing = $missing
    }
}

try {
    . (Join-Path $RepoRoot "scripts\lib\project-skills.ps1")
    $activeSkillNames = @(Get-ProjectActiveSkillNames -RepoRoot $RepoRoot)
    $userSkillNames = @(Get-ProjectUserSkillNames)
    if ($activeSkillNames -notcontains $SkillName -and $userSkillNames -notcontains $SkillName) {
        throw "skill is not owned by Superpowers Project: $SkillName"
    }

    $canonicalNamespace = Get-ProjectCanonicalPromptNamespace
    $needles = @(
        "name: $SkillName",
        $canonicalNamespace,
        "Native"
    )
    if (-not [string]::IsNullOrWhiteSpace($ExpectedQuestionId)) {
        $needles += $ExpectedQuestionId
    }

    $sourceSkillPath = Join-Path $RepoRoot "skills\$SkillName\SKILL.md"
    $sourceMetadataPath = Join-Path $RepoRoot "skills\$SkillName\agents\openai.yaml"
    $liveSkillPath = Join-Path $LivePluginRoot "skills\$SkillName\SKILL.md"
    $liveMetadataPath = Join-Path $LivePluginRoot "skills\$SkillName\agents\openai.yaml"
    $userSkillPath = Join-Path $UserSkillsRoot "$SkillName\SKILL.md"

    $surfaces = @(
        (New-SurfaceEvidence -Name "source-skill" -Path $sourceSkillPath -Needles $needles),
        (New-SurfaceEvidence -Name "source-metadata" -Path $sourceMetadataPath -Needles @($canonicalNamespace)),
        (New-SurfaceEvidence -Name "live-skill" -Path $liveSkillPath -Needles $needles),
        (New-SurfaceEvidence -Name "live-metadata" -Path $liveMetadataPath -Needles @($canonicalNamespace)),
        (New-SurfaceEvidence -Name "user-skill" -Path $userSkillPath -Needles @("name: $SkillName"))
    )

    $sourceMissing = @($surfaces | Where-Object { $_.name -like "source*" } | ForEach-Object { $_.missing })
    $liveMissing = @($surfaces | Where-Object { $_.name -like "live*" -and $_.exists } | ForEach-Object { $_.missing })
    $staleIndicators = @()
    foreach ($surface in $surfaces) {
        if ($surface.exists -and @($surface.missing).Count -gt 0) {
            $staleIndicators += "$($surface.name) missing $(@($surface.missing) -join ', ')"
        }
    }
    $ok = ($sourceMissing.Count -eq 0 -and $liveMissing.Count -eq 0)
    $recovery = if ($ok) {
        "Source and checked live surfaces contain expected contract markers."
    } else {
        "Warn that the loaded thread may be stale, name the missed gate, re-ask the native gate, and continue from the corrected route. Run scripts/sync-live.ps1 -Validate when live drift is reported."
    }

    [pscustomobject]@{
        ok = $ok
        phase = "stale-skill-contract"
        skill = $SkillName
        expected_question_id = $ExpectedQuestionId
        canonical_namespace = $canonicalNamespace
        surfaces = $surfaces
        stale_indicators = $staleIndicators
        recommended_recovery = $recovery
    } | ConvertTo-Json -Depth 16
    if (-not $ok) { exit 1 }
} catch {
    [pscustomobject]@{
        ok = $false
        phase = "stale-skill-contract"
        skill = $SkillName
        reason = $_.Exception.Message
    } | ConvertTo-Json -Depth 8
    exit 1
}
