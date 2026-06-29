[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot "..\..")).Path
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$validatorFile = Join-Path $scriptRoot "validate-issue-mirror.ps1"
$hydrationFile = Join-Path $scriptRoot "hydrate-external-issue.ps1"
$titlePolicyValidatorFile = Join-Path $scriptRoot "validate-issue-title-policy.ps1"

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
    $normalizedText = ($Text -replace "\s+", " ").Trim()
    $normalizedNeedle = ($Needle -replace "\s+", " ").Trim()
    if (-not $normalizedText.Contains($normalizedNeedle)) { throw $Message }
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

function Run-Hydration {
    param(
        [string]$RepoRoot,
        [string]$IssueUrl,
        [string]$IssueBodyPath
    )
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $hydrationFile -RepoRoot $RepoRoot -IssueUrl $IssueUrl -IssueBodyPath $IssueBodyPath
    if ($LASTEXITCODE -ne 0) { throw ($output | Out-String) }
    $output | ConvertFrom-Json
}

function New-OutcomeProofSummary {
    param([string]$SourcePlan = "docs/superpowers/plans/2026-06-02-sample-plan.md")
@"
## Outcome Summary

**Outcome Source:** $SourcePlan#outcome-proof
**Intent:** Enforce issue contract continuity.
**Target Output:** Maintainer sees issue execution blocked without contract proof.
**Owner:** ``scripts/lib/outcome-proof.ps1``
**Interface:** Markdown issue summary fields consumed by validators.
**Cutover:** Extend issue readiness validation.
**Replaced Path:** Issue readiness without outcome workflow.
**Acceptance Proof:** issue validator returns ``ok: true``.
**Stop Criteria:** Reject issue mirrors missing contract proof.
**Avoid:** Do not use ``docs/goals`` as the issue source.
"@
}

function New-ExternalIssueBody {
    param([string]$Path, [string]$SourcePlan)
    @"
# External Hydration

**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/external-hydration-design.md
**Source Plan:** $SourcePlan
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Hydrate external GitHub issue before worker execution.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Hydrate an externally created GitHub issue into local Superpowers Project artifacts.

## Acceptance Criteria

- [ ] External issue body is preserved in a local mirror
- [ ] Source plan exists before execution routing

## Blocked by

- None

## Non-goals

- Do not publish draft project items

## Proof Oracle

- ``pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1``

$(New-OutcomeProofSummary -SourcePlan $SourcePlan)
"@ | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: create-issues" "missing skill name"
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
            "Auto Mode authorization ledger",
            "project_auto_mode_authorization",
            "the plugin-provided Auto Mode validator",
            "bounded-auto-merge",
            "recorded defaults",
            "direct-inline-resolve-issue",
            "stop outside policy",
            "docs/agents/triage-labels.md",
            "configured tracker vocabulary",
            "External GitHub Issue Hydration",
            "external GitHub issues are intake",
            "hydrate-external-issue.ps1",
            "Missing or malformed workflow metadata is blocking for every issue mirror",
            "Outcome Summary",
            "Outcome Source",
            "Interface",
            "Cutover",
            "Stop Criteria"
        )) {
            Assert-Contains $text $needle "missing create-issues contract: $needle"
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
        Assert-Contains $metadata "default_prompt:" "missing metadata default_prompt"
        Assert-Contains $metadata "docs/superpowers/issues" "missing metadata issue path"
        Assert-Contains $metadata "vertical slices" "missing metadata slice policy"
        Assert-Contains $metadata "flat canonical roots" "missing metadata flat root policy"
        Assert-Contains $metadata "issue mirrors include the GitHub issue number" "missing metadata issue filename policy"
        Assert-Contains $metadata "missing or malformed workflow metadata is blocking for every issue mirror" "missing metadata strict workflow metadata policy"
        foreach ($needle in @("Outcome Summary", "Outcome Source", "Interface", "Cutover", "Stop Criteria")) {
            Assert-Contains $metadata $needle "missing metadata outcome summary policy: $needle"
        }
        foreach ($needle in @("summarize", "artifact review gate", "broader project context", "recommended next route", "machine-readable artifacts", "project_issue_next_step", "top-level continuation gate", "docs/superpowers/workflow-contract.yml", "child routes", "starting the selected next skill")) {
            Assert-Contains $metadata $needle "missing metadata continuation route: $needle"
        }
        foreach ($needle in @("external GitHub issue hydration", "hydrate-external-issue.ps1", "Source Plan: TBD", "local mirror and source plan")) {
            Assert-Contains $metadata $needle "missing metadata hydration route: $needle"
        }
    }
    Invoke-Scenario "native continuation gate is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Native Continuation Gate",
            "skills/advanced-user-input/SKILL.md",
            "artifact review gate",
            "route-specific artifact inventory:",
            "created or updated issue mirror",
            "AFK/HITL classification",
            "blockers",
            "dependencies",
            "validation result",
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
    Invoke-Scenario "title policy validator rejects milestone metadata in new titles" {
        if (-not (Test-Path -LiteralPath $titlePolicyValidatorFile -PathType Leaf)) { throw "missing validate-issue-title-policy.ps1" }
        $cleanRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $titlePolicyValidatorFile -Title "Decision Ledger Examples" -KnownMilestoneTitles "M1 - Source Of Truth" -KnownMilestoneNumbers "M0","M1","M2" -Json
        if ($LASTEXITCODE -ne 0) { throw ($cleanRaw | Out-String) }
        $clean = ($cleanRaw | Out-String) | ConvertFrom-Json
        if (-not $clean.ok) { throw "clean title should pass: $($clean.reason)" }

        foreach ($badTitle in @(
            "M1: Decision Ledger Examples",
            "M1 Decision Ledger Examples",
            "M1.2 Decision Ledger Examples",
            "[M0] Artifact Review Card Schema",
            "[M0]Artifact Review Card Schema",
            "Source Of Truth: Decision Ledger Examples",
            "Source Of Truth Decision Ledger Examples",
            "1. Decision Ledger Examples"
        )) {
            $badRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $titlePolicyValidatorFile -Title $badTitle -KnownMilestoneTitles "M1 - Source Of Truth" -KnownMilestoneNumbers "M0","M1","M2" -Json
            $bad = ($badRaw | Out-String) | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -or $bad.ok) { throw "bad title should fail: $badTitle" }
            if ([string]::IsNullOrWhiteSpace([string]$bad.reason)) { throw "bad title failure should name the reason: $badTitle" }
        }
    }
    Invoke-Scenario "issue mirror validator accepts happy AFK issue" {
        if (-not (Test-Path -LiteralPath $validatorFile -PathType Leaf)) { throw "missing validate-issue-mirror.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-" + [guid]::NewGuid().ToString("N"))
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

$(New-OutcomeProofSummary)
"@ | Set-Content -LiteralPath $issuePath -Encoding utf8NoBOM
            $result = Run-Validator -RepoRoot $root -IssuePath $issuePath -MilestoneRequired
            if (-not $result.ok) { throw $result.reason }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "issue mirror validator blocks missing workflow metadata" {
        if (-not (Test-Path -LiteralPath $validatorFile -PathType Leaf)) { throw "missing validate-issue-mirror.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-missing-workflow-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\plans") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root "docs\superpowers\plans\2026-06-02-sample-plan.md") -Value "# Sample Plan" -Encoding utf8NoBOM
            $issuePath = Join-Path $root "docs\superpowers\issues\14-missing-workflow.md"
            @"
# Missing Workflow Metadata

**GitHub Issue:** https://github.com/example/repo/issues/14
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Plan:** docs/superpowers/plans/2026-06-02-sample-plan.md
**Classification:** AFK
**Goal Command:** /goal Resolve sample issue
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

$(New-OutcomeProofSummary)
"@ | Set-Content -LiteralPath $issuePath -Encoding utf8NoBOM
            $result = Run-Validator -RepoRoot $root -IssuePath $issuePath -MilestoneRequired
            if ($result.ok -or $result.reason -ne "Execution Mode is required") { throw "expected Execution Mode to be required" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "issue mirror validator blocks missing outcome summary" {
        if (-not (Test-Path -LiteralPath $validatorFile -PathType Leaf)) { throw "missing validate-issue-mirror.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-missing-contract-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\plans") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root "docs\superpowers\plans\2026-06-02-sample-plan.md") -Value "# Sample Plan" -Encoding utf8NoBOM
            $issuePath = Join-Path $root "docs\superpowers\issues\15-missing-contract.md"
            @"
# Missing Outcome Summary

**GitHub Issue:** https://github.com/example/repo/issues/15
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
            if ($result.ok -or $result.reason -notmatch "Outcome Summary") { throw "expected missing outcome summary to fail" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "bug issue mirror requires repro or feedback loop" {
        if (-not (Test-Path -LiteralPath $validatorFile -PathType Leaf)) { throw "missing validate-issue-mirror.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-bug-" + [guid]::NewGuid().ToString("N"))
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

- [ ] Bug fix is verified

$(New-OutcomeProofSummary -SourcePlan "docs/superpowers/specs/2026-06-02-bug-design.md")
"@ | Set-Content -LiteralPath $issuePath -Encoding utf8NoBOM
            $result = Run-Validator -RepoRoot $root -IssuePath $issuePath -MilestoneRequired
            if ($result.ok -or $result.reason -notmatch "repro|feedback") { throw "expected repro or feedback loop failure" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "external GitHub issue with unresolved Source Plan is intake only" {
        if (-not (Test-Path -LiteralPath $hydrationFile -PathType Leaf)) { throw "missing hydrate-external-issue.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hydration-intake-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $bodyPath = Join-Path $root "issue-body.md"
            New-ExternalIssueBody -Path $bodyPath -SourcePlan "TBD"
            $result = Run-Hydration -RepoRoot $root -IssueUrl "https://github.com/example/repo/issues/31" -IssueBodyPath $bodyPath
            if (-not $result.ok) { throw $result.reason }
            if ($result.ready_for_execution -ne $false) { throw "unresolved external issue must be intake before validation" }
            if (-not $result.created_source_plan) { throw "hydration must create a source plan for unresolved source plan input" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "external GitHub issue body hydrates local mirror under docs/superpowers/issues" {
        if (-not (Test-Path -LiteralPath $hydrationFile -PathType Leaf)) { throw "missing hydrate-external-issue.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hydration-mirror-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $bodyPath = Join-Path $root "issue-body.md"
            New-ExternalIssueBody -Path $bodyPath -SourcePlan "TBD"
            $result = Run-Hydration -RepoRoot $root -IssueUrl "https://github.com/example/repo/issues/31" -IssueBodyPath $bodyPath
            if (-not $result.ok) { throw $result.reason }
            if ($result.issue_mirror -ne "docs/superpowers/issues/31-external-hydration.md") { throw "unexpected issue mirror path: $($result.issue_mirror)" }
            if (-not (Test-Path -LiteralPath (Join-Path $root $result.issue_mirror) -PathType Leaf)) { throw "issue mirror was not written" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "hydration preserves issue URL, milestone, labels, acceptance criteria, proof oracle, and goal command" {
        if (-not (Test-Path -LiteralPath $hydrationFile -PathType Leaf)) { throw "missing hydrate-external-issue.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hydration-fields-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $bodyPath = Join-Path $root "issue-body.md"
            New-ExternalIssueBody -Path $bodyPath -SourcePlan "TBD"
            $result = Run-Hydration -RepoRoot $root -IssueUrl "https://github.com/example/repo/issues/31" -IssueBodyPath $bodyPath
            $mirror = Get-Content -LiteralPath (Join-Path $root $result.issue_mirror) -Raw
            foreach ($needle in @(
                "**GitHub Issue:** https://github.com/example/repo/issues/31",
                "**GitHub Milestone:** M1 - Source Of Truth",
                "**Labels:** type:feature, status:ready",
                "**Goal Command:** /goal Hydrate external GitHub issue before worker execution.",
                "- [ ] External issue body is preserved in a local mirror",
                "- ``pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1``"
            )) {
                Assert-Contains $mirror $needle "hydrated mirror did not preserve: $needle"
            }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "hydration creates or links a source plan before execution routing" {
        if (-not (Test-Path -LiteralPath $hydrationFile -PathType Leaf)) { throw "missing hydrate-external-issue.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hydration-plan-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $bodyPath = Join-Path $root "issue-body.md"
            New-ExternalIssueBody -Path $bodyPath -SourcePlan "docs/superpowers/plans/custom-external-hydration-plan.md"
            $result = Run-Hydration -RepoRoot $root -IssueUrl "https://github.com/example/repo/issues/31" -IssueBodyPath $bodyPath
            if (-not $result.ok) { throw $result.reason }
            if ($result.source_plan -ne "docs/superpowers/plans/custom-external-hydration-plan.md") { throw "source plan linkage was not preserved" }
            if (-not (Test-Path -LiteralPath (Join-Path $root $result.source_plan) -PathType Leaf)) { throw "linked source plan was not created" }
            $validation = Run-Validator -RepoRoot $root -IssuePath $result.issue_mirror -MilestoneRequired
            if (-not $validation.ok) { throw $validation.reason }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "execution routing is blocked until local mirror and source plan exist" {
        if (-not (Test-Path -LiteralPath $hydrationFile -PathType Leaf)) { throw "missing hydrate-external-issue.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hydration-block-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\issues") -Force | Out-Null
            $unreadyIssue = Join-Path $root "docs\superpowers\issues\31-external-hydration.md"
            @"
# External Hydration

**GitHub Issue:** https://github.com/example/repo/issues/31
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Plan:** docs/superpowers/plans/missing-plan.md
**Classification:** AFK
**Goal Command:** /goal Hydrate external GitHub issue before worker execution.

## Acceptance Criteria

- [ ] Source plan exists before execution routing
"@ | Set-Content -LiteralPath $unreadyIssue -Encoding utf8NoBOM
            $validation = Run-Validator -RepoRoot $root -IssuePath $unreadyIssue -MilestoneRequired
            if ($validation.ok -or $validation.reason -notmatch "source spec or source plan must exist") { throw "expected mirror validation to block execution routing" }

            $bodyPath = Join-Path $root "issue-body.md"
            New-ExternalIssueBody -Path $bodyPath -SourcePlan "TBD"
            $result = Run-Hydration -RepoRoot $root -IssueUrl "https://github.com/example/repo/issues/31" -IssueBodyPath $bodyPath
            $validation = Run-Validator -RepoRoot $root -IssuePath $result.issue_mirror -MilestoneRequired
            if (-not $validation.ok) { throw $validation.reason }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
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
            "project_issue_next_step",
            "top-level continuation gate",
            "child routes",
            "starting the selected next skill"
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
