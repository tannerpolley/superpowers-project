[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptRoot
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
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
    @{
        issue_url = "https://github.com/example/repo/issues/12"
        issue_mirror = "docs/superpowers/issues/12-sample.md"
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/sample-issue"
        goal_id = "thread-goal"
        goal_objective = "Implement issue to PR-ready evidence."
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

Invoke-Scenario "skill frontmatter is valid" {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    $text = Get-Content -LiteralPath $skillFile -Raw
    Assert-Contains $text "name: project-merge" "missing skill name"
    Assert-Contains $text "description: Use when" "description must start with Use when"
    Assert-Contains $text "# Project Merge" "missing skill title"
}

Invoke-Scenario "merge contract text is present" {
    $text = Get-Content -LiteralPath $skillFile -Raw
    foreach ($needle in @(
        "PR URL or worker handoff",
        "main orchestrator",
        "request_user_input",
        "project_merge_approval",
        "Merge",
        "Decline",
        "premerge.ps1",
        "closeout.ps1",
        "git fetch --prune",
        "cleanup hook",
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
        "project_merge_next_step",
        "Project Doctor",
        "Resolve Another",
        "Review First",
        "Stop",
        "start the selected next skill"
    )) {
        Assert-Contains $text $needle "missing project-merge contract: $needle"
    }
}

Invoke-Scenario "metadata is present" {
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $metadata = Get-Content -LiteralPath $metadataFile -Raw
    Assert-Contains $metadata "project-merge:" "missing metadata key"
    Assert-Contains $metadata "PR URL or worker handoff" "missing PR intake"
    Assert-Contains $metadata "request_user_input" "missing native UI merge gate"
    foreach ($needle in @("summarize", "project_merge_next_step", "Project Doctor", "Resolve Another", "Review First", "Stop", "start the selected next skill")) {
        Assert-Contains $metadata $needle "missing metadata continuation route: $needle"
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
    } | ConvertTo-Json -Depth 16 -Compress
    $result = Invoke-JsonScript -ScriptName "closeout.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-CompletionLedgerJson", $completion, "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
    if ($result.evidence.repo_clean -ne $true) { throw "clean proof was not recorded" }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
