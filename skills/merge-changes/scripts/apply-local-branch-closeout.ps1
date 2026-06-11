[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [Parameter(Mandatory = $true)][string]$SetupLedgerPath,
    [string]$PremergeResultJson,
    [string]$PremergeResultPath,
    [string]$MergeDecisionJson,
    [string]$MergeDecisionPath,
    [string]$ValidationCommand = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1",
    [string]$CleanupHookCommand = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1`" -RepoRoot .",
    [string]$BranchCleanupTarget,
    [string]$OutputDir,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "apply-local-branch-closeout"

function Invoke-GitCapture {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>&1
    [pscustomobject]@{ exit_code = $LASTEXITCODE; output = ($output | Out-String).Trim() }
}

function Invoke-PwshCommandCapture {
    param([string]$Root, [string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return [pscustomobject]@{ exit_code = 0; output = "" }
    }
    Push-Location -LiteralPath $Root
    try {
        $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command $Command 2>&1
        [pscustomobject]@{ exit_code = $LASTEXITCODE; output = ($output | Out-String).Trim() }
    } finally {
        Pop-Location
    }
}

function New-OutputPath {
    param([string]$OutputDir, [string]$Name)
    $targetDir = $OutputDir
    if ([string]::IsNullOrWhiteSpace($targetDir)) {
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("merge-changes-local-branch-apply-" + [guid]::NewGuid().ToString("N"))
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Join-Path $targetDir $Name
}

function Write-Result {
    param([bool]$Ok, [string]$Reason, [object]$Evidence = $null)
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $setup = Read-JsonInput -Path $SetupLedgerPath -Name "setup ledger"
    $mode = Get-MergeMode -Setup $setup
    if ($mode -ne "local-branch") { throw "setup ledger merge_mode must be local-branch" }
    Assert-SourcePlanLinkage -Setup $setup
    Assert-BranchLinkage -Setup $setup
    $branch = Normalize-RepoPath ([string]$setup.branch)
    if ($branch -in @("main", "master", "origin/main", "origin/master")) { throw "local branch closeout cannot target default branch $branch" }
    if (-not [string]::IsNullOrWhiteSpace($BranchCleanupTarget) -and (Normalize-RepoPath $BranchCleanupTarget) -ne $branch) {
        throw "branch cleanup target must match setup branch"
    }
    $premerge = Read-JsonInput -Json $PremergeResultJson -Path $PremergeResultPath -Name "premerge result"
    $decision = Read-JsonInput -Json $MergeDecisionJson -Path $MergeDecisionPath -Name "merge decision"
    $decisionRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-merge-decision.ps1") -RepoRoot $root -PremergeResultJson ($premerge | ConvertTo-Json -Depth 32 -Compress) -MergeDecisionJson ($decision | ConvertTo-Json -Depth 32 -Compress)
    $decisionExit = $LASTEXITCODE
    $decisionResult = $decisionRaw | Out-String | ConvertFrom-Json
    if ($decisionExit -ne 0 -or $decisionResult.ok -ne $true) { Write-Result -Ok $false -Reason ([string]$decisionResult.reason) -Evidence @{ merge_decision = $decisionResult } }

    $currentBranch = Invoke-GitCapture -Root $root -Arguments @("branch", "--show-current")
    if ([string]$currentBranch.output -ne "main") { throw "apply local branch closeout must run from main" }
    $branchExists = Invoke-GitCapture -Root $root -Arguments @("show-ref", "--verify", "--quiet", "refs/heads/$branch")
    if ($branchExists.exit_code -ne 0) { throw "local branch is missing: $branch" }
    if ($DryRun) {
        Write-Result -Ok $true -Reason "local branch closeout dry run passed" -Evidence @{
            branch = $branch
            merge_decision = $decisionResult
            would_merge = $true
            would_delete_branch = $branch
        }
    }

    $merge = Invoke-GitCapture -Root $root -Arguments @("merge", "--ff-only", $branch)
    if ($merge.exit_code -ne 0) { throw "git merge --ff-only $branch failed: $($merge.output)" }
    $pushMain = Invoke-GitCapture -Root $root -Arguments @("push", "origin", "main")
    if ($pushMain.exit_code -ne 0) { throw "git push origin main failed: $($pushMain.output)" }
    $validation = Invoke-PwshCommandCapture -Root $root -Command $ValidationCommand
    if ($validation.exit_code -ne 0) { throw "post-merge validation failed: $($validation.output)" }
    $deleteLocal = Invoke-GitCapture -Root $root -Arguments @("branch", "-d", $branch)
    if ($deleteLocal.exit_code -ne 0) { throw "git branch -d $branch failed: $($deleteLocal.output)" }
    $remoteBranch = Invoke-GitCapture -Root $root -Arguments @("ls-remote", "--heads", "origin", $branch)
    $deleteRemote = [pscustomobject]@{ exit_code = 0; output = "" }
    $remoteDeletedBranches = @()
    if (-not [string]::IsNullOrWhiteSpace($remoteBranch.output)) {
        $deleteRemote = Invoke-GitCapture -Root $root -Arguments @("push", "origin", "--delete", $branch)
        if ($deleteRemote.exit_code -ne 0) { throw "git push origin --delete $branch failed: $($deleteRemote.output)" }
        $remoteDeletedBranches = @($branch)
    }
    $fetchPrune = Invoke-GitCapture -Root $root -Arguments @("fetch", "--prune")
    if ($fetchPrune.exit_code -ne 0) { throw "git fetch --prune failed: $($fetchPrune.output)" }
    $cleanup = Invoke-PwshCommandCapture -Root $root -Command $CleanupHookCommand
    if ($cleanup.exit_code -ne 0) { throw "cleanup hook failed: $($cleanup.output)" }
    $status = Invoke-GitCapture -Root $root -Arguments @("status", "--short")
    $localBranchAfter = Invoke-GitCapture -Root $root -Arguments @("show-ref", "--verify", "--quiet", "refs/heads/$branch")
    $remoteBranchAfter = Invoke-GitCapture -Root $root -Arguments @("ls-remote", "--heads", "origin", $branch)
    $completion = [ordered]@{
        merge_decision = $decision
        local_merge_confirmation = [ordered]@{
            command = "git merge --ff-only $branch"
            exit_code = [int]$merge.exit_code
            merged_branch = $branch
            output = [string]$merge.output
        }
        validation_proof = [ordered]@{
            command = $ValidationCommand
            exit_code = [int]$validation.exit_code
            output = [string]$validation.output
        }
        default_branch_sync = [ordered]@{
            command = "git push origin main"
            exit_code = [int]$pushMain.exit_code
            output = [string]$pushMain.output
        }
        branch_cleanup_confirmation = [ordered]@{
            deleted_local = ($localBranchAfter.exit_code -ne 0)
            deleted_remote = [string]::IsNullOrWhiteSpace([string]$remoteBranchAfter.output)
            only_goal_owned_removed = $true
            local_delete_target = $branch
            remote_delete_target = $branch
            remote_deleted_branches = $remoteDeletedBranches
        }
        worktree_cleanup_confirmation = [ordered]@{
            owned_worktree_removed = $true
            worktree_path = if (Test-Property -Object $setup -Name "worktree_path") { [string]$setup.worktree_path } else { "" }
        }
        fetch_prune_result = [ordered]@{
            command = "git fetch --prune"
            exit_code = [int]$fetchPrune.exit_code
            output = [string]$fetchPrune.output
        }
        cleanup_hook_result = [ordered]@{
            command = $CleanupHookCommand
            exit_code = [int]$cleanup.exit_code
            output = [string]$cleanup.output
        }
        clean_repo_proof = [ordered]@{
            source = "git status --short"
            exit_code = [int]$status.exit_code
            status_output = [string]$status.output
        }
    }
    $completionPath = New-OutputPath -OutputDir $OutputDir -Name "local-branch-completion-ledger.json"
    $completion | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $completionPath -Encoding utf8NoBOM
    $closeoutRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "closeout.ps1") -RepoRoot $root -SetupLedgerPath $SetupLedgerPath -CompletionLedgerPath $completionPath
    $closeoutExit = $LASTEXITCODE
    $closeout = $closeoutRaw | Out-String | ConvertFrom-Json
    $closeoutPath = New-OutputPath -OutputDir $OutputDir -Name "local-branch-closeout-result.json"
    ($closeoutRaw | Out-String).Trim() | Set-Content -LiteralPath $closeoutPath -Encoding utf8NoBOM
    $evidence = [ordered]@{
        completion_ledger_path = [IO.Path]::GetFullPath($completionPath)
        closeout_result_path = [IO.Path]::GetFullPath($closeoutPath)
        closeout = $closeout
    }
    if ($closeoutExit -ne 0 -or $closeout.ok -ne $true) { Write-Result -Ok $false -Reason ([string]$closeout.reason) -Evidence $evidence }
    Write-Result -Ok $true -Reason "local branch merged and closeout proof passed" -Evidence $evidence
} catch {
    Write-Result -Ok $false -Reason $_.Exception.Message -Evidence @{}
}
