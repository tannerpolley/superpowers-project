[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Ok,
        [string]$Reason = "passed"
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

function Get-SkillText {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    Get-Content -LiteralPath $Path -Raw
}

$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$skillRoot = Join-Path $root "skills"
$checks = [System.Collections.Generic.List[object]]::new()

if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
    throw "missing skills directory: $skillRoot"
}

$helperPath = Join-Path $skillRoot "advanced-user-input\SKILL.md"
$helperText = Get-SkillText -Path $helperPath
Add-Check $checks "advanced-user-input owns global native policy" ($helperText.Contains("## Continuation Gates")) "$helperPath must contain the global continuation gate section"
foreach ($needle in @(
    "Before any continuation, permission, push, publish, or merge question, complete an artifact review gate",
    "Strict artifact display is mandatory",
    "Do not merely say something changed",
    "Revisit is non-terminal",
    "Nested Yes-route menus must not include terminal options",
    "Nested Revisit-route menus must not include terminal options",
    "Custom Other never terminates a workflow directly",
    "A verified final Done gate requires final proof and a clean worktree"
)) {
    Add-Check $checks "advanced-user-input contains global policy: $needle" ($helperText.Contains($needle)) "$helperPath must own global policy: $needle"
}

$duplicatedGlobalPolicy = @(
    "Strict artifact display is mandatory and must happen before the summary or native question.",
    "Do not merely say something changed.",
    "After the artifact review gate, add a separate findings summary that states what was done, what was fixed, what remains unsatisfactory or risky",
    "The top-level closeout question must use exactly three trajectory options",
    "Do not show Continue children beside Revisit and Stop in the same top-level question.",
    "Nested Yes-route menus must not include terminal options",
    "Nested Revisit-route menus must not include terminal options",
    "Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires.",
    "Custom Other never terminates a workflow directly",
    "ask a fresh confirmation question with separate built-in labels instead of terminating from Other",
    "The agent must not get out of the loop by itself",
    "ending a turn after a governed workflow action is invalid",
    "Do not infer terminal intent from a custom answer."
)

$workflowSkills = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object { $_.Name -ne "advanced-user-input" } | Sort-Object Name)
foreach ($skill in $workflowSkills) {
    $skillPath = Join-Path $skill.FullName "SKILL.md"
    $text = Get-SkillText -Path $skillPath
    Add-Check $checks "$($skill.Name) references advanced-user-input helper" ($text.Contains("skills/advanced-user-input/SKILL.md")) "$skillPath must point to the helper-owned global policy"
    Add-Check $checks "$($skill.Name) keeps route-specific policy local" ($text.Contains("route-specific")) "$skillPath must state that only route-specific gates/artifacts stay local"
    Add-Check $checks "$($skill.Name) keeps a native continuation section" ($text.Contains("## Native Continuation")) "$skillPath must keep a route-specific native continuation section"

    foreach ($forbidden in $duplicatedGlobalPolicy) {
        Add-Check $checks "$($skill.Name) omits duplicated global policy: $forbidden" (-not $text.Contains($forbidden)) "$skillPath duplicates helper-owned global policy: $forbidden"
    }
}

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "global-policy-deduplication"
    checks = $checks
} | ConvertTo-Json -Depth 8

if ($failed.Count -gt 0) { exit 1 }
