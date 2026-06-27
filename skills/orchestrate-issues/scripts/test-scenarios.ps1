[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path (Split-Path $skillRoot -Parent) -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Name, [bool]$Ok, [string]$Reason) $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason }) }
function Assert-Contains { param([string]$Text, [string]$Needle, [string]$Reason) if (-not $Text.Contains($Needle)) { throw $Reason } }
function Invoke-Scenario { param([string]$Name, [scriptblock]$Body) try { & $Body; Add-Result -Name $Name -Ok $true -Reason "passed" } catch { Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message } }

function New-FixtureRepo {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("orchestrate-issues-fixture-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "docs/superpowers/issues") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "docs/superpowers/plans") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "scripts/lib") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "skills/create-issues/scripts") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "skills/orchestrate-issues/scripts") | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/create-issues/scripts/validate-issue-mirror.ps1") -Destination (Join-Path $temp "skills/create-issues/scripts/validate-issue-mirror.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "scripts/lib/outcome-proof.ps1") -Destination (Join-Path $temp "scripts/lib/outcome-proof.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/orchestrate-issues/scripts/derive-worker-identity.ps1") -Destination (Join-Path $temp "skills/orchestrate-issues/scripts/derive-worker-identity.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1") -Destination (Join-Path $temp "skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/orchestrate-issues/scripts/validate-worker-handoff.ps1") -Destination (Join-Path $temp "skills/orchestrate-issues/scripts/validate-worker-handoff.ps1")
    Set-Content -LiteralPath (Join-Path $temp "docs/superpowers/plans/2026-06-03-audit-project-audit-gate-plan.md") -Value "# Plan`n" -Encoding utf8NoBOM
    $issueText = @(
        "# Project Align Audit Gate",
        "",
        "**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/10",
        "**GitHub Milestone:** M1 - Source Of Truth",
        "**Issue Type:** task",
        "**Source Plan:** docs/superpowers/plans/2026-06-03-audit-project-audit-gate-plan.md",
        "**Classification:** AFK",
        "**Labels:** type:task, status:ready",
        "**Goal Command:** /goal Resolve issue 10.",
        "**Execution Mode:** Orchestrated worker",
        "**Worktree Policy:** Native Codex worktree thread first",
        "**Integration Policy:** Worker PR reviewed by main thread",
        "**TDD Policy:** Required",
        "**Parallelization Plan:** None",
        "**Reviewer Role:** Main thread orchestrator",
        "**Script Gate Mode:** Safety only",
        "",
        "## Outcome Summary",
        "",
        "**Outcome Source:** docs/superpowers/plans/2026-06-03-audit-project-audit-gate-plan.md#outcome-proof",
        "**Intent:** Prove orchestrated worker handoff carries contract evidence.",
        "**Target Output:** Maintainer sees worker handoff prepared from a contract-backed issue mirror.",
        "**Owner:** scripts/lib/outcome-proof.ps1",
        "**Interface:** issue mirror Outcome Summary fields",
        "**Cutover:** Worker handoff validation requires the outcome workflow.",
        "**Replaced Path:** Worker handoff from issue mirrors without contract evidence",
        "**Acceptance Proof:** orchestrate-issues scenario returns ok true.",
        "**Stop Criteria:** Reject worker handoff when contract proof is missing.",
        "**Avoid:** Do not use detached goal-board evidence as the contract source.",
        "",
        "## Project Merge",
        "",
        "**Merge Owner:** Main thread orchestrator",
        "**Merge Gate:** Native UI approval required",
        "**Merge Policy:** Repo default",
        "**Worktree Cleanup Policy:** Remove owned worktree after merge",
        "**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat",
        "",
        "## Acceptance Criteria",
        "",
        "- [ ] Worker identity is derived.",
        "",
        "## Proof Oracle",
        "",
        "- ``pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1``"
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $temp "docs/superpowers/issues/10-audit-project-audit-gate.md") -Value $issueText -Encoding utf8NoBOM
    $temp
}

try {
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $metadataFile -Raw

    Invoke-Scenario "skill frontmatter and metadata are valid" {
        foreach ($needle in @("name: orchestrate-issues", "worker-thread", "project_orchestrate_next_step", "project_issue_resolution_route", "debug_question_mode", "Native Question Debug Ledger", "Auto Mode authorization ledger", "project_auto_mode_authorization", "the plugin-provided Auto Mode validator", "bounded-auto-merge", "recorded defaults", "direct-inline-resolve-issue", "stop outside policy", "artifact review gate", "skills/advanced-user-input/SKILL.md", "route-specific artifact inventory:", "machine-readable handoff ledgers")) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing orchestrate skill contract: $needle"
        }
        foreach ($needle in @("orchestrate-issues", "derive-worker-identity.ps1", "merge-changes", "Auto Mode authorization ledger", "project_auto_mode_authorization", "bounded-auto-merge", "artifact review gate", "broader project context", "recommended next route", "machine-readable artifacts")) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "missing orchestrate metadata contract: $needle"
        }
    }

    Invoke-Scenario "derive-worker-identity creates canonical names" {
        $fixture = New-FixtureRepo
        try {
            $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "skills/orchestrate-issues/scripts/derive-worker-identity.ps1") -RepoRoot $fixture -IssueFile "docs/superpowers/issues/10-audit-project-audit-gate.md"
            if ($LASTEXITCODE -ne 0) { throw ($raw | Out-String) }
            $result = ($raw | Out-String) | ConvertFrom-Json
            if ($result.identity.thread_title -ne "Resolve #10: Audit Project audit gate") { throw "thread title mismatch" }
            if ($result.identity.branch -ne "codex/issue-10-audit-project-audit-gate") { throw "branch mismatch" }
            if ($result.identity.evidence_folder -ne "orchestrate-issues-issue-10-audit-project-audit-gate") { throw "evidence folder mismatch" }
        } finally {
            if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
        }
    }

    Invoke-Scenario "prepare and validate worker handoff" {
        $fixture = New-FixtureRepo
        try {
            $out = "handoff/worker-handoff.json"
            $preparedRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1") -RepoRoot $fixture -IssueFile "docs/superpowers/issues/10-audit-project-audit-gate.md" -OutputPath $out
            if ($LASTEXITCODE -ne 0) { throw ($preparedRaw | Out-String) }
            $prepared = ($preparedRaw | Out-String) | ConvertFrom-Json
            if (-not $prepared.ok) { throw $prepared.reason }
            $validatedRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "skills/orchestrate-issues/scripts/validate-worker-handoff.ps1") -RepoRoot $fixture -HandoffPath $out
            if ($LASTEXITCODE -ne 0) { throw ($validatedRaw | Out-String) }
            $validated = ($validatedRaw | Out-String) | ConvertFrom-Json
            if (-not $validated.ok) { throw $validated.reason }
        } finally {
            if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
        }
    }

    
    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $globalPolicyNeedles = @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )
        foreach ($needle in $globalPolicyNeedles) {
            if ($skill.Contains($needle)) { throw "SKILL.md duplicates helper-owned global policy instead of compact contract reference: $needle" }
            if ($metadata.Contains($needle)) { throw "metadata duplicates native continuation policy instead of compact contract reference: $needle" }
        }
        foreach ($needle in @(
            "skills/advanced-user-input/SKILL.md",
            "global native question geometry",
            "route-specific question IDs",
            "selected answers are executable routing"
        )) {
            if (-not $skill.Contains($needle)) { throw "missing compact native continuation helper reference: $needle" }
        }
        foreach ($needle in @(
            "docs/superpowers/workflow-contract.yml",
            "derive-worker-identity.ps1",
            "merge-changes"
        )) {
            if (-not $metadata.Contains($needle)) { throw "missing compact continuation metadata: $needle" }
        }

        $questionIds = [regex]::Matches($skill, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $skill.Length }
            $block = $skill.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: terminal option: break the continuation loop.')) { throw "nested question $questionId must not repeat stale terminal label" }
        }
        if ($metadata.Contains("Right terminal label")) { throw "metadata must not use old Right terminal label wording" }
    }
$results | ConvertTo-Json -Depth 8
    if (@($results | Where-Object { -not $_.ok }).Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
