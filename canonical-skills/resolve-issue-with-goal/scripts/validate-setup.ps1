[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$HandoffJson,
    [string]$HandoffPath,
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$IssueFixturePath,
    [string]$MilestonesFixturePath,
    [switch]$SkipGoalBuddyCheck
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

$phase = "setup"
$evidence = @{}

try {
    if ($SkipGoalBuddyCheck.IsPresent) { Assert-TestModeSwitch -Name "-SkipGoalBuddyCheck" }
    if (-not [string]::IsNullOrWhiteSpace($IssueFixturePath)) { Assert-TestModeSwitch -Name "-IssueFixturePath" }
    if (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath)) { Assert-TestModeSwitch -Name "-MilestonesFixturePath" }

    $root = Get-CanonicalRepoRoot -RepoRoot $RepoRoot
    $origin = Invoke-Git -RepoRoot $root -Arguments @("remote", "get-url", "origin")
    if ($origin.ExitCode -ne 0) { Stop-Contract -Phase $phase -Reason "missing GitHub origin remote" -Evidence @{ repo_root = $root } }
    $remoteSlug = Get-OriginRemoteSlug -RemoteUrl $origin.Stdout
    if ([string]::IsNullOrWhiteSpace($remoteSlug)) { Stop-Contract -Phase $phase -Reason "origin remote is not a GitHub repository" -Evidence @{ origin = $origin.Stdout } }

    $handoff = Get-Handoff -HandoffJson $HandoffJson -HandoffPath $HandoffPath
    $milestones = @()
    if ([string]$handoff.milestone_policy -eq "hard" -or (-not [string]::IsNullOrWhiteSpace($MilestonesFixturePath))) {
        $milestones = Get-MilestoneList -RepoRoot $root -RemoteSlug $remoteSlug -FixturePath $MilestonesFixturePath
    }
    $milestoneEvidence = Assert-MilestoneContract -RepoRoot $root -Handoff $handoff -Milestones $milestones
    $ledger = Get-SetupLedger -SetupLedgerJson $SetupLedgerJson -SetupLedgerPath $SetupLedgerPath -Handoff $handoff -RemoteSlug $remoteSlug

    if ([string]$handoff.milestone_policy -eq "hard") {
        $issueNumber = Get-IssueNumberFromUrl -IssueUrl ([string]$ledger.issue_url)
        if ($null -eq $issueNumber) {
            Stop-Contract -Phase $phase -Reason "could not resolve linked issue number from setup ledger" -Evidence @{ issue_url = $ledger.issue_url }
        }
        $issueObject = if (-not [string]::IsNullOrWhiteSpace($IssueFixturePath)) {
            Read-JsonInput -Path $IssueFixturePath -Name "issue fixture"
        } else {
            $issueResult = Invoke-Gh -Arguments @("issue", "view", "$issueNumber", "--repo", $remoteSlug, "--json", "url,number,state,milestone") -WorkingDirectory $root
            if ($issueResult.ExitCode -ne 0) {
                Stop-Contract -Phase $phase -Reason "could not read linked issue milestone" -Evidence @{ issue_url = $ledger.issue_url; gh_stderr = $issueResult.Stderr }
            }
            $issueResult.Stdout | ConvertFrom-Json
        }
        Assert-IssueMilestone -Issue $issueObject -Handoff $handoff -IssueUrl ([string]$ledger.issue_url)
    }

    $currentBranch = Invoke-Git -RepoRoot $root -Arguments @("branch", "--show-current")
    if ($currentBranch.ExitCode -ne 0 -or (Normalize-RepoPath $currentBranch.Stdout) -ne (Normalize-RepoPath ([string]$ledger.branch))) {
        Stop-Contract -Phase $phase -Reason "current branch does not match setup ledger branch" -Evidence @{
            current_branch = $currentBranch.Stdout
            ledger_branch = $ledger.branch
        }
    }

    $slicePath = Join-Path $root ([string]$ledger.slice_roadmap_path)
    if (-not (Test-Path -LiteralPath $slicePath -PathType Leaf)) {
        Stop-Contract -Phase $phase -Reason "local issue file path is missing" -Evidence @{ local_issue_file = $ledger.slice_roadmap_path }
    }

    $goalBoardPath = Join-Path $root ([string]$ledger.goal_board_path)
    $goalMd = Join-Path $goalBoardPath "goal.md"
    $stateYaml = Join-Path $goalBoardPath "state.yaml"
    if (-not (Test-Path -LiteralPath $goalBoardPath -PathType Container)) {
        Stop-Contract -Phase $phase -Reason "GoalBuddy board path is missing" -Evidence @{ goal_board_path = $ledger.goal_board_path }
    }
    foreach ($requiredBoardFile in @($goalMd, $stateYaml)) {
        if (-not (Test-Path -LiteralPath $requiredBoardFile -PathType Leaf)) {
            Stop-Contract -Phase $phase -Reason "GoalBuddy board is missing $([IO.Path]::GetFileName($requiredBoardFile))" -Evidence @{
                goal_board_path = $ledger.goal_board_path
                missing_path = $requiredBoardFile
            }
        }
    }

    if (-not $SkipGoalBuddyCheck) {
        $resolver = Join-Path $env:USERPROFILE "Documents\git\codex-maintenance\scripts\resolve-goalbuddy-skill-path.ps1"
        if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
            Stop-Contract -Phase $phase -Reason "GoalBuddy resolver helper is missing" -Evidence @{ resolver = $resolver }
        }
        $checkerPath = (& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $resolver -RelativePath "scripts\check-goal-state.mjs").Trim()
        if (-not (Test-Path -LiteralPath $checkerPath -PathType Leaf)) {
            Stop-Contract -Phase $phase -Reason "GoalBuddy checker is missing" -Evidence @{ checker = $checkerPath }
        }
        $checker = Invoke-External -FilePath "node" -Arguments @($checkerPath, $stateYaml) -WorkingDirectory $root
        if ($checker.ExitCode -ne 0) {
            Stop-Contract -Phase $phase -Reason "GoalBuddy state.yaml checker failed" -Evidence @{
                state_yaml = $stateYaml
                checker_stdout = $checker.Stdout
                checker_stderr = $checker.Stderr
            }
        }
    }

    $contractValidator = Join-Path $PSScriptRoot "validate-goalbuddy-contract.mjs"
    $contractCheck = Invoke-External -FilePath "node" -Arguments @($contractValidator, $stateYaml) -WorkingDirectory $root
    if ($contractCheck.ExitCode -ne 0) {
        Stop-Contract -Phase $phase -Reason "GoalBuddy delegation contract failed" -Evidence @{
            state_yaml = $stateYaml
            checker_stdout = $contractCheck.Stdout
            checker_stderr = $contractCheck.Stderr
        }
    }

    $gitignorePath = Join-Path $root ".gitignore"
    if (-not (Test-Path -LiteralPath $gitignorePath -PathType Leaf)) {
        Stop-Contract -Phase $phase -Reason ".gitignore is missing GoalBuddy local-only policy" -Evidence @{ gitignore = $gitignorePath }
    }
    $gitignore = Get-Content -LiteralPath $gitignorePath -Raw
    if ($gitignore -notmatch "(?m)^\s*docs/goals/?\s*$" -and $gitignore -notmatch "(?m)^\s*docs/goals/\*\s*$") {
        Stop-Contract -Phase $phase -Reason ".gitignore does not ignore docs/goals local boards" -Evidence @{ gitignore = $gitignorePath }
    }
    if ($gitignore -notmatch "(?m)\.goalbuddy-board/") {
        Stop-Contract -Phase $phase -Reason ".gitignore does not ignore generated .goalbuddy-board directories" -Evidence @{ gitignore = $gitignorePath }
    }

    $ignored = Invoke-Git -RepoRoot $root -Arguments @("check-ignore", "-q", "--no-index", "--", ([string]$ledger.goal_board_path))
    if ($ignored.ExitCode -ne 0) {
        Stop-Contract -Phase $phase -Reason "GoalBuddy board path is not ignored by git" -Evidence @{ goal_board_path = $ledger.goal_board_path }
    }

    $trackedGoalPaths = Get-TrackedGoalPaths -RepoRoot $root
    $remainingTrackedGoalDocs = @()
    foreach ($path in $trackedGoalPaths) {
        $normalized = Normalize-RepoPath $path
        if ($normalized -match '^docs/goals/' -and $normalized -ne 'docs/goals/README.md') {
            $remainingTrackedGoalDocs += $normalized
        }
    }
    if ($remainingTrackedGoalDocs.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "tracked GoalBuddy docs remain and must be committed as deletions" -Evidence @{ tracked_goal_paths = $remainingTrackedGoalDocs }
    }

    $staged = Get-StagedEntries -RepoRoot $root
    $badStaged = @()
    foreach ($entry in $staged) {
        $path = Normalize-RepoPath $entry.Path
        $status = [string]$entry.Status
        if ($path -match "^docs/goals/" -and $path -ne "docs/goals/README.md" -and $status -notmatch "^D") {
            $badStaged += "$status $path"
        }
        if ($path -match "(^|/)\.goalbuddy-board/") {
            $badStaged += "$status $path"
        }
    }
    if ($badStaged.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "new GoalBuddy board files are staged" -Evidence @{ staged_goal_files = $badStaged }
    }

    $evidence = @{
        repo_root = $root
        remote_slug = $remoteSlug
        issue_url = $ledger.issue_url
        branch = $ledger.branch
        slice_roadmap_path = $ledger.slice_roadmap_path
        goal_board_path = $ledger.goal_board_path
        proof_oracle = $ledger.proof_oracle
        milestone_contract = $milestoneEvidence
        branch_inventory_before = $ledger.branch_inventory_before
        goalbuddy_checker_ran = -not $SkipGoalBuddyCheck.IsPresent
        delegation_contract_ran = $true
        staged_entries_count = $staged.Count
        handoff_slug = $handoff.slug
    }
    Complete-Contract -Phase $phase -Reason "setup ledger passed" -Evidence $evidence
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence $evidence
}
