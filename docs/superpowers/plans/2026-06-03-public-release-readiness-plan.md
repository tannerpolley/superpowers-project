# Public Release Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the repo docs and install scripts match the Superpowers Project public identity without renaming the GitHub repo or workspace yet.

**Architecture:** Keep the plugin's stable runtime identity as `superpowers-project`, use `codex-superpowers-project` as the public repository/package identity, and move the local live plugin target from `plugins/milestones` to `plugins/superpowers-project`. Preserve current tracker repository fields until the GitHub repo is actually renamed.

**Tech Stack:** Markdown, Codex plugin manifest JSON, Bash validation/sync scripts, GitHub issue template YAML.

---

## Source Material

- Source spec: `docs/superpowers/specs/2026-06-03-public-release-readiness-design.md`
- Direct approval: user selected `codex-superpowers-project` and `Docs/scripts only`.

## Acceptance Criteria

- [ ] README presents Superpowers Project as a public Codex/Superpowers extension and documents clone/install usage.
- [ ] Manifest includes public repository/homepage/license/keywords metadata.
- [ ] Sync/install defaults deploy to `/home/tnnrpolley21/.codex/plugins/superpowers-project`.
- [ ] Sync removes this plugin's retired live copy at `/home/tnnrpolley21/.codex/plugins/milestones`.
- [ ] Doctor live-sync audit checks the new live plugin path.
- [ ] GitHub issue templates say Superpowers Project and reference `docs/superpowers/issues`.
- [ ] Active docs/scripts no longer instruct users to use `plugins/milestones` or `docs/milestones`.
- [ ] `scripts/validate.sh` passes.
- [ ] `scripts/sync-live.sh --validate` passes.

## Non-Goals

- Do not rename the GitHub repo.
- Do not make the GitHub repo public.
- Do not rename the local workspace folder.
- Do not rewrite historical closed issue/PR links.
- Do not tag a release.

## Proof Oracle

Run:

```bash
./scripts/validate.sh
./scripts/sync-live.sh --validate
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Then verify:

```bash
Test-Path "$HOME\plugins/superpowers-project\.codex-plugin\plugin.json"
Test-Path "$HOME\plugins/milestones"
rg -n "Milestones plugin|docs/milestones|plugins/\milestones|plugins/milestones" README.md .github
Select-String -Path ./scripts/sync-live.sh,./skills/audit-project/scripts/audit-project.sh -Pattern "plugins/\project|plugins/project"
```

## TDD And Debug Policy

This is docs/scripts work. Use the existing repo validation tests as the regression suite. If validation fails, use systematic debugging before patching.

## Quick Apply Approval

This plan is approved for Quick Apply on clean synced `main` by the user's request and the native scope decision `Docs/scripts only`. It does not require a GitHub issue, branch, PR, or merge flow.

### Task 1: Update Public README And Manifest Metadata

**Files:**
- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`

- [ ] **Step 1: Add public positioning to README**
  Describe Superpowers Project as a Codex plugin/skill extension for Superpowers that adds repo context, GitHub issue and milestone backbone, native question routing, goal-backed execution, worker orchestration, and merge cleanup.
- [ ] **Step 2: Add clone/install instructions**
  Include the intended public repo name `codex-superpowers-project`, local clone instructions, `scripts/install.sh`, validation, and live install locations.
- [ ] **Step 3: Update manifest metadata**
  Add `repository`, `homepage`, `license`, and `keywords`. Keep `name` as `superpowers-project`.
- [ ] **Step 4: Review public wording**
  Ensure the README distinguishes current local source state from future GitHub repo rename.

### Task 2: Move Live Plugin Target To superpowers-project

**Files:**
- Modify: `scripts/sync-live.sh`
- Modify: `skills/audit-project/scripts/audit-project.sh`
- Modify: `AGENTS.md`

- [ ] **Step 1: Change sync default**
  Set the default live plugin root to `$HOME\plugins/superpowers-project`.
- [ ] **Step 2: Retire old live path**
  Add safe cleanup for the owned retired live plugin root `$HOME\plugins/milestones`.
- [ ] **Step 3: Update Doctor live-sync target**
  Make Doctor inspect `plugins/project/skills/audit-project/SKILL.md`.
- [ ] **Step 4: Update source/live policy text**
  Replace active references to `plugins/milestones` with `plugins/superpowers-project`.

### Task 3: Fix Public Issue Templates And Active Path Guards

**Files:**
- Modify: `.github/ISSUE_TEMPLATE/bug.yml`
- Modify: `.github/ISSUE_TEMPLATE/feature.yml`
- Modify: `.github/ISSUE_TEMPLATE/task.yml`
- Modify: `scripts/test-superpowers-project-repo-contract.sh`

- [ ] **Step 1: Rename template descriptions**
  Change "Milestones plugin" wording to "Superpowers Project".
- [ ] **Step 2: Update issue mirror path hints**
  Replace `docs/milestones/<milestone-folder>/issues/...` with `docs/superpowers/issues/<issue-number>-<slug>.md`.
- [ ] **Step 3: Add contract checks**
  Ensure active public docs/templates/scripts do not route to `docs/milestones` or `plugins/milestones`.

### Task 4: Verify And Sync

**Files:**
- Test: `scripts/validate.sh`
- Test: `scripts/sync-live.sh`

- [ ] **Step 1: Run validation**
  `./scripts/validate.sh`
- [ ] **Step 2: Sync live install**
  `./scripts/sync-live.sh --validate`
- [ ] **Step 3: Verify live paths**
  Confirm `plugins/superpowers-project` exists and `plugins/milestones` is gone or no longer contains this plugin.
- [ ] **Step 4: Run cleanup hook**
  `"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .`

