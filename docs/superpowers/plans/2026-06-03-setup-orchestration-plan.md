# Project Setup And Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the next Superpowers Project workflow layer: rename `project-context` to `setup`, add a dedicated `orchestrate-issues` worker-thread route, narrow `resolve-issue` to current-thread execution, standardize issue/worktree identity, and add approved GitHub Project board setup support.

**Architecture:** Keep `skills/` as the only source root and make routing explicit: `setup` owns project infrastructure, `orchestrate-issues` owns worker-thread lifecycle, and `resolve-issue` owns direct current-thread issue execution. Scripts should validate contracts and generate ledgers, while native UI approval remains the gate for remote GitHub Project mutation and ambiguous route selection.

**Tech Stack:** Codex skill Markdown, `agents/openai.yaml` metadata, PowerShell 7 validation scripts, GitHub CLI evidence where approved, Codex native thread tools, native goal tools, and existing `scripts/validate.ps1` plus `scripts/sync-live.ps1 -Validate`.

---

## Source And Planning Decisions

**Source spec:** `docs/superpowers/specs/2026-06-03-setup-orchestration-design.md`

**Milestones:** Primary `M1 - Source Of Truth`; secondary `M0 - Governance`.

**Planning decisions selected for implementation:**

- Apply the new branch format to newly published mirrors and newly orchestrated worker runs first. Existing mirrors can keep their current branch fields until touched by a migration or issue update.
- `setup` creates or verifies a GitHub Project board only after explicit native approval. A GitHub-linked repo can be audited without creating a board.
- `orchestrate-issues` owns the native goal in the orchestrator thread for this version. Worker-owned goals can be introduced later only after the ledger model proves it can carry cross-thread goal evidence reliably.

## File Map

Create:

- `skills/orchestrate-issues/SKILL.md`: worker-thread orchestration skill.
- `skills/orchestrate-issues/agents/openai.yaml`: metadata prompt for orchestration routing.
- `skills/orchestrate-issues/scripts/test-scenarios.ps1`: contract and fixture tests for worker identity, handoff, and routing.
- `skills/orchestrate-issues/scripts/derive-worker-identity.ps1`: derives canonical issue identity, thread title, branch name, evidence folder, and PR title hints from one issue mirror.
- `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`: validates a ready issue mirror/source plan and emits the worker handoff ledger.
- `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`: verifies worker identity, branch, issue URL, source plan, proof oracle, and topology handoff evidence.
- `skills/setup/scripts/prepare-github-project-board.ps1`: creates an approval-ready GitHub Project board plan and validates post-creation board config evidence.
- `skills/setup/scripts/test-scenarios.ps1`: renamed and extended copy of the current project-context scenario script.

Rename:

- `skills/project-context/` to `skills/setup/`.

Modify:

- `.codex-plugin/plugin.json`
- `README.md`
- `CHANGELOG.md`
- `scripts/validate.ps1`
- `scripts/sync-live.ps1`
- `scripts/test-superpowers-project-repo-contract.ps1`
- `scripts/test-superpowers-project-dummy-repo.ps1`
- `skills/workflow/SKILL.md`
- `skills/workflow/agents/openai.yaml`
- `skills/workflow/scripts/test-scenarios.ps1`
- `skills/setup/SKILL.md`
- `skills/setup/agents/openai.yaml`
- `skills/create-issues/SKILL.md`
- `skills/create-issues/agents/openai.yaml`
- `skills/create-issues/scripts/validate-issue-mirror.ps1`
- `skills/create-issues/scripts/test-scenarios.ps1`
- `skills/resolve-issue/SKILL.md`
- `skills/resolve-issue/agents/openai.yaml`
- `skills/resolve-issue/scripts/prepare-execution.ps1`
- `skills/resolve-issue/scripts/validate-setup.ps1`
- `skills/resolve-issue/scripts/test-scenarios.ps1`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones/README.md`
- `docs/superpowers/milestones/M0-governance.md`
- `docs/superpowers/milestones/M1-source-of-truth.md`
- `docs/agents/project-roadmap.md`
- `docs/agents/project-roadmap.json`

Delete:

- `skills/project-context/` after the git rename is complete and `skills/setup/` passes validation.
- Live deployed `project-context` copies during `scripts/sync-live.ps1 -Validate` by adding `project-context` to the retired skill list.

## Acceptance Criteria Mapping

- Rename `project-context` to `setup`: Tasks 1, 2, 8, 9.
- Consistent orchestrator-created thread and branch names: Tasks 3, 4, 8.
- New `orchestrate-issues` skill: Tasks 3, 4, 6, 8.
- `resolve-issue` becomes direct current-thread issue execution: Tasks 5, 6, 8.
- GitHub Project board setup in `setup`: Tasks 7, 8.
- External issue hydration before execution: Tasks 6, 8.
- Native UI route selection remains standard: Tasks 4, 6, 7, 8.
- Proof oracle and sync validation: Tasks 9, 10.

## Non-Goals

- Do not keep a permanent `project-context` compatibility wrapper.
- Do not make worker orchestration the only issue-resolution route.
- Do not let worker threads merge their own PRs by default.
- Do not make GitHub Projects canonical for specs, plans, or issue mirrors.
- Do not create GoalBuddy boards or local goal board files.
- Do not publish or mutate a GitHub Project board without native approval.
- Do not migrate every old issue branch name in the same change; only enforce the new format for new mirrors and new orchestrated runs.

## Proof Oracle

Run these commands before claiming the implementation complete:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected result: every command exits `0`; `scripts/validate.ps1` emits top-level `"ok": true`; `sync-live.ps1 -Validate` removes stale deployed `project-context` copies and deploys `setup` plus `orchestrate-issues`; cleanup reports no repo-owned leftover processes.

## Tasks

### Task 1: Add Red Tests For Skill Inventory And Rename Contracts

**Files:**
- Modify: `scripts/validate.ps1`
- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`
- Modify: `skills/workflow/scripts/test-scenarios.ps1`
- Test: `scripts/validate.ps1`

- [ ] **Step 1: Write failing active-skill inventory expectations**

In `scripts/validate.ps1`, update `Get-ActiveSkillNames` so the expected skill set contains `setup` and `orchestrate-issues`, and no longer contains `project-context`.

```powershell
function Get-ActiveSkillNames {
    @(
        "superpowers-project",
        "setup",
        "brainstorm-spec",
        "write-plan",
        "create-issues",
        "resolve-issue",
        "orchestrate-issues",
        "merge-changes",
        "audit-project"
    )
}
```

Expected red state before implementation: `scripts/validate.ps1` fails with missing active skills and unexpected `project-context`.

- [ ] **Step 2: Write failing sync-live retirement expectations**

In `scripts/sync-live.ps1`, add `"project-context"` to `$retiredSkillNames`. Keep all older retired milestone-era names in that array.

```powershell
$retiredSkillNames = @(
    "using-milestones",
    "setup-project-milestones",
    "explore-ideas",
    "milestone-writing-issue-plan",
    "convert-idea-to-issue",
    "project-writing-plan",
    "plan-to-issue",
    "resolve-issue-with-goal",
    "milestones-doctor",
    "project-context"
)
```

Expected red state before implementation: sync-live validation cannot pass until `skills/setup` exists.

- [ ] **Step 3: Write failing repo contract checks**

In `scripts/test-superpowers-project-repo-contract.ps1`, update the skill loop to expect `setup` and `orchestrate-issues`.

```powershell
foreach ($skillName in @(
    "superpowers-project",
    "setup",
    "brainstorm-spec",
    "write-plan",
    "create-issues",
    "resolve-issue",
    "orchestrate-issues",
    "merge-changes",
    "audit-project"
)) {
    $skillPath = Join-Path $repoRoot "skills/$skillName/SKILL.md"
    $skillText = Get-Content -LiteralPath $skillPath -Raw
    foreach ($needle in @(
        "## Native Question Debug Mode",
        "debug_question_mode",
        "waitingOnUserInput",
        "Native Question Debug Ledger",
        "recommended-default",
        "user-provided-debug-answer",
        "Debug mode must not"
    )) {
        if (-not $skillText.Contains($needle)) {
            throw "$skillName is missing native question debug mode contract: $needle"
        }
    }
}
```

Add a focused assertion that active routing docs contain `setup` and `orchestrate-issues`, and do not contain `project-context` as an active skill route.

```powershell
Assert-TextContains -RelativePath "README.md" -Needles @(
    '$project:setup',
    '$project:orchestrate-issues'
)
$readmeText = Get-Content -LiteralPath (Join-Path $repoRoot "README.md") -Raw
if ($readmeText.Contains('$project-context')) {
    throw "README.md still lists project-context as an active skill"
}
```

- [ ] **Step 4: Write failing router scenario checks**

In `skills/workflow/scripts/test-scenarios.ps1`, change the routing contract needles to require `setup` and `orchestrate-issues`.

```powershell
foreach ($needle in @(
    'setup',
    'brainstorm-spec',
    'write-plan',
    'create-issues',
    'resolve-issue',
    'orchestrate-issues',
    'merge-changes',
    'audit-project',
    'Project Orchestrate',
    'Project Resolve',
    'Review First'
)) {
    Assert-Contains -Text $skill -Needle $needle -Reason "missing router contract: $needle"
}
```

- [ ] **Step 5: Run the red tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: failures name missing `setup`, missing `orchestrate-issues`, or stale `project-context` active routing. If failures are syntax errors, fix the tests before continuing.

- [ ] **Step 6: Commit**

```powershell
git add scripts/validate.ps1 scripts/sync-live.ps1 scripts/test-superpowers-project-repo-contract.ps1 skills/workflow/scripts/test-scenarios.ps1
git commit -m "test: define setup and orchestration skill contracts"
```

### Task 2: Rename project-context To setup

**Files:**
- Move: `skills/project-context/` to `skills/setup/`
- Modify: `skills/setup/SKILL.md`
- Modify: `skills/setup/agents/openai.yaml`
- Modify: `skills/setup/scripts/test-scenarios.ps1`
- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `docs/superpowers/milestones/README.md`
- Test: `skills/setup/scripts/test-scenarios.ps1`

- [ ] **Step 1: Move the skill directory**

Run:

```powershell
git mv skills/project-context skills/setup
```

Expected: `git status --short` shows a rename from `skills/project-context` to `skills/setup`.

- [ ] **Step 2: Update skill frontmatter and title**

In `skills/setup/SKILL.md`, replace the frontmatter and H1 with:

```markdown
---
name: setup
description: Create or maintain the Superpowers Project setup, large-context map, milestone pages, GitHub tracker configuration, GitHub Project board configuration, and roadmap artifacts under docs/superpowers.
---

# Project Setup
```

Update purpose language so it says `Project setup` establishes durable infrastructure, not only context.

- [ ] **Step 3: Rename continuation question id and options**

In `skills/setup/SKILL.md`, replace `project_context_next_step` with `project_setup_next_step` and update the prompt:

```markdown
Question id: `project_setup_next_step`

Prompt: `How should I continue from this project setup work?`
```

Keep `Project Brainstorm`, `Project Plan`, `Project Issue`, `Project Doctor`, `Review First`, and `Stop` as continuation options.

- [ ] **Step 4: Update setup metadata**

In `skills/setup/agents/openai.yaml`, use this key and prompt prefix:

```yaml
agents:
  setup:
    default_prompt: "Use $project:setup for Superpowers Project setup, adoption, large-context mapping, milestone pages, GitHub tracker configuration, GitHub Project board setup, and roadmap repair under docs/superpowers. Maintain docs/superpowers/PROJECT_CONTEXT.md, docs/superpowers/milestones, docs/agents/project-roadmap.json, and tracker configuration. Use request_user_input when callable for roadmap, milestone, GitHub, board creation, or /goal execution policy decisions. Summarize setup results, then ask native question project_setup_next_step with Project Brainstorm, Project Plan, Project Issue, Project Doctor, Review First, and Stop options, and start the selected next skill in the same turn when tools and state allow it."
```

- [ ] **Step 5: Update setup scenario script**

In `skills/setup/scripts/test-scenarios.ps1`, change the metadata checks:

```powershell
Assert-Contains -Text $metadata -Needle 'setup' -Reason "metadata missing skill name"
foreach ($needle in @(
    'GitHub Project board setup',
    'project_setup_next_step',
    'Project Brainstorm',
    'Project Plan',
    'Project Issue',
    'Project Doctor',
    'Review First',
    'Stop'
)) {
    Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing setup route: $needle"
}
```

Remove checks that require `project-context` as the metadata key.

- [ ] **Step 6: Update README and plugin manifest active skill list**

In `README.md`, replace the active skill line with:

```markdown
- `$project:setup`: creates and maintains project setup, large-context mapping, milestone pages, GitHub tracker configuration, and approved GitHub Project board setup.
```

Add:

```markdown
- `$project:orchestrate-issues`: creates and manages issue-resolution worker worktree threads while the current thread acts as orchestrator and reviewer.
```

In `.codex-plugin/plugin.json`, update `interface.defaultPrompt` entries so they mention setup and orchestration:

```json
"Set up this repo's Superpowers Project context and tracker board.",
"Orchestrate this GitHub issue in a worker worktree thread.",
"Resolve this GitHub issue directly in the current thread with a native goal."
```

- [ ] **Step 7: Update project docs**

In `docs/superpowers/PROJECT_CONTEXT.md` and `docs/superpowers/milestones/README.md`, update active skill naming so `setup` replaces `project-context` and `orchestrate-issues` is listed as the worker-thread route.

- [ ] **Step 8: Run focused green tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
```

Expected: all three commands pass, except any failures from the missing `orchestrate-issues` implementation that Task 3 will address.

- [ ] **Step 9: Commit**

```powershell
git add .codex-plugin/plugin.json README.md docs/superpowers/PROJECT_CONTEXT.md docs/superpowers/milestones/README.md skills/setup scripts/validate.ps1 scripts/sync-live.ps1 scripts/test-superpowers-project-repo-contract.ps1 skills/workflow/scripts/test-scenarios.ps1
git commit -m "feat: rename project context to project setup"
```

### Task 3: Add orchestrate-issues Skill Skeleton And Identity Tests

**Files:**
- Create: `skills/orchestrate-issues/SKILL.md`
- Create: `skills/orchestrate-issues/agents/openai.yaml`
- Create: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Create: `skills/orchestrate-issues/scripts/derive-worker-identity.ps1`
- Test: `skills/orchestrate-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Create red scenario tests for identity derivation**

Create `skills/orchestrate-issues/scripts/test-scenarios.ps1` with scenarios that require frontmatter, native question debug mode text, worker identity derivation, and worker handoff validation.

Key identity assertion:

```powershell
Invoke-Scenario "derive-worker-identity creates canonical names" {
    $repo = New-TestRepo
    $issue = Join-Path $repo "docs/superpowers/issues/10-audit-project-audit-gate.md"
    New-Item -ItemType Directory -Path (Split-Path -Parent $issue) -Force | Out-Null
    @"
# Project Doctor Audit Gate

**GitHub Issue:** https://github.com/example/repo/issues/10
**Source Plan:** docs/superpowers/plans/2026-06-03-doctor-plan.md
**Classification:** AFK
**Branch:** codex/audit-project-audit-gate

## Acceptance Criteria

- [ ] Audit gate exists

## Proof Oracle

- pwsh.exe -NoProfile -Command 'exit 0'
"@ | Set-Content -LiteralPath $issue -Encoding utf8NoBOM
    New-Item -ItemType Directory -Path (Join-Path $repo "docs/superpowers/plans") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/plans/2026-06-03-doctor-plan.md") -Value "# Plan" -Encoding utf8NoBOM

    $result = Invoke-JsonScript -ScriptName "derive-worker-identity.ps1" -Arguments @("-RepoRoot", $repo, "-IssueMirror", "docs/superpowers/issues/10-audit-project-audit-gate.md")
    Assert-True $result.ok $result.reason
    Assert-True ($result.identity.canonical_id -eq "issue-10-audit-project-audit-gate") "canonical id mismatch"
    Assert-True ($result.identity.thread_title -eq "Resolve #10: Project Doctor audit gate") "thread title mismatch"
    Assert-True ($result.identity.branch -eq "codex/issue-10-audit-project-audit-gate") "branch mismatch"
    Assert-True ($result.identity.evidence_folder -eq "orchestrate-issues-issue-10-audit-project-audit-gate") "evidence folder mismatch"
}
```

Expected red state: `derive-worker-identity.ps1` does not exist.

- [ ] **Step 2: Create the skill document**

Create `skills/orchestrate-issues/SKILL.md` with:

```markdown
---
name: orchestrate-issues
description: Use when one ready Superpowers Project issue should be resolved by a delegated Codex worktree worker thread while the current thread manages setup, monitoring, review, PR-ready evidence, and merge-changes handoff.
---

# Project Orchestrate
```

Required sections:

- Inputs
- Hard Failures
- Native Goal Policy
- Worker Identity Contract
- Worker Thread Creation Protocol
- Scripted Gates
- Monitoring And Handoff
- Native Question Debug Mode
- Native Continuation Gate

- [ ] **Step 3: Create metadata prompt**

Create `skills/orchestrate-issues/agents/openai.yaml`:

```yaml
agents:
  orchestrate-issues:
    default_prompt: "Use $project:orchestrate-issues when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread. Validate the issue mirror and source plan, create or reuse the orchestrator-owned native goal, derive one canonical worker identity with derive-worker-identity.ps1, create the worker thread from main with matching thread title and branch naming, send a topology handoff, monitor progress, collect PR-ready evidence, and route the finished PR to $project:merge-changes. Do not implement code yourself except for explicitly approved recovery edits. Use request_user_input when callable for publish, recovery, merge, or route decisions. Ask project_orchestrate_next_step after PR-ready handoff."
```

- [ ] **Step 4: Implement identity derivation script**

Create `skills/orchestrate-issues/scripts/derive-worker-identity.ps1`. It must read the issue mirror, parse issue number from the GitHub issue URL or filename, derive a slug from the filename, and output JSON.

Core output shape:

```json
{
  "ok": true,
  "phase": "derive-worker-identity",
  "reason": "worker identity derived",
  "identity": {
    "issue_number": 10,
    "issue_slug": "audit-project-audit-gate",
    "canonical_id": "issue-10-audit-project-audit-gate",
    "thread_title": "Resolve #10: Project Doctor audit gate",
    "branch": "codex/issue-10-audit-project-audit-gate",
    "worker_handoff_label": "issue-10-audit-project-audit-gate",
    "evidence_folder": "orchestrate-issues-issue-10-audit-project-audit-gate"
  }
}
```

Use the existing helper style from `skills/resolve-issue/scripts/lib/contract.ps1` rather than adding broad dependencies.

- [ ] **Step 5: Run identity tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
```

Expected: `derive-worker-identity creates canonical names` passes.

- [ ] **Step 6: Commit**

```powershell
git add skills/orchestrate-issues
git commit -m "feat: add project orchestrate identity contract"
```

### Task 4: Add Worker Handoff And Orchestrator Ledger Gates

**Files:**
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Create: `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`
- Create: `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`
- Test: `skills/orchestrate-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add red worker handoff scenarios**

Extend `skills/orchestrate-issues/scripts/test-scenarios.ps1` with a scenario that calls `prepare-worker-handoff.ps1` and then `validate-worker-handoff.ps1`.

Required handoff fields:

```powershell
foreach ($field in @(
    "issue_url",
    "issue_mirror",
    "source_plan",
    "goal_objective",
    "proof_oracle",
    "worker_identity",
    "thread_creation",
    "topology_handoff",
    "merge_owner"
)) {
    Assert-True ($handoff.PSObject.Properties.Name -contains $field) "handoff missing $field"
}
```

Expected red state: handoff scripts do not exist.

- [ ] **Step 2: Implement prepare-worker-handoff.ps1**

Create `prepare-worker-handoff.ps1` with parameters:

```powershell
param(
    [string]$RepoRoot = ".",
    [string]$IssueMirror,
    [string]$GoalProofJson,
    [string]$GoalProofPath,
    [string]$OutputDir
)
```

Behavior:

- Validate issue mirror path under `docs/superpowers/issues`.
- Validate linked source plan exists under `docs/superpowers/plans`.
- Run `derive-worker-identity.ps1`.
- Require structured native goal proof from `get_goal`.
- Emit a handoff ledger with branch `codex/issue-<number>-<slug>`.
- Include the exact worker prompt body and the immediate topology follow-up body.
- Write `worker-handoff.json` under `OutputDir` only when `OutputDir` is outside the repo.

Core handoff shape:

```json
{
  "issue_url": "https://github.com/example/repo/issues/10",
  "issue_mirror": "docs/superpowers/issues/10-audit-project-audit-gate.md",
  "source_plan": "docs/superpowers/plans/2026-06-03-doctor-plan.md",
  "goal_objective": "Resolve issue #10...",
  "proof_oracle": ["pwsh.exe -NoProfile -Command 'exit 0'"],
  "worker_identity": {
    "canonical_id": "issue-10-audit-project-audit-gate",
    "branch": "codex/issue-10-audit-project-audit-gate"
  },
  "thread_creation": {
    "starting_state": "main",
    "model_override_policy": "omit-unless-confirmed-supported"
  },
  "topology_handoff": {
    "selected_route": "delegated-worker-worktree",
    "worker_must_not_ask_topology": true
  },
  "merge_owner": "merge-changes"
}
```

- [ ] **Step 3: Implement validate-worker-handoff.ps1**

Create `validate-worker-handoff.ps1` with `-WorkerHandoffJson` and `-WorkerHandoffPath` inputs. It must reject:

- missing worker identity;
- branch not equal to `codex/<canonical_id>`;
- missing source plan;
- missing proof oracle;
- missing topology handoff;
- missing `merge_owner: merge-changes`;
- `OutputDir` paths inside the repo.

- [ ] **Step 4: Update skill document protocol**

In `skills/orchestrate-issues/SKILL.md`, require this runtime order:

1. Inspect issue mirror and source plan.
2. Check native goal state with `get_goal`.
3. Create or reuse orchestrator-owned native goal.
4. Run `derive-worker-identity.ps1`.
5. Run `prepare-worker-handoff.ps1`.
6. Create native Codex worktree thread from `main`.
7. Rename the app thread to `Resolve #<n>: <Title Case Slug>` when thread title tools are callable.
8. Send topology follow-up immediately.
9. Monitor worker and collect PR-ready evidence.
10. Route to `merge-changes`.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
```

Expected: all `orchestrate-issues` scenarios pass.

- [ ] **Step 6: Commit**

```powershell
git add skills/orchestrate-issues
git commit -m "feat: validate project orchestrator handoffs"
```

### Task 5: Narrow resolve-issue To Direct Current-Thread Resolution

**Files:**
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/prepare-execution.ps1`
- Modify: `skills/resolve-issue/scripts/validate-setup.ps1`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Test: `skills/resolve-issue/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add red resolver scenarios for direct-only route**

In `skills/resolve-issue/scripts/test-scenarios.ps1`, replace the orchestrated-worker happy-path scenario with a direct-only rejection scenario:

```powershell
Invoke-Scenario "orchestrated worker mode is owned by orchestrate-issues" {
    $result = Invoke-JsonScript -ScriptName "prepare-execution.ps1" -Arguments @(
        "-Mode", "FinalizeSetup",
        "-RepoRoot", $repo,
        "-HandoffJson", (New-Handoff),
        "-GoalProofJson", (New-GoalProof),
        "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "orchestrated-worker")
    )
    Assert-True (-not $result.ok -and $result.reason -match "orchestrate-issues") "expected worker mode to route to orchestrate-issues"
}
```

Keep inline setup and PR-ready tests.

- [ ] **Step 2: Update resolve-issue skill text**

In `skills/resolve-issue/SKILL.md`, remove the runtime topology question as a normal resolver step. Replace it with:

```markdown
## Route Boundary

`resolve-issue` is the direct current-thread route for one ready issue. It does not create worker threads. If the user wants worker-thread execution, route to `$project:orchestrate-issues` before setup.
```

State machine should begin after route selection:

1. repo gate;
2. issue mirror validation;
3. source plan validation;
4. native goal activation;
5. setup validation for direct current-thread execution;
6. worktree and branch setup in this thread;
7. Superpowers execution;
8. development branch finish;
9. PR-ready validation;
10. handoff to `merge-changes`.

- [ ] **Step 3: Update resolver metadata**

In `skills/resolve-issue/agents/openai.yaml`, say:

```yaml
default_prompt: "Use $project:resolve-issue for direct current-thread implementation of one ready Superpowers Project GitHub issue mirror with native /goal proof, TDD, verification, pushed branch, opened PR, and PR-ready handoff. Do not create worker threads from this skill; use $project:orchestrate-issues for delegated worker worktree execution."
```

Keep the existing PR-ready continuation gate wording.

- [ ] **Step 4: Update prepare-execution.ps1**

In `prepare-execution.ps1`, after `Assert-ExecutionDecision -Decision $executionDecision`, add:

```powershell
if ([string]$executionDecision.selected_mode -eq "orchestrated-worker") {
    throw "orchestrated worker execution is owned by orchestrate-issues; use resolve-issue only for direct current-thread execution"
}
```

Set `worker_handoff` and `dynamic_work_packet_map` to `$null` for all direct resolver ledgers.

- [ ] **Step 5: Update validate-setup.ps1**

In `validate-setup.ps1`, reject orchestrated-worker setup ledgers with the same route message:

```powershell
if ([string]$ledger.execution_decision.selected_mode -eq "orchestrated-worker") {
    throw "orchestrated worker execution is owned by orchestrate-issues; use resolve-issue only for direct current-thread execution"
}
```

- [ ] **Step 6: Run resolver tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
```

Expected: direct resolver scenarios pass and orchestrated-worker setup is blocked with a route-to-orchestrate-issues reason.

- [ ] **Step 7: Commit**

```powershell
git add skills/resolve-issue
git commit -m "refactor: make project resolve direct-only"
```

### Task 6: Update Router And Issue Mirror Contracts For Resolve Versus Orchestrate

**Files:**
- Modify: `skills/workflow/SKILL.md`
- Modify: `skills/workflow/agents/openai.yaml`
- Modify: `skills/workflow/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/validate-issue-mirror.ps1`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `skills/workflow/scripts/test-scenarios.ps1`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add router red tests for ambiguous resolve routing**

In `skills/workflow/scripts/test-scenarios.ps1`, add checks for:

```powershell
foreach ($needle in @(
    "Project Orchestrate",
    "Project Resolve",
    "Review First",
    "project_issue_resolution_route",
    "worker-thread implementation",
    "current-thread implementation"
)) {
    Assert-Contains -Text $skill -Needle $needle -Reason "missing resolve route decision: $needle"
    Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing resolve route decision: $needle"
}
```

- [ ] **Step 2: Update router docs**

In `skills/workflow/SKILL.md`, change routing bullets:

```markdown
- Project setup, roadmap context, tracker board setup, or large-scope project map: `$project:setup`
- Current-thread implementation of one ready issue with native `/goal` proof: `$project:resolve-issue`
- Worker-thread implementation of one ready issue: `$project:orchestrate-issues`
```

Add native route question:

```markdown
Question id: `project_issue_resolution_route`

Prompt: `How should this issue be resolved?`

Options:

- `Project Orchestrate`: use a worker worktree thread while this thread manages setup, review, and merge handoff.
- `Project Resolve`: resolve directly in this current thread.
- `Review First`: stop after showing issue context.
```

- [ ] **Step 3: Update router metadata**

In `skills/workflow/agents/openai.yaml`, mention:

```text
Route worker-thread implementation to $project:orchestrate-issues and current-thread implementation to $project:resolve-issue. When the user asks to resolve an issue without naming the route, ask native question project_issue_resolution_route with Project Orchestrate, Project Resolve, and Review First options.
```

- [ ] **Step 4: Update issue mirror branch policy for new issues**

In `skills/create-issues/SKILL.md`, change the new issue branch guidance:

```markdown
For newly published GitHub issues, prefer branch `codex/issue-<issue-number>-<slug>` after the GitHub issue number exists. Pre-publication mirrors can carry `codex/<slug>` and must be updated when the GitHub issue number is known.
```

Update `GitHub Issue Body` template:

```markdown
**Branch:** codex/issue-<issue-number>-<slug>
```

- [ ] **Step 5: Add issue validator branch warning**

In `skills/create-issues/scripts/validate-issue-mirror.ps1`, parse the `Branch` field. If the mirror has a numeric GitHub issue URL and the branch is present but does not equal `codex/issue-<number>-<slug>`, return `ok: true` with advisory evidence for migration rather than blocking existing mirrors.

Expected evidence field:

```json
{
  "branch_identity_policy": {
    "expected": "codex/issue-10-audit-project-audit-gate",
    "actual": "codex/audit-project-audit-gate",
    "severity": "advisory-existing-mirror"
  }
}
```

- [ ] **Step 6: Add create-issues scenario coverage**

In `skills/create-issues/scripts/test-scenarios.ps1`, add a happy fixture with:

```markdown
**GitHub Issue:** https://github.com/example/repo/issues/10
**Branch:** codex/issue-10-audit-project-audit-gate
```

Assert the validator returns `ok: true`.

Add an existing-mirror advisory fixture with:

```markdown
**GitHub Issue:** https://github.com/example/repo/issues/10
**Branch:** codex/audit-project-audit-gate
```

Assert the validator returns `ok: true` and evidence includes `advisory-existing-mirror`.

- [ ] **Step 7: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
```

Expected: router and issue mirror branch policy tests pass.

- [ ] **Step 8: Commit**

```powershell
git add skills/workflow skills/create-issues
git commit -m "feat: split issue routing between resolve and orchestrate"
```

### Task 7: Add GitHub Project Board Setup Gate

**Files:**
- Modify: `skills/setup/SKILL.md`
- Modify: `skills/setup/agents/openai.yaml`
- Modify: `skills/setup/scripts/test-scenarios.ps1`
- Create: `skills/setup/scripts/prepare-github-project-board.ps1`
- Modify: `docs/agents/project-roadmap.md`
- Modify: `docs/agents/project-roadmap.json`
- Test: `skills/setup/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add red project board setup scenarios**

In `skills/setup/scripts/test-scenarios.ps1`, add a scenario requiring:

- `prepare-github-project-board.ps1`;
- native question id `project_setup_github_project_board`;
- approval-required language;
- board views `Roadmap by milestone`, `Board by status`, `Ready issues`, `In progress worker threads`, `PR-ready waiting for merge`, and `Closed issues by milestone`;
- `docs/agents/project-roadmap.json` board config.

Scenario snippet:

```powershell
foreach ($needle in @(
    "project_setup_github_project_board",
    "GitHub Project board setup",
    "Roadmap by milestone",
    "Board by status",
    "Ready issues",
    "In progress worker threads",
    "PR-ready waiting for merge",
    "Closed issues by milestone",
    "native approval"
)) {
    Assert-Contains -Text $skill -Needle $needle -Reason "missing GitHub Project board setup contract: $needle"
}
```

- [ ] **Step 2: Implement prepare-github-project-board.ps1**

Create `skills/setup/scripts/prepare-github-project-board.ps1` with modes:

```powershell
param(
    [ValidateSet("Plan", "ValidateConfig")][string]$Mode = "Plan",
    [string]$RepoRoot = ".",
    [string]$ApprovalJson,
    [string]$ApprovalPath,
    [string]$ProjectConfigJson,
    [string]$ProjectConfigPath
)
```

`Plan` mode emits an approval-ready board plan and exits successfully without mutating GitHub.

`ValidateConfig` mode requires:

- approval question id `project_setup_github_project_board`;
- selected action `create-or-sync-board`;
- repository from `docs/agents/project-roadmap.json`;
- `github_project.url` or `github_project.id`;
- configured fields for milestone, status, labels, linked PR, mirror path, source spec, and source plan;
- configured views listed in the spec.

- [ ] **Step 3: Update project setup skill docs**

In `skills/setup/SKILL.md`, add:

```markdown
## GitHub Project Board Setup

When a repo is GitHub-linked, `$project:setup` can create or verify a GitHub Project board after native approval.

Question id: `project_setup_github_project_board`

Prompt: `Create or sync a GitHub Project board for this repo?`

Options:

- `Create Or Sync Board`: approve remote board setup or synchronization.
- `Record Existing Board`: record an existing GitHub Project URL or id in local config.
- `Skip Board`: keep GitHub issues and milestones without a Project board.
```

State that the board is integration metadata only, not the canonical source for specs, plans, or issue mirrors.

- [ ] **Step 4: Extend roadmap config docs**

In `docs/agents/project-roadmap.md`, add the board fields and view policy.

In `docs/agents/project-roadmap.json`, add a null-safe config shape that does not claim a board exists:

```json
"github_project": {
  "status": "not-configured",
  "url": "",
  "id": "",
  "fields": [
    "Milestone",
    "Status",
    "Labels",
    "Linked PR",
    "Mirror Path",
    "Source Spec",
    "Source Plan"
  ],
  "views": [
    "Roadmap by milestone",
    "Board by status",
    "Ready issues",
    "In progress worker threads",
    "PR-ready waiting for merge",
    "Closed issues by milestone"
  ]
}
```

- [ ] **Step 5: Run focused tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup\scripts\test-scenarios.ps1
```

Expected: setup scenarios pass and no GitHub mutation is attempted.

- [ ] **Step 6: Commit**

```powershell
git add skills/setup docs/agents/project-roadmap.md docs/agents/project-roadmap.json
git commit -m "feat: add approved github project board setup"
```

### Task 8: Add External Issue Hydration Route

**Files:**
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/SKILL.md`
- Create: `skills/create-issues/scripts/hydrate-external-issue.ps1`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `skills/orchestrate-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add red hydration scenario**

In `skills/create-issues/scripts/test-scenarios.ps1`, create a fixture issue body with a GitHub issue URL, milestone, labels, branch, acceptance criteria, proof oracle, and unresolved source plan field. Call `hydrate-external-issue.ps1` and assert it writes:

- `docs/superpowers/issues/15-flat-artifact-roots-milestone-indexes.md`;
- a source plan under `docs/superpowers/plans`;
- issue mirror fields linking the GitHub issue and source plan.

Expected red state: hydration script does not exist.

- [ ] **Step 2: Implement hydrate-external-issue.ps1**

Create `skills/create-issues/scripts/hydrate-external-issue.ps1` with:

```powershell
param(
    [string]$RepoRoot = ".",
    [string]$IssueJson,
    [string]$IssuePath,
    [string]$OutputPlanSlug,
    [switch]$AllowGitHubBodyUpdate
)
```

Behavior:

- Read `IssueJson` from `gh issue view --json number,title,url,body,labels,milestone,state` output or fixture path.
- Create a mirror path `docs/superpowers/issues/<number>-<slug>.md`.
- Preserve GitHub issue URL, title, milestone, labels, branch, acceptance criteria, proof oracle, and goal command.
- When the source plan field is unresolved, create `docs/superpowers/plans/YYYY-MM-DD-<slug>-plan.md` from the GitHub body and repo context.
- Never update GitHub unless `AllowGitHubBodyUpdate` is present and the caller separately records native approval.

- [ ] **Step 3: Update orchestrate-issues docs**

In `skills/orchestrate-issues/SKILL.md`, add `External GitHub Issue Hydration`:

```markdown
If a GitHub issue exists but no local mirror or source plan exists, route through `$project:create-issues` hydration first. Do not create a worker handoff until the mirror and source plan exist and pass the normal issue and orchestration gates.
```

- [ ] **Step 4: Run hydration tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
```

Expected: hydration scenarios pass, and orchestrate docs require hydration before worker creation.

- [ ] **Step 5: Commit**

```powershell
git add skills/create-issues skills/orchestrate-issues
git commit -m "feat: hydrate external github issues before orchestration"
```

### Task 9: Update Repo Docs, Dummy Repo, And Manifest Contracts

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `docs/superpowers/milestones/M0-governance.md`
- Modify: `docs/superpowers/milestones/M1-source-of-truth.md`
- Modify: `scripts/test-superpowers-project-dummy-repo.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`
- Test: `scripts/test-superpowers-project-dummy-repo.ps1`
- Test: `scripts/test-superpowers-project-repo-contract.ps1`

- [ ] **Step 1: Update public skill list**

In `README.md`, make `Current Skills` exactly reflect:

- `$project:workflow`
- `$project:setup`
- `$project:brainstorm-spec`
- `$project:write-plan`
- `$project:create-issues`
- `$project:resolve-issue`
- `$project:orchestrate-issues`
- `$project:merge-changes`
- `$project:audit-project`

Remove active `project-context` wording.

- [ ] **Step 2: Update plugin manifest description and prompts**

In `.codex-plugin/plugin.json`, update `interface.longDescription` to include:

```json
"Superpowers Project extends Superpowers with large-scope project setup, roadmap and milestone mapping, GitHub issue mirrors, GitHub Project board integration, issue orchestration, native request_user_input grilling, and native /goal-backed issue resolution."
```

Ensure `interface.defaultPrompt` contains setup, direct resolve, orchestration, and merge prompts.

- [ ] **Step 3: Update milestone pages**

In `docs/superpowers/milestones/M0-governance.md`, add governance success criteria for:

- orchestrator-owned goals;
- worker thread naming and branch identity;
- native approval before GitHub Project mutation.

In `docs/superpowers/milestones/M1-source-of-truth.md`, add success criteria for:

- `setup` as source-of-truth setup skill;
- GitHub Project board config recorded in `docs/agents/project-roadmap.json`;
- external issue hydration before resolve or orchestrate.

- [ ] **Step 4: Update dummy repo test**

In `scripts/test-superpowers-project-dummy-repo.ps1`, update any expected skill names or docs assertions from `project-context` to `setup`, and add a check for `orchestrate-issues` if the dummy repo asserts active skill discovery text.

- [ ] **Step 5: Run repo contract tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
```

Expected: both commands pass.

- [ ] **Step 6: Commit**

```powershell
git add README.md CHANGELOG.md .codex-plugin/plugin.json docs/superpowers/PROJECT_CONTEXT.md docs/superpowers/milestones/M0-governance.md docs/superpowers/milestones/M1-source-of-truth.md scripts/test-superpowers-project-dummy-repo.ps1 scripts/test-superpowers-project-repo-contract.ps1
git commit -m "docs: document setup and orchestration workflow"
```

### Task 10: Full Verification, Live Sync, And Closeout

**Files:**
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1`
- Test: user cleanup hook

- [ ] **Step 1: Run all focused proof commands**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
```

Expected: every command exits `0`.

- [ ] **Step 2: Run full repo validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: top-level JSON includes `"ok": true`.

- [ ] **Step 3: Sync to live install**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected:

- `setup` and `orchestrate-issues` appear in deployed plugin skills and user skills.
- `project-context` appears in removed plugin skills or removed user skills when it existed before sync.
- No tree drift remains.

- [ ] **Step 4: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no matching leftover Codex processes under this repo.

- [ ] **Step 5: Review git state**

Run:

```powershell
git status --short --branch
git log --oneline -10
```

Expected: implementation branch is clean after the final commit; recent commits match the task checkpoints.

- [ ] **Step 6: Commit final verification docs if needed**

If verification required a docs-only adjustment, commit it:

```powershell
git add README.md CHANGELOG.md docs/superpowers docs/agents
git commit -m "docs: finalize setup orchestration verification"
```

If no files changed after verification, do not create an empty commit.

## Risk And Dependency Notes

- PRs #16 and #17 may modify `audit-project`, `write-plan`, `superpowers-project`, README, and validation contracts. Before executing this plan, rebase or start from current `main` after those PRs are merged.
- Issue #10 may add `skills/audit-project/scripts/audit-project.ps1`. This plan should not duplicate Doctor audit behavior; it should only add setup/orchestrate/resolve routing and board-config audit hooks that Doctor can later inspect.
- Issue #15 may add flat artifact root validators. Keep all new specs, plans, issue mirrors, and skill files in flat canonical roots and `skills/`.
- Remote GitHub Project mutation requires native approval. Script tests should use fixture JSON and must not require network writes.
- `orchestrate-issues` depends on Codex app thread tools at runtime. Scripts should validate ledgers and handoff content; they should not attempt to fake app thread creation.

## TDD And Debug Policy

- Use `superpowers:test-driven-development` for script and scenario behavior.
- Use `superpowers:systematic-debugging` or `diagnose` if any existing validation starts failing for unclear reasons after the rename.
- Use `superpowers:verification-before-completion` before claiming the implementation complete.
- Use `superpowers:finishing-a-development-branch` before pushing the branch and opening the PR.

## Self-Review

- Save path is under `docs/superpowers/plans`.
- Source spec is named: `docs/superpowers/specs/2026-06-03-setup-orchestration-design.md`.
- Every acceptance criterion maps to at least one task in the acceptance matrix.
- Every task names exact files and exact verification commands.
- Feature work requires TDD and completion requires verification before completion.
- Bug/debug discipline is included for unclear validation failures.
- No permanent compatibility wrapper is planned for `project-context`.
- GitHub Project board setup remains approval-gated and non-canonical.

