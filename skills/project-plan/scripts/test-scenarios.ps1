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
        Assert-Contains $text "name: project-plan" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Plan" "missing skill title"
    }
    Invoke-Scenario "superpowers writing contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "superpowers:writing-plans",
            "docs/superpowers/plans",
            "docs/superpowers/specs",
            "docs/superpowers/issues",
            "request_user_input",
            "Interview me relentlessly about every aspect of this plan",
            "superpowers:test-driven-development",
            "superpowers:systematic-debugging",
            "superpowers:verification-before-completion"
        )) {
            Assert-Contains $text $needle "missing project-plan contract: $needle"
        }
    }
    Invoke-Scenario "old milestone issue target is retired" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-NotContains $text "docs/milestones/<milestone-folder>/issues" "old milestone issues path must not be active"
    }
    Invoke-Scenario "metadata routes to project plan" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "project-plan:" "missing metadata key"
        Assert-Contains $text "docs/superpowers/plans" "missing metadata plan path"
        Assert-Contains $text "superpowers:writing-plans" "missing metadata Superpowers route"
        Assert-Contains $text "request_user_input" "missing metadata native question policy"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
