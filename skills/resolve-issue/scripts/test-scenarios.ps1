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

function New-OutcomeProof {
    [pscustomobject]@{
        source = "docs/superpowers/plans/2026-06-02-sample-plan.md#outcome-proof"
        intent = "Resolve the sample issue with contract continuity."
        target_output = "Maintainer sees PR-ready evidence tied to the source contract."
        owner = "scripts/lib/outcome-proof.ps1"
        interface = "structured outcome_proof ledger object"
        cutover = "Resolve setup and PR-ready validation require contract evidence."
        replaced_path = "PR-ready handoff without outcome proof proof"
        acceptance_proof = "validate-pr-ready.ps1 returns ok true with readiness review."
        stop_criteria = "Block PR-ready handoff when readiness review is missing."
        avoid = @("Do not use GoalBuddy board paths as the contract source.")
    }
}

function New-ReadinessReview {
    [pscustomobject]@{
        plan_alignment = $true
        correctness = $true
        maintainability = $true
        reality_evidence = $true
    }
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

## Outcome Summary

**Outcome Source:** $SourcePlan#outcome-proof
**Intent:** Resolve the sample issue with contract continuity.
**Target Output:** Maintainer sees PR-ready evidence tied to the source contract.
**Owner:** `scripts/lib/outcome-proof.ps1`
**Interface:** structured outcome_proof ledger object
**Cutover:** Resolve setup and PR-ready validation require contract evidence.
**Replaced Path:** PR-ready handoff without outcome proof proof
**Acceptance Proof:** validate-pr-ready.ps1 returns ok true with readiness review.
**Stop Criteria:** Block PR-ready handoff when readiness review is missing.
**Avoid:** Do not use GoalBuddy board paths as the contract source.

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
        outcome_proof = New-OutcomeProof
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

function New-PushPermission {
    param([string]$SelectedAction = "push-pr", [string]$Source = "request_user_input")
    @{
        question_id = "project_resolve_push_permission"
        source = $Source
        selected_action = $SelectedAction
        recommended_action = "push-pr"
        options = @("push-pr", "hold")
    } | ConvertTo-Json -Depth 8 -Compress
}

function New-ResolveContinuationDecision {
    param(
        [string]$QuestionId = "project_resolve_next_step",
        [string]$SelectedOptionId = "stop",
        [string]$RecommendedOptionId = "integrate-resolved-issue",
        [string]$TerminalState = "stop",
        [string[]]$OptionIds = @("integrate-resolved-issue", "review-revise-pr-ready-work", "stop"),
        [string]$Source = "request_user_input"
    )
    @{
        skill = "resolve-issue"
        question_id = $QuestionId
        prompt = "Should I continue on with the workflow?"
        source = $Source
        selected_option_id = $SelectedOptionId
        selected_option_label = $SelectedOptionId
        recommended_option_id = $RecommendedOptionId
        recommended_option_label = $RecommendedOptionId
        option_ids = @($OptionIds)
        terminal_state = $TerminalState
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
        outcome_proof = New-OutcomeProof
        proof_oracle = @("pwsh -NoProfile -Command 'exit 0'")
        branch_inventory_before = @{ local = @("main"); remote = @() }
    }
    if ($Extra) {
        foreach ($property in $Extra.PSObject.Properties) { $ledger[$property.Name] = $property.Value }
    }
    $ledger | ConvertTo-Json -Depth 16 -Compress
}

function New-PrReadyLedger {
    param([object]$Extra = $null)
    $ledger = [ordered]@{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        branch = "codex/sample-issue"
        outcome_proof = New-OutcomeProof
        readiness_review = New-ReadinessReview
        branch_pushed = $true
        pr_closes_issue = $true
        push_permission = (New-PushPermission | ConvertFrom-Json)
        branch_push_proof = @{ source = "PR evidence"; pr_url = "https://github.com/example/repo/pull/5" }
        acceptance_criteria_covered = $true
        verification_passed = $true
        handoff_sent = @{ source = "worker-final-message"; status = "sent"; recipient = "main-thread-orchestrator" }
        goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
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

    Invoke-Scenario "skill documents flat canonical roots" {
        $skillText = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
        foreach ($needle in @(
            "flat canonical roots",
            "spec -> plan -> issue",
            "docs/superpowers/specs",
            "docs/superpowers/plans",
            "docs/superpowers/issues",
            "Milestone pages are index views",
            "nested canonical milestone artifact folders are drift"
        )) {
            Assert-True ($skillText.Contains($needle)) "missing flat artifact root resolve contract: $needle"
        }
        $metadata = Get-Content -LiteralPath (Join-Path $skillRoot "agents\openai.yaml") -Raw
        Assert-True ($metadata.Contains("flat canonical roots")) "metadata missing flat root policy"
        Assert-True ($metadata.Contains("Milestone pages are index views")) "metadata missing milestone index policy"
    }

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

    Invoke-Scenario "setup ledger rejects missing outcome proof" {
        $ledgerObject = New-SetupLedger | ConvertFrom-Json
        $ledgerObject.PSObject.Properties.Remove("outcome_proof")
        $ledger = $ledgerObject | ConvertTo-Json -Depth 16 -Compress
        $result = Invoke-JsonScript -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $ledger)
        Assert-True (-not $result.ok -and $result.reason -match "outcome[_ ]proof") "expected setup validation to require outcome proof"
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

    Invoke-Scenario "orchestrated worker mode is owned by orchestrate-issues" {
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "orchestrated-worker"))
        Assert-True (-not $result.ok -and $result.reason -match "orchestrate-issues") "expected worker mode to route to orchestrate-issues"

        $ledger = New-SetupLedger -Extra ([pscustomobject]@{
            execution_decision = (New-ExecutionDecision -SelectedMode "orchestrated-worker" | ConvertFrom-Json)
        })
        $validation = Invoke-JsonScript -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $ledger)
        Assert-True (-not $validation.ok -and $validation.reason -match "orchestrate-issues") "expected setup validation to reject worker mode"
    }

    Invoke-Scenario "happy setup passes with structured native goal proof" {
        $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "inline"))
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.setup_ledger.goal_id -eq "thread-goal") "missing goal id in setup ledger"
        Assert-True (-not ($result.setup_ledger.PSObject.Properties.Name -contains "goal_board_path")) "setup ledger must not contain goal_board_path"
    }

    Invoke-Scenario "happy PR-ready handoff marks resolve goal complete" {
        $prReady = New-PrReadyLedger
        $result = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", $prReady)
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.evidence.goal_status -eq "complete") "resolve goal completion was not recorded"
    }

    Invoke-Scenario "collect-pr-ready-ledger emits gate-ready temp ledger" {
        $outputDir = Join-Path $tempRoot "pr-ready-ledger-output"
        $setupPath = Join-Path $tempRoot "setup-ledger.json"
        New-SetupLedger | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
        $pr = @{
            url = "https://github.com/example/repo/pull/5"
            state = "OPEN"
            body = "Closes #12"
            closingIssuesReferences = @(@{ number = 12 })
        } | ConvertTo-Json -Depth 12 -Compress
        $acceptance = @(
            @{ criterion = "Sample issue is resolved"; evidence = "fixture coverage" }
        ) | ConvertTo-Json -Depth 8 -Compress
        $handoff = @{
            source = "worker-final-message"
            status = "sent"
            recipient = "main-thread-orchestrator"
        } | ConvertTo-Json -Depth 8 -Compress
        $goalCompletion = @{
            source = "update_goal"
            status = "complete"
            issue_url = "https://github.com/example/repo/issues/12"
        } | ConvertTo-Json -Depth 8 -Compress
        $pushPermission = New-PushPermission
        $collected = Invoke-JsonScript -ScriptName "collect-pr-ready-ledger.ps1" -Arguments @(
            "-RepoRoot", $repo,
            "-SetupLedgerPath", $setupPath,
            "-PrJson", $pr,
            "-VerificationCommands", "pwsh -NoProfile -Command 'exit 0'",
            "-PushPermissionJson", $pushPermission,
            "-AcceptanceCoverageJson", $acceptance,
            "-HandoffProofJson", $handoff,
            "-ReadinessReviewJson", (New-ReadinessReview | ConvertTo-Json -Depth 8 -Compress),
            "-GoalCompletionProofJson", $goalCompletion,
            "-OutputDir", $outputDir
        )
        Assert-True ($collected.ok) $collected.reason
        Assert-True (Test-Path -LiteralPath $collected.ledger_path -PathType Leaf) "collector did not write ledger path"
        Assert-True ($collected.ledger_path.StartsWith($outputDir, [StringComparison]::OrdinalIgnoreCase)) "collector did not honor OutputDir"
        $result = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerPath", $setupPath, "-PrReadyLedgerPath", $collected.ledger_path)
        Assert-True ($result.ok) $result.reason
    }

    Invoke-Scenario "collect-pr-ready-ledger defaults generated ledgers to temp" {
        $setupPath = Join-Path $tempRoot "setup-ledger-default.json"
        New-SetupLedger | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
        $pr = @{
            url = "https://github.com/example/repo/pull/5"
            state = "OPEN"
            body = "Closes #12"
            closingIssuesReferences = @(@{ number = 12 })
        } | ConvertTo-Json -Depth 12 -Compress
        $acceptance = @(@{ criterion = "Sample issue is resolved"; evidence = "fixture coverage" }) | ConvertTo-Json -Depth 8 -Compress
        $handoff = @{ source = "worker-final-message"; status = "sent"; recipient = "main-thread-orchestrator" } | ConvertTo-Json -Depth 8 -Compress
        $goalCompletion = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" } | ConvertTo-Json -Depth 8 -Compress
        $pushPermission = New-PushPermission
        $collected = Invoke-JsonScript -ScriptName "collect-pr-ready-ledger.ps1" -Arguments @(
            "-RepoRoot", $repo,
            "-SetupLedgerPath", $setupPath,
            "-PrJson", $pr,
            "-VerificationCommands", "pwsh -NoProfile -Command 'exit 0'",
            "-PushPermissionJson", $pushPermission,
            "-AcceptanceCoverageJson", $acceptance,
            "-HandoffProofJson", $handoff,
            "-ReadinessReviewJson", (New-ReadinessReview | ConvertTo-Json -Depth 8 -Compress),
            "-GoalCompletionProofJson", $goalCompletion
        )
        Assert-True ($collected.ok) $collected.reason
        Assert-True (Test-Path -LiteralPath $collected.ledger_path -PathType Leaf) "collector did not write default temp ledger"
        $tempPath = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $ledgerPath = [IO.Path]::GetFullPath([string]$collected.ledger_path)
        $repoPath = [IO.Path]::GetFullPath($repo)
        Assert-True ($ledgerPath.StartsWith($tempPath, [StringComparison]::OrdinalIgnoreCase)) "default ledger path was not under temp"
        Assert-True (-not $ledgerPath.StartsWith($repoPath, [StringComparison]::OrdinalIgnoreCase)) "default ledger path must not be inside repo"
    }

    Invoke-Scenario "collect-continuation-ledger emits structured stop ledger" {
        $outputDir = Join-Path $tempRoot "resolve-continuation-output"
        $collected = Invoke-JsonScript -ScriptName "collect-continuation-ledger.ps1" -Arguments @(
            "-RepoRoot", $repo,
            "-QuestionId", "project_resolve_next_step",
            "-Prompt", "Should I continue on with the workflow?",
            "-Source", "request_user_input",
            "-SelectedOptionId", "stop",
            "-RecommendedOptionId", "integrate-resolved-issue",
            "-TerminalState", "stop",
            "-OptionIds", "integrate-resolved-issue,review-revise-pr-ready-work,stop",
            "-OutputDir", $outputDir
        )
        Assert-True ($collected.ok) $collected.reason
        Assert-True (Test-Path -LiteralPath $collected.ledger_path -PathType Leaf) "collector did not write continuation ledger"
        Assert-True ([string]$collected.ledger.skill -eq "resolve-issue") "continuation ledger missing resolve-issue skill"
        Assert-True ([string]$collected.ledger.terminal_state -eq "stop") "continuation ledger did not record stop terminal state"
    }

    Invoke-Scenario "PR-ready handoff rejects missing push permission" {
        $prReadyObject = New-PrReadyLedger | ConvertFrom-Json
        $prReadyObject.PSObject.Properties.Remove("push_permission")
        $prReady = $prReadyObject | ConvertTo-Json -Depth 16 -Compress
        $result = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", $prReady)
        Assert-True (-not $result.ok -and $result.reason -match "push[_ ]permission") "expected missing push permission failure"
    }

    Invoke-Scenario "PR-ready handoff rejects missing readiness review" {
        $prReadyObject = New-PrReadyLedger | ConvertFrom-Json
        $prReadyObject.PSObject.Properties.Remove("readiness_review")
        $prReady = $prReadyObject | ConvertTo-Json -Depth 16 -Compress
        $result = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", $prReady)
        Assert-True (-not $result.ok -and $result.reason -match "readiness[_ ]review") "expected missing readiness review failure"
    }

    Invoke-Scenario "resolve terminal closeout blocks missing continuation ledger" {
        $prReady = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", (New-PrReadyLedger))
        Assert-True ($prReady.ok) $prReady.reason
        $result = Invoke-JsonScript -ScriptName "validate-terminal-closeout.ps1" -Arguments @(
            "-RepoRoot", $repo,
            "-PrReadyResultJson", ($prReady | ConvertTo-Json -Depth 16 -Compress)
        )
        Assert-True (-not $result.ok -and $result.reason -match "continuation decision") "expected missing continuation ledger to block resolve termination"
    }

    Invoke-Scenario "resolve terminal closeout blocks non-terminal continuation" {
        $prReady = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", (New-PrReadyLedger))
        Assert-True ($prReady.ok) $prReady.reason
        $result = Invoke-JsonScript -ScriptName "validate-terminal-closeout.ps1" -Arguments @(
            "-RepoRoot", $repo,
            "-PrReadyResultJson", ($prReady | ConvertTo-Json -Depth 16 -Compress),
            "-ContinuationDecisionJson", (New-ResolveContinuationDecision -QuestionId "project_resolve_integration_route" -SelectedOptionId "merge" -RecommendedOptionId "merge" -TerminalState "continue" -OptionIds @("merge", "continue-another-issue", "stop"))
        )
        Assert-True (-not $result.ok -and $result.reason -match "cannot terminate") "expected non-terminal continuation route to block resolve termination"
    }

    Invoke-Scenario "resolve terminal closeout accepts explicit stop" {
        $prReady = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", (New-PrReadyLedger))
        Assert-True ($prReady.ok) $prReady.reason
        $result = Invoke-JsonScript -ScriptName "validate-terminal-closeout.ps1" -Arguments @(
            "-RepoRoot", $repo,
            "-PrReadyResultJson", ($prReady | ConvertTo-Json -Depth 16 -Compress),
            "-ContinuationDecisionJson", (New-ResolveContinuationDecision)
        )
        Assert-True ($result.ok) $result.reason
        Assert-True ($result.evidence.terminal_state -eq "stop") "resolve terminal closeout did not record stop evidence"
    }

    Invoke-Scenario "skill text declares native goal state machine" {
        $text = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
        foreach ($needle in @("repo gate", "issue mirror validation", "source plan validation", "Outcome Summary", "outcome proof", "readiness review", "native goal activation", "Superpowers execution", "PR-ready validation", "project_resolve_push_permission", "GoalBuddy boards are outside the default execution model", "Auto Mode authorization ledger", "project_auto_mode_authorization", "the plugin-provided Auto Mode validator", "bounded-auto-merge", "recorded defaults", "stop outside policy")) {
            Assert-True ($text.Contains($needle)) "missing skill text: $needle"
        }
        foreach ($needle in @(
            "direct current-thread",
            "orchestrate-issues",
            "project_issue_resolution_route",
            "request_user_input",
            "debug_question_mode",
            "using-git-worktrees",
            "test-driven-development",
            "verification-before-completion",
            "finishing-a-development-branch",
            "collect-pr-ready-ledger.ps1",
            "collect-continuation-ledger.ps1",
            "Temp Plus Evidence",
            "generated ledgers passed to existing gates",
            "no hand-authored JSON requirement",
            "main thread orchestrator",
            "merge-changes",
            "validate-terminal-closeout.ps1",
            'explicit `Stop`',
            "## Native Continuation Gate",
            "helper-required findings summary",
            "artifact review gate",
            "verification evidence",
            "broader project context",
            "recommended next route",
            "branch push proof",
            "handoff proof",
            "native goal completion proof",
            "Do not ask for push approval first and explain later",
            "project_resolve_next_step",
            "Merge",
            "Resolve Another",
            "Review First",
            "Stop",
            "start the selected next skill"
        )) {
            Assert-True ($text.Contains($needle)) "missing resolver workflow text: $needle"
        }
    }

    Invoke-Scenario "metadata declares executable continuation routing" {
        $metadata = Get-Content -LiteralPath (Join-Path $skillRoot "agents\openai.yaml") -Raw
        foreach ($needle in @("summarize", "artifact review gate", "Outcome Summary", "outcome_proof", "readiness review", "plan_alignment", "reality_evidence", "verification evidence", "broader project context", "recommended next route", "machine-readable artifacts", "project_resolve_next_step", "top-level continuation gate", "docs/superpowers/workflow-contract.yml", "child routes", "starting the selected next skill", "project_resolve_push_permission", "Auto Mode authorization ledger", "project_auto_mode_authorization", "bounded-auto-merge", "collect-continuation-ledger.ps1", "validate-terminal-closeout.ps1", "explicit Stop")) {
            Assert-True ($metadata.Contains($needle)) "missing metadata continuation route: $needle"
        }
    }

    
    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $text = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
        $metadata = Get-Content -LiteralPath (Join-Path $skillRoot "agents\openai.yaml") -Raw
        $globalPolicyNeedles = @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )
        foreach ($needle in $globalPolicyNeedles) {
            Assert-True (-not $text.Contains($needle)) "SKILL.md duplicates helper-owned global policy instead of compact contract reference: $needle"
            Assert-True (-not $metadata.Contains($needle)) "metadata duplicates native continuation policy instead of compact contract reference: $needle"
        }
        foreach ($needle in @(
            "skills/advanced-user-input/SKILL.md",
            "global native question geometry",
            "route-specific question IDs",
            "selected answers are executable routing"
        )) {
            Assert-True ($text.Contains($needle)) "missing compact native continuation helper reference: $needle"
        }
        foreach ($needle in @(
            "docs/superpowers/workflow-contract.yml",
            "project_resolve_next_step",
            "project_resolve_push_permission",
            "Push And Open PR",
            "Hold",
            "starting the selected next skill"
        )) {
            Assert-True ($metadata.Contains($needle)) "missing compact continuation metadata: $needle"
        }

        $questionIds = [regex]::Matches($text, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $text.Length }
            $block = $text.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            Assert-True (-not $block.Contains('Right: terminal option: break the continuation loop.')) "nested question $questionId must not repeat stale terminal label"
        }
        Assert-True (-not $metadata.Contains("Right terminal label")) "metadata must not use old Right terminal label wording"
    }
$failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
