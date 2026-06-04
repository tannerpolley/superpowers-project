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
        Assert-Contains $text "project_plan_next_step" "missing continuation question id"
        Assert-Contains $text "start the selected next skill" "missing executable routing guidance"
        foreach ($needle in @("summarize", "Create Work Artifact", "Create Issue", "Plan Implementation", "Review First", "Revise Plan")) {
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
            "project_plan_next_step",
            "Create Issue",
            "Plan Implementation",
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
            "Stop / Done",
            "project_plan_work_route",
            "Create Work Artifact",
            "Execute Existing Work",
            "project_plan_artifact_route",
            "Create Issue",
            "Plan Implementation",
            "project_plan_implementation_route",
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
            'continue to `$project:implement-plan` using the saved plan path',
            'Project Issue First',
            'continue to `$project:create-issues` using the saved plan path',
            'Recommend `Project Implement` for branch-backed non-issue implementation',
            'Recommend `Project Issue First` when the GitHub issue backbone is desired',
            'does not create issue mirrors'
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
