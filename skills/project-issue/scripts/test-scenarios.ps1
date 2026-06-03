[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot "..\..")).Path
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$validatorFile = Join-Path $scriptRoot "validate-issue-mirror.ps1"

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

function Run-Validator {
    param([string]$RepoRoot, [string]$IssuePath, [switch]$MilestoneRequired)
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validatorFile, "-RepoRoot", $RepoRoot, "-IssueFile", $IssuePath)
    if ($MilestoneRequired) { $args += "-MilestoneRequired" }
    $output = & pwsh.exe @args
    $output | ConvertFrom-Json
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: project-issue" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Issue" "missing skill title"
    }
    Invoke-Scenario "issue slicing contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "docs/superpowers/plans",
            "docs/superpowers/specs",
            "docs/superpowers/issues",
            "vertical slices",
            "AFK",
            "HITL",
            "Blocked by",
            "Acceptance Criteria",
            "GitHub Issue",
            "GitHub Milestone",
            "Goal Command",
            "docs/agents/triage-labels.md",
            "configured tracker vocabulary"
        )) {
            Assert-Contains $text $needle "missing project-issue contract: $needle"
        }
        foreach ($needle in @(
            "Execution Mode",
            "Worktree Policy",
            "Integration Policy",
            "TDD Policy",
            "Parallelization Plan",
            "Reviewer Role",
            "Script Gate Mode",
            "Project Merge",
            "Merge Owner",
            "Merge Gate",
            "Merge Policy",
            "Worktree Cleanup Policy",
            "Orchestrator Wakeup Policy"
        )) {
            Assert-Contains $text $needle "missing workflow metadata contract: $needle"
        }
    }
    Invoke-Scenario "flat canonical issue root contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "flat canonical roots",
            "spec -> plan -> issue",
            "issue mirrors include the GitHub issue number",
            "docs/superpowers/issues/<issue-number>-<slug>.md",
            "Milestone pages are index views",
            "frontmatter plus milestone indexes",
            "nested canonical milestone artifact folders are drift"
        )) {
            Assert-Contains $text $needle "missing flat canonical issue root contract: $needle"
        }
    }
    Invoke-Scenario "metadata is present" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $metadata "project-issue:" "missing metadata key"
        Assert-Contains $metadata "docs/superpowers/issues" "missing metadata issue path"
        Assert-Contains $metadata "vertical slices" "missing metadata slice policy"
        Assert-Contains $metadata "flat canonical roots" "missing metadata flat root policy"
        Assert-Contains $metadata "issue mirrors include the GitHub issue number" "missing metadata issue filename policy"
        foreach ($needle in @("summarize", "project_issue_next_step", "Resolve First Ready", "Resolve Selected", "Review First", "Stop", "start the selected next skill")) {
            Assert-Contains $metadata $needle "missing metadata continuation route: $needle"
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
            "project_issue_next_step",
            "Resolve First Ready",
            "Resolve Selected",
            "Stop"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }
    Invoke-Scenario "old issue creation target is retired" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-NotContains $text "docs/milestones/<milestone-folder>/issues" "old milestone issue path must not be active"
        Assert-NotContains $text "docs/issues" "top-level issue path must not be active"
    }
    Invoke-Scenario "issue mirror validator accepts happy AFK issue" {
        if (-not (Test-Path -LiteralPath $validatorFile -PathType Leaf)) { throw "missing validate-issue-mirror.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("project-issue-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\plans") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root "docs\superpowers\plans\2026-06-02-sample-plan.md") -Value "# Sample Plan" -Encoding utf8NoBOM
            $issuePath = Join-Path $root "docs\superpowers\issues\12-sample.md"
            @"
# Sample Issue

**GitHub Issue:** https://github.com/example/repo/issues/12
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Plan:** docs/superpowers/plans/2026-06-02-sample-plan.md
**Classification:** AFK
**Goal Command:** /goal Resolve sample issue
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Acceptance Criteria

- [ ] Sample issue can be resolved by an agent
"@ | Set-Content -LiteralPath $issuePath -Encoding utf8NoBOM
            $result = Run-Validator -RepoRoot $root -IssuePath $issuePath -MilestoneRequired
            if (-not $result.ok) { throw $result.reason }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "bug issue mirror requires repro or feedback loop" {
        if (-not (Test-Path -LiteralPath $validatorFile -PathType Leaf)) { throw "missing validate-issue-mirror.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("project-issue-bug-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\specs") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root "docs\superpowers\specs\2026-06-02-bug-design.md") -Value "# Bug Design" -Encoding utf8NoBOM
            $issuePath = Join-Path $root "docs\superpowers\issues\13-bug.md"
            @"
# Bug Issue

**GitHub Issue:** https://github.com/example/repo/issues/13
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** bug
**Source Spec:** docs/superpowers/specs/2026-06-02-bug-design.md
**Classification:** AFK
**Goal Command:** /goal Resolve bug issue

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Acceptance Criteria

- [ ] Bug fix is verified
"@ | Set-Content -LiteralPath $issuePath -Encoding utf8NoBOM
            $result = Run-Validator -RepoRoot $root -IssuePath $issuePath -MilestoneRequired
            if ($result.ok -or $result.reason -notmatch "repro|feedback") { throw "expected repro or feedback loop failure" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
