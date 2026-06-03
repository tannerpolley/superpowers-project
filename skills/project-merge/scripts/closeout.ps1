[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$CompletionLedgerJson,
    [string]$CompletionLedgerPath,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string]$IssueJson,
    [string]$IssueFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "closeout"

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $setup = Read-JsonInput -Json $SetupLedgerJson -Path $SetupLedgerPath -Name "setup ledger"
    $completion = Read-JsonInput -Json $CompletionLedgerJson -Path $CompletionLedgerPath -Name "completion ledger"
    $pr = Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
    $issue = Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
    if ([string]$completion.issue_url -ne [string]$setup.issue_url) { throw "completion issue_url must match setup ledger" }
    if ([string]$pr.state -ne "MERGED" -and [string]$completion.merge_confirmation.state -ne "MERGED") { throw "PR is not merged" }
    if ([string]$issue.state -ne "CLOSED" -and [string]$completion.linked_issue_closed_confirmation.state -ne "CLOSED") { throw "linked issue is not closed" }
    foreach ($field in @(
        "merge_decision",
        "merge_confirmation",
        "linked_issue_closed_confirmation",
        "default_branch_sync",
        "branch_cleanup_confirmation",
        "worktree_cleanup_confirmation",
        "fetch_prune_result",
        "cleanup_hook_result",
        "clean_repo_proof",
        "resolve_goal_completion_proof"
    )) {
        if (-not (Test-Property -Object $completion -Name $field) -or $completion.$field -is [string]) { throw "completion ledger $field must be structured" }
    }
    Assert-MergeDecision -Decision $completion.merge_decision
    Assert-CleanRepoProof -Proof $completion.clean_repo_proof
    if ([int]$completion.default_branch_sync.exit_code -ne 0) { throw "default branch sync must pass" }
    if ([int]$completion.fetch_prune_result.exit_code -ne 0) { throw "git fetch --prune must pass" }
    if ([int]$completion.cleanup_hook_result.exit_code -ne 0) { throw "cleanup hook must pass" }
    $cleanup = $completion.branch_cleanup_confirmation
    $branch = Normalize-RepoPath ([string]$setup.branch)
    if ($cleanup.deleted_local -ne $true -or $cleanup.deleted_remote -ne $true -or $cleanup.only_goal_owned_removed -ne $true) { throw "branch cleanup must delete only the goal branch" }
    if ((Normalize-RepoPath ([string]$cleanup.local_delete_target)) -ne $branch -or (Normalize-RepoPath ([string]$cleanup.remote_delete_target)) -ne $branch) { throw "branch cleanup target must match setup branch" }
    foreach ($deleted in (Get-StringArray $cleanup.remote_deleted_branches)) {
        if ((Normalize-RepoPath $deleted) -ne $branch) { throw "remote cleanup includes non-goal branch" }
    }
    $resolveGoal = $completion.resolve_goal_completion_proof
    if ($resolveGoal -is [string]) { throw "resolve goal completion proof must be structured" }
    if ([string]$resolveGoal.status -ne "complete") { throw "resolve goal completion proof must mark status complete" }
    if ([string]$issue.state -eq "CLOSED" -or [string]$completion.linked_issue_closed_confirmation.state -eq "CLOSED") {
        if (-not (Test-Property -Object $completion -Name "mirror_cleanup_confirmation") -or $completion.mirror_cleanup_confirmation -is [string]) {
            throw "mirror cleanup confirmation must be structured for closed issues"
        }
        $mirrorCleanup = $completion.mirror_cleanup_confirmation
        foreach ($field in @("policy", "issue_mirror", "deleted", "retained", "milestone_record", "milestone_summary")) {
            if (-not (Test-Property -Object $mirrorCleanup -Name $field)) { throw "mirror cleanup confirmation missing $field" }
        }
        $cleanupMirror = Normalize-RepoPath ([string]$mirrorCleanup.issue_mirror)
        $setupMirror = Normalize-RepoPath ([string]$setup.issue_mirror)
        if ($cleanupMirror -ne $setupMirror) { throw "mirror cleanup issue_mirror must match setup ledger" }
        $mirrorPath = Resolve-RepoFile -RepoRoot $root -Path $setupMirror
        $mirrorText = if (Test-Path -LiteralPath $mirrorPath -PathType Leaf) { Get-Content -LiteralPath $mirrorPath -Raw } else { "" }
        $retentionMarked = $mirrorText -match '(?im)^\s*\*\*Mirror Retention:\*\*\s*Keep\s*$'
        if ($retentionMarked) {
            if ($mirrorCleanup.retained -ne $true -or $mirrorCleanup.deleted -eq $true) { throw "retained mirror must have retained=true and deleted=false" }
            if ([string]::IsNullOrWhiteSpace([string]$mirrorCleanup.retention_reason)) { throw "retained mirror requires retention_reason" }
        } elseif ($mirrorCleanup.deleted -ne $true -and $mirrorCleanup.retained -ne $true) {
            throw "closed issue mirror cleanup must show deletion or explicit retention"
        }
        if ($mirrorCleanup.retained -eq $true -and [string]::IsNullOrWhiteSpace([string]$mirrorCleanup.retention_reason)) {
            throw "retained mirror requires retention_reason"
        }
        if ([string]$mirrorCleanup.milestone_record -ne "closed-summary") { throw "mirror cleanup must preserve milestone_record as closed-summary" }
        $summary = $mirrorCleanup.milestone_summary
        foreach ($field in @("milestone_page", "issue_url", "pr_url")) {
            if (-not (Test-Property -Object $summary -Name $field) -or [string]::IsNullOrWhiteSpace([string]$summary.$field)) { throw "milestone summary missing $field" }
        }
        if ([string]$summary.issue_url -ne [string]$completion.issue_url) { throw "milestone summary issue_url must match completion issue_url" }
        if ([string]$summary.pr_url -ne [string]$completion.pr_url) { throw "milestone summary pr_url must match completion pr_url" }
    }
    Complete-Contract -Phase $phase -Reason "closeout checks passed" -Evidence @{ pr_url = [string]$completion.pr_url; issue_url = [string]$completion.issue_url; branch_deleted = $branch; repo_clean = $true; mirror_cleanup = $true }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
