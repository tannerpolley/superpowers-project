[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$PremergeResultJson,
    [string]$PremergeResultPath,
    [string]$MergeDecisionJson,
    [string]$MergeDecisionPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "merge-decision"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $premerge = Read-JsonInput -Json $PremergeResultJson -Path $PremergeResultPath -Name "premerge result"
    if ($premerge.ok -ne $true) { throw "premerge proof must pass before merge approval" }
    $decision = Read-JsonInput -Json $MergeDecisionJson -Path $MergeDecisionPath -Name "merge decision"
    Assert-MergeDecision -Decision $decision
    Complete-Contract -Phase $phase -Reason "merge approved" -Evidence @{ selected_action = [string]$decision.selected_action; question_id = [string]$decision.question_id }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
