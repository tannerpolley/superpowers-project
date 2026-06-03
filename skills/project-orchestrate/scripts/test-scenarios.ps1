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
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("project-orchestrate-fixture-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "docs/superpowers/issues") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "docs/superpowers/plans") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "skills/project-issue/scripts") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp "skills/project-orchestrate/scripts") | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/project-issue/scripts/validate-issue-mirror.ps1") -Destination (Join-Path $temp "skills/project-issue/scripts/validate-issue-mirror.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/project-orchestrate/scripts/derive-worker-identity.ps1") -Destination (Join-Path $temp "skills/project-orchestrate/scripts/derive-worker-identity.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/project-orchestrate/scripts/prepare-worker-handoff.ps1") -Destination (Join-Path $temp "skills/project-orchestrate/scripts/prepare-worker-handoff.ps1")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skills/project-orchestrate/scripts/validate-worker-handoff.ps1") -Destination (Join-Path $temp "skills/project-orchestrate/scripts/validate-worker-handoff.ps1")
    Set-Content -LiteralPath (Join-Path $temp "docs/superpowers/plans/2026-06-03-project-doctor-audit-gate-plan.md") -Value "# Plan`n" -Encoding utf8NoBOM
    $issueText = @(
        "# Project Doctor Audit Gate",
        "",
        "**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/10",
        "**GitHub Milestone:** M1 - Source Of Truth",
        "**Issue Type:** task",
        "**Source Plan:** docs/superpowers/plans/2026-06-03-project-doctor-audit-gate-plan.md",
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
    Set-Content -LiteralPath (Join-Path $temp "docs/superpowers/issues/10-project-doctor-audit-gate.md") -Value $issueText -Encoding utf8NoBOM
    $temp
}

try {
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $metadataFile -Raw

    Invoke-Scenario "skill frontmatter and metadata are valid" {
        foreach ($needle in @("name: project-orchestrate", "worker-thread", "project_orchestrate_next_step", "project_issue_resolution_route", "debug_question_mode", "Native Question Debug Ledger")) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing orchestrate skill contract: $needle"
        }
        foreach ($needle in @("project-orchestrate", "derive-worker-identity.ps1", "project-merge")) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "missing orchestrate metadata contract: $needle"
        }
    }

    Invoke-Scenario "derive-worker-identity creates canonical names" {
        $fixture = New-FixtureRepo
        try {
            $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "skills/project-orchestrate/scripts/derive-worker-identity.ps1") -RepoRoot $fixture -IssueFile "docs/superpowers/issues/10-project-doctor-audit-gate.md"
            if ($LASTEXITCODE -ne 0) { throw ($raw | Out-String) }
            $result = ($raw | Out-String) | ConvertFrom-Json
            if ($result.identity.thread_title -ne "Resolve #10: Project Doctor audit gate") { throw "thread title mismatch" }
            if ($result.identity.branch -ne "codex/issue-10-project-doctor-audit-gate") { throw "branch mismatch" }
            if ($result.identity.evidence_folder -ne "project-orchestrate-issue-10-project-doctor-audit-gate") { throw "evidence folder mismatch" }
        } finally {
            if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
        }
    }

    Invoke-Scenario "prepare and validate worker handoff" {
        $fixture = New-FixtureRepo
        try {
            $out = "handoff/worker-handoff.json"
            $preparedRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "skills/project-orchestrate/scripts/prepare-worker-handoff.ps1") -RepoRoot $fixture -IssueFile "docs/superpowers/issues/10-project-doctor-audit-gate.md" -OutputPath $out
            if ($LASTEXITCODE -ne 0) { throw ($preparedRaw | Out-String) }
            $prepared = ($preparedRaw | Out-String) | ConvertFrom-Json
            if (-not $prepared.ok) { throw $prepared.reason }
            $validatedRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "skills/project-orchestrate/scripts/validate-worker-handoff.ps1") -RepoRoot $fixture -HandoffPath $out
            if ($LASTEXITCODE -ne 0) { throw ($validatedRaw | Out-String) }
            $validated = ($validatedRaw | Out-String) | ConvertFrom-Json
            if (-not $validated.ok) { throw $validated.reason }
        } finally {
            if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
        }
    }

    $results | ConvertTo-Json -Depth 8
    if (@($results | Where-Object { -not $_.ok }).Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
