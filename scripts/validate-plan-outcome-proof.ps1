[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$PlanPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\outcome-proof.ps1")

function Normalize-RelativePath {
    param([string]$Path)
    ($Path -replace '\\', '/').TrimStart('.', '/')
}

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path)
    $rootFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $rootFull $Path)) }
    if (-not $candidate.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $candidate -ne $rootFull) {
        throw "plan path is outside repo root: $candidate"
    }
    $candidate
}

try {
    $repoRootFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
    $planFull = Resolve-RepoPath -Root $repoRootFull -Path $PlanPath
    if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) {
        throw "plan does not exist: $PlanPath"
    }

    $relativePlan = Normalize-RelativePath ([IO.Path]::GetRelativePath($repoRootFull, $planFull))
    if (-not $relativePlan.StartsWith("docs/superpowers/plans/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "plan must be under docs/superpowers/plans: $relativePlan"
    }

    $text = Get-Content -LiteralPath $planFull -Raw
    $result = Test-PlanOutcomeProof -Text $text
    [pscustomobject]@{
        ok = [bool]$result.ok
        phase = "plan-outcome-proof"
        plan_path = $relativePlan
        reason = [string]$result.reason
        fields = $result.fields
    } | ConvertTo-Json -Depth 16
    if (-not $result.ok) { exit 1 }
} catch {
    [pscustomobject]@{
        ok = $false
        phase = "plan-outcome-proof"
        reason = $_.Exception.Message
    } | ConvertTo-Json -Depth 8
    exit 1
}
