[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$InventoryPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

function Get-LoopCandidateRiskScore {
    param([string]$Risk)
    switch ($Risk) {
        "low" { 0 }
        "medium" { 10 }
        "high" { 20 }
        default { 30 }
    }
}

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $inventoryFullPath = if ([IO.Path]::IsPathRooted($InventoryPath)) { $InventoryPath } else { Join-Path $repo $InventoryPath }
    $inventory = Read-LoopControllerJson -Path $inventoryFullPath
    Assert-LoopRequiredProperties -Object $inventory -Names @("candidates")

    $validRoutes = @("brainstorm-spec", "write-plan", "create-issues", "implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes", "audit-project", "align-project")
    $ready = [System.Collections.Generic.List[object]]::new()
    $skipped = [System.Collections.Generic.List[object]]::new()

    foreach ($candidate in @($inventory.candidates)) {
        try {
            Assert-LoopRequiredProperties -Object $candidate -Names @("id", "source", "route", "ready", "risk", "source_path", "reason")
            if ([string]$candidate.route -notin $validRoutes) { throw "invalid route: $($candidate.route)" }
            $sourcePath = Join-Path $repo ([string]$candidate.source_path)
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "source path missing: $($candidate.source_path)" }
            if ($candidate.ready -ne $true) { throw "candidate is not ready: $($candidate.reason)" }
            $ready.Add($candidate) | Out-Null
        } catch {
            $candidateId = if (Test-LoopControllerProperty -Object $candidate -Name "id") { [string]$candidate.id } else { "unknown" }
            $skipped.Add([pscustomobject]@{ id = $candidateId; reason = $_.Exception.Message }) | Out-Null
        }
    }

    if ($ready.Count -eq 0) { throw "no ready candidates" }

    $selected = @(
        $ready |
            Sort-Object @{ Expression = { Get-LoopCandidateRiskScore -Risk ([string]$_.risk) } }, @{ Expression = { [string]$_.id } } |
            Select-Object -First 1
    )[0]

    [pscustomobject]@{
        ok = $true
        phase = "candidate-selection"
        selected_candidate_id = [string]$selected.id
        selected_route = [string]$selected.route
        route_reason = [string]$selected.reason
        skipped = @($skipped)
    } | ConvertTo-Json -Depth 10
} catch {
    New-LoopControllerResult -Ok $false -Phase "candidate-selection" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
