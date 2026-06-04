# Project Merge Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `$project:merge-changes` and narrow `$project:resolve-issue` so issue implementation ends at PR-ready handoff and merge, issue closure, cleanup, and clean-state proof happen in a separate skill.

**Architecture:** Keep `$project:resolve-issue` as the goal-backed implementation owner for one issue mirror and source plan. Add `$project:merge-changes` as the main-orchestrator integration owner that starts from a PR URL or worker handoff, asks native UI merge approval after premerge proof, then merges and cleans up. Preserve the current PowerShell gate style, but move merge-specific gates into `skills/merge-changes`.

**Tech Stack:** Codex skills in Markdown, skill metadata in YAML, PowerShell gate scripts and scenario tests, JSON ledgers, Git/GitHub evidence through `gh` or fixtures, native `request_user_input`, native goal tools, and Superpowers execution skills.

---

## Source And Decisions

**Source spec:** `docs/superpowers/specs/2026-06-02-merge-changes-skill-design.md`

**Planning approval:** User asked to use `$project:write-plan` to turn the approved `$project:merge-changes` spec into this plan.

**Native UI planning decisions:**

- Merge gate: `$project:merge-changes` asks through native `request_user_input` before merging. The two options are `Merge` and `Decline`.
- Fixture support: support both real GitHub PR workflows and local dummy fixtures.
- Issue mirror shape: add a dedicated `## Project Merge` section instead of expanding only the existing workflow metadata block.

## Acceptance Criteria

- [ ] `scripts/validate.ps1` treats `merge-changes` as an active skill.
- [ ] `skills/merge-changes` exists with `SKILL.md`, `agents/openai.yaml`, and scenario tests.
- [ ] `$project:merge-changes` owns `premerge.ps1`, `closeout.ps1`, native merge approval validation, branch/worktree cleanup, prune evidence, and final clean repo proof.
- [ ] `$project:resolve-issue` no longer claims to merge PRs, close issues, or run final cleanup.
- [ ] `$project:resolve-issue` completes its native goal at PR-ready evidence.
- [ ] Worker-mode `$project:resolve-issue` records a lightweight Dynamic Work Packet Map in the setup ledger or worker handoff.
- [ ] Full `$codex-dynamic-workflows` artifacts are optional and only used when the issue meets the heavier orchestration decision rule or the user explicitly requests them.
- [ ] Issue mirrors include a `## Project Merge` section with merge owner, merge gate, merge policy, cleanup policy, and wakeup policy.
- [ ] `$project:merge-changes` asks for native UI merge approval after clean premerge proof and before any merge command.
- [ ] Major Superpowers Project handoffs use native continuation questions and immediately start the selected next skill when feasible.
- [ ] Full repo validation and live sync validation pass.

## File Map

Create:

- `skills/merge-changes/SKILL.md`: project integration skill instructions.
- `skills/merge-changes/agents/openai.yaml`: skill metadata prompt.
- `skills/merge-changes/scripts/lib/contract.ps1`: merge-skill JSON, path, GitHub URL, branch cleanup, and decision helpers.
- `skills/merge-changes/scripts/premerge.ps1`: PR-to-issue and verification coverage gate.
- `skills/merge-changes/scripts/validate-merge-decision.ps1`: native merge approval ledger gate.
- `skills/merge-changes/scripts/closeout.ps1`: merged PR, issue close, branch/worktree cleanup, prune, cleanup hook, and clean repo proof gate.
- `skills/merge-changes/scripts/test-scenarios.ps1`: local fixtures for the new skill.

Modify:

- `skills/resolve-issue/SKILL.md`: end at PR-ready handoff and route to `$project:merge-changes`.
- `skills/resolve-issue/agents/openai.yaml`: remove merge/issue-close/cleanup ownership from the prompt.
- `skills/resolve-issue/scripts/lib/contract.ps1`: add Dynamic Work Packet Map and PR-ready handoff helpers.
- `skills/resolve-issue/scripts/prepare-execution.ps1`: include packet map in worker setup ledger and worker handoff.
- `skills/resolve-issue/scripts/validate-setup.ps1`: require packet map for orchestrated worker mode.
- `skills/resolve-issue/scripts/test-scenarios.ps1`: replace merge closeout scenarios with PR-ready scenarios.
- `skills/create-issues/SKILL.md`: document the `## Project Merge` section.
- `skills/create-issues/agents/openai.yaml`: include merge section fields in issue creation guidance.
- `skills/create-issues/scripts/validate-issue-mirror.ps1`: validate merge section fields.
- `skills/create-issues/scripts/test-scenarios.ps1`: test happy issue mirrors with `## Project Merge`.
- `skills/write-plan/SKILL.md`: replace vanilla execution-only handoff with native continuation routing.
- `skills/write-plan/agents/openai.yaml`: include the continuation gate in project planning guidance.
- `skills/write-plan/scripts/test-scenarios.ps1`: test continuation-gate text.
- `docs/superpowers/issues/README.md`: document the merge section template.
- `docs/superpowers/issues/smoke-test-workflow.md`: add the merge section.
- `skills/initiate-workflow/SKILL.md`: route PR/handoff integration to `$project:merge-changes`.
- `skills/initiate-workflow/agents/openai.yaml`: include `$project:merge-changes`.
- `skills/initiate-workflow/scripts/test-scenarios.ps1`: require router text for `$project:merge-changes`.
- `docs/superpowers/PROJECT_CONTEXT.md`: list `merge-changes` in extension skills and execution model.
- `README.md`: list `$project:merge-changes`.
- `.codex-plugin/plugin.json`: add a default prompt for merge integration.
- `scripts/validate.ps1`: add `merge-changes` to active skill names.
- `scripts/test-superpowers-project-dummy-repo.ps1`: seed merge metadata and test PR-ready setup.
- `scripts/test-superpowers-project-repo-contract.ps1`: require `merge-changes` and merge metadata.

Delete after successful move:

- `skills/resolve-issue/scripts/premerge.ps1`
- `skills/resolve-issue/scripts/closeout.ps1`

Test:

- `skills/resolve-issue/scripts/test-scenarios.ps1`
- `skills/merge-changes/scripts/test-scenarios.ps1`
- `skills/create-issues/scripts/test-scenarios.ps1`
- `skills/initiate-workflow/scripts/test-scenarios.ps1`
- `scripts/test-superpowers-project-dummy-repo.ps1`
- `scripts/test-superpowers-project-repo-contract.ps1`
- `scripts/validate.ps1`
- `scripts/sync-live.ps1 -Validate`

## Non-Goals

- Do not make `$project:merge-changes` implement issue changes except for small review-requested fixes explicitly handled during integration.
- Do not let worker threads merge their own PRs by default.
- Do not add GoalBuddy boards or `docs/goals`.
- Do not create `.workflow/<slug>` folders for ordinary issue resolution.
- Do not require a native `/goal` for `$project:merge-changes` unless the user explicitly asks for a goal-backed integration run.

## Native Continuation Contract

Every major Superpowers Project handoff should treat the next-step native UI answer as executable routing:

- Ask with `request_user_input` when callable.
- Carry forward the source artifact path, decisions, and proof summary.
- Start the selected next skill in the same turn when tools and state allow it.
- Stop only when the selected route needs unavailable tools, external-write approval, or user-provided data that the current thread does not have.

Default continuation gates:

- `$project:brainstorm-spec`: continue to `$project:write-plan`, `$project:create-issues` for direct issue creation, or stop.
- `$project:write-plan`: continue to `$project:create-issues`, `superpowers:subagent-driven-development`, or `superpowers:executing-plans`.
- `$project:create-issues`: resolve the first ready issue, resolve a selected issue, or stop after issue creation.
- `$project:resolve-issue`: start `$project:merge-changes`, resolve another ready issue, or stop at PR-ready.
- `$project:merge-changes`: resolve the next ready issue, run `$project:audit-project`, or stop.

## Proof Oracle

Run these from the repository root:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

## Task 1: Add Failing Active-Skill And Router Expectations

**Files:**

- Modify: `scripts/validate.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Test: `scripts/validate.ps1`

- [ ] **Step 1: Add `merge-changes` to active skill validation**

In `scripts/validate.ps1`, replace `Get-ActiveSkillNames` with:

```powershell
function Get-ActiveSkillNames {
    @(
        "superpowers-project",
        "project-context",
        "brainstorm-spec",
        "write-plan",
        "create-issues",
        "resolve-issue",
        "merge-changes",
        "audit-project"
    )
}
```

- [ ] **Step 2: Add `merge-changes` to repo contract skill checks**

In `scripts/test-superpowers-project-repo-contract.ps1`, add `"merge-changes"` to every active skill array that currently contains `"resolve-issue"` and `"audit-project"`.

The active skill array should read:

```powershell
foreach ($skillName in @(
    "superpowers-project",
    "project-context",
    "brainstorm-spec",
    "write-plan",
    "create-issues",
    "resolve-issue",
    "merge-changes",
    "audit-project"
)) {
```

- [ ] **Step 3: Add `merge-changes` to router scenario tests**

In `skills/initiate-workflow/scripts/test-scenarios.ps1`, extend the router needle list so it includes `merge-changes`:

```powershell
foreach ($needle in @(
    'project-context',
    'brainstorm-spec',
    'write-plan',
    'create-issues',
    'resolve-issue',
    'merge-changes',
    'audit-project',
    'superpowers:brainstorming',
    'superpowers:writing-plans',
    'superpowers:executing-plans',
    'request_user_input',
    'docs/superpowers',
    '/goal'
)) {
```

- [ ] **Step 4: Run validation and verify the expected red state**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: FAIL because `skills/merge-changes/SKILL.md` does not exist yet. The failure should mention `merge-changes` or a missing active skill file.

Do not commit this red state.

## Task 2: Create The `$project:merge-changes` Skill Shell

**Files:**

- Create: `skills/merge-changes/SKILL.md`
- Create: `skills/merge-changes/agents/openai.yaml`
- Create: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `scripts/validate.ps1`

- [ ] **Step 1: Create the skill directory**

Run:

```powershell
New-Item -ItemType Directory -Path .\skills\merge-changes\agents -Force | Out-Null
New-Item -ItemType Directory -Path .\skills\merge-changes\scripts\lib -Force | Out-Null
```

- [ ] **Step 2: Write the first `$project:merge-changes` scenario tests**

Create `skills/merge-changes/scripts/test-scenarios.ps1` with:

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptRoot
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Name, [bool]$Ok, [string]$Reason) $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason }) }
function Invoke-Scenario { param([string]$Name, [scriptblock]$Body) try { & $Body; Add-Result -Name $Name -Ok $true -Reason "passed" } catch { Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message } }
function Assert-Contains { param([string]$Text, [string]$Needle, [string]$Message) if (-not $Text.Contains($Needle)) { throw $Message } }

Invoke-Scenario "skill frontmatter is valid" {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    $text = Get-Content -LiteralPath $skillFile -Raw
    Assert-Contains $text "name: merge-changes" "missing skill name"
    Assert-Contains $text "description: Use when" "description must start with Use when"
    Assert-Contains $text "# Project Merge" "missing skill title"
}

Invoke-Scenario "merge contract text is present" {
    $text = Get-Content -LiteralPath $skillFile -Raw
    foreach ($needle in @(
        "PR URL or worker handoff",
        "main orchestrator",
        "request_user_input",
        "project_merge_approval",
        "Merge",
        "Decline",
        "premerge.ps1",
        "closeout.ps1",
        "git fetch --prune",
        "cleanup hook",
        "Do not merge without native UI approval"
    )) {
        Assert-Contains $text $needle "missing merge-changes contract: $needle"
    }
}

Invoke-Scenario "metadata is present" {
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $metadata = Get-Content -LiteralPath $metadataFile -Raw
    Assert-Contains $metadata "merge-changes:" "missing metadata key"
    Assert-Contains $metadata "PR URL or worker handoff" "missing PR intake"
    Assert-Contains $metadata "request_user_input" "missing native UI merge gate"
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
```

- [ ] **Step 3: Run the new scenario tests and verify red state**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
```

Expected: FAIL with `missing SKILL.md`.

- [ ] **Step 4: Create `skills/merge-changes/SKILL.md`**

Create `skills/merge-changes/SKILL.md` with:

```markdown
---
name: merge-changes
description: Use when a Superpowers Project PR URL or worker handoff must be reviewed, approved, merged, linked issue closure verified, worktree and branch cleanup completed, and clean repo proof recorded.
---

# Project Merge

This skill owns integration after `$project:resolve-issue` creates PR-ready evidence. It starts from a PR URL or worker handoff, verifies the issue mirror and source plan, runs premerge checks, asks native UI merge approval, merges only after approval, verifies linked issue closure, cleans up the owned branch and worktree, runs `git fetch --prune`, runs the cleanup hook, and records final clean repo proof.

`$project:merge-changes` is normally run by the main orchestrator thread. Workers do not merge their own PR by default.

## Hard Failures

Stop immediately when any of these are true:

- No PR URL or worker handoff is named.
- No linked issue mirror under `docs/superpowers/issues` can be identified.
- No linked source plan under `docs/superpowers/plans` can be identified.
- PR evidence does not close the exact linked GitHub issue.
- Required checks fail, are pending, or are missing while policy requires existing checks.
- PR changed files are not covered by verification receipts tied to the source plan.
- Premerge proof has not passed.
- Native UI merge approval is missing, malformed, or declined.
- Branch cleanup attempts to delete anything other than the owned implementation branch.
- Worktree cleanup targets a path outside the owned worktree.
- Cleanup hook proof is missing or failed.
- Final repo state is dirty.

## State Machine

Follow this order exactly:

1. `merge intake`: read the PR URL or worker handoff.
2. `source linkage`: read the issue mirror, source plan, setup ledger, PR-ready handoff ledger, and verification ledger.
3. `premerge`: run `scripts/premerge.ps1` with real GitHub evidence or local fixtures.
4. `merge approval`: explain the clean premerge evidence, then ask native UI question `project_merge_approval`.
5. `merge`: merge the PR only when the user selects `Merge`.
6. `issue closure`: verify the exact linked GitHub issue is closed.
7. `default sync`: sync the default branch.
8. `branch cleanup`: delete only the owned implementation branch locally and remotely.
9. `worktree cleanup`: remove only the owned worktree when one exists.
10. `prune`: run `git fetch --prune`.
11. `cleanup hook`: run the repo cleanup hook.
12. `clean state`: verify clean repo state and record closeout proof through `scripts/closeout.ps1`.

## Native Merge Approval

After premerge proof passes and before any merge command, ask with `request_user_input` when callable.

Question id: `project_merge_approval`

Prompt shape:

```text
Premerge proof is clean for <PR URL>. Merge this PR now?
```

Options:

- `Merge`: merge the PR and continue issue closure plus cleanup.
- `Decline`: stop without merging and report the exact pending state.

Use `Merge` as the recommended option only after premerge proof is clean. Do not merge without native UI approval.

For explicit non-interactive smoke tests, use `debug_question_mode` only when the prompt authorizes debug defaults. Record the same structured decision ledger.

## Scripted Gates

Run bundled scripts with explicit `-RepoRoot`:

- `scripts/premerge.ps1`: validates PR closing reference, checks, issue acceptance state, changed-file coverage, and proof commands.
- `scripts/validate-merge-decision.ps1`: validates the native merge approval ledger and blocks declined decisions.
- `scripts/closeout.ps1`: validates merged PR proof, linked issue closure proof, branch cleanup, worktree cleanup, prune proof, cleanup hook proof, and clean repo proof.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Completion Rule

Do not send a success-style final response until closeout proof shows:

- PR merged.
- Exact linked issue closed.
- Default branch synced.
- Only the owned implementation branch deleted.
- Owned worktree removed or proven absent.
- `git fetch --prune` passed.
- Repo cleanup hook passed.
- Repo state is clean.
```

- [ ] **Step 5: Create metadata**

Create `skills/merge-changes/agents/openai.yaml` with:

```yaml
version: 1
skills:
  merge-changes:
    default_prompt: "Use $project:merge-changes when a Superpowers Project PR URL or worker handoff is ready for main-thread integration. Read the linked issue mirror, source plan, setup ledger, PR-ready handoff, and verification ledger; run premerge proof; ask native request_user_input question project_merge_approval with Merge and Decline options before merging; merge only after approval; verify the linked issue closed; sync default; delete only the owned branch; remove the owned worktree; run git fetch --prune and the repo cleanup hook; then record clean closeout proof."
```

- [ ] **Step 6: Run the new skill tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
```

Expected: PASS.

- [ ] **Step 7: Run full validation and verify the remaining red state**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: FAIL until project context, router text, and active repo contract files mention `merge-changes`. Keep going to the routing and docs tasks before committing.

## Task 3: Port Merge Gates Into `$project:merge-changes`

**Files:**

- Create: `skills/merge-changes/scripts/lib/contract.ps1`
- Create: `skills/merge-changes/scripts/premerge.ps1`
- Create: `skills/merge-changes/scripts/validate-merge-decision.ps1`
- Create: `skills/merge-changes/scripts/closeout.ps1`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`

- [ ] **Step 1: Copy the existing contract helpers**

Run:

```powershell
Copy-Item -LiteralPath .\skills\resolve-issue\scripts\lib\contract.ps1 -Destination .\skills\merge-changes\scripts\lib\contract.ps1 -Force
```

- [ ] **Step 2: Add merge-decision helpers to the copied contract**

Append to `skills/merge-changes/scripts/lib/contract.ps1`:

```powershell
function Assert-MergeDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "merge decision is required" }
    if ($Decision -is [string]) { throw "merge decision must be structured, not a string" }
    foreach ($field in @("question_id", "source", "selected_action", "recommended_action", "options")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "merge decision missing $field" }
    }
    if ([string]$Decision.question_id -ne "project_merge_approval") { throw "merge decision question_id mismatch" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "merge decision source must be request_user_input or debug_question_mode" }
    if ([string]$Decision.selected_action -notin @("merge", "decline")) { throw "merge decision selected_action must be merge or decline" }
    if ([string]$Decision.recommended_action -ne "merge") { throw "merge decision recommended_action must be merge after clean premerge proof" }
    $options = Get-StringArray $Decision.options
    foreach ($requiredOption in @("merge", "decline")) {
        if ($options -notcontains $requiredOption) { throw "merge decision options must include $requiredOption" }
    }
    if ([string]$Decision.selected_action -eq "decline") { throw "merge declined by user" }
}

function Assert-CleanRepoProof {
    param($Proof)
    if ($null -eq $Proof -or $Proof -is [string]) { throw "clean repo proof must be structured" }
    foreach ($field in @("source", "exit_code", "status_output")) {
        if (-not (Test-Property -Object $Proof -Name $field)) { throw "clean repo proof missing $field" }
    }
    if ([int]$Proof.exit_code -ne 0) { throw "clean repo proof command must pass" }
    if (-not [string]::IsNullOrWhiteSpace([string]$Proof.status_output)) { throw "repo status must be clean" }
}
```

- [ ] **Step 3: Create `premerge.ps1` with JSON and fixture inputs**

Copy `skills/resolve-issue/scripts/premerge.ps1` to `skills/merge-changes/scripts/premerge.ps1`, then update the parameter block so it accepts real JSON or fixture paths:

```powershell
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$VerificationLedgerJson,
    [string]$VerificationLedgerPath,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string]$IssueJson,
    [string]$IssueFixturePath
)
```

In the body, replace PR and issue reads with:

```powershell
$pr = Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
$issue = Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
```

Keep the existing checks for exact closing reference, required checks, acceptance criteria coverage, changed-file coverage, and proof commands.

- [ ] **Step 4: Create `validate-merge-decision.ps1`**

Create `skills/merge-changes/scripts/validate-merge-decision.ps1` with:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$PremergeResultJson,
    [string]$PremergeResultPath,
    [string]$MergeDecisionJson,
    [string]$MergeDecisionPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "merge-decision"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $premerge = Read-JsonInput -Json $PremergeResultJson -Path $PremergeResultPath -Name "premerge result"
    if ($premerge.ok -ne $true) { throw "premerge proof must pass before merge approval" }
    $decision = Read-JsonInput -Json $MergeDecisionJson -Path $MergeDecisionPath -Name "merge decision"
    Assert-MergeDecision -Decision $decision
    Complete-Contract -Phase $phase -Reason "merge approved" -Evidence @{ selected_action = [string]$decision.selected_action; question_id = [string]$decision.question_id }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
```

- [ ] **Step 5: Create `closeout.ps1` for merge closeout**

Copy `skills/resolve-issue/scripts/closeout.ps1` to `skills/merge-changes/scripts/closeout.ps1`, then change its parameter block to:

```powershell
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$CompletionLedgerJson,
    [string]$CompletionLedgerPath,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string]$IssueJson,
    [string]$IssueFixturePath
)
```

Replace fixture reads with:

```powershell
$pr = Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
$issue = Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
```

Require these structured completion fields:

```powershell
foreach ($field in @(
    "merge_decision",
    "merge_confirmation",
    "linked_issue_closed_confirmation",
    "default_branch_sync",
    "branch_cleanup_confirmation",
    "worktree_cleanup_confirmation",
    "fetch_prune_result",
    "cleanup_hook_result",
    "clean_repo_proof",
    "resolve_goal_completion_proof"
)) {
    if (-not (Test-Property -Object $completion -Name $field) -or $completion.$field -is [string]) { throw "completion ledger $field must be structured" }
}
Assert-MergeDecision -Decision $completion.merge_decision
Assert-CleanRepoProof -Proof $completion.clean_repo_proof
```

Remove the old requirement that `$project:merge-changes` must call `update_goal` by default. Instead, require `resolve_goal_completion_proof.status` to be `complete`:

```powershell
$resolveGoal = $completion.resolve_goal_completion_proof
if ($resolveGoal -is [string]) { throw "resolve goal completion proof must be structured" }
if ([string]$resolveGoal.status -ne "complete") { throw "resolve goal completion proof must mark status complete" }
```

Keep the existing branch cleanup rule that only the setup branch may be deleted.

- [ ] **Step 6: Add merge script scenarios**

Extend `skills/merge-changes/scripts/test-scenarios.ps1` with helpers equivalent to the resolver tests:

```powershell
function Invoke-JsonScript {
    param([string]$ScriptName, [string[]]$Arguments)
    $scriptPath = Join-Path $scriptRoot $ScriptName
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
    $raw = ($output | Out-String).Trim()
    try {
        if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty output" }
        return ($raw | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{ ok = $false; phase = $ScriptName; reason = $raw }
    }
}

function New-SetupLedger {
    @{
        issue_url = "https://github.com/example/repo/issues/12"
        issue_mirror = "docs/superpowers/issues/12-sample.md"
        source_plan = "docs/superpowers/plans/2026-06-02-sample-plan.md"
        branch = "codex/sample-issue"
        goal_id = "thread-goal"
        goal_objective = "Implement issue to PR-ready evidence."
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-VerificationLedger {
    @{
        required_checks_policy = "require-existing"
        acceptance_criteria_closeout_proof = $true
        changed_files_covered = @("src/example.txt", "docs/superpowers/issues/12-sample.md")
        verification_exemptions = @()
        proof_commands = @("pwsh -NoProfile -Command 'exit 0'")
    } | ConvertTo-Json -Depth 12 -Compress
}

function New-MergeDecision {
    param([string]$SelectedAction = "merge")
    @{
        question_id = "project_merge_approval"
        source = "request_user_input"
        selected_action = $SelectedAction
        recommended_action = "merge"
        options = @("merge", "decline")
    } | ConvertTo-Json -Depth 8 -Compress
}
```

Add scenarios:

```powershell
Invoke-Scenario "premerge accepts happy fixture" {
    $pr = @{
        url = "https://github.com/example/repo/pull/5"
        state = "OPEN"
        body = "Closes #12"
        closingIssuesReferences = @(@{ number = 12 })
        requiredChecks = @(@{ name = "local-proof"; state = "SUCCESS"; conclusion = "SUCCESS" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/superpowers/issues/12-sample.md" })
    } | ConvertTo-Json -Depth 12 -Compress
    $issue = @{ state = "OPEN"; body = "- [x] Sample issue is resolved" } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "premerge.ps1" -Arguments @("-SetupLedgerJson", (New-SetupLedger), "-VerificationLedgerJson", (New-VerificationLedger), "-PrJson", $pr, "-IssueJson", $issue)
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario "merge approval blocks declined decision" {
    $premerge = @{ ok = $true; phase = "premerge"; reason = "passed"; evidence = @{} } | ConvertTo-Json -Depth 8 -Compress
    $result = Invoke-JsonScript -ScriptName "validate-merge-decision.ps1" -Arguments @("-PremergeResultJson", $premerge, "-MergeDecisionJson", (New-MergeDecision -SelectedAction "decline"))
    if ($result.ok -or $result.reason -notmatch "declined") { throw "expected declined merge decision to block" }
}
```

Add a happy closeout scenario that includes:

```powershell
$completion = @{
    pr_url = "https://github.com/example/repo/pull/5"
    issue_url = "https://github.com/example/repo/issues/12"
    merge_decision = (New-MergeDecision | ConvertFrom-Json)
    merge_confirmation = @{ source = "gh pr view"; state = "MERGED" }
    linked_issue_closed_confirmation = @{ source = "gh issue view"; state = "CLOSED" }
    default_branch_sync = @{ command = "git pull --ff-only origin main"; exit_code = 0 }
    branch_cleanup_confirmation = @{ deleted_local = $true; deleted_remote = $true; only_goal_owned_removed = $true; local_delete_target = "codex/sample-issue"; remote_delete_target = "codex/sample-issue"; remote_deleted_branches = @("codex/sample-issue") }
    worktree_cleanup_confirmation = @{ owned_worktree_removed = $true; worktree_path = "C:/tmp/sample-worktree" }
    fetch_prune_result = @{ command = "git fetch --prune"; exit_code = 0 }
    cleanup_hook_result = @{ command = "codex-cleanup"; exit_code = 0; output = "clean" }
    clean_repo_proof = @{ source = "git status --short"; exit_code = 0; status_output = "" }
    resolve_goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
} | ConvertTo-Json -Depth 16 -Compress
```

- [ ] **Step 7: Run merge scenario tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
```

Expected: PASS.

## Task 4: Narrow `$project:resolve-issue` To PR-Ready Handoff

**Files:**

- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/lib/contract.ps1`
- Modify: `skills/resolve-issue/scripts/prepare-execution.ps1`
- Modify: `skills/resolve-issue/scripts/validate-setup.ps1`
- Create: `skills/resolve-issue/scripts/validate-pr-ready.ps1`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Delete: `skills/resolve-issue/scripts/premerge.ps1`
- Delete: `skills/resolve-issue/scripts/closeout.ps1`
- Test: `skills/resolve-issue/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing resolver scenarios for packet map and PR-ready close**

In `skills/resolve-issue/scripts/test-scenarios.ps1`, replace the `"happy closeout marks goal complete after merge and issue close"` scenario with `"happy PR-ready handoff marks resolve goal complete"`.

Use this PR-ready ledger in the new scenario:

```powershell
$prReady = @{
    pr_url = "https://github.com/example/repo/pull/5"
    issue_url = "https://github.com/example/repo/issues/12"
    branch = "codex/sample-issue"
    branch_pushed = $true
    pr_closes_issue = $true
    acceptance_criteria_covered = $true
    verification_passed = $true
    handoff_sent = @{ source = "worker-final-message"; status = "sent"; recipient = "main-thread-orchestrator" }
    goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
} | ConvertTo-Json -Depth 16 -Compress
```

Call the new script:

```powershell
$result = Invoke-JsonScript -ScriptName "validate-pr-ready.ps1" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", (New-SetupLedger), "-PrReadyLedgerJson", $prReady)
Assert-True ($result.ok) $result.reason
Assert-True ($result.evidence.goal_status -eq "complete") "resolve goal completion was not recorded"
```

Add a scenario named `"worker setup includes dynamic work packet map"`:

```powershell
$result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "orchestrated-worker"))
Assert-True ($result.ok) $result.reason
Assert-True ($result.setup_ledger.worker_handoff.dynamic_work_packet_map.worker_packet.objective -match "Implement") "worker packet objective missing"
Assert-True ($result.setup_ledger.dynamic_work_packet_map.merge_owner -eq "merge-changes") "merge owner must be merge-changes"
```

- [ ] **Step 2: Run resolver scenarios and verify red state**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
```

Expected: FAIL because `validate-pr-ready.ps1` and Dynamic Work Packet Map fields do not exist yet.

- [ ] **Step 3: Add Dynamic Work Packet Map helpers**

Append to `skills/resolve-issue/scripts/lib/contract.ps1`:

```powershell
function New-DynamicWorkPacketMap {
    param($Handoff, $Decision)
    [ordered]@{
        goal = [string]$Handoff.goal_objective
        success_criteria = @(
            "acceptance criteria covered",
            "verification passes",
            "branch pushed",
            "PR opened and closes linked issue",
            "PR-ready handoff sent to main orchestrator"
        )
        repo_context = [ordered]@{
            issue_url = [string]$Handoff.issue_url
            issue_mirror = Normalize-RepoPath ([string]$Handoff.issue_mirror)
            source_plan = Normalize-RepoPath ([string]$Handoff.source_plan)
            branch = Normalize-RepoPath ([string]$Handoff.branch)
        }
        orchestrator_owner = "main-thread-orchestrator"
        merge_owner = "merge-changes"
        full_dynamic_workflow_policy = "Use only when scope, risk, independent packets, separate verification, reusable workflow value, or explicit user request justifies it."
        worker_packet = [ordered]@{
            objective = "Implement the linked issue to PR-ready evidence."
            do = @(
                "use superpowers:using-git-worktrees",
                "use superpowers:test-driven-development unless the source plan records an explicit opt-out",
                "use superpowers:executing-plans or superpowers:subagent-driven-development",
                "use superpowers:verification-before-completion",
                "use superpowers:finishing-a-development-branch",
                "open a PR that closes the exact linked issue",
                "send PR-ready handoff to the main orchestrator"
            )
            do_not = @(
                "merge the PR",
                "delete branches outside the owned implementation branch",
                "create GoalBuddy boards",
                "create .workflow directories for ordinary issue resolution"
            )
            expected_output = "PR-ready handoff ledger"
            verification = Get-StringArray $Handoff.proof_oracle
        }
        wakeup_policy = "worker handoff or bounded heartbeat"
    }
}

function Assert-DynamicWorkPacketMap {
    param($Map)
    if ($null -eq $Map) { throw "dynamic_work_packet_map is required for orchestrated-worker execution" }
    if ($Map -is [string]) { throw "dynamic_work_packet_map must be structured" }
    foreach ($field in @("goal", "success_criteria", "repo_context", "orchestrator_owner", "merge_owner", "worker_packet", "wakeup_policy")) {
        if (-not (Test-Property -Object $Map -Name $field)) { throw "dynamic_work_packet_map missing $field" }
    }
    if ([string]$Map.merge_owner -ne "merge-changes") { throw "dynamic_work_packet_map merge_owner must be merge-changes" }
}
```

- [ ] **Step 4: Include the map in worker setup**

In `New-WorkerHandoff`, add this field before `closeout_owner`:

```powershell
dynamic_work_packet_map = New-DynamicWorkPacketMap -Handoff $Handoff -Decision $Decision
```

Change `closeout_owner` to:

```powershell
integration_owner = "merge-changes"
```

In `prepare-execution.ps1`, add this top-level setup ledger field:

```powershell
dynamic_work_packet_map = if ([string]$executionDecision.selected_mode -eq "orchestrated-worker") { New-DynamicWorkPacketMap -Handoff $handoff -Decision $executionDecision } else { $null }
```

- [ ] **Step 5: Validate the map for worker mode**

In `skills/resolve-issue/scripts/validate-setup.ps1`, after the existing worker handoff check, add:

```powershell
if ([string]$ledger.execution_decision.selected_mode -eq "orchestrated-worker") {
    Assert-DynamicWorkPacketMap -Map $ledger.dynamic_work_packet_map
    Assert-DynamicWorkPacketMap -Map $ledger.worker_handoff.dynamic_work_packet_map
}
```

- [ ] **Step 6: Create `validate-pr-ready.ps1`**

Create `skills/resolve-issue/scripts/validate-pr-ready.ps1` with:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerJson,
    [string]$SetupLedgerPath,
    [string]$PrReadyLedgerJson,
    [string]$PrReadyLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "pr-ready"

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $setup = Read-JsonInput -Json $SetupLedgerJson -Path $SetupLedgerPath -Name "setup ledger"
    $ready = Read-JsonInput -Json $PrReadyLedgerJson -Path $PrReadyLedgerPath -Name "PR-ready ledger"
    if ([string]$ready.issue_url -ne [string]$setup.issue_url) { throw "PR-ready issue_url must match setup ledger" }
    if ((Normalize-RepoPath ([string]$ready.branch)) -ne (Normalize-RepoPath ([string]$setup.branch))) { throw "PR-ready branch must match setup ledger" }
    foreach ($field in @("branch_pushed", "pr_closes_issue", "acceptance_criteria_covered", "verification_passed")) {
        if ($ready.$field -ne $true) { throw "PR-ready ledger requires $field" }
    }
    foreach ($field in @("handoff_sent", "goal_completion_proof")) {
        if (-not (Test-Property -Object $ready -Name $field) -or $ready.$field -is [string]) { throw "PR-ready ledger $field must be structured" }
    }
    $goalProof = $ready.goal_completion_proof
    if ([string]$goalProof.status -ne "complete") { throw "goal completion proof must mark status complete" }
    if ([string]$goalProof.source -ne "update_goal" -and [string]$goalProof.source -ne "slash-command") { throw "goal completion proof must come from update_goal or exact slash-command evidence" }
    Complete-Contract -Phase $phase -Reason "PR-ready handoff checks passed" -Evidence @{ pr_url = [string]$ready.pr_url; issue_url = [string]$ready.issue_url; goal_status = [string]$goalProof.status }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
```

- [ ] **Step 7: Narrow resolver skill text**

In `skills/resolve-issue/SKILL.md`, update the opening paragraph to:

```markdown
This skill owns implementation for one ready GitHub issue. It starts from a synced issue mirror under `docs/superpowers/issues`, validates the linked source plan, activates a native `/goal`, executes with Superpowers discipline, and ends with PR-ready evidence: covered acceptance criteria, passed verification, pushed branch, opened PR that closes the linked issue, native goal completion proof, and a handoff to `$project:merge-changes`.
```

Replace the state machine tail with:

```markdown
10. `development branch finish`: use `superpowers:finishing-a-development-branch`, with PR as the default finish path.
11. `PR-ready validation`: validate branch push, PR URL, closing issue reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
12. `handoff`: send or record the worker/main-thread handoff and route final integration to `$project:merge-changes`.
```

Replace the completion rule with:

```markdown
Do not send a success-style final response until PR-ready proof shows:

- Acceptance criteria are covered.
- Verification passed.
- Branch is pushed.
- PR is opened and closes the exact linked issue.
- Native resolve goal is marked complete.
- PR-ready handoff was sent or recorded for `$project:merge-changes`.
```

Remove resolver claims that it merges, closes issues, syncs default, deletes branches, or runs final closeout.

- [ ] **Step 8: Narrow resolver metadata**

In `skills/resolve-issue/agents/openai.yaml`, replace the default prompt with:

```yaml
version: 1
skills:
  resolve-issue:
    default_prompt: "Use $project:resolve-issue to implement one ready GitHub issue mirror under docs/superpowers/issues with a linked source plan under docs/superpowers/plans. Ask the native execution topology question before branch setup: open a worker worktree thread or resolve in the current thread. Activate native /goal proof, record the execution decision, create a Dynamic Work Packet Map for worker mode, execute with Superpowers TDD and verification, push the branch, open a PR that closes the exact issue, validate PR-ready evidence, complete the resolve goal at PR-ready, and hand off final integration to $project:merge-changes. Do not merge, close issues, delete branches, or run final cleanup from this skill."
```

- [ ] **Step 9: Delete resolver merge scripts after the new merge scripts pass**

Run:

```powershell
Remove-Item -LiteralPath .\skills\resolve-issue\scripts\premerge.ps1
Remove-Item -LiteralPath .\skills\resolve-issue\scripts\closeout.ps1
```

- [ ] **Step 10: Run resolver scenario tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
```

Expected: PASS.

## Task 5: Add The `## Project Merge` Issue Mirror Section

**Files:**

- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/validate-issue-mirror.ps1`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `docs/superpowers/issues/README.md`
- Modify: `docs/superpowers/issues/smoke-test-workflow.md`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `scripts/test-superpowers-project-repo-contract.ps1`

- [ ] **Step 1: Update issue mirror template text**

In `skills/create-issues/SKILL.md`, add these required fields to the Issue Mirror Contract list:

```markdown
- Project Merge section
- Merge Owner
- Merge Gate
- Merge Policy
- Worktree Cleanup Policy
- Orchestrator Wakeup Policy
```

In the GitHub issue body shape, add this section after `**Script Gate Mode:** Safety only`:

```markdown
## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat
```

- [ ] **Step 2: Update issue metadata prompt**

In `skills/create-issues/agents/openai.yaml`, add this phrase to the default prompt:

```text
include a Project Merge section with Merge Owner, Merge Gate, Merge Policy, Worktree Cleanup Policy, and Orchestrator Wakeup Policy
```

- [ ] **Step 3: Add merge section validation**

In `skills/create-issues/scripts/validate-issue-mirror.ps1`, after workflow metadata validation, add:

```powershell
$hasProjectMergeSection = [regex]::IsMatch($text, "(?im)^##\s*Project Merge\s*$")
if (-not $hasProjectMergeSection) {
    Complete -Ok $false -Reason "Project Merge section is required"
}
Add-Check -Name "project merge section" -Ok $true -Reason "passed"

$mergeFields = [ordered]@{
    "Merge Owner" = @("Main thread orchestrator")
    "Merge Gate" = @("Native UI approval required")
    "Merge Policy" = @("Repo default", "Squash", "Merge commit", "Rebase")
    "Worktree Cleanup Policy" = @("Remove owned worktree after merge", "No worktree created")
    "Orchestrator Wakeup Policy" = @("Worker handoff or bounded heartbeat", "User resumes from handoff", "Inline run")
}
foreach ($fieldName in $mergeFields.Keys) {
    $value = Get-FieldValue -Text $text -Name $fieldName
    if ([string]::IsNullOrWhiteSpace($value)) {
        Complete -Ok $false -Reason "$fieldName is required in Project Merge section"
    }
    if ($mergeFields[$fieldName] -notcontains $value) {
        Complete -Ok $false -Reason "$fieldName must be one of: $($mergeFields[$fieldName] -join ', ')"
    }
    Add-Check -Name "project merge metadata: $fieldName" -Ok $true -Reason "passed"
}
```

- [ ] **Step 4: Update project issue scenarios**

In `skills/create-issues/scripts/test-scenarios.ps1`, add the `## Project Merge` section to every happy issue mirror fixture:

```markdown
## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat
```

Add text needles for:

```powershell
"Project Merge",
"Merge Owner",
"Merge Gate",
"Merge Policy",
"Worktree Cleanup Policy",
"Orchestrator Wakeup Policy"
```

- [ ] **Step 5: Update repo issue docs and smoke issue**

In `docs/superpowers/issues/README.md`, add:

```markdown
## Project Merge Metadata

New issue mirrors should include:

```markdown
## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat
```
```

In `docs/superpowers/issues/smoke-test-workflow.md`, add the same `## Project Merge` section after the workflow metadata block.

- [ ] **Step 6: Run issue scenario tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
```

Expected: PASS.

## Task 6: Update Router, Context, Metadata, And Repo Contracts

**Files:**

- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `scripts/test-superpowers-project-dummy-repo.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`
- Test: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Test: `scripts/test-superpowers-project-dummy-repo.ps1`
- Test: `scripts/test-superpowers-project-repo-contract.ps1`

- [ ] **Step 1: Update router text**

In `skills/initiate-workflow/SKILL.md`, add this route:

```markdown
- PR URL, worker handoff, merge approval, issue close verification, branch/worktree cleanup, or clean repo proof: `$project:merge-changes`
```

In the Goal Routing section, add:

```markdown
After `$project:resolve-issue` creates PR-ready evidence, final integration must route to `$project:merge-changes`.
```

- [ ] **Step 2: Update router metadata**

In `skills/initiate-workflow/agents/openai.yaml`, replace the default prompt with a prompt that includes:

```text
PR or worker-handoff integration to $project:merge-changes with native merge approval, issue close verification, branch/worktree cleanup, prune, cleanup hook, and clean repo proof
```

- [ ] **Step 3: Update project context**

In `docs/superpowers/PROJECT_CONTEXT.md`, add `merge-changes` under Extension Skills:

```markdown
- `merge-changes`
```

Update Execution Model to:

```markdown
Issue implementation uses native `/goal` or goal tools plus Superpowers execution skills through `$project:resolve-issue`. PR integration, linked issue close verification, branch/worktree cleanup, pruning, and final clean repo proof are owned by `$project:merge-changes`. GoalBuddy boards are outside the default execution model.
```

- [ ] **Step 4: Update README**

In `README.md`, add:

```markdown
- `$project:merge-changes`: reviews and merges PR-ready issue work, verifies linked issue closure, cleans owned branches and worktrees, prunes, and records clean repo proof.
```

- [ ] **Step 5: Update plugin manifest prompts**

In `.codex-plugin/plugin.json`, add this default prompt entry:

```json
"Merge a PR-ready issue handoff with merge-changes."
```

- [ ] **Step 6: Update dummy repo fixture**

In `scripts/test-superpowers-project-dummy-repo.ps1`, add the `## Project Merge` section to the seeded `12-dummy.md` issue mirror.

After the worker setup decision check, assert the packet map:

```powershell
if (-not $workerFinalize.setup_ledger.dynamic_work_packet_map) { throw "dynamic work packet map was not recorded" }
if ($workerFinalize.setup_ledger.dynamic_work_packet_map.merge_owner -ne "merge-changes") { throw "dynamic work packet map merge owner mismatch" }
```

- [ ] **Step 7: Update repo contract checks**

In `scripts/test-superpowers-project-repo-contract.ps1`, add `merge-changes` to the active skill arrays and add these required issue mirror needles:

```powershell
"Project Merge",
"Merge Owner",
"Merge Gate",
"Merge Policy",
"Worktree Cleanup Policy",
"Orchestrator Wakeup Policy"
```

- [ ] **Step 8: Run router and repo contract tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
```

Expected: all PASS.

## Task 7: Add Native Continuation Gates Across Handoffs

**Files:**

- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/initiate-workflow/SKILL.md`
- Test: `skills/write-plan/scripts/test-scenarios.ps1`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `skills/initiate-workflow/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add a failing `$project:write-plan` continuation test**

In `skills/write-plan/scripts/test-scenarios.ps1`, add a scenario that requires the skill text to contain the executable continuation gate:

```powershell
Invoke-Scenario "native continuation gate is present" {
    $text = Get-Content -LiteralPath $skillFile -Raw
    foreach ($needle in @(
        "## Native Continuation Gate",
        "project_plan_next_step",
        "Project Issue First",
        "Subagent Execute",
        "Inline Execute",
        "start the selected next skill",
        "Do not only tell the user what to prompt next"
    )) {
        Assert-Contains $text $needle "missing continuation gate text: $needle"
    }
}
```

Add metadata needles:

```powershell
Assert-Contains $metadata "project_plan_next_step" "missing continuation question id"
Assert-Contains $metadata "start the selected next skill" "missing executable routing guidance"
```

- [ ] **Step 2: Run the `$project:write-plan` tests and verify red state**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
```

Expected: FAIL because the continuation-gate text is not present yet.

- [ ] **Step 3: Add the `$project:write-plan` continuation gate**

In `skills/write-plan/SKILL.md`, add this section before `## Self-Review`:

```markdown
## Native Continuation Gate

After saving and self-reviewing the plan, ask a native continuation question when `request_user_input` is callable. This question is executable routing, not advisory text.

Question id: `project_plan_next_step`

Prompt: `How should I continue from this project plan?`

Options:

- `Project Issue First`: continue to `$project:create-issues` using the saved plan path.
- `Subagent Execute`: continue with `superpowers:subagent-driven-development` using the saved plan path.
- `Inline Execute`: continue with `superpowers:executing-plans` using the saved plan path.

Recommend `Project Issue First` for repos using the Superpowers Project GitHub issue backbone. Recommend direct execution only when the user intentionally wants to bypass issue creation.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the saved plan path, source spec or issue mirror path, decisions, acceptance criteria, and proof oracle. Do not only tell the user what to prompt next.

If the selected next skill needs its own material decision, ask that next skill's native UI question. If the route needs unavailable tools or an external write that still requires approval, stop with a clear pending state and exact resume target.
```

- [ ] **Step 4: Update `$project:write-plan` metadata**

In `skills/write-plan/agents/openai.yaml`, add this sentence to the default prompt:

```text
After saving and self-reviewing the plan, ask native question project_plan_next_step with Project Issue First, Subagent Execute, and Inline Execute options, then start the selected next skill in the same turn instead of only telling the user what to prompt next.
```

- [ ] **Step 5: Add downstream continuation text**

In `skills/create-issues/SKILL.md`, add:

```markdown
## Native Continuation Gate

After approved issue mirrors or GitHub issues are created and validated, ask how to continue when `request_user_input` is callable. Options should include resolving the first ready issue with `$project:resolve-issue`, resolving a selected issue with `$project:resolve-issue`, or stopping after issue creation. Start the selected next skill in the same turn when tools and state allow it.
```

In `skills/resolve-issue/SKILL.md`, add:

```markdown
## Native Continuation Gate

After PR-ready handoff proof passes, ask how to continue when `request_user_input` is callable. Options should include starting `$project:merge-changes`, resolving another ready issue, or stopping at PR-ready. Start the selected next skill in the same turn when tools and state allow it.
```

In the new `skills/merge-changes/SKILL.md`, add:

```markdown
## Native Continuation Gate

After closeout proof passes, ask how to continue when `request_user_input` is callable. Options should include resolving the next ready issue with `$project:resolve-issue`, running `$project:audit-project`, or stopping after clean closeout. Start the selected next skill in the same turn when tools and state allow it.
```

- [ ] **Step 6: Update router text**

In `skills/initiate-workflow/SKILL.md`, add:

```markdown
## Continuation Routing

At major handoffs, use native continuation questions and treat the selected answer as executable routing. The agent should start the selected next skill in the same turn when possible instead of ending with a prompt suggestion.
```

- [ ] **Step 7: Run focused continuation tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
```

Expected: all PASS.

## Task 8: Verify The Split End To End

**Files:**

- Test: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1`

- [ ] **Step 1: Run focused skill tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
```

Expected: all PASS.

- [ ] **Step 2: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

- [ ] **Step 3: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: PASS. Confirm the JSON output includes `merge-changes` under both deployed plugin skills and deployed user skills.

- [ ] **Step 4: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no matching leftover Codex processes for this repo, or only processes clearly owned by the task if `-Kill` is explicitly used later.

- [ ] **Step 5: Commit**

Run:

```powershell
git status --short
git add .codex-plugin/plugin.json README.md docs/superpowers skills scripts
git commit -m "feat: add project merge workflow"
```

Expected: commit succeeds after all proof commands pass.

## Self-Review Checklist

- [ ] Source spec is named: `docs/superpowers/specs/2026-06-02-merge-changes-skill-design.md`.
- [ ] Native UI planning decisions are recorded.
- [ ] Every acceptance criterion maps to at least one task.
- [ ] Every task names exact files and exact commands.
- [ ] TDD is required through failing scenario tests before implementation changes.
- [ ] `$project:resolve-issue` ends at PR-ready evidence.
- [ ] `$project:merge-changes` owns premerge, native merge approval, merge closeout, cleanup, prune, and clean proof.
- [ ] Full completion requires `superpowers:verification-before-completion` before success claims.

## Execution Handoff

Plan complete when this file is saved. The implemented `$project:write-plan` closeout should ask `project_plan_next_step` and then immediately route to `$project:create-issues`, `superpowers:subagent-driven-development`, or `superpowers:executing-plans` based on the selected native UI answer.


