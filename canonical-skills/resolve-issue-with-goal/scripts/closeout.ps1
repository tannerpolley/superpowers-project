[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$CompletionLedgerJson,
    [string]$CompletionLedgerPath,
    [string]$PrFixturePath,
    [string]$IssueFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "closeout"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $setup = Read-JsonInput -Json $SetupLedgerJson -Path $SetupLedgerPath -Name "setup ledger"
    $completion = Read-JsonInput -Json $CompletionLedgerJson -Path $CompletionLedgerPath -Name "completion ledger"
    $pr = Read-JsonInput -Path $PrFixturePath -Name "PR fixture"
    $issue = Read-JsonInput -Path $IssueFixturePath -Name "issue fixture"
    if ([string]$completion.issue_url -ne [string]$setup.issue_url) { throw "completion issue_url must match setup ledger" }
    if ([string]$pr.state -ne "MERGED" -and [string]$completion.merge_confirmation.state -ne "MERGED") { throw "PR is not merged" }
    if ([string]$issue.state -ne "CLOSED" -and [string]$completion.linked_issue_closed_confirmation.state -ne "CLOSED") { throw "linked issue is not closed" }
    foreach ($field in @("branch_cleanup_confirmation", "cleanup_hook_result")) {
        if (-not (Test-Property -Object $completion -Name $field) -or $completion.$field -is [string]) { throw "completion ledger $field must be structured" }
    }
    $cleanup = $completion.branch_cleanup_confirmation
    $branch = Normalize-RepoPath ([string]$setup.branch)
    if ($cleanup.deleted_local -ne $true -or $cleanup.deleted_remote -ne $true -or $cleanup.only_goal_owned_removed -ne $true) { throw "branch cleanup must delete only the goal branch" }
    if ((Normalize-RepoPath ([string]$cleanup.local_delete_target)) -ne $branch -or (Normalize-RepoPath ([string]$cleanup.remote_delete_target)) -ne $branch) { throw "branch cleanup target must match setup branch" }
    foreach ($deleted in (Get-StringArray $cleanup.remote_deleted_branches)) {
        if ((Normalize-RepoPath $deleted) -ne $branch) { throw "remote cleanup includes non-goal branch" }
    }
    if ([int]$completion.cleanup_hook_result.exit_code -ne 0) { throw "cleanup hook must pass" }
    if (-not (Test-Property -Object $completion -Name "goal_completion_proof")) { throw "goal completion proof is required" }
    $goalProof = $completion.goal_completion_proof
    if ($goalProof -is [string]) { throw "goal completion proof must be structured" }
    $goalStatus = [string]$goalProof.status
    if ($goalStatus -ne "complete") { throw "goal completion proof must mark status complete" }
    $goalSource = [string]$goalProof.source
    if ($goalSource -ne "update_goal" -and $goalSource -ne "slash-command") { throw "goal completion proof must come from update_goal or exact slash-command evidence" }
    Complete-Contract -Phase $phase -Reason "closeout checks passed" -Evidence @{ pr_url = [string]$completion.pr_url; issue_url = [string]$completion.issue_url; goal_status = $goalStatus; branch_deleted = $branch }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
