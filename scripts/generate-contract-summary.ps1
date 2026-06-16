[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutputPath = (Join-Path (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path "docs\superpowers\CONTRACT_SUMMARY.md")
)

$ErrorActionPreference = "Stop"
. (Join-Path $RepoRoot "scripts\lib\project-skills.ps1")

function Get-FrontmatterValue {
    param([string]$Text, [string]$Name)
    $match = [regex]::Match($Text, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    ""
}

function Get-QuestionIds {
    param([string]$Text)
    @([regex]::Matches($Text, 'Question id:\s*`([^`]+)`') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}

function Get-FirstLine {
    param([string]$Text)
    $line = ($Text -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
    if ($null -eq $line) { return "" }
    $line.Trim()
}

$workflowSkills = @(Get-ProjectWorkflowSkillNames -RepoRoot $RepoRoot)
$finalCapable = @(Get-ProjectFinalCapableSkillNames)
$canonicalNamespace = Get-ProjectCanonicalPromptNamespace
$lines = [System.Collections.Generic.List[string]]::new()

foreach ($line in @(
    '# Superpowers Project Contract Summary',
    '',
    '> Generated from repo source by `scripts/generate-contract-summary.ps1`. Do not edit by hand.',
    '',
    '## Canonical Identity',
    '',
    '- Plugin manifest name: `superpowers-project`',
    ("- User-facing prompt namespace: ``" + $canonicalNamespace + ":*``"),
    '- Source repo: `tannerpolley/superpowers-project`',
    '',
    '## Artifact Roots',
    '',
    '- Specs: `docs/superpowers/specs/`',
    '- Plans: `docs/superpowers/plans/`',
    '- Issue mirrors: `docs/superpowers/issues/`',
    '- Milestone index pages: `docs/superpowers/milestones/`',
    '',
    '## Plan Task Use Cases',
    '',
    '- `Task # Use Cases` is a strict requirement for plan making, plan implementation, and issue resolution.',
    '- Every numbered `Task N` in an implementation plan must include a non-empty `**Use Cases:**` block before files and steps.',
    '- `scripts/validate-plan-task-use-cases.ps1 -PlanPath <plan>` is mandatory before a plan is ready, before `$superpowers-project:implement-plan` edits code, and before `$superpowers-project:resolve-issue` executes a linked source plan.',
    '',
    '## Terminal Model',
    '',
    '- Intermediate workflow gates use `Yes`, `Revisit`, and `Stop`.',
    '- Verified final health gates use `Done`, `Revisit`, and `Stop`.',
    '- `Done` is valid only after final proof and a clean worktree.',
    '- Custom Other never terminates directly; re-ask with built-in terminal labels when needed.',
    '- A saved spec, saved plan, created issue set, pushed branch, merged branch, completed audit, or synced live plugin is not terminal by itself.',
    '',
    '## Workflow Modes',
    '',
    '- `project_workflow_mode` is mandatory in `$superpowers-project:initiate-workflow` before task routing.',
    '- `Manual Mode` asks at each material route, mutation, and closeout decision.',
    '- `Auto Mode` is one-route autonomy only; it must stop at route closeout and must not continue to another candidate.',
    '- `Looping Mode` is bounded repeated maintenance autonomy; it routes through `$superpowers-project:loop-controller` to select one ready candidate at a time, route the actual work to the owning skill, and re-check budget before another candidate.',
    '- Workflow mode ledgers record `selected_mode`, repo identity, plugin manifest version, `contract_hash`, autonomy scope, mutation scope, route policy, proof policy, stop conditions, and downstream ledger paths.',
    '- Validate workflow mode ledgers with `scripts/validate-workflow-mode-ledger.ps1 -RepoRoot <active repo> -ModeLedgerPath <ledger>`.',
    '',
    '## Workflow Skills',
    '',
    '| Skill | Purpose | Native Question IDs | Final Health Gate |',
    '|---|---|---|---|'
)) {
    [void]$lines.Add($line)
}

foreach ($skillName in $workflowSkills) {
    $skillPath = Join-Path $RepoRoot "skills\$skillName\SKILL.md"
    $text = Get-Content -LiteralPath $skillPath -Raw
    $description = Get-FrontmatterValue -Text $text -Name "description"
    if ([string]::IsNullOrWhiteSpace($description)) { $description = Get-FirstLine -Text $text }
    $questionIds = @(Get-QuestionIds -Text $text)
    $finalGate = if ($finalCapable -contains $skillName) {
        @($questionIds | Where-Object { $_ -like "*_final_health_gate" }) -join ", "
    } else {
        ""
    }
    if ([string]::IsNullOrWhiteSpace($finalGate)) { $finalGate = "None" }
    $questionText = if ($questionIds.Count -gt 0) { ($questionIds | ForEach-Object { "``$_``" }) -join "<br>" } else { "None" }
    [void]$lines.Add("| ``$skillName`` | $description | $questionText | ``$finalGate`` |")
}

foreach ($line in @(
    '',
    '## Approval Boundaries',
    '',
    '- Push, publish, merge, board creation, GitHub mutation, and final `Done` require explicit proof and the owning native gate.',
    '- `project_merge_approval` is the merge approval gate.',
    '- `project_auto_mode_authorization` can authorize bounded Auto Mode only when the plugin-provided Auto Mode validator passes.',
    '- Validate Auto Mode ledgers with `scripts/validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>` from the loaded Superpowers Project plugin surface.',
    '- Helper scripts may prepare evidence, but they must not convert missing approval into approval.',
    '',
    '## Debug Mode',
    '',
    '- `debug_question_mode` is only for explicit non-interactive smoke tests or proven stuck background prompts.',
    '- Required ledger fields include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source`, `no_answer_tool_available: true`, and `mutation_allowed: false`.',
    '- Debug mode must not approve mutation.',
    '',
    '## Live Sync',
    '',
    '- Source repo is authoritative.',
    '- Live deployed plugin copy is checked by `scripts/sync-live.ps1 -Validate`.',
    '- Plugin cache paths are not durable contracts.',
    '- Validated live sync refreshes matching local plugin cache roots when they already exist, so existing threads can see updated files when they re-read plugin skill bodies.',
    '- Already-loaded prompt text cannot be rewritten inside an existing agent context; a stale observed root after sync still requires a fresh agent session.',
    '',
    '## Startup Version Check',
    '',
    '- At Superpowers Project startup, agents must run `scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent` and print the banner before selecting a project workflow route.',
    '- If the active agent knows its loaded plugin or skill root, it must also pass `-ObservedPluginRoot` or `-ObservedSkillRoot`.',
    '- The banner reports the manifest version, source commit, source dirty state, `contract_hash`, source/live freshness, observed-root freshness, and stale cache candidate count.',
    '',
    '## Agent Version Tracking',
    '',
    '- Exact runtime identity is the plugin manifest version plus the runtime `contract_hash`.',
    '- `scripts/get-agent-plugin-version.ps1 -RequireCurrent` compares source, live install, optional observed plugin or skill root, and local cache candidates.',
    '- Use `-ObservedPluginRoot` or `-ObservedSkillRoot` when an agent needs to prove the exact loaded copy it is using.',
    '- If source and live are current but the observed surface differs, run validated live sync to refresh live install and matching local plugin cache roots, then start a fresh agent session if the observed surface still differs.',
    '',
    '## Validation Commands',
    '',
    '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`',
    '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`',
    '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1`',
    '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -RequireCurrent`',
    '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\detect-stale-skill-contract.ps1 -SkillName brainstorm-spec -ExpectedQuestionId project_brainstorm_start_route`'
)) {
    [void]$lines.Add($line)
}

$output = $lines -join [Environment]::NewLine
$targetPath = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $RepoRoot $OutputPath }
$targetDir = Split-Path -Parent $targetPath
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Set-Content -LiteralPath $targetPath -Value $output -Encoding utf8NoBOM

[pscustomobject]@{
    ok = $true
    phase = "generate-contract-summary"
    output_path = [IO.Path]::GetFullPath($targetPath)
    workflow_skill_count = $workflowSkills.Count
} | ConvertTo-Json -Depth 8
