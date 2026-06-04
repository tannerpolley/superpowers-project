# Superpowers Project Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current parallel Milestones artifact model with a Superpowers Project extension that keeps canonical artifacts under `docs/superpowers`, adds project context, GitHub issue and milestone support, Matt-style grilling, native Default-mode questions, and `/goal` issue execution.

**Architecture:** Keep Superpowers as the base workflow and turn this plugin into an extension layer. Rename the public skill surface around project workflows, move canonical artifact contracts to `docs/superpowers`, convert issue handling to local GitHub issue mirrors, and remove GoalBuddy board setup from default execution. Preserve the existing validation discipline by writing scenario tests before changing each skill contract.

**Tech Stack:** Codex plugin manifest, Codex skills, PowerShell 7 validation scripts, Markdown artifacts, GitHub CLI/fixtures, native goal tools or slash-command goal activation.

---

## Source Spec

- `docs/superpowers/specs/2026-06-02-superpowers-project-extension-design.md`

## Acceptance Criteria

- Plugin identity and README describe the extension as **Superpowers Project**, not a separate Milestones artifact system.
- Canonical project artifacts use `docs/superpowers/PROJECT_CONTEXT.md`, `docs/superpowers/specs`, `docs/superpowers/plans`, `docs/superpowers/issues`, and `docs/superpowers/milestones`.
- New canonical skills do not instruct agents to write active specs, plans, or issue mirrors under `docs/milestones`.
- `brainstorm-spec` preserves Superpowers brainstorming and Matt-style grilling, including native `request_user_input` in Default mode when callable.
- `write-plan` preserves Superpowers writing-plans structure and writes to `docs/superpowers/plans`.
- `create-issues` uses vertical-slice issue decomposition, AFK/HITL classification, blocked-by relationships, GitHub issue mirrors, labels, and milestones.
- `resolve-issue` requires native `/goal` or goal-tool proof before issue execution and does not create GoalBuddy boards.
- `audit-project` audits drift across project context, milestones, specs, plans, issue mirrors, GitHub issues, labels, and live plugin sync.
- `scripts/sync-live.ps1 -Validate` removes retired Milestones-owned skill directories from live deploy paths.
- A dummy repo scenario proves setup, spec, plan, issue mirror, GitHub fixture, and goal-required execution gates.

## File Map

- Modify: `.codex-plugin/plugin.json`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/agents/issue-tracker.md`
- Modify: `docs/agents/project-roadmap.md`
- Modify: `docs/agents/project-roadmap.json`
- Create: `docs/superpowers/PROJECT_CONTEXT.md`
- Create: `docs/superpowers/milestones/README.md`
- Create: `docs/superpowers/milestones/M0-governance.md`
- Create: `docs/superpowers/milestones/M1-source-of-truth.md`
- Create: `docs/superpowers/milestones/M2-distribution.md`
- Create: `canonical-skills/workflow/`
- Create: `canonical-skills/project-context/`
- Create: `canonical-skills/brainstorm-spec/`
- Create: `canonical-skills/write-plan/`
- Create: `canonical-skills/create-issues/`
- Modify: `canonical-skills/resolve-issue/`
- Create: `canonical-skills/audit-project/`
- Create matching plugin wrappers under `skills/<skill-name>/`
- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/validate.ps1`
- Create: `scripts/test-superpowers-project-dummy-repo.ps1`
- Delete after replacement: obsolete canonical skill folders that only serve the old Milestones artifact model
- Delete after replacement: obsolete plugin wrappers that only serve the old Milestones artifact model

## New Skill Names

Active skills after migration:

- `superpowers-project`
- `project-context`
- `brainstorm-spec`
- `write-plan`
- `create-issues`
- `resolve-issue`
- `audit-project`

Retired skill names after migration:

- `using-milestones`
- `setup-project-milestones`
- `explore-ideas`
- `milestone-writing-issue-plan`
- `convert-idea-to-issue`
- `milestones-doctor`

`resolve-issue` remains because the name now matches the desired native goal-backed execution role.

## Task 1: Establish The Superpowers Project Artifact Contract

**Files:**
- Create: `docs/superpowers/PROJECT_CONTEXT.md`
- Create: `docs/superpowers/milestones/README.md`
- Create: `docs/superpowers/milestones/M0-governance.md`
- Create: `docs/superpowers/milestones/M1-source-of-truth.md`
- Create: `docs/superpowers/milestones/M2-distribution.md`
- Modify: `docs/agents/issue-tracker.md`
- Modify: `docs/agents/project-roadmap.md`
- Modify: `docs/agents/project-roadmap.json`
- Modify: `README.md`
- Test: `scripts/validate.ps1 -SkipScenarioTests`

- [ ] **Step 1: Write the project context file**

Create `docs/superpowers/PROJECT_CONTEXT.md` with these sections:

```markdown
# Superpowers Project Context

## Durable Intent

Superpowers Project extends Superpowers with durable project context, roadmap and milestone mapping, GitHub issue and milestone linkage, native user-input grilling, and native `/goal` issue execution.

## Artifact Model

- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

## Execution Model

Issue execution uses native `/goal` or goal tools plus Superpowers execution skills. GoalBuddy boards are outside the default execution model.

## Extension Skills

- `superpowers-project`
- `project-context`
- `brainstorm-spec`
- `write-plan`
- `create-issues`
- `resolve-issue`
- `audit-project`
```

- [ ] **Step 2: Write milestone pages under `docs/superpowers/milestones`**

Create:

- `docs/superpowers/milestones/README.md`
- `docs/superpowers/milestones/M0-governance.md`
- `docs/superpowers/milestones/M1-source-of-truth.md`
- `docs/superpowers/milestones/M2-distribution.md`

Each milestone page must include:

```markdown
# <Milestone Title>

## Purpose

<durable milestone purpose>

## GitHub Milestone

- Title: `<title>`

## Related Specs

- None yet

## Related Plans

- None yet

## Related Issues

- None yet
```

- [ ] **Step 3: Update agent tracker docs to the new canonical paths**

Modify `docs/agents/issue-tracker.md` so the issue source of truth is:

```markdown
- Issue source of truth: GitHub Issues plus synced local issue mirrors under `docs/superpowers/issues/`.
- Milestones are project roadmap buckets and mirror `docs/superpowers/milestones/`.
```

Modify `docs/agents/project-roadmap.md` so it names:

```markdown
Superpowers Project is managed through `docs/superpowers/PROJECT_CONTEXT.md` and `docs/superpowers/milestones/`.

Specs:
- `docs/superpowers/specs/<YYYY-MM-DD>-<slug>-design.md`

Plans:
- `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`

Issue mirrors:
- `docs/superpowers/issues/<issue-number>-<slug>.md`
```

Modify `docs/agents/project-roadmap.json` so the templates are:

```json
{
  "tracker": "github",
  "repository": "tannerpolley/milestones-plugin",
  "project_context": "docs/superpowers/PROJECT_CONTEXT.md",
  "milestone_root": "docs/superpowers/milestones",
  "spec_file_template": "docs/superpowers/specs/<YYYY-MM-DD>-<slug>-design.md",
  "plan_file_template": "docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md",
  "issue_file_template": "docs/superpowers/issues/<issue-number>-<slug>.md",
  "issue_types": ["bug", "enhancement", "task"],
  "triage_states": ["status:triage", "status:ready", "status:blocked"],
  "forbidden_canonical_roots": ["docs/milestones/<milestone-folder>/ideas", "docs/milestones/<milestone-folder>/issues", "docs/plans", "docs/issues"]
}
```

- [ ] **Step 4: Run structural validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero.

- [ ] **Step 5: Commit the artifact contract**

Run:

```powershell
git add README.md docs/agents docs/superpowers/PROJECT_CONTEXT.md docs/superpowers/milestones
git commit -m "docs: define superpowers project artifact model"
```

## Task 2: Rename The Public Plugin Surface

**Files:**
- Modify: `.codex-plugin/plugin.json`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/validate.ps1 -SkipScenarioTests`

- [ ] **Step 1: Update plugin manifest metadata**

Modify `.codex-plugin/plugin.json`:

```json
{
  "name": "superpowers-project",
  "version": "0.2.0",
  "description": "Superpowers extension for durable project context, GitHub issues and milestones, native user-input grilling, and goal-backed execution.",
  "interface": {
    "displayName": "Superpowers Project",
    "shortDescription": "Project context, GitHub issues, milestones, and goal-backed execution for Superpowers.",
    "longDescription": "Superpowers Project extends Superpowers with large-scope project context, roadmap and milestone mapping, GitHub issue mirrors, issue triage, native request_user_input grilling, and native /goal-backed issue resolution."
  }
}
```

Keep existing author metadata unless it conflicts with the new name.

- [ ] **Step 2: Record retired skill names for live cleanup**

In `scripts/sync-live.ps1`, set:

```powershell
$retiredSkillNames = @(
    "using-milestones",
    "setup-project-milestones",
    "explore-ideas",
    "milestone-writing-issue-plan",
    "convert-idea-to-issue",
    "milestones-doctor"
)
$retiredPluginSkillNames = @(
    "using-milestones",
    "setup-project-milestones",
    "explore-ideas",
    "milestone-writing-issue-plan",
    "convert-idea-to-issue",
    "milestones-doctor"
)
```

Do not include `resolve-issue` in the retired list.

- [ ] **Step 3: Update validation to reject active old canonical paths**

In `scripts/validate.ps1`, add a check named `Superpowers project path contract` that fails if active canonical skill text instructs new specs, plans, or issue mirrors to be written under:

```text
docs/milestones/<milestone-folder>/ideas
docs/milestones/<milestone-folder>/issues
docs/plans
docs/issues
```

Allow those strings only in migration docs and retired issue files under `docs/milestones/**/issues/*.md`.

- [ ] **Step 4: Run structural validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero and includes `Superpowers project path contract`.

- [ ] **Step 5: Commit plugin rename metadata**

Run:

```powershell
git add .codex-plugin/plugin.json README.md CHANGELOG.md scripts/sync-live.ps1 scripts/validate.ps1
git commit -m "feat: rename plugin to superpowers project"
```

## Task 3: Add The Project Router And Project Context Skill

**Files:**
- Create: `canonical-skills/workflow/SKILL.md`
- Create: `canonical-skills/workflow/agents/openai.yaml`
- Create: `canonical-skills/workflow/scripts/test-scenarios.ps1`
- Create: `canonical-skills/project-context/SKILL.md`
- Create: `canonical-skills/project-context/agents/openai.yaml`
- Create: `canonical-skills/project-context/scripts/test-scenarios.ps1`
- Create: `skills/workflow/SKILL.md`
- Create: `skills/project-context/SKILL.md`
- Test: targeted scenario scripts

- [ ] **Step 1: Write failing router scenario tests**

Create `canonical-skills/workflow/scripts/test-scenarios.ps1` with assertions that `SKILL.md` contains:

```text
project-context
brainstorm-spec
write-plan
create-issues
resolve-issue
audit-project
superpowers:brainstorming
superpowers:writing-plans
superpowers:executing-plans
request_user_input
docs/superpowers
/goal
```

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\superpowers-project\scripts\test-scenarios.ps1
```

Expected: fails because the skill does not exist yet.

- [ ] **Step 2: Create `superpowers-project` skill**

Create `canonical-skills/workflow/SKILL.md` with this contract:

```markdown
---
name: workflow
description: Route Superpowers Project extension requests to project context, brainstorming, planning, issue creation, issue triage, doctor, or goal-backed resolution workflows.
---

# Superpowers Project

This skill is the router for the Superpowers Project extension. It does not replace Superpowers. It routes project-backed work to extension skills and routes method work to Superpowers skills.

## Routing

- Project setup or roadmap context: `$project-context`
- Brainstorming, specs, PRDs, or broad product/architecture design: `$project:brainstorm-spec`
- Implementation planning: `$project:write-plan`
- Issue decomposition or GitHub issue creation: `$project:create-issues`
- One issue execution: `$project:resolve-issue`
- Drift audit or migration: `$project:audit-project`

## Artifact Root

Canonical project artifacts live under `docs/superpowers`.

## Method Routing

Use Superpowers skills for method: `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:subagent-driven-development`, and `superpowers:verification-before-completion`.
```

- [ ] **Step 3: Create `project-context` skill**

Create `canonical-skills/project-context/SKILL.md` with sections:

- Purpose
- Required artifacts
- Native question policy
- Project context shape
- Milestone page shape
- GitHub tracker config
- Validation

The skill must require `docs/superpowers/PROJECT_CONTEXT.md` and `docs/superpowers/milestones/`.

- [ ] **Step 4: Create plugin wrappers**

For both new skills, create `skills/<skill-name>/SKILL.md` wrappers that point to:

```text
C:\Users\Tanner\.agents\skills\<skill-name>\SKILL.md
```

The wrapper must include:

```markdown
This plugin skill is a namespace wrapper.
Read the deployed user-level `SKILL.md` above.
Follow that skill exactly.
Treat this plugin wrapper as organization only; do not invent separate behavior here.
```

- [ ] **Step 5: Run targeted tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\project-context\scripts\test-scenarios.ps1
```

Expected: both exit zero.

- [ ] **Step 6: Commit router and context skills**

Run:

```powershell
git add canonical-skills/workflow canonical-skills/project-context skills/workflow skills/project-context
git commit -m "feat: add superpowers project routing skills"
```

## Task 4: Replace Brainstorming And Planning Adapters

**Files:**
- Create: `canonical-skills/brainstorm-spec/`
- Create: `canonical-skills/write-plan/`
- Create: `skills/brainstorm-spec/`
- Create: `skills/write-plan/`
- Delete: `canonical-skills/explore-ideas/`
- Delete: `canonical-skills/milestone-writing-issue-plan/`
- Delete: `skills/explore-ideas/`
- Delete: `skills/milestone-writing-issue-plan/`
- Test: targeted scenario scripts

- [ ] **Step 1: Write `brainstorm-spec` scenario tests**

The test must assert the skill text contains:

```text
superpowers:brainstorming
Interview me relentlessly about every aspect of this plan
request_user_input
Default mode
docs/superpowers/specs
docs/superpowers/PROJECT_CONTEXT.md
docs/superpowers/milestones
grill-with-docs
to-prd
improve-codebase-architecture
```

The test must assert the skill text does not present `docs/milestones/<milestone-folder>/ideas` as an active write target.

- [ ] **Step 2: Create `brainstorm-spec` skill**

Create `canonical-skills/brainstorm-spec/SKILL.md` as a Superpowers brainstorming adapter:

- announce that it uses Superpowers brainstorming;
- inspect project context first;
- use native `request_user_input` in Default mode when callable;
- batch independent questions;
- ask sequentially for dependent branches;
- include the grill-me sentence verbatim;
- challenge language with `CONTEXT.md`, ADRs, project context, and code reality when present;
- use `to-prd` behavior only for large product-shaped work;
- use architecture opportunity language when architecture work dominates;
- save specs to `docs/superpowers/specs`.

- [ ] **Step 3: Write `write-plan` scenario tests**

The test must assert the skill text contains:

```text
superpowers:writing-plans
docs/superpowers/plans
docs/superpowers/specs
docs/superpowers/issues
request_user_input
Interview me relentlessly about every aspect of this plan
superpowers:test-driven-development
superpowers:systematic-debugging
superpowers:verification-before-completion
```

The test must assert the skill text does not present `docs/milestones/<milestone-folder>/issues` as an active write target.

- [ ] **Step 4: Create `write-plan` skill**

Create `canonical-skills/write-plan/SKILL.md` as a Superpowers writing-plans adapter:

- preserve the Superpowers plan header exactly;
- write plans to `docs/superpowers/plans`;
- require source spec or explicit user decision to plan directly;
- include issue mirror linkage when an issue already exists;
- require proof oracle;
- use TDD for features and bugs unless the user explicitly opts out in the plan;
- use systematic debugging or diagnose discipline for bugs;
- require verification before completion.

- [ ] **Step 5: Delete retired brainstorming and planning skill folders**

Delete:

```text
canonical-skills/explore-ideas
canonical-skills/milestone-writing-issue-plan
skills/explore-ideas
skills/milestone-writing-issue-plan
```

Use git removal so deletions are tracked.

- [ ] **Step 6: Run targeted tests and quick validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\brainstorm-spec\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: all exit zero.

- [ ] **Step 7: Commit adapters**

Run:

```powershell
git add canonical-skills/brainstorm-spec canonical-skills/write-plan skills/brainstorm-spec skills/write-plan
git add -u canonical-skills/explore-ideas canonical-skills/milestone-writing-issue-plan skills/explore-ideas skills/milestone-writing-issue-plan
git commit -m "feat: add superpowers brainstorming and planning adapters"
```

## Task 5: Replace Issue Creation With Plan-To-Issue

**Files:**
- Create: `canonical-skills/create-issues/`
- Create: `skills/create-issues/`
- Delete: `canonical-skills/convert-idea-to-issue/`
- Delete: `skills/convert-idea-to-issue/`
- Test: `canonical-skills/create-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Write failing `create-issues` tests**

The scenario script must test that the skill requires:

```text
docs/superpowers/plans
docs/superpowers/specs
docs/superpowers/issues
vertical slices
AFK
HITL
Blocked by
Acceptance Criteria
GitHub Issue
GitHub Milestone
Goal Command
configured tracker vocabulary
status:ready
status:blocked
```

It must also test that bug issues require a feedback-loop or repro section.

- [ ] **Step 2: Create `create-issues` skill**

Create `canonical-skills/create-issues/SKILL.md` that borrows `to-issues` behavior:

- read source spec or plan;
- inspect project context and milestone pages;
- produce vertical issue slices;
- classify each slice as AFK or HITL;
- identify blocked-by relationships;
- ask the user to approve granularity and dependencies with native UI when callable;
- write issue mirrors to `docs/superpowers/issues`;
- create or update GitHub issues;
- apply labels and GitHub milestone;
- publish in dependency order;
- keep issue mirrors tracker-focused.

- [ ] **Step 3: Create issue mirror validation script**

Create `canonical-skills/create-issues/scripts/validate-issue-mirror.ps1` that validates:

- file path is under `docs/superpowers/issues`;
- source spec or source plan exists;
- GitHub Issue field is present or the file is explicitly pre-publication;
- GitHub Milestone field is present when milestone policy is hard;
- acceptance criteria are checkboxes;
- AFK/HITL classification is present;
- goal command is present for AFK issues.

- [ ] **Step 4: Delete retired issue creation skill folders**

Delete:

```text
canonical-skills/convert-idea-to-issue
skills/convert-idea-to-issue
```

- [ ] **Step 5: Run targeted tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: both exit zero.

- [ ] **Step 6: Commit create-issues**

Run:

```powershell
git add canonical-skills/create-issues skills/create-issues
git add -u canonical-skills/convert-idea-to-issue skills/convert-idea-to-issue
git commit -m "feat: add superpowers issue mirror generation"
```

## Task 6: Rebuild Issue Resolution Around Native Goal

**Files:**
- Modify: `canonical-skills/resolve-issue/SKILL.md`
- Modify: `canonical-skills/resolve-issue/agents/openai.yaml`
- Modify: `canonical-skills/resolve-issue/scripts/prepare-execution.ps1`
- Modify: `canonical-skills/resolve-issue/scripts/validate-setup.ps1`
- Modify: `canonical-skills/resolve-issue/scripts/preflight.ps1`
- Modify: `canonical-skills/resolve-issue/scripts/premerge.ps1`
- Modify: `canonical-skills/resolve-issue/scripts/closeout.ps1`
- Delete: `canonical-skills/resolve-issue/scripts/validate-goalbuddy-contract.mjs`
- Test: `canonical-skills/resolve-issue/scripts/test-scenarios.ps1`

- [ ] **Step 1: Write failing native-goal scenario tests**

Modify `test-scenarios.ps1` so these scenarios fail before implementation:

- issue mirror path outside `docs/superpowers/issues` blocks;
- missing source plan blocks;
- missing goal activation proof blocks;
- fake string goal proof blocks;
- GoalBuddy board path in setup ledger blocks;
- tracked GoalBuddy board files are never required;
- happy setup passes with structured native goal proof;
- happy closeout marks goal complete after merge and issue close.

- [ ] **Step 2: Update skill text**

Modify `SKILL.md` so execution state is:

```text
repo gate
issue mirror validation
source plan validation
preflight
branch setup
native goal activation
setup validation
Superpowers execution
verification
premerge
merge
issue close
goal complete
cleanup
```

The skill must say that GoalBuddy boards are outside the default execution model.

- [ ] **Step 3: Update prepare-execution**

Change `prepare-execution.ps1` to:

- read `docs/superpowers/issues/<issue>.md`;
- read linked source plan;
- create or verify an implementation branch;
- generate the exact native goal objective;
- accept structured goal proof from `get_goal`;
- write setup ledger fields for issue mirror, source plan, branch, goal id, goal objective, and proof oracle;
- not create `docs/goals`, GoalBuddy board files, or GoalBuddy state.

- [ ] **Step 4: Update validate-setup**

Change `validate-setup.ps1` to reject any setup ledger containing:

```text
goal_board_path
goalbuddy_checker
docs/goals
```

It must require:

```text
goal_activation_proof
goal_id or thread goal proof
issue_mirror
source_plan
proof_oracle
```

- [ ] **Step 5: Update premerge and closeout**

Premerge must validate:

- PR closes the linked GitHub issue;
- required checks pass or local proof policy explicitly allows no required checks;
- issue acceptance criteria in the mirror are checked or reflected in closeout proof;
- source plan verification receipts cover changed files.

Closeout must:

- close or verify closed GitHub issue;
- call native goal completion when tool support exists;
- record exact `/goal` completion evidence when slash-command flow is used;
- sync default branch;
- delete only the goal branch;
- remove local temporary scaffolding owned by the run.

- [ ] **Step 6: Run targeted tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: both exit zero.

- [ ] **Step 7: Commit native goal resolution**

Run:

```powershell
git add canonical-skills/resolve-issue
git commit -m "feat: resolve issues with native goals"
```

## Task 7: Add Project Doctor And Remove Old Milestones Workflow

**Files:**
- Create: `canonical-skills/audit-project/`
- Create: `skills/audit-project/`
- Delete: `canonical-skills/milestones-doctor/`
- Delete: `canonical-skills/setup-project-milestones/`
- Delete: `canonical-skills/using-milestones/`
- Delete: `skills/milestones-doctor/`
- Delete: `skills/setup-project-milestones/`
- Delete: `skills/using-milestones/`
- Modify: `scripts/validate.ps1`
- Test: targeted scenario scripts

- [ ] **Step 1: Write `audit-project` tests**

The scenario script must prove the doctor audits:

- `docs/superpowers/PROJECT_CONTEXT.md`;
- `docs/superpowers/milestones`;
- `docs/superpowers/specs`;
- `docs/superpowers/plans`;
- `docs/superpowers/issues`;
- GitHub issue mirror fields;
- GitHub milestone linkage;
- label vocabulary;
- retired `docs/milestones` canonical usage;
- live plugin sync drift.

- [ ] **Step 2: Create `audit-project` skill**

Create `canonical-skills/audit-project/SKILL.md` with:

- report-first behavior;
- no mutation without user approval;
- drift categories: blocking, repairable, informational, healthy;
- migration report from old Milestones paths to new Superpowers paths;
- GitHub issue/milestone/label checks;
- goal execution checks for active issue work.

- [ ] **Step 3: Delete retired setup/router/doctor folders**

Delete:

```text
canonical-skills/milestones-doctor
canonical-skills/setup-project-milestones
canonical-skills/using-milestones
skills/milestones-doctor
skills/setup-project-milestones
skills/using-milestones
```

- [ ] **Step 4: Update validate wrapper contract**

Ensure `scripts/validate.ps1` now expects wrappers exactly for:

```text
superpowers-project
project-context
brainstorm-spec
write-plan
create-issues
resolve-issue
audit-project
```

- [ ] **Step 5: Run validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: both exit zero.

- [ ] **Step 6: Commit doctor and retirement**

Run:

```powershell
git add canonical-skills/audit-project skills/audit-project scripts/validate.ps1
git add -u canonical-skills/milestones-doctor canonical-skills/setup-project-milestones canonical-skills/using-milestones
git add -u skills/milestones-doctor skills/setup-project-milestones skills/using-milestones
git commit -m "feat: add project doctor and retire milestones skills"
```

## Task 8: Add Dummy Repo End-To-End Validation

**Files:**
- Create: `scripts/test-superpowers-project-dummy-repo.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-superpowers-project-dummy-repo.ps1`

- [ ] **Step 1: Create dummy repo test script**

Create `scripts/test-superpowers-project-dummy-repo.ps1` that:

1. Creates a temporary Git repo.
2. Adds `AGENTS.md`.
3. Adds a fake GitHub remote.
4. Runs or simulates project context setup by writing `docs/superpowers/PROJECT_CONTEXT.md`.
5. Writes a sample spec under `docs/superpowers/specs`.
6. Writes a sample plan under `docs/superpowers/plans`.
7. Writes a sample issue mirror under `docs/superpowers/issues`.
8. Validates the issue mirror with the bundled validator.
9. Runs resolve setup in fixture mode.
10. Confirms missing native goal proof blocks.
11. Confirms structured native goal proof passes.
12. Confirms no `docs/goals` or GoalBuddy board files are created.

The script must output:

```json
{
  "ok": true,
  "phase": "dummy-repo",
  "checks": []
}
```

- [ ] **Step 2: Add dummy repo test to validation**

Modify `scripts/validate.ps1` to run the dummy repo test after PowerShell parser check and sync helper tests:

```powershell
$results.Add((Invoke-Step "superpowers project dummy repo" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-superpowers-project-dummy-repo.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "superpowers project dummy repo failed" }
}))
```

- [ ] **Step 3: Run dummy and structural validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: both exit zero.

- [ ] **Step 4: Commit dummy repo validation**

Run:

```powershell
git add scripts/test-superpowers-project-dummy-repo.ps1 scripts/validate.ps1
git commit -m "test: add superpowers project dummy repo validation"
```

## Task 9: Full Validation, Live Sync, And Release Docs

**Files:**
- Modify: `docs/milestones/M2-distribution/RELEASE_POLICY.md`
- Modify: `README.md`
- Test: full validation and sync

- [ ] **Step 1: Update release docs**

Update release docs to say the first release after this migration is `v0.2.0` and represents the Superpowers Project rename and artifact-model migration.

- [ ] **Step 2: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: exits zero and includes all new skill scenario tests plus the dummy repo test.

- [ ] **Step 3: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected:

- exits zero;
- deploys exactly the seven active skills;
- removes retired skill directories listed in `scripts/sync-live.ps1`;
- reports no source/live drift.

- [ ] **Step 4: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: exits zero.

- [ ] **Step 5: Commit release documentation**

Run:

```powershell
git add README.md docs/milestones/M2-distribution/RELEASE_POLICY.md
git commit -m "docs: document superpowers project release"
```

## Self-Review Checklist For Implementers

Before claiming this plan is complete, verify:

- Every active skill name has both canonical and plugin wrapper folders.
- Retired skill folders are deleted from source.
- Retired live skill folders are listed in sync-live retired arrays.
- `docs/superpowers` is the only canonical artifact root.
- `docs/milestones` appears only in migration history or release notes.
- `/goal` is mandatory for issue execution.
- GoalBuddy board creation is absent from default execution scripts.
- Dummy repo validation proves the full extension loop.
- Full validation and sync-live validation exit zero.

