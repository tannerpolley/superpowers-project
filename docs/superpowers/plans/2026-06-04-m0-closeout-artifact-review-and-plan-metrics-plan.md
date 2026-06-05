# Closeout Artifact Review And Plan Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish enforcing the closeout artifact-review gate, findings-summary interpretation contract, and plan-metrics planning rules across the remaining Superpowers Project workflow surfaces.

**Architecture:** Treat the current repo state as partially implemented governance work, not greenfield. Preserve the shared closeout contract already present in `advanced-user-input`, `brainstorm-spec`, `write-plan`, `create-issues`, `implement-plan`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, and `audit-project`, then propagate the same explicit artifact-review and findings-summary rules into the remaining router/setup surfaces and the shared validator that should catch contract drift. Keep this as direct repo maintenance on the current branch; do not create issue mirrors for this slice.

**Tech Stack:** PowerShell 7, Markdown skill contracts, YAML skill metadata, repo validation scripts, scenario test suites, Auto Mode authorization ledger JSON, git

---

## Intake

**Source Spec:**

- `docs/superpowers/specs/2026-06-04-closeout-artifact-review-and-plan-metrics-design.md`

**Milestone Linkage:**

- `M0 - Governance`
- `M1 - Source Of Truth`

**Current Repo-State Findings:**

- `skills/advanced-user-input/SKILL.md` already defines the shared artifact-review gate, findings summary, and pre-push / pre-merge blocking rule.
- `skills/brainstorm-spec/SKILL.md`, `skills/write-plan/SKILL.md`, `skills/create-issues/SKILL.md`, `skills/implement-plan/SKILL.md`, `skills/resolve-issue/SKILL.md`, `skills/orchestrate-issues/SKILL.md`, `skills/merge-changes/SKILL.md`, and `skills/audit-project/SKILL.md` already contain explicit artifact-review closeout language.
- `skills/write-plan/SKILL.md` already contains the direct test-complete and scientific/engineering metrics gate.
- `skills/initiate-workflow/SKILL.md` still uses a summary-first closeout description instead of the full artifact-review and findings-summary contract.
- `skills/setup-project/SKILL.md` still uses a summary-first closeout description instead of the full artifact-review and findings-summary contract.
- `skills/initiate-workflow/scripts/test-scenarios.ps1`, `skills/setup-project/scripts/test-scenarios.ps1`, and `scripts/test-native-continuation-loop.ps1` do not yet enforce the stronger artifact-review contract on those remaining surfaces.

## Auto Mode Planning Authorization

- `source spec path`: `docs/superpowers/specs/2026-06-04-closeout-artifact-review-and-plan-metrics-design.md`
- `authorization ledger path`: `C:\Users\Tanner\AppData\Local\Temp\superpowers-project\auto-mode\2026-06-04-closeout-artifact-review-and-plan-metrics-authorization.json`
- `selected authority`: `bounded-auto-merge`
- `route choice`: `Project Implement`
- `route reason`: This is source-of-truth plugin maintenance in the current repository, the remaining work is narrow and locally verifiable, and no new GitHub issue mirrors are required to make the repo contract correct.
- `decision defaults used`:
  - revise the existing canonical plan instead of creating a duplicate plan artifact
  - target only the remaining router/setup contract gaps plus the shared validator coverage that should catch them
  - keep validation on targeted suites first, then full `scripts/validate.ps1`, then `scripts/sync-live.ps1 -Validate`, then the cleanup hook
  - stop outside policy if implementation reveals a broader downstream gap that requires new scope or a tracker-backed split
- `proof oracle`: targeted scenario suites, shared validator, repo validation, live-sync validation, cleanup hook
- `stop conditions inherited by downstream skills`: `missing-proof`, `dirty-unsafe-state`, `failed-validation`, `decision-outside-policy`

## Acceptance Criteria

- `initiate-workflow` explicitly requires an artifact-review gate before any closeout continuation question.
- `initiate-workflow` explicitly requires a findings summary that covers result meaning, goal impact, broader/full project-context impact, and recommended next steps.
- `setup-project` explicitly requires an artifact-review gate before any closeout continuation question.
- `setup-project` explicitly requires a findings summary that covers result meaning, goal impact, broader/full project-context impact, and recommended next steps.
- The router/setup metadata mirrors the same artifact-review and findings-summary contract.
- `scripts/test-native-continuation-loop.ps1` fails when governed skills lack the artifact-review gate or the required interpretation-summary language.
- `skills/initiate-workflow/scripts/test-scenarios.ps1` and `skills/setup-project/scripts/test-scenarios.ps1` explicitly assert the new artifact-review closeout contract.
- Existing `write-plan` test-complete and scientific/engineering metrics gate remains intact.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` passes.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` passes.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .` passes.

## Non-Goals

- Do not create a second canonical plan for the same spec.
- Do not rewrite already compliant skill contracts just for wording churn.
- Do not weaken the stricter push/merge evidence gates already implemented in `implement-plan`, `resolve-issue`, or `merge-changes`.
- Do not add GitHub issue mirrors for this governance slice.
- Do not treat a generic summary-only closeout as equivalent to the explicit artifact-review gate.
- Do not treat `tests pass` as a sufficient plan-metrics definition for future scientific or engineering work.

## File Map

- Modify: `docs/superpowers/plans/2026-06-04-m0-closeout-artifact-review-and-plan-metrics-plan.md`
- Modify: `scripts/test-native-continuation-loop.ps1`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/setup-project/scripts/test-scenarios.ps1`

## Proof Oracle

Run these commands before claiming implementation complete:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\initiate-workflow\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
git status --short --branch
```

Expected final state:

- every command exits `0`
- the router/setup skills and metadata contain the explicit artifact-review and findings-summary contract
- `scripts/test-native-continuation-loop.ps1` catches missing artifact-review closeout wording on governed skills
- `git status --short --branch` shows only intentional branch changes before commit, and a clean worktree after final commit

## Test Complete Definition

For this plan, `test complete` means all of the following are true:

- the remaining router/setup skill docs explicitly say `artifact review gate`
- those closeout sections require exact artifact paths or identifiers, rendered Markdown when appropriate, machine-readable artifact summaries when present, and a findings summary
- the findings summary language explicitly covers result meaning, active-goal impact, broader/full project-context impact, and recommended next steps
- the router/setup scenario suites prove those phrases are present
- the shared continuation validator proves those phrases are enforced across governed skills
- full repo validation and live-sync validation pass after the targeted work

Scientific or engineering numerical thresholds do not apply to this plan because the work is governance text, validator coverage, and scenario enforcement rather than a numerical model. The implementation must still preserve the future workflow contract that asks for those numbers when the project domain needs them.

## Risks And Dependencies

- `initiate-workflow` is a router rather than a heavy artifact-producing skill, so the closeout contract must be adapted carefully without inventing fake artifacts.
- `setup-project` can own GitHub board and roadmap evidence, so the artifact-review contract must stay compatible with that broader artifact surface.
- `scripts/test-native-continuation-loop.ps1` currently checks generic continuation semantics across many skills. Tightening it too broadly without matching actual compliant text will create noisy false failures.
- The current branch already has unrelated in-progress governance edits. Implementation should build on them and avoid reverting nearby work.
- Full validation is slow enough that targeted suites should go green before the full validation pass.

### Task 1: Harden `initiate-workflow` closeout into a true artifact-review gate

**Files:**
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Test: `skills/initiate-workflow/scripts/test-scenarios.ps1`

- [ ] **Step 1: Change the router closeout text from summary-only language to explicit artifact-review language**

```markdown
After routing or preparing the next project workflow, complete the artifact review gate before asking the continuation question.
Inventory every produced or materially changed artifact owned by the routing run, including saved specs, plans, issue mirrors, or route-decision evidence when present.
```

- [ ] **Step 2: Add the findings-summary interpretation contract to the router**

```markdown
The findings summary must state what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.
```

- [ ] **Step 3: Mirror the same contract in `agents/openai.yaml` and strengthen the router scenario suite**

```powershell
foreach ($needle in @(
    "artifact review gate",
    "what the agent thinks those results mean",
    "broader project context",
    "recommended next route",
    "machine-readable artifacts"
)) {
    Assert-Contains -Text $skill -Needle $needle -Reason "missing router closeout contract: $needle"
    Assert-Contains -Text $metadata -Needle $needle -Reason "missing router metadata closeout contract: $needle"
}
```

- [ ] **Step 4: Run the router scenario suite**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\initiate-workflow\scripts\test-scenarios.ps1
```

Expected: the suite exits `0` and fails if `initiate-workflow` falls back to summary-only closeout wording.

- [ ] **Step 5: Commit the router closeout hardening**

```bash
git add skills/initiate-workflow/SKILL.md skills/initiate-workflow/agents/openai.yaml skills/initiate-workflow/scripts/test-scenarios.ps1
git commit -m "Harden initiate-workflow closeout review"
```

### Task 2: Harden `setup-project` closeout into a true artifact-review gate

**Files:**
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/setup-project/scripts/test-scenarios.ps1`
- Test: `skills/setup-project/scripts/test-scenarios.ps1`

- [ ] **Step 1: Replace summary-only setup closeout wording with explicit artifact-review requirements**

```markdown
After creating, auditing, or repairing project setup, complete the artifact review gate before asking the continuation question.
Inventory every produced or materially changed artifact owned by the setup run.
```

- [ ] **Step 2: Add the full findings-summary interpretation contract to setup closeout**

```markdown
The findings summary must name the changed or verified artifacts, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.
```

- [ ] **Step 3: Require exact artifact paths, rendered Markdown handling, and machine-readable summaries in setup metadata and tests**

```powershell
foreach ($needle in @(
    "artifact review gate",
    "exact artifact paths and links",
    "rendered Markdown artifacts",
    "machine-readable artifacts",
    "broader project context",
    "recommended next route"
)) {
    Assert-Contains -Text $skill -Needle $needle -Reason "missing setup closeout contract: $needle"
    Assert-Contains -Text $metadata -Needle $needle -Reason "missing setup metadata closeout contract: $needle"
}
```

- [ ] **Step 4: Run the setup scenario suite**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup-project\scripts\test-scenarios.ps1
```

Expected: the suite exits `0` and proves `setup-project` no longer uses a weaker summary-only closeout.

- [ ] **Step 5: Commit the setup closeout hardening**

```bash
git add skills/setup-project/SKILL.md skills/setup-project/agents/openai.yaml skills/setup-project/scripts/test-scenarios.ps1
git commit -m "Harden setup-project closeout review"
```

### Task 3: Extend the shared continuation validator to catch router/setup drift

**Files:**
- Modify: `scripts/test-native-continuation-loop.ps1`
- Test: `scripts/test-native-continuation-loop.ps1`

- [ ] **Step 1: Add explicit artifact-review and findings-summary checks for governed skills**

```powershell
foreach ($needle in @(
    "artifact review gate",
    "what the agent thinks those results mean",
    "what that means for the active goal",
    "broader project context"
)) {
    Add-Check $checks "$skillName contains $needle" ($text.Contains($needle)) "$skillPath must contain closeout contract: $needle"
}
```

- [ ] **Step 2: Keep the validator scoped to active skill contracts rather than historical specs and plans**

```powershell
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
```

- [ ] **Step 3: Run the shared continuation validator**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

Expected: the validator exits `0` and fails if any governed skill omits the artifact-review or findings-summary contract.

- [ ] **Step 4: Commit the validator hardening**

```bash
git add scripts/test-native-continuation-loop.ps1
git commit -m "Enforce artifact review in continuation validator"
```

### Task 4: Run full governance validation for the revised closeout scope

**Files:**
- Modify: none expected
- Test: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Test: `skills/setup-project/scripts/test-scenarios.ps1`
- Test: `scripts/test-native-continuation-loop.ps1`
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1 -Validate`

- [ ] **Step 1: Run the targeted scenario suites and shared validator**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\initiate-workflow\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

- [ ] **Step 2: Run full repo validation and live-sync validation**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

- [ ] **Step 3: Run the required cleanup hook and inspect branch state**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
git status --short --branch
```

- [ ] **Step 4: Commit the validated plan implementation result**

```bash
git add skills/initiate-workflow skills/setup-project scripts/test-native-continuation-loop.ps1
git commit -m "Finish closeout artifact review propagation"
```
