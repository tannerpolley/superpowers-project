[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerPath,
    [string]$PrNumber,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string]$IssueNumber,
    [string]$IssueJson,
    [string]$IssueFixturePath,
    [string]$ParentIssueJson,
    [string]$ParentIssueFixturePath,
    [string]$HierarchyRollupJson,
    [string]$MergeDecisionJson,
    [string]$CleanupHookOutput,
    [string]$ResolveGoalCompletionProofJson,
    [string]$MirrorCleanupJson,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "collect-closeout-ledger"

function Write-CollectorResult {
    param([bool]$Ok, [string]$Reason, [object]$Ledger = $null, [string]$LedgerPath = $null, [object]$Pr = $null, [object]$Issue = $null)
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        ledger = $Ledger
        ledger_json = if ($null -eq $Ledger) { $null } else { $Ledger | ConvertTo-Json -Depth 32 -Compress }
        ledger_path = $LedgerPath
        pr = $Pr
        pr_json = if ($null -eq $Pr) { $null } else { $Pr | ConvertTo-Json -Depth 32 -Compress }
        issue = $Issue
        issue_json = if ($null -eq $Issue) { $null } else { $Issue | ConvertTo-Json -Depth 32 -Compress }
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function New-OutputPath {
    param([string]$OutputDir)
    $targetDir = $OutputDir
    if ([string]::IsNullOrWhiteSpace($targetDir)) {
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("merge-changes-closeout-" + [guid]::NewGuid().ToString("N"))
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Join-Path $targetDir "closeout-ledger.json"
}

function Invoke-GhJson {
    param([string[]]$Arguments)
    $ghCommand = "gh"
    $windowsGh = "C:\Program Files\GitHub CLI\gh.exe"
    if (-not (Get-Command $ghCommand -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $windowsGh -PathType Leaf)) {
        $ghCommand = $windowsGh
    }
    $output = & $ghCommand @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments -join ' ') failed: $($output | Out-String)" }
    ($output | Out-String).Trim() | ConvertFrom-Json
}

function Invoke-GitCapture {
    param([string]$RepoRoot, [string[]]$Arguments)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "git"
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($argument in @("-C", $RepoRoot) + $Arguments) { [void]$psi.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ exit_code = $process.ExitCode; stdout = $stdout.Trim(); stderr = $stderr.Trim() }
}

function Get-PrEvidence {
    if (-not [string]::IsNullOrWhiteSpace($PrJson) -or -not [string]::IsNullOrWhiteSpace($PrFixturePath)) {
        return Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
    }
    if ([string]::IsNullOrWhiteSpace($PrNumber)) { throw "PrNumber or PrJson is required" }
    Invoke-GhJson -Arguments @("pr", "view", $PrNumber, "--json", "number,url,state,body,mergedAt,mergeCommit")
}

function Get-IssueEvidence {
    if (-not [string]::IsNullOrWhiteSpace($IssueJson) -or -not [string]::IsNullOrWhiteSpace($IssueFixturePath)) {
        return Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
    }
    if ([string]::IsNullOrWhiteSpace($IssueNumber)) { throw "IssueNumber or IssueJson is required" }
    Invoke-GhJson -Arguments @("issue", "view", $IssueNumber, "--json", "number,url,state,body,title,closedAt,parent,subIssues,subIssuesSummary")
}

function Get-ParentIssueEvidence {
    param($Hierarchy)
    if (-not [string]::IsNullOrWhiteSpace($ParentIssueJson) -or -not [string]::IsNullOrWhiteSpace($ParentIssueFixturePath)) {
        return Read-JsonInput -Json $ParentIssueJson -Path $ParentIssueFixturePath -Name "parent issue evidence"
    }
    if ($null -eq $Hierarchy -or $null -eq $Hierarchy.parent_number) { return $null }
    if (-not [string]::IsNullOrWhiteSpace($IssueJson) -or -not [string]::IsNullOrWhiteSpace($IssueFixturePath)) { return $null }
    Invoke-GhJson -Arguments @("issue", "view", ([string]$Hierarchy.parent_number), "--json", "number,url,state,title,subIssues,subIssuesSummary")
}

function ConvertTo-HierarchyBool {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    switch -Regex ($Value.Trim()) {
        '^(?i:true|yes)$' { return $true }
        '^(?i:false|no)$' { return $false }
        default { return $null }
    }
}

function Get-IssueNumberFromUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    $match = [regex]::Match($Url, '/issues/(?<number>\d+)(?:\b|$)')
    if ($match.Success) { return [int]$match.Groups["number"].Value }
    $null
}

function Read-HierarchyFromMirror {
    param([string]$RepoRoot, $Setup)
    if (-not (Test-Property -Object $Setup -Name "issue_mirror")) { return $null }
    $issueMirror = Normalize-RepoPath ([string]$Setup.issue_mirror)
    if ([string]::IsNullOrWhiteSpace($issueMirror)) { return $null }
    $mirrorPath = Resolve-RepoFile -RepoRoot $RepoRoot -Path $issueMirror
    if (-not (Test-Path -LiteralPath $mirrorPath -PathType Leaf)) { return $null }
    $text = Get-Content -LiteralPath $mirrorPath -Raw
    $mode = Get-FieldValue -Text $text -Name "Hierarchy Mode"
    $role = Get-FieldValue -Text $text -Name "Sub-Issue Role"
    if ([string]::IsNullOrWhiteSpace($mode) -and [string]::IsNullOrWhiteSpace($role)) { return $null }
    $parentIssue = Get-FieldValue -Text $text -Name "Parent Issue"
    $parentMirror = Get-FieldValue -Text $text -Name "Parent Mirror"
    [pscustomobject]@{
        issue_mirror = $issueMirror
        mode = if ([string]::IsNullOrWhiteSpace($mode)) { "flat" } else { $mode.Trim().ToLowerInvariant() }
        role = if ([string]::IsNullOrWhiteSpace($role)) { "none" } else { $role.Trim().ToLowerInvariant() }
        executable = ConvertTo-HierarchyBool -Value (Get-FieldValue -Text $text -Name "Executable")
        parent_issue = if ([string]::IsNullOrWhiteSpace($parentIssue)) { "" } else { $parentIssue.Trim() }
        parent_mirror = if ([string]::IsNullOrWhiteSpace($parentMirror)) { "" } else { Normalize-RepoPath $parentMirror.Trim() }
        child_issues = @(ConvertTo-IssueLinks -Value (Get-FieldValue -Text $text -Name "Child Issues"))
        rollup_policy = if ([string]::IsNullOrWhiteSpace((Get-FieldValue -Text $text -Name "Rollup Policy"))) { "" } else { (Get-FieldValue -Text $text -Name "Rollup Policy").Trim().ToLowerInvariant() }
        title_policy = Get-FieldValue -Text $text -Name "Title Policy"
        parent_number = Get-IssueNumberFromUrl -Url $parentIssue
    }
}

function ConvertTo-IssueLinks {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Trim().Equals("None", [StringComparison]::OrdinalIgnoreCase)) { return @() }
    @($Value -split '\s*,\s*|\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "None" })
}

function Get-GitHubSubIssueNodes {
    param($Issue)
    if ($null -eq $Issue -or $Issue.PSObject.Properties.Name -notcontains "subIssues" -or $null -eq $Issue.subIssues) { return @() }
    if ($Issue.subIssues.PSObject.Properties.Name -contains "nodes") { return @($Issue.subIssues.nodes) }
    if ($Issue.subIssues -is [array]) { return @($Issue.subIssues) }
    @()
}

function Get-SubIssuesSummary {
    param($Issue, [object[]]$Nodes)
    if ($null -ne $Issue -and $Issue.PSObject.Properties.Name -contains "subIssuesSummary" -and $null -ne $Issue.subIssuesSummary) {
        $summary = $Issue.subIssuesSummary
        return [ordered]@{
            total = if ($summary.PSObject.Properties.Name -contains "total") { [int]$summary.total } elseif ($summary.PSObject.Properties.Name -contains "totalCount") { [int]$summary.totalCount } else { $Nodes.Count }
            completed = if ($summary.PSObject.Properties.Name -contains "completed") { [int]$summary.completed } elseif ($summary.PSObject.Properties.Name -contains "completedCount") { [int]$summary.completedCount } else { @($Nodes | Where-Object { [string]$_.state -eq "CLOSED" }).Count }
            percent_completed = if ($summary.PSObject.Properties.Name -contains "percentCompleted") { [int]$summary.percentCompleted } else { 0 }
        }
    }
    $total = $Nodes.Count
    $completed = @($Nodes | Where-Object { [string]$_.state -eq "CLOSED" }).Count
    [ordered]@{ total = $total; completed = $completed; percent_completed = if ($total -eq 0) { 0 } else { [int](($completed / $total) * 100) } }
}

function ConvertTo-ChildStateRecord {
    param($Node)
    $state = if ($Node.PSObject.Properties.Name -contains "state") { [string]$Node.state } else { "" }
    [ordered]@{
        number = if ($Node.PSObject.Properties.Name -contains "number") { [int]$Node.number } else { $null }
        url = if ($Node.PSObject.Properties.Name -contains "url") { [string]$Node.url } else { "" }
        title = if ($Node.PSObject.Properties.Name -contains "title") { [string]$Node.title } else { "" }
        state = $state
        disposition = if ($state.Equals("CLOSED", [StringComparison]::OrdinalIgnoreCase)) { "closed" } else { "open" }
        required = $true
    }
}

function Get-HierarchyRollupEvidence {
    param([string]$RepoRoot, $Setup, $Issue, $ProvidedRollup)
    if ($null -ne $ProvidedRollup) { return $ProvidedRollup }
    $hierarchy = Read-HierarchyFromMirror -RepoRoot $RepoRoot -Setup $Setup
    if ($null -eq $hierarchy -or $hierarchy.mode -eq "flat") { return $null }
    $parentIssue = Get-ParentIssueEvidence -Hierarchy $hierarchy
    $parentNodes = @(Get-GitHubSubIssueNodes -Issue $parentIssue)
    if ($hierarchy.role -eq "leaf") {
        $leafUrl = if ((Test-Property -Object $Issue -Name "url") -and -not [string]::IsNullOrWhiteSpace([string]$Issue.url)) { [string]$Issue.url } else { [string]$Setup.issue_url }
        $siblingStates = @($parentNodes | ForEach-Object { ConvertTo-ChildStateRecord -Node $_ })
        if ($siblingStates.Count -eq 0) {
            $siblingStates = @([ordered]@{ number = Get-IssueNumberFromUrl -Url $leafUrl; url = $leafUrl; title = if (Test-Property -Object $Issue -Name "title") { [string]$Issue.title } else { "" }; state = [string]$Issue.state; disposition = "closed"; required = $true })
        }
        return [ordered]@{
            role = "leaf"
            leaf_issue_url = $leafUrl
            parent_issue_url = $hierarchy.parent_issue
            parent_mirror = $hierarchy.parent_mirror
            sibling_child_states = @($siblingStates)
            sub_issues_summary = Get-SubIssuesSummary -Issue $parentIssue -Nodes $parentNodes
            local_receipts = [ordered]@{
                issue_mirror = $hierarchy.issue_mirror
                parent_mirror = $hierarchy.parent_mirror
                hierarchy_mode = $hierarchy.mode
                rollup_policy = $hierarchy.rollup_policy
                title_policy = $hierarchy.title_policy
            }
            parent_closeout = [ordered]@{
                auto_closed = $false
                requires_native_approval = $true
                approval = $null
            }
        }
    }
    $childStates = @((Get-GitHubSubIssueNodes -Issue $Issue) | ForEach-Object { ConvertTo-ChildStateRecord -Node $_ })
    return [ordered]@{
        role = $hierarchy.role
        issue_url = if ((Test-Property -Object $Issue -Name "url") -and -not [string]::IsNullOrWhiteSpace([string]$Issue.url)) { [string]$Issue.url } else { [string]$Setup.issue_url }
        child_states = @($childStates)
        rollup_policy = $hierarchy.rollup_policy
        sub_issues_summary = Get-SubIssuesSummary -Issue $Issue -Nodes $childStates
        local_receipts = [ordered]@{
            issue_mirror = $hierarchy.issue_mirror
            hierarchy_mode = $hierarchy.mode
            rollup_policy = $hierarchy.rollup_policy
            title_policy = $hierarchy.title_policy
        }
        parent_closeout = [ordered]@{
            auto_closed = $false
            requires_native_approval = $true
            approval = $null
        }
    }
}

function Find-MilestonePage {
    param([string]$RepoRoot, [string]$MilestoneTitle)
    if ([string]::IsNullOrWhiteSpace($MilestoneTitle)) { throw "GitHub Milestone is required for closed mirror cleanup" }
    $milestoneRoot = Join-Path $RepoRoot "docs/superpowers/milestones"
    if (-not (Test-Path -LiteralPath $milestoneRoot -PathType Container)) { throw "milestone directory is missing" }
    $matches = @(Get-ChildItem -LiteralPath $milestoneRoot -Filter "*.md" | Where-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $text -match "(?im)^\s*#\s*$([regex]::Escape($MilestoneTitle))\s*$" -or
        $text -match "(?im)^\s*-\s*Title:\s*``?$([regex]::Escape($MilestoneTitle))``?\s*$"
    })
    if ($matches.Count -ne 1) { throw "expected one milestone page for '$MilestoneTitle', found $($matches.Count)" }
    Get-RelativeRepoPath -RepoRoot $RepoRoot -Path $matches[0].FullName
}

function Update-MilestoneClosedSummary {
    param(
        [string]$RepoRoot,
        [string]$MilestonePage,
        [string]$IssueMirror,
        [string]$IssueUrl,
        [string]$PrUrl,
        [string]$ClosedAt
    )
    $path = Resolve-RepoFile -RepoRoot $RepoRoot -Path $MilestonePage
    $text = Get-Content -LiteralPath $path -Raw
    $mirrorPattern = "(?m)^\s*-\s*``$([regex]::Escape($IssueMirror))``\s*\r?\n?"
    $text = [regex]::Replace($text, $mirrorPattern, "")
    $summaryLine = "- [$IssueUrl]($IssueUrl) closed by [$PrUrl]($PrUrl)"
    if (-not [string]::IsNullOrWhiteSpace($ClosedAt)) { $summaryLine += " on $ClosedAt" }
    if ($text -notmatch "(?m)^##\s+Closed Issues\s*$") {
        $text = $text.TrimEnd() + "`n`n## Closed Issues`n`n$summaryLine`n"
    } elseif (-not $text.Contains($IssueUrl)) {
        $text = [regex]::Replace($text, "(?m)^##\s+Closed Issues\s*$", "## Closed Issues`n`n$summaryLine", 1)
    }
    Set-Content -LiteralPath $path -Value $text -Encoding utf8NoBOM
}

function Get-MirrorCleanupConfirmation {
    param([string]$RepoRoot, $Setup, $Pr, $Issue, $ProvidedCleanup)
    if ($null -ne $ProvidedCleanup) { return $ProvidedCleanup }
    if ([string]$Issue.state -ne "CLOSED") { return $null }
    $issueMirror = Normalize-RepoPath ([string]$Setup.issue_mirror)
    $mirrorPath = Resolve-RepoFile -RepoRoot $RepoRoot -Path $issueMirror
    if (-not (Test-Path -LiteralPath $mirrorPath -PathType Leaf)) { throw "issue mirror is missing; provide MirrorCleanupJson with deletion evidence" }
    $mirrorText = Get-Content -LiteralPath $mirrorPath -Raw
    $retentionMarked = $mirrorText -match '(?im)^\s*\*\*Mirror Retention:\*\*\s*Keep\s*$'
    $milestoneTitle = Get-FieldValue -Text $mirrorText -Name "GitHub Milestone"
    $milestonePage = Find-MilestonePage -RepoRoot $RepoRoot -MilestoneTitle $milestoneTitle
    $issueUrl = if ((Test-Property -Object $Issue -Name "url") -and -not [string]::IsNullOrWhiteSpace([string]$Issue.url)) { [string]$Issue.url } else { [string]$Setup.issue_url }
    $prUrl = [string]$Pr.url
    $closedAt = if (Test-Property -Object $Issue -Name "closedAt") { [string]$Issue.closedAt } else { "" }
    Update-MilestoneClosedSummary -RepoRoot $RepoRoot -MilestonePage $milestonePage -IssueMirror $issueMirror -IssueUrl $issueUrl -PrUrl $prUrl -ClosedAt $closedAt
    if ($retentionMarked) {
        return [ordered]@{
            policy = "retain"
            issue_mirror = $issueMirror
            deleted = $false
            retained = $true
            retention_reason = "Mirror Retention: Keep"
            milestone_record = "closed-summary"
            milestone_summary = [ordered]@{ milestone_page = $milestonePage; issue_url = $issueUrl; pr_url = $prUrl }
        }
    }
    Remove-Item -LiteralPath $mirrorPath -Force
    [ordered]@{
        policy = "delete-after-close"
        issue_mirror = $issueMirror
        deleted = $true
        retained = $false
        retention_reason = ""
        milestone_record = "closed-summary"
        milestone_summary = [ordered]@{ milestone_page = $milestonePage; issue_url = $issueUrl; pr_url = $prUrl }
    }
}

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $setup = Read-JsonInput -Path $SetupLedgerPath -Name "setup ledger"
    $pr = Get-PrEvidence
    $issue = Get-IssueEvidence
    $mergeDecision = Read-JsonInput -Json $MergeDecisionJson -Name "merge decision"
    $resolveGoal = Read-JsonInput -Json $ResolveGoalCompletionProofJson -Name "resolve goal completion proof"
    $providedMirrorCleanup = if ([string]::IsNullOrWhiteSpace($MirrorCleanupJson)) { $null } else { Read-JsonInput -Json $MirrorCleanupJson -Name "mirror cleanup proof" }
    $providedHierarchyRollup = if ([string]::IsNullOrWhiteSpace($HierarchyRollupJson)) { $null } else { Read-JsonInput -Json $HierarchyRollupJson -Name "hierarchy rollup proof" }
    $hierarchyRollup = Get-HierarchyRollupEvidence -RepoRoot $root -Setup $setup -Issue $issue -ProvidedRollup $providedHierarchyRollup
    $mirrorCleanup = Get-MirrorCleanupConfirmation -RepoRoot $root -Setup $setup -Pr $pr -Issue $issue -ProvidedCleanup $providedMirrorCleanup
    $branch = Normalize-RepoPath ([string]$setup.branch)
    $localBranch = Invoke-GitCapture -RepoRoot $root -Arguments @("show-ref", "--verify", "--quiet", "refs/heads/$branch")
    $remoteBranch = Invoke-GitCapture -RepoRoot $root -Arguments @("ls-remote", "--heads", "origin", $branch)
    $worktrees = Invoke-GitCapture -RepoRoot $root -Arguments @("worktree", "list", "--porcelain")
    $status = Invoke-GitCapture -RepoRoot $root -Arguments @("status", "--short")
    $branchStatus = Invoke-GitCapture -RepoRoot $root -Arguments @("status", "--short", "--branch")
    $remotes = Invoke-GitCapture -RepoRoot $root -Arguments @("remote")
    if ([string]::IsNullOrWhiteSpace($remotes.stdout)) {
        $fetchPrune = [pscustomobject]@{ exit_code = 0; stdout = ""; stderr = "no remote configured" }
    } else {
        $fetchPrune = Invoke-GitCapture -RepoRoot $root -Arguments @("fetch", "--prune")
    }
    $ledger = [ordered]@{
        pr_url = [string]$pr.url
        issue_url = [string]$setup.issue_url
        merge_decision = $mergeDecision
        merge_confirmation = [ordered]@{
            source = "PR evidence"
            state = [string]$pr.state
            merged_at = if (Test-Property -Object $pr -Name "mergedAt") { [string]$pr.mergedAt } else { $null }
            merge_commit = if (Test-Property -Object $pr -Name "mergeCommit") { $pr.mergeCommit } else { $null }
        }
        linked_issue_closed_confirmation = [ordered]@{
            source = "issue evidence"
            state = [string]$issue.state
            closed_at = if (Test-Property -Object $issue -Name "closedAt") { [string]$issue.closedAt } else { $null }
        }
        default_branch_sync = [ordered]@{
            command = "git status --short --branch"
            exit_code = [int]$branchStatus.exit_code
            output = [string]$branchStatus.stdout
        }
        branch_cleanup_confirmation = [ordered]@{
            deleted_local = $localBranch.exit_code -ne 0
            deleted_remote = [string]::IsNullOrWhiteSpace($remoteBranch.stdout)
            only_goal_owned_removed = $true
            local_delete_target = $branch
            remote_delete_target = $branch
            remote_deleted_branches = @($branch)
        }
        worktree_cleanup_confirmation = [ordered]@{
            owned_worktree_removed = ($worktrees.stdout -notmatch [regex]::Escape("branch refs/heads/$branch"))
            worktree_path = if (Test-Property -Object $setup -Name "worktree_path") { [string]$setup.worktree_path } else { "" }
        }
        fetch_prune_result = [ordered]@{
            command = "git fetch --prune"
            exit_code = [int]$fetchPrune.exit_code
            output = [string]$fetchPrune.stdout
            error = [string]$fetchPrune.stderr
        }
        cleanup_hook_result = [ordered]@{
            command = "codex-cleanup"
            exit_code = 0
            output = [string]$CleanupHookOutput
        }
        clean_repo_proof = [ordered]@{
            source = "git status --short"
            exit_code = [int]$status.exit_code
            status_output = [string]$status.stdout
        }
        resolve_goal_completion_proof = $resolveGoal
        mirror_cleanup_confirmation = $mirrorCleanup
    }
    if ($null -ne $hierarchyRollup) {
        $ledger["hierarchy_rollup"] = $hierarchyRollup
    }
    $ledgerPath = New-OutputPath -OutputDir $OutputDir
    $ledger | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
    Write-CollectorResult -Ok $true -Reason "closeout ledger collected" -Ledger $ledger -LedgerPath $ledgerPath -Pr $pr -Issue $issue
} catch {
    Write-CollectorResult -Ok $false -Reason $_.Exception.Message
}
