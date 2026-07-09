# Required Post-Revision Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the validated revision, deployment, installation-refresh, freshness, cleanup, and fresh-session loop a required repository closeout gate for future Codex agents.

**Architecture:** Put the binding agent rule in `AGENTS.md` and the copyable maintainer runbook in `README.md`. Keep both surfaces synchronized around one command order and scope the deployment steps to the package roots already hashed by plugin provenance.

**Tech Stack:** Markdown repository policy, Bash commands, Codex plugin CLI, Git.

## Global Constraints

- The repository is the only editable source; live plugin, user-skill, and installed plugin locations are deployment outputs.
- The required loop applies to `.codex-plugin/`, `skills/`, `assets/`, `scripts/`, and `docs/superpowers/` revisions.
- A future agent without commit authorization must request it before live deployment instead of deploying an uncommitted source state.
- Direct cache mutation and live-copy edits remain forbidden.
- A named release updates the plugin version and changelog; routine local refreshes may reuse the current marketplace version.
- The current model context cannot reload prompt or skill text, so every completed refresh ends with a fresh-session notice.

---

## Source Evidence

- Approved design: `docs/superpowers/specs/2026-07-09-required-post-revision-loop-design.md`
- Existing agent policy: `AGENTS.md`
- Existing sync/install guidance: `README.md`
- Supported refresh command: `codex plugin add superpowers-project@personal --json`

## Outcome Proof

**Intent:** Future Codex agents complete plugin revisions through one visible and repeatable source-to-installed-plugin loop.
**Current Behavior:** `AGENTS.md` requires validation and validated live sync but does not require marketplace snapshot refresh, strict freshness proof, clean committed provenance, or a fresh-session notice. `README.md` separates sync and install guidance without a single post-revision runbook.
**Expected Outcome:** Future agents see a mandatory closeout gate in `AGENTS.md`, and maintainers can copy the same ordered workflow from `README.md` after any installable-surface revision.
**Target Output:** Updated `AGENTS.md` and `README.md` with matching scope, commands, failure policy, and session-refresh guidance.
**Owner:** Superpowers Project plugin source repository.
**Interface:** Repo-level Codex instructions, maintainer README, `scripts/validate.sh`, `scripts/sync-live.sh`, Codex plugin CLI, version tracker, cleanup hook, and Git status.
**Cutover:** The new required gate replaces the current partial validation-only closeout guidance for installable-surface revisions.
**Replaced Path:** Ad hoc sequences that stop after `validate.sh` or `sync-live.sh --validate` without refreshing the installed plugin and proving freshness.
**Evidence:** Exact-heading checks, command-order review, full validation, validated live sync, successful plugin refresh, strict source/live proof, cleanup output, and clean Git status.
**Acceptance Proof:** Both documentation surfaces contain the same ordered gate; all repository and live checks pass; a fresh-session notice appears in both surfaces.
**Stop Criteria:** Stop before live deployment if source validation fails, commit permission is absent, the intended changes are uncommitted, sync fails, plugin refresh fails, or strict freshness proof reports drift.
**Avoid:** Do not add a wrapper script, mutate cache files, edit live copies, create compatibility aliases, or require GitHub issue/PR workflow for routine maintenance.
**Risk:** Low. The change affects repository operating instructions and deploys those docs as part of the provenance-owned plugin surface. Risk owner: current Codex thread.

## Implementation Boundaries

**Files To Create:** `docs/superpowers/plans/2026-07-09-required-post-revision-loop-plan.md`.
**Files To Modify:** `AGENTS.md`; `README.md`.
**Files To Avoid:** Deployed plugin copies, deployed user skills, Codex plugin cache, unrelated skills, scripts, workflow contracts, and release metadata.
**Source Of Truth:** `docs/superpowers/specs/2026-07-09-required-post-revision-loop-design.md`.
**Read Path:** Read the approved design and current validation, sync, version, install, and cleanup guidance.
**Write Path:** Patch only `AGENTS.md` and `README.md` in the source repository.
**Integration Points:** Codex repository instruction loading, maintainer onboarding, personal marketplace refresh, source/live provenance check, and session restart behavior.
**Migration Or Cutover:** Add the complete required loop and retain existing shorter validation headings as supporting commands, not alternate completion paths.
**Replaced Path Handling:** Explicitly state that validation-only and sync-only sequences do not complete an installable-surface revision.
**Acceptance Proof Gate:** Exact documentation checks pass before full validation; validated sync, plugin refresh, strict freshness proof, cleanup, and Git status complete before handoff.

### Task 1: Add the required agent gate and maintainer runbook

**Use Cases:**
- A Codex agent changes a skill and can find the complete required closeout sequence in `AGENTS.md` without consulting conversation history.
- A maintainer revises scripts or packaged documentation and can copy the refresh sequence from `README.md`.
- An agent without commit permission stops before deployment and asks for authorization.
- A docs-only change outside the provenance-owned plugin roots avoids unnecessary live deployment.
- A refreshed installation tells the user to start a fresh session before expecting updated skill behavior.
- Acceptance evidence proves both documentation surfaces use the same command order and that strict source/live freshness passes after deployment.
- Cutover displaces the old validation-only or sync-only closeout path by naming it incomplete for installable-surface revisions.

**Files:**
- Modify: `AGENTS.md:18`
- Modify: `README.md:211`
- Test: `scripts/validate.sh`
- Test: `scripts/sync-live.sh --validate`

**Interfaces:**
- Consumes: the installable path set and command order from the approved design.
- Produces: `## Required Post-Revision Loop` in `AGENTS.md` and `## Revision And Refresh Loop` in `README.md`.

- [ ] **Step 1: Verify the required headings are absent**

  Run:

  ```bash
  rg -n '^## Required Post-Revision Loop$' AGENTS.md
  rg -n '^## Revision And Refresh Loop$' README.md
  ```

  Expected: both commands exit `1` because the required sections do not exist yet.

- [ ] **Step 2: Add the binding AGENTS.md gate**

  Add this section after the existing rules and before `## Validation`:

  ```markdown
  ## Required Post-Revision Loop

  Changes under `.codex-plugin/`, `skills/`, `assets/`, `scripts/`, or `docs/superpowers/` change the installable plugin surface. Before reporting such a revision complete, future agents must complete this sequence in order:

  1. Run `./scripts/validate.sh`.
  2. Commit the intended source changes. If commit authorization is absent, request it and stop before live deployment.
  3. Run `./scripts/sync-live.sh --validate`.
  4. Run `codex plugin add superpowers-project@personal --json` to install or refresh the supported marketplace snapshot.
  5. Run `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`.
  6. Run `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`.
  7. Confirm `git status --short --branch` shows the expected clean branch state.
  8. Tell the user to start a fresh Codex session so the updated prompt and skill text load.

  Report every skipped or failed gate. Validation-only and sync-only sequences do not complete an installable-surface revision. Never edit deployed copies or plugin cache files to bypass this loop.

  Changes outside the listed installable paths require proportionate validation and cleanup, but do not require live sync or plugin refresh unless they alter runtime behavior.
  ```

- [ ] **Step 3: Add the copyable README runbook**

  Add `## Revision And Refresh Loop` after the live-sync explanation and before `## Install`. Include this exact command order:

  ```bash
  ./scripts/validate.sh
  git status --short
  # Stage only the reviewed revision files, then create a focused commit.
  ./scripts/sync-live.sh --validate
  codex plugin add superpowers-project@personal --json
  ./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
  bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .
  git status --short --branch
  ```

  Explain that `plugin add` may be rerun to refresh the installed snapshot, a fresh Codex session loads the new prompt and skill text, and named releases still require a version and changelog update.

- [ ] **Step 4: Verify documentation alignment and source integrity**

  Run:

  ```bash
  rg -n '^## Required Post-Revision Loop$|codex plugin add superpowers-project@personal|fresh Codex session' AGENTS.md
  rg -n '^## Revision And Refresh Loop$|codex plugin add superpowers-project@personal|fresh Codex session' README.md
  git diff --check
  ./scripts/validate.sh
  ```

  Expected: both headings and shared commands appear; diff and full source validation pass.

- [ ] **Step 5: Commit the repository contract**

  ```bash
  git add AGENTS.md README.md
  git commit -m "docs: require the plugin revision refresh loop"
  ```

  Expected: the commit succeeds and `git status --short` is empty.

- [ ] **Step 6: Run deployment and installed-snapshot proof**

  Run:

  ```bash
  ./scripts/validate.sh
  ./scripts/sync-live.sh --validate
  codex plugin add superpowers-project@personal --json
  ./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
  bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .
  git status --short --branch
  ```

  Expected: validated sync, plugin refresh, freshness, and cleanup pass; Git reports a clean branch. Push only with explicit user authorization.
