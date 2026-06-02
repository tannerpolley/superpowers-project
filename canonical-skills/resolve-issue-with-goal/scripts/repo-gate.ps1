[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$ExpectedRemoteSlug,
    [switch]$SkipGhAuth,
    [string]$MilestonesFixturePath,
    [string]$ProjectsFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

$phase = "repo-gate"
$evidence = @{}

try {
    if (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath)) { Assert-TestModeSwitch -Name "-MilestonesFixturePath" }
    if (-not [string]::IsNullOrWhiteSpace($ProjectsFixturePath)) { Assert-TestModeSwitch -Name "-ProjectsFixturePath" }

    $context = Get-GithubRepoContext -RepoRoot $RepoRoot -SkipGhAuth:$SkipGhAuth
    if (-not [string]::IsNullOrWhiteSpace($ExpectedRemoteSlug)) {
        if ($ExpectedRemoteSlug -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            throw "expected remote slug must be owner/repo"
        }
        if ([string]$context.remote_slug -ne $ExpectedRemoteSlug) {
            throw "target repo mismatch: repo gate resolved '$($context.remote_slug)' but expected '$ExpectedRemoteSlug'"
        }
    }
    $defaultBranch = Get-BranchDefault -RepoRoot $context.repo_root
    $inventory = Get-BranchInventory -RepoRoot $context.repo_root
    $milestonesChecked = $false
    $milestones = @()
    if ((-not $SkipGhAuth.IsPresent) -or (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath))) {
        $milestones = Get-MilestoneList -RepoRoot $context.repo_root -RemoteSlug $context.remote_slug -FixturePath $MilestonesFixturePath
        $milestonesChecked = $true
    }
    $projectsSummary = if ((-not $SkipGhAuth.IsPresent) -or (-not [string]::IsNullOrWhiteSpace($ProjectsFixturePath))) {
        Get-GithubProjectsSummary -RepoRoot $context.repo_root -RemoteSlug $context.remote_slug -FixturePath $ProjectsFixturePath
    } else {
        [pscustomobject]@{ checked = $false; error = $null; projects = @() }
    }
    $projects = @($projectsSummary.projects)
    $evidence = @{
        repo_root = $context.repo_root
        origin = $context.origin
        remote_slug = $context.remote_slug
        default_branch = $defaultBranch
        local_branches = $inventory.local
        remote_branches = $inventory.remote
        agent_file = $context.agent_file
        issue_tracker = $context.issue_tracker
        gh_auth_checked = $context.gh_auth_checked
        matt_pocock_setup = $context.matt_pocock_setup
        milestones_checked = $milestonesChecked
        milestones_present = @($milestones).Count -gt 0
        milestones_count = @($milestones).Count
        milestone_titles = @($milestones | ForEach-Object { [string]$_.title })
        projects_checked = $projectsSummary.checked
        projects_present = $projects.Count -gt 0
        projects_count = $projects.Count
        project_titles = @($projects | ForEach-Object { [string]$_.title })
        projects_check_error = $projectsSummary.error
    }
    Complete-Contract -Phase $phase -Reason "repo gate passed" -Evidence $evidence
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence $evidence
}
