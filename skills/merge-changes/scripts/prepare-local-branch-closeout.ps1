[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerPath,
    [string]$Branch,
    [string]$SourcePlan,
    [string]$ValidationCommand = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1",
    [string[]]$ProofCommands = @(),
    [string]$ReadinessReviewJson,
    [string]$ReadinessReviewPath,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "prepare-local-branch-closeout"

function Invoke-GitCapture {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = ($output | Out-String).Trim()
    }
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
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("merge-changes-local-branch-" + [guid]::NewGuid().ToString("N"))
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
    $setup = if (-not [string]::IsNullOrWhiteSpace($SetupLedgerPath)) {
        Read-JsonInput -Path $SetupLedgerPath -Name "setup ledger"
    } else {
        if ([string]::IsNullOrWhiteSpace($Branch)) { throw "Branch is required when SetupLedgerPath is omitted" }
        if ([string]::IsNullOrWhiteSpace($SourcePlan)) { throw "SourcePlan is required when SetupLedgerPath is omitted" }
        [pscustomobject]@{
            merge_mode = "local-branch"
            source_plan = $SourcePlan
            branch = $Branch
        }
    }
    $mode = Get-MergeMode -Setup $setup
    if ($mode -ne "local-branch") { throw "setup ledger merge_mode must be local-branch" }
    Assert-SourcePlanLinkage -Setup $setup
    Assert-BranchLinkage -Setup $setup
    $branchName = Normalize-RepoPath ([string]$setup.branch)
    if ($branchName -in @("main", "master", "origin/main", "origin/master")) { throw "local branch closeout cannot target default branch $branchName" }

    $currentBranch = Invoke-GitCapture -Root $root -Arguments @("branch", "--show-current")
    if ($currentBranch.exit_code -ne 0) { throw "git branch --show-current failed: $($currentBranch.output)" }
    if ([string]$currentBranch.output -ne "main") { throw "prepare local branch closeout must run from main" }
    $mainStatus = Invoke-GitCapture -Root $root -Arguments @("status", "--short")
    if ($mainStatus.exit_code -ne 0) { throw "git status failed: $($mainStatus.output)" }
    $upstream = Invoke-GitCapture -Root $root -Arguments @("rev-parse", "--abbrev-ref", "main@{upstream}")
    if ($upstream.exit_code -ne 0 -or [string]$upstream.output -ne "origin/main") { throw "main must track origin/main" }
    $aheadBehind = Invoke-GitCapture -Root $root -Arguments @("rev-list", "--left-right", "--count", "origin/main...main")
    if ($aheadBehind.exit_code -ne 0) { throw "origin/main comparison failed: $($aheadBehind.output)" }
    $parts = @(([string]$aheadBehind.output) -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -ne 2) { throw "could not read main ahead/behind counts" }
    $branchExists = Invoke-GitCapture -Root $root -Arguments @("show-ref", "--verify", "--quiet", "refs/heads/$branchName")
    if ($branchExists.exit_code -ne 0) { throw "local branch is missing: $branchName" }
    $changedFiles = @(Invoke-GitCapture -Root $root -Arguments @("diff", "--name-only", "main...$branchName")).output -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Normalize-RepoPath $_ }
    $validation = Invoke-PwshCommandCapture -Root $root -Command $ValidationCommand
    $readinessReview = Read-JsonInput -Json $ReadinessReviewJson -Path $ReadinessReviewPath -Name "readiness review"
    Assert-ReadinessReviewProof -Proof $readinessReview
    $allProofCommands = @($ProofCommands)
    if ($allProofCommands.Count -eq 0) { $allProofCommands = @($ValidationCommand) }

    $cleanProof = [ordered]@{
        source = "git status --short --branch"
        exit_code = [int]$mainStatus.exit_code
        branch = "main"
        upstream = "origin/main"
        ahead = [int]$parts[1]
        behind = [int]$parts[0]
        status_output = [string]$mainStatus.output
    }
    $verification = [ordered]@{
        proof_commands = @($allProofCommands)
        clean_synced_main_proof = $cleanProof
        validation_proof = [ordered]@{
            command = $ValidationCommand
            exit_code = [int]$validation.exit_code
            output = [string]$validation.output
        }
        readiness_review = $readinessReview
        changed_files = @($changedFiles)
    }
    $setupPath = if (-not [string]::IsNullOrWhiteSpace($SetupLedgerPath)) { $SetupLedgerPath } else { New-OutputPath -OutputDir $OutputDir -Name "local-branch-setup-ledger.json" }
    if ([string]::IsNullOrWhiteSpace($SetupLedgerPath)) {
        $setup | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
    }
    $verificationPath = New-OutputPath -OutputDir $OutputDir -Name "local-branch-verification-ledger.json"
    $verification | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $verificationPath -Encoding utf8NoBOM
    $premergeRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "premerge.ps1") -RepoRoot $root -SetupLedgerPath $setupPath -VerificationLedgerPath $verificationPath
    $premergeExit = $LASTEXITCODE
    $premerge = $premergeRaw | Out-String | ConvertFrom-Json
    $premergePath = New-OutputPath -OutputDir $OutputDir -Name "local-branch-premerge-result.json"
    ($premergeRaw | Out-String).Trim() | Set-Content -LiteralPath $premergePath -Encoding utf8NoBOM
    $evidence = [ordered]@{
        setup_ledger_path = [IO.Path]::GetFullPath($setupPath)
        verification_ledger_path = [IO.Path]::GetFullPath($verificationPath)
        premerge_result_path = [IO.Path]::GetFullPath($premergePath)
        premerge = $premerge
        changed_files = @($changedFiles)
        merge_question_id = "project_merge_approval"
        required_native_decision = "request_user_input project_merge_approval with selected_action merge"
    }
    if ($premergeExit -ne 0 -or $premerge.ok -ne $true) { Write-Result -Ok $false -Reason ([string]$premerge.reason) -Evidence $evidence }
    Write-Result -Ok $true -Reason "local branch premerge proof prepared" -Evidence $evidence
} catch {
    Write-Result -Ok $false -Reason $_.Exception.Message -Evidence @{}
}
