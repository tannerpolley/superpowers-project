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

function Test-NestedContinuationBlocks {
    param(
        [string]$Text,
        [string]$Forbidden
    )

    $questionIds = [regex]::Matches($Text, 'Question id:\s*`([^`]+)`')
    if ($questionIds.Count -eq 0) {
        return -not $Text.Contains($Forbidden)
    }

    for ($index = 0; $index -lt $questionIds.Count; $index++) {
        $current = $questionIds[$index]
        $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $Text.Length }
        $block = $Text.Substring($current.Index, $nextStart - $current.Index)
        $questionId = $current.Groups[1].Value
        if ($questionId.EndsWith("_next_step")) { continue }
        if ($block.Contains($Forbidden)) { return $false }
    }

    return $true
}

function Test-NestedContinuationBlocksRegex {
    param(
        [string]$Text,
        [string]$ForbiddenPattern
    )

    $questionIds = [regex]::Matches($Text, 'Question id:\s*`([^`]+)`')
    if ($questionIds.Count -eq 0) {
        return $true
    }

    for ($index = 0; $index -lt $questionIds.Count; $index++) {
        $current = $questionIds[$index]
        $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $Text.Length }
        $block = $Text.Substring($current.Index, $nextStart - $current.Index)
        $questionId = $current.Groups[1].Value
        if ($questionId.EndsWith("_next_step") -or $questionId.EndsWith("_final_health_gate")) { continue }
        if ([regex]::IsMatch($block, $ForbiddenPattern)) { return $false }
    }

    return $true
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
$intermediateSkillNames = @(
    "initiate-workflow",
    "setup-project",
    "orchestrate-issues",
    "brainstorm-spec",
    "write-plan",
    "implement-plan",
    "create-issues",
    "resolve-issue"
)
$finalCapableSkillNames = @("merge-changes", "audit-project")

foreach ($skillName in $workflowSkillNames) {
    $skillPath = Join-Path $skillRoot "$skillName\SKILL.md"
    $exists = Test-Path -LiteralPath $skillPath -PathType Leaf
    Add-Check $checks "$skillName SKILL.md exists" $exists "missing $skillPath"
    if (-not $exists) { continue }

    $text = Get-Content -LiteralPath $skillPath -Raw
    foreach ($needle in @(
        '## Native Continuation Loop',
        'Do not end the turn',
        'until a native continuation question returns `Stop` or reaches a verified final `Done` gate',
        'After every completed action',
        'ask another native continuation question',
        'Only a user-selected `Stop` option or verified final `Done` gate is terminal',
        'Revisit is non-terminal',
        'Only Stop can break an intermediate loop before a verified final Done gate',
        'Review First is not a terminal answer',
        'The agent must not get out of the loop by itself',
        'ending a turn after a governed workflow action is invalid',
        'must not recommend Stop before verified final completion'
    )) {
        Add-Check $checks "$skillName contains $needle" ($text.Contains($needle)) "$skillPath must contain continuation-loop contract: $needle"
    }
    $terminalPhrases = @(
        'A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal',
        'A local merge, created issue, saved plan, completed audit, or synced live plugin is not terminal',
        'A pushed issue-backed commit, merged issue-backed PR, local branch merge, created issue, saved plan, completed audit, or synced live plugin is not terminal'
    )
    Add-Check $checks "$skillName contains non-terminal artifact contract" (@($terminalPhrases | Where-Object { $text.Contains($_) }).Count -gt 0) "$skillPath must contain a non-terminal artifact contract"

    foreach ($needle in @(
        '## Native Continuation Gate',
        'Continue?',
        'Yes',
        'No',
        'Revisit',
        'Stop',
        'top-level closeout question must use exactly three trajectory options',
        'Do not show Continue children as peer top-level options',
        'Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires',
        'Custom Other',
        'rendered Markdown artifacts',
        'return to the originating continuation gate',
        'Nested Yes-route menus must not include Stop / Done',
        'Nested Revisit-route menus must not include Stop / Done',
        'Recommend Yes when at least one safe forward route exists',
        'Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion.',
        'Custom Other never terminates a workflow directly',
        'fresh confirmation question instead of terminating from Other'
    )) {
        Add-Check $checks "$skillName contains flowchart contract $needle" ($text.Contains($needle)) "$skillPath must contain native flowchart contract: $needle"
    }

    Add-Check $checks "$skillName contains artifact review gate" ($text.Contains('artifact review gate')) "$skillPath must contain closeout artifact review wording"
    Add-Check $checks "$skillName contains machine-readable artifact summary" ($text.Contains('machine-readable artifacts')) "$skillPath must summarize machine-readable artifacts at closeout"
    Add-Check $checks "$skillName contains broader project context closeout wording" ($text.Contains('broader project context')) "$skillPath must connect closeout findings to the broader project context"
    Add-Check $checks "$skillName contains recommended next route wording" (
        $text.Contains('recommended next route') -or
        $text.Contains('recommended next workflow') -or
        $text.Contains('what next steps are now recommended') -or
        $text.Contains('what the result means for the next workflow step') -or
        $text.Contains('Recommend `Project Implement`')
    ) "$skillPath must include a next-route or next-steps closeout recommendation"
    Add-Check $checks "$skillName contains findings interpretation wording" (
        $text.Contains('what the agent thinks those results mean') -or
        $text.Contains('what the agent thinks those results and findings mean') -or
        $text.Contains('what the results mean for the active goal') -or
        $text.Contains('explain what the results mean for the active goal and broader project context') -or
        $text.Contains('what the result means for the active goal') -or
        $text.Contains('what the result means for the next workflow step')
    ) "$skillPath must interpret the meaning of the closeout result"
    Add-Check $checks "$skillName omits old direction-coded option labels" (-not [regex]::IsMatch($text, '(?m)^\s*-\s+(Down|Left|Right):')) "$skillPath must not expose Down/Left/Right as option names"

    $agentPath = Join-Path $skillRoot "$skillName\agents\openai.yaml"
    $agentExists = Test-Path -LiteralPath $agentPath -PathType Leaf
    Add-Check $checks "$skillName agents/openai.yaml exists" $agentExists "missing $agentPath"
    if (-not $agentExists) { continue }

    $agentText = Get-Content -LiteralPath $agentPath -Raw
    foreach ($needle in @(
        'After every completed action, ask the next native continuation or permission question',
        'Do not end the workflow until the user selects Stop through native continuation input or reaches a verified final Done gate',
        'Revisit is non-terminal',
        'Only Stop can break an intermediate loop before a verified final Done gate',
        'Review First is not a terminal answer',
        'The agent must not get out of the loop by itself',
        'ending a turn after a governed workflow action is invalid',
        'must not recommend Stop before verified final completion',
        'Continue?',
        'Yes',
        'No',
        'Revisit',
        'Stop',
        'top-level closeout question must use exactly three trajectory options',
        'Do not show Continue children as peer top-level options',
        'Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires',
        'Custom Other',
        'rendered Markdown artifacts',
        'return to the originating continuation gate',
        'Nested Yes-route menus must not include Stop / Done',
        'Nested Revisit-route menus must not include Stop / Done',
        'Recommend Yes when at least one safe forward route exists',
        'Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion.',
        'fresh confirmation question instead of terminating from Other'
    )) {
        Add-Check $checks "$skillName metadata contains $needle" ($agentText.Contains($needle)) "$agentPath must contain continuation-loop metadata: $needle"
    }
    Add-Check $checks "$skillName metadata contains artifact review gate" ($agentText.Contains('artifact review gate')) "$agentPath must contain closeout artifact review wording"
    Add-Check $checks "$skillName metadata contains machine-readable artifact summary" ($agentText.Contains('machine-readable artifacts')) "$agentPath must summarize machine-readable artifacts at closeout"
    Add-Check $checks "$skillName metadata contains broader project context closeout wording" ($agentText.Contains('broader project context')) "$agentPath must connect closeout findings to the broader project context"
    Add-Check $checks "$skillName metadata contains recommended next route wording" (
        $agentText.Contains('recommended next route') -or
        $agentText.Contains('recommended next workflow') -or
        $agentText.Contains('what next steps are now recommended') -or
        $agentText.Contains('what the result means for the next workflow step') -or
        $agentText.Contains('Recommend `Project Implement`')
    ) "$agentPath must include a next-route or next-steps closeout recommendation"
    Add-Check $checks "$skillName metadata contains findings interpretation wording" (
        $agentText.Contains('what the agent thinks those results mean') -or
        $agentText.Contains('what the agent thinks those results and findings mean') -or
        $agentText.Contains('what the results mean for the active goal') -or
        $agentText.Contains('explain what the results mean for the active goal and broader project context') -or
        $agentText.Contains('what the result means for the active goal') -or
        $agentText.Contains('what the result means for the next workflow step')
    ) "$agentPath must interpret the meaning of the closeout result"
    Add-Check $checks "$skillName metadata contains non-terminal artifact contract" (@($terminalPhrases | Where-Object { $agentText.Contains($_) }).Count -gt 0) "$agentPath must contain a non-terminal artifact contract"
    foreach ($forbiddenMetadata in @(
        'with Down',
        'Down Continue',
        'Down Merge',
        'Right Stop',
        'Down default progress',
        'Left reiteration'
    )) {
        Add-Check $checks "$skillName metadata omits old direction wording $forbiddenMetadata" (-not $agentText.Contains($forbiddenMetadata)) "$agentPath must not advertise old direction wording: $forbiddenMetadata"
    }

    if ($intermediateSkillNames -contains $skillName) {
        $usesCombinedRouteLabel = $text.Contains('Right: `Stop / Done`') -or $agentText.Contains('Right: `Stop / Done`') -or $text.Contains('and No / Stop / Done') -or $agentText.Contains('and No / Stop / Done')
        Add-Check $checks "$skillName uses Stop for intermediate terminal routes" (-not $usesCombinedRouteLabel) "$skillName must use Stop for intermediate terminal routes"
    }
    if ($finalCapableSkillNames -contains $skillName) {
        Add-Check $checks "$skillName defines verified final Done semantics" ($text.Contains("verified final") -and $agentText.Contains("verified final")) "$skillName must define verified final Done semantics"
        Add-Check $checks "$skillName final Done requires clean worktree in SKILL.md" ($text.Contains("git status --short") -or $text.Contains("worktree is clean")) "$skillPath must state that final Done requires a clean worktree"
        Add-Check $checks "$skillName final Done requires clean worktree in metadata" ($agentText.Contains("git status --short") -or $agentText.Contains("worktree is clean")) "$agentPath must state that final Done requires a clean worktree"
    }

    foreach ($forbidden in @(
        'Right: `Stop / Done`: break the continuation loop.',
        'Right Stop / Done'
    )) {
        Add-Check $checks "$skillName nested routes avoid $forbidden" (Test-NestedContinuationBlocks -Text $text -Forbidden $forbidden) "$skillPath contains nested continuation wording that repeats terminal stop: $forbidden"
        Add-Check $checks "$skillName metadata nested routes avoid $forbidden" (Test-NestedContinuationBlocks -Text $agentText -Forbidden $forbidden) "$agentPath contains nested continuation wording that repeats terminal stop: $forbidden"
    }
    foreach ($forbiddenPattern in @(
        '(?m)^\s*-\s+Right:\s*`?Stop`?',
        '(?m)^\s*-\s+(?:Right:\s*)?`?Stop / Done`?',
        '(?m)^\s*-\s+(?:Right:\s*)?`?No / Stop / Done`?'
    )) {
        Add-Check $checks "$skillName nested routes avoid pattern $forbiddenPattern" (Test-NestedContinuationBlocksRegex -Text $text -ForbiddenPattern $forbiddenPattern) "$skillPath contains nested continuation wording that repeats terminal stop: $forbiddenPattern"
        Add-Check $checks "$skillName metadata nested routes avoid pattern $forbiddenPattern" (Test-NestedContinuationBlocksRegex -Text $agentText -ForbiddenPattern $forbiddenPattern) "$agentPath contains nested continuation wording that repeats terminal stop: $forbiddenPattern"
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
        'including more than three peer options or independent questions when useful',
        'Recommend No / Stop / Done only for explicit terminal, blocker, or user-requested stop states',
        'Recommend Stop only for explicit mid-loop terminal or blocker states. Recommend Done only at a verified final Done gate.',
        'Custom answers that mean a mid-loop exit are treated as Stop',
        'Custom answers that claim completion before proof exists are treated as Stop',
        'Custom Other is terminal only when it explicitly says Stop',
        'Custom answers are terminal only when they explicitly say Stop',
        'Treat it as terminal only when it explicitly says Stop'
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
