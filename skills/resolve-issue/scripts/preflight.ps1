[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$HandoffJson,
    [string]$HandoffPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "preflight"

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $handoff = Read-JsonInput -Json $HandoffJson -Path $HandoffPath -Name "handoff"
    foreach ($field in @("issue_url", "issue_mirror", "source_plan", "branch", "goal_objective", "proof_oracle")) {
        if (-not (Test-Property -Object $handoff -Name $field)) { throw "$field is required in handoff" }
    }
    $issueMirror = Assert-UnderRepoPath -RepoRoot $root -Path ([string]$handoff.issue_mirror) -Prefix "docs/superpowers/issues" -Name "issue mirror"
    $sourcePlan = Assert-UnderRepoPath -RepoRoot $root -Path ([string]$handoff.source_plan) -Prefix "docs/superpowers/plans" -Name "source plan"
    if (-not (Test-Path -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $issueMirror) -PathType Leaf)) { throw "issue mirror file is missing" }
    if (-not (Test-Path -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $sourcePlan) -PathType Leaf)) { throw "source plan does not exist" }
    Assert-ExecutableIssueMirror -Text (Get-Content -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $issueMirror) -Raw)
    $dirty = Invoke-GitSimple -RepoRoot $root -Arguments @("status", "--porcelain=v1")
    if ($dirty.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($dirty.Stdout)) { throw "unrelated dirty changes are present" }
    Complete-Contract -Phase $phase -Reason "preflight passed" -Evidence @{ issue_mirror = $issueMirror; source_plan = $sourcePlan; branch = Normalize-RepoPath ([string]$handoff.branch) }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
