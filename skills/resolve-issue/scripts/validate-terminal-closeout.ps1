[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$PrReadyResultJson,
    [string]$PrReadyResultPath,
    [string]$ContinuationDecisionJson,
    [string]$ContinuationDecisionPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "terminal-closeout"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $prReady = Read-JsonInput -Json $PrReadyResultJson -Path $PrReadyResultPath -Name "PR-ready validation result"
    if ($prReady.ok -ne $true) { throw "PR-ready validation result must be ok before terminal closeout" }
    if ([string]$prReady.phase -ne "pr-ready") { throw "PR-ready validation result phase must be pr-ready" }
    $decision = Read-JsonInput -Json $ContinuationDecisionJson -Path $ContinuationDecisionPath -Name "continuation decision"
    Assert-ResolveTerminalContinuationDecision -Decision $decision
    Complete-Contract -Phase $phase -Reason "resolve terminal closeout is permitted" -Evidence @{
        question_id = [string]$decision.question_id
        selected_option_id = [string]$decision.selected_option_id
        terminal_state = [string]$decision.terminal_state
        pr_url = if (Test-Property -Object $prReady -Name "evidence") { [string]$prReady.evidence.pr_url } else { "" }
    }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
