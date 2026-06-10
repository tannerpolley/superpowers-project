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
$skillPath = Join-Path $RepoRoot "skills\advanced-user-input\SKILL.md"
$metadataPath = Join-Path $RepoRoot "skills\advanced-user-input\agents\openai.yaml"

$exists = Test-Path -LiteralPath $skillPath -PathType Leaf
Add-Check $checks "advanced-user-input exists in plugin source" $exists "missing $skillPath"
$metadataExists = Test-Path -LiteralPath $metadataPath -PathType Leaf
Add-Check $checks "advanced-user-input has plugin UI metadata" $metadataExists "missing $metadataPath"

if ($exists) {
    $text = Get-Content -LiteralPath $skillPath -Raw

    foreach ($needle in @(
        "Use the smallest native question shape that preserves the real decision tree",
        "For project workflow closeout gates, always ask the three-way trajectory question first",
        "Do not flatten closeout into a five-option or larger peer menu",
        "Use larger native prompts only inside a selected branch",
        "Observed Codex Desktop behavior",
        "current runtime-permissive behavior",
        "Sequential Branching",
        "Bulk Question Sets",
        "Large Option Sets",
        "request_agent_input",
        "Do not collapse real routes into fake categories",
        "Ask exactly three top-level options",
        "Ask the top-level closeout as Continue?",
        "Use Yes for the progress route",
        "Use Revisit as the standard go-back route label",
        "Use Stop for mid-loop exits",
        "Use Done only for verified final states",
        "Done is invalid whenever ``git status --short`` is non-empty",
        "A verified final Done gate requires final proof and a clean worktree",
        "Before any continuation, permission, push, publish, or merge question, complete an artifact review gate",
        "Strict artifact display is mandatory",
        "Do not merely say something changed",
        "Show what was created or revised",
        "the chosen brainstorm design/spec",
        "the full plan task and step list",
        "the full issue mirror or created issue body",
        "exact test values/results",
        "what was done",
        "what was fixed",
        "what remains unsatisfactory or risky",
        "the agent's own feedback/opinion",
        "what the agent thinks those results mean",
        "what that means for the active goal",
        "what that means for the broader project context",
        "what next steps are now recommended",
        "Do not recommend Stop merely because a clean forward route exists",
        "The agent must not get out of the loop by itself",
        "ending a turn after a governed workflow action is invalid",
        "must not recommend Stop before verified final completion",
        "Push, publish, and merge approval questions are invalid until the artifact review gate and findings summary have been shown",
        "loaded thread may still be using older skill text",
        "re-ask that gate natively",
        "skipped step as terminal or implicit approval",
        "Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop",
        "Verified final health gates use exactly three top-level options: Done, Revisit, and Stop",
        "Do not put Continue children beside Revisit and Stop in the same top-level question",
        "Revisit is non-terminal",
        "Review First is not a terminal answer",
        "Only Stop can end an intermediate continuation loop before a verified final Done gate",
        "Other never terminates a workflow directly",
        'If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other',
        "Do not end a loop until the user chooses Stop or reaches a verified final Done gate through a built-in terminal option",
        "Custom answers that ask for another route, review, revision, repair, explanation, or continued work are non-terminal",
        "Custom answers that request revision, review, repair, more evidence, a different route, or stronger loop behavior are Revisit behavior",
        "reaches a verified final Done gate",
        "If the active runtime rejects a large prompt, fail loudly"
    )) {
        Add-Check $checks "advanced-user-input contains $needle" ($text.Contains($needle)) "$skillPath must contain policy: $needle"
    }

    foreach ($forbidden in @(
        "Do not ask 4+ native options",
        "Do not ask 4+ native questions",
        "Do not pre-collapse to three choices",
        "Prefer the full peer set over a nested Down / Left / Right pre-question",
        "Show all peer options at once when that makes the workflow easier to understand",
        "Forcing all prompts into three options",
        "One call may ask 1-3 questions.",
        "Each question must define 2-3 mutually exclusive options.",
        "Right is shown to the user as stale terminal option",
        "Only stale terminal option can end a continuation loop before that final Done gate",
        "Ask exactly three top-level options: Yes, Revisit, and stale terminal option",
        ("Final clean closeout gates may use exactly three top-level options: Yes, Revisit, and " + "Done"),
        ("If it appears to ask for " + "Stop" + " or " + "Done" + ", ask a fresh confirmation question instead of terminating from Other"),
        ("If a Custom answer appears to ask for " + "Stop" + " or " + "Done" + ", ask a fresh confirmation question instead of terminating from Other"),
        ("Stop" + "/Done"),
        "Custom answers that mean a mid-loop exit are treated as Stop",
        "Custom answers that claim completion before proof exists are treated as Stop",
        "Custom answers are terminal only when they explicitly say Stop",
        "Treat it as terminal only when it explicitly says Stop",
        "Recommend Stop only for explicit mid-loop terminal or blocker states. Recommend Done only at a verified final Done gate."
    )) {
        Add-Check $checks "advanced-user-input omits stale limit $forbidden" (-not $text.Contains($forbidden)) "$skillPath must not contain stale native limit: $forbidden"
    }
}

if ($metadataExists) {
    $metadata = Get-Content -LiteralPath $metadataPath -Raw
    foreach ($needle in @(
        'display_name: "Advanced User Input"',
        'Use $superpowers-project:advanced-user-input',
        'Use the smallest native question shape that preserves the real decision tree',
        'For project workflow closeout gates, always ask the three-way trajectory question first',
        'Use Stop for mid-loop exits',
        'Use Done only for verified final states',
        'Verified final health gates use exactly three top-level options: Done, Revisit, and Stop',
        'Done is invalid whenever git status --short is non-empty',
        'Before any continuation, permission, push, publish, or merge question, complete an artifact review gate',
        'Strict artifact display is mandatory',
        'show what was created or revised',
        'do not merely say something changed',
        'chosen brainstorm design/specs',
        'full plan tasks and steps',
        'created issue bodies or mirrors',
        'exact test values/results',
        'what was done',
        'what was fixed',
        'what remains unsatisfactory or risky',
        "the agent's own feedback/opinion",
        'what the agent thinks those results mean',
        'what that means for the active goal',
        'what that means for the broader project context',
        'what next steps are now recommended',
        'Do not recommend Stop merely because a clean forward route exists',
        'The agent must not get out of the loop by itself',
        'ending a turn after a governed workflow action is invalid',
        'must not recommend Stop before verified final completion',
        'Push, publish, and merge approval questions are invalid until the artifact review gate and findings summary have been shown',
        'loaded thread may still be using older skill text',
        're-ask that gate natively',
        'skipped step as terminal or implicit approval',
        'Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires',
        'Nested Yes-route menus must not include terminal options',
        'Nested Revisit-route menus must not include terminal options',
        'Recommend Yes when at least one safe forward route exists',
        'Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion.',
        'Custom answers never terminate directly from Other',
        'Custom answers that request revision, review, repair, more evidence, a different route, or stronger loop behavior are Revisit behavior',
        'ask a fresh confirmation question with separate built-in labels instead of terminating from Other',
        'Approval gates use domain-specific decline or cancel labels instead of generic terminal labels',
        'request_agent_input'
    )) {
        Add-Check $checks "advanced-user-input metadata contains $needle" ($metadata.Contains($needle)) "$metadataPath must contain policy: $needle"
    }

    foreach ($forbidden in @(
        'Custom answers are terminal only when they explicitly say Stop',
        'Custom answers that claim completion before proof exists are treated as Stop',
        ('Final clean closeout gates may use exactly three top-level options: Yes, Revisit, and ' + 'Done'),
        ('If it appears to ask for ' + 'Stop' + ' or ' + 'Done' + ', ask a fresh confirmation question instead of terminating from Other'),
        ('If a Custom answer appears to ask for ' + 'Stop' + ' or ' + 'Done' + ', ask a fresh confirmation question instead of terminating from Other'),
        ('Stop' + '/Done'),
        'Recommend terminal option only for explicit terminal, blocker, or user-requested stop states',
        'Recommend Stop only for explicit mid-loop terminal or blocker states. Recommend Done only at a verified final Done gate.'
    )) {
        Add-Check $checks "advanced-user-input metadata omits stale terminal rule $forbidden" (-not $metadata.Contains($forbidden)) "$metadataPath must not contain stale terminal rule: $forbidden"
    }
}

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "advanced-user-input-policy"
    checks = $checks
} | ConvertTo-Json -Depth 8

if ($failed.Count -gt 0) { exit 1 }
