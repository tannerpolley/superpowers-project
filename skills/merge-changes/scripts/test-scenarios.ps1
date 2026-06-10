[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptRoot
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("merge-changes-ledgers-" + [guid]::NewGuid().ToString("N"))
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Name, [bool]$Ok, [string]$Reason) $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason }) }
function Invoke-Scenario { param([string]$Name, [scriptblock]$Body) try { & $Body; Add-Result -Name $Name -Ok $true -Reason "passed" } catch { Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message } }
function Assert-Contains { param([string]$Text, [string]$Needle, [string]$Message) if (-not $Text.Contains($Needle)) { throw $Message } }

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
    param([string]$Mode = "pr-issue", [switch]$Orchestrated)
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

function New-VerificationLedger {
    @{
        required_checks_policy = "require-existing"
        acceptance_criteria_closeout_proof = $true
        changed_files_covered = @("src/example.txt", "docs/superpowers/issues/12-sample.md")
        verification_exemptions = @()
        proof_commands = @("pwsh -NoProfile -Command 'exit 0'")
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-LocalBranchVerificationLedger {
    @{
        proof_commands = @("pwsh -NoProfile -Command 'exit 0'")
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

function New-MirrorCleanupConfirmation {
    param(
        [bool]$Deleted = $true,
        [bool]$Retained = $false,
        [string]$Policy = "delete-after-close",
        [string]$RetentionReason = "",
        [string]$MilestoneRecord = "closed-summary"
    )
    @{
        policy = $Policy
        issue_mirror = "docs/superpowers/issues/12-sample.md"
        deleted = $Deleted
        retained = $Retained
        retention_reason = $RetentionReason
        milestone_record = $MilestoneRecord
        milestone_summary = @{
            milestone_page = "docs/superpowers/milestones/M1-source-of-truth.md"
            issue_url = "https://github.com/example/repo/issues/12"
            pr_url = "https://github.com/example/repo/pull/5"
        }
    }
}

function New-OrchestratedWorkerCloseout {
    param([bool]$Archived = $true, [bool]$RemovedAfterArchive = $true)
    @{
        worker_thread = @{
            thread_id = "thread-worker-12"
            thread_title = "Resolve #12: Sample issue"
            worktree_path = "C:/tmp/sample-worktree"
        }
        worker_thread_archival_proof = @{
            source = "thread archive tool"
            archived = $Archived
            archived_after_merge = $Archived
        }
        physical_worktree_folder_cleanup = @{
            removed = $true
            target_inside_owned_worktree_root = $true
            removed_after_thread_archive = $RemovedAfterArchive
            removed_before_thread_archive = (-not $RemovedAfterArchive)
        }
    }
}

Invoke-Scenario "skill frontmatter is valid" {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    $text = Get-Content -LiteralPath $skillFile -Raw
    Assert-Contains $text "name: merge-changes" "missing skill name"
    Assert-Contains $text "description: Use when" "description must start with Use when"
    Assert-Contains $text "# Project Merge" "missing skill title"
}

Invoke-Scenario "merge contract text is present" {
    $text = Get-Content -LiteralPath $skillFile -Raw
    foreach ($needle in @(
        "issue-backed PR URL",
        "main orchestrator",
        "request_user_input",
        "Auto Mode authorization ledger",
        "project_auto_mode_authorization",
        "the repo-root Auto Mode contract helper",
        "bounded-auto-merge",
        "recorded defaults",
        "preauthorized-after-clean-premerge",
        "stop outside policy",
        "project_merge_approval",
        "Merge",
        "Decline",
        "premerge.ps1",
        "closeout.ps1",
        "git fetch --prune",
        "cleanup hook",
        "collect-premerge-ledger.ps1",
        "collect-closeout-ledger.ps1",
        "collect-continuation-ledger.ps1",
        "Temp Plus Evidence",
        "generated ledgers passed to existing gates",
        "no hand-authored JSON requirement",
        "validate-terminal-closeout.ps1",
        'explicit `Stop`',
        'verified final `Done`',
        "git status --short",
        "Do not merge without native UI approval",
        "## Native Question Debug Mode",
        "debug_question_mode",
        "waitingOnUserInput",
        "Native Question Debug Ledger",
        "recommended-default",
        "user-provided-debug-answer",
        "Debug mode must not",
        "## Native Continuation Gate",
        "summarize",
        "artifact review gate",
        "verification evidence",
        "broader project context",
        "recommended next route",
        "machine-readable artifacts",
        "Do not ask for approval first and explain later",
        "project_merge_next_step",
        "Run Align",
        "Resolve Another",
        "Review Closeout",
        "Stop",
        "start the selected next skill",
        "pr-issue",
        "local-branch",
        "## Reassessment Routing",
        "Reassess Plan",
        "Reassess Spec",
        "request_agent_input"
    )) {
        Assert-Contains $text $needle "missing merge-changes contract: $needle"
    }
}

Invoke-Scenario "metadata is present" {
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $metadata = Get-Content -LiteralPath $metadataFile -Raw
    Assert-Contains $metadata "default_prompt:" "missing metadata default_prompt"
    Assert-Contains $metadata "issue-backed PR URL" "missing PR intake"
    Assert-Contains $metadata "request_user_input" "missing native UI merge gate"
    foreach ($needle in @("summarize", "artifact review gate", "verification evidence", "broader project context", "recommended next route", "machine-readable artifacts", "project_merge_next_step", "Run Align", "Resolve Another", "Review Closeout", "Stop", "start the selected next skill", "collect-continuation-ledger.ps1", "validate-terminal-closeout.ps1", "explicit Stop", "verified final Done")) {
        Assert-Contains $metadata $needle "missing metadata continuation route: $needle"
    }
    foreach ($needle in @("pr-issue", "local-branch", "Reassess Plan", "Reassess Spec", "request_agent_input", "Auto Mode authorization ledger", "project_auto_mode_authorization", "bounded-auto-merge", "preauthorized-after-clean-premerge")) {
        Assert-Contains $metadata $needle "missing metadata merge mode route: $needle"
    }
}

Invoke-Scenario "premerge accepts happy fixture" {
    $pr = @{
        url = "https://github.com/example/repo/pull/5"
        state = "OPEN"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "local-proof"; state = "SUCCESS"; conclusion = "SUCCESS" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/superpowers/issues/12-sample.md" })
    } | ConvertTo-Json -Depth 12 -Compress
    $issue = @{ state = "OPEN"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-VerificationLedgerJson", (New-VerificationLedger), "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "premerge accepts pr-issue with issue closure policy" {
    $pr = @{
        url = "https://github.com/example/repo/pull/5"
        state = "OPEN"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "local-proof"; state = "SUCCESS"; conclusion = "SUCCESS" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/superpowers/issues/12-sample.md" })
    } | ConvertTo-Json -Depth 12 -Compress
    $issue = @{ state = "OPEN"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger -Mode "pr-issue"), "-VerificationLedgerJson", (New-VerificationLedger), "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
    if ([string]$result.evidence.mode -ne "pr-issue") { throw "premerge did not record pr-issue mode" }
}

Invoke-Scenario "premerge accepts local-branch with clean synced main and validation proof" {
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-LocalBranchSetupLedger), "-VerificationLedgerJson", (New-LocalBranchVerificationLedger))
    if (-not $result.ok) { throw $result.reason }
    if ([string]$result.evidence.mode -ne "local-branch") { throw "premerge did not record local-branch mode" }
}

Invoke-Scenario "premerge rejects non-issue PR mode" {
    $setup = @{
        merge_mode = "pr-no-issue"
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/non-issue-work"
    } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", $setup, "-VerificationLedgerJson", (New-VerificationLedger))
    if ($result.ok -or $result.reason -notmatch "pr-issue, local-branch") { throw "expected obsolete pr-no-issue mode to block" }
}

Invoke-Scenario "premerge rejects local-branch when main is not clean synced" {
    $verification = (New-LocalBranchVerificationLedger | ConvertFrom-Json)
    $verification.clean_synced_main_proof.behind = 1
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-LocalBranchSetupLedger), "-VerificationLedgerJson", ($verification | ConvertTo-Json -Depth 12 -Compress))
    if ($result.ok -or $result.reason -notmatch "clean synced main") { throw "expected dirty or stale main proof to block" }
}

Invoke-Scenario "premerge allows explicitly optional skipped check" {
    $verification = (New-VerificationLedger | ConvertFrom-Json)
    $verification | Add-Member -NotePropertyName "optional_checks" -NotePropertyValue @("docs")
    $verification.changed_files_covered = @("src/example.txt")
    $verificationJson = $verification | ConvertTo-Json -Depth 12 -Compress
    $pr = @{
        url = "https://github.com/example/repo/pull/5"
        state = "OPEN"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "docs"; status = "COMPLETED"; conclusion = "SKIPPED" })
        files = @(@{ path = "src/example.txt" })
    } | ConvertTo-Json -Depth 12 -Compress
    $issue = @{ state = "OPEN"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-VerificationLedgerJson", $verificationJson, "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "premerge blocks skipped required check" {
    $pr = @{
        url = "https://github.com/example/repo/pull/5"
        state = "OPEN"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "unit"; status = "COMPLETED"; conclusion = "SKIPPED" })
        files = @(@{ path = "src/example.txt" })
    } | ConvertTo-Json -Depth 12 -Compress
    $issue = @{ state = "OPEN"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-VerificationLedgerJson", (New-VerificationLedger), "-PrJson", $pr, "-IssueJson", $issue)
    if ($result.ok -or $result.reason -notmatch "skipped") { throw "expected skipped required check to block" }
}

Invoke-Scenario "merge approval blocks declined decision" {
    $premerge = @{ ok = $true; phase = "premerge"; reason = "passed"; evidence = @{} } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "validate-merge-decision.ps1" -Arguments @("-PremergeResultJson", $premerge, "-MergeDecisionJson", (New-MergeDecision -SelectedAction "decline"))
    if ($result.ok -or $result.reason -notmatch "declined") { throw "expected declined merge decision to block" }
}

Invoke-Scenario "happy closeout records clean proof" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
        linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
        resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
        mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
    } | ConvertTo-Json -Depth 16 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
    if ($result.evidence.repo_clean -ne $true) { throw "clean proof was not recorded" }
}

Invoke-Scenario "orchestrated closeout requires worker archival before folder removal" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
        linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
        resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
        mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
        orchestrated_worker_closeout = New-OrchestratedWorkerCloseout
    } | ConvertTo-Json -Depth 20 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger -Orchestrated), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "orchestrated closeout blocks missing archival proof" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
        linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
        resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
        mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
    } | ConvertTo-Json -Depth 20 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger -Orchestrated), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if ($result.ok -or $result.reason -notmatch "orchestrated_worker_closeout") { throw "expected missing archival proof to block" }
}

Invoke-Scenario "orchestrated closeout blocks folder deletion before archival" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
        linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
        resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
        mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
        orchestrated_worker_closeout = New-OrchestratedWorkerCloseout -RemovedAfterArchive $false
    } | ConvertTo-Json -Depth 20 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger -Orchestrated), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if ($result.ok -or $result.reason -notmatch "after worker thread archival|before worker thread archival") { throw "expected folder deletion order to block" }
}

Invoke-Scenario "local-branch closeout requires native approval validation cleanup and clean repo proof" {
    $completion = @{
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        local_merge_confirmation = @{ source = "git merge"; exit_code = 0; merged_branch = "codex/local-branch-work" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        validation_proof = @{ command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $false; only_goal_owned_removed = $true; local_delete_target = "codex/local-branch-work"; remote_delete_target = ""; remote_deleted_branches = @() }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/local-branch-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
    } | ConvertTo-Json -Depth 16 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-LocalBranchSetupLedger), "-CompletionLedgerJson", $completion)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "closeout blocks closed issue without mirror cleanup evidence" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
        linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
        resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
    } | ConvertTo-Json -Depth 16 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if ($result.ok -or $result.reason -notmatch "mirror cleanup") { throw "expected missing mirror cleanup evidence to block" }
}

Invoke-Scenario "closeout accepts explicit retained mirror evidence" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        merge_decision = (New-MergeDecision | ConvertFrom-Json)
        merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
        linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
        default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
        branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
        worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
        fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
        cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
        clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
        resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
        mirror_cleanup_confirmation = New-MirrorCleanupConfirmation -Deleted $false -Retained $true -Policy "retain" -RetentionReason "audit fixture"
    } | ConvertTo-Json -Depth 16 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "collect-premerge-ledger emits evidence accepted by premerge" {
    $repo = New-TestRepo
    $setupPath = Join-Path $tempRoot "premerge-setup-ledger.json"
    New-SetupLedger | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
    $pr = @{
        url = "https://github.com/example/repo/pull/5"
        state = "OPEN"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "local-proof"; state = "SUCCESS"; conclusion = "SUCCESS" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/superpowers/issues/12-sample.md" })
    } | ConvertTo-Json -Depth 12 -Compress
    $issue = @{ state = "OPEN"; body = "- [ ] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $outputDir = Join-Path $tempRoot "premerge-output"
    $collected = Invoke-JsonScript -ScriptName "collect-premerge-ledger.ps1" -Arguments @(
        "-RepoRoot", $repo,
        "-SetupLedgerPath", $setupPath,
        "-PrJson", $pr,
        "-IssueJson", $issue,
        "-VerificationCommands", "pwsh -NoProfile -Command 'exit 0'",
        "-ChangedFilesCovered", "src/example.txt,docs/superpowers/issues/12-sample.md",
        "-OutputDir", $outputDir
    )
    if (-not $collected.ok) { throw $collected.reason }
    if (-not (Test-Path -LiteralPath $collected.ledger_path -PathType Leaf)) { throw "collector did not write premerge ledger" }
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerPath", $setupPath, "-VerificationLedgerPath", $collected.ledger_path, "-PrJson", $collected.pr_json, "-IssueJson", $collected.issue_json)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "collect-closeout-ledger emits evidence accepted by closeout" {
    $repo = New-TestRepo
    $setupPath = Join-Path $tempRoot "closeout-setup-ledger.json"
    New-SetupLedger | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $goal = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" } | ConvertTo-Json -Depth 8 -Compress
    $mirrorCleanup = New-MirrorCleanupConfirmation -Deleted $false -Retained $true -Policy "retain" -RetentionReason "fixture" | ConvertTo-Json -Depth 12 -Compress
    $outputDir = Join-Path $tempRoot "closeout-output"
    $collected = Invoke-JsonScript -ScriptName "collect-closeout-ledger.ps1" -Arguments @(
        "-RepoRoot", $repo,
        "-SetupLedgerPath", $setupPath,
        "-PrJson", $pr,
        "-IssueJson", $issue,
        "-MergeDecisionJson", (New-MergeDecision),
        "-CleanupHookOutput", "No matching leftover Codex processes under repo root.",
        "-ResolveGoalCompletionProofJson", $goal,
        "-MirrorCleanupJson", $mirrorCleanup,
        "-OutputDir", $outputDir
    )
    if (-not $collected.ok) { throw $collected.reason }
    if (-not (Test-Path -LiteralPath $collected.ledger_path -PathType Leaf)) { throw "collector did not write closeout ledger" }
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerPath", $setupPath, "-CompletionLedgerPath", $collected.ledger_path, "-PrJson", $collected.pr_json, "-IssueJson", $collected.issue_json)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "collect-closeout-ledger deletes closed mirror and records milestone summary by default" {
    $repo = New-TestRepo
    Add-SampleMirrorAndMilestone -Repo $repo
    $setupPath = Join-Path $tempRoot "closeout-default-setup-ledger.json"
    New-SetupLedger | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ number = 12; url = "https://github.com/example/repo/issues/12"; state = "CLOSED"; body = "- [x] Sample issue is resolved"; closedAt = "2026-06-03T01:00:00Z" } | ConvertTo-Json -Depth 8 -Compress
    $goal = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" } | ConvertTo-Json -Depth 8 -Compress
    $outputDir = Join-Path $tempRoot "closeout-default-output"
    $collected = Invoke-JsonScript -ScriptName "collect-closeout-ledger.ps1" -Arguments @(
        "-RepoRoot", $repo,
        "-SetupLedgerPath", $setupPath,
        "-PrJson", $pr,
        "-IssueJson", $issue,
        "-MergeDecisionJson", (New-MergeDecision),
        "-CleanupHookOutput", "No matching leftover Codex processes under repo root.",
        "-ResolveGoalCompletionProofJson", $goal,
        "-OutputDir", $outputDir
    )
    if (-not $collected.ok) { throw $collected.reason }
    if (Test-Path -LiteralPath (Join-Path $repo "docs/superpowers/issues/12-sample.md")) { throw "closed mirror was not deleted" }
    $milestone = Get-Content -LiteralPath (Join-Path $repo "docs/superpowers/milestones/M1-source-of-truth.md") -Raw
    Assert-Contains $milestone "## Closed Issues" "milestone closed issue section was not written"
    Assert-Contains $milestone "https://github.com/example/repo/issues/12" "milestone summary missing issue link"
    Assert-Contains $milestone "https://github.com/example/repo/pull/5" "milestone summary missing PR link"
    if ($collected.ledger.mirror_cleanup_confirmation.deleted -ne $true) { throw "collector did not record deletion evidence" }
    if ([string]$collected.ledger.mirror_cleanup_confirmation.milestone_record -ne "closed-summary") { throw "collector did not record closed-summary milestone evidence" }
}

Invoke-Scenario "collect-continuation-ledger emits structured stop ledger" {
    $repo = New-TestRepo
    $outputDir = Join-Path $tempRoot "merge-continuation-output"
    $collected = Invoke-JsonScript -ScriptName "collect-continuation-ledger.ps1" -Arguments @(
        "-RepoRoot", $repo,
        "-QuestionId", "project_merge_next_step",
        "-Prompt", "Should I continue on with the workflow?",
        "-Source", "request_user_input",
        "-SelectedOptionId", "stop",
        "-RecommendedOptionId", "continue-project-execution",
        "-TerminalState", "stop",
        "-OptionIds", "continue-project-execution,review-repair-closeout,stop",
        "-OutputDir", $outputDir
    )
    if (-not $collected.ok) { throw $collected.reason }
    if (-not (Test-Path -LiteralPath $collected.ledger_path -PathType Leaf)) { throw "collector did not write continuation ledger" }
    if ([string]$collected.ledger.skill -ne "merge-changes") { throw "continuation ledger missing merge-changes skill" }
    if ([string]$collected.ledger.terminal_state -ne "stop") { throw "continuation ledger did not record stop terminal state" }
}

Invoke-Scenario "merge terminal closeout blocks non-terminal continuation" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{}
    $completion.pr_url = "https://github.com/example/repo/pull/5"
    $completion.issue_url = "https://github.com/example/repo/issues/12"
    $completion.merge_decision = (New-MergeDecision | ConvertFrom-Json)
    $completion.merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
    $completion.linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
    $completion.default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
    $completion.branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
    $completion.worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
    $completion.fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
    $completion.cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
    $completion.clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
    $completion.resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
    $completion.mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
    $closeout = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", ($completion | ConvertTo-Json -Depth 20 -Compress), "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $closeout.ok) { throw $closeout.reason }
    $result = Invoke-JsonScript -ScriptName "validate-terminal-closeout.ps1" -Arguments @(
        "-RepoRoot", $tempRoot,
        "-CloseoutResultJson", ($closeout | ConvertTo-Json -Depth 20 -Compress),
        "-ContinuationDecisionJson", (New-MergeContinuationDecision -QuestionId "project_merge_continue_group" -SelectedOptionId "continue-issues" -RecommendedOptionId "continue-issues" -TerminalState "continue" -OptionIds @("continue-issues", "start-planning", "stop"))
    )
    if ($result.ok -or $result.reason -notmatch "cannot terminate") { throw "expected non-terminal merge continuation route to block terminal closeout" }
}

Invoke-Scenario "merge terminal closeout accepts explicit stop" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{}
    $completion.pr_url = "https://github.com/example/repo/pull/5"
    $completion.issue_url = "https://github.com/example/repo/issues/12"
    $completion.merge_decision = (New-MergeDecision | ConvertFrom-Json)
    $completion.merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
    $completion.linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
    $completion.default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
    $completion.branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
    $completion.worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
    $completion.fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
    $completion.cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
    $completion.clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
    $completion.resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
    $completion.mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
    $closeout = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", ($completion | ConvertTo-Json -Depth 20 -Compress), "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $closeout.ok) { throw $closeout.reason }
    $result = Invoke-JsonScript -ScriptName "validate-terminal-closeout.ps1" -Arguments @(
        "-RepoRoot", $tempRoot,
        "-CloseoutResultJson", ($closeout | ConvertTo-Json -Depth 20 -Compress),
        "-ContinuationDecisionJson", (New-MergeContinuationDecision)
    )
    if (-not $result.ok) { throw $result.reason }
    if ($result.evidence.terminal_state -ne "stop") { throw "merge terminal closeout did not record stop evidence" }
}

Invoke-Scenario "merge terminal closeout accepts verified final done" {
    $pr = @{ url = "https://github.com/example/repo/pull/5"; state = "MERGED"; body = "Closes #12" } | ConvertTo-Json -Depth 8 -Compress
    $issue = @{ state = "CLOSED"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $completion = @{}
    $completion.pr_url = "https://github.com/example/repo/pull/5"
    $completion.issue_url = "https://github.com/example/repo/issues/12"
    $completion.merge_decision = (New-MergeDecision | ConvertFrom-Json)
    $completion.merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
    $completion.linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
    $completion.default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
    $completion.branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
    $completion.worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
    $completion.fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
    $completion.cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
    $completion.clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
    $completion.resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
    $completion.mirror_cleanup_confirmation = New-MirrorCleanupConfirmation
    $closeout = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", ($completion | ConvertTo-Json -Depth 20 -Compress), "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $closeout.ok) { throw $closeout.reason }
    $result = Invoke-JsonScript -ScriptName "validate-terminal-closeout.ps1" -Arguments @(
        "-RepoRoot", $tempRoot,
        "-CloseoutResultJson", ($closeout | ConvertTo-Json -Depth 20 -Compress),
        "-ContinuationDecisionJson", (New-MergeContinuationDecision -QuestionId "project_merge_final_health_gate" -SelectedOptionId "done" -RecommendedOptionId "done" -TerminalState "done" -OptionIds @("done", "revisit", "stop"))
    )
    if (-not $result.ok) { throw $result.reason }
    if ($result.evidence.selected_option_id -ne "done") { throw "merge terminal closeout did not preserve done evidence" }
}


    try {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadataText = Get-Content -LiteralPath $metadataFile -Raw
        foreach ($needle in @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )) {
            if (-not $text.Contains($needle)) { throw "missing native continuation policy in SKILL.md: $needle" }
            if (-not $metadataText.Contains($needle)) { throw "missing native continuation policy in metadata: $needle" }
        }

        $questionIds = [regex]::Matches($text, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $text.Length }
            $block = $text.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: terminal option: break the continuation loop.')) { throw "nested question $questionId must not repeat stale terminal label" }
        }
        if ($metadataText.Contains("Right terminal label")) { throw "metadata must not use old Right terminal label wording" }
        Add-Result -Name "native continuation policy avoids nested stop routes" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "native continuation policy avoids nested stop routes" -Ok $false -Reason $_.Exception.Message }
$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
