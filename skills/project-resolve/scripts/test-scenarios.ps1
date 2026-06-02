[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptRoot
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("riwg-native-goal-" + [guid]::NewGuid().ToString("N"))
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Add-Result -Name $Name -Ok $true -Reason "passed"
    } catch {
        Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message
    }
}

function Invoke-JsonScript {
    param([string]$ScriptName, [string[]]$Arguments)
    $scriptPath = Join-Path $scriptRoot $ScriptName
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
    $raw = ($output | Out-String).Trim()
    try {
        if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty output" }
        return ($raw | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{ ok = $false; phase = $ScriptName; reason = $raw }
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-TestRepo {
    $repo = Join-Path $tempRoot "repo"
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -b main | Out-Null
    & git -C $repo config user.email tests@example.invalid | Out-Null
    & git -C $repo config user.name "Native Goal Tests" | Out-Null
    & git -C $repo config core.autocrlf false | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "docs\superpowers\plans") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "docs\superpowers\issues") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "src") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "# Repo`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "docs\superpowers\plans\2026-06-02-sample-plan.md") -Value "# Sample Plan`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "src\example.txt") -Value "example`n" -Encoding utf8NoBOM
    & git -C $repo add . | Out-Null
    & git -C $repo commit -m initial | Out-Null
    $repo
}

function Write-IssueMirror {
    param(
        [string]$Repo,
        [string]$RelativePath = "docs/superpowers/issues/12-sample.md",
        [string]$SourcePlan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
    )
    $path = Join-Path $Repo $RelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
@"
# Sample Issue

**GitHub Issue:** https://github.com/example/repo/issues/12
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Plan:** $SourcePlan
**Classification:** AFK
**Goal Command:** /goal Resolve sample issue
**Branch:** codex/sample-issue

## Acceptance Criteria

- [ ] Sample issue is resolved

## Proof Oracle

- pwsh -NoProfile -Command 'exit 0'
"@ | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    $RelativePath
}

function New-Handoff {
    param([string]$IssueMirror = "docs/superpowers/issues/12-sample.md")
    @{
        issue_url = "https://github.com/example/repo/issues/12"
        issue_mirror = $IssueMirror
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/sample-issue"
        goal_objective = "Resolve https://github.com/example/repo/issues/12 on codex/sample-issue using docs/superpowers/issues/12-sample.md and docs/superpowers/plans/2026-06-02-sample-plan.md."
        proof_oracle = @("pwsh -NoProfile -Command 'exit 0'")
        required_checks_policy = "allow-none-with-local-proof"
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-GoalProof {
    @{
        source = "get_goal"
        active = $true
        goal_id = "thread-goal"
        objective = "Resolve https://github.com/example/repo/issues/12 on codex/sample-issue using docs/superpowers/issues/12-sample.md and docs/superpowers/plans/2026-06-02-sample-plan.md."
    } | ConvertTo-Json -Depth 8 -Compress
}

function New-ExecutionDecision {
    param([string]$SelectedMode = "inline", [string]$Source = "request_user_input")
    @{
        question_id = "resolve_execution_topology"
        source = $Source
        selected_mode = $SelectedMode
        recommended_mode = $SelectedMode
        options = @("orchestrated-worker", "inline")
    } | ConvertTo-Json -Depth 8 -Compress
}

function New-SetupLedger {
    param([object]$Extra = $null, [object]$GoalProof = $null)
    $ledger = [ordered]@{
        issue_url = "https://github.com/example/repo/issues/12"
        issue_mirror = "docs/superpowers/issues/12-sample.md"
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/sample-issue"
        goal_id = "thread-goal"
        goal_objective = "Resolve https://github.com/example/repo/issues/12 on codex/sample-issue using docs/superpowers/issues/12-sample.md and docs/superpowers/plans/2026-06-02-sample-plan.md."
        goal_activation_proof = if ($null -eq $GoalProof) { (New-GoalProof | ConvertFrom-Json) } else { $GoalProof }
        execution_decision = (New-ExecutionDecision | ConvertFrom-Json)
        proof_oracle = @("pwsh -NoProfile -Command 'exit 0'")
        branch_inventory_before = @{ local = @("main"); remote = @() }
    }
    if ($Extra) {
        foreach ($property in $Extra.PSObject.Properties) { $ledger[$property.Name] = $property.Value }
    }
    $ledger | ConvertTo-Json -Depth 16 -Compress
}

function New-PrFixture {
    param([string]$Path)
    @{
        url = "https://github.com/example/repo/pull/5"
        state = "MERGED"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "local-proof"; state = "SUCCESS"; conclusion = "SUCCESS" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/superpowers/issues/12-sample.md" })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function New-IssueFixture {
    param([string]$Path)
    @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

try {
    $repo = New-TestRepo
    $issueMirror = Write-IssueMirror -Repo $repo

    Invoke-Scenario "issue mirror path outside docs/superpowers/issues blocks" {
        $badMirror = Write-IssueMirror -Repo $repo -RelativePath "docs/superpowers/plans/not-an-issue.md"
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $repo, "-IssueMirror", $badMirror)
        Assert-True (-not $result.ok -and $result.reason -match "docs/superpowers/issues") "expected issue mirror path failure"
    }

    Invoke-Scenario "missing source plan blocks" {
        $missingPlanMirror = Write-IssueMirror -Repo $repo -RelativePath "docs/superpowers/issues/13-missing-plan.md" -SourcePlan "docs/superpowers/plans/missing.md"
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $repo, "-IssueMirror", $missingPlanMirror)
        Assert-True (-not $result.ok -and $result.reason -match "source plan") "expected missing source plan failure"
    }

    Invoke-Scenario "missing goal activation proof blocks" {
        $ledger = New-SetupLedger -GoalProof ([pscustomobject]@{})
        $result = Invoke-JsonScript -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $ledger)
        Assert-True (-not $result.ok -and $result.reason -match "goal_activation_proof") "expected missing goal proof failure"
    }

    Invoke-Scenario "fake string goal proof blocks" {
        $ledger = New-SetupLedger -GoalProof "get_goal says active"
        $result = Invoke-JsonScript -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $ledger)
        Assert-True (-not $result.ok -and $result.reason -match "structured") "expected fake proof failure"
    }

    Invoke-Scenario "GoalBuddy board path in setup ledger blocks" {
        $ledger = New-SetupLedger -Extra ([pscustomobject]@{ goal_board_path = "docs/goals/sample-issue" })
        $result = Invoke-JsonScript -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $ledger)
        Assert-True (-not $result.ok -and $result.reason -match "goal_board_path") "expected board path rejection"
    }

    Invoke-Scenario "tracked GoalBuddy board files are never required" {
        $ledger = New-SetupLedger
        $result = Invoke-JsonScript -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $ledger)
        Assert-True ($result.ok) $result.reason
    }

    Invoke-Scenario "missing execution decision blocks setup finalization" {
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof))
        Assert-True (-not $result.ok -and $result.reason -match "execution decision") "expected missing execution decision failure"
    }

    Invoke-Scenario "inline execution decision is recorded" {
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "inline"))
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.setup_ledger.execution_decision.selected_mode -eq "inline") "inline mode was not recorded"
    }

    Invoke-Scenario "orchestrated worker execution decision is recorded with worker handoff" {
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "orchestrated-worker"))
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.setup_ledger.execution_decision.selected_mode -eq "orchestrated-worker") "worker mode was not recorded"
        Assert-True ($result.setup_ledger.worker_handoff.issue_mirror -eq "docs/superpowers/issues/12-sample.md") "worker handoff missing issue mirror"
        Assert-True ($result.setup_ledger.worker_handoff.dynamic_work_packet_map.worker_packet.objective -match "Implement") "worker packet objective missing"
        Assert-True ($result.setup_ledger.dynamic_work_packet_map.merge_owner -eq "project-merge") "merge owner must be project-merge"
    }

    Invoke-Scenario "happy setup passes with structured native goal proof" {
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "inline"))
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.setup_ledger.goal_id -eq "thread-goal") "missing goal id in setup ledger"
        Assert-True (-not ($result.setup_ledger.PSObject.Properties.Name -contains "goal_board_path")) "setup ledger must not contain goal_board_path"
    }

    Invoke-Scenario "happy PR-ready handoff marks resolve goal complete" {
        $prReady = @{
            pr_url = "https://github.com/example/repo/pull/5"
            issue_url = "https://github.com/example/repo/issues/12"
            branch = "codex/sample-issue"
            branch_pushed = $true
            pr_closes_issue = $true
            acceptance_criteria_covered = $true
            verification_passed = $true
            handoff_sent = @{ source = "worker-final-message"; status = "sent"; recipient = "main-thread-orchestrator" }
            goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
        } | ConvertTo-Json -Depth 16 -Compress
        $result = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", $prReady)
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.evidence.goal_status -eq "complete") "resolve goal completion was not recorded"
    }

    Invoke-Scenario "skill text declares native goal state machine" {
        $text = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
        foreach ($needle in @("repo gate", "issue mirror validation", "source plan validation", "native goal activation", "Superpowers execution", "PR-ready validation", "GoalBuddy boards are outside the default execution model")) {
            Assert-True ($text.Contains($needle)) "missing skill text: $needle"
        }
        foreach ($needle in @(
            "execution topology question",
            "Open worker thread",
            "Current thread",
            "request_user_input",
            "debug_question_mode",
            "using-git-worktrees",
            "Dynamic Work Packet Map",
            "codex-dynamic-workflows",
            "test-driven-development",
            "verification-before-completion",
            "finishing-a-development-branch",
            "main thread orchestrator",
            "project-merge",
            "## Native Continuation Gate"
        )) {
            Assert-True ($text.Contains($needle)) "missing resolver workflow text: $needle"
        }
    }

    $failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
