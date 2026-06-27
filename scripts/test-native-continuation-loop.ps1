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

function Get-QuestionBlock {
    param(
        [string]$Text,
        [string]$QuestionId
    )

    $questionIds = [regex]::Matches($Text, 'Question id:\s*`([^`]+)`')
    for ($index = 0; $index -lt $questionIds.Count; $index++) {
        $current = $questionIds[$index]
        if ($current.Groups[1].Value -ne $QuestionId) { continue }
        $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $Text.Length }
        return $Text.Substring($current.Index, $nextStart - $current.Index)
    }
    return ""
}

$checks = [System.Collections.Generic.List[object]]::new()
$skillRoot = Join-Path $RepoRoot "skills"
. (Join-Path $RepoRoot "scripts\lib\project-skills.ps1")
$helperPath = Join-Path $skillRoot "advanced-user-input\SKILL.md"
$helperText = if (Test-Path -LiteralPath $helperPath -PathType Leaf) { Get-Content -LiteralPath $helperPath -Raw } else { "" }
$workflowSkillNames = @(Get-ProjectWorkflowSkillNames -RepoRoot $RepoRoot)
$finalCapableSkillNames = @(Get-ProjectFinalCapableSkillNames)
$intermediateSkillNames = @($workflowSkillNames | Where-Object { $finalCapableSkillNames -notcontains $_ })
$finalHealthGateIds = @{
    "align-project" = "project_align_final_health_gate"
    "loop-controller" = "project_loop_final_health_gate"
    "merge-changes" = "project_merge_final_health_gate"
}

foreach ($skillName in $workflowSkillNames) {
    $skillPath = Join-Path $skillRoot "$skillName\SKILL.md"
    $exists = Test-Path -LiteralPath $skillPath -PathType Leaf
    Add-Check $checks "$skillName SKILL.md exists" $exists "missing $skillPath"
    if (-not $exists) { continue }

    $text = Get-Content -LiteralPath $skillPath -Raw
    foreach ($needle in @(
        '## Native Continuation Loop',
        'skills/advanced-user-input/SKILL.md',
        'global native continuation',
        'verified Done',
        'artifact review policy',
        'route-specific gates',
        'After every completed route-specific action',
        'ask the next native continuation or permission question',
        'selected route can continue',
        'ask or report the exact blocker through the next native question'
    )) {
        Add-Check $checks "$skillName contains centralized loop reference $needle" ($text.Contains($needle)) "$skillPath must contain centralized continuation-loop reference: $needle"
    }

    foreach ($needle in @(
        '## Native Continuation Gate',
        'skills/advanced-user-input/SKILL.md',
        'global native question geometry',
        'Custom Other handling',
        'Revisit behavior',
        'Stop and verified Done terminal rules',
        'nested-route rules',
        'route-specific question IDs',
        'selected answers are executable routing'
    )) {
        Add-Check $checks "$skillName contains route-specific native gate $needle" ($text.Contains($needle)) "$skillPath must contain route-specific native gate reference: $needle"
    }
    if ($skillName -ne 'companion-interface') {
        Add-Check $checks "$skillName contains route-specific native gate Question id:" ($text.Contains('Question id:')) "$skillPath must contain route-specific native gate question IDs"
    }

    Add-Check $checks "$skillName contains artifact review gate" ($text.Contains('artifact review gate')) "$skillPath must contain closeout artifact review wording"
    Add-Check $checks "$skillName references helper-required artifact review" ($text.Contains('artifact review gate required by `skills/advanced-user-input/SKILL.md`')) "$skillPath must reference helper-owned artifact review gate"
    Add-Check $checks "$skillName preserves route-specific artifact inventory" ($text.Contains('route-specific artifact inventory:') -or $text.Contains('Route-specific artifact inventory must include')) "$skillPath must preserve route-specific artifact inventory"
    Add-Check $checks "$skillName delegates findings summary to helper" ($text.Contains('skills/advanced-user-input/SKILL.md') -and $helperText.Contains('After the artifact review gate, add a separate findings summary')) "$skillPath must delegate findings-summary policy to $helperPath"
    Add-Check $checks "$skillName omits helper-required summary duplication" (-not $text.Contains('Add the helper-required findings summary')) "$skillPath must not duplicate helper-required findings summary prose"
    Add-Check $checks "$skillName uses centralized findings interpretation wording" ($helperText.Contains('what the results say') -and $helperText.Contains('what that means for the active goal')) "$helperPath must own findings interpretation wording"
    Add-Check $checks "$skillName omits old direction-coded option labels" (-not [regex]::IsMatch($text, '(?m)^\s*-\s+(Down|Left|Right):')) "$skillPath must not expose Down/Left/Right as option names"

    $agentPath = Join-Path $skillRoot "$skillName\agents\openai.yaml"
    $agentExists = Test-Path -LiteralPath $agentPath -PathType Leaf
    Add-Check $checks "$skillName agents/openai.yaml exists" $agentExists "missing $agentPath"
    if (-not $agentExists) { continue }

    $agentText = Get-Content -LiteralPath $agentPath -Raw
    $debugNeedles = @(
        'Native Question Debug Ledger',
        'no tool exists to answer the modal prompt',
        'skill_name',
        'thread_id',
        'observed_status: waitingOnUserInput',
        'question_id',
        'prompt',
        'options',
        'recommended_option',
        'selected_answer',
        'answer_source: recommended-default | user-provided-debug-answer',
        'no_answer_tool_available: true',
        'mutation_allowed: false',
        'must not approve mutation'
    )
    if ($text.Contains('debug_question_mode')) {
        foreach ($needle in $debugNeedles) {
            Add-Check $checks "$skillName debug policy contains $needle" ($text.Contains($needle)) "$skillPath must contain debug-mode policy: $needle"
        }
    }
    foreach ($needle in @(
        'SKILL.md',
        'docs/superpowers/workflow-contract.yml'
    )) {
        Add-Check $checks "$skillName metadata contains compact reference $needle" ($agentText.Contains($needle)) "$agentPath must point to $needle instead of duplicating full policy"
    }
    foreach ($forbiddenMetadataPolicy in @(
        'After every completed action, ask the next native continuation or permission question',
        'Do not end the workflow until the user selects Stop through native continuation input or reaches a verified final Done gate',
        'The agent must not get out of the loop by itself',
        'ending a turn after a governed workflow action is invalid',
        'top-level closeout question must use exactly three trajectory options',
        'Nested Yes-route menus must not include terminal options',
        'Nested Revisit-route menus must not include terminal options',
        'Strict artifact display is mandatory',
        'do not merely say something changed',
        'fresh confirmation question with separate built-in labels instead of terminating from Other'
    )) {
        Add-Check $checks "$skillName metadata omits duplicated policy $forbiddenMetadataPolicy" (-not $agentText.Contains($forbiddenMetadataPolicy)) "$agentPath must not duplicate global policy: $forbiddenMetadataPolicy"
    }
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
        $usesCombinedRouteLabel = $text.Contains('Right: `stale terminal label`') -or $agentText.Contains('Right: `stale terminal label`') -or $text.Contains('and stale terminal option') -or $agentText.Contains('and stale terminal option')
        Add-Check $checks "$skillName uses Stop for intermediate terminal routes" (-not $usesCombinedRouteLabel) "$skillName must use Stop for intermediate terminal routes"
    }
    if ($finalCapableSkillNames -contains $skillName) {
        Add-Check $checks "$skillName defines verified final Done semantics" ($text.Contains("verified final") -or $text.Contains("verified Done")) "$skillName must define verified final Done semantics"
        Add-Check $checks "$skillName final Done requires clean worktree in SKILL.md" ($text.Contains("git status --short") -or $text.Contains("worktree is clean")) "$skillPath must state that final Done requires a clean worktree"
        $finalGateId = $finalHealthGateIds[$skillName]
        $finalGateBlock = Get-QuestionBlock -Text $text -QuestionId $finalGateId
        Add-Check $checks "$skillName defines $finalGateId" (-not [string]::IsNullOrWhiteSpace($finalGateBlock)) "$skillPath must define final health gate $finalGateId"
        foreach ($label in @("Done", "Revisit", "Stop")) {
            Add-Check $checks "$skillName final gate contains $label" ($finalGateBlock.Contains($label)) "$finalGateId must contain $label"
        }
        Add-Check $checks "$skillName final gate omits Yes" (-not [regex]::IsMatch($finalGateBlock, '(?m)^\s*-\s+`?Yes`?:')) "$finalGateId must not offer Yes"
    }
    if ($skillName -eq 'brainstorm-spec') {
        Add-Check $checks "$skillName shows chosen design artifact" ($text.Contains('chosen design plan')) "$skillPath must show the chosen brainstorm design/spec before closeout"
    }
    if ($skillName -eq 'write-plan') {
        Add-Check $checks "$skillName shows plan tasks and steps" ($text.Contains('full task list') -and $text.Contains('full step list')) "$skillPath must show plan tasks and steps before closeout"
    }
    if ($skillName -eq 'create-issues') {
        Add-Check $checks "$skillName shows created issue bodies" ($text.Contains('full issue body')) "$skillPath must show created issue bodies before closeout"
    }
    if ($skillName -in @('implement-plan', 'resolve-issue')) {
        Add-Check $checks "$skillName shows pre-push changed artifacts and tests" ($text.Contains('before push') -and $text.Contains('full changed-artifact inventory') -and $text.Contains('exact test values/results')) "$skillPath must show changed artifacts and exact test values/results before push"
    }

    foreach ($forbidden in @(
        'Right: terminal option: break the continuation loop.',
        'Right terminal label'
    )) {
        Add-Check $checks "$skillName nested routes avoid $forbidden" (Test-NestedContinuationBlocks -Text $text -Forbidden $forbidden) "$skillPath contains nested continuation wording that repeats terminal stop: $forbidden"
    }
    foreach ($forbiddenPattern in @(
        '(?m)^\s*-\s+Right:\s*`?Stop`?',
        '(?m)^\s*-\s+(?:Right:\s*)?`?stale terminal label`?',
        '(?m)^\s*-\s+(?:Right:\s*)?`?stale terminal option`?'
    )) {
        Add-Check $checks "$skillName nested routes avoid pattern $forbiddenPattern" (Test-NestedContinuationBlocksRegex -Text $text -ForbiddenPattern $forbiddenPattern) "$skillPath contains nested continuation wording that repeats terminal stop: $forbiddenPattern"
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
        'Recommend terminal option only for explicit terminal, blocker, or user-requested stop states',
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
