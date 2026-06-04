[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$VerificationLedgerJson,
    [string]$VerificationLedgerPath,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string]$IssueJson,
    [string]$IssueFixturePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "premerge"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $setup = Read-JsonInput -Json $SetupLedgerJson -Path $SetupLedgerPath -Name "setup ledger"
    $mode = Get-MergeMode -Setup $setup
    Assert-SourcePlanLinkage -Setup $setup
    Assert-BranchLinkage -Setup $setup
    $verification = Read-JsonInput -Json $VerificationLedgerJson -Path $VerificationLedgerPath -Name "verification ledger"

    if ($mode -eq "local-branch") {
        if (-not (Test-Property -Object $verification -Name "clean_synced_main_proof")) { throw "clean synced main proof is required for local-branch mode" }
        if (-not (Test-Property -Object $verification -Name "validation_proof")) { throw "validation proof is required for local-branch mode" }
        Assert-CleanSyncedMainProof -Proof $verification.clean_synced_main_proof
        Assert-ValidationProof -Proof $verification.validation_proof
        if ((Get-StringArray $verification.proof_commands).Count -eq 0) { throw "verification proof commands are required" }
        Complete-Contract -Phase $phase -Reason "premerge checks passed" -Evidence @{ mode = $mode; source_plan = [string]$setup.source_plan; branch = [string]$setup.branch }
    }

    $pr = Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"

    $issue = Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
    $issueNumber = Get-IssueNumberFromUrl -IssueUrl ([string]$setup.issue_url)
    if (-not (Test-ClosingKeywordForIssue -Body ([string]$pr.body) -IssueNumber $issueNumber) -and -not (Test-ClosingReferenceIncludesIssue -References $pr.closingIssuesReferences -IssueNumber $issueNumber)) { throw "PR must close the linked issue" }
    $issueBody = [string]$issue.body
    if ($issueBody -match "(?m)^\s*[-*]\s+\[ \]") {
        if (-not (Test-Property -Object $verification -Name "acceptance_criteria_closeout_proof") -or $verification.acceptance_criteria_closeout_proof -ne $true) { throw "issue acceptance criteria must be checked or reflected in closeout proof" }
    }
    Assert-PrVerification -Verification $verification -Pr $pr
    Complete-Contract -Phase $phase -Reason "premerge checks passed" -Evidence @{ mode = $mode; pr_url = [string]$pr.url; issue_url = [string]$setup.issue_url; changed_files = @($pr.files | ForEach-Object { [string]$_.path }) }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
