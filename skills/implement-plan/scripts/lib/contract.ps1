$ErrorActionPreference = "Stop"

function Test-Property {
    param([object]$Object, [string]$Name)
    $null -ne $Object.PSObject.Properties[$Name]
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
    if (-not (Test-Property $Ledger "native_goal") -or $Ledger.native_goal.activated -ne $true) { throw "native /goal activation proof is required" }
    if (-not (Test-Property $Ledger "branch") -or [string]::IsNullOrWhiteSpace([string]$Ledger.branch)) { throw "branch is required" }
    if ([string]$Ledger.branch -eq "main") { throw "implement-plan requires a development branch, not main" }
    if (-not (Test-Property $Ledger "topology") -or [string]::IsNullOrWhiteSpace([string]$Ledger.topology.selected_mode)) { throw "execution topology selection is required" }
    if ([string]$Ledger.topology.selected_mode -notin @("inline", "worker")) { throw "execution topology selected_mode is invalid" }
    if (-not (Test-Property $Ledger "verification") -or $Ledger.verification.passed -ne $true) { throw "passed verification is required" }
    if (-not (Test-Property $Ledger "publish_permission")) { throw "native publish permission is required" }
    if ([string]$Ledger.publish_permission.question_id -ne "implement_plan_publish_permission") { throw "publish permission question_id is invalid" }
    if ([string]$Ledger.publish_permission.selected_action -notin @("push", "local-merge-ready", "hold")) { throw "publish permission selected_action is invalid" }
    if (-not (Test-Property $Ledger "merge_ready") -or $Ledger.merge_ready.ready -ne $true) { throw "merge-ready evidence is required" }
    if ([string]$Ledger.merge_ready.route -notin @("merge-changes", "approved-merge-route")) { throw "merge-ready route is invalid" }
    if (Test-Property $Ledger "issue_closure_claim" -and $Ledger.issue_closure_claim -eq $true) { throw "implement-plan must not claim issue closure" }

    [pscustomobject]@{
        ok = $true
        phase = "implement-plan-ledger"
        plan_path = $planPath
        branch = [string]$Ledger.branch
        selected_mode = [string]$Ledger.topology.selected_mode
        publish_action = [string]$Ledger.publish_permission.selected_action
    }
}

