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
    Invoke-Scenario "upstream brainstorming checklist gate is mandatory" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "## Upstream Brainstorming Checklist Gate",
            'The upstream `superpowers:brainstorming` checklist is mandatory',
            "MUST create checklist tasks",
            "complete them in order",
            "Explore project context",
            "Offer visual companion",
            "Ask clarifying questions one at a time",
            "Design 1",
            "Design 2",
            "2-3 approaches",
            "present design sections",
            "approval after each section",
            "architecture, components, data flow, error handling, and testing",
            "Write design doc",
            "Spec self-review",
            "User reviews written spec",
            'Transition only to `$superpowers-project:write-plan`',
            "Do NOT invoke implementation",
            'Auto Mode routing belongs to `$superpowers-project:initiate-workflow`'
        )) {
            Assert-Contains $text $needle "missing upstream brainstorming checklist gate in SKILL.md: $needle"
        }
        foreach ($needle in @(
            "Upstream Brainstorming Checklist Gate",
            "The upstream superpowers:brainstorming checklist is mandatory",
            "Design 1",
            "Design 2",
            "2-3 approaches",
            "approval after each section",
            "architecture, components, data flow, error handling, and testing",
            "User reviews written spec",
            "Auto Mode routing belongs to initiate-workflow"
        )) {
            Assert-Contains $metadata $needle "missing upstream brainstorming checklist gate in metadata: $needle"
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
            "artifact review gate",
            "what the result means for the next workflow step",
            "broader project context",
            "machine-readable artifacts",
            "project_brainstorm_next_step",
            "top-level continuation gate",
            "child routes",
            "loaded thread may still be using older skill text",
            "re-ask the missed native route",
            "stale-thread recovery",
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
            "artifact review gate",
            "what the result means for the next workflow step",
            "broader project context",
            "machine-readable artifacts",
            "Review First",
            "stop",
            "request_user_input",
            "start the selected next skill",
            "project_brainstorm_next_step",
            "Continue From Spec",
            "Revise / Review Brainstorm",
            "Manual Planning",
            "loaded thread may still be using older skill text",
            "re-ask the missed native route",
            "stale-thread recovery",
            "project_brainstorm_plan_route",
            "Create One Plan",
            "Revise Spec"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }
    Invoke-Scenario "brainstorm no longer owns Auto Mode authorization" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "project_brainstorm_start_route",
            "project_auto_mode_authorization",
            "Bounded Auto Merge",
            "Auto Mode authorization ledger",
            "validate-auto-mode-authorization.ps1",
            "authorize Auto Mode"
        )) {
            Assert-NotContains $text $needle "brainstorm SKILL.md must not own Auto Mode route: $needle"
            Assert-NotContains $metadata $needle "brainstorm metadata must not own Auto Mode route: $needle"
        }
        Assert-Contains $text 'Auto Mode routing belongs to `$superpowers-project:initiate-workflow`' "brainstorm must point Auto Mode ownership at initiate-workflow"
        Assert-Contains $metadata "Auto Mode routing belongs to initiate-workflow" "metadata must point Auto Mode ownership at initiate-workflow"
    }

    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        $globalPolicyNeedles = @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )
        foreach ($needle in $globalPolicyNeedles) {
            if ($text.Contains($needle)) { throw "SKILL.md duplicates helper-owned global policy instead of compact contract reference: $needle" }
            if ($metadata.Contains($needle)) { throw "metadata duplicates native continuation policy instead of compact contract reference: $needle" }
        }
        foreach ($needle in @(
            "skills/advanced-user-input/SKILL.md",
            "global native question geometry",
            "route-specific question IDs",
            "selected answers are executable routing"
        )) {
            if (-not $text.Contains($needle)) { throw "missing compact native continuation helper reference: $needle" }
        }
        foreach ($needle in @(
            "docs/superpowers/workflow-contract.yml",
            "project_brainstorm_next_step",
            "top-level continuation gate",
            "child routes",
            "project_brainstorm_plan_route",
            "project_brainstorm_reiteration_route",
            "start the selected next skill"
        )) {
            if (-not $metadata.Contains($needle)) { throw "missing compact continuation metadata: $needle" }
        }

        $questionIds = [regex]::Matches($text, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $text.Length }
            $block = $text.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: terminal option: break the continuation loop.')) {
                throw "nested question $questionId must not repeat stale terminal label"
            }
        }

        if ($metadata.Contains("Right terminal label")) { throw "metadata must not use old Right terminal label wording" }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
