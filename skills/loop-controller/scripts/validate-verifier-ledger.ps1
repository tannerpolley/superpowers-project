[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$VerifierLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $ledgerPath = if ([IO.Path]::IsPathRooted($VerifierLedgerPath)) { $VerifierLedgerPath } else { Join-Path $repo $VerifierLedgerPath }
    $ledger = Read-LoopControllerJson -Path $ledgerPath
    Assert-LoopRequiredProperties -Object $ledger -Names @("candidate_id", "route", "risk", "verifier_type", "independent", "proof")

    if (@($ledger.proof).Count -eq 0) { throw "verifier proof is required" }
    if ([string]$ledger.risk -eq "high" -and $ledger.independent -ne $true) {
        throw "high-risk routes require independent verifier proof"
    }

    foreach ($proof in @($ledger.proof)) {
        Assert-LoopRequiredProperties -Object $proof -Names @("command", "ok", "artifact")
        if ($proof.ok -ne $true) { throw "verifier proof failed: $($proof.command)" }
    }

    New-LoopControllerResult -Ok $true -Phase "verifier-ledger" -Reason "verifier proof is valid" -Evidence @{
        candidate_id = [string]$ledger.candidate_id
        verifier_type = [string]$ledger.verifier_type
        independent = [bool]$ledger.independent
    } | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "verifier-ledger" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
