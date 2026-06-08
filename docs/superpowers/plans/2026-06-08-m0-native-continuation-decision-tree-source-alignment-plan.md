# Native Continuation Decision Tree Source Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the actual Superpowers Project skill sources, metadata, docs, and validation tests enforce the documented native continuation decision tree and prevent agents from exiting the workflow loop by inference.

**Architecture:** Treat this as a contract-first source alignment pass. First harden validation so the known drift fails, then update active skill contracts and metadata, then reconcile docs/assets, and finally run repo validation plus live-sync validation before any live deployment.

**Tech Stack:** Markdown skill contracts, YAML skill metadata, PowerShell validators and scenario tests, README/workflow docs, local generated Auto Mode authorization ledger, git.

---

## Intake

**Source Spec:** `docs/superpowers/specs/2026-06-08-native-continuation-decision-tree-source-alignment-design.md`

**Auto Mode Authorization Ledger:** `C:\Users\Tanner\AppData\Local\Temp\superpowers-project\auto-mode\2026-06-08-native-continuation-decision-tree-source-alignment-authorization.json`

**Selected Authority:** `bounded-auto-merge`

**Route Choice:** `Project Implement`

**Route Reason:** This is source-of-truth plugin maintenance in the current repository. The work is broad across skill contracts and validators but locally verifiable, and it does not require new GitHub issue mirrors before implementation.

**Decision Defaults Used:**

- Implement as one coordinated sweep across active governed skills, metadata, docs, and validation.
- Keep the readable tree free of internal route IDs.
- Treat the developer tree as a developer/audit map unless implementation deliberately converts it into the canonical desired route-ID map.
- Use explicit top-level closeout labels `Yes`, `Revisit`, and `Stop`.
- Remove nested Stop choices after top-level `Yes` or `Revisit`.
- Keep Stop user-selectable at top-level gates but never recommended before verified final completion.
- Route directly to `project:implement-plan` after this plan because the changes are source maintenance with local proof oracles.

**Stop Conditions Inherited From Auto Mode:**

- `missing-proof`
- `dirty-unsafe-state`
- `failed-validation`
- `github-auth-failure`
- `pending-required-check`
- `decision-outside-policy`

## Milestone Linkage

- `M0 - Governance`: native continuation contract, terminal state semantics, validation hardening, and loop enforcement.
- `M1 - Source Of Truth`: source skills, metadata, docs, validation, and live install alignment.

## Acceptance Criteria

- Active governed `SKILL.md` closeout gates no longer expose `Down`, `Left`, or `Right` as user-visible route labels.
- Active governed `agents/openai.yaml` files no longer advertise old closeout route wording such as `with Down`, `Down Continue`, `Down Merge`, or `Right Stop`.
- Nested Yes-route and Revisit-route question blocks no longer contain `Right: Stop`, `Stop / Done`, or equivalent terminal wording.
- Governed skill text states that the agent must not get out of the loop by itself before a user-selected top-level Stop or verified final Done gate.
- Governed skill text treats custom review, revision, repair, evidence, route-change, or stronger-loop answers as non-terminal Revisit behavior.
- Governed skill text forbids recommending Stop before verified final completion.
- README and workflow docs use `Yes`, `Revisit`, and `Stop` for top-level closeout behavior and reserve `Done` for verified final gates.
- The readable decision tree keeps valid `Q<n>` and `A<n><letter>` labels.
- The developer decision-tree document clearly states whether it is a desired route-ID map or an audit/source-drift map.
- Validation fails if nested Stop or old direction-coded closeout labels return.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` passes before any live install sync is reported complete.
- The cleanup hook passes before closeout.

## Test Complete And Metrics

This is workflow-contract maintenance, not scientific or numerical modeling work. Numerical thresholds, units, residuals, or tolerances are not applicable.

Test complete means all of these are true:

- targeted source scans show no old direction-coded closeout labels in active governed `SKILL.md` files
- targeted metadata scans show no old direction-coded closeout wording in governed `agents/openai.yaml` files
- nested route scans show no nested terminal Stop wording after Yes/Revisit route questions
- recommendation-policy scans show no active governed text allowing Stop recommendation before verified final completion
- readable decision-tree structural checks pass
- updated scenario tests pass for all governed skills touched by the implementation
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` exits `0`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` exits `0`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .` exits `0`

## Proof Oracle

Run these commands before claiming the implementation complete:

```powershell
rg -n '^- (Down|Left|Right):' skills -g SKILL.md
rg -n 'with Down|Down Continue|Down Merge|Right Stop|Down default progress' skills -g openai.yaml
rg -n 'Right: `Stop|Right: Stop|Stop / Done|No / Stop / Done' skills README.md docs/assets docs/superpowers/closeout-startup-decision-tree*.md
rg -n 'Recommend Stop only|recommended.*Stop.*blocker|Stop.*recommended.*locally complete|Stop.*recommended.*validation passed' skills README.md docs/superpowers/closeout-startup-decision-tree*.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
git status --short --branch
```

Expected final state:

- validator and scenario commands exit `0`
- active source scans either produce no active drift hits or only documented historical/spec references outside active contracts
- `git status --short --branch` shows only intentional uncommitted work if commit/push approval has not yet been requested

## Non-Goals

- Do not edit live deployed plugin copies directly while this source repo is available.
- Do not create GitHub issues for this repair unless later route policy explicitly changes.
- Do not alter core Superpowers method pairings.
- Do not weaken final Done proof requirements.
- Do not expose internal route IDs in the non-developer readable tree.
- Do not treat a current green validation result as proof the source already matches the desired tree.

## File Map

- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `README.md`
- Modify: `docs/assets/native-qa-main-flow-mermaid.md`
- Modify: `docs/assets/native-qa-main-flow.svg`
- Modify: `docs/superpowers/closeout-startup-decision-tree.md`
- Modify: `docs/superpowers/closeout-startup-decision-tree-dev.md`
- Modify: `scripts/test-native-continuation-loop.ps1`
- Modify: `scripts/test-advanced-user-input-policy.ps1`
- Modify: `scripts/test-native-qa-svg.ps1`
- Modify: governed skill `scripts/test-scenarios.ps1` files when they assert the old contract or miss the new guardrail

## Task 1: Harden Native Continuation Validation

**Files:**
- Modify: `scripts/test-native-continuation-loop.ps1`
- Modify: governed skill `scripts/test-scenarios.ps1` files as needed

- [ ] **Step 1: Add active source scans for visible direction labels**

Update `scripts/test-native-continuation-loop.ps1` so active governed `SKILL.md` closeout sections fail when option lines start with:

```powershell
- Down:
- Left:
- Right:
```

Expected result before source edits: the validator fails on current active skill gate examples.

- [ ] **Step 2: Add nested terminal route detection**

Update the nested block scanner so any non-top-level route question fails if it contains:

```text
Right: `Stop`
Right: Stop
Stop / Done
No / Stop / Done
```

Top-level closeout gates and verified final health gates should be identified explicitly, not guessed loosely.

- [ ] **Step 3: Add metadata drift scans**

Fail active governed `agents/openai.yaml` files when they advertise old route wording such as:

```text
with Down
Down Continue
Down Merge
Right Stop
Down default progress
```

- [ ] **Step 4: Add loop non-escape and Stop recommendation assertions**

Require governed skills and metadata to include the new loop enforcement contract:

```text
the agent must not get out of the loop by itself
ending a turn after a governed workflow action is invalid
custom answers that ask for revision, review, repair, evidence, route change, or stronger loop behavior are non-terminal
must not recommend Stop before verified final completion
```

Remove active-contract language that allows Stop recommendation before final completion.

- [ ] **Step 5: Run the red validation checks**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

Expected: fails on the known active source drift.

## Task 2: Update Shared Native UI Policy

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `scripts/test-advanced-user-input-policy.ps1`

- [ ] **Step 1: Update policy text**

Revise the shared policy to state:

```text
Top-level closeout gates use Yes, Revisit, and Stop.
Nested Yes-route menus list only forward routes.
Nested Revisit-route menus list only review, revision, repair, rerun, recovery, or evidence routes.
Custom answers never terminate directly from Other.
Custom answers that request revision, review, repair, more evidence, a different route, or stronger loop behavior are Revisit behavior.
The agent must not get out of the loop by itself before Stop or verified final Done.
Stop remains selectable but must not be recommended before verified final completion.
```

- [ ] **Step 2: Update metadata**

Mirror the same compact policy in `skills/advanced-user-input/agents/openai.yaml`.

- [ ] **Step 3: Update tests**

Update `scripts/test-advanced-user-input-policy.ps1` to require the new policy and reject active text that permits Stop recommendation before verified final completion.

- [ ] **Step 4: Run the policy test**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
```

Expected: exits `0` after the shared policy and metadata align.

## Task 3: Update Active Skill Closeout Gates

**Files:**
- Modify: governed `skills/*/SKILL.md`

- [ ] **Step 1: Replace top-level option names**

In every governed top-level closeout gate, replace direction-coded options with visible labels:

```markdown
- Yes: `<route name>`: <description>
- Revisit: `<route name>`: <description>
- Stop: pause the continuation loop.
```

Use the actual skill route names as details, not as visible direction labels.

- [ ] **Step 2: Remove nested Stop options**

In every nested question after a `Yes` or `Revisit` selection, remove the terminal option. Nested menus should list only real branch choices.

Examples:

```markdown
Options:

- `Create One Plan`: create one `$superpowers-project:write-plan` from the saved spec.
- `Multi-Spec Planning`: choose how multiple specs become one or more plans.
```

```markdown
Options:

- `Review First`: show the rendered artifact and ask for follow-up confirmation.
- `Re-run Planning Grill`: run the planning grill again for the existing spec.
```

- [ ] **Step 3: Add non-escape loop wording**

Add the new loop rule to governed skills:

```text
The agent must not get out of the loop by itself. Saving an artifact, passing validation, a clean worktree, or writing a final response is not terminal before a user-selected Stop or verified final Done gate.
```

- [ ] **Step 4: Add strict Stop recommendation wording**

Replace old `Recommend Stop only...` wording with:

```text
Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Recommend Yes when a safe forward route exists. Recommend Revisit when review, repair, validation, evidence gathering, source alignment, sync, or clarification is still needed.
```

- [ ] **Step 5: Preserve final Done gates**

Keep `Done` only in verified final health gates owned by final-capable workflows such as merge closeout and healthy audit closeout.

## Task 4: Update Skill Metadata

**Files:**
- Modify: governed `skills/*/agents/openai.yaml`

- [ ] **Step 1: Remove old closeout wording**

Replace metadata phrases such as:

```text
Ask ... with Down ..., Left ..., and Right Stop
use Down default progress, Left reiteration, and Right Stop
```

with compact Yes/Revisit/Stop wording.

- [ ] **Step 2: Add nested route policy**

State that nested Yes/Revisit routes do not repeat Stop and that branch options use real route names.

- [ ] **Step 3: Add non-escape and Stop recommendation policy**

Mirror the source skill rule that the agent must not exit the loop by itself and must not recommend Stop before verified final completion.

## Task 5: Reconcile Docs And Workflow Assets

**Files:**
- Modify: `README.md`
- Modify: `docs/assets/native-qa-main-flow-mermaid.md`
- Modify: `docs/assets/native-qa-main-flow.svg`
- Modify: `docs/superpowers/closeout-startup-decision-tree.md`
- Modify: `docs/superpowers/closeout-startup-decision-tree-dev.md`
- Modify: `scripts/test-native-qa-svg.ps1`

- [ ] **Step 1: Update README stale recommendation wording**

Replace `No / Stop / Done` recommendation text with phase-specific wording:

```text
The recommended option should be Yes when a safe forward route exists and Revisit when review, repair, evidence, source alignment, validation, or clarification is still needed. Stop remains selectable for user control but should not be recommended before verified final completion. Done is reserved for verified final gates.
```

- [ ] **Step 2: Clarify the developer tree role**

Update `docs/superpowers/closeout-startup-decision-tree-dev.md` so it clearly says whether it is:

- a canonical desired route-ID map, or
- a developer audit map that records source drift and repair targets.

If it remains an audit map, label drift entries as defects to repair.

- [ ] **Step 3: Keep the readable tree structurally valid**

Maintain:

- `Q<n>` and `A<n><letter>` labels
- matching question/answer depth numbers
- color-coded question and answer spans
- no internal route IDs in the readable tree
- no nested Stop choices under Yes/Revisit route questions

- [ ] **Step 4: Update asset tests**

Extend `scripts/test-native-qa-svg.ps1` so README/SVG/Mermaid checks reject stale `No / Stop / Done` recommendation wording and old direction labels in user-facing workflow docs.

## Task 6: Update Scenario Tests

**Files:**
- Modify: governed skill `scripts/test-scenarios.ps1` files

- [ ] **Step 1: Add positive assertions**

Each governed scenario suite should assert the relevant skill and metadata contain:

```text
Nested Yes-route menus must not include Stop / Done
Nested Revisit-route menus must not include Stop / Done
the agent must not get out of the loop by itself
must not recommend Stop before verified final completion
```

- [ ] **Step 2: Add negative assertions**

Each suite should inspect its owned nested route blocks and fail on:

```text
Right: `Stop`
Right: Stop
Stop / Done
No / Stop / Done
```

- [ ] **Step 3: Run all scenario suites**

Run the governed skill scenario scripts through `scripts/validate.ps1` after targeted fixes are complete.

## Task 7: Validate, Sync Live, And Prepare Closeout

**Files:**
- Modify only files required by earlier tasks.

- [ ] **Step 1: Run targeted scans**

Run the `rg` proof oracle commands from this plan and inspect any matches.

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
```

- [ ] **Step 3: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

- [ ] **Step 4: Run live-sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

- [ ] **Step 5: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

- [ ] **Step 6: Review git state**

Run:

```powershell
git status --short --branch
git diff --stat
```

Expected: changed files match this plan's implementation surface.

## Plan Self-Review

- Source coverage: every P1 and P2 audit finding maps to tasks.
- User decision coverage: the plan includes the stricter non-escape loop rule and Stop recommendation constraint requested after the first spec revision.
- Placeholder scan: no placeholder tokens remain.
- Scope check: this is one coherent source-alignment repair across skills, metadata, docs, and validation.
- Test-complete check: success is defined by source scans, scenario tests, full validation, live-sync validation, cleanup, and git review.
