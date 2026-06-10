# Native Q&A Continuation Recommendation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Superpowers Project native Q&A recommend progress when safe and remove routine `stale terminal label` choices from nested branch questions after the user already selected `Yes` or `Revisit`.

**Architecture:** Treat this as a skill-contract migration. First harden policy tests, then update `advanced-user-input`, project skill docs, plugin metadata prompts, and per-skill scenario tests so top-level closeouts keep `Yes / Revisit / No`, while nested Yes and Revisit menus contain only real forward or revisit routes.

**Tech Stack:** Markdown skill contracts, YAML plugin metadata, PowerShell scenario tests, repo validation scripts.

---

## Source Spec

- `docs/superpowers/specs/2026-06-04-native-qa-continuation-recommendation-design.md`

## User Decisions

- Apply the change across all active Project workflow skills.
- Nested Yes-route menus should be forward-only.
- Nested Revisit-route menus should be revisit-only.
- Do not add a routine `Back`, `Cancel`, or `stale terminal label` option to nested route menus.
- Do not update SVG or Mermaid diagrams unless validation shows the diagrams contradict the new contract.

## Acceptance Criteria

- Top-level workflow closeout questions still include `Yes`, `Revisit`, and `stale terminal option`.
- Nested questions asked after `Yes` do not include `stale terminal label`.
- Nested questions asked after `Revisit` do not include `stale terminal label`.
- `stale terminal label` is recommended only for final `Healthy? -> Done`, explicit user stop, no safe next route, or blocker states.
- Permission gates use action-specific labels such as `Decline`, `Keep Local`, or `Do Not Merge` instead of generic `stale terminal label`.
- Active `agents/openai.yaml` prompts teach the same policy as the corresponding `SKILL.md` files.
- Scenario and policy tests reject regressions.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` passes before claiming the live plugin is updated.

## Non-Goals

- Do not remove top-level stop ability.
- Do not change the core skill sequence or artifact model.
- Do not alter SVG or Mermaid layout unless a test exposes a contradiction.
- Do not create GitHub issues as part of this implementation pass.

## Task 1: Harden Global Native Q&A Policy Tests

**Files:**
- Modify: `scripts/test-advanced-user-input-policy.ps1`
- Modify: `scripts/test-native-continuation-loop.ps1`

- [ ] **Step 1: Add failing assertions for nested Yes menus**

In `scripts/test-advanced-user-input-policy.ps1`, add required policy strings for `advanced-user-input`:

```powershell
"Nested Yes-route menus must not include terminal options",
"Nested Revisit-route menus must not include terminal options",
"Recommend Yes when at least one safe forward route exists",
"Recommend terminal option only for explicit terminal, blocker, or user-requested stop states",
"Approval gates use domain-specific decline or cancel labels instead of generic terminal labels"
```

Expected result before contract edits: the test fails because these exact policy strings are missing.

- [ ] **Step 2: Add global continuation-loop assertions**

In `scripts/test-native-continuation-loop.ps1`, add required strings for every workflow skill and metadata prompt:

```powershell
'Nested Yes-route menus must not include terminal options',
'Nested Revisit-route menus must not include terminal options',
'Recommend Yes when at least one safe forward route exists',
'Recommend terminal option only for explicit terminal, blocker, or user-requested stop states'
```

Also add a forbidden scan for active skill docs and metadata:

```powershell
'Right: terminal option: break the continuation loop.'
'Right terminal label'
```

Expected result before skill edits: the test fails on nested route sections.

- [ ] **Step 3: Run the red checks**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

Expected: both tests fail for missing new policy and existing nested stop wording.

## Task 2: Update Advanced User Input Contract

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `scripts/test-advanced-user-input-policy.ps1`

- [ ] **Step 1: Revise the policy text**

In `skills/advanced-user-input/SKILL.md`, update `Sequential Branching`, `Large Option Sets`, `Continuation Gates`, and `Common Mistakes` so the contract says:

```markdown
Nested Yes-route menus must not include terminal options. They show only real forward routes.

Nested Revisit-route menus must not include terminal options. They show only real review, revise, repair, rerun, recover, or evidence-gathering routes and then return to the originating top-level gate.

Recommend Yes when at least one safe forward route exists. Recommend Revisit when evidence is incomplete, validation failed, or review/repair is the next safe action. Recommend terminal option only for explicit terminal, blocker, or user-requested stop states.

Approval gates use domain-specific decline or cancel labels instead of generic terminal labels unless the decline actually ends the workflow.
```

Remove or rewrite the current large-menu example that includes `Stop` after `Yes selected`.

- [ ] **Step 2: Align plugin metadata**

In `skills/advanced-user-input/agents/openai.yaml`, add the same nested-menu and recommendation policy to `default_prompt`.

- [ ] **Step 3: Run the policy test**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
```

Expected: policy test passes after the skill and metadata contract align.

## Task 3: Update Shared Continuation Contract Across Workflow Skills

**Files:**
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`

- [ ] **Step 1: Replace the shared continuation paragraph**

In each `SKILL.md` Native Continuation Gate section, replace the current nested-branch guidance with:

```markdown
If Yes has multiple next routes, ask a nested Yes-route question after the user selects Yes. Nested Yes-route menus must not include `stale terminal label`; they include only real forward routes. If no forward route is safe, do not ask the nested route question; return to the top-level gate with evidence or report the blocker.

If Revisit has multiple reiteration paths, ask a nested Revisit-route question after the user selects Revisit. Nested Revisit-route menus must not include `stale terminal label`; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. After the revisit action, return to the originating top-level gate.

Recommend `Yes` when at least one safe forward route exists. Recommend `Revisit` when review, repair, or missing evidence is the next safe action. Recommend `stale terminal option` only for explicit terminal, blocker, or user-requested stop states.
```

- [ ] **Step 2: Update metadata prompts**

In each `agents/openai.yaml`, add equivalent compact wording:

```text
Nested Yes-route menus must not include terminal options and should list only forward routes. Nested Revisit-route menus must not include terminal options and should list only revisit routes. Recommend Yes when a safe forward route exists; recommend terminal option only for explicit terminal, blocker, or user-requested stop states.
```

- [ ] **Step 3: Run the global continuation test**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

Expected: the test still fails until per-skill nested option lists are cleaned up in Task 4.

## Task 4: Remove Nested Stop Options From Per-Skill Route Menus

**Files:**
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/audit-project/SKILL.md`

- [ ] **Step 1: Preserve top-level stop options**

Keep the top-level closeout route in each skill:

```markdown
- Right: terminal option: break the continuation loop.
```

Only keep this in the first `project_*_next_step` closeout menu or equivalent final health gate.

- [ ] **Step 2: Remove nested stop options from Yes-route menus**

For nested menus after progress selection, remove the `Right: terminal label` line entirely. Examples:

`skills/brainstorm-spec/SKILL.md`:

```markdown
Question id: `project_brainstorm_plan_route`
Options:
- Down: `Create One Plan`: create one `$project:write-plan` from the recently generated spec.
- Left: `Multi-Spec Planning`: choose whether to create one plan from multiple specs or multiple related plans.
```

`skills/write-plan/SKILL.md`:

```markdown
Question id: `project_plan_work_route`
Options:
- Down: `Project Issue First`: continue to issue creation from the saved plan.
- Left: `Project Implement`: continue direct plan implementation without creating issue mirrors first.
```

Apply the same pattern to all nested Yes-route menus in the active workflow skills.

- [ ] **Step 3: Remove nested stop options from Revisit-route menus**

For nested menus after Revisit selection, remove the `Right: terminal label` line entirely. Examples:

```markdown
Question id: `project_brainstorm_reiteration_route`
Options:
- Down: `Revise Spec`: continue `$project:brainstorm-spec` with follow-up questions to revise the saved spec or decision summary.
- Left: `Review Or Restart`: choose whether to review the current artifact or brainstorm another idea.
```

Apply the same pattern to all nested Revisit-route menus.

- [ ] **Step 4: Keep approval gates domain-specific**

Do not remove legitimate approval labels such as `Decline`, `Keep Local`, `Do Not Merge`, `Review First`, or `Recover`. Replace generic `stale terminal label` in approval gates only when it appears as a routine continuation option rather than a real approval outcome.

- [ ] **Step 5: Run a nested-stop scan**

Run:

```powershell
rg -n "Right: `stale terminal label`: break the continuation loop|Right terminal label" skills -g SKILL.md -g openai.yaml
```

Expected: matches remain only for top-level closeout sections or test fixtures that assert the policy. Review each remaining match manually.

## Task 5: Update Scenario Tests

**Files:**
- Modify: `skills/setup-project/scripts/test-scenarios.ps1`
- Modify: `skills/brainstorm-spec/scripts/test-scenarios.ps1`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`
- Modify: `skills/audit-project/scripts/test-scenarios.ps1`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add positive assertions for new policy**

Each scenario test should assert that the skill text and metadata include:

```powershell
"Nested Yes-route menus must not include terminal options"
"Nested Revisit-route menus must not include terminal options"
"Recommend Yes when at least one safe forward route exists"
```

- [ ] **Step 2: Remove stale assertions expecting nested stop options**

Where a scenario test currently expects nested menu routes to include `Stop` or `stale terminal label`, update the assertion to expect only the real branch routes.

- [ ] **Step 3: Add skill-specific negative checks**

For each active skill, add checks that known nested question blocks do not contain `stale terminal label`. For example in `skills/write-plan/scripts/test-scenarios.ps1`, inspect the text between:

```powershell
"Question id: `project_plan_work_route`"
"Question id: `project_plan_issue_execution_route`"
```

and assert that segment does not contain:

```powershell
"stale terminal label"
```

Repeat for the nested Yes and Revisit route IDs owned by that skill.

- [ ] **Step 4: Run all scenario tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: all parser, policy, and scenario tests pass.

## Task 6: Update Public README Wording

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Clarify top-level versus nested routing**

Update the Native Q&A Workflow section so it says:

```markdown
Top-level closeouts always ask `Continue?` with `Yes`, `Revisit`, and `stale terminal option`. After `Yes`, nested route menus list only forward routes. After `Revisit`, nested route menus list only review, revision, repair, recovery, rerun, or evidence-gathering routes. terminal options are not repeated inside those nested route menus.
```

- [ ] **Step 2: Clarify recommendation behavior**

Add:

```markdown
The recommended option should be `Yes` when a safe forward route exists, `Revisit` when evidence or repair is needed, and `stale terminal option` only when the workflow is terminal, blocked, or the user has asked to stop.
```

- [ ] **Step 3: Run README-related tests**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
```

Expected: both tests pass.

## Task 7: Validate, Sync Live, And Commit

**Files:**
- Modify only files from Tasks 1-6.

- [ ] **Step 1: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: validation result has `"ok": true`.

- [ ] **Step 2: Sync the live plugin**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: source path is this repo, live plugin root is `C:\Users\Tanner\plugins\project`, and validation passes.

- [ ] **Step 3: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no leftover Codex processes under this repo.

- [ ] **Step 4: Review staged changes**

Run:

```powershell
git status --short --branch
git diff --stat
git diff -- README.md skills scripts docs/superpowers/specs/2026-06-04-native-qa-continuation-recommendation-design.md docs/superpowers/plans/2026-06-04-native-qa-continuation-recommendation-plan.md
```

Expected: changes are limited to the planned docs, skill contracts, metadata, and tests.

- [ ] **Step 5: Ask native commit/push approval**

Use `request_user_input` with:

- `Commit + Push`: commit and push to `origin/main`.
- `Commit Only`: commit locally.
- `Stop`: leave validated changes uncommitted.

If approved, commit with:

```powershell
git add -- README.md docs/superpowers/specs/2026-06-04-native-qa-continuation-recommendation-design.md docs/superpowers/plans/2026-06-04-native-qa-continuation-recommendation-plan.md scripts skills
git commit -m "Refine native QA continuation routing"
git push origin main
```

Expected: local `main` and `origin/main` point to the same commit after push.

## Plan Self-Review

- Spec coverage: all user decisions and proof candidates from the source spec map to tasks.
- Placeholder scan: no placeholders remain.
- Scope check: this is one coherent contract migration across active Project workflow skills.
- TDD policy: tests are updated before contract text and scenario docs.
- Completion policy: validation, sync-live validation, cleanup, and native commit/push approval are required before completion.
