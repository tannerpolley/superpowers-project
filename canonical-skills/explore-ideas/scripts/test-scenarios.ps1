[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$skillFile = Join-Path $skillRoot "SKILL.md"
$openaiFile = Join-Path $skillRoot "agents\openai.yaml"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Name, [bool]$Passed, [string]$Reason)
    $results.Add([pscustomobject]@{
        name = $Name
        passed = $Passed
        reason = $Reason
    })
}

function Assert-Contains {
    param([string]$Text, [string]$Pattern, [string]$Reason)
    if ($Text -notmatch $Pattern) { throw $Reason }
}

function Assert-NotContains {
    param([string]$Text, [string]$Pattern, [string]$Reason)
    if ($Text -match $Pattern) { throw $Reason }
}

try {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    if (-not (Test-Path -LiteralPath $openaiFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $openaiFile -Raw

    try {
        Assert-Contains -Text $skill -Pattern "Run this skill in Default mode" -Reason "SKILL.md must require Default mode"
        Assert-Contains -Text $skill -Pattern "request_user_input" -Reason "SKILL.md must require request_user_input"
        Assert-Contains -Text $skill -Pattern "this skill requires native question UI" -Reason "SKILL.md must block when native question UI cannot be called"
        Assert-Contains -Text $skill -Pattern "If the thread is in Plan mode, stop" -Reason "SKILL.md must block Plan mode"
        Assert-Contains -Text $skill -Pattern "Implement Plan" -Reason "SKILL.md must mention avoiding Implement Plan"
        Add-Result -Name "mode and native UI contract present" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "mode and native UI contract present" -Passed $false -Reason $_.Exception.Message
    }

    try {
        foreach ($pattern in @("create a GitHub issue", "implementation branch", "GoalBuddy board", "native goal", "open PRs", "merge")) {
            Assert-Contains -Text $skill -Pattern $pattern -Reason "missing forbidden action: $pattern"
        }
        Add-Result -Name "execution actions forbidden" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "execution actions forbidden" -Passed $false -Reason $_.Exception.Message
    }

    try {
        Assert-Contains -Text $skill -Pattern "name: explore-ideas" -Reason "SKILL.md must use explore-ideas metadata name"
        Assert-Contains -Text $skill -Pattern "# Explore Ideas" -Reason "SKILL.md must use Explore Ideas heading"
        Assert-Contains -Text $skill -Pattern "Blocked by explore-ideas contract" -Reason "SKILL.md must use explore-ideas blocked response"
        Assert-Contains -Text $skill -Pattern "explore_ideas_brief" -Reason "missing explore_ideas_brief JSON handoff"
        Assert-Contains -Text $skill -Pattern "decision_inventory" -Reason "missing decision inventory"
        Assert-Contains -Text $skill -Pattern "question_log" -Reason "missing question log"
        Assert-Contains -Text $skill -Pattern "candidate_issue_slices" -Reason "missing candidate issue slices"
        Assert-Contains -Text $skill -Pattern "code_health_audit" -Reason "missing code health audit"
        Assert-Contains -Text $skill -Pattern "workflow_connections" -Reason "missing workflow connections"
        Add-Result -Name "brief handoff schema present" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "brief handoff schema present" -Passed $false -Reason $_.Exception.Message
    }

    try {
        foreach ($supportingSkill in @("inlined-docs-grilling", "grill-me", "diagnose", "improve-codebase-architecture", "superpowers:brainstorming")) {
            Assert-Contains -Text $skill -Pattern ([regex]::Escape($supportingSkill)) -Reason "missing supporting skill route: $supportingSkill"
        }
        Assert-Contains -Text $skill -Pattern "apply the docs-grilling behavior directly" -Reason "docs-grilling behavior must be inlined"
        Assert-Contains -Text $skill -Pattern "Treat .*grill-with-docs.* as source behavior to inline" -Reason "grill-with-docs must not be a nested dependency"
        Assert-Contains -Text $skill -Pattern "Adopt .*superpowers:brainstorming.* patterns" -Reason "Superpowers brainstorming patterns must be adopted"
        Add-Result -Name "supporting skill routing and inlined patterns present" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "supporting skill routing and inlined patterns present" -Passed $false -Reason $_.Exception.Message
    }

    try {
        Assert-Contains -Text $metadata -Pattern "explore-ideas" -Reason "openai metadata must use explore-ideas key/prompt"
        Assert-Contains -Text $metadata -Pattern "Default mode" -Reason "openai metadata must mention Default mode"
        Assert-Contains -Text $metadata -Pattern "request_user_input" -Reason "openai metadata must mention request_user_input"
        Assert-Contains -Text $metadata -Pattern "Inline docs-grilling behavior" -Reason "openai metadata must require inlined docs-grilling"
        Assert-Contains -Text $metadata -Pattern "explore_ideas_brief" -Reason "openai metadata must mention explore_ideas_brief handoff"
        Assert-Contains -Text $metadata -Pattern "without Plan mode or an Implement Plan step" -Reason "openai metadata must mention no Plan mode/Implement Plan"
        Assert-Contains -Text $metadata -Pattern "do not create issues, branches, PRs, GoalBuddy boards" -Reason "openai metadata must forbid execution actions"
        Add-Result -Name "openai metadata matches contract" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "openai metadata matches contract" -Passed $false -Reason $_.Exception.Message
    }

    try {
        Assert-Contains -Text $skill -Pattern "docs/milestones/<milestone-folder>/ideas/<YYYY-MM-DD>-<slug>.md" -Reason "missing tracked milestone-local idea brief policy"
        Assert-Contains -Text $skill -Pattern "docs/ideas.*legacy|legacy.*docs/ideas" -Reason "missing docs/ideas legacy warning"
        Assert-Contains -Text $skill -Pattern "owning milestone|owning_milestone" -Reason "missing owning milestone selection requirement"
        Assert-Contains -Text $skill -Pattern "commit and push that brief on the synced default branch" -Reason "missing commit/push policy for approved idea briefs"
        Assert-Contains -Text $skill -Pattern "Do not paste the full machine-readable JSON in chat" -Reason "missing no-JSON-dump final response rule"
        Assert-Contains -Text $skill -Pattern "tool_receipts" -Reason "missing tool receipts ledger"
        Assert-Contains -Text $skill -Pattern "Carto" -Reason "missing Carto mapping guidance"
        Assert-Contains -Text $skill -Pattern "Graphify" -Reason "missing Graphify mapping guidance"
        Add-Result -Name "idea artifact and exploration receipts present" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "idea artifact and exploration receipts present" -Passed $false -Reason $_.Exception.Message
    }

    try {
        $extraDocs = @(Get-ChildItem -LiteralPath $skillRoot -File | Where-Object { $_.Name -notin @("SKILL.md") })
        if ($extraDocs.Count -gt 0) { throw "unexpected top-level extra files: $($extraDocs.Name -join ', ')" }
        Add-Result -Name "skill package has no top-level clutter" -Passed $true -Reason "passed"
    } catch {
        Add-Result -Name "skill package has no top-level clutter" -Passed $false -Reason $_.Exception.Message
    }

    $failed = @($results | Where-Object { -not $_.passed })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Passed $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
