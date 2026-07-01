[CmdletBinding()]
param()

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

function New-SetupLedger {
    param([string]$Mode = "pr-issue", [switch]$Orchestrated, [switch]$InlineNullWorkerFields)
    $ledger = @{
        merge_mode = $Mode
        issue_url = "https://github.com/example/repo/issues/12"
        issue_mirror = "docs/superpowers/issues/12-sample.md"
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/sample-issue"
        goal_id = "thread-goal"
        goal_objective = "Implement issue to PR-ready evidence."
    }
    if ($Orchestrated) {
        $ledger.merge_context = "orchestrated"
        $ledger.worker_thread_id = "thread-worker-12"
        $ledger.worker_identity = @{
            thread_title = "Resolve #12: Sample issue"
            branch = "codex/sample-issue"
            worktree_path = "C:/tmp/sample-worktree"
        }
    } elseif ($InlineNullWorkerFields) {
        $ledger.dynamic_work_packet_map = $null
        $ledger.worker_handoff = $null
    }
    $ledger | ConvertTo-Json -Depth 12 -Compress
}

function New-LocalBranchSetupLedger {
    @{
        merge_mode = "local-branch"
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/local-branch-work"
        goal_id = "thread-goal"
        goal_objective = "Implement approved local branch to merge-ready evidence."
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-ReadinessReview {
    [pscustomobject]@{
        plan_alignment = $true
        correctness = $true
        maintainability = $true
        reality_evidence = $true
    }
}

function New-VerificationLedger {
    @{
        required_checks_policy = "require-existing"
        acceptance_criteria_closeout_proof = $true
        changed_files_covered = @("src/example.txt", "docs/superpowers/issues/12-sample.md")
        verification_exemptions = @()
        proof_commands = @("pwsh -NoProfile -Command 'exit 0'")
        readiness_review = New-ReadinessReview
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-LocalBranchVerificationLedger {
    @{
        proof_commands = @("pwsh -NoProfile -Command 'exit 0'")
        readiness_review = New-ReadinessReview
        clean_synced_main_proof = @{
            source = "git status --short --branch"
            exit_code = 0
            branch = "main"
            upstream = "origin/main"
            ahead = 0
            behind = 0
            status_output = ""
        }
        validation_proof = @{
            command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1"
            exit_code = 0
        }
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-MergeDecision {
    param([string]$SelectedAction = "merge")
    @{
        question_id = "project_merge_approval"
        source = "request_user_input"
        selected_action = $SelectedAction
        recommended_action = "merge"
        options = @("merge", "decline")
    } | ConvertTo-Json -Depth 8 -Compress
}

function New-MergeContinuationDecision {
    param(
        [string]$QuestionId = "project_merge_next_step",
        [string]$SelectedOptionId = "stop",
        [string]$RecommendedOptionId = "continue-project-execution",
        [string]$TerminalState = "stop",
        [string[]]$OptionIds = @("continue-project-execution", "review-repair-closeout", "stop"),
        [string]$Source = "request_user_input"
    )
    @{
        skill = "merge-changes"
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

function New-TestRepo {
    $repo = Join-Path $tempRoot ("repo-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -b main | Out-Null
    & git -C $repo config user.email tests@example.invalid | Out-Null
    & git -C $repo config user.name "Project Merge Tests" | Out-Null
    & git -C $repo config core.autocrlf false | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "# Repo`n" -Encoding utf8NoBOM
    & git -C $repo add . | Out-Null
    & git -C $repo commit -m initial | Out-Null
    $repo
}

function Add-SampleMirrorAndMilestone {
    param([string]$Repo)
    New-Item -ItemType Directory -Path (Join-Path $Repo "docs/superpowers/issues") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Repo "docs/superpowers/milestones") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $Repo "docs/superpowers/issues/12-sample.md") -Value "# Sample`n`n**GitHub Issue:** https://github.com/example/repo/issues/12`n**GitHub Milestone:** M1 - Source Of Truth`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $Repo "docs/superpowers/milestones/M1-source-of-truth.md") -Value "# M1 - Source Of Truth`n`n## Related Issues`n`n- ``docs/superpowers/issues/12-sample.md```n" -Encoding utf8NoBOM
}
