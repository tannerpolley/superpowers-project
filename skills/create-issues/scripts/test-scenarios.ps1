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
$hierarchyLibFile = Join-Path $scriptRoot "lib\issue-hierarchy.ps1"
$hierarchyValidatorFile = Join-Path $scriptRoot "validate-issue-hierarchy.ps1"
$hierarchyPlanBuilderFile = Join-Path $scriptRoot "build-issue-hierarchy-plan.ps1"

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
        [string]$IssueBodyPath,
        [string]$IssueJsonPath
    )
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $hydrationFile, "-RepoRoot", $RepoRoot, "-IssueUrl", $IssueUrl)
    if (-not [string]::IsNullOrWhiteSpace($IssueBodyPath)) { $args += @("-IssueBodyPath", $IssueBodyPath) }
    if (-not [string]::IsNullOrWhiteSpace($IssueJsonPath)) { $args += @("-IssueJsonPath", $IssueJsonPath) }
    $output = & pwsh.exe @args
    if ($LASTEXITCODE -ne 0) { throw ($output | Out-String) }
    $output | ConvertFrom-Json
}

function Run-HierarchyValidator {
    param(
        [string]$RepoRoot,
        [string]$IssuePath,
        [string]$GitHubIssueFixturePath
    )
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $hierarchyValidatorFile, "-RepoRoot", $RepoRoot, "-IssueMirrorPath", $IssuePath, "-Json")
    if (-not [string]::IsNullOrWhiteSpace($GitHubIssueFixturePath)) {
        $args += @("-GitHubIssueFixturePath", $GitHubIssueFixturePath)
    }
    $output = & pwsh.exe @args
    $output | ConvertFrom-Json
}

function Run-HierarchyPlanBuilder {
    param([string[]]$Arguments)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $hierarchyPlanBuilderFile @Arguments
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
    Invoke-Scenario "hierarchy publication route uses native gates before mutation" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "## Hierarchy Publication Paths",
            '`flat`',
            '`issue-set`',
            '`sub-milestone`',
            "project_issue_hierarchy_mode",
            "project_issue_hierarchy_parent",
            "project_issue_hierarchy_wrapper",
            "project_issue_hierarchy_children",
            "project_issue_hierarchy_tracker_fields",
            "project_issue_hierarchy_publish",
            "build-issue-hierarchy-plan.ps1",
            "validate-issue-title-policy.ps1",
            "dry command receipt",
            "clean-title validation runs before any GitHub mutation",
            "gh issue create --parent",
            "gh issue edit --add-sub-issue"
        )) {
            Assert-Contains $text $needle "missing hierarchy publication route contract: $needle"
        }
        foreach ($needle in @(
            "hierarchy modes",
            "flat, issue-set, and sub-milestone",
            "dry command receipt",
            "read SKILL.md for hierarchy route details"
        )) {
            Assert-Contains $metadata $needle "missing compact hierarchy metadata: $needle"
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
    Invoke-Scenario "issue hierarchy validator covers flat parent wrapper leaf and GitHub parity" {
        foreach ($requiredFile in @($hierarchyLibFile, $hierarchyValidatorFile)) {
            if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "missing hierarchy validation file: $requiredFile" }
        }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hierarchy-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\plans") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root "docs\superpowers\plans\2026-06-02-sample-plan.md") -Value "# Sample Plan" -Encoding utf8NoBOM

            $base = @"
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

- [ ] Hierarchy fixture validates

$(New-OutcomeProofSummary)
"@
            $flat = Join-Path $root "docs\superpowers\issues\10-flat.md"
            @"
# Flat

**GitHub Issue:** https://github.com/example/repo/issues/10
$base
"@ | Set-Content -LiteralPath $flat -Encoding utf8NoBOM

            $parent = Join-Path $root "docs\superpowers\issues\11-parent.md"
            @"
# Parent

**GitHub Issue:** https://github.com/example/repo/issues/11
$base
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** parent
**Executable:** false
**Parent Issue:** None
**Parent Mirror:** None
**Child Issues:** https://github.com/example/repo/issues/12, https://github.com/example/repo/issues/13
**Rollup Policy:** all-required-children-closed
**Title Policy:** Clean GitHub title
"@ | Set-Content -LiteralPath $parent -Encoding utf8NoBOM

            $wrapper = Join-Path $root "docs\superpowers\issues\12-wrapper.md"
            @"
# Wrapper

**GitHub Issue:** https://github.com/example/repo/issues/12
$base
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** plan-wrapper
**Executable:** false
**Parent Issue:** https://github.com/example/repo/issues/11
**Parent Mirror:** docs/superpowers/issues/11-parent.md
**Child Issues:** https://github.com/example/repo/issues/13
**Rollup Policy:** all-required-children-closed
**Title Policy:** Clean GitHub title
"@ | Set-Content -LiteralPath $wrapper -Encoding utf8NoBOM

            $leaf = Join-Path $root "docs\superpowers\issues\13-leaf.md"
            @"
# Leaf

**GitHub Issue:** https://github.com/example/repo/issues/13
$base
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** leaf
**Executable:** true
**Parent Issue:** https://github.com/example/repo/issues/12
**Parent Mirror:** docs/superpowers/issues/12-wrapper.md
**Child Issues:** None
**Rollup Policy:** none
**Title Policy:** Clean GitHub title
"@ | Set-Content -LiteralPath $leaf -Encoding utf8NoBOM

            $invalidParent = Join-Path $root "docs\superpowers\issues\14-invalid-parent.md"
            (Get-Content -LiteralPath $parent -Raw).Replace("**Executable:** false", "**Executable:** true") | Set-Content -LiteralPath $invalidParent -Encoding utf8NoBOM

            foreach ($valid in @($flat, $parent, $wrapper, $leaf)) {
                $result = Run-HierarchyValidator -RepoRoot $root -IssuePath $valid
                if (-not $result.ok) { throw "expected hierarchy mirror to pass: $valid -> $($result.reason)" }
            }
            $invalid = Run-HierarchyValidator -RepoRoot $root -IssuePath $invalidParent
            if ($invalid.ok -or $invalid.reason -notmatch "Executable false") { throw "expected executable parent to fail with explicit reason" }

            $fixturePath = Join-Path $root "parent-github.json"
            @{
                number = 11
                url = "https://github.com/example/repo/issues/11"
                parent = $null
                subIssues = @{ nodes = @(
                    @{ number = 12; url = "https://github.com/example/repo/issues/12"; title = "Wrapper"; state = "OPEN" },
                    @{ number = 13; url = "https://github.com/example/repo/issues/13"; title = "Leaf"; state = "OPEN" }
                ); totalCount = 2 }
                subIssuesSummary = @{ total = 2; completed = 0; percentCompleted = 0 }
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixturePath -Encoding utf8NoBOM
            $parity = Run-HierarchyValidator -RepoRoot $root -IssuePath $parent -GitHubIssueFixturePath $fixturePath
            if (-not $parity.ok) { throw "expected GitHub fixture parity to pass: $($parity.reason)" }
            $badFixturePath = Join-Path $root "bad-parent-github.json"
            (Get-Content -LiteralPath $fixturePath -Raw).Replace("https://github.com/example/repo/issues/13", "https://github.com/example/repo/issues/99") | Set-Content -LiteralPath $badFixturePath -Encoding utf8NoBOM
            $badParity = Run-HierarchyValidator -RepoRoot $root -IssuePath $parent -GitHubIssueFixturePath $badFixturePath
            if ($badParity.ok -or $badParity.reason -notmatch "subIssues") { throw "expected GitHub subIssues parity drift to fail" }

            $integrated = Run-Validator -RepoRoot $root -IssuePath $invalidParent -MilestoneRequired
            if ($integrated.ok -or $integrated.reason -notmatch "Executable false") { throw "issue mirror validator should delegate hierarchy failures" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "hierarchy dry command builder emits parent first wrapper leaf order" {
        if (-not (Test-Path -LiteralPath $hierarchyPlanBuilderFile -PathType Leaf)) { throw "missing build-issue-hierarchy-plan.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hierarchy-plan-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\superpowers\plans") -Force | Out-Null
            $plan = Join-Path $root "docs\superpowers\plans\2026-06-02-sample-plan.md"
            Set-Content -LiteralPath $plan -Value "# Sample Plan" -Encoding utf8NoBOM
            $result = Run-HierarchyPlanBuilder -Arguments @(
                "-RepoRoot", $root,
                "-SourcePlanPath", "docs/superpowers/plans/2026-06-02-sample-plan.md",
                "-HierarchyMode", "sub-milestone",
                "-GitHubMilestoneTitle", "M1 - Source Of Truth",
                "-ParentTitle", "GitHub Sub-Issues Workflow",
                "-WrapperTitles", "Create Issues",
                "-LeafTitles", "Hierarchy Schema,Hydration Routing",
                "-ExistingChildIssueUrls", "https://github.com/example/repo/issues/77",
                "-Labels", "type:task,status:ready",
                "-Json"
            )
            if (-not $result.ok) { throw $result.reason }
            $roles = @($result.publication_order | ForEach-Object { $_.role })
            if (($roles -join ",") -ne "parent,plan-wrapper,leaf,leaf,existing-child") { throw "unexpected publication order: $($roles -join ',')" }
            $commands = (@($result.dry_commands) -join "`n")
            foreach ($needle in @("gh issue create", "--parent", "gh issue edit", "--add-sub-issue", "--milestone `"M1 - Source Of Truth`"")) {
                if (-not $commands.Contains($needle)) { throw "dry commands missing $needle" }
            }
            $bad = Run-HierarchyPlanBuilder -Arguments @(
                "-RepoRoot", $root,
                "-SourcePlanPath", "docs/superpowers/plans/2026-06-02-sample-plan.md",
                "-HierarchyMode", "issue-set",
                "-GitHubMilestoneTitle", "M1 - Source Of Truth",
                "-ParentTitle", "M1: Bad Parent",
                "-LeafTitles", "Clean Leaf",
                "-Json"
            )
            if ($bad.ok -or $bad.reason -notmatch "title encodes") { throw "expected title-policy failure from dry planner" }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
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
    Invoke-Scenario "external GitHub hierarchy JSON hydrates local mirror metadata" {
        if (-not (Test-Path -LiteralPath $hydrationFile -PathType Leaf)) { throw "missing hydrate-external-issue.ps1" }
        $root = Join-Path ([IO.Path]::GetTempPath()) ("create-issues-hydration-hierarchy-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $bodyPath = Join-Path $root "issue-body.md"
            New-ExternalIssueBody -Path $bodyPath -SourcePlan "TBD"
            $fixturePath = Join-Path $root "github-issue.json"
            @{
                number = 42
                title = "External Hydration"
                url = "https://github.com/example/repo/issues/42"
                body = Get-Content -LiteralPath $bodyPath -Raw
                milestone = @{ title = "M1 - Source Of Truth" }
                labels = @(
                    @{ name = "type:task" },
                    @{ name = "status:ready" }
                )
                issueType = @{ name = "task" }
                parent = @{
                    number = 41
                    title = "GitHub Sub-Issues Workflow"
                    url = "https://github.com/example/repo/issues/41"
                    state = "OPEN"
                }
                subIssues = @{ nodes = @(); totalCount = 0 }
                subIssuesSummary = @{ total = 0; completed = 0; percentCompleted = 0 }
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixturePath -Encoding utf8NoBOM
            $result = Run-Hydration -RepoRoot $root -IssueUrl "https://github.com/example/repo/issues/42" -IssueJsonPath $fixturePath
            if (-not $result.ok) { throw $result.reason }
            $mirror = Get-Content -LiteralPath (Join-Path $root $result.issue_mirror) -Raw
            foreach ($needle in @(
                "**GitHub Issue:** https://github.com/example/repo/issues/42",
                "**GitHub Milestone:** M1 - Source Of Truth",
                "**Issue Type:** task",
                "**Labels:** type:task, status:ready",
                "**Hierarchy Mode:** sub-milestone",
                "**Sub-Issue Role:** leaf",
                "**Executable:** true",
                "**Parent Issue:** https://github.com/example/repo/issues/41",
                "**Parent Mirror:** docs/superpowers/issues/41-github-sub-issues-workflow.md",
                "**Child Issues:** None",
                "**Rollup Policy:** none",
                "**Title Policy:** Clean GitHub title"
            )) {
                Assert-Contains $mirror $needle "hydrated hierarchy mirror did not preserve: $needle"
            }
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
