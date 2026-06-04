# Project Namespace And Implementation Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Superpowers Project to the `project:*` plugin namespace, bundle `advanced-user-input` as an official plugin skill, add the direct `implement-plan` route, and align setup, orchestration, merge, sync, and public-release surfaces around the new workflow.

**Architecture:** Treat this as one source-of-truth migration in the plugin repo: source skills live only under `skills/`, runtime deployment goes to `C:\Users\Tanner\plugins\project`, and old global user-skill copies are removed. Implement behavior in validated skill docs plus bundled scenario scripts, then update repo validation and live sync so stale names, stale paths, and missing bundled skills fail loudly.

**Tech Stack:** Codex skill Markdown/YAML, PowerShell 7 validation scripts, JSON ledgers, Git/GitHub CLI evidence, native `request_user_input`, `request_agent_input` written protocol, docs under `docs/superpowers`, and existing repo validators.

---

## Intake

**Source Specs:**

- `docs/superpowers/specs/2026-06-03-project-implement-and-integration-workflow-design.md`
- `docs/superpowers/specs/2026-06-03-project-plugin-namespace-skill-naming-design.md`
- `docs/superpowers/specs/2026-06-03-project-setup-orchestration-design.md`
- `docs/superpowers/specs/2026-06-03-public-release-readiness-design.md`

**Bundled Skill Source:**

- `C:\Users\Tanner\.agents\skills\advanced-user-input\SKILL.md`

**Planning Grill Decisions:**

- Keep this as one master implementation plan with phased checkpoints.
- Ship the namespace migration and `implement-plan` behavior in the same implementation pass.
- Remove repo-owned stale live plugin roots and global user-skill copies automatically after ownership checks.
- Adapt `advanced-user-input` wording for the plugin, rather than copying the user-level skill verbatim.
- Setup may create/configure the GitHub Project board only after native approval.
- `merge-changes` should support guarded local branch merges in the first implementation.
- `request_agent_input` is only valid for worker threads created by `project:orchestrate-issues` where the worker knows its orchestrator, role, reporting path, and reason for asking.
- External GitHub issue hydration is a strict gate before resolve/orchestrate execution.
- Rename the GitHub repository only, not the local workspace folder.
- Make the GitHub repository public in this implementation after the rename and public-readiness checks.
- Harden the current and future plan-writing skills so `$grill-me` behavior and native `request_user_input` are hard gates before plan save when material decisions remain.

**Current Source Skill Set:**

- `skills/superpowers-project`
- `skills/project-setup`
- `skills/project-orchestrate`
- `skills/project-brainstorm`
- `skills/project-plan`
- `skills/project-issue`
- `skills/project-resolve`
- `skills/project-merge`
- `skills/project-doctor`

**Target Source Skill Set:**

- `skills/workflow`
- `skills/setup`
- `skills/audit-project`
- `skills/brainstorm-spec`
- `skills/write-plan`
- `skills/create-issues`
- `skills/implement-plan`
- `skills/resolve-issue`
- `skills/orchestrate-issues`
- `skills/merge-changes`
- `skills/advanced-user-input`

**Milestone Linkage:**

- `M0 - Governance`: native Q&A, request-agent protocol, publish permission, merge approval, goal and proof gates.
- `M1 - Source Of Truth`: plugin namespace, source skill names, setup context, GitHub board config, live sync ownership, stale copy cleanup.
- `M2 - Distribution`: public install path, README clarity, plugin metadata, Reddit-ready public surface.

## Acceptance Criteria

- `.codex-plugin/plugin.json` uses runtime `name: project` and keeps display name `Superpowers Project`.
- GitHub repository is renamed from `tannerpolley/milestones-plugin` to `tannerpolley/codex-superpowers-project`.
- GitHub repository visibility is changed to public after README, manifest, issue templates, and validation pass.
- Active source skills match the target source skill set exactly.
- `advanced-user-input` is bundled under `skills/advanced-user-input` and validates as an official plugin skill.
- The bundled `advanced-user-input` skill includes both `request_user_input` guidance and the `request_agent_input` worker-to-orchestrator protocol.
- Current `project-plan` and future `write-plan` enforce planning grill plus native Q&A as hard gates before plan save when material decisions remain.
- `scripts/sync-live.ps1 -Validate` deploys to `C:\Users\Tanner\plugins\project`.
- `scripts/sync-live.ps1 -Validate` stops copying active plugin skills into `C:\Users\Tanner\.agents\skills`.
- Sync removes repo-owned old user-skill copies and old live plugin roots after ownership checks.
- `workflow` routes using `project:*` names and no longer advertises `$project-*` global skills.
- `write-plan` continuation includes `Project Implement`, `Project Issue First`, `Review First`, `Revise Plan`, and `Stop`; Quick Apply remains only for guarded local-main small changes.
- `implement-plan` accepts an approved plan, requires native `/goal`, chooses inline or worker topology, uses branch-backed execution, asks native publish permission, and routes merge-ready work to `merge-changes`.
- `merge-changes` supports `pr-issue`, `pr-no-issue`, and `local-branch` modes.
- `orchestrate-issues` supports canonical worker identity and autonomous ready-issue selection with local/GitHub drift reroute to `audit-project`.
- `setup` supports GitHub Project board configuration after native approval and records enough config for audit.
- External GitHub issues can be hydrated into local mirrors plus source plans before execution.
- README, issue templates, metadata, and scenario tests use `project:*` names.
- Repo validation and live sync validation pass.

## Non-Goals

- Do not keep compatibility wrappers, alias stubs, or forwarding skills for old names.
- Do not copy active plugin skills into `C:\Users\Tanner\.agents\skills` after the namespace migration.
- Do not rename the local workspace folder.
- Do not rewrite closed issue or PR history links.
- Do not create `docs/superpowers/implementations`.
- Do not let non-issue implementation claim GitHub issue closure.
- Do not let worker threads merge their own PRs by default.
- Do not implement full Doctor tracker repair from issue #21 unless a separate plan explicitly targets that issue.

## File Map

- Create: `skills/advanced-user-input/SKILL.md`
- Create: `skills/advanced-user-input/scripts/test-scenarios.ps1`
- Create: `skills/implement-plan/SKILL.md`
- Create: `skills/implement-plan/agents/openai.yaml`
- Create: `skills/implement-plan/scripts/test-scenarios.ps1`
- Create: `skills/implement-plan/scripts/lib/contract.ps1`
- Create: `scripts/test-project-namespace-migration.ps1`
- Create: `scripts/test-plugin-only-live-sync.ps1`
- Modify: `.codex-plugin/plugin.json`
- Modify: `.github/ISSUE_TEMPLATE/*.yml`
- Modify: `scripts/validate.ps1`
- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/test-sync-live.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`
- Modify: `README.md`
- Modify: `skills/project-plan/SKILL.md`
- Modify: `skills/project-plan/agents/openai.yaml`
- Modify: `skills/project-plan/scripts/test-scenarios.ps1`
- Modify/Rename: all existing `skills/<old-name>` directories into target `skills/<new-name>` directories.
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `docs/agents/project-roadmap.json`
- Modify: `docs/agents/issue-tracker.md`
- Modify: `skills/setup/**`
- Modify: `skills/workflow/**`
- Modify: `skills/write-plan/**`
- Modify: `skills/create-issues/**`
- Modify: `skills/resolve-issue/**`
- Modify: `skills/orchestrate-issues/**`
- Modify: `skills/merge-changes/**`
- Modify: `skills/audit-project/**`

## Risk And Sequencing Notes

- Do namespace migration before behavior expansion. Otherwise new behavior gets written against names that immediately become stale.
- Bundle `advanced-user-input` before updating skills that reference it.
- Keep validation green at every task checkpoint with scenario tests and focused migration checks.
- Use `git mv` for skill directory renames so history is preserved.
- Remove live user-skill copies only through `scripts/sync-live.ps1` ownership checks.
- Treat `request_agent_input` as a written protocol, not a tool call. It is only valid for worker/subagent threads that need an orchestrator decision.
- In this plugin, `request_agent_input` is narrower than the generic user-level skill: use it only for workers created by `project:orchestrate-issues` that have an explicit worker handoff naming the orchestrator, branch, issue/plan, reporting path, and why the worker may ask the orchestrator.
- Because the repo rename and public visibility change are remote mutations, execute them only after validation and native confirmation inside the implementation task, even though this plan includes them in scope.

## Proof Oracle

Run these commands before claiming completion:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\advanced-user-input\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-project-namespace-migration.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plugin-only-live-sync.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
git status --short --branch
```

Expected final state:

- Every command exits `0`.
- `git status --short --branch` shows a clean branch after final commit.
- `Test-Path "$env:USERPROFILE\plugins\project\.codex-plugin\plugin.json"` returns `True`.
- `Test-Path "$env:USERPROFILE\plugins\superpowers-project"` returns `False` after ownership-checked cleanup, or is reported as a retired path if cleanup is deferred by an explicit user decision.
- `Get-ChildItem "$env:USERPROFILE\.agents\skills"` does not include repo-owned old global copies such as `project-plan`, `project-resolve`, or `superpowers-project`.

### Task 1: Harden Current Plan-Writing Gate

**Files:**

- Modify: `skills/project-plan/SKILL.md`
- Modify: `skills/project-plan/agents/openai.yaml`
- Modify: `skills/project-plan/scripts/test-scenarios.ps1`
- Test: `skills/project-plan/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add a failing scenario for the Planning Grill Gate**

In `skills/project-plan/scripts/test-scenarios.ps1`, add a scenario that requires these phrases in `SKILL.md`:

```text
## Planning Grill Gate
Before saving any new plan
Interview me relentlessly about every aspect of this plan
native UI hard gate
Do not save the plan until material decisions have been answered
If the planning agent realizes it skipped the grill after drafting a plan
revise the saved plan before presenting it as ready
branch strategy
publish behavior
live mutation
```

- [ ] **Step 2: Make the Planning Grill Gate explicit**

In `skills/project-plan/SKILL.md`, replace the optional short-grill wording with a hard gate:

```markdown
## Planning Grill Gate

Before saving any new plan, run a planning grill whenever material assumptions, scope choices, sequencing choices, proof-oracle choices, naming choices, branch strategy choices, or routing choices remain.

Use the `$grill-me` behavior verbatim:

`Interview me relentlessly about every aspect of this plan`

When `request_user_input` is callable, the grill is a native UI hard gate, not optional prose. Batch independent material questions into native Q&A calls with recommended options first. Ask sequential follow-ups when one answer changes the next branch. Do not save the plan until material decisions have been answered or explicitly deferred in the plan with a named risk owner.

If a question can be answered by inspecting the repo, inspect first instead of asking. If the planning agent realizes it skipped the grill after drafting a plan, stop, run the native grill, and revise the saved plan before presenting it as ready.
```

- [ ] **Step 3: Mirror the gate in metadata**

In `skills/project-plan/agents/openai.yaml`, include the same policy in the default prompt:

```text
Before saving a plan, use the Planning Grill Gate: apply grill-me behavior, inspect knowable context first, and use request_user_input in Default mode as a hard gate for material scope, acceptance criteria, sequencing, proof oracle, TDD policy, branch strategy, routing, publish behavior, or live mutation choices.
```

- [ ] **Step 4: Run focused validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1
```

Expected: all scenarios pass.

- [ ] **Step 5: Commit checkpoint**

```powershell
git add skills/project-plan
git commit -m "fix: require planning grill native qa gate"
```

### Task 2: Add Namespace Migration Contract Tests

**Files:**

- Create: `scripts/test-project-namespace-migration.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-project-namespace-migration.ps1`

- [ ] **Step 1: Write the failing namespace test**

Create `scripts/test-project-namespace-migration.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param([System.Collections.Generic.List[object]]$Checks, [string]$Name, [bool]$Ok, [string]$Reason = "passed")
    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

$checks = [System.Collections.Generic.List[object]]::new()
$skillRoot = Join-Path $RepoRoot "skills"
$manifestPath = Join-Path $RepoRoot ".codex-plugin\plugin.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

$expectedSkills = @(
    "advanced-user-input",
    "audit-project",
    "brainstorm-spec",
    "create-issues",
    "implement-plan",
    "merge-changes",
    "orchestrate-issues",
    "resolve-issue",
    "setup",
    "workflow",
    "write-plan"
)
$retiredSkills = @(
    "superpowers-project",
    "project-setup",
    "project-orchestrate",
    "project-brainstorm",
    "project-plan",
    "project-issue",
    "project-resolve",
    "project-merge",
    "project-doctor",
    "project-context"
)

$actualSkills = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)
Add-Check $checks "plugin runtime namespace is project" ($manifest.name -eq "project") "plugin.json name must be project"
Add-Check $checks "display brand remains Superpowers Project" ($manifest.interface.displayName -eq "Superpowers Project") "display name must remain Superpowers Project"
Add-Check $checks "active skill set matches target" (@(Compare-Object $expectedSkills $actualSkills).Count -eq 0) "skills directory must match target project namespace surface"

foreach ($skillName in $expectedSkills) {
    $skillPath = Join-Path $skillRoot "$skillName\SKILL.md"
    $exists = Test-Path -LiteralPath $skillPath -PathType Leaf
    Add-Check $checks "skill exists $skillName" $exists "missing $skillPath"
    if ($exists) {
        $text = Get-Content -LiteralPath $skillPath -Raw
        Add-Check $checks "skill frontmatter name $skillName" ($text.Contains("name: $skillName")) "$skillPath must declare name: $skillName"
    }
}

foreach ($skillName in $retiredSkills) {
    Add-Check $checks "retired skill absent $skillName" (-not (Test-Path -LiteralPath (Join-Path $skillRoot $skillName) -PathType Container)) "retired skill directory must be removed: $skillName"
}

$scanRoots = @(
    (Join-Path $RepoRoot "README.md"),
    (Join-Path $RepoRoot ".codex-plugin"),
    (Join-Path $RepoRoot "skills")
)
$stale = @(rg -n "\$project-|project-brainstorm|project-plan|project-issue|project-resolve|project-orchestrate|project-merge|project-doctor|superpowers-project" @scanRoots 2>$null)
$allowed = @($stale | Where-Object { $_ -match "retired|migration|history|removed" })
Add-Check $checks "no active stale prompt names" ($stale.Count -eq $allowed.Count) "active docs/prompts still contain retired skill names: $($stale -join '; ')"

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "project-namespace-migration"
    checks = $checks
} | ConvertTo-Json -Depth 8

if ($failed.Count -gt 0) { exit 1 }
```

- [ ] **Step 2: Wire the failing test into validation after the current skill source contract**

In `scripts/validate.ps1`, add:

```powershell
$results.Add((Invoke-Step "project namespace migration contract" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-project-namespace-migration.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "project namespace migration contract failed" }
}))
```

Place it after `Native Q&A SVG contract` while this migration is under active implementation.

- [ ] **Step 3: Run the test and verify expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-project-namespace-migration.ps1
```

Expected: fails because `.codex-plugin/plugin.json` is still `superpowers-project`, old skill directories still exist, and target directories do not exist yet.

- [ ] **Step 4: Commit checkpoint**

```powershell
git add scripts/test-project-namespace-migration.ps1 scripts/validate.ps1
git commit -m "test: add project namespace migration contract"
```

### Task 3: Bundle Advanced User Input As A Plugin Skill

**Files:**

- Create: `skills/advanced-user-input/SKILL.md`
- Create: `skills/advanced-user-input/scripts/test-scenarios.ps1`
- Modify: `scripts/validate.ps1`
- Test: `skills/advanced-user-input/scripts/test-scenarios.ps1`

- [ ] **Step 1: Adapt the source skill into the plugin**

Create `skills/advanced-user-input/SKILL.md` using `C:\Users\Tanner\.agents\skills\advanced-user-input\SKILL.md` as source material, but adapt wording for the Superpowers Project plugin. Keep the generic native UI patterns, then narrow `request_agent_input` to the plugin's orchestrated-worker model.

The frontmatter must be:

```yaml
---
name: advanced-user-input
description: Use when choosing how to ask users or orchestrator agents for structured input, nested choices, free-text answers, exact values, or multi-step clarification.
---
```

The body must include these headings exactly:

```markdown
## Native UI Constraints
## Inspect First
## Input Choice
## Native Choice Pattern
## Request Agent Input Pattern
## Nested Choice Pattern
## Fill-In-The-Blank Pattern
## Open Feedback Pattern
## Hybrid Pattern
## Stop Rules
```

The `Request Agent Input Pattern` section must state:

```markdown
`request_agent_input` is a written protocol, not a runtime tool. In Superpowers Project, use it only inside worker threads created by `project:orchestrate-issues` when the worker has a handoff that names the orchestrator, branch, issue or plan, reporting path, and reason the worker may ask the orchestrator.

Do not use `request_agent_input` in root user-facing threads, ordinary planning threads, or worker threads whose orchestrator relationship is unclear. Those threads must use native `request_user_input` when callable or normal chat for exact free-form values.
```

- [ ] **Step 2: Add scenario tests for user and agent input contracts**

Create `skills/advanced-user-input/scripts/test-scenarios.ps1`:

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path $PSScriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        [pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }
    } catch {
        [pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }
    }
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Reason)
    if (-not $Text.Contains($Needle)) { throw $Reason }
}

$text = Get-Content -LiteralPath $skillFile -Raw

$scenarios = @(
    Invoke-Scenario "frontmatter is valid" {
        Assert-Contains $text "name: advanced-user-input" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
    }
    Invoke-Scenario "native request_user_input contract is present" {
        foreach ($needle in @(
            "request_user_input",
            "Use as many native questions and options as the decision requires.",
            "Observed Codex Desktop behavior",
            "Do not add an `Other` option",
            "Normal chat is for exact text."
        )) {
            Assert-Contains $text $needle "missing native UI contract: $needle"
        }
    }
    Invoke-Scenario "request_agent_input protocol is present" {
        foreach ($needle in @(
            "request_agent_input",
            "written protocol, not a runtime tool",
            "created by `project:orchestrate-issues`",
            "names the orchestrator",
            "reporting path",
            "Do not call native `request_user_input`.",
            "Waiting for orchestrator response."
        )) {
            Assert-Contains $text $needle "missing request_agent_input contract: $needle"
        }
    }
    Invoke-Scenario "nested choice pattern is present" {
        foreach ($needle in @(
            "Sketch the decision tree before asking.",
            "Ask only the top-level blocking choice first.",
            "Group 4+ options into 2-3 meaningful branches.",
            "Path: <answer> -> <current branch>"
        )) {
            Assert-Contains $text $needle "missing nested choice contract: $needle"
        }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
```

- [ ] **Step 3: Update active skill validation**

In `scripts/validate.ps1`, include `advanced-user-input` in the active skill list after the namespace migration is in place:

```powershell
function Get-ActiveSkillNames {
    @(
        "advanced-user-input",
        "audit-project",
        "brainstorm-spec",
        "create-issues",
        "implement-plan",
        "merge-changes",
        "orchestrate-issues",
        "resolve-issue",
        "setup",
        "workflow",
        "write-plan"
    )
}
```

- [ ] **Step 4: Run focused validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\advanced-user-input\scripts\test-scenarios.ps1
py -3.12 .\scripts\quick-validate-skill.py .\skills\advanced-user-input
```

Expected: scenario JSON has `"ok": true` for every scenario, and `quick-validate-skill.py` prints `Skill is valid!`.

- [ ] **Step 5: Commit checkpoint**

```powershell
git add skills/advanced-user-input scripts/validate.ps1
git commit -m "feat: bundle advanced user input skill"
```

### Task 4: Rename Plugin Namespace And Skill Directories

**Files:**

- Modify: `.codex-plugin/plugin.json`
- Rename: `skills/superpowers-project` -> `skills/workflow`
- Rename: `skills/project-setup` -> `skills/setup`
- Rename: `skills/project-doctor` -> `skills/audit-project`
- Rename: `skills/project-brainstorm` -> `skills/brainstorm-spec`
- Rename: `skills/project-plan` -> `skills/write-plan`
- Rename: `skills/project-issue` -> `skills/create-issues`
- Rename: `skills/project-resolve` -> `skills/resolve-issue`
- Rename: `skills/project-orchestrate` -> `skills/orchestrate-issues`
- Rename: `skills/project-merge` -> `skills/merge-changes`
- Test: `scripts/test-project-namespace-migration.ps1`

- [ ] **Step 1: Rename directories with Git**

Run:

```powershell
git mv .\skills\superpowers-project .\skills\workflow
git mv .\skills\project-setup .\skills\setup
git mv .\skills\project-doctor .\skills\audit-project
git mv .\skills\project-brainstorm .\skills\brainstorm-spec
git mv .\skills\project-plan .\skills\write-plan
git mv .\skills\project-issue .\skills\create-issues
git mv .\skills\project-resolve .\skills\resolve-issue
git mv .\skills\project-orchestrate .\skills\orchestrate-issues
git mv .\skills\project-merge .\skills\merge-changes
```

Expected: `git status --short` shows renames, not delete/add churn where Git can detect the move.

- [ ] **Step 2: Update skill frontmatter names**

Update these files:

```text
skills/workflow/SKILL.md                  name: workflow
skills/setup/SKILL.md                     name: setup
skills/audit-project/SKILL.md             name: audit-project
skills/brainstorm-spec/SKILL.md           name: brainstorm-spec
skills/write-plan/SKILL.md                name: write-plan
skills/create-issues/SKILL.md             name: create-issues
skills/resolve-issue/SKILL.md             name: resolve-issue
skills/orchestrate-issues/SKILL.md        name: orchestrate-issues
skills/merge-changes/SKILL.md             name: merge-changes
```

Update each matching `agents/openai.yaml` top-level skill key to the same new name.

- [ ] **Step 3: Update plugin manifest runtime namespace**

In `.codex-plugin/plugin.json`, change:

```json
"name": "superpowers-project"
```

to:

```json
"name": "project"
```

Keep:

```json
"displayName": "Superpowers Project"
```

Update `interface.defaultPrompt` entries to use `project:*` language, for example:

```json
"Use project:workflow to choose the right Superpowers Project workflow.",
"Use project:setup to initialize project context, roadmap, and tracker setup.",
"Use project:write-plan to turn an approved spec into an implementation plan.",
"Use project:implement-plan to implement an approved plan without creating a GitHub issue.",
"Use project:merge-changes to integrate a PR or local branch."
```

- [ ] **Step 4: Update internal skill references**

Replace active prompt references:

```text
$superpowers-project       -> project:workflow
$project-setup             -> project:setup
$project-doctor            -> project:audit-project
$project-brainstorm        -> project:brainstorm-spec
$project-plan              -> project:write-plan
$project-issue             -> project:create-issues
$project-resolve           -> project:resolve-issue
$project-orchestrate       -> project:orchestrate-issues
$project-merge             -> project:merge-changes
```

Do not add wrappers for old names.

- [ ] **Step 5: Run namespace test**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-project-namespace-migration.ps1
```

Expected: passes, or reports only documentation references intentionally labeled as migration history.

- [ ] **Step 6: Commit checkpoint**

```powershell
git add .codex-plugin skills scripts/test-project-namespace-migration.ps1 scripts/validate.ps1
git commit -m "feat: migrate skills to project namespace"
```

### Task 5: Update Live Sync For Plugin-Only Deployment

**Files:**

- Create: `scripts/test-plugin-only-live-sync.ps1`
- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/test-sync-live.ps1`
- Test: `scripts/test-plugin-only-live-sync.ps1`

- [ ] **Step 1: Add failing plugin-only sync test**

Create `scripts/test-plugin-only-live-sync.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$syncPath = Join-Path $RepoRoot "scripts\sync-live.ps1"
$text = Get-Content -LiteralPath $syncPath -Raw
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason = "passed")
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

Add-Check "live plugin path is project" ($text.Contains('plugins\project')) "sync-live must deploy to USERPROFILE\plugins\project"
Add-Check "retired superpowers-project path tracked" ($text.Contains('plugins\superpowers-project')) "sync-live must remove or report retired superpowers-project path"
Add-Check "retired milestones path tracked" ($text.Contains('plugins\milestones')) "sync-live must keep milestones cleanup"
Add-Check "does not copy active skills to user skills" (-not $text.Contains('Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $userSkillsRootResolved')) "active plugin skills must not be copied to .agents\skills"
Add-Check "removes old user skill names" ($text.Contains('Remove-StaleOwnedSkillDirectories') -and $text.Contains('project-plan')) "sync-live must remove old repo-owned global skill copies"

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "plugin-only-live-sync"
    checks = $checks
} | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
```

- [ ] **Step 2: Update `sync-live.ps1` defaults and ownership checks**

Change the parameter default:

```powershell
[string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\project")
```

Set expected paths:

```powershell
$expectedLivePluginRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\project"))
$retiredSuperpowersProjectRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\superpowers-project"))
$retiredMilestonesRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "plugins\milestones"))
```

Remove the active `Copy-SkillDirectories` call to `$userSkillsRootResolved`. Keep a cleanup pass that removes repo-owned retired user skills from `.agents\skills`.

- [ ] **Step 3: Update retired skill cleanup list**

In `scripts/sync-live.ps1`, include old names:

```powershell
$retiredSkillNames = @(
    "superpowers-project",
    "project-setup",
    "project-orchestrate",
    "project-brainstorm",
    "project-plan",
    "project-issue",
    "project-resolve",
    "project-merge",
    "project-doctor",
    "project-context",
    "using-milestones",
    "setup-project-milestones",
    "explore-ideas",
    "milestone-writing-issue-plan",
    "convert-idea-to-issue",
    "project-writing-plan",
    "plan-to-issue",
    "resolve-issue-with-goal",
    "milestones-doctor"
)
```

- [ ] **Step 4: Update sync output schema**

The final JSON should include:

```powershell
[pscustomobject]@{
    ok = $true
    source = $repoRoot
    live_plugin_root = $livePluginRootResolved
    user_skills_root = $userSkillsRootResolved
    deployed_plugin_skills = $deployedPluginSkills
    deployed_user_skills = @()
    removed_plugin_skills = $removedPluginSkills
    removed_user_skills = $removedUserSkills
    retired_live_plugin_roots = $retiredRootResults
} | ConvertTo-Json -Depth 8
```

- [ ] **Step 5: Run focused sync tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plugin-only-live-sync.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sync-live.ps1
```

Expected: both pass.

- [ ] **Step 6: Commit checkpoint**

```powershell
git add scripts/sync-live.ps1 scripts/test-sync-live.ps1 scripts/test-plugin-only-live-sync.ps1
git commit -m "feat: deploy project plugin without global skill copies"
```

### Task 6: Add Implement Plan Skill

**Files:**

- Create: `skills/implement-plan/SKILL.md`
- Create: `skills/implement-plan/agents/openai.yaml`
- Create: `skills/implement-plan/scripts/lib/contract.ps1`
- Create: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/workflow/SKILL.md`
- Modify: `skills/workflow/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Test: `skills/implement-plan/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add implementation contract helper**

Create `skills/implement-plan/scripts/lib/contract.ps1`:

```powershell
$ErrorActionPreference = "Stop"

function Test-Property {
    param($Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Test-ImplementPlanLedger {
    param(
        [Parameter(Mandatory = $true)]$Ledger,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if (-not (Test-Property $Ledger "plan_path")) { throw "ledger requires plan_path" }
    $planPath = [string]$Ledger.plan_path
    if (-not $planPath.StartsWith("docs/superpowers/plans/")) { throw "plan_path must be under docs/superpowers/plans" }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $planPath) -PathType Leaf)) { throw "plan_path does not exist" }

    if (-not (Test-Property $Ledger "goal")) { throw "ledger requires goal" }
    if (-not (Test-Property $Ledger.goal "objective") -or [string]::IsNullOrWhiteSpace([string]$Ledger.goal.objective)) { throw "goal objective is required" }
    if (-not (Test-Property $Ledger.goal "status") -or [string]$Ledger.goal.status -notin @("active", "complete")) { throw "goal status must be active or complete" }

    if (-not (Test-Property $Ledger "topology")) { throw "ledger requires topology" }
    if ([string]$Ledger.topology.selected_mode -notin @("inline", "worker")) { throw "topology selected_mode must be inline or worker" }
    if ([string]$Ledger.topology.source -notin @("request_user_input", "request_agent_input", "debug_question_mode")) { throw "topology source must be request_user_input, request_agent_input, or debug_question_mode" }
    if ([string]$Ledger.topology.source -eq "request_agent_input") {
        if (-not (Test-Property $Ledger.topology "orchestrator_skill") -or [string]$Ledger.topology.orchestrator_skill -ne "project:orchestrate-issues") { throw "request_agent_input topology requires orchestrator_skill project:orchestrate-issues" }
        if (-not (Test-Property $Ledger.topology "orchestrator_thread_id") -or [string]::IsNullOrWhiteSpace([string]$Ledger.topology.orchestrator_thread_id)) { throw "request_agent_input topology requires orchestrator_thread_id" }
        if (-not (Test-Property $Ledger.topology "worker_handoff_id") -or [string]::IsNullOrWhiteSpace([string]$Ledger.topology.worker_handoff_id)) { throw "request_agent_input topology requires worker_handoff_id" }
    }

    if (-not (Test-Property $Ledger "branch") -or [string]::IsNullOrWhiteSpace([string]$Ledger.branch)) { throw "branch is required" }
    if ([string]$Ledger.branch -eq "main") { throw "implement-plan requires a development branch, not main" }

    if (-not (Test-Property $Ledger "verification") -or $Ledger.verification.passed -ne $true) { throw "passed verification is required" }
    if (-not (Test-Property $Ledger "publish_permission")) { throw "native publish permission is required" }
    if ([string]$Ledger.publish_permission.source -notin @("request_user_input", "request_agent_input", "debug_question_mode")) { throw "publish permission source must be native/debug/request-agent evidence" }
    if ([string]$Ledger.publish_permission.source -eq "request_agent_input") {
        if (-not (Test-Property $Ledger.publish_permission "orchestrator_skill") -or [string]$Ledger.publish_permission.orchestrator_skill -ne "project:orchestrate-issues") { throw "request_agent_input publish permission requires orchestrator_skill project:orchestrate-issues" }
        if (-not (Test-Property $Ledger.publish_permission "orchestrator_thread_id") -or [string]::IsNullOrWhiteSpace([string]$Ledger.publish_permission.orchestrator_thread_id)) { throw "request_agent_input publish permission requires orchestrator_thread_id" }
    }
    if ([string]$Ledger.publish_permission.selected_action -notin @("push", "local-merge-ready", "hold")) { throw "publish permission selected_action is invalid" }

    if (Test-Property $Ledger "issue_closure_claim" -and $Ledger.issue_closure_claim -eq $true) { throw "implement-plan must not claim issue closure" }

    [pscustomobject]@{
        ok = $true
        phase = "implement-plan-ledger"
        plan_path = $planPath
        branch = [string]$Ledger.branch
        selected_mode = [string]$Ledger.topology.selected_mode
    }
}
```

- [ ] **Step 2: Add `implement-plan` scenario tests**

Create `skills/implement-plan/scripts/test-scenarios.ps1` that imports the helper and proves:

```powershell
. (Join-Path $PSScriptRoot "lib\contract.ps1")
```

Scenarios must cover:

- missing plan fails;
- `main` branch fails;
- missing native goal fails;
- inline topology passes;
- worker topology with `request_agent_input` source and `project:orchestrate-issues` ownership passes;
- worker topology with `request_agent_input` source but missing orchestrator ownership fails;
- missing publish permission fails;
- issue closure claim fails.

Use a temp repo fixture with `docs/superpowers/plans/plan.md`.

- [ ] **Step 3: Create `skills/implement-plan/SKILL.md`**

The frontmatter must be:

```yaml
---
name: implement-plan
description: Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof.
---
```

The body must include:

```markdown
# Implement Plan

Implement Plan is the non-issue execution route for approved Superpowers Project plans. It does not create issue mirrors and must not claim GitHub issue closure.

## Required Inputs

- approved plan under `docs/superpowers/plans`
- acceptance criteria
- proof oracle
- native `/goal` objective

## Execution Contract

1. Load and critically review the plan.
2. Ask native topology question when `request_user_input` is callable: inline current thread or worker worktree.
3. Use `request_agent_input` only when this thread is a worker created by `project:orchestrate-issues` and the worker handoff names the orchestrator, branch, issue or plan, reporting path, and reason for asking.
4. Activate native `/goal`.
5. Create or verify a development branch. Never implement on `main`.
6. Use `superpowers:executing-plans` or `superpowers:subagent-driven-development`.
7. Use `superpowers:test-driven-development` for feature or bug code changes unless explicitly opted out in the plan.
8. Use `superpowers:verification-before-completion` before completion claims.
9. Use `superpowers:finishing-a-development-branch` before integration.
10. Ask native publish permission before push, local merge readiness, or merge handoff.
11. Produce a merge-ready ledger accepted by `scripts/lib/contract.ps1`.
12. Route to `project:merge-changes`.
```

- [ ] **Step 4: Add metadata**

Create `skills/implement-plan/agents/openai.yaml`:

```yaml
version: 1
skills:
  implement-plan:
    default_prompt: "Use project:implement-plan when an approved Superpowers Project plan under docs/superpowers/plans should be implemented without creating a GitHub issue. Require native /goal activation, a development branch, topology selection through request_user_input when callable, request_agent_input only for workers created by project:orchestrate-issues with an explicit orchestrator handoff, Superpowers execution, verification-before-completion, finishing-a-development-branch, native publish permission, and merge-ready routing to project:merge-changes. Do not create issue mirrors or claim issue closure."
```

- [ ] **Step 5: Update workflow and write-plan routing**

In `skills/workflow/SKILL.md` and `skills/workflow/agents/openai.yaml`, add route:

```text
project:implement-plan - implement an approved plan without creating a GitHub issue.
```

In `skills/write-plan/SKILL.md`, update continuation options:

```text
- `Project Implement`: continue to `project:implement-plan` using the saved plan path.
- `Project Issue First`: continue to `project:create-issues` using the saved plan path.
- `Quick Apply`: apply a small, explicitly approved local-main change through the bundled Quick Apply gate.
- `Review First`: stop for user review before issue creation or execution.
- `Revise Plan`: continue `project:write-plan` to revise the saved plan.
- `Stop`: stop after the plan closeout.
```

Recommend `Project Implement` for branch-backed non-issue implementation and `Project Issue First` when the GitHub issue backbone is desired.

- [ ] **Step 6: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\workflow\scripts\test-scenarios.ps1
```

Expected: all pass.

- [ ] **Step 7: Commit checkpoint**

```powershell
git add skills/implement-plan skills/workflow skills/write-plan
git commit -m "feat: add implement plan execution route"
```

### Task 7: Extend Merge Changes For Non-Issue And Local Branch Modes

**Files:**

- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/lib/contract.ps1`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing merge mode scenarios**

In `skills/merge-changes/scripts/test-scenarios.ps1`, add scenarios for:

```text
premerge accepts pr-issue with issue closure policy
premerge accepts pr-no-issue with plan linkage and no issue closure expectation
premerge accepts local-branch with clean synced main, merge approval, validation, cleanup proof
premerge rejects non-issue PR that claims issue closure
premerge rejects local-branch when main is not clean synced
merge decline can route to reassess plan or brainstorm
```

- [ ] **Step 2: Extend contract helper**

In `skills/merge-changes/scripts/lib/contract.ps1`, support:

```powershell
$allowedModes = @("pr-issue", "pr-no-issue", "local-branch")
```

Required evidence by mode:

```text
pr-issue: issue mirror, PR URL, check state, merge approval, issue closure/mirror cleanup policy
pr-no-issue: source plan, PR URL, check state, merge approval, no issue closure claim
local-branch: source plan, branch name, clean synced main proof, native merge approval, validation proof, cleanup proof
```

- [ ] **Step 3: Document nested reassessment route**

In `skills/merge-changes/SKILL.md`, add:

```markdown
## Reassessment Routing

If merge approval is declined, ask native follow-up through `advanced-user-input` when callable:

- `User Review`: stop with the PR or branch evidence.
- `Reassess Plan`: route to `project:write-plan` for strict execution, testing, acceptance, or branch strategy revision.
- `Reassess Spec`: route to `project:brainstorm-spec` for loose idea or scope reassessment.

When this thread is a worker/subagent and the merge decision belongs to the orchestrator, use the `request_agent_input` protocol instead of native `request_user_input`.
```

- [ ] **Step 4: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
```

Expected: all merge mode scenarios pass.

- [ ] **Step 5: Commit checkpoint**

```powershell
git add skills/merge-changes
git commit -m "feat: support non-issue and local branch merges"
```

### Task 8: Extend Setup And Orchestration Contracts

**Files:**

- Modify: `skills/setup/SKILL.md`
- Modify: `skills/setup/agents/openai.yaml`
- Modify: `skills/setup/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `docs/agents/project-roadmap.json`
- Test: setup and orchestrate scenario scripts

- [ ] **Step 1: Add setup board scenarios**

In `skills/setup/scripts/test-scenarios.ps1`, add checks for:

```text
GitHub Project board setup contract is present
remote tracker mutation requires request_user_input when callable
PROJECT_CONTEXT records GitHub Project URL or id after setup
project-roadmap.json records board config for audit
```

- [ ] **Step 2: Add setup skill docs**

In `skills/setup/SKILL.md`, add:

```markdown
## GitHub Project Board Setup

Setup may create or verify a GitHub Project board for GitHub-linked repos after native approval. It should summarize proposed remote mutations before creating a board, adding fields, or bulk-linking issues.

Default views:

- Roadmap by milestone
- Board by status
- Ready issues
- In progress worker threads
- PR-ready waiting for merge
- Closed issues by milestone

Record the GitHub Project URL or id in `docs/superpowers/PROJECT_CONTEXT.md` and machine-auditable config in `docs/agents/project-roadmap.json`.
```

- [ ] **Step 3: Add orchestrate identity and autonomous selection scenarios**

In `skills/orchestrate-issues/scripts/test-scenarios.ps1`, add checks for:

```text
derive-worker-identity creates issue-<number>-<slug>
thread title uses Resolve #<number>: <title>
branch uses codex/issue-<number>-<slug>
evidence folder uses project-orchestrate-issue-<number>-<slug>
autonomous ready selection compares local and GitHub state
local/GitHub readiness drift routes to project:audit-project
request_agent_input is used only for worker-to-orchestrator blocking questions
```

- [ ] **Step 4: Update orchestrate skill docs**

In `skills/orchestrate-issues/SKILL.md`, add:

```markdown
## Autonomous Ready-Issue Selection

When asked to choose ready work, inspect local mirrors and GitHub issues together. Compare readiness, milestone, labels, blockers, dependency notes, proof oracle clarity, branch/worktree ownership, and parallel safety.

If local and GitHub state disagree about readiness, blockers, open/closed state, or project status, stop and route to `project:audit-project`. Do not guess.

## Worker Identity

Every worker run uses:

`issue-<number>-<slug>`

Derived names:

- app thread title: `Resolve #<number>: <issue title>`
- branch: `codex/issue-<number>-<slug>`
- worker handoff label: `issue-<number>-<slug>`
- temp evidence folder: `project-orchestrate-issue-<number>-<slug>`
```

- [ ] **Step 5: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
```

Expected: all pass.

- [ ] **Step 6: Commit checkpoint**

```powershell
git add skills/setup skills/orchestrate-issues docs/superpowers/PROJECT_CONTEXT.md docs/agents/project-roadmap.json
git commit -m "feat: harden setup board and orchestration contracts"
```

### Task 9: Add External GitHub Issue Hydration

**Files:**

- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `skills/workflow/SKILL.md`
- Modify: `skills/workflow/agents/openai.yaml`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add hydration scenario tests**

In `skills/create-issues/scripts/test-scenarios.ps1`, add scenarios:

```text
external GitHub issue with Source Plan: TBD is intake only
external GitHub issue body hydrates local mirror under docs/superpowers/issues
hydration preserves issue URL, milestone, labels, acceptance criteria, proof oracle, goal command
hydration creates or links a source plan before execution routing
execution routing is blocked until local mirror and source plan exist
```

- [ ] **Step 2: Document hydration protocol**

In `skills/create-issues/SKILL.md`, add:

```markdown
## External GitHub Issue Hydration

External GitHub issues are intake, not ready execution inputs, until they have local mirrors and source artifacts.

Protocol:

1. Read the GitHub issue body.
2. Create `docs/superpowers/issues/<number>-<slug>.md`.
3. Preserve GitHub issue URL, milestone, labels, branch policy, acceptance criteria, proof oracle, and goal command.
4. If `Source Spec` or `Source Plan` is missing or `TBD`, create a defensible source spec or plan from the issue body and repo context before execution.
5. Update the local mirror and, when appropriate, the GitHub issue body to link the new artifact.
6. Only then route to `project:resolve-issue` or `project:orchestrate-issues`.
```

- [ ] **Step 3: Update workflow routing**

In `skills/workflow/SKILL.md`, route prompts like `hydrate this GitHub issue`, `issue exists on GitHub but not locally`, or `Source Plan: TBD` to `project:create-issues`.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\workflow\scripts\test-scenarios.ps1
```

Expected: all pass.

- [ ] **Step 5: Commit checkpoint**

```powershell
git add skills/create-issues skills/workflow
git commit -m "feat: hydrate external github issues before execution"
```

### Task 10: Update Public Release And Documentation Surface

**Files:**

- Modify: `README.md`
- Modify: `.github/ISSUE_TEMPLATE/*.yml`
- Modify: `CHANGELOG.md`
- Modify: `docs/agents/issue-tracker.md`
- Modify: `docs/agents/project-roadmap.json`
- Modify: `.codex-plugin/plugin.json`
- Test: `scripts/test-superpowers-project-repo-contract.ps1`

- [ ] **Step 1: Update README prompt surface**

In `README.md`, replace old global skill examples with:

```markdown
## Skill Surface

- `project:workflow`: choose the right Superpowers Project workflow.
- `project:setup`: initialize or maintain project context, roadmap, tracker, and board setup.
- `project:audit-project`: audit drift across docs, GitHub, live sync, and tracker config.
- `project:brainstorm-spec`: shape repo-backed specs with native Q&A grilling.
- `project:write-plan`: turn an approved spec or issue mirror into an implementation plan.
- `project:create-issues`: create or hydrate GitHub issues and local issue mirrors.
- `project:implement-plan`: implement an approved plan without creating a GitHub issue.
- `project:resolve-issue`: resolve one ready issue in the current thread.
- `project:orchestrate-issues`: delegate ready issue work to worker worktree threads.
- `project:merge-changes`: merge PRs or local branches with verification and cleanup.
```

Document install:

```markdown
## Local Install

Clone the repo, then sync the plugin:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

The live plugin installs to `C:\Users\<you>\plugins\project`.
```
```

- [ ] **Step 2: Update issue templates**

In `.github/ISSUE_TEMPLATE/*.yml`, replace:

```text
Milestones plugin
docs/milestones
```

with:

```text
Superpowers Project
docs/superpowers/issues
```

- [ ] **Step 3: Update repo contract tests**

In `scripts/test-superpowers-project-repo-contract.ps1`, update expected public paths and skill names:

```text
project namespace
C:\Users\Tanner\plugins\project
project:workflow
project:implement-plan
skills/advanced-user-input
skills/implement-plan
```

- [ ] **Step 4: Prepare GitHub-only repo rename and visibility update**

Update `docs/agents/issue-tracker.md` and `docs/agents/project-roadmap.json` from the operational repository name:

```text
tannerpolley/milestones-plugin
```

to:

```text
tannerpolley/codex-superpowers-project
```

Keep the local workspace path unchanged:

```text
C:\Users\Tanner\Documents\Workspaces\Projects\milestones-plugin
```

Do not rename the local folder in this plan.

- [ ] **Step 5: Run docs contract tests before remote mutation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
rg -n "Milestones plugin|docs/milestones|plugins\\milestones|plugins/milestones" README.md .github
```

Expected: repo contract passes; `rg` returns no active public docs hits.

- [ ] **Step 6: Commit docs and metadata before remote mutation**

```powershell
git add README.md .github CHANGELOG.md .codex-plugin docs/agents scripts/test-superpowers-project-repo-contract.ps1
git commit -m "docs: update public project namespace surface"
```

- [ ] **Step 7: Rename GitHub repository only**

Verify the current remote:

```powershell
gh repo view tannerpolley/milestones-plugin --json nameWithOwner,visibility,url
```

Expected before rename: `nameWithOwner` is `tannerpolley/milestones-plugin`.

Rename the GitHub repository:

```powershell
gh repo rename -R tannerpolley/milestones-plugin codex-superpowers-project --yes
```

Update the local remote URL:

```powershell
git remote set-url origin https://github.com/tannerpolley/codex-superpowers-project.git
git remote -v
```

Expected: `origin` points to `https://github.com/tannerpolley/codex-superpowers-project.git`.

- [ ] **Step 8: Make GitHub repository public**

Verify public readiness after the rename:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
gh repo view tannerpolley/codex-superpowers-project --json nameWithOwner,visibility,url
```

Expected: validation passes and repo is still accessible.

Make the repo public:

```powershell
gh repo edit tannerpolley/codex-superpowers-project --visibility public --accept-visibility-change-consequences
```

Verify:

```powershell
gh repo view tannerpolley/codex-superpowers-project --json nameWithOwner,visibility,url
```

Expected: `visibility` is `PUBLIC`.

### Task 11: Final Validation, Live Sync, And Cleanup

**Files:**

- Modify: no source files unless validation reveals a gap.
- Test: full validation suite and live sync.

- [ ] **Step 1: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: final JSON has `"ok": true`.

- [ ] **Step 2: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected:

- live plugin root is `C:\Users\Tanner\plugins\project`;
- `deployed_user_skills` is empty;
- old repo-owned global user skills are removed or listed as already absent;
- old live plugin roots are removed or reported only after ownership checks.

- [ ] **Step 3: Verify live plugin path**

Run:

```powershell
Test-Path "$env:USERPROFILE\plugins\project\.codex-plugin\plugin.json"
Test-Path "$env:USERPROFILE\plugins\superpowers-project"
Get-ChildItem "$env:USERPROFILE\.agents\skills" -Directory |
    Where-Object Name -in @("superpowers-project","project-plan","project-resolve","project-merge","project-doctor","project-brainstorm","project-issue","project-orchestrate","project-setup") |
    Select-Object -ExpandProperty FullName
```

Expected:

- first command returns `True`;
- second command returns `False` unless cleanup was explicitly deferred;
- third command returns no paths for repo-owned old skills.

- [ ] **Step 4: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no matching leftover Codex processes under the repo.

- [ ] **Step 5: Commit final fixups if needed**

If validation required final edits:

```powershell
git add .
git commit -m "test: complete project namespace migration validation"
```

- [ ] **Step 6: Ask native publish continuation**

After final commit, ask native Q&A:

Question id: `project_plan_publish_next_step`

Prompt: `The project namespace and implementation expansion is complete locally. What should I do next?`

Options:

- `Push Now`: push `main` to `origin/main`.
- `Review First`: show summary and hold local.
- `Stop`: stop with local commit evidence.

Do not end with a prose-only pending push state when `request_user_input` is callable.

## Plan Self-Review

- Spec coverage: the four source specs are covered by namespace migration, bundled advanced input, direct plan implementation, setup/orchestration, merge modes, external issue hydration, public docs, and live sync tasks.
- Placeholder scan: no implementation step depends on `TBD`, `TODO`, `not implemented`, or vague future work.
- Naming consistency: target runtime is `project:*`; source skill directories omit redundant `project-` prefixes.
- TDD policy: every behavior task starts with scenario or contract tests before skill/script changes.
- Debug policy: `request_agent_input` is treated as a written worker-to-orchestrator protocol, not as a runtime tool or normal user-facing prompt.
- Verification policy: full repo validation, live sync validation, cleanup hook, and native publish continuation are mandatory before closeout.
