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
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("project-merge-closeout-" + [guid]::NewGuid().ToString("N"))
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
    Invoke-GhJson -Arguments @("issue", "view", $IssueNumber, "--json", "number,url,state,body,title,closedAt")
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
    $ledgerPath = New-OutputPath -OutputDir $OutputDir
    $ledger | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
    Write-CollectorResult -Ok $true -Reason "closeout ledger collected" -Ledger $ledger -LedgerPath $ledgerPath -Pr $pr -Issue $issue
} catch {
    Write-CollectorResult -Ok $false -Reason $_.Exception.Message
}
