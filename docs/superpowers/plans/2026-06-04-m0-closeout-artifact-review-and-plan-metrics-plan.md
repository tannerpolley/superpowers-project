# Closeout Artifact Review And Plan Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce explicit artifact-review closeout gates, interpretation summaries, and plan metric completeness across the Superpowers Project workflow surface.

**Architecture:** Extend the existing continuation-governance model instead of inventing a separate workflow layer. Keep per-skill closeout shapes where they already exist, but harden them with one shared contract: produced artifacts must be surfaced, findings must be interpreted, and publish/integration questions must be blocked until evidence review is complete. For planning, add explicit test-complete and scientific/engineering metric questions so plan readiness is measurable rather than implied.

**Tech Stack:** PowerShell 7, Markdown skill contracts, YAML skill metadata, repo validation scripts, scenario test suites, git

---

**Source Spec:** `docs/superpowers/specs/2026-06-04-closeout-artifact-review-and-plan-metrics-design.md`

**Milestone:** `M0 - Governance`, `M1 - Source Of Truth`

**Execution Route:** `Project Implement` is the right downstream route because this is repo-owned plugin maintenance inside the source-of-truth repository and does not require new GitHub issue mirrors to be valid work.

## Acceptance Criteria

- Governed skills explicitly require an artifact-review gate before their continuation question.
- Governed skills explicitly require a findings summary that covers result meaning, goal impact, project-context impact, and recommended next steps.
- Push and merge questions are blocked until the evidence review summary has been shown.
- `write-plan` explicitly asks what counts as test complete before the plan is considered ready.
- `write-plan` explicitly asks for pass metrics, proof criteria, and scientific/engineering numerical thresholds when relevant.
- Auto Mode text and tests make it clear that these gates are inherited, not bypassed.
- Targeted scenario suites and repo validation pass.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` passes after source validation.

## Non-Goals

- Do not dump raw full-text machine-readable ledgers by default when a concise structured summary is enough.
- Do not weaken the existing push/merge strictness already added by prior governance work.
- Do not introduce a generic fallback that treats vague `tests pass` wording as a valid plan success definition.
- Do not make scientific/engineering metric prompts fire indiscriminately when the work is clearly non-numerical.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`

## Test Complete Definition

For this plan, `test complete` means all of the following are true:

- every targeted skill/test surface contains the new artifact-review and findings-summary contract language
- `write-plan` contains the new direct questions for test-complete and metric definition
- governed publish/integration skills explicitly require evidence review before push/merge decisions
- all targeted scenario suites pass
- repo-wide validation passes
- live-sync validation passes

For this specific implementation, scientific/engineering numerical success thresholds are **not applicable** because the target is governance text, routing policy, and tests, not a scientific model or numerical algorithm. The plan should still make the future scientific/engineering prompts explicit in the workflow contract.

## Risks And Dependencies

- Closeout rules are duplicated across Markdown skill files and YAML metadata; changing only one surface will leave the repo inconsistent.
- Scenario suites currently assert many exact phrases. Wording changes must be reflected in the tests deliberately rather than patched ad hoc.
- `scripts\validate.ps1` already exceeded a short timeout in live execution, so full validation should be run only after targeted suites are green and should use a larger timeout budget.
- Existing uncommitted governance edits on the current branch may overlap with this plan. Workers must read current branch state carefully and build on it instead of rewriting nearby changes.

### Task 1: Harden the shared closeout contract in common policy surfaces

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `scripts/test-advanced-user-input-policy.ps1`
- Modify: `scripts/test-native-continuation-loop.ps1`
- Test: `scripts/test-advanced-user-input-policy.ps1`
- Test: `scripts/test-native-continuation-loop.ps1`

- [ ] **Step 1: Add failing shared-policy checks for artifact review and interpretation requirements**

```powershell
foreach ($needle in @(
    "artifact review gate",
    "what the agent thinks those results mean",
    "what that means for the active goal",
    "what that means for the broader project context",
    "what next steps are now recommended"
)) {
    Add-Check $checks "policy contains $needle" ($text.Contains($needle)) "$skillPath must contain policy: $needle"
}
```

- [ ] **Step 2: Update the shared continuation policy text and metadata**

```markdown
Before any continuation question, complete an artifact review gate.
Surface every produced or materially changed artifact with exact path or identifier.
Add a findings summary that explains result meaning, goal impact, project-context impact, and recommended next steps.
```

- [ ] **Step 3: Clarify that push/merge approvals are blocked until evidence review has been shown**

```markdown
Push, publish, and merge approval questions are invalid until the closeout evidence review and findings summary have been shown.
```

- [ ] **Step 4: Run the shared-policy tests**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

Expected: both scripts exit `0` and explicitly cover the new artifact-review and findings-summary language.

- [ ] **Step 5: Commit the shared closeout policy hardening**

```bash
git add skills/advanced-user-input/SKILL.md skills/advanced-user-input/agents/openai.yaml scripts/test-advanced-user-input-policy.ps1 scripts/test-native-continuation-loop.ps1
git commit -m "Add shared artifact review closeout contract"
```

### Task 2: Update brainstorming and planning closeout contracts, including test-complete questions

**Files:**
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/scripts/test-scenarios.ps1`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Test: `skills/brainstorm-spec/scripts/test-scenarios.ps1`
- Test: `skills/write-plan/scripts/test-scenarios.ps1`

- [ ] **Step 1: Strengthen brainstorm closeout to require artifact review plus light interpretation summary**

```markdown
After saving or revising the brainstorm artifact, complete the artifact review gate, show the saved artifact, summarize the decisions made and assumptions removed, explain what the result means for the next workflow step, and recommend the next route.
```

- [ ] **Step 2: Add a planning gate for test-complete definition before plan readiness**

```markdown
Before presenting a plan as ready, ask direct questions that define:
- what counts as test complete
- what proof demonstrates that status
- what metrics define pass versus fail
- whether tolerances or edge-case thresholds matter
```

- [ ] **Step 3: Add scientific/engineering metric prompts to write-plan**

```markdown
When the project is scientific or engineering-oriented, ask for numerical metrics, thresholds, tolerances, units, and validation coverage. Record those answers in the plan acceptance criteria and proof oracle.
```

- [ ] **Step 4: Add or update scenario tests for missing test-complete / metrics coverage**

```powershell
foreach ($needle in @(
    "what counts as test complete",
    "what metrics define pass versus fail",
    "scientific or engineering",
    "numerical metrics",
    "thresholds",
    "tolerances",
    "units"
)) {
    Assert-Contains $text $needle "missing write-plan contract: $needle"
}
```

- [ ] **Step 5: Run the brainstorm and write-plan scenario suites**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
```

Expected: both suites pass, and the write-plan suite proves the new test-complete and numerical-metrics contract text exists.

- [ ] **Step 6: Commit the brainstorm/planning closeout and metrics hardening**

```bash
git add skills/brainstorm-spec/SKILL.md skills/brainstorm-spec/agents/openai.yaml skills/brainstorm-spec/scripts/test-scenarios.ps1 skills/write-plan/SKILL.md skills/write-plan/agents/openai.yaml skills/write-plan/scripts/test-scenarios.ps1
git commit -m "Add artifact review and plan metric gates"
```

### Task 3: Align non-merge project skills with the new artifact-review summary contract

**Files:**
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/audit-project/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Test: `skills/audit-project/scripts/test-scenarios.ps1`
- Test: `skills/create-issues/scripts/test-scenarios.ps1`
- Test: `skills/orchestrate-issues/scripts/test-scenarios.ps1`

- [ ] **Step 1: Require full artifact review inventories in audit-project, create-issues, and orchestrate-issues**

```markdown
Summaries must inventory every produced or materially changed artifact, not only rendered Markdown outputs.
```

- [ ] **Step 2: Add findings-summary wording to those closeout sections**

```markdown
The summary must state what the results mean, what they imply for the active goal, what they imply for the broader project context, and the recommended next steps.
```

- [ ] **Step 3: Extend the metadata and scenario checks to enforce the new phrases**

```powershell
foreach ($needle in @(
    "artifact review gate",
    "project context",
    "recommended next steps"
)) {
    Assert-Contains $text $needle "missing closeout summary contract: $needle"
}
```

- [ ] **Step 4: Run the three scenario suites**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
```

Expected: all three suites pass and explicitly assert the stronger artifact-review and interpretation-summary closeout language.

- [ ] **Step 5: Commit the non-merge closeout contract alignment**

```bash
git add skills/audit-project/SKILL.md skills/audit-project/agents/openai.yaml skills/audit-project/scripts/test-scenarios.ps1 skills/create-issues/SKILL.md skills/create-issues/agents/openai.yaml skills/create-issues/scripts/test-scenarios.ps1 skills/orchestrate-issues/SKILL.md skills/orchestrate-issues/agents/openai.yaml skills/orchestrate-issues/scripts/test-scenarios.ps1
git commit -m "Align project skill closeout summaries"
```

### Task 4: Enforce strict evidence review before push and merge decisions

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `skills/implement-plan/scripts/test-scenarios.ps1`
- Test: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add explicit evidence-review blocking language before push and merge questions**

```markdown
Before asking push or merge questions, complete the artifact review gate, show verification evidence, and provide the findings summary. Do not ask for approval first and explain later.
```

- [ ] **Step 2: Require execution closeout summaries to include readiness interpretation**

```markdown
State whether the branch, PR, or merge evidence is actually ready, what that judgment is based on, and which next step is recommended.
```

- [ ] **Step 3: Extend scenario checks for pre-approval summary language**

```powershell
foreach ($needle in @(
    "Before asking push or merge questions",
    "verification evidence",
    "what that means for the active goal",
    "recommended next steps"
)) {
    Assert-Contains $text $needle "missing execution closeout contract: $needle"
}
```

- [ ] **Step 4: Run the publish/integration scenario suites**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
```

Expected: all three suites pass and confirm that push/merge approval language is downstream of evidence review.

- [ ] **Step 5: Commit the push/merge evidence-review hardening**

```bash
git add skills/implement-plan/SKILL.md skills/implement-plan/agents/openai.yaml skills/implement-plan/scripts/test-scenarios.ps1 skills/resolve-issue/SKILL.md skills/resolve-issue/agents/openai.yaml skills/resolve-issue/scripts/test-scenarios.ps1 skills/merge-changes/SKILL.md skills/merge-changes/agents/openai.yaml skills/merge-changes/scripts/test-scenarios.ps1
git commit -m "Require evidence review before push and merge approval"
```

### Task 5: Run full validation, live-sync validation, and branch hygiene

**Files:**
- Modify: `scripts/validate.ps1` only if the new tests are not already covered
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1`

- [ ] **Step 1: Confirm repo validation covers the new skill/test surfaces**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: repo validation passes. If it times out at short tool limits, rerun with a larger timeout after all targeted suites are already green.

- [ ] **Step 2: Run live-sync validation**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: live-sync validation passes and proves the source repo plus deployed copy agree on the hardened contract.

- [ ] **Step 3: Run the repo cleanup hook before closeout**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

- [ ] **Step 4: Commit the validation alignment if any coverage script changed**

```bash
git add scripts/validate.ps1
git commit -m "Update validation coverage for closeout artifact review rules"
```

## Plan Self-Review

1. **Source linkage:** The plan directly implements `docs/superpowers/specs/2026-06-04-closeout-artifact-review-and-plan-metrics-design.md`.
2. **Acceptance mapping:** Every acceptance criterion maps to at least one task and one test surface.
3. **Exact verification:** Each task names exact files and exact commands rather than generic "verify" wording.
4. **Test completeness:** The plan explicitly defines what counts as test complete for this governance work and states why scientific numerical metrics are not applicable to this specific implementation.
5. **Execution fit:** `Project Implement` is the correct downstream route because the work is source-repo maintenance rather than issue-backed product delivery.
