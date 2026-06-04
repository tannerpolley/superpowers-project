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
    "initiate-workflow",
    "setup-project",
    "orchestrate-issues",
    "brainstorm-spec",
    "write-plan",
    "implement-plan",
    "create-issues",
    "resolve-issue",
    "merge-changes",
    "audit-project"
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
        'Only a user-selected `Stop` or `Done` option is terminal',
        'Revisit is non-terminal',
        'the only Yes terminal exception is an explicit final Healthy -> Done gate',
        'Only No / Stop / Done can break the loop before that final Done gate',
        'Review First is not a terminal answer'
    )) {
        Add-Check $checks "$skillName contains $needle" ($text.Contains($needle)) "$skillPath must contain continuation-loop contract: $needle"
    }

    foreach ($needle in @(
        '## Native Continuation Gate',
        'Continue?',
        'Yes',
        'No',
        'Revisit',
        'Stop / Done',
        'top-level closeout question must use exactly three trajectory options',
        'Do not show Continue children as peer top-level options',
        'Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires',
        'Custom Other',
        'rendered Markdown artifacts',
        'return to the originating continuation gate'
    )) {
        Add-Check $checks "$skillName contains flowchart contract $needle" ($text.Contains($needle)) "$skillPath must contain native flowchart contract: $needle"
    }

    $agentPath = Join-Path $skillRoot "$skillName\agents\openai.yaml"
    $agentExists = Test-Path -LiteralPath $agentPath -PathType Leaf
    Add-Check $checks "$skillName agents/openai.yaml exists" $agentExists "missing $agentPath"
    if (-not $agentExists) { continue }

    $agentText = Get-Content -LiteralPath $agentPath -Raw
    foreach ($needle in @(
        'After every completed action, ask the next native continuation or permission question',
        'Do not end the workflow until the user selects Stop or Done through native continuation input',
        'A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal',
        'Revisit is non-terminal',
        'the only Yes terminal exception is an explicit final Healthy -> Done gate',
        'Only No / Stop / Done can break the loop before that final Done gate',
        'Review First is not a terminal answer',
        'Continue?',
        'Yes',
        'No',
        'Revisit',
        'Stop / Done',
        'top-level closeout question must use exactly three trajectory options',
        'Do not show Continue children as peer top-level options',
        'Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires',
        'Custom Other',
        'rendered Markdown artifacts',
        'return to the originating continuation gate'
    )) {
        Add-Check $checks "$skillName metadata contains $needle" ($agentText.Contains($needle)) "$agentPath must contain continuation-loop metadata: $needle"
    }

    foreach ($forbidden in @(
        'Ask one to three short questions',
        'for one to three short',
        'Ask no more than three',
        'no more than three milestone choices',
        'One call may ask 1-3 questions',
        'Each question must define 2-3 mutually exclusive options',
        'show all real peer routes when clearer',
        'Show four or more native options when they are real peer routes',
        'including more than three peer options or independent questions when useful'
    )) {
        Add-Check $checks "$skillName omits stale native limit $forbidden" (-not $text.Contains($forbidden) -and -not $agentText.Contains($forbidden)) "$skillName must not keep stale native UI limit wording: $forbidden"
    }
}

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "native-continuation-loop"
    checks = $checks
} | ConvertTo-Json -Depth 8

if ($failed.Count -gt 0) { exit 1 }
