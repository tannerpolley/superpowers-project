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

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: write-plan" "missing skill name"
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
            "Auto Mode authorization ledger",
            "project_auto_mode_authorization",
            "the plugin-provided Auto Mode validator",
            "bounded-auto-merge",
            "recorded defaults",
            "stop outside policy",
            "Interview me relentlessly about every aspect of this plan",
            "superpowers:test-driven-development",
            "superpowers:systematic-debugging",
            "superpowers:verification-before-completion"
        )) {
            Assert-Contains $text $needle "missing write-plan contract: $needle"
        }
    }
    Invoke-Scenario "planning grill gate is mandatory" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Planning Grill Gate",
            "Before saving any new plan",
            "Interview me relentlessly about every aspect of this plan",
            "native UI hard gate",
            "Do not save the plan until material decisions have been answered",
            "If the planning agent realizes it skipped the grill after drafting a plan",
            "revise the saved plan before presenting it as ready",
            "branch strategy",
            "publish behavior",
            "live mutation"
        )) {
            Assert-Contains $text $needle "missing planning grill gate contract: $needle"
        }
    }
    Invoke-Scenario "test-complete and metrics gate is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Test-Complete And Metrics Gate",
            "what counts as test complete",
            "what proof demonstrates that status",
            "what metrics define pass versus fail",
            "edge-case thresholds",
            "scientific or engineering-oriented",
            "numerical metrics",
            "thresholds",
            "tolerances",
            "units",
            "validation coverage",
            "explicitly marked not applicable with a clear reason"
        )) {
            Assert-Contains $text $needle "missing test-complete or metrics contract: $needle"
        }
    }
    Invoke-Scenario "flat canonical plan root contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "flat canonical roots",
            "spec -> plan -> issue",
            "plans include creation date and milestone identity where applicable",
            "docs/superpowers/plans/<yyyy-mm-dd>-<milestone-or-category>-<slug>-plan.md",
            "link one or more loose specs or a raw approved idea",
            "Milestone pages are index views",
            "frontmatter plus milestone indexes",
            "nested canonical milestone artifact folders are drift"
        )) {
            Assert-Contains $text $needle "missing flat canonical plan root contract: $needle"
        }
    }
    Invoke-Scenario "old milestone issue target is retired" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-NotContains $text "docs/milestones/<milestone-folder>/issues" "old milestone issues path must not be active"
    }
    Invoke-Scenario "metadata routes to project plan" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "default_prompt:" "missing metadata default_prompt"
        Assert-Contains $text "docs/superpowers/plans" "missing metadata plan path"
        Assert-Contains $text "superpowers:writing-plans" "missing metadata Superpowers route"
        Assert-Contains $text "request_user_input" "missing metadata native question policy"
        Assert-Contains $text "flat canonical roots" "missing metadata flat root policy"
        Assert-Contains $text "plans include creation date and milestone identity where applicable" "missing metadata plan filename policy"
        foreach ($needle in @(
            "what counts as test complete",
            "what metrics define pass versus fail",
            "scientific or engineering-oriented",
            "numerical metrics",
            "thresholds",
            "tolerances",
            "units",
            "artifact review gate",
            "broader project context"
        )) {
            Assert-Contains $text $needle "missing metadata planning closeout contract: $needle"
        }
        Assert-Contains $text "project_plan_next_step" "missing continuation question id"
        Assert-Contains $text "start the selected next skill" "missing executable routing guidance"
        foreach ($needle in @("summarize", "Project Issue First", "Project Implement", "Use Ready Issue", "Review First", "Revise Plan")) {
            Assert-Contains $text $needle "missing metadata continuation route: $needle"
        }
    }
    Invoke-Scenario "native continuation gate is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Native Continuation Gate",
            "summarize",
            "artifact review gate",
            "Inventory every produced or materially changed artifact",
            "what counts as test complete",
            "scientific or engineering numerical metrics",
            "broader project context",
            "Review First",
            "stop",
            "request_user_input",
            "project_plan_next_step",
            "Project Issue First",
            "Project Implement",
            "Use Ready Issue",
            "Revise Plan",
            "start the selected next skill",
            "Do not only tell the user what to prompt next"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }
    Invoke-Scenario "native continuation routing respects native UI option limits" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "advanced-user-input",
            "sequential branching",
            "project_plan_next_step",
            "Continue Into Work",
            "Revise / Review Plan",
            "Stop",
            "project_plan_work_route",
            "Project Issue First",
            "Project Implement",
            "Use Ready Issue",
            "project_plan_issue_execution_route",
            "Resolve Issue",
            "Orchestrate Issues",
            "implement-plan",
            "project_plan_review_route",
            "Review First",
            "Revise Plan",
            "Do not show Continue children as peer top-level options",
            "Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires"
        )) {
            Assert-Contains $text $needle "missing nested continuation routing contract: $needle"
            Assert-Contains $metadata $needle "missing nested continuation routing metadata: $needle"
        }
        Assert-NotContains $metadata "with Project Issue First, Quick Apply, Review First, Revise Plan, and Stop options" "metadata must not specify an impossible five-option native question"
    }
    Invoke-Scenario "plan implementation route targets implement-plan directly" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            'Project Implement',
            '`$superpowers-project:implement-plan` using the saved plan path',
            'Project Issue First',
            '`$superpowers-project:create-issues` using the saved plan path',
            'Use Ready Issue',
            'compatible ready issue mirror already exists',
            'Recommend `Project Implement` for branch-backed non-issue implementation',
            'Recommend `Project Issue First` when the GitHub issue backbone is desired',
            'creating issue mirrors'
        )) {
            Assert-Contains $text $needle "missing direct implement route contract: $needle"
            Assert-Contains $metadata $needle "missing direct implement route metadata: $needle"
        }
    }
    Invoke-Scenario "removed local-main direct apply path is absent" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($removed in @(
            "Quick Apply",
            "project_quick_apply_approval",
            "Apply on Main",
            "Use Issue Flow",
            "Create Plan Artifact",
            "Execute Existing Work",
            "project_plan_artifact_route",
            "project_plan_implementation_route",
            "project_plan_execution_route",
            "validate-quick-apply.ps1",
            "clean synced ``main``"
        )) {
            Assert-NotContains $text $removed "write-plan skill must not advertise removed local-main path: $removed"
            Assert-NotContains $metadata $removed "write-plan metadata must not advertise removed local-main path: $removed"
        }
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $scriptRoot "validate-quick-apply.ps1") -PathType Leaf)) "removed local-main gate script must not remain in active skill"
    }

    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
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
