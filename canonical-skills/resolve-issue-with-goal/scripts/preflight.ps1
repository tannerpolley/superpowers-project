[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$HandoffJson,
    [string]$HandoffPath,
    [switch]$SkipGhAuth,
    [string]$MilestonesFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

$phase = "preflight"
$evidence = @{}

try {
    if (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath)) { Assert-TestModeSwitch -Name "-MilestonesFixturePath" }

    $context = Get-GithubRepoContext -RepoRoot $RepoRoot -SkipGhAuth:$SkipGhAuth
    $root = $context.repo_root
    $handoff = Get-Handoff -HandoffJson $HandoffJson -HandoffPath $HandoffPath
    $milestones = @()
    if ((-not $SkipGhAuth.IsPresent) -or (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath))) {
        $milestones = Get-MilestoneList -RepoRoot $root -RemoteSlug $context.remote_slug -FixturePath $MilestonesFixturePath
    }
    $milestoneEvidence = Assert-MilestoneContract -RepoRoot $root -Handoff $handoff -Milestones $milestones

    $currentBranch = Invoke-Git -RepoRoot $root -Arguments @("branch", "--show-current")
    if ($currentBranch.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($currentBranch.Stdout)) {
        Stop-Contract -Phase $phase -Reason "could not resolve current git branch" -Evidence @{ repo_root = $root; stderr = $currentBranch.Stderr }
    }

    $defaultBranch = Get-BranchDefault -RepoRoot $root
    $inventory = Get-BranchInventory -RepoRoot $root
    $currentBranchName = Normalize-RepoPath $currentBranch.Stdout
    $goalBranch = Normalize-RepoPath ([string]$handoff.branch)
    $localHasGoalBranch = @($inventory.local) -contains $goalBranch
    $remoteHasGoalBranch = @($inventory.remote) -contains $goalBranch
    $localDefaultOid = $null
    $remoteDefaultOid = $null

    if ([string]$handoff.branch_policy -eq "create") {
        if ([string]::IsNullOrWhiteSpace($defaultBranch)) {
            Stop-Contract -Phase $phase -Reason "could not resolve remote default branch" -Evidence @{ repo_root = $root }
        }
        if ($currentBranchName -ne (Normalize-RepoPath $defaultBranch)) {
            Stop-Contract -Phase $phase -Reason "branch_policy create requires current branch to be the remote default branch" -Evidence @{
                current_branch = $currentBranch.Stdout
                default_branch = $defaultBranch
            }
        }
        $localDefault = Invoke-Git -RepoRoot $root -Arguments @("rev-parse", $defaultBranch)
        $remoteDefault = Invoke-Git -RepoRoot $root -Arguments @("rev-parse", "origin/$defaultBranch")
        $localDefaultOid = $localDefault.Stdout
        $remoteDefaultOid = $remoteDefault.Stdout
        if ($localDefault.ExitCode -ne 0 -or $remoteDefault.ExitCode -ne 0 -or $localDefaultOid -ne $remoteDefaultOid) {
            Stop-Contract -Phase $phase -Reason "branch_policy create requires local default branch to equal origin default branch" -Evidence @{
                default_branch = $defaultBranch
                local_oid = $localDefaultOid
                remote_oid = $remoteDefaultOid
            }
        }
        if ($localHasGoalBranch -or $remoteHasGoalBranch) {
            Stop-Contract -Phase $phase -Reason "handoff branch already exists but branch_policy is create" -Evidence @{
                branch = $goalBranch
                local_has_branch = $localHasGoalBranch
                remote_has_branch = $remoteHasGoalBranch
            }
        }
    }
    if ([string]$handoff.branch_policy -eq "reuse-current" -and $currentBranchName -ne $goalBranch) {
        Stop-Contract -Phase $phase -Reason "branch_policy reuse-current requires current branch to equal handoff branch" -Evidence @{
            current_branch = $currentBranch.Stdout
            handoff_branch = $goalBranch
        }
    }

    $allowed = Get-StringArray $handoff.allowed_existing_dirty_paths
    $dirtyEntries = Get-GitStatusEntries -RepoRoot $root
    $unrelated = @()
    foreach ($entry in $dirtyEntries) {
        $path = Normalize-RepoPath $entry.Path
        if ($allowed -notcontains $path) {
            $unrelated += "$($entry.Status) $path"
        }
    }
    if ($unrelated.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "unrelated dirty changes are present" -Evidence @{
            repo_root = $root
            allowed_existing_dirty_paths = $allowed
            unrelated_dirty_changes = $unrelated
        }
    }

    $trackedGoalPaths = Get-TrackedGoalPaths -RepoRoot $root
    $evidence = @{
        repo_root = $root
        origin = $context.origin
        remote_slug = $context.remote_slug
        current_branch = $currentBranch.Stdout
        default_branch = $defaultBranch
        default_local_oid = $localDefaultOid
        default_remote_oid = $remoteDefaultOid
        handoff_slug = $handoff.slug
        handoff_branch = $goalBranch
        branch_policy = $handoff.branch_policy
        branch_inventory_before = @{
            local = $inventory.local
            remote = $inventory.remote
        }
        milestone_contract = $milestoneEvidence
        tracked_goal_paths_requiring_deletion = $trackedGoalPaths
        allowed_existing_dirty_paths = $allowed
        dirty_entries_count = $dirtyEntries.Count
        gh_auth_checked = $context.gh_auth_checked
        matt_pocock_setup = $context.matt_pocock_setup
    }
    Complete-Contract -Phase $phase -Reason "preflight passed" -Evidence $evidence
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence $evidence
}
