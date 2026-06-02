[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "validate-setup"

function Test-ContainsForbiddenGoalBuddyValue {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return (Normalize-RepoPath $Value).Contains("docs/goals") }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($item in $Value.Values) { if (Test-ContainsForbiddenGoalBuddyValue -Value $item) { return $true } }
        return $false
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) { if (Test-ContainsForbiddenGoalBuddyValue -Value $item) { return $true } }
        return $false
    }
    if ($Value -is [pscustomobject]) {
        foreach ($property in $Value.PSObject.Properties) { if (Test-ContainsForbiddenGoalBuddyValue -Value $property.Value) { return $true } }
    }
    $false
}

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $ledger = Read-JsonInput -Json $SetupLedgerJson -Path $SetupLedgerPath -Name "setup ledger"
    foreach ($forbidden in @("goal_board_path", "goalbuddy_checker")) {
        if (Test-Property -Object $ledger -Name $forbidden) { throw "$forbidden is outside the native goal setup ledger" }
    }
    if (Test-ContainsForbiddenGoalBuddyValue -Value $ledger) { throw "docs/goals is outside the default execution model" }
    foreach ($field in @("issue_url", "issue_mirror", "source_plan", "branch", "goal_activation_proof", "goal_objective", "execution_decision", "proof_oracle")) {
        if (-not (Test-Property -Object $ledger -Name $field)) { throw "$field is required in setup ledger" }
    }
    if (-not (Test-Property -Object $ledger -Name "goal_id") -and -not (Test-Property -Object $ledger -Name "thread_goal_proof")) { throw "goal_id or thread goal proof is required" }
    Assert-NativeGoalProof -Proof $ledger.goal_activation_proof
    Assert-ExecutionDecision -Decision $ledger.execution_decision
    if ([string]$ledger.execution_decision.selected_mode -eq "orchestrated-worker" -and (-not (Test-Property -Object $ledger -Name "worker_handoff") -or $null -eq $ledger.worker_handoff)) {
        throw "worker_handoff is required for orchestrated-worker execution"
    }
    if ([string]$ledger.execution_decision.selected_mode -eq "orchestrated-worker") {
        Assert-DynamicWorkPacketMap -Map $ledger.dynamic_work_packet_map
        Assert-DynamicWorkPacketMap -Map $ledger.worker_handoff.dynamic_work_packet_map
    }
    $issueMirror = Assert-UnderRepoPath -RepoRoot $root -Path ([string]$ledger.issue_mirror) -Prefix "docs/superpowers/issues" -Name "issue mirror"
    $sourcePlan = Assert-UnderRepoPath -RepoRoot $root -Path ([string]$ledger.source_plan) -Prefix "docs/superpowers/plans" -Name "source plan"
    if (-not (Test-Path -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $issueMirror) -PathType Leaf)) { throw "issue mirror file is missing" }
    if (-not (Test-Path -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $sourcePlan) -PathType Leaf)) { throw "source plan does not exist" }
    if ((Get-StringArray $ledger.proof_oracle).Count -eq 0) { throw "proof_oracle is required" }
    Complete-Contract -Phase $phase -Reason "setup ledger passed" -Evidence @{ issue_mirror = $issueMirror; source_plan = $sourcePlan; branch = Normalize-RepoPath ([string]$ledger.branch); goal_id = if (Test-Property -Object $ledger -Name "goal_id") { [string]$ledger.goal_id } else { [string]$ledger.thread_goal_proof } }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
