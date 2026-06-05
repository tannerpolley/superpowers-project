[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$CloseoutResultJson,
    [string]$CloseoutResultPath,
    [string]$ContinuationDecisionJson,
    [string]$ContinuationDecisionPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "terminal-closeout"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $closeout = Read-JsonInput -Json $CloseoutResultJson -Path $CloseoutResultPath -Name "closeout result"
    if ($closeout.ok -ne $true) { throw "closeout result must be ok before terminal closeout" }
    if ([string]$closeout.phase -ne "closeout") { throw "closeout result phase must be closeout" }
    $decision = Read-JsonInput -Json $ContinuationDecisionJson -Path $ContinuationDecisionPath -Name "continuation decision"
    Assert-MergeTerminalContinuationDecision -Decision $decision
    Complete-Contract -Phase $phase -Reason "merge terminal closeout is permitted" -Evidence @{
        question_id = [string]$decision.question_id
        selected_option_id = [string]$decision.selected_option_id
        terminal_state = [string]$decision.terminal_state
        pr_url = if (Test-Property -Object $closeout -Name "evidence") { [string]$closeout.evidence.pr_url } else { "" }
        issue_url = if (Test-Property -Object $closeout -Name "evidence") { [string]$closeout.evidence.issue_url } else { "" }
    }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
