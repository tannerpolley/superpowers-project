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
    $verification = Read-JsonInput -Json $VerificationLedgerJson -Path $VerificationLedgerPath -Name "verification ledger"
    $pr = Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
    $issue = Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
    $issueNumber = Get-IssueNumberFromUrl -IssueUrl ([string]$setup.issue_url)
    if (-not (Test-ClosingKeywordForIssue -Body ([string]$pr.body) -IssueNumber $issueNumber) -and -not (Test-ClosingReferenceIncludesIssue -References $pr.closingIssuesReferences -IssueNumber $issueNumber)) { throw "PR must close the linked issue" }
    $policy = if (Test-Property -Object $verification -Name "required_checks_policy") { [string]$verification.required_checks_policy } else { "require-existing" }
    $checks = @($pr.requiredChecks)
    if ($policy -eq "require-existing" -and $checks.Count -eq 0) { throw "required GitHub checks are missing" }
    foreach ($check in $checks) {
        $state = ([string]$check.state + " " + [string]$check.conclusion).ToUpperInvariant()
        if ($state -notmatch "SUCCESS|PASS|COMPLETED") { throw "required GitHub checks must pass" }
    }
    $issueBody = [string]$issue.body
    if ($issueBody -match "(?m)^\s*[-*]\s+\[ \]") {
        if (-not (Test-Property -Object $verification -Name "acceptance_criteria_closeout_proof") -or $verification.acceptance_criteria_closeout_proof -ne $true) { throw "issue acceptance criteria must be checked or reflected in closeout proof" }
    }
    $covered = Get-StringArray $verification.changed_files_covered
    $exempt = Get-StringArray $verification.verification_exemptions
    foreach ($file in @($pr.files)) {
        $path = Normalize-RepoPath ([string]$file.path)
        if ($covered -notcontains $path -and $exempt -notcontains $path) { throw "source plan verification receipts must cover PR changed file: $path" }
    }
    if ((Get-StringArray $verification.proof_commands).Count -eq 0) { throw "verification proof commands are required" }
    Complete-Contract -Phase $phase -Reason "premerge checks passed" -Evidence @{ pr_url = [string]$pr.url; issue_url = [string]$setup.issue_url; changed_files = @($pr.files | ForEach-Object { [string]$_.path }) }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
