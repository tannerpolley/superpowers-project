[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$RunLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $ledgerFull = if ([IO.Path]::IsPathRooted($RunLedgerPath)) { [IO.Path]::GetFullPath($RunLedgerPath) } else { [IO.Path]::GetFullPath((Join-Path $repo $RunLedgerPath)) }
    $relative = ConvertTo-LoopControllerRelativePath -RepoRoot $repo -Path $ledgerFull
    if (-not $relative.StartsWith(".superpowers/runs/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "run ledger must live under .superpowers/runs by default: $relative"
    }

    $ledger = Read-LoopControllerJson -Path $ledgerFull
    Assert-LoopRequiredProperties -Object $ledger -Names @(
        "run_id", "trigger_source", "repo_root", "plugin_manifest_version", "plugin_contract_hash",
        "started_at", "updated_at", "status", "current_phase", "candidate_source", "candidate_id",
        "selected_route", "route_reason", "budget_policy", "attempts", "branch",
        "proof_artifacts", "verifier_artifacts", "metrics_artifacts"
    )

    if ([string]$ledger.status -notin @("created", "running", "paused", "blocked", "complete")) { throw "status is invalid: $($ledger.status)" }
    if ([string]$ledger.selected_route -notin @("brainstorm-spec", "write-plan", "create-issues", "implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes", "audit-project", "align-project")) {
        throw "selected_route is invalid: $($ledger.selected_route)"
    }

    $result = New-LoopControllerResult -Ok $true -Phase "loop-run-ledger" -Reason "run ledger is valid" -Evidence @{ run_ledger_path = $relative; status = [string]$ledger.status; selected_route = [string]$ledger.selected_route }
    $result | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-run-ledger" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
