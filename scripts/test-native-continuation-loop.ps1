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

$checks = [System.Collections.Generic.List[object]]::new()
$skillRoot = Join-Path $RepoRoot "skills"
$workflowSkillNames = @(
    "superpowers-project",
    "project-setup",
    "project-orchestrate",
    "project-brainstorm",
    "project-plan",
    "project-issue",
    "project-resolve",
    "project-merge",
    "project-doctor"
)

foreach ($skillName in $workflowSkillNames) {
    $skillPath = Join-Path $skillRoot "$skillName\SKILL.md"
    $exists = Test-Path -LiteralPath $skillPath -PathType Leaf
    Add-Check $checks "$skillName SKILL.md exists" $exists "missing $skillPath"
    if (-not $exists) { continue }

    $text = Get-Content -LiteralPath $skillPath -Raw
    foreach ($needle in @(
        '## Native Continuation Loop',
        'Do not end the turn',
        'until a native continuation question returns `Stop` or `Done`',
        'After every completed action',
        'ask another native continuation question',
        'A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal',
        'Only a user-selected `Stop` or `Done` option is terminal'
    )) {
        Add-Check $checks "$skillName contains $needle" ($text.Contains($needle)) "$skillPath must contain continuation-loop contract: $needle"
    }

    $agentPath = Join-Path $skillRoot "$skillName\agents\openai.yaml"
    $agentExists = Test-Path -LiteralPath $agentPath -PathType Leaf
    Add-Check $checks "$skillName agents/openai.yaml exists" $agentExists "missing $agentPath"
    if (-not $agentExists) { continue }

    $agentText = Get-Content -LiteralPath $agentPath -Raw
    foreach ($needle in @(
        'After every completed action, ask the next native continuation or permission question',
        'Do not end the workflow until the user selects Stop or Done through native continuation input',
        'A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal'
    )) {
        Add-Check $checks "$skillName metadata contains $needle" ($agentText.Contains($needle)) "$agentPath must contain continuation-loop metadata: $needle"
    }
}

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "native-continuation-loop"
    checks = $checks
} | ConvertTo-Json -Depth 8

if ($failed.Count -gt 0) { exit 1 }
