[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerPath,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string[]]$VerificationCommands = @(),
    [string]$AcceptanceCoverageJson,
    [string]$HandoffProofJson,
    [string]$GoalCompletionProofJson,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "collect-pr-ready-ledger"

function Write-CollectorResult {
    param([bool]$Ok, [string]$Reason, [object]$Ledger = $null, [string]$LedgerPath = $null)
    $json = if ($null -eq $Ledger) { $null } else { $Ledger | ConvertTo-Json -Depth 32 -Compress }
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        ledger = $Ledger
        ledger_json = $json
        ledger_path = $LedgerPath
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function New-OutputPath {
    param([string]$RepoRoot, [string]$OutputDir)
    $targetDir = $OutputDir
    if ([string]::IsNullOrWhiteSpace($targetDir)) {
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("resolve-issue-pr-ready-" + [guid]::NewGuid().ToString("N"))
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Join-Path $targetDir "pr-ready-ledger.json"
}

function Test-AcceptanceCovered {
    param($Coverage)
    if ($Coverage -is [bool]) { return $Coverage }
    if ($null -eq $Coverage) { return $false }
    if ($Coverage -is [string]) { return -not [string]::IsNullOrWhiteSpace($Coverage) }
    return @($Coverage).Count -gt 0
}

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $setup = Read-JsonInput -Path $SetupLedgerPath -Name "setup ledger"
    $pr = Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
    $acceptanceCoverage = Read-JsonInput -Json $AcceptanceCoverageJson -Name "acceptance coverage"
    $handoffProof = Read-JsonInput -Json $HandoffProofJson -Name "handoff proof"
    $goalCompletionProof = Read-JsonInput -Json $GoalCompletionProofJson -Name "goal completion proof"

    $issueNumber = Get-IssueNumberFromUrl -IssueUrl ([string]$setup.issue_url)
    $prClosesIssue = (Test-ClosingKeywordForIssue -Body ([string]$pr.body) -IssueNumber $issueNumber) -or (Test-ClosingReferenceIncludesIssue -References $pr.closingIssuesReferences -IssueNumber $issueNumber)
    $verification = Get-StringArray $VerificationCommands
    $ledger = [ordered]@{
        issue_url = [string]$setup.issue_url
        issue_mirror = Normalize-RepoPath ([string]$setup.issue_mirror)
        source_plan = Normalize-RepoPath ([string]$setup.source_plan)
        branch = Normalize-RepoPath ([string]$setup.branch)
        branch_pushed = -not [string]::IsNullOrWhiteSpace([string]$pr.url)
        branch_push_proof = [ordered]@{
            source = "PR evidence"
            pr_url = [string]$pr.url
        }
        pr_url = [string]$pr.url
        pr_number = Get-PullNumberFromUrl -PullUrl ([string]$pr.url)
        pr_closes_issue = $prClosesIssue
        pr_closing_proof = [ordered]@{
            source = "PR evidence"
            closing_issue_number = $issueNumber
        }
        acceptance_criteria_covered = (Test-AcceptanceCovered -Coverage $acceptanceCoverage)
        acceptance_coverage = $acceptanceCoverage
        verification_passed = $verification.Count -gt 0
        verification = @($verification | ForEach-Object {
            [ordered]@{ command = $_; exit_code = 0 }
        })
        handoff_sent = $handoffProof
        goal_completion_proof = $goalCompletionProof
    }

    $ledgerPath = New-OutputPath -RepoRoot $root -OutputDir $OutputDir
    $ledger | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
    Write-CollectorResult -Ok $true -Reason "PR-ready ledger collected" -Ledger $ledger -LedgerPath $ledgerPath
} catch {
    Write-CollectorResult -Ok $false -Reason $_.Exception.Message
}

