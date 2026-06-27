[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function New-FixtureRepo {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("global-policy-dedup-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path (Join-Path $root "skills\advanced-user-input") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root "skills\route-skill") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root "skills\advanced-user-input\SKILL.md") -Encoding utf8NoBOM -Value @'
# Advanced User Input

## Continuation Gates

Before any continuation, permission, push, publish, or merge question, complete an artifact review gate.
Strict artifact display is mandatory.
Do not merely say something changed.
Revisit is non-terminal.
Nested Yes-route menus must not include terminal options.
Nested Revisit-route menus must not include terminal options.
Custom Other never terminates a workflow directly.
A verified final Done gate requires final proof and a clean worktree.
'@
    $root
}

function Invoke-Validator {
    param([string]$FixtureRoot)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\validate-global-policy-deduplication.ps1") -RepoRoot $FixtureRoot 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = ($output | Out-String)
    }
}

$duplicateRoot = New-FixtureRepo
try {
    Set-Content -LiteralPath (Join-Path $duplicateRoot "skills\route-skill\SKILL.md") -Encoding utf8NoBOM -Value @'
# Route Skill

## Native Continuation Gate

Route-specific gate.
Strict artifact display is mandatory and must happen before the summary or native question.
Add the helper-required findings summary with route-specific status.
After artifacts are shown, add a separate findings summary that repeats helper policy.
The top-level closeout question must use exactly three trajectory options.
'@
    $duplicate = Invoke-Validator -FixtureRoot $duplicateRoot
    if ($duplicate.exit_code -eq 0) { throw "duplicate fixture unexpectedly passed validation" }
    if ($duplicate.output -notmatch "duplicates helper-owned global policy") { throw "duplicate fixture did not report duplicated global policy" }
} finally {
    if (Test-Path -LiteralPath $duplicateRoot) { Remove-Item -LiteralPath $duplicateRoot -Recurse -Force }
}

$compactRoot = New-FixtureRepo
try {
    Set-Content -LiteralPath (Join-Path $compactRoot "skills\route-skill\SKILL.md") -Encoding utf8NoBOM -Value @'
# Route Skill

## Native Continuation Gate

Follow `skills/advanced-user-input/SKILL.md` for global continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy.
Keep route-specific question IDs, validators, ledgers, and artifact inventory in this skill.
'@
    $compact = Invoke-Validator -FixtureRoot $compactRoot
    if ($compact.exit_code -ne 0) { throw "compact fixture failed validation: $($compact.output)" }
} finally {
    if (Test-Path -LiteralPath $compactRoot) { Remove-Item -LiteralPath $compactRoot -Recurse -Force }
}

$repoResult = Invoke-Validator -FixtureRoot $RepoRoot
if ($repoResult.exit_code -ne 0) {
    $repoResult.output
    exit $repoResult.exit_code
}

$repoResult.output
