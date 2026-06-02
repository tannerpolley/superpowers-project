[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$ExpectedRemoteSlug,
    [switch]$SkipGhAuth
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "repo-gate"

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    $top = Invoke-GitSimple -RepoRoot $root -Arguments @("rev-parse", "--show-toplevel")
    if ($top.ExitCode -ne 0) { throw "repo root is not a git repository" }
    $origin = Invoke-GitSimple -RepoRoot $root -Arguments @("remote", "get-url", "origin")
    $remoteSlug = $null
    if ($origin.ExitCode -eq 0 -and $origin.Stdout -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$') { $remoteSlug = "$($Matches.owner)/$($Matches.repo)" }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedRemoteSlug) -and $remoteSlug -ne $ExpectedRemoteSlug) { throw "target repo mismatch" }
    Complete-Contract -Phase $phase -Reason "repo gate passed" -Evidence @{ repo_root = $root; remote_slug = $remoteSlug; gh_auth_checked = -not $SkipGhAuth.IsPresent }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
