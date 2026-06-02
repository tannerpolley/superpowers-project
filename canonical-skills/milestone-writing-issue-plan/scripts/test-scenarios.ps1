[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$pluginWrapperFile = Join-Path $env:USERPROFILE "plugins\milestones\skills\milestone-writing-issue-plan\SKILL.md"

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        [pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }
    } catch {
        [pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -notmatch $Pattern) { throw $Message }
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Match $text "(?s)^---\s*name:\s*milestone-writing-issue-plan\s*description:\s*Use when" "missing valid frontmatter"
        Assert-Contains $text "# Milestone Writing Issue Plan" "missing skill title"
        Assert-Contains $text 'Milestones-native adaptation of `superpowers:writing-plans`' "missing writing-plans adaptation"
    }
    Invoke-Scenario "destination policy is milestone issue files only" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md" "missing known issue-number path"
        Assert-Contains $text "docs/milestones/<milestone-folder>/issues/<slug>.md" "missing pre-issue-number path"
        Assert-Contains $text 'Never write Milestones issue plans to `docs/superpowers/plans`' "missing superpowers plans ban"
        Assert-Contains $text "docs/milestones/<milestone-folder>/plans" "missing milestone plans ban"
    }
    Invoke-Scenario "required intake is explicit" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "GitHub issue URL",
            "Issue title",
            "Issue type",
            "Milestone title and milestone folder",
            "Acceptance criteria",
            "Non-goals",
            "Proof oracle",
            'Candidate files, or the explicit statement `candidate files unknown`'
        )) {
            Assert-Contains $text $needle "missing required intake: $needle"
        }
    }
    Invoke-Scenario "writing-plans discipline is preserved" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "**Goal:**",
            "**Architecture:**",
            "**Tech Stack:**",
            "- [ ]",
            "exact files",
            "exact verification",
            "No Placeholders",
            "DRY and YAGNI"
        )) {
            Assert-Contains $text $needle "missing writing-plans discipline: $needle"
        }
    }
    Invoke-Scenario "sub-skill discipline is explicit" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "superpowers:test-driven-development" "missing TDD sub-skill"
        Assert-Contains $text "unless the user explicitly opts out" "missing explicit TDD opt-out rule"
        Assert-Contains $text "superpowers:systematic-debugging" "missing systematic debugging sub-skill"
        Assert-Contains $text "superpowers:verification-before-completion" "missing verification-before-completion sub-skill"
    }
    Invoke-Scenario "openai metadata exists and routes correctly" {
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "version: 1" "missing metadata version"
        Assert-Contains $text "milestone-writing-issue-plan:" "missing skill metadata key"
        Assert-Contains $text "GitHub issue URL" "missing metadata issue URL requirement"
        Assert-Contains $text "docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md" "missing metadata known issue path"
        Assert-Contains $text "docs/superpowers/plans" "missing metadata plans ban"
        Assert-Contains $text "Goal, Architecture, Tech Stack" "missing metadata plan header discipline"
        Assert-Contains $text "TDD for feature/bug plans unless explicit opt-out" "missing metadata TDD rule"
        Assert-Contains $text "systematic-debugging for debugging" "missing metadata debugging rule"
        Assert-Contains $text "verification-before-completion before completion" "missing metadata completion rule"
    }
    Invoke-Scenario "plugin wrapper points to canonical skill" {
        $text = Get-Content -LiteralPath $pluginWrapperFile -Raw
        Assert-Match $text "(?s)^---\s*name:\s*milestone-writing-issue-plan\s*description:" "missing wrapper frontmatter"
        Assert-Contains $text "namespace wrapper" "missing wrapper declaration"
        Assert-Contains $text "C:\Users\Tanner\.agents\skills\milestone-writing-issue-plan\SKILL.md" "missing canonical skill path"
        Assert-Contains $text "Follow that canonical skill exactly" "missing canonical follow rule"
        Assert-Contains $text "Treat this plugin wrapper as organization only" "missing no separate behavior rule"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
