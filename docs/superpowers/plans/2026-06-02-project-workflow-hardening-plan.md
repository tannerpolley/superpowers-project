# Project Workflow Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden Superpowers Project workflow contracts so native UI continuations, ledgers, GitHub checks, closed issue mirrors, ignored files, Doctor drift audits, and quick local-main work are reliable and validated.

**Architecture:** Keep the existing skill split: `$project-brainstorm` designs, `$project-plan` plans and can route to Quick Apply, `$project-issue` publishes tracker work, `$project-resolve` implements one issue, `$project-merge` integrates PRs, and `$project-doctor` audits drift. Add small PowerShell gates and shared helpers where they prevent contract drift, while keeping existing gate scripts authoritative.

**Tech Stack:** Codex skill Markdown/YAML, PowerShell 7 validation scripts, JSON ledgers, Git/GitHub CLI evidence, native `request_user_input`, `docs/superpowers` artifacts, and existing repo validation through `scripts/validate.ps1` plus `scripts/sync-live.ps1 -Validate`.

---

## Source And Decisions

**Source spec:** `docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md`

**Planning decision evidence:**

- Spec shape: one cohesive workflow-hardening spec.
- Quick path policy: guarded local `main`.
- Closed mirror policy: delete mirrors by default after verified issue closure.
- Continuation policy: every Superpowers Project skill must conclude with a native continuation question when `request_user_input` is callable, and the closeout response must summarize the artifact or result in chat.
- Quick Apply enforcement: bundled script.
- Ledger storage: temp by default, with selected final ledgers copied into handoff evidence when useful.
- Closed milestone record: milestone pages keep concise closed issue summaries and GitHub issue/PR links.
- GitHub check normalization: shared script library.

## Acceptance Criteria

- [ ] Every Superpowers Project skill documents a native closeout continuation gate with stop/review and relevant next routes.
- [ ] `$project-brainstorm` requires an in-chat spec summary and native `Project Plan`, `Review First`, `Revise Spec` continuation question.
- [ ] `$project-plan` includes `Quick Apply`, `Review First`, and `Revise Plan` in `project_plan_next_step`.
- [ ] Quick Apply has a bundled gate script that blocks dirty, unsynced, non-main, missing approval, missing verification, or missing cleanup states.
- [ ] Skill docs cannot drift from exposed PowerShell script parameters without `scripts/validate.ps1` failing.
- [ ] Resolve and merge ledger helpers generate setup, PR-ready, premerge, and closeout evidence from local/GitHub inputs without hand-authored JSON.
- [ ] GitHub check state normalization is shared and treats skipped checks consistently.
- [ ] `$project-merge` closeout records mirror deletion or explicit retention evidence for closed issues.
- [ ] `$project-doctor` has a scripted audit for milestone, mirror, GitHub tracker, label, live sync, native UI, and ignored-path drift.
- [ ] Local ignore traps are detected before structure files are assumed to be tracked.
- [ ] Full repo validation and live sync validation pass.

## File Map

Create:

- `scripts/lib/github-checks.ps1`: shared GitHub check-state normalization.
- `scripts/lib/git-ignore.ps1`: ignored-path detection helper.
- `scripts/validate-skill-script-contract.ps1`: skill docs vs script parameter contract.
- `scripts/test-github-checks.ps1`: shared check normalization scenarios.
- `scripts/test-git-ignore-traps.ps1`: ignored-path scenarios.
- `skills/project-plan/scripts/validate-quick-apply.ps1`: Quick Apply gate.
- `skills/project-resolve/scripts/collect-pr-ready-ledger.ps1`: PR-ready ledger generator.
- `skills/project-merge/scripts/collect-premerge-ledger.ps1`: premerge evidence generator.
- `skills/project-merge/scripts/collect-closeout-ledger.ps1`: closeout ledger generator.
- `skills/project-doctor/scripts/audit-project.ps1`: structured Doctor audit.

Modify:

- `scripts/validate.ps1`
- `scripts/test-superpowers-project-dummy-repo.ps1`
- `scripts/test-superpowers-project-repo-contract.ps1`
- `skills/superpowers-project/SKILL.md`
- `skills/superpowers-project/agents/openai.yaml`
- `skills/superpowers-project/scripts/test-scenarios.ps1`
- `skills/project-context/SKILL.md`
- `skills/project-context/agents/openai.yaml`
- `skills/project-context/scripts/test-scenarios.ps1`
- `skills/project-brainstorm/SKILL.md`
- `skills/project-brainstorm/agents/openai.yaml`
- `skills/project-brainstorm/scripts/test-scenarios.ps1`
- `skills/project-plan/SKILL.md`
- `skills/project-plan/agents/openai.yaml`
- `skills/project-plan/scripts/test-scenarios.ps1`
- `skills/project-issue/SKILL.md`
- `skills/project-issue/agents/openai.yaml`
- `skills/project-issue/scripts/test-scenarios.ps1`
- `skills/project-resolve/SKILL.md`
- `skills/project-resolve/agents/openai.yaml`
- `skills/project-resolve/scripts/lib/contract.ps1`
- `skills/project-resolve/scripts/test-scenarios.ps1`
- `skills/project-resolve/scripts/validate-pr-ready.ps1`
- `skills/project-merge/SKILL.md`
- `skills/project-merge/agents/openai.yaml`
- `skills/project-merge/scripts/lib/contract.ps1`
- `skills/project-merge/scripts/premerge.ps1`
- `skills/project-merge/scripts/closeout.ps1`
- `skills/project-merge/scripts/test-scenarios.ps1`
- `skills/project-doctor/SKILL.md`
- `skills/project-doctor/agents/openai.yaml`
- `skills/project-doctor/scripts/test-scenarios.ps1`
- `docs/superpowers/issues/README.md`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `README.md`

Test:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-script-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-github-checks.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-git-ignore-traps.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`

## Non-Goals

- Do not add GoalBuddy boards or `docs/goals`.
- Do not replace `$project-issue`, `$project-resolve`, or `$project-merge`.
- Do not skip native merge approval.
- Do not make Quick Apply available for risky or multi-issue implementation work.
- Do not write generated ledgers into the repo by default.
- Do not let `$project-doctor` mutate docs or tracker state without native repair approval.

## Task 1: Enforce Native Continuation Closeout Across Skills

**Files:**

- Modify: `skills/superpowers-project/SKILL.md`
- Modify: `skills/superpowers-project/agents/openai.yaml`
- Modify: `skills/superpowers-project/scripts/test-scenarios.ps1`
- Modify: `skills/project-context/SKILL.md`
- Modify: `skills/project-context/agents/openai.yaml`
- Modify: `skills/project-context/scripts/test-scenarios.ps1`
- Modify: `skills/project-brainstorm/SKILL.md`
- Modify: `skills/project-brainstorm/agents/openai.yaml`
- Modify: `skills/project-brainstorm/scripts/test-scenarios.ps1`
- Modify: `skills/project-plan/SKILL.md`
- Modify: `skills/project-plan/agents/openai.yaml`
- Modify: `skills/project-plan/scripts/test-scenarios.ps1`
- Modify: `skills/project-issue/SKILL.md`
- Modify: `skills/project-issue/agents/openai.yaml`
- Modify: `skills/project-issue/scripts/test-scenarios.ps1`
- Modify: `skills/project-resolve/SKILL.md`
- Modify: `skills/project-resolve/agents/openai.yaml`
- Modify: `skills/project-resolve/scripts/test-scenarios.ps1`
- Modify: `skills/project-merge/SKILL.md`
- Modify: `skills/project-merge/agents/openai.yaml`
- Modify: `skills/project-merge/scripts/test-scenarios.ps1`
- Modify: `skills/project-doctor/SKILL.md`
- Modify: `skills/project-doctor/agents/openai.yaml`
- Modify: `skills/project-doctor/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing continuation-closeout scenario tests**

Add scenario assertions requiring each skill to contain:

```powershell
"Native Continuation Gate",
"summarize",
"Review First",
"stop",
"request_user_input",
"start the selected next skill"
```

Add skill-specific question id and option needles:

- `$project-brainstorm`: `project_brainstorm_next_step`, `Project Plan`, `Review First`, `Revise Spec`
- `$project-context`: `project_context_next_step`, `Project Brainstorm`, `Project Plan`, `Project Issue`, `Project Doctor`, `Stop`
- `$project-plan`: `project_plan_next_step`, `Project Issue First`, `Quick Apply`, `Review First`, `Revise Plan`
- `$project-issue`: `project_issue_next_step`, `Resolve First Ready`, `Resolve Selected`, `Review First`, `Stop`
- `$project-resolve`: `project_resolve_next_step`, `Project Merge`, `Resolve Another`, `Review First`, `Stop`
- `$project-merge`: `project_merge_next_step`, `Project Doctor`, `Resolve Another`, `Review First`, `Stop`
- `$project-doctor`: `project_doctor_next_step`, `Apply Repair`, `Create Planning Spec`, `Run Audit Again`, `Stop`

- [ ] **Step 2: Run focused tests and verify red state**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-brainstorm\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-context\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1
```

Expected: FAIL until each skill contains the new closeout contract.

- [ ] **Step 3: Update skill docs and metadata**

For each skill, add a `## Native Continuation Gate` section that requires:

- an in-chat summary of the artifact or result before the question;
- `request_user_input` when callable;
- a stop/review option;
- relevant next workflow routes;
- same-turn routing when tools and state allow it;
- debug mode only for explicit non-interactive smoke tests.

Update each `agents/openai.yaml` default prompt with the closeout summary and native continuation requirement.

- [ ] **Step 4: Run focused tests and commit checkpoint**

Run the focused tests from Step 2.

Expected: PASS.

Commit:

```powershell
git add skills/*/SKILL.md skills/*/agents/openai.yaml skills/*/scripts/test-scenarios.ps1
git commit -m "feat: enforce native continuation closeouts"
```

## Task 2: Add Skill Docs Versus Script Parameter Validation

**Files:**

- Create: `scripts/validate-skill-script-contract.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`
- Test: `scripts/validate-skill-script-contract.ps1`

- [ ] **Step 1: Write failing parameter-drift validator fixture**

Create `scripts/validate-skill-script-contract.ps1` with fixture support:

- parse `param(...)` blocks from skill-owned `.ps1` files;
- inspect `SKILL.md` script references and parameter examples;
- fail when docs mention an exposed script with a parameter not present in the script;
- fail when an exposed script has a mandatory parameter that is not documented;
- include a fixture where docs mention `-IssueFile` but script exposes `-IssueMirror`.

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-script-contract.ps1
```

Expected: FAIL until real docs and script references satisfy the contract.

- [ ] **Step 2: Fix current script references**

Audit all `SKILL.md` files for script examples and align with actual script parameter names, especially:

- `skills/project-resolve/scripts/prepare-execution.ps1 -IssueMirror`
- `skills/project-issue/scripts/validate-issue-mirror.ps1 -IssueFile`
- `skills/project-merge/scripts/premerge.ps1`
- `skills/project-merge/scripts/closeout.ps1`

- [ ] **Step 3: Add validation integration**

In `scripts/validate.ps1`, add:

```powershell
$results.Add((Invoke-Step "skill script parameter contract" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-skill-script-contract.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "skill script parameter contract failed" }
}))
```

In `scripts/test-superpowers-project-repo-contract.ps1`, add a check that the validator exists and is referenced by `scripts/validate.ps1`.

- [ ] **Step 4: Run validation and commit checkpoint**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-script-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add scripts skills
git commit -m "feat: validate skill script parameter contracts"
```

## Task 3: Add Shared GitHub Check Normalization

**Files:**

- Create: `scripts/lib/github-checks.ps1`
- Create: `scripts/test-github-checks.ps1`
- Modify: `skills/project-merge/scripts/lib/contract.ps1`
- Modify: `skills/project-merge/scripts/premerge.ps1`
- Modify: `skills/project-merge/scripts/test-scenarios.ps1`
- Modify: `scripts/validate.ps1`

- [ ] **Step 1: Write failing check-state scenarios**

Create `scripts/test-github-checks.ps1` with cases for:

- successful required check passes;
- failed required check blocks;
- pending required check blocks;
- missing required check blocks when policy is `require-existing`;
- skipped optional check passes only when explicitly optional;
- skipped required check blocks.

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-github-checks.ps1
```

Expected: FAIL until `scripts/lib/github-checks.ps1` exists.

- [ ] **Step 2: Implement shared check helper**

Create `scripts/lib/github-checks.ps1` with functions:

- `Normalize-GitHubCheckState`
- `Test-GitHubCheckPassed`
- `Test-GitHubRequiredChecks`

Use string states from `gh pr view --json statusCheckRollup` and `gh pr checks`.

- [ ] **Step 3: Use helper in `$project-merge`**

Dot-source `scripts/lib/github-checks.ps1` from `skills/project-merge/scripts/lib/contract.ps1` by resolving from repo root or by adding a local shim that can find the repo root passed to the gate.

Replace the loose `SUCCESS|PASS|COMPLETED` regex in `skills/project-merge/scripts/premerge.ps1` with the shared helper.

- [ ] **Step 4: Add validation integration and commit checkpoint**

Add `scripts/test-github-checks.ps1` to `scripts/validate.ps1`.

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-github-checks.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add scripts skills/project-merge
git commit -m "feat: normalize github check states"
```

## Task 4: Add Ledger Generation Helpers

**Files:**

- Create: `skills/project-resolve/scripts/collect-pr-ready-ledger.ps1`
- Create: `skills/project-merge/scripts/collect-premerge-ledger.ps1`
- Create: `skills/project-merge/scripts/collect-closeout-ledger.ps1`
- Modify: `skills/project-resolve/SKILL.md`
- Modify: `skills/project-resolve/agents/openai.yaml`
- Modify: `skills/project-resolve/scripts/test-scenarios.ps1`
- Modify: `skills/project-merge/SKILL.md`
- Modify: `skills/project-merge/agents/openai.yaml`
- Modify: `skills/project-merge/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing ledger helper scenarios**

Extend resolver and merge scenario tests to require:

- `collect-pr-ready-ledger.ps1`
- `collect-premerge-ledger.ps1`
- `collect-closeout-ledger.ps1`
- `Temp Plus Evidence`
- generated ledgers passed to existing gates
- no hand-authored JSON requirement for normal runs

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1
```

Expected: FAIL until helper scripts and docs exist.

- [ ] **Step 2: Implement resolver PR-ready collector**

Create `skills/project-resolve/scripts/collect-pr-ready-ledger.ps1` with parameters:

- `-RepoRoot`
- `-SetupLedgerPath`
- `-PrJson` or `-PrFixturePath`
- `-VerificationCommands`
- `-AcceptanceCoverageJson`
- `-HandoffProofJson`
- `-GoalCompletionProofJson`
- `-OutputDir`

Emit JSON containing `ok`, `phase`, `ledger`, `ledger_json`, and optional `ledger_path`. The output must satisfy `validate-pr-ready.ps1`.

- [ ] **Step 3: Implement merge collectors**

Create `skills/project-merge/scripts/collect-premerge-ledger.ps1` with parameters:

- `-RepoRoot`
- `-SetupLedgerPath`
- `-PrNumber` or `-PrJson`
- `-IssueNumber` or `-IssueJson`
- `-VerificationCommands`
- `-ChangedFilesCovered`
- `-OutputDir`

Create `skills/project-merge/scripts/collect-closeout-ledger.ps1` with parameters:

- `-RepoRoot`
- `-SetupLedgerPath`
- `-PrNumber` or `-PrJson`
- `-IssueNumber` or `-IssueJson`
- `-MergeDecisionJson`
- `-CleanupHookOutput`
- `-ResolveGoalCompletionProofJson`
- `-MirrorCleanupJson`
- `-OutputDir`

Both collectors should support fixtures for scenario tests and real `gh` evidence for live runs.

- [ ] **Step 4: Update docs and run tests**

Update resolver and merge docs to tell agents to use collectors before gate scripts. Keep the gate scripts authoritative.

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add skills/project-resolve skills/project-merge
git commit -m "feat: generate workflow evidence ledgers"
```

## Task 5: Add Closed Issue Mirror Cleanup And Milestone Summaries

**Files:**

- Modify: `skills/project-merge/SKILL.md`
- Modify: `skills/project-merge/agents/openai.yaml`
- Modify: `skills/project-merge/scripts/closeout.ps1`
- Modify: `skills/project-merge/scripts/collect-closeout-ledger.ps1`
- Modify: `skills/project-merge/scripts/test-scenarios.ps1`
- Modify: `skills/project-doctor/SKILL.md`
- Modify: `skills/project-doctor/scripts/test-scenarios.ps1`
- Modify: `docs/superpowers/issues/README.md`

- [ ] **Step 1: Add failing mirror lifecycle scenarios**

Extend merge scenarios so closeout requires one of:

- mirror deletion proof for a closed issue; or
- explicit `Mirror Retention: Keep` proof.

Add a scenario that fails when a closed issue mirror remains without retention.

- [ ] **Step 2: Implement closeout validation**

Update `skills/project-merge/scripts/closeout.ps1` to require structured `mirror_cleanup_confirmation` with:

```json
{
  "policy": "delete-after-close",
  "issue_mirror": "docs/superpowers/issues/<file>.md",
  "deleted": true,
  "retained": false,
  "retention_reason": "",
  "milestone_record": "closed-summary"
}
```

If the mirror has `**Mirror Retention:** Keep`, require `retained = true` and a non-empty `retention_reason`.

- [ ] **Step 3: Implement collector support**

Update `collect-closeout-ledger.ps1` to:

- inspect the issue mirror;
- delete it after verified closeout unless retained;
- update or verify milestone page closed summaries;
- record GitHub issue and PR links in the ledger.

- [ ] **Step 4: Document lifecycle policy**

Update `docs/superpowers/issues/README.md` with:

- mirrors are execution inputs;
- closed mirrors are deleted by default;
- `**Mirror Retention:** Keep` preserves unusual historical mirrors;
- milestone pages keep closed summaries instead of active mirror links.

- [ ] **Step 5: Run tests and commit checkpoint**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add skills/project-merge skills/project-doctor docs/superpowers/issues/README.md
git commit -m "feat: clean closed issue mirrors"
```

## Task 6: Add Ignored-Path Detection

**Files:**

- Create: `scripts/lib/git-ignore.ps1`
- Create: `scripts/test-git-ignore-traps.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `skills/project-context/SKILL.md`
- Modify: `skills/project-context/scripts/test-scenarios.ps1`
- Modify: `skills/project-doctor/SKILL.md`
- Modify: `skills/project-doctor/scripts/test-scenarios.ps1`

- [ ] **Step 1: Write failing ignore-trap tests**

Create `scripts/test-git-ignore-traps.ps1` using a temporary git repo fixture where `.git/info/exclude` ignores `AGENTS.md`.

Assert the helper reports:

- path ignored;
- source is `.git/info/exclude` when available from `git check-ignore -v`;
- caller can decide to block or force-add later.

- [ ] **Step 2: Implement helper**

Create `scripts/lib/git-ignore.ps1` with:

- `Test-GitIgnoredPath`
- `Get-GitIgnoreEvidence`

Use `git check-ignore -v -- <path>` and return structured evidence.

- [ ] **Step 3: Document usage**

Update `$project-context` for structure file creation and `$project-doctor` for drift audits. Mention `AGENTS.md`, `docs/agents/*.md`, skill files, issue mirrors, and milestone pages.

- [ ] **Step 4: Add validation integration and commit checkpoint**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-git-ignore-traps.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-context\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add scripts skills/project-context skills/project-doctor
git commit -m "feat: detect ignored project files"
```

## Task 7: Add Quick Apply Path

**Files:**

- Create: `skills/project-plan/scripts/validate-quick-apply.ps1`
- Modify: `skills/project-plan/SKILL.md`
- Modify: `skills/project-plan/agents/openai.yaml`
- Modify: `skills/project-plan/scripts/test-scenarios.ps1`
- Modify: `skills/superpowers-project/SKILL.md`
- Modify: `skills/superpowers-project/agents/openai.yaml`
- Modify: `skills/superpowers-project/scripts/test-scenarios.ps1`
- Modify: `README.md`

- [ ] **Step 1: Add failing Quick Apply tests**

Extend project-plan scenarios to require:

- `Quick Apply`
- `Review First`
- `Revise Plan`
- `validate-quick-apply.ps1`
- clean synced `main`
- native approval ledger
- focused verification
- cleanup hook
- push approval if pushing is requested

- [ ] **Step 2: Implement Quick Apply gate**

Create `skills/project-plan/scripts/validate-quick-apply.ps1` with parameters:

- `-RepoRoot`
- `-PlanPath`
- `-ApprovalJson` or `-ApprovalPath`
- `-VerificationJson` or `-VerificationPath`
- `-CleanupJson` or `-CleanupPath`
- `-AllowPush`

The gate must block unless:

- current branch is `main`;
- `git status --short` is clean before edits or the provided mode is post-change verification with known changed files;
- `main` is synced to `origin/main` before edits;
- approval question id is `project_quick_apply_approval`;
- selected action is `apply`;
- verification commands are present and passed;
- cleanup hook result is present and passed;
- push is not performed unless approved.

- [ ] **Step 3: Update plan continuation docs**

Update `$project-plan` continuation options:

- `Project Issue First`
- `Quick Apply`
- `Subagent Execute`
- `Inline Execute`
- `Review First`
- `Revise Plan`

Add a second native approval question for Quick Apply:

Question id: `project_quick_apply_approval`

Options:

- `Apply on Main`
- `Use Issue Flow`
- `Stop`

- [ ] **Step 4: Update router docs**

Update `$superpowers-project` and `README.md` so small, low-risk post-plan work can route to Quick Apply, while non-trivial work stays issue-backed.

- [ ] **Step 5: Run tests and commit checkpoint**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add skills/project-plan skills/superpowers-project README.md
git commit -m "feat: add guarded quick apply path"
```

## Task 8: Add Project Doctor Scripted Audit

**Files:**

- Create: `skills/project-doctor/scripts/audit-project.ps1`
- Modify: `skills/project-doctor/SKILL.md`
- Modify: `skills/project-doctor/agents/openai.yaml`
- Modify: `skills/project-doctor/scripts/test-scenarios.ps1`
- Modify: `scripts/test-superpowers-project-repo-contract.ps1`

- [ ] **Step 1: Add failing Doctor audit scenarios**

Extend Doctor scenario tests to require:

- `audit-project.ps1`
- blocking/repairable/informational/healthy JSON categories;
- milestone vs GitHub issue membership drift;
- issue mirror vs GitHub issue body/state/labels/milestone drift;
- closed mirror lifecycle drift;
- label vocabulary drift;
- native UI closeout wording drift;
- ignored-path trap drift;
- live sync drift.

- [ ] **Step 2: Implement local-docs audit mode**

Create `audit-project.ps1` with:

- `-RepoRoot`
- `-Mode LocalDocs`
- `-Mode GitHubAware`
- `-IssueFixturePath`
- `-MilestoneFixturePath`
- `-LabelFixturePath`

LocalDocs mode should not require network.

- [ ] **Step 3: Implement GitHub-aware audit mode**

When `gh` is available and repo config is present, compare:

- issue mirrors to GitHub issue bodies, state, labels, and milestones;
- milestone pages to GitHub milestones and issue membership;
- labels to `docs/agents/triage-labels.md`;
- live skill source to deployed live sync output when requested.

- [ ] **Step 4: Update docs and repo contract**

Update Doctor docs to require scripted audit before repair. Add repo contract checks that `audit-project.ps1` exists and that Doctor docs reference it.

- [ ] **Step 5: Run tests and commit checkpoint**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: PASS.

Commit:

```powershell
git add skills/project-doctor scripts/test-superpowers-project-repo-contract.ps1
git commit -m "feat: add project doctor audit gate"
```

## Task 9: Verify End To End And Sync Live

**Files:**

- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `README.md`
- Test: full repo validation and live sync

- [ ] **Step 1: Update top-level project docs**

Make sure `docs/superpowers/PROJECT_CONTEXT.md` and `README.md` mention:

- project-wide native continuation closeouts;
- Quick Apply as a small-work escape hatch;
- generated ledgers;
- closed mirror deletion policy;
- Project Doctor scripted audits.

- [ ] **Step 2: Run focused test suite**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-script-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-github-checks.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-git-ignore-traps.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1
```

Expected: PASS.

- [ ] **Step 3: Run full validation and live sync**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: PASS, and deployed plugin/user skills include all updated skill docs and scripts.

- [ ] **Step 4: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no matching leftover Codex processes under this repo.

- [ ] **Step 5: Commit final docs/sync checkpoint if needed**

If Task 9 changed top-level docs or sync-owned files, commit:

```powershell
git add README.md docs/superpowers/PROJECT_CONTEXT.md
git commit -m "docs: document hardened project workflow"
```

## Self-Review Checklist

- [ ] Source spec is named.
- [ ] Native planning decisions are recorded.
- [ ] Every acceptance criterion maps to at least one task.
- [ ] Every task names exact files and exact commands.
- [ ] TDD is required through failing scenario or contract tests before implementation changes.
- [ ] Quick Apply is guarded and does not replace issue-backed work.
- [ ] Merge approval remains mandatory.
- [ ] Closed mirror deletion has a retention escape hatch.
- [ ] Full completion requires `superpowers:verification-before-completion` before success claims.

## Execution Handoff

Plan complete when this file is saved and self-reviewed. The closeout question should summarize this plan and ask whether to continue to `$project-issue`, use Quick Apply, review first, or revise the plan.
