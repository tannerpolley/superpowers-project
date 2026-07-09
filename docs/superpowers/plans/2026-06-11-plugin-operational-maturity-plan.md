# Plugin Operational Maturity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the six operational maturity improvements from `docs/superpowers/specs/2026-06-11-plugin-operational-maturity-design.md`.

**Architecture:** Add source-owned scripts and generated documentation rather than new ad hoc workflow text. Keep native approval boundaries intact by separating evidence preparation from mutation-capable merge and release helpers.

**Tech Stack:** Bash scripts, GitHub Actions YAML, Markdown docs, existing Superpowers Project validators.

---

## Source Evidence

- Source spec: `docs/superpowers/specs/2026-06-11-plugin-operational-maturity-design.md`
- Auto Mode authorization: `project_auto_mode_authorization`, `selected_authority: bounded-auto-merge`, source spec under `docs/superpowers/specs`, recorded defaults, stop outside policy, current repo and development branch mutation scope.
- Milestones: `M0 - Governance`, `M1 - Source Of Truth`, `M2 - Distribution`

## Acceptance Criteria

- [ ] CI workflow has explicit manual dispatch, timeout, dependency install, and validation steps suitable for source validation.
- [ ] Release preparation has a source-owned script and policy text that emits traceable release evidence without publishing by itself.
- [ ] Stale skill detection has a source-owned script that reports source/live/metadata contract markers and missing expected question ids.
- [ ] Local-branch merge closeout has prepare/apply helpers that preserve native approval boundaries.
- [ ] End-to-end smoke coverage has a safe local-only fixture test.
- [ ] A generated outcome workflow exists and validation fails when it drifts from source.
- [ ] `scripts/validate.sh` wires all new validators.
- [ ] `scripts/sync-live.sh --validate` passes after implementation.

## Non-Goals

- Do not create GitHub issues.
- Do not publish releases or tags.
- Do not mutate plugin cache files.
- Do not bypass native approval for merge, push, release, or final `Done`.
- Do not require real GitHub state for default smoke tests.

## Test Complete And Metrics

This is a workflow/plugin governance change. Numerical metrics are not applicable. Test complete means:

- all new scripts parse under the repo Bash parser check;
- focused tests for each new script pass;
- `scripts/validate.sh` passes;
- `scripts/sync-live.sh --validate` passes;
- cleanup hook passes;
- final branch merge closeout proof passes.

## Proof Oracle

- `./scripts/test-contract-summary.sh`
- `./scripts/detect-stale-skill-contract.sh -SkillName brainstorm-spec -ExpectedQuestionId project_brainstorm_start_route`
- `./scripts/prepare-release.sh -CheckOnly`
- `./scripts/test-e2e-project-workflow.sh -LocalOnly`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`

## Task 1: Generate Outcome Workflow

**Files:**
- Create: `scripts/generate-contract-summary.sh`
- Create: `scripts/test-contract-summary.sh`
- Create: `docs/superpowers/OUTCOME_WORKFLOW.md`
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Add generator**
  - Parse active workflow skills from `scripts/lib/project-skills.sh`.
  - Extract skill frontmatter name, description, question ids, final gate ids, and key contract markers.
  - Emit deterministic Markdown to `docs/superpowers/OUTCOME_WORKFLOW.md`.
- [ ] **Step 2: Add summary validator**
  - Generate to temp and compare normalized content against the checked-in summary.
  - Fail if a workflow skill, question id, final gate, canonical namespace, or validation command is missing.
- [ ] **Step 3: Wire validation**
  - Add `scripts/test-contract-summary.sh` to `scripts/validate.sh`.
- [ ] **Step 4: Run focused proof**
  - Run `scripts/generate-contract-summary.sh`.
  - Run `scripts/test-contract-summary.sh`.

## Task 2: Add Stale Skill Detector

**Files:**
- Create: `scripts/detect-stale-skill-contract.sh`
- Create: `scripts/test-stale-skill-contract.sh`
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Implement detector**
  - Inputs: `-SkillName`, `-ExpectedQuestionId`, `-LivePluginRoot`, `-UserSkillsRoot`.
  - Inspect source skill, source metadata, optional live deployed skill, and optional user skill copy.
  - Report missing question ids, missing canonical namespace, missing final gate markers, and live/source drift.
- [ ] **Step 2: Keep cache paths non-authoritative**
  - Do not inspect plugin cache paths by default.
  - Do not require cache paths for pass/fail.
- [ ] **Step 3: Add tests**
  - Positive test for `brainstorm-spec` with `project_brainstorm_start_route`.
  - Negative temp fixture with missing question id.
- [ ] **Step 4: Wire validation**
  - Add the test script to `scripts/validate.sh`.

## Task 3: Add Release Preparation Receipt

**Files:**
- Create: `scripts/prepare-release.sh`
- Create: `scripts/test-prepare-release.sh`
- Modify: `docs/superpowers/RELEASE_POLICY.md`
- Modify: `CHANGELOG.md`
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Implement release check script**
  - Support `-CheckOnly`, `-Version`, and optional `-OutputPath`.
  - Read `.codex-plugin/plugin.json`, `CHANGELOG.md`, current git commit, and dirty status.
  - Emit JSON with version, commit, changelog evidence, dirty status, and required gate commands.
- [ ] **Step 2: Update release policy**
  - Define release receipts, source commit stamping, and what counts as patch/minor/major.
  - State that prepare-release does not publish or tag by itself.
- [ ] **Step 3: Update changelog**
  - Add an `Unreleased` section for operational maturity tooling.
- [ ] **Step 4: Add tests and validation wiring**
  - Add a focused test for current manifest/changelog evidence.

## Task 4: Add Local-Branch Merge Closeout Helpers

**Files:**
- Create: `skills/merge-changes/scripts/prepare-local-branch-closeout.sh`
- Create: `skills/merge-changes/scripts/apply-local-branch-closeout.sh`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`

- [ ] **Step 1: Prepare helper**
  - Collect setup ledger, clean synced main proof, validation proof, changed file inventory, and premerge proof.
  - Emit JSON and a path to the premerge evidence file.
  - Print fields needed for `project_merge_approval`.
- [ ] **Step 2: Apply helper**
  - Require a structured merge decision path or JSON.
  - Validate merge decision before mutation.
  - Merge only the setup ledger branch into `main`, push `main`, delete only that branch locally/remotely, prune, run cleanup, and validate closeout.
- [ ] **Step 3: Scenario coverage**
  - Use temp repos and declined/dry-run paths where mutation would otherwise be risky.
  - Prove helper refuses malformed merge decisions and wrong branch cleanup targets.

## Task 5: Add End-To-End Local Fixture Smoke Test

**Files:**
- Create: `scripts/test-e2e-project-workflow.sh`
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Implement local-only fixture**
  - Create a temp repo.
  - Copy only the minimum source fixtures required.
  - Create a toy spec, plan, branch edit, validation proof, local-branch closeout proof, and terminal decision proof.
- [ ] **Step 2: Add negative assertions**
  - Prove terminal `Done` is blocked before closeout proof.
  - Prove missing expected question id or missing proof fails with a clear phase.
- [ ] **Step 3: Wire validation**
  - Run in `-LocalOnly` mode from `scripts/validate.sh`.

## Task 6: Strengthen CI Workflow

**Files:**
- Modify: `.github/workflows/validate.yml`

- [ ] **Step 1: Add manual dispatch and timeout**
  - Add `workflow_dispatch`.
  - Add `timeout-minutes`.
- [ ] **Step 2: Make validation steps explicit**
  - Keep Windows runner.
  - Install PyYAML and ripgrep.
  - Run full source validation.
  - Keep job label `Validate Superpowers Project plugin`.
- [ ] **Step 3: Avoid secret requirements**
  - Do not add real GitHub mutation steps.

## Task 7: Final Validation And Closeout

**Files:**
- Modify as needed for validator fallout.

- [ ] **Step 1: Run focused checks**
  - `scripts/test-contract-summary.sh`
  - `scripts/test-stale-skill-contract.sh`
  - `scripts/test-prepare-release.sh`
  - `scripts/test-e2e-project-workflow.sh -LocalOnly`
  - `skills/merge-changes/scripts/test-scenarios.sh`
- [ ] **Step 2: Run full validation**
  - `scripts/validate.sh`
  - `scripts/sync-live.sh --validate`
- [ ] **Step 3: Cleanup and branch finish**
  - Run cleanup hook.
  - Commit.
  - Push branch.
  - Use merge-changes local-branch mode with preauthorized clean premerge proof from Auto Mode.

