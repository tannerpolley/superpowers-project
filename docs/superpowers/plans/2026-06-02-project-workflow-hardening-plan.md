# Project Workflow Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden Superpowers Project workflow contracts so native UI continuations, ledgers, GitHub checks, closed issue mirrors, ignored files, Doctor drift audits, and quick local-main work are reliable and validated.

**Architecture:** Keep the existing skill split: `$project:brainstorm-spec` designs, `$project:write-plan` plans and can route to Quick Apply, `$project:create-issues` publishes tracker work, `$project:resolve-issue` implements one issue, `$project:merge-changes` integrates PRs, and `$project:audit-project` audits drift. Add small Bash gates and shared helpers where they prevent contract drift, while keeping existing gate scripts authoritative.

**Tech Stack:** Codex skill Markdown/YAML, Bash 7 validation scripts, JSON ledgers, Git/GitHub CLI evidence, native `request_user_input`, `docs/superpowers` artifacts, and existing repo validation through `scripts/validate.sh` plus `scripts/sync-live.sh --validate`.

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
- [ ] `$project:brainstorm-spec` requires an in-chat spec summary and native `Project Plan`, `Review First`, `Revise Spec` continuation question.
- [ ] `$project:write-plan` includes `Quick Apply`, `Review First`, and `Revise Plan` in `project_plan_next_step`.
- [ ] Quick Apply has a bundled gate script that blocks dirty, unsynced, non-main, missing approval, missing verification, or missing cleanup states.
- [ ] Skill docs cannot drift from exposed Bash script parameters without `scripts/validate.sh` failing.
- [ ] Resolve and merge ledger helpers generate setup, PR-ready, premerge, and closeout evidence from local/GitHub inputs without hand-authored JSON.
- [ ] GitHub check state normalization is shared and treats skipped checks consistently.
- [ ] `$project:merge-changes` closeout records mirror deletion or explicit retention evidence for closed issues.
- [ ] `$project:audit-project` has a scripted audit for milestone, mirror, GitHub tracker, label, live sync, native UI, and ignored-path drift.
- [ ] Local ignore traps are detected before structure files are assumed to be tracked.
- [ ] Full repo validation and live sync validation pass.

## File Map

Create:

- `scripts/lib/github-checks.sh`: shared GitHub check-state normalization.
- `scripts/lib/git-ignore.sh`: ignored-path detection helper.
- `scripts/validate-skill-script-contract.sh`: skill docs vs script parameter contract.
- `scripts/test-github-checks.sh`: shared check normalization scenarios.
- `scripts/test-git-ignore-traps.sh`: ignored-path scenarios.
- `skills/write-plan/scripts/validate-quick-apply.sh`: Quick Apply gate.
- `skills/resolve-issue/scripts/collect-pr-ready-ledger.sh`: PR-ready ledger generator.
- `skills/merge-changes/scripts/collect-premerge-ledger.sh`: premerge evidence generator.
- `skills/merge-changes/scripts/collect-closeout-ledger.sh`: closeout ledger generator.
- `skills/audit-project/scripts/audit-project.sh`: structured Doctor audit.

Modify:

- `scripts/validate.sh`
- `scripts/test-superpowers-project-dummy-repo.sh`
- `scripts/test-superpowers-project-repo-contract.sh`
- `skills/initiate-workflow/SKILL.md`
- `skills/initiate-workflow/agents/openai.yaml`
- `skills/initiate-workflow/scripts/test-scenarios.sh`
- `skills/project-context/SKILL.md`
- `skills/project-context/agents/openai.yaml`
- `skills/project-context/scripts/test-scenarios.sh`
- `skills/brainstorm-spec/SKILL.md`
- `skills/brainstorm-spec/agents/openai.yaml`
- `skills/brainstorm-spec/scripts/test-scenarios.sh`
- `skills/write-plan/SKILL.md`
- `skills/write-plan/agents/openai.yaml`
- `skills/write-plan/scripts/test-scenarios.sh`
- `skills/create-issues/SKILL.md`
- `skills/create-issues/agents/openai.yaml`
- `skills/create-issues/scripts/test-scenarios.sh`
- `skills/resolve-issue/SKILL.md`
- `skills/resolve-issue/agents/openai.yaml`
- `skills/resolve-issue/scripts/lib/contract.sh`
- `skills/resolve-issue/scripts/test-scenarios.sh`
- `skills/resolve-issue/scripts/validate-pr-ready.sh`
- `skills/merge-changes/SKILL.md`
- `skills/merge-changes/agents/openai.yaml`
- `skills/merge-changes/scripts/lib/contract.sh`
- `skills/merge-changes/scripts/premerge.sh`
- `skills/merge-changes/scripts/closeout.sh`
- `skills/merge-changes/scripts/test-scenarios.sh`
- `skills/audit-project/SKILL.md`
- `skills/audit-project/agents/openai.yaml`
- `skills/audit-project/scripts/test-scenarios.sh`
- `docs/superpowers/issues/README.md`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `README.md`

Test:

- `./scripts/validate-skill-script-contract.sh`
- `./scripts/test-github-checks.sh`
- `./scripts/test-git-ignore-traps.sh`
- `./skills/write-plan/scripts/test-scenarios.sh`
- `./skills/resolve-issue/scripts/test-scenarios.sh`
- `./skills/merge-changes/scripts/test-scenarios.sh`
- `./skills/audit-project/scripts/test-scenarios.sh`
- `./skills/superpowers-project/scripts/test-scenarios.sh`
- `./scripts/test-superpowers-project-dummy-repo.sh`
- `./scripts/test-superpowers-project-repo-contract.sh`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .`

## Non-Goals

- Do not add GoalBuddy boards or `docs/goals`.
- Do not replace `$project:create-issues`, `$project:resolve-issue`, or `$project:merge-changes`.
- Do not skip native merge approval.
- Do not make Quick Apply available for risky or multi-issue implementation work.
- Do not write generated ledgers into the repo by default.
- Do not let `$project:audit-project` mutate docs or tracker state without native repair approval.

## Task 1: Enforce Native Continuation Closeout Across Skills

**Files:**

- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.sh`
- Modify: `skills/project-context/SKILL.md`
- Modify: `skills/project-context/agents/openai.yaml`
- Modify: `skills/project-context/scripts/test-scenarios.sh`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/scripts/test-scenarios.sh`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.sh`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/test-scenarios.sh`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/audit-project/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing continuation-closeout scenario tests**

Add scenario assertions requiring each skill to contain:

```bash
"Native Continuation Gate",
"summarize",
"Review First",
"stop",
"request_user_input",
"start the selected next skill"
```

Add skill-specific question id and option needles:

- `$project:brainstorm-spec`: `project_brainstorm_next_step`, `Project Plan`, `Review First`, `Revise Spec`
- `$project-context`: `project_context_next_step`, `Project Brainstorm`, `Project Plan`, `Project Issue`, `Project Doctor`, `Stop`
- `$project:write-plan`: `project_plan_next_step`, `Project Issue First`, `Quick Apply`, `Review First`, `Revise Plan`
- `$project:create-issues`: `project_issue_next_step`, `Resolve First Ready`, `Resolve Selected`, `Review First`, `Stop`
- `$project:resolve-issue`: `project_resolve_next_step`, `Project Merge`, `Resolve Another`, `Review First`, `Stop`
- `$project:merge-changes`: `project_merge_next_step`, `Project Doctor`, `Resolve Another`, `Review First`, `Stop`
- `$project:audit-project`: `project_doctor_next_step`, `Apply Repair`, `Create Planning Spec`, `Run Audit Again`, `Stop`

- [ ] **Step 2: Run focused tests and verify red state**

Run:

```bash
./skills/brainstorm-spec/scripts/test-scenarios.sh
./skills/project-context/scripts/test-scenarios.sh
./skills/write-plan/scripts/test-scenarios.sh
./skills/create-issues/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./skills/audit-project/scripts/test-scenarios.sh
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

```bash
git add skills/*/SKILL.md skills/*/agents/openai.yaml skills/*/scripts/test-scenarios.sh
git commit -m "feat: enforce native continuation closeouts"
```

## Task 2: Add Skill Docs Versus Script Parameter Validation

**Files:**

- Create: `scripts/validate-skill-script-contract.sh`
- Modify: `scripts/validate.sh`
- Modify: `scripts/test-superpowers-project-repo-contract.sh`
- Test: `scripts/validate-skill-script-contract.sh`

- [ ] **Step 1: Write failing parameter-drift validator fixture**

Create `scripts/validate-skill-script-contract.sh` with fixture support:

- parse `param(...)` blocks from skill-owned `.sh` files;
- inspect `SKILL.md` script references and parameter examples;
- fail when docs mention an exposed script with a parameter not present in the script;
- fail when an exposed script has a mandatory parameter that is not documented;
- include a fixture where docs mention `-IssueFile` but script exposes `-IssueMirror`.

Run:

```bash
./scripts/validate-skill-script-contract.sh
```

Expected: FAIL until real docs and script references satisfy the contract.

- [ ] **Step 2: Fix current script references**

Audit all `SKILL.md` files for script examples and align with actual script parameter names, especially:

- `skills/resolve-issue/scripts/prepare-execution.sh -IssueMirror`
- `skills/create-issues/scripts/validate-issue-mirror.sh -IssueFile`
- `skills/merge-changes/scripts/premerge.sh`
- `skills/merge-changes/scripts/closeout.sh`

- [ ] **Step 3: Add validation integration**

In `scripts/validate.sh`, add:

```bash
$results.Add((Invoke-Step "skill script parameter contract" {
    & (Join-Path $PSScriptRoot "validate-skill-script-contract.sh") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "skill script parameter contract failed" }
}))
```

In `scripts/test-superpowers-project-repo-contract.sh`, add a check that the validator exists and is referenced by `scripts/validate.sh`.

- [ ] **Step 4: Run validation and commit checkpoint**

Run:

```bash
./scripts/validate-skill-script-contract.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add scripts skills
git commit -m "feat: validate skill script parameter contracts"
```

## Task 3: Add Shared GitHub Check Normalization

**Files:**

- Create: `scripts/lib/github-checks.sh`
- Create: `scripts/test-github-checks.sh`
- Modify: `skills/merge-changes/scripts/lib/contract.sh`
- Modify: `skills/merge-changes/scripts/premerge.sh`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Write failing check-state scenarios**

Create `scripts/test-github-checks.sh` with cases for:

- successful required check passes;
- failed required check blocks;
- pending required check blocks;
- missing required check blocks when policy is `require-existing`;
- skipped optional check passes only when explicitly optional;
- skipped required check blocks.

Run:

```bash
./scripts/test-github-checks.sh
```

Expected: FAIL until `scripts/lib/github-checks.sh` exists.

- [ ] **Step 2: Implement shared check helper**

Create `scripts/lib/github-checks.sh` with functions:

- `Normalize-GitHubCheckState`
- `Test-GitHubCheckPassed`
- `Test-GitHubRequiredChecks`

Use string states from `gh pr view --json statusCheckRollup` and `gh pr checks`.

- [ ] **Step 3: Use helper in `$project:merge-changes`**

Dot-source `scripts/lib/github-checks.sh` from `skills/merge-changes/scripts/lib/contract.sh` by resolving from repo root or by adding a local shim that can find the repo root passed to the gate.

Replace the loose `SUCCESS|PASS|COMPLETED` regex in `skills/merge-changes/scripts/premerge.sh` with the shared helper.

- [ ] **Step 4: Add validation integration and commit checkpoint**

Add `scripts/test-github-checks.sh` to `scripts/validate.sh`.

Run:

```bash
./scripts/test-github-checks.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add scripts skills/merge-changes
git commit -m "feat: normalize github check states"
```

## Task 4: Add Ledger Generation Helpers

**Files:**

- Create: `skills/resolve-issue/scripts/collect-pr-ready-ledger.sh`
- Create: `skills/merge-changes/scripts/collect-premerge-ledger.sh`
- Create: `skills/merge-changes/scripts/collect-closeout-ledger.sh`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing ledger helper scenarios**

Extend resolver and merge scenario tests to require:

- `collect-pr-ready-ledger.sh`
- `collect-premerge-ledger.sh`
- `collect-closeout-ledger.sh`
- `Temp Plus Evidence`
- generated ledgers passed to existing gates
- no hand-authored JSON requirement for normal runs

Run:

```bash
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
```

Expected: FAIL until helper scripts and docs exist.

- [ ] **Step 2: Implement resolver PR-ready collector**

Create `skills/resolve-issue/scripts/collect-pr-ready-ledger.sh` with parameters:

- `-RepoRoot`
- `-SetupLedgerPath`
- `-PrJson` or `-PrFixturePath`
- `-VerificationCommands`
- `-AcceptanceCoverageJson`
- `-HandoffProofJson`
- `-GoalCompletionProofJson`
- `-OutputDir`

Emit JSON containing `ok`, `phase`, `ledger`, `ledger_json`, and optional `ledger_path`. The output must satisfy `validate-pr-ready.sh`.

- [ ] **Step 3: Implement merge collectors**

Create `skills/merge-changes/scripts/collect-premerge-ledger.sh` with parameters:

- `-RepoRoot`
- `-SetupLedgerPath`
- `-PrNumber` or `-PrJson`
- `-IssueNumber` or `-IssueJson`
- `-VerificationCommands`
- `-ChangedFilesCovered`
- `-OutputDir`

Create `skills/merge-changes/scripts/collect-closeout-ledger.sh` with parameters:

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

```bash
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add skills/resolve-issue skills/merge-changes
git commit -m "feat: generate workflow evidence ledgers"
```

## Task 5: Add Closed Issue Mirror Cleanup And Milestone Summaries

**Files:**

- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/closeout.sh`
- Modify: `skills/merge-changes/scripts/collect-closeout-ledger.sh`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/scripts/test-scenarios.sh`
- Modify: `docs/superpowers/issues/README.md`

- [ ] **Step 1: Add failing mirror lifecycle scenarios**

Extend merge scenarios so closeout requires one of:

- mirror deletion proof for a closed issue; or
- explicit `Mirror Retention: Keep` proof.

Add a scenario that fails when a closed issue mirror remains without retention.

- [ ] **Step 2: Implement closeout validation**

Update `skills/merge-changes/scripts/closeout.sh` to require structured `mirror_cleanup_confirmation` with:

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

Update `collect-closeout-ledger.sh` to:

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

```bash
./skills/merge-changes/scripts/test-scenarios.sh
./skills/audit-project/scripts/test-scenarios.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add skills/merge-changes skills/audit-project docs/superpowers/issues/README.md
git commit -m "feat: clean closed issue mirrors"
```

## Task 6: Add Ignored-Path Detection

**Files:**

- Create: `scripts/lib/git-ignore.sh`
- Create: `scripts/test-git-ignore-traps.sh`
- Modify: `scripts/validate.sh`
- Modify: `skills/project-context/SKILL.md`
- Modify: `skills/project-context/scripts/test-scenarios.sh`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/scripts/test-scenarios.sh`

- [ ] **Step 1: Write failing ignore-trap tests**

Create `scripts/test-git-ignore-traps.sh` using a temporary git repo fixture where `.git/info/exclude` ignores `AGENTS.md`.

Assert the helper reports:

- path ignored;
- source is `.git/info/exclude` when available from `git check-ignore -v`;
- caller can decide to block or force-add later.

- [ ] **Step 2: Implement helper**

Create `scripts/lib/git-ignore.sh` with:

- `Test-GitIgnoredPath`
- `Get-GitIgnoreEvidence`

Use `git check-ignore -v -- <path>` and return structured evidence.

- [ ] **Step 3: Document usage**

Update `$project-context` for structure file creation and `$project:audit-project` for drift audits. Mention `AGENTS.md`, `docs/agents/*.md`, skill files, issue mirrors, and milestone pages.

- [ ] **Step 4: Add validation integration and commit checkpoint**

Run:

```bash
./scripts/test-git-ignore-traps.sh
./skills/project-context/scripts/test-scenarios.sh
./skills/audit-project/scripts/test-scenarios.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add scripts skills/project-context skills/audit-project
git commit -m "feat: detect ignored project files"
```

## Task 7: Add Quick Apply Path

**Files:**

- Create: `skills/write-plan/scripts/validate-quick-apply.sh`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.sh`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.sh`
- Modify: `README.md`

- [ ] **Step 1: Add failing Quick Apply tests**

Extend write-plan scenarios to require:

- `Quick Apply`
- `Review First`
- `Revise Plan`
- `validate-quick-apply.sh`
- clean synced `main`
- native approval ledger
- focused verification
- cleanup hook
- push approval if pushing is requested

- [ ] **Step 2: Implement Quick Apply gate**

Create `skills/write-plan/scripts/validate-quick-apply.sh` with parameters:

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

Update `$project:write-plan` continuation options:

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

Update `$project:initiate-workflow` and `README.md` so small, low-risk post-plan work can route to Quick Apply, while non-trivial work stays issue-backed.

- [ ] **Step 5: Run tests and commit checkpoint**

Run:

```bash
./skills/write-plan/scripts/test-scenarios.sh
./skills/superpowers-project/scripts/test-scenarios.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add skills/write-plan skills/workflow README.md
git commit -m "feat: add guarded quick apply path"
```

## Task 8: Add Project Doctor Scripted Audit

**Files:**

- Create: `skills/audit-project/scripts/audit-project.sh`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/audit-project/scripts/test-scenarios.sh`
- Modify: `scripts/test-superpowers-project-repo-contract.sh`

- [ ] **Step 1: Add failing Doctor audit scenarios**

Extend Doctor scenario tests to require:

- `audit-project.sh`
- blocking/repairable/informational/healthy JSON categories;
- milestone vs GitHub issue membership drift;
- issue mirror vs GitHub issue body/state/labels/milestone drift;
- closed mirror lifecycle drift;
- label vocabulary drift;
- native UI closeout wording drift;
- ignored-path trap drift;
- live sync drift.

- [ ] **Step 2: Implement local-docs audit mode**

Create `audit-project.sh` with:

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

Update Doctor docs to require scripted audit before repair. Add repo contract checks that `audit-project.sh` exists and that Doctor docs reference it.

- [ ] **Step 5: Run tests and commit checkpoint**

Run:

```bash
./skills/audit-project/scripts/test-scenarios.sh
./scripts/test-superpowers-project-repo-contract.sh
./scripts/validate.sh
```

Expected: PASS.

Commit:

```bash
git add skills/audit-project scripts/test-superpowers-project-repo-contract.sh
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

```bash
./scripts/validate-skill-script-contract.sh
./scripts/test-github-checks.sh
./scripts/test-git-ignore-traps.sh
./skills/write-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./skills/audit-project/scripts/test-scenarios.sh
./skills/superpowers-project/scripts/test-scenarios.sh
```

Expected: PASS.

- [ ] **Step 3: Run full validation and live sync**

Run:

```bash
./scripts/validate.sh
./scripts/sync-live.sh --validate
```

Expected: PASS, and deployed plugin/user skills include all updated skill docs and scripts.

- [ ] **Step 4: Run cleanup hook**

Run:

```bash
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Expected: no matching leftover Codex processes under this repo.

- [ ] **Step 5: Commit final docs/sync checkpoint if needed**

If Task 9 changed top-level docs or sync-owned files, commit:

```bash
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

Plan complete when this file is saved and self-reviewed. The closeout question should summarize this plan and ask whether to continue to `$project:create-issues`, use Quick Apply, review first, or revise the plan.


