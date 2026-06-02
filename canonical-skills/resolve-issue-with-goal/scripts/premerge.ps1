[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$HandoffJson,
    [string]$HandoffPath,
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$VerificationLedgerJson,
    [string]$VerificationLedgerPath,
    [string]$Pr,
    [string]$PrFixturePath,
    [string]$IssueFixturePath,
    [string]$MilestonesFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

$phase = "premerge"
$evidence = @{}

function Get-PrFromGh {
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
    $args += @("--repo", $RemoteSlug, "--json", "number,url,body,isDraft,mergeable,state,reviewDecision,headRefName,baseRefName,closingIssuesReferences,files")
    $prResult = Invoke-Gh -Arguments $args -WorkingDirectory $RepoRoot
    if ($prResult.ExitCode -ne 0) { throw "gh pr view failed: $($prResult.Stderr)" }
    $prObject = $prResult.Stdout | ConvertFrom-Json

    $checks = Invoke-Gh -Arguments @("pr", "checks", ([string]$prObject.number), "--repo", $RemoteSlug, "--required", "--json", "name,bucket,state,workflow,link") -WorkingDirectory $RepoRoot
    if ([string]::IsNullOrWhiteSpace($checks.Stdout) -and $checks.Stderr -match "(?i)no checks|no required") {
        $requiredChecks = @()
    } elseif ([string]::IsNullOrWhiteSpace($checks.Stdout)) {
        throw "gh pr checks --required returned no machine-readable check data: $($checks.Stderr)"
    } else {
        $requiredChecks = @($checks.Stdout | ConvertFrom-Json)
    }
    $prObject | Add-Member -NotePropertyName requiredChecks -NotePropertyValue $requiredChecks -Force

    $repoParts = $RemoteSlug -split "/", 2
    if ($repoParts.Count -ne 2) { throw "target repo slug is invalid: $RemoteSlug" }
    $owner = $repoParts[0]
    $name = $repoParts[1]
    $allThreads = @()
    $cursor = $null
    do {
        $afterPart = if ($cursor) { ", after: `"$cursor`"" } else { "" }
        $query = @"
query(`$owner:String!, `$repo:String!, `$number:Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$number) {
      reviewThreads(first: 100$afterPart) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          isOutdated
          comments(first: 5) {
            nodes {
              body
              path
              line
              url
              author { login }
            }
          }
        }
      }
    }
  }
}
"@
        $threads = Invoke-Gh -Arguments @("api", "graphql", "-f", "query=$query", "-F", "owner=$owner", "-F", "repo=$name", "-F", "number=$($prObject.number)") -WorkingDirectory $RepoRoot
        if ($threads.ExitCode -ne 0) { throw "GitHub review-thread query failed: $($threads.Stderr)" }
        $threadObject = $threads.Stdout | ConvertFrom-Json
        $threadConnection = $threadObject.data.repository.pullRequest.reviewThreads
        if ($null -eq $threadConnection) { throw "GitHub review-thread query returned no thread connection" }
        $allThreads += @($threadConnection.nodes)
        $cursor = $threadConnection.pageInfo.endCursor
    } while ($threadConnection.pageInfo.hasNextPage -eq $true)

    $prObject | Add-Member -NotePropertyName reviewThreads -NotePropertyValue $allThreads -Force
    $prObject
}

function Get-PrChangedFilePaths {
    param($Files)
    $paths = @()
    foreach ($file in @($Files)) {
        if ($null -eq $file) { continue }
        if ($file -is [string]) {
            $paths += (Normalize-RepoPath $file)
            continue
        }
        if (Test-Property -Object $file -Name "path") {
            $paths += (Normalize-RepoPath ([string]$file.path))
            continue
        }
        if (Test-Property -Object $file -Name "filename") {
            $paths += (Normalize-RepoPath ([string]$file.filename))
            continue
        }
    }
    @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
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
    $ledger = Get-SetupLedger -SetupLedgerJson $SetupLedgerJson -SetupLedgerPath $SetupLedgerPath -Handoff $handoff -RemoteSlug $remoteSlug
    $verification = Get-VerificationLedger -VerificationLedgerJson $VerificationLedgerJson -VerificationLedgerPath $VerificationLedgerPath -SetupLedger $ledger
    $statusEntries = Get-GitStatusEntries -RepoRoot $root
    if ($statusEntries.Count -gt 0) {
        $residue = @($statusEntries | ForEach-Object { "$($_.Status) $(Normalize-RepoPath $_.Path)" })
        Stop-Contract -Phase $phase -Reason "git-visible residue remains before premerge" -Evidence @{ repo_root = $root; residue = $residue }
    }

    $prObject = if (-not [string]::IsNullOrWhiteSpace($PrFixturePath)) {
        Read-JsonInput -Path $PrFixturePath -Name "PR fixture"
    } else {
        Get-PrFromGh -RepoRoot $root -Pr $Pr -RemoteSlug $remoteSlug
    }

    if ([string]$prObject.url -ne [string]$verification.pr_url) {
        Stop-Contract -Phase $phase -Reason "PR URL does not match verification ledger" -Evidence @{ pr_url = $prObject.url; ledger_pr_url = $verification.pr_url }
    }
    if ($prObject.state -ne "OPEN") {
        Stop-Contract -Phase $phase -Reason "PR is not open" -Evidence @{ pr_state = $prObject.state; pr_url = $prObject.url }
    }
    if ($prObject.isDraft -eq $true) {
        Stop-Contract -Phase $phase -Reason "PR is still draft" -Evidence @{ pr_url = $prObject.url }
    }
    if ((Normalize-RepoPath ([string]$prObject.headRefName)) -ne (Normalize-RepoPath ([string]$ledger.branch))) {
        Stop-Contract -Phase $phase -Reason "PR head branch does not match setup ledger branch" -Evidence @{ pr_head = $prObject.headRefName; ledger_branch = $ledger.branch }
    }
    $defaultBranch = Get-BranchDefault -RepoRoot $root
    if ([string]::IsNullOrWhiteSpace($defaultBranch)) { $defaultBranch = [string]$prObject.baseRefName }
    if ([string]$prObject.baseRefName -ne $defaultBranch) {
        Stop-Contract -Phase $phase -Reason "PR base branch is not the remote default branch" -Evidence @{ pr_base = $prObject.baseRefName; default_branch = $defaultBranch }
    }

    $issueNumber = Get-IssueNumberFromUrl -IssueUrl ([string]$ledger.issue_url)
    if (-not (Test-ClosingKeywordForIssue -Body ([string]$prObject.body) -IssueNumber $issueNumber -RemoteSlug $remoteSlug)) {
        Stop-Contract -Phase $phase -Reason "PR body lacks a GitHub closing keyword for the exact linked issue" -Evidence @{ pr_url = $prObject.url; issue_url = $ledger.issue_url }
    }
    if (-not (Test-ClosingReferenceIncludesIssue -References $prObject.closingIssuesReferences -IssueNumber $issueNumber)) {
        Stop-Contract -Phase $phase -Reason "PR closingIssuesReferences does not include the linked issue" -Evidence @{ pr_url = $prObject.url; issue_url = $ledger.issue_url }
    }
    if ([string]$prObject.mergeable -ne "MERGEABLE") {
        Stop-Contract -Phase $phase -Reason "GitHub does not report the PR mergeable" -Evidence @{ pr_url = $prObject.url; mergeable = $prObject.mergeable }
    }
    if ($prObject.reviewDecision -eq "CHANGES_REQUESTED") {
        Stop-Contract -Phase $phase -Reason "PR has requested changes" -Evidence @{ pr_url = $prObject.url }
    }

    if (-not (Test-Property -Object $prObject -Name "requiredChecks")) {
        Stop-Contract -Phase $phase -Reason "required GitHub check data is missing" -Evidence @{ pr_url = $prObject.url }
    }
    $requiredChecks = @($prObject.requiredChecks)
    if ($requiredChecks.Count -eq 0 -and [string]$handoff.required_checks_policy -ne "allow-none-with-local-proof") {
        Stop-Contract -Phase $phase -Reason "no required GitHub checks found" -Evidence @{ pr_url = $prObject.url; required_checks_policy = $handoff.required_checks_policy }
    }
    $badChecks = @()
    foreach ($check in $requiredChecks) {
        if ($null -eq $check) {
            $badChecks += "missing check object"
            continue
        }
        $bucket = [string]$check.bucket
        $state = [string]$check.state
        $name = [string]$check.name
        if ([string]::IsNullOrWhiteSpace($bucket) -or $bucket -ne "pass") {
            $badChecks += "$name bucket=$bucket state=$state"
        }
    }
    if ($badChecks.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "required GitHub checks are not passing" -Evidence @{ pr_url = $prObject.url; failing_checks = $badChecks }
    }

    if (-not (Test-Property -Object $prObject -Name "files")) {
        Stop-Contract -Phase $phase -Reason "PR changed file data is missing" -Evidence @{ pr_url = $prObject.url }
    }
    $changedFiles = Get-PrChangedFilePaths -Files $prObject.files
    if ($changedFiles.Count -eq 0) {
        Stop-Contract -Phase $phase -Reason "PR reports no changed files" -Evidence @{ pr_url = $prObject.url }
    }
    $coveredFiles = @(Get-StringArray $verification.changed_files_covered | ForEach-Object { Normalize-RepoPath $_ } | Sort-Object -Unique)
    $exemptFiles = @()
    if (Test-Property -Object $verification -Name "verification_exemptions") {
        $exemptFiles = @(Get-StringArray $verification.verification_exemptions | ForEach-Object { Normalize-RepoPath $_ } | Sort-Object -Unique)
    }
    $uncoveredFiles = @($changedFiles | Where-Object { $coveredFiles -notcontains $_ -and $exemptFiles -notcontains $_ })
    if ($uncoveredFiles.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "verification ledger does not cover all PR changed files" -Evidence @{
            pr_url = $prObject.url
            uncovered_files = $uncoveredFiles
            changed_files_covered = $coveredFiles
            verification_exemptions = $exemptFiles
        }
    }

    if (-not (Test-Property -Object $prObject -Name "reviewThreads")) {
        Stop-Contract -Phase $phase -Reason "PR review thread data is missing" -Evidence @{ pr_url = $prObject.url }
    }
    $blockingThreads = @()
    foreach ($thread in @($prObject.reviewThreads)) {
        if ($null -eq $thread) { continue }
        if ($thread.isResolved -eq $false -and $thread.isOutdated -ne $true) {
            $firstComment = @($thread.comments.nodes | Select-Object -First 1)[0]
            $blockingThreads += if ($null -ne $firstComment) { [string]$firstComment.url } else { "unresolved review thread" }
        }
    }
    if ($blockingThreads.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "PR has unresolved non-outdated review threads" -Evidence @{ pr_url = $prObject.url; blocking_threads = $blockingThreads }
    }

    $issueBody = $null
    $issueState = $null
    $issue = $null
    if (-not [string]::IsNullOrWhiteSpace($IssueFixturePath)) {
        $issue = Read-JsonInput -Path $IssueFixturePath -Name "issue fixture"
        $issueBody = [string]$issue.body
        $issueState = [string]$issue.state
    } else {
        $issueResult = Invoke-Gh -Arguments @("issue", "view", "$issueNumber", "--repo", $remoteSlug, "--json", "body,state,milestone") -WorkingDirectory $root
        if ($issueResult.ExitCode -ne 0) {
            Stop-Contract -Phase $phase -Reason "could not read linked issue acceptance criteria" -Evidence @{ issue_url = $ledger.issue_url; gh_stderr = $issueResult.Stderr }
        }
        $issue = $issueResult.Stdout | ConvertFrom-Json
        $issueBody = [string]$issue.body
        $issueState = [string]$issue.state
    }
    Assert-IssueMilestone -Issue $issue -Handoff $handoff -IssueUrl ([string]$ledger.issue_url)
    if ($issueState -ne "OPEN") {
        Stop-Contract -Phase $phase -Reason "linked issue is not open before merge" -Evidence @{ issue_url = $ledger.issue_url; issue_state = $issueState }
    }
    if (-not (Test-HasCheckbox -Text $issueBody)) {
        Stop-Contract -Phase $phase -Reason "linked issue has no acceptance-criteria checkboxes" -Evidence @{ issue_url = $ledger.issue_url }
    }
    if (Test-UncheckedCheckbox -Text $issueBody) {
        Stop-Contract -Phase $phase -Reason "linked issue still has unchecked acceptance criteria" -Evidence @{ issue_url = $ledger.issue_url }
    }

    $slicePath = Join-Path $root ([string]$ledger.slice_roadmap_path)
    if (-not (Test-Path -LiteralPath $slicePath -PathType Leaf)) {
        Stop-Contract -Phase $phase -Reason "local issue file path is missing" -Evidence @{ local_issue_file = $ledger.slice_roadmap_path }
    }
    $sliceText = Get-Content -LiteralPath $slicePath -Raw
    if (-not (Test-HasCheckbox -Text $sliceText)) {
        Stop-Contract -Phase $phase -Reason "local issue file has no gate checkboxes" -Evidence @{ local_issue_file = $ledger.slice_roadmap_path }
    }
    if (Test-UncheckedCheckbox -Text $sliceText) {
        Stop-Contract -Phase $phase -Reason "local issue file still has unchecked gates" -Evidence @{ local_issue_file = $ledger.slice_roadmap_path }
    }

    $evidence = @{
        repo_root = $root
        pr_url = $prObject.url
        issue_url = $ledger.issue_url
        issue_state = $issueState
        branch = $ledger.branch
        base_branch = $prObject.baseRefName
        local_issue_file = $ledger.slice_roadmap_path
        required_checks_count = $requiredChecks.Count
        pr_changed_files_count = $changedFiles.Count
        review_threads_count = @($prObject.reviewThreads).Count
        verification_commands_count = @($verification.proof_commands).Count
        milestone_contract = $milestoneEvidence
        handoff_slug = $handoff.slug
    }
    Complete-Contract -Phase $phase -Reason "premerge checks passed" -Evidence $evidence
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence $evidence
}
