[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"

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

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw $Message }
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: project-brainstorm" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Brainstorm" "missing skill title"
    }
    Invoke-Scenario "superpowers and grilling contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "superpowers:brainstorming",
            "Interview me relentlessly about every aspect of this plan",
            "request_user_input",
            "Default mode",
            "docs/superpowers/specs",
            "docs/superpowers/PROJECT_CONTEXT.md",
            "docs/superpowers/milestones",
            "grill-with-docs",
            "to-prd",
            "improve-codebase-architecture"
        )) {
            Assert-Contains $text $needle "missing project-brainstorm contract: $needle"
        }
    }
    Invoke-Scenario "old milestone idea target is retired" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-NotContains $text "docs/milestones/<milestone-folder>/ideas" "old milestone ideas path must not be active"
    }
    Invoke-Scenario "metadata routes to project brainstorm" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "project-brainstorm:" "missing metadata key"
        Assert-Contains $text "docs/superpowers/specs" "missing metadata spec path"
        Assert-Contains $text "request_user_input" "missing metadata native question policy"
        Assert-Contains $text "superpowers:brainstorming" "missing metadata Superpowers route"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
