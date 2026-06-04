[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$HandoffJson,
    [string]$HandoffPath
)

$ErrorActionPreference = "Stop"
$phase = "validate-worker-handoff"

function Complete {
    param([bool]$Ok, [string]$Reason, [object]$Evidence = $null)
    [ordered]@{ ok = $Ok; phase = $phase; reason = $Reason; evidence = $Evidence } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Has-Property {
    param($Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $text = if (-not [string]::IsNullOrWhiteSpace($HandoffJson)) {
        $HandoffJson
    } elseif (-not [string]::IsNullOrWhiteSpace($HandoffPath)) {
        $path = if ([IO.Path]::IsPathRooted($HandoffPath)) { $HandoffPath } else { Join-Path $root $HandoffPath }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "handoff path is missing" }
        Get-Content -LiteralPath $path -Raw
    } else {
        throw "HandoffJson or HandoffPath is required"
    }
    $handoff = $text | ConvertFrom-Json
    foreach ($field in @("issue_mirror", "source_plan", "worker_identity", "branch", "proof_oracle", "topology_handoff", "required_skills")) {
        if (-not (Has-Property -Object $handoff -Name $field)) { throw "handoff missing $field" }
    }
    foreach ($pathField in @("issue_mirror", "source_plan")) {
        $relative = [string]$handoff.$pathField
        $path = if ([IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $root $relative }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$pathField does not exist: $relative" }
    }
    $identity = $handoff.worker_identity
    foreach ($field in @("issue_number", "issue_slug", "thread_title", "branch", "evidence_folder", "pr_title")) {
        if (-not (Has-Property -Object $identity -Name $field) -or [string]::IsNullOrWhiteSpace([string]$identity.$field)) {
            throw "worker_identity missing $field"
        }
    }
    $expectedBranch = "codex/issue-$($identity.issue_number)-$($identity.issue_slug)"
    $expectedEvidence = "orchestrate-issues-issue-$($identity.issue_number)-$($identity.issue_slug)"
    if ([string]$identity.branch -ne $expectedBranch) { throw "worker_identity branch mismatch" }
    if ([string]$handoff.branch -ne $expectedBranch) { throw "handoff branch mismatch" }
    if ([string]$identity.evidence_folder -ne $expectedEvidence) { throw "worker_identity evidence folder mismatch" }
    if (-not ([string]$identity.thread_title).StartsWith("Resolve #$($identity.issue_number): ")) { throw "thread title must start with issue identity" }
    if (-not ([string]$identity.pr_title).StartsWith("Resolve #$($identity.issue_number): ")) { throw "PR title must start with issue identity" }
    if ($handoff.topology_handoff.worker_must_not_merge -ne $true) { throw "worker_must_not_merge must be true" }
    if ([string]$handoff.topology_handoff.merge_owner -ne "merge-changes") { throw "merge_owner must be merge-changes" }
    $required = @($handoff.required_skills | ForEach-Object { [string]$_ })
    foreach ($skill in @("superpowers:using-git-worktrees", "superpowers:test-driven-development", "superpowers:verification-before-completion", "superpowers:finishing-a-development-branch")) {
        if ($required -notcontains $skill) { throw "required skill missing: $skill" }
    }
    $proof = @($handoff.proof_oracle | ForEach-Object { [string]$_ })
    if ($proof.Count -eq 0) { throw "proof_oracle must contain at least one command" }
    Complete -Ok $true -Reason "worker handoff passed" -Evidence @{ branch = [string]$handoff.branch; issue_mirror = [string]$handoff.issue_mirror; source_plan = [string]$handoff.source_plan }
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}

