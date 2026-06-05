$ErrorActionPreference = "Stop"

$githubChecksPath = $null
$cursor = $PSScriptRoot
while (-not [string]::IsNullOrWhiteSpace($cursor)) {
    $candidate = Join-Path $cursor "scripts\lib\github-checks.ps1"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $githubChecksPath = $candidate
        break
    }
    $parent = Split-Path -Parent $cursor
    if ($parent -eq $cursor) { break }
    $cursor = $parent
}
if ([string]::IsNullOrWhiteSpace($githubChecksPath)) {
    throw "shared GitHub check helper not found"
}
. $githubChecksPath

function Write-ContractResult {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{}
    )
    [ordered]@{ ok = $Ok; phase = $Phase; reason = $Reason; evidence = $Evidence } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Stop-Contract {
    param([string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    Write-ContractResult -Phase $Phase -Ok $false -Reason $Reason -Evidence $Evidence
}

function Complete-Contract {
    param([string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    Write-ContractResult -Phase $Phase -Ok $true -Reason $Reason -Evidence $Evidence
}

function Test-Property {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name)
    return $null -ne $Object -and ($Object.PSObject.Properties.Name -contains $Name)
}

function Read-JsonInput {
    param([string]$Json, [string]$Path, [string]$Name = "json")
    $text = $null
    if (-not [string]::IsNullOrWhiteSpace($Json)) {
        $text = $Json
    } elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name path not found: $Path" }
        $text = Get-Content -LiteralPath $Path -Raw
    } else {
        throw "Missing $Name input."
    }
    try { return ($text | ConvertFrom-Json) } catch { throw "Invalid $Name JSON: $($_.Exception.Message)" }
}

function Get-StringArray {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    @($Value | ForEach-Object { [string]$_ })
}

function Get-MergeMode {
    param($Setup)
    if (-not (Test-Property -Object $Setup -Name "merge_mode") -or [string]::IsNullOrWhiteSpace([string]$Setup.merge_mode)) {
        throw "setup ledger merge_mode is required"
    }
    $mode = [string]$Setup.merge_mode
    $allowedModes = @("pr-issue", "local-branch")
    if ($mode -notin $allowedModes) { throw "setup ledger merge_mode must be one of: $($allowedModes -join ', ')" }
    $mode
}

function Normalize-RepoPath {
    param([string]$Path)
    if ($null -eq $Path) { return "" }
    ($Path -replace '\\', '/').Trim()
}

function Assert-SourcePlanLinkage {
    param($Setup)
    if (-not (Test-Property -Object $Setup -Name "source_plan") -or [string]::IsNullOrWhiteSpace([string]$Setup.source_plan)) {
        throw "source plan linkage is required"
    }
    $plan = Normalize-RepoPath ([string]$Setup.source_plan)
    if ($plan -notmatch '^docs/superpowers/plans/.+\.md$') { throw "source plan must be under docs/superpowers/plans" }
}

function Assert-BranchLinkage {
    param($Setup)
    if (-not (Test-Property -Object $Setup -Name "branch") -or [string]::IsNullOrWhiteSpace([string]$Setup.branch)) {
        throw "branch name is required"
    }
}

function Resolve-RepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = "." }
    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) { throw "repo root does not exist: $RepoRoot" }
    [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
}

function Resolve-RepoFile {
    param([string]$RepoRoot, [string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-RelativeRepoPath {
    param([string]$RepoRoot, [string]$Path)
    Normalize-RepoPath ([IO.Path]::GetRelativePath($RepoRoot, (Resolve-RepoFile -RepoRoot $RepoRoot -Path $Path)))
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    $null
}

function Get-IssueNumberFromUrl {
    param([string]$IssueUrl)
    if ($IssueUrl -match '/issues/(?<n>\d+)(?:$|[?#])') { return [int]$Matches.n }
    $null
}

function Test-ClosingKeywordForIssue {
    param([string]$Body, [int]$IssueNumber)
    if ([string]::IsNullOrWhiteSpace($Body) -or $IssueNumber -le 0) { return $false }
    [bool]($Body -match "(?im)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#$IssueNumber(?!\d)\b")
}

function Test-ClosingReferenceIncludesIssue {
    param($References, [int]$IssueNumber)
    foreach ($reference in @($References)) {
        if ($null -ne $reference -and [int]$reference.number -eq $IssueNumber) { return $true }
    }
    $false
}

function Assert-MergeDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "merge decision is required" }
    if ($Decision -is [string]) { throw "merge decision must be structured, not a string" }
    foreach ($field in @("question_id", "source", "selected_action", "recommended_action", "options")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "merge decision missing $field" }
    }
    if ([string]$Decision.question_id -ne "project_merge_approval") { throw "merge decision question_id mismatch" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "merge decision source must be request_user_input or debug_question_mode" }
    if ([string]$Decision.selected_action -notin @("merge", "decline")) { throw "merge decision selected_action must be merge or decline" }
    if ([string]$Decision.recommended_action -ne "merge") { throw "merge decision recommended_action must be merge after clean premerge proof" }
    $options = Get-StringArray $Decision.options
    foreach ($requiredOption in @("merge", "decline")) {
        if ($options -notcontains $requiredOption) { throw "merge decision options must include $requiredOption" }
    }
    if ([string]$Decision.selected_action -eq "decline") { throw "merge declined by user" }
}

function Assert-MergeContinuationDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "continuation decision is required" }
    if ($Decision -is [string]) { throw "continuation decision must be structured, not a string" }
    foreach ($field in @("skill", "question_id", "prompt", "source", "selected_option_id", "recommended_option_id", "option_ids", "terminal_state")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "continuation decision missing $field" }
    }
    if ([string]$Decision.skill -ne "merge-changes") { throw "continuation decision skill must be merge-changes" }
    $questionId = [string]$Decision.question_id
    $allowedQuestionIds = @(
        "project_merge_final_health_gate",
        "project_merge_next_step",
        "project_merge_continue_group",
        "project_merge_issue_route",
        "project_merge_planning_route",
        "project_merge_reiteration_group",
        "project_merge_repair_route",
        "project_merge_repair_cleanup_route"
    )
    if ($questionId -notin $allowedQuestionIds) { throw "continuation decision question_id is not recognized for merge-changes" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "continuation decision source must be request_user_input or debug_question_mode" }
    $selectedOptionId = [string]$Decision.selected_option_id
    $recommendedOptionId = [string]$Decision.recommended_option_id
    $optionIds = Get-StringArray $Decision.option_ids
    if ($optionIds.Count -eq 0) { throw "continuation decision option_ids must be populated" }
    if ($optionIds -notcontains $selectedOptionId) { throw "continuation decision selected_option_id must appear in option_ids" }
    if ($optionIds -notcontains $recommendedOptionId) { throw "continuation decision recommended_option_id must appear in option_ids" }
    $terminalState = [string]$Decision.terminal_state
    if ($terminalState -notin @("stop", "done", "continue", "revisit")) { throw "continuation decision terminal_state must be stop, done, continue, or revisit" }
    if ($selectedOptionId -eq "stop" -and $terminalState -ne "stop") { throw "continuation decision stop must use terminal_state stop" }
    if ($selectedOptionId -eq "done" -and $terminalState -ne "done") { throw "continuation decision done must use terminal_state done" }
}

function Assert-MergeTerminalContinuationDecision {
    param($Decision)
    Assert-MergeContinuationDecision -Decision $Decision
    $selectedOptionId = [string]$Decision.selected_option_id
    $terminalState = [string]$Decision.terminal_state
    if ($selectedOptionId -eq "stop" -and $terminalState -eq "stop") { return }
    if ($selectedOptionId -eq "done" -and $terminalState -eq "done" -and [string]$Decision.question_id -eq "project_merge_final_health_gate") { return }
    if ($terminalState -eq "done" -or $selectedOptionId -eq "done") {
        throw "merge-changes Done is valid only from project_merge_final_health_gate after clean closeout proof"
    }
    throw "merge-changes cannot terminate on continuation decision '$selectedOptionId'; continue the selected route or record explicit Stop"
}

function Assert-CleanRepoProof {
    param($Proof)
    if ($null -eq $Proof -or $Proof -is [string]) { throw "clean repo proof must be structured" }
    foreach ($field in @("source", "exit_code", "status_output")) {
        if (-not (Test-Property -Object $Proof -Name $field)) { throw "clean repo proof missing $field" }
    }
    if ([int]$Proof.exit_code -ne 0) { throw "clean repo proof command must pass" }
    if (-not [string]::IsNullOrWhiteSpace([string]$Proof.status_output)) { throw "repo status must be clean" }
}

function Assert-CleanSyncedMainProof {
    param($Proof)
    if ($null -eq $Proof -or $Proof -is [string]) { throw "clean synced main proof must be structured" }
    foreach ($field in @("source", "exit_code", "branch", "upstream", "ahead", "behind", "status_output")) {
        if (-not (Test-Property -Object $Proof -Name $field)) { throw "clean synced main proof missing $field" }
    }
    if ([int]$Proof.exit_code -ne 0) { throw "clean synced main proof command must pass" }
    if ([string]$Proof.branch -ne "main") { throw "clean synced main proof must be for main" }
    if ([string]$Proof.upstream -ne "origin/main") { throw "clean synced main proof must compare origin/main" }
    if ([int]$Proof.ahead -ne 0 -or [int]$Proof.behind -ne 0) { throw "clean synced main proof must show main even with origin/main" }
    if (-not [string]::IsNullOrWhiteSpace([string]$Proof.status_output)) { throw "clean synced main proof requires clean status" }
}

function Assert-ValidationProof {
    param($Proof)
    if ($null -eq $Proof -or $Proof -is [string]) { throw "validation proof must be structured" }
    foreach ($field in @("command", "exit_code")) {
        if (-not (Test-Property -Object $Proof -Name $field)) { throw "validation proof missing $field" }
    }
    if ([int]$Proof.exit_code -ne 0) { throw "validation proof must pass" }
}

function Assert-PrVerification {
    param($Verification, $Pr)
    $policy = if (Test-Property -Object $Verification -Name "required_checks_policy") { [string]$Verification.required_checks_policy } else { "require-existing" }
    $checks = @($Pr.requiredChecks)
    $checkResult = Test-GitHubRequiredChecks `
        -Checks $checks `
        -Policy $policy `
        -RequiredCheckNames (Get-StringArray $Verification.required_checks) `
        -OptionalCheckNames (Get-StringArray $Verification.optional_checks)
    if (-not $checkResult.ok) { throw $checkResult.reason }
    $covered = Get-StringArray $Verification.changed_files_covered
    $exempt = Get-StringArray $Verification.verification_exemptions
    foreach ($file in @($Pr.files)) {
        $path = Normalize-RepoPath ([string]$file.path)
        if ($covered -notcontains $path -and $exempt -notcontains $path) { throw "source plan verification receipts must cover PR changed file: $path" }
    }
    if ((Get-StringArray $Verification.proof_commands).Count -eq 0) { throw "verification proof commands are required" }
}

function Test-AnyIssueClosureClaim {
    param($Pr)
    if ($null -eq $Pr) { return $false }
    if (@($Pr.closingIssuesReferences | Where-Object { $null -ne $_ }).Count -gt 0) { return $true }
    [bool]([string]$Pr.body -match "(?im)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#\d+\b")
}

function Assert-BranchCleanup {
    param($Setup, $Cleanup, [bool]$RequireRemoteDelete)
    if ($null -eq $Cleanup -or $Cleanup -is [string]) { throw "branch cleanup confirmation must be structured" }
    $branch = Normalize-RepoPath ([string]$Setup.branch)
    if ($Cleanup.deleted_local -ne $true -or $Cleanup.only_goal_owned_removed -ne $true) { throw "branch cleanup must delete only the goal branch locally" }
    if ($RequireRemoteDelete -and $Cleanup.deleted_remote -ne $true) { throw "branch cleanup must delete the remote goal branch" }
    if ((Normalize-RepoPath ([string]$Cleanup.local_delete_target)) -ne $branch) { throw "branch cleanup local target must match setup branch" }
    if ($RequireRemoteDelete -and (Normalize-RepoPath ([string]$Cleanup.remote_delete_target)) -ne $branch) { throw "branch cleanup remote target must match setup branch" }
    foreach ($deleted in (Get-StringArray $Cleanup.remote_deleted_branches)) {
        if ((Normalize-RepoPath $deleted) -ne $branch) { throw "remote cleanup includes non-goal branch" }
    }
}

function Assert-CommonCloseoutProof {
    param($Completion, $Setup, [bool]$RequireRemoteDelete)
    foreach ($field in @(
        "merge_decision",
        "default_branch_sync",
        "branch_cleanup_confirmation",
        "worktree_cleanup_confirmation",
        "fetch_prune_result",
        "cleanup_hook_result",
        "clean_repo_proof"
    )) {
        if (-not (Test-Property -Object $Completion -Name $field) -or $Completion.$field -is [string]) { throw "completion ledger $field must be structured" }
    }
    Assert-MergeDecision -Decision $Completion.merge_decision
    Assert-CleanRepoProof -Proof $Completion.clean_repo_proof
    if ([int]$Completion.default_branch_sync.exit_code -ne 0) { throw "default branch sync must pass" }
    if ([int]$Completion.fetch_prune_result.exit_code -ne 0) { throw "git fetch --prune must pass" }
    if ([int]$Completion.cleanup_hook_result.exit_code -ne 0) { throw "cleanup hook must pass" }
    Assert-BranchCleanup -Setup $Setup -Cleanup $Completion.branch_cleanup_confirmation -RequireRemoteDelete $RequireRemoteDelete
}

function Test-OrchestratedMergeContext {
    param($Setup, $Completion)
    if ((Test-Property -Object $Setup -Name "merge_context") -and [string]$Setup.merge_context -eq "orchestrated") { return $true }
    if ((Test-Property -Object $Completion -Name "merge_context") -and [string]$Completion.merge_context -eq "orchestrated") { return $true }
    if (Test-Property -Object $Setup -Name "worker_identity") { return $true }
    if (Test-Property -Object $Setup -Name "worker_handoff") { return $true }
    if (Test-Property -Object $Setup -Name "worker_thread_id") { return $true }
    $false
}

function Assert-OrchestratedWorkerCloseout {
    param($Setup, $Completion)
    if (-not (Test-OrchestratedMergeContext -Setup $Setup -Completion $Completion)) { return }
    if (-not (Test-Property -Object $Completion -Name "orchestrated_worker_closeout") -or $Completion.orchestrated_worker_closeout -is [string]) {
        throw "orchestrated merge closeout requires structured orchestrated_worker_closeout"
    }
    $closeout = $Completion.orchestrated_worker_closeout
    foreach ($field in @("worker_thread", "worker_thread_archival_proof", "physical_worktree_folder_cleanup")) {
        if (-not (Test-Property -Object $closeout -Name $field) -or $closeout.$field -is [string]) {
            throw "orchestrated_worker_closeout missing structured $field"
        }
    }
    $worker = $closeout.worker_thread
    $hasThreadId = (Test-Property -Object $worker -Name "thread_id") -and -not [string]::IsNullOrWhiteSpace([string]$worker.thread_id)
    $hasThreadTitle = (Test-Property -Object $worker -Name "thread_title") -and -not [string]::IsNullOrWhiteSpace([string]$worker.thread_title)
    if (-not ($hasThreadId -or $hasThreadTitle)) { throw "orchestrated closeout requires worker thread id or title evidence" }
    if (-not (Test-Property -Object $worker -Name "worktree_path") -or [string]::IsNullOrWhiteSpace([string]$worker.worktree_path)) {
        throw "orchestrated closeout requires worker worktree path evidence"
    }
    $archive = $closeout.worker_thread_archival_proof
    if ($archive.archived -ne $true) { throw "worker thread archival proof must show archived=true" }
    if ($archive.archived_after_merge -ne $true -and $archive.archived_after_pr_merge -ne $true) {
        throw "worker thread archival must occur after PR merge"
    }
    if (-not (Test-Property -Object $archive -Name "source") -or [string]::IsNullOrWhiteSpace([string]$archive.source)) {
        throw "worker thread archival proof requires source evidence"
    }
    $folder = $closeout.physical_worktree_folder_cleanup
    if ($folder.removed -ne $true) { throw "physical worktree folder cleanup must show removed=true" }
    if ($folder.target_inside_owned_worktree_root -ne $true) { throw "folder cleanup must target the owned worktree root" }
    if ($folder.removed_after_thread_archive -ne $true) { throw "physical worktree folder removal must occur after worker thread archival" }
    if ((Test-Property -Object $folder -Name "removed_before_thread_archive") -and $folder.removed_before_thread_archive -eq $true) {
        throw "physical worktree folder removal cannot run before worker thread archival"
    }
}
