[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot "..\..")).Path
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$pluginWrapperFile = Join-Path $repoRoot "skills\project-doctor\SKILL.md"

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        [pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }
    } catch {
        [pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }
    }
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw $Message }
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: project-doctor" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Doctor" "missing title"
    }
    Invoke-Scenario "audit surface contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "docs/superpowers/PROJECT_CONTEXT.md",
            "docs/superpowers/milestones",
            "docs/superpowers/specs",
            "docs/superpowers/plans",
            "docs/superpowers/issues",
            "GitHub issue mirror fields",
            "GitHub milestone linkage",
            "label vocabulary",
            "retired docs/milestones canonical usage",
            "live plugin sync drift"
        )) {
            Assert-Contains $text $needle "missing doctor audit contract: $needle"
        }
    }
    Invoke-Scenario "report-first and drift categories are present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @("report-first", "no mutation without user approval", "blocking", "repairable", "informational", "healthy", "migration report", "goal execution checks")) {
            Assert-Contains $text $needle "missing report/drift contract: $needle"
        }
    }
    Invoke-Scenario "metadata and wrapper are present" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        if (-not (Test-Path -LiteralPath $pluginWrapperFile -PathType Leaf)) { throw "missing plugin wrapper" }
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        $wrapper = Get-Content -LiteralPath $pluginWrapperFile -Raw
        Assert-Contains $metadata "project-doctor:" "missing metadata key"
        Assert-Contains $metadata "docs/superpowers/PROJECT_CONTEXT.md" "missing metadata project context path"
        Assert-Contains $metadata "live plugin sync drift" "missing metadata live sync drift"
        Assert-Contains $wrapper "name: project-doctor" "missing wrapper name"
        Assert-Contains $wrapper "C:\Users\Tanner\.agents\skills\project-doctor\SKILL.md" "missing deployed path"
        Assert-Contains $wrapper "namespace wrapper" "missing wrapper declaration"
        Assert-Contains $wrapper "Follow that skill exactly." "missing follow instruction"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
