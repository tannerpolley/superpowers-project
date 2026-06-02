[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$PrReadyLedgerJson,
    [string]$PrReadyLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "pr-ready"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $setup = Read-JsonInput -Json $SetupLedgerJson -Path $SetupLedgerPath -Name "setup ledger"
    $ready = Read-JsonInput -Json $PrReadyLedgerJson -Path $PrReadyLedgerPath -Name "PR-ready ledger"
    if ([string]$ready.issue_url -ne [string]$setup.issue_url) { throw "PR-ready issue_url must match setup ledger" }
    if ((Normalize-RepoPath ([string]$ready.branch)) -ne (Normalize-RepoPath ([string]$setup.branch))) { throw "PR-ready branch must match setup ledger" }
    foreach ($field in @("branch_pushed", "pr_closes_issue", "acceptance_criteria_covered", "verification_passed")) {
        if ($ready.$field -ne $true) { throw "PR-ready ledger requires $field" }
    }
    foreach ($field in @("handoff_sent", "goal_completion_proof")) {
        if (-not (Test-Property -Object $ready -Name $field) -or $ready.$field -is [string]) { throw "PR-ready ledger $field must be structured" }
    }
    $goalProof = $ready.goal_completion_proof
    if ([string]$goalProof.status -ne "complete") { throw "goal completion proof must mark status complete" }
    if ([string]$goalProof.source -ne "update_goal" -and [string]$goalProof.source -ne "slash-command") { throw "goal completion proof must come from update_goal or exact slash-command evidence" }
    Complete-Contract -Phase $phase -Reason "PR-ready handoff checks passed" -Evidence @{ pr_url = [string]$ready.pr_url; issue_url = [string]$ready.issue_url; goal_status = [string]$goalProof.status }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
