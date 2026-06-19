$ErrorActionPreference = "Stop"

function Test-Property {
    param([object]$Object, [string]$Name)
    $null -ne $Object.PSObject.Properties[$Name]
}

function Assert-OutcomeContract {
    param([object]$Contract)
    if ($null -eq $Contract -or $Contract -is [string]) { throw "outcome contract must be structured" }
    foreach ($field in @("intent", "truth_owner", "contract_interface", "cutover_decision", "displaced_path", "acceptance_evidence", "kill_criteria", "forbidden_moves")) {
        if (-not (Test-Property $Contract $field)) { throw "outcome contract missing $field" }
        $value = $Contract.$field
        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) { throw "outcome contract $field is empty" }
        if ($null -eq $value) { throw "outcome contract $field is empty" }
    }
}

function Assert-ContractReview {
    param([object]$Review)
    if ($null -eq $Review -or $Review -is [string]) { throw "contract review must be structured" }
    foreach ($field in @("plan_alignment", "correctness", "maintainability", "reality_evidence")) {
        if (-not (Test-Property $Review $field)) { throw "contract review missing $field" }
        if ($Review.$field -ne $true) { throw "contract review $field must be true" }
    }
}

function Test-ImplementPlanLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [object]$Ledger
    )

    $repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path

    if (-not (Test-Property $Ledger "plan_path") -or [string]::IsNullOrWhiteSpace([string]$Ledger.plan_path)) { throw "plan_path is required" }
    $planPath = [string]$Ledger.plan_path
    if ([IO.Path]::IsPathRooted($planPath)) { throw "plan_path must be repo-relative" }
    if (-not $planPath.StartsWith("docs/superpowers/plans/")) { throw "plan_path must be under docs/superpowers/plans" }
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath $planPath) -PathType Leaf)) { throw "approved plan file is required" }

    if (Test-Property $Ledger "issue_mirror_path") { throw "implement-plan must not create or require issue mirrors" }
    if (-not (Test-Property $Ledger "outcome_contract")) { throw "outcome contract is required" }
    Assert-OutcomeContract -Contract $Ledger.outcome_contract
    if (-not (Test-Property $Ledger "contract_review")) { throw "contract review is required" }
    Assert-ContractReview -Review $Ledger.contract_review
    if (-not (Test-Property $Ledger "native_goal") -or $Ledger.native_goal.activated -ne $true) { throw "native /goal activation proof is required" }
    if (-not (Test-Property $Ledger "branch") -or [string]::IsNullOrWhiteSpace([string]$Ledger.branch)) { throw "branch is required" }
    if ([string]$Ledger.branch -eq "main") { throw "implement-plan requires a development branch, not main" }
    if (-not (Test-Property $Ledger "topology") -or [string]::IsNullOrWhiteSpace([string]$Ledger.topology.selected_mode)) { throw "execution topology selection is required" }
    if ([string]$Ledger.topology.selected_mode -notin @("inline", "worker")) { throw "execution topology selected_mode is invalid" }
    if (-not (Test-Property $Ledger "verification") -or $Ledger.verification.passed -ne $true) { throw "passed verification is required" }
    if (-not (Test-Property $Ledger "push_permission")) { throw "native push permission is required" }
    if ([string]$Ledger.push_permission.question_id -ne "implement_plan_push_permission") { throw "push permission question_id is invalid" }
    if ([string]$Ledger.push_permission.selected_action -notin @("push-branch", "hold")) { throw "push permission selected_action is invalid" }
    if ([string]$Ledger.push_permission.selected_action -eq "push-branch") {
        if (-not (Test-Property $Ledger "branch_push_proof") -or $Ledger.branch_push_proof -is [string]) { throw "branch push proof is required" }
        if (-not (Test-Property $Ledger.branch_push_proof "pushed") -or $Ledger.branch_push_proof.pushed -ne $true) { throw "branch push proof must confirm the branch was pushed" }
    }
    if (-not (Test-Property $Ledger "merge_ready") -or $Ledger.merge_ready.ready -ne $true) { throw "merge-ready evidence is required" }
    if ([string]$Ledger.merge_ready.route -notin @("merge-changes", "approved-merge-route")) { throw "merge-ready route is invalid" }
    if (-not (Test-Property $Ledger.merge_ready "mode") -or [string]$Ledger.merge_ready.mode -ne "local-branch") { throw "implement-plan merge-ready mode must be local-branch" }
    if (Test-Property $Ledger "pr_url") { throw "implement-plan must not create pull requests" }
    if (Test-Property $Ledger "issue_closure_claim" -and $Ledger.issue_closure_claim -eq $true) { throw "implement-plan must not claim issue closure" }

    [pscustomobject]@{
        ok = $true
        phase = "implement-plan-ledger"
        plan_path = $planPath
        branch = [string]$Ledger.branch
        selected_mode = [string]$Ledger.topology.selected_mode
        push_action = [string]$Ledger.push_permission.selected_action
    }
}
