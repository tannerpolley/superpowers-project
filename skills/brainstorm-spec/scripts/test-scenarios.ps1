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
        Assert-Contains $text "name: brainstorm-spec" "missing skill name"
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
            Assert-Contains $text $needle "missing brainstorm-spec contract: $needle"
        }
    }
    Invoke-Scenario "loose spec flat root contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "flat canonical roots",
            "spec -> plan -> issue",
            "loose specs",
            "docs/superpowers/specs/<yyyy-mm-dd>-<slug>.md",
            "milestone identity is optional",
            "frontmatter plus milestone indexes",
            "Milestone pages are index views",
            "nested canonical milestone artifact folders are drift"
        )) {
            Assert-Contains $text $needle "missing loose spec flat root contract: $needle"
        }
    }
    Invoke-Scenario "native UI and grill pressure are mandatory for decisions" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "slightest hint of a shared decision",
            'Do not answer a brainstorming decision in prose when `request_user_input` is callable.',
            "inspect codebase and project context before asking",
            "report back with evidence gathered, decision points, and assumptions to remove",
            'Use the same grilling pressure as `$superpowers-project:brainstorm-spec` plus `grill-me`.'
        )) {
            Assert-Contains $text $needle "missing native UI/grill pressure contract: $needle"
        }
    }
    Invoke-Scenario "old milestone idea target is retired" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-NotContains $text "docs/milestones/<milestone-folder>/ideas" "old milestone ideas path must not be active"
    }
    Invoke-Scenario "metadata routes to project brainstorm" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "default_prompt:" "missing metadata default_prompt"
        Assert-Contains $text "docs/superpowers/specs" "missing metadata spec path"
        Assert-Contains $text "request_user_input" "missing metadata native question policy"
        Assert-Contains $text "superpowers:brainstorming" "missing metadata Superpowers route"
        Assert-Contains $text "flat canonical roots" "missing metadata flat root policy"
        Assert-Contains $text "loose specs" "missing metadata loose spec policy"
        foreach ($needle in @(
            "summarize",
            "project_brainstorm_next_step",
            "Continue From Spec",
            "Revise / Review Brainstorm",
            "Stop",
            "project_brainstorm_start_route",
            "Manual Planning",
            "Auto Mode",
            "project_auto_mode_authorization",
            "Bounded Auto Merge",
            "Auto Mode authorization ledger",
            "bounded-auto-merge",
            "recorded-defaults",
            "issue-backed-orchestrate-only",
            "the repo-root Auto Mode contract helper",
            "project_brainstorm_plan_route",
            "Create One Plan",
            "Multi-Spec Planning",
            "project_brainstorm_reiteration_route",
            "Revise Spec",
            "start the selected next skill"
        )) {
            Assert-Contains $text $needle "missing metadata continuation route: $needle"
        }
    }
    Invoke-Scenario "native continuation gate is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Native Continuation Gate",
            "summarize",
            "Review First",
            "stop",
            "request_user_input",
            "start the selected next skill",
            "project_brainstorm_next_step",
            "Continue From Spec",
            "Revise / Review Brainstorm",
            "project_brainstorm_start_route",
            "Manual Planning",
            "Auto Mode",
            "project_auto_mode_authorization",
            "Bounded Auto Merge",
            "project_brainstorm_plan_route",
            "Create One Plan",
            "Revise Spec"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }

    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "Nested Yes-route menus must not include Stop / Done",
            "Nested Revisit-route menus must not include Stop / Done",
            "Recommend Yes when at least one safe forward route exists",
            "Recommend No / Stop / Done only for explicit terminal, blocker, or user-requested stop states"
        )) {
            if (-not $text.Contains($needle)) { throw "missing native continuation policy in SKILL.md: $needle" }
            if (-not $metadata.Contains($needle)) { throw "missing native continuation policy in metadata: $needle" }
        }

        $questionIds = [regex]::Matches($text, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $text.Length }
            $block = $text.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: `Stop / Done`: break the continuation loop.')) {
                throw "nested question $questionId must not repeat Stop / Done"
            }
        }

        if ($metadata.Contains("Right Stop / Done")) { throw "metadata must not use old Right Stop / Done wording" }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
