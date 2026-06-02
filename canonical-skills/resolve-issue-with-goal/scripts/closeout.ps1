[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$HandoffJson,
    [string]$HandoffPath,
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$CompletionLedgerJson,
    [string]$CompletionLedgerPath,
    [string]$Pr,
    [string]$PrFixturePath,
    [string]$IssueFixturePath,
    [string]$MilestonesFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

$phase = "closeout"
$evidence = @{}

function Get-PrFromGhForCloseout {
    param([string]$RepoRoot, [string]$Pr, [string]$RemoteSlug)
    $args = @("pr", "view")
    if (-not [string]::IsNullOrWhiteSpace($Pr)) {
        if ($Pr -match '^https://github\.com/[^/]+/[^/]+/pull/\d+') {
            $prRepo = Get-RepoSlugFromPullUrl -PullUrl $Pr
            if ($prRepo -ne $RemoteSlug) { throw "PR URL repository does not match target RepoRoot: pr='$prRepo' repo_root='$RemoteSlug'" }
            $args += [string](Get-PullNumberFromUrl -PullUrl $Pr)
        } else {
            $args += $Pr
        }
    }
    $args += @("--repo", $RemoteSlug, "--json", "number,url,state,mergedAt,headRefName,baseRefName,closingIssuesReferences")
    $result = Invoke-Gh -Arguments $args -WorkingDirectory $RepoRoot
    if ($result.ExitCode -ne 0) { throw "gh pr view failed: $($result.Stderr)" }
    $result.Stdout | ConvertFrom-Json
}

try {
    if (-not [string]::IsNullOrWhiteSpace($PrFixturePath)) { Assert-TestModeSwitch -Name "-PrFixturePath" }
    if (-not [string]::IsNullOrWhiteSpace($IssueFixturePath)) { Assert-TestModeSwitch -Name "-IssueFixturePath" }
    if (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath)) { Assert-TestModeSwitch -Name "-MilestonesFixturePath" }

    $root = Get-CanonicalRepoRoot -RepoRoot $RepoRoot
    $origin = Invoke-Git -RepoRoot $root -Arguments @("remote", "get-url", "origin")
    $remoteSlug = Get-OriginRemoteSlug -RemoteUrl $origin.Stdout
    $handoff = Get-Handoff -HandoffJson $HandoffJson -HandoffPath $HandoffPath
    $milestones = @()
    if ([string]$handoff.milestone_policy -eq "hard" -or (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath))) {
        $milestones = Get-MilestoneList -RepoRoot $root -RemoteSlug $remoteSlug -FixturePath $MilestonesFixturePath
    }
    $milestoneEvidence = Assert-MilestoneContract -RepoRoot $root -Handoff $handoff -Milestones $milestones
    $setup = Get-SetupLedger -SetupLedgerJson $SetupLedgerJson -SetupLedgerPath $SetupLedgerPath -Handoff $handoff -RemoteSlug $remoteSlug
    $completion = Get-CompletionLedger -CompletionLedgerJson $CompletionLedgerJson -CompletionLedgerPath $CompletionLedgerPath -SetupLedger $setup

    $prObject = if (-not [string]::IsNullOrWhiteSpace($PrFixturePath)) {
        Read-JsonInput -Path $PrFixturePath -Name "PR fixture"
    } else {
        Get-PrFromGhForCloseout -RepoRoot $root -Pr $Pr -RemoteSlug $remoteSlug
    }

    if ([string]$prObject.url -ne [string]$completion.pr_url) {
        Stop-Contract -Phase $phase -Reason "PR URL does not match completion ledger" -Evidence @{ pr_url = $prObject.url; ledger_pr_url = $completion.pr_url }
    }
    if ($prObject.state -ne "MERGED" -or [string]::IsNullOrWhiteSpace([string]$prObject.mergedAt)) {
        Stop-Contract -Phase $phase -Reason "PR is not merged" -Evidence @{ pr_url = $prObject.url; pr_state = $prObject.state; merged_at = $prObject.mergedAt }
    }

    $issueNumber = Get-IssueNumberFromUrl -IssueUrl ([string]$setup.issue_url)
    if (-not (Test-ClosingReferenceIncludesIssue -References $prObject.closingIssuesReferences -IssueNumber $issueNumber)) {
        Stop-Contract -Phase $phase -Reason "merged PR does not report the linked issue as a closing reference" -Evidence @{ pr_url = $prObject.url; issue_url = $setup.issue_url }
    }

    $issueState = $null
    $issue = $null
    if (-not [string]::IsNullOrWhiteSpace($IssueFixturePath)) {
        $issue = Read-JsonInput -Path $IssueFixturePath -Name "issue fixture"
        $issueState = [string]$issue.state
    } else {
        if ($null -eq $issueNumber) {
            Stop-Contract -Phase $phase -Reason "could not resolve linked issue number from setup ledger" -Evidence @{ issue_url = $setup.issue_url }
        }
        $issueResult = Invoke-Gh -Arguments @("issue", "view", "$issueNumber", "--repo", $remoteSlug, "--json", "state,milestone") -WorkingDirectory $root
        if ($issueResult.ExitCode -ne 0) {
            Stop-Contract -Phase $phase -Reason "could not read linked issue state" -Evidence @{ issue_url = $setup.issue_url; gh_stderr = $issueResult.Stderr }
        }
        $issue = $issueResult.Stdout | ConvertFrom-Json
        $issueState = [string]$issue.state
    }
    Assert-IssueMilestone -Issue $issue -Handoff $handoff -IssueUrl ([string]$setup.issue_url)
    if ($issueState -ne "CLOSED") {
        Stop-Contract -Phase $phase -Reason "linked issue is not closed" -Evidence @{ issue_url = $setup.issue_url; issue_state = $issueState }
    }

    $defaultBranch = Get-BranchDefault -RepoRoot $root
    if ([string]::IsNullOrWhiteSpace($defaultBranch)) { $defaultBranch = [string]$prObject.baseRefName }
    $currentBranch = Invoke-Git -RepoRoot $root -Arguments @("branch", "--show-current")
    if ($currentBranch.ExitCode -ne 0 -or $currentBranch.Stdout -ne $defaultBranch) {
        Stop-Contract -Phase $phase -Reason "local checkout is not on the remote default branch" -Evidence @{ current_branch = $currentBranch.Stdout; default_branch = $defaultBranch }
    }

    $localDefault = Invoke-Git -RepoRoot $root -Arguments @("rev-parse", $defaultBranch)
    $remoteDefault = Invoke-Git -RepoRoot $root -Arguments @("rev-parse", "origin/$defaultBranch")
    if ($localDefault.ExitCode -ne 0 -or $remoteDefault.ExitCode -ne 0 -or $localDefault.Stdout -ne $remoteDefault.Stdout) {
        Stop-Contract -Phase $phase -Reason "local default branch is not synced to origin" -Evidence @{
            default_branch = $defaultBranch
            local_oid = $localDefault.Stdout
            remote_oid = $remoteDefault.Stdout
        }
    }

    $goalBranch = Normalize-RepoPath ([string]$setup.branch)
    $currentInventory = Get-BranchInventory -RepoRoot $root
    $expectedLocal = @(Get-StringArray $setup.branch_inventory_before.local | Where-Object { (Normalize-RepoPath $_) -ne $goalBranch })
    $localCompare = Compare-StringSet -Expected $expectedLocal -Actual $currentInventory.local
    if ($localCompare.missing.Count -gt 0 -or $localCompare.added.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "local branch inventory changed beyond the goal-owned branch" -Evidence @{
            local_missing = $localCompare.missing
            local_added = $localCompare.added
            goal_branch = $goalBranch
        }
    }

    $localGoalBranch = Invoke-Git -RepoRoot $root -Arguments @("show-ref", "--verify", "--quiet", "refs/heads/$goalBranch")
    if ($localGoalBranch.ExitCode -eq 0) {
        Stop-Contract -Phase $phase -Reason "goal-owned local branch still exists" -Evidence @{ branch = $goalBranch }
    }
    $remoteGoalBranch = Invoke-Git -RepoRoot $root -Arguments @("show-ref", "--verify", "--quiet", "refs/remotes/origin/$goalBranch")
    if ($remoteGoalBranch.ExitCode -eq 0) {
        Stop-Contract -Phase $phase -Reason "goal-owned remote branch still exists" -Evidence @{ branch = $goalBranch }
    }

    $goalBoardPath = Join-Path $root ([string]$setup.goal_board_path)
    if (Test-Path -LiteralPath $goalBoardPath) {
        Stop-Contract -Phase $phase -Reason "local GoalBuddy board still exists" -Evidence @{ goal_board_path = $setup.goal_board_path }
    }
    $statusEntries = Get-GitStatusEntries -RepoRoot $root
    $goalResidue = @()
    foreach ($entry in $statusEntries) {
        $path = Normalize-RepoPath $entry.Path
        if ($path -match "^docs/goals/" -or $path -match "(^|/)\.goalbuddy-board/") {
            $goalResidue += "$($entry.Status) $path"
        }
    }
    if ($goalResidue.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "GoalBuddy board residue remains in git status" -Evidence @{ residue = $goalResidue }
    }

    $evidence = @{
        repo_root = $root
        pr_url = $prObject.url
        issue_url = $setup.issue_url
        issue_state = $issueState
        default_branch = $defaultBranch
        goal_branch = $goalBranch
        merge_confirmation = $completion.merge_confirmation
        branch_cleanup_confirmation = $completion.branch_cleanup_confirmation
        goal_board_deletion_confirmation = $completion.goal_board_deletion_confirmation
        cleanup_hook_result = $completion.cleanup_hook_result
        milestone_contract = $milestoneEvidence
        handoff_slug = $handoff.slug
    }
    Complete-Contract -Phase $phase -Reason "closeout checks passed" -Evidence $evidence
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence $evidence
}
