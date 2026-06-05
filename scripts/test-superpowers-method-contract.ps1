[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Test-Contract {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$SkillPath,
        [Parameter(Mandatory = $true)][string]$MetadataPath,
        [Parameter(Mandatory = $true)][string[]]$SkillNeedles,
        [Parameter(Mandatory = $true)][string[]]$MetadataNeedles
    )

    try {
        $skill = Get-Content -LiteralPath (Join-Path $repoRoot $SkillPath) -Raw
        $metadata = Get-Content -LiteralPath (Join-Path $repoRoot $MetadataPath) -Raw
        foreach ($needle in $SkillNeedles) {
            Assert-Contains -Text $skill -Needle $needle -Message "$Name skill missing: $needle"
        }
        foreach ($needle in $MetadataNeedles) {
            Assert-Contains -Text $metadata -Needle $needle -Message "$Name metadata missing: $needle"
        }
        Add-Check -Name $Name -Ok $true -Reason "passed"
    } catch {
        Add-Check -Name $Name -Ok $false -Reason $_.Exception.Message
    }
}

Test-Contract `
    -Name "initiate-workflow route-to-method contract" `
    -SkillPath "skills/initiate-workflow/SKILL.md" `
    -MetadataPath "skills/initiate-workflow/agents/openai.yaml" `
    -SkillNeedles @(
        'Routing is not complete until the project skill and its required Superpowers companion skills are both selected.',
        '$superpowers-project:brainstorm-spec',
        'superpowers:brainstorming',
        '$superpowers-project:write-plan',
        'superpowers:writing-plans',
        '$superpowers-project:implement-plan',
        'superpowers:executing-plans',
        '$superpowers-project:create-issues',
        '$superpowers-project:resolve-issue',
        'superpowers:using-git-worktrees',
        '$superpowers-project:orchestrate-issues',
        'superpowers:subagent-driven-development',
        '$superpowers-project:merge-changes',
        'superpowers:finishing-a-development-branch',
        'Do not claim a project route is active if the required Superpowers companion method is omitted.'
    ) `
    -MetadataNeedles @(
        'Routing is not complete until the paired Superpowers companion method is also enforced',
        'brainstorm-spec with superpowers:brainstorming',
        'write-plan with superpowers:writing-plans',
        'implement-plan with superpowers:executing-plans plus required TDD/debug/verification companions',
        'create-issues with downstream resolve/orchestrate method compatibility',
        'resolve-issue with using-git-worktrees plus executing-plans plus TDD/debug/verification plus finishing-a-development-branch',
        'orchestrate-issues with subagent-driven-development plus the worker companion skill set',
        'merge-changes with finishing-a-development-branch plus upstream verification-before-completion proof',
        'Do not treat those pairings as optional guidance.'
    )

Test-Contract `
    -Name "implement-plan companion method contract" `
    -SkillPath "skills/implement-plan/SKILL.md" `
    -MetadataPath "skills/implement-plan/agents/openai.yaml" `
    -SkillNeedles @(
        'Implement Plan is the Superpowers Project adapter for `superpowers:executing-plans` on non-issue approved plans.',
        '## Superpowers Method Contract',
        'Always use `superpowers:executing-plans` as the base implementation workflow.',
        'Require `superpowers:test-driven-development` for feature and bug work unless the approved plan records an explicit opt-out.',
        'Require `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, CI failures, performance work, or unclear failure modes.',
        'Require `superpowers:verification-before-completion` before any success claim, commit, or local merge.',
        'If worker topology is selected, require `superpowers:subagent-driven-development` for delegation and reporting discipline.',
        'Do not treat these companion skills as optional suggestions.'
    ) `
    -MetadataNeedles @(
        'This route is the non-issue adapter for superpowers:executing-plans.',
        'Require superpowers:executing-plans as the base method',
        'require superpowers:test-driven-development for feature and bug work unless the approved plan records an explicit opt-out',
        'require superpowers:systematic-debugging or diagnose for bugs, regressions, CI failures, performance work, or unclear failure modes',
        'require superpowers:verification-before-completion before any success claim, commit, or local merge',
        'require superpowers:subagent-driven-development whenever worker topology is selected',
        'Do not treat those companion skills as optional suggestions.'
    )

Test-Contract `
    -Name "resolve-issue companion method contract" `
    -SkillPath "skills/resolve-issue/SKILL.md" `
    -MetadataPath "skills/resolve-issue/agents/openai.yaml" `
    -SkillNeedles @(
        'This skill is the issue-backed Superpowers Project adapter for `superpowers:executing-plans`.',
        '## Superpowers Method Contract',
        'Always use `superpowers:using-git-worktrees` before implementation work begins.',
        'Always use `superpowers:executing-plans` as the base execution workflow for the linked source plan.',
        'Require `superpowers:test-driven-development` for feature or bug code unless the source plan records an explicit opt-out.',
        'Require `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes.',
        'Require `superpowers:verification-before-completion` before PR-ready claims.',
        'Require `superpowers:finishing-a-development-branch` after verification and before PR creation.',
        'Do not collapse this into generic "Superpowers execution".'
    ) `
    -MetadataNeedles @(
        'This route is the issue-backed adapter for superpowers:executing-plans.',
        'Require superpowers:using-git-worktrees before implementation',
        'require superpowers:executing-plans as the base execution method',
        'require superpowers:test-driven-development unless the source plan records an explicit opt-out',
        'require superpowers:systematic-debugging or diagnose for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes',
        'require superpowers:verification-before-completion before PR-ready claims',
        'require superpowers:finishing-a-development-branch after verification and before PR creation',
        'Do not collapse this into generic Superpowers execution or treat the companion skills as optional.'
    )

Test-Contract `
    -Name "orchestrate-issues companion method contract" `
    -SkillPath "skills/orchestrate-issues/SKILL.md" `
    -MetadataPath "skills/orchestrate-issues/agents/openai.yaml" `
    -SkillNeedles @(
        'This skill is the delegated Superpowers Project adapter for `superpowers:subagent-driven-development`.',
        '## Superpowers Method Contract',
        'The orchestrator must use that delegation discipline, and the worker handoff must require this companion skill set:',
        '`superpowers:using-git-worktrees`',
        '`superpowers:test-driven-development`',
        '`superpowers:executing-plans` or `superpowers:subagent-driven-development`',
        '`superpowers:verification-before-completion`',
        '`superpowers:finishing-a-development-branch`',
        'Do not create or launch a worker without this companion skill set in the handoff.'
    ) `
    -MetadataNeedles @(
        'This route is the delegated adapter for superpowers:subagent-driven-development.',
        'The orchestrator must use that delegation discipline',
        'every worker handoff must require superpowers:using-git-worktrees',
        'superpowers:test-driven-development',
        'superpowers:executing-plans or superpowers:subagent-driven-development',
        'superpowers:verification-before-completion',
        'superpowers:finishing-a-development-branch',
        'Do not create or launch a worker without that companion skill set in the handoff.'
    )

Test-Contract `
    -Name "merge-changes companion method contract" `
    -SkillPath "skills/merge-changes/SKILL.md" `
    -MetadataPath "skills/merge-changes/agents/openai.yaml" `
    -SkillNeedles @(
        '## Superpowers Method Contract',
        'This skill is the closeout Superpowers Project adapter for `superpowers:finishing-a-development-branch`.',
        'Merge-changes requires upstream `superpowers:verification-before-completion` proof and does not replace it.'
    ) `
    -MetadataNeedles @(
        'This route is the closeout adapter for superpowers:finishing-a-development-branch.',
        'Require upstream superpowers:verification-before-completion proof',
        'do not treat merge-time judgment as a substitute for missing execution-time verification or branch-finish discipline'
    )

Test-Contract `
    -Name "create-issues downstream method compatibility contract" `
    -SkillPath "skills/create-issues/SKILL.md" `
    -MetadataPath "skills/create-issues/agents/openai.yaml" `
    -SkillNeedles @(
        '$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues` to execute one issue at a time with their mandatory Superpowers companion skills.',
        'Issue metadata must keep downstream routing compatible with the mandatory Superpowers companion skills used by those execution routes.'
    ) `
    -MetadataNeedles @(
        'keep downstream routing compatible with the mandatory Superpowers companion skills enforced by $superpowers-project:resolve-issue and $superpowers-project:orchestrate-issues'
    )

$failed = @($results | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "superpowers-method-contract"
    checks = $results
} | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
