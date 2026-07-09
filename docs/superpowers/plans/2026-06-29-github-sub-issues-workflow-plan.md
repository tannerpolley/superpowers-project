# GitHub Sub-Issues Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional GitHub sub-issue hierarchy support while keeping issue titles clean and using GitHub Milestones as the milestone tracking source.

**Architecture:** Extend the existing `spec -> plan -> issue` workflow with an optional hierarchy layer owned by `create-issues`, validated by mirror and tracker scripts, and consumed as read-only context by execution routes. Parent and wrapper issues become rollup records; only leaf issue mirrors can run through `resolve-issue` or `orchestrate-issues`.

**Tech Stack:** Bash 7 validators and fixtures, GitHub CLI `gh` 2.94 or newer, Markdown issue mirrors, JSON tracker metadata, GitHub Issues sub-issues, GitHub Milestones, existing Superpowers Project skill scripts, and repo validation scripts.

---

## Source Spec

- `docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md`

## Test-Complete Definition

Test complete means the repo proves all three hierarchy modes with deterministic fixtures: flat issues stay executable, grouped plans create clean-title parent plus leaf payloads, and pseudo sub-milestone plans create parent, wrapper, and leaf payloads in GitHub publication order. New validators must reject manual milestone names or numbers in new issue titles, block non-leaf execution, prove GitHub parent/sub-issue mirror parity from fixture data, and keep real GitHub mutation behind native approval or dry command output. Final proof is targeted skill scenario tests, root workflow example tests, `scripts/validate.sh`, `scripts/sync-live.sh --validate`, version freshness, cleanup hook, and clean Git state.

Pass/fail metrics are command exit codes, validator JSON receipts, exact fixture assertions, and dry GitHub command receipts. Numeric tolerances do not apply because this is workflow contract work; the measurable threshold is zero failing required validators and zero new issue title examples that encode milestone identity in the title.

## Outcome Proof

**Intent:** Implement GitHub-native sub-issue hierarchy so large grouped work can use parent issues as pseudo sub-milestones while GitHub Milestones remain the milestone tracker and issue titles remain clean.
**Current Behavior:** The workflow creates flat GitHub issues and local mirrors with milestone metadata, labels, workflow metadata, outcome proof, and merge metadata. It does not model parent/sub-issue relationships, does not prevent manual milestone text in new issue titles, and does not distinguish rollup issues from executable leaf issues.
**Expected Outcome:** `create-issues` can publish or dry-run flat, issue-set, and pseudo sub-milestone hierarchies; mirrors record hierarchy role and executability; execution routes reject parent and wrapper issues; merge closeout records rollup evidence; align-project audits drift and selective migration candidates; docs and examples teach GitHub-native milestone tracking instead of title prefixes.
**Target Output:** A merged source change with new hierarchy scripts, updated skill instructions, updated tracker vocabulary, updated tests, generated docs, passing validation, and live-sync proof.
**Owner:** `skills/create-issues` owns hierarchy construction and publication; `skills/resolve-issue` and `skills/orchestrate-issues` own leaf-only execution gates; `skills/merge-changes` owns rollup evidence; `skills/align-project` owns drift and selective migration reporting; `docs/agents` owns tracker vocabulary.
**Interface:** Agents interact through skill Markdown, native questions, local issue mirrors, dry GitHub command receipts, GitHub issue JSON fields, and validator receipts consumed by `scripts/validate.sh`.
**Cutover:** Add validators and fixtures first, update skill docs and scripts to require hierarchy fields when present, then wire the new checks into full validation and live sync.
**Replaced Path:** Manual milestone names, milestone numbers, pseudo sub-milestone ordinals, and hierarchy ordering in new issue titles stop being accepted as tracker structure.
**Evidence:** Clean-title validator receipts, hierarchy mirror validator receipts, dry GitHub command payloads, fixture-based GitHub JSON parity checks, leaf-only execution rejection tests, rollup closeout receipts, updated tracker docs, generated workflow examples, full validation output, live-sync validation output, cleanup output, and Git status.
**Acceptance Proof:** The proof oracle commands in this plan pass, including targeted scenario scripts, root workflow tests, `scripts/validate.sh`, `scripts/sync-live.sh --validate`, version freshness, cleanup, and clean Git state.
**Stop Criteria:** Stop before publish, push, merge, or live update if hierarchy metadata cannot be represented in GitHub, if parent or wrapper issues can enter an execution route, if clean-title validation misses title-encoded milestone metadata, if dry commands differ from approved hierarchy, or if full validation fails.
**Avoid:** Do not edit deployed plugin copies directly, do not require hierarchy for single-issue plans, do not replace GitHub Milestones with parent issues, do not bulk-rename historical issues without native approval, and do not make GitHub Projects the execution source of truth.
**Risk:** The highest risk is creating two tracker truths, with titles or local mirrors disagreeing with GitHub Milestones and sub-issue state. The plan mitigates that by validating clean titles, reading GitHub hierarchy JSON, and blocking execution unless mirror role and GitHub evidence agree.

## Implementation Boundaries

**Files To Create:** `skills/create-issues/scripts/lib/issue-hierarchy.sh`, `skills/create-issues/scripts/validate-issue-title-policy.sh`, `skills/create-issues/scripts/validate-issue-hierarchy.sh`, `skills/create-issues/scripts/build-issue-hierarchy-plan.sh`, and `docs/superpowers/examples/sub-issues-workflow-examples.md`.
**Files To Modify:** `docs/agents/triage-labels.md`, `docs/agents/project-roadmap.json`, `docs/agents/project-roadmap.md`, `docs/agents/issue-tracker.md`, `docs/superpowers/PROJECT_CONTEXT.md`, `skills/setup-project/SKILL.md`, `skills/setup-project/agents/openai.yaml`, `skills/setup-project/scripts/prepare-github-project-board.sh`, `skills/setup-project/scripts/test-scenarios.sh`, `skills/create-issues/SKILL.md`, `skills/create-issues/agents/openai.yaml`, `skills/create-issues/scripts/validate-issue-mirror.sh`, `skills/create-issues/scripts/hydrate-external-issue.sh`, `skills/create-issues/scripts/test-scenarios.sh`, `skills/resolve-issue/SKILL.md`, `skills/resolve-issue/scripts/preflight.sh`, `skills/resolve-issue/scripts/prepare-execution.sh`, `skills/resolve-issue/scripts/test-scenarios.sh`, `skills/orchestrate-issues/SKILL.md`, `skills/orchestrate-issues/scripts/prepare-worker-handoff.sh`, `skills/orchestrate-issues/scripts/test-scenarios.sh`, `skills/merge-changes/SKILL.md`, `skills/merge-changes/scripts/collect-closeout-ledger.sh`, `skills/merge-changes/scripts/closeout.sh`, `skills/merge-changes/scripts/test-scenarios.sh`, `skills/align-project/SKILL.md`, `skills/align-project/scripts/align-project.sh`, `skills/align-project/scripts/test-scenarios.sh`, `skills/loop-controller/SKILL.md`, `skills/loop-controller/scripts/select-candidate.sh`, `skills/loop-controller/scripts/test-scenarios.sh`, `docs/superpowers/examples/workflow-golden-paths.md`, `scripts/validate-workflow-examples.sh`, `scripts/test-workflow-examples.sh`, `scripts/generate-outcome-workflow-summary.sh`, `scripts/test-outcome-workflow-summary.sh`, `scripts/test-tracker-roadmap-proof.sh`, `scripts/validate-tracker-roadmap-proof.sh`, `scripts/validate.sh`, and `README.md`.
**Files To Avoid:** `/home/tnnrpolley21/.codex/plugins/superpowers-project`, `/home/tnnrpolley21/.agents/skills/advanced-user-input`, plugin cache directories, unrelated `.chatgpt` audit inputs, old milestone-local canonical artifact roots, and unrelated generated run ledgers.
**Source Of Truth:** This plan plus `docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md` drive implementation; after cutover, GitHub Milestone fields and GitHub parent/sub-issue links own tracker structure, while local mirrors own execution readiness.
**Read Path:** Scripts read source plans, issue mirrors, tracker docs, roadmap JSON, GitHub issue JSON fixtures, `gh issue` command help, GitHub issue bodies, parent/sub-issue fields, labels, milestones, and project fields.
**Write Path:** Source edits happen only in this repo; local mirrors are written under `docs/superpowers/issues`; live install updates happen only through `scripts/sync-live.sh --validate`.
**Integration Points:** `gh issue create --parent`, `gh issue edit --add-sub-issue`, `gh issue view --json parent,subIssues,subIssuesSummary,milestone,labels,issueType`, `scripts/validate.sh`, `scripts/sync-live.sh`, create-issues mirror validation, resolve/orchestrate preflight, merge closeout, align tracker hygiene, loop candidate selection, workflow examples, and generated outcome docs.
**Migration Or Cutover:** Introduce hierarchy fields as optional for existing flat mirrors, require them for newly generated hierarchy mirrors, report historical title and hierarchy drift through `align-project`, and require native approval before any GitHub issue attachment, detachment, rename, or closeout action.
**Replaced Path Handling:** Displace title-encoded milestone tracking with GitHub Milestones and parent/sub-issue links; retain historical titles until an approved align-project migration explicitly changes them.
**Acceptance Proof Gate:** A worker cannot claim completion until targeted scripts pass, full repo validation passes, live-sync validation passes, version freshness passes, cleanup passes, and `git status --short --branch` shows only intentional committed state.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Hierarchy feature scope | User request | Integrate GitHub sub-issues across the workflow for grouped work. | Adds hierarchy support to issue creation, validation, execution guards, merge closeout, alignment, loop selection, and docs. | No | `create-issues` |
| Hierarchy optionality | User clarification | Projects and plans that do not need sub-issues stay flat. | Requires a `flat` mode and opt-out fixtures. | No | `create-issues` |
| Parent semantics | User clarification | Big parent issues act as pseudo sub-milestones inside real GitHub Milestones. | Parent and wrapper issues become rollup records, not executable implementation records. | No | `create-issues` |
| Title policy | User clarification | New issue titles must not include manual milestone names, milestone numbers, pseudo sub-milestone ordinals, or hierarchy ordering. | Adds clean-title validation before publication and align-project reporting for historical title drift. | No | `create-issues` |
| Tracker metadata location | User clarification and GitHub docs | GitHub Milestones, parent/sub-issue links, labels, issue types, and Project fields carry structure. | Keeps titles readable and avoids duplicating milestone identity in issue titles. | No | `setup-project` |
| Default hierarchy trigger | Native planning decision | Recommend hierarchy for grouped multi-issue plans. | `create-issues` should suggest issue-set mode when a plan creates multiple coordinated vertical slices. | No | `create-issues` |
| Depth model | Native planning decision | Support parent, optional plan-wrapper, and executable leaf levels. | Covers both single-plan issue sets and multi-plan pseudo sub-milestones. | No | `create-issues` |
| Execution boundary | Source spec | Only leaf issue mirrors can enter `resolve-issue` or `orchestrate-issues`. | Non-leaf records must fail before branch, worker, or PR setup. | No | `resolve-issue` |
| Migration policy | Native planning decision | Use selective migration with native approval. | `align-project` proposes repairs without mutating existing GitHub issues automatically. | No | `align-project` |
| GitHub mutation proof | Native planning decision | Use fixtures and dry commands during implementation; require native approval before real tracker mutation. | Tests can prove command shape without modifying GitHub state. | No | `create-issues` |
| Test completion | Native planning decision | Require targeted tests, full validation, live-sync validation, version freshness, cleanup, and clean Git proof. | Completion proof spans source, generated docs, deployed copy validation, and repository hygiene. | No | `merge-changes` |

## Acceptance Criteria

- [ ] New issue publication has a clean-title validator that rejects manual milestone names, milestone numbers, pseudo sub-milestone ordinals, and hierarchy ordering in titles.
- [ ] Tracker docs and roadmap metadata describe hierarchy labels or native issue types without requiring hierarchy for flat projects.
- [ ] `create-issues` supports `flat`, `issue-set`, and `sub-milestone` hierarchy modes.
- [ ] `create-issues` can produce dry GitHub command plans for parent, wrapper, and leaf publication order.
- [ ] Issue mirrors include hierarchy mode, role, executability, parent, child, rollup, and title-policy fields when hierarchy is present.
- [ ] External GitHub issue hydration reads `parent`, `subIssues`, and `subIssuesSummary` and writes mirror hierarchy fields.
- [ ] `resolve-issue` and `orchestrate-issues` reject parent and wrapper mirrors before execution setup.
- [ ] Leaf mirrors under a parent still pass direct and worker execution preflight when all required execution metadata is valid.
- [ ] `merge-changes` records parent or wrapper rollup evidence after leaf closeout and requires native approval before rollup closeout.
- [ ] `align-project` reports hierarchy drift, title drift, missing hierarchy labels/types, and selective migration candidates.
- [ ] `loop-controller` selects executable leaf issues for implementation and reserves parent or wrapper issues for align, closeout, or tracker repair routes.
- [ ] Workflow examples and generated docs show GitHub Milestones plus sub-issues as the tracking model, with clean issue titles.
- [ ] `scripts/validate.sh`, `scripts/sync-live.sh --validate`, version freshness, cleanup, and clean Git proof pass.

## Non-Goals

- Replace GitHub Milestones with parent issues.
- Require sub-issues for every project, plan, or issue.
- Bulk-rename historical issue titles without native approval.
- Use GitHub Projects as the source of truth for execution readiness.
- Let parent or wrapper issues run as implementation work.
- Edit deployed plugin copies directly.

## Proof Oracle

Run these commands from the repo root after implementation:

```bash
./skills/setup-project/scripts/test-scenarios.sh
./skills/create-issues/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/orchestrate-issues/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./skills/align-project/scripts/test-scenarios.sh
./skills/loop-controller/scripts/test-scenarios.sh
./scripts/test-workflow-examples.sh
./scripts/test-outcome-workflow-summary.sh
./scripts/test-tracker-roadmap-proof.sh
./scripts/validate.sh
./scripts/sync-live.sh --validate
./scripts/get-agent-plugin-version.sh
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
git status --short --branch
```

Expected final state: all commands exit 0, generated docs are current, live-sync validation passes, version freshness reports the source version, cleanup reports no repo-owned processes to stop, and Git status is clean after intentional commits.

## Issue Slices

Create six issue-backed slices from this plan:

1. Tracker vocabulary and clean-title policy.
2. Create-issues hierarchy schema, validators, and dry command builder.
3. Create-issues publication, hydration, and skill routing.
4. Leaf-only execution guards for direct and worker routes.
5. Merge rollup, align migration audit, and loop candidate selection.
6. Workflow examples, generated docs, validation wiring, live sync, and final proof.

## Task 1: Tracker Vocabulary And Clean-Title Policy

**Use Cases:**
- A flat project keeps using normal executable issues with GitHub Milestones and no parent issue.
- A grouped plan has hierarchy labels or issue types available before `create-issues` offers a parent issue.
- A new issue title that embeds milestone identity is rejected before any GitHub mutation.
- Cutover evidence shows milestone identity moved from title text into GitHub Milestone fields.

**Files:**
- Create: `skills/create-issues/scripts/validate-issue-title-policy.sh`
- Modify: `docs/agents/triage-labels.md`
- Modify: `docs/agents/project-roadmap.json`
- Modify: `docs/agents/project-roadmap.md`
- Modify: `docs/agents/issue-tracker.md`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/setup-project/scripts/prepare-github-project-board.sh`
- Modify: `skills/setup-project/scripts/test-scenarios.sh`
- Modify: `skills/create-issues/scripts/test-scenarios.sh`
- Modify: `scripts/test-tracker-roadmap-proof.sh`
- Modify: `scripts/validate-tracker-roadmap-proof.sh`
- Test: `skills/setup-project/scripts/test-scenarios.sh`
- Test: `skills/create-issues/scripts/test-scenarios.sh`
- Test: `scripts/test-tracker-roadmap-proof.sh`

- [ ] **Step 1: Add failing tracker vocabulary fixtures**
  - Add `skills/setup-project/scripts/test-scenarios.sh` assertions that require hierarchy identity to be represented by labels or native issue types such as `type:issue-set`, `type:sub-milestone`, and `type:plan-wrapper`.
  - Add `scripts/test-tracker-roadmap-proof.sh` assertions that roadmap JSON and Markdown list the hierarchy labels or their native issue-type equivalents.
  - Run: `./skills/setup-project/scripts/test-scenarios.sh`
  - Expected: failure naming missing hierarchy tracker vocabulary.

- [ ] **Step 2: Add clean-title failing fixtures**
  - Add `skills/create-issues/scripts/test-scenarios.sh` cases that call `validate-issue-title-policy.sh` with clean titles and with titles containing milestone numbers, milestone names from fixture data, pseudo sub-milestone ordinals, bracketed milestone tags, and leading hierarchy numbers.
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Expected: failure because `validate-issue-title-policy.sh` does not exist yet.

- [ ] **Step 3: Implement the title policy validator**
  - Create `skills/create-issues/scripts/validate-issue-title-policy.sh` with parameters `-Title`, `-KnownMilestoneTitles`, `-KnownMilestoneNumbers`, and `-Json`.
  - Reject titles matching approved fixture patterns for manual milestone numbers, exact milestone names, bracketed milestone tags, pseudo sub-milestone ordinals, and leading hierarchy numbering.
  - Return a JSON receipt with `ok`, `phase`, `title`, and `reason` when `-Json` is passed.

- [ ] **Step 4: Update tracker docs and setup metadata**
  - Update `docs/agents/triage-labels.md`, `docs/agents/project-roadmap.json`, `docs/agents/project-roadmap.md`, and `docs/agents/issue-tracker.md` to describe optional hierarchy identity.
  - Update `skills/setup-project/SKILL.md` and `skills/setup-project/agents/openai.yaml` so setup verifies hierarchy capability only when hierarchy is enabled for the target repo.
  - Update `skills/setup-project/scripts/prepare-github-project-board.sh` to include hierarchy tracker proof in its dry board preparation receipt.

- [ ] **Step 5: Validate and commit**
  - Run: `./skills/setup-project/scripts/test-scenarios.sh`
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Run: `./scripts/test-tracker-roadmap-proof.sh`
  - Commit: `git add docs/agents docs/superpowers/PROJECT_CONTEXT.md skills/setup-project skills/create-issues/scripts/test-scenarios.sh skills/create-issues/scripts/validate-issue-title-policy.sh scripts/test-tracker-roadmap-proof.sh scripts/validate-tracker-roadmap-proof.sh && git commit -m "feat: add clean title hierarchy tracker policy"`

## Task 2: Create-Issues Hierarchy Schema And Validators

**Use Cases:**
- A flat mirror stays valid without parent or child fields when no hierarchy is present.
- A parent or wrapper mirror records `Executable: false` and rollup policy.
- A leaf mirror records `Executable: true`, a valid parent link, and existing execution metadata.
- Validator evidence catches mirror/GitHub parent-child drift before cutover to execution.

**Files:**
- Create: `skills/create-issues/scripts/lib/issue-hierarchy.sh`
- Create: `skills/create-issues/scripts/validate-issue-hierarchy.sh`
- Create: `skills/create-issues/scripts/build-issue-hierarchy-plan.sh`
- Modify: `skills/create-issues/scripts/validate-issue-mirror.sh`
- Modify: `skills/create-issues/scripts/test-scenarios.sh`
- Test: `skills/create-issues/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing mirror schema tests**
  - Add fixtures for valid flat mirror, valid parent mirror, valid plan-wrapper mirror, valid leaf mirror under a parent, invalid parent with `Executable: true`, invalid leaf with missing parent, invalid leaf with `Rollup Policy: all-required-children-closed`, and invalid hierarchy mode values.
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Expected: failure naming missing hierarchy field validation.

- [ ] **Step 2: Add failing dry command builder tests**
  - Add fixtures for a grouped multi-issue plan that should produce parent first and leaves second.
  - Add fixtures for a pseudo sub-milestone plan that should produce parent, wrapper, then leaves.
  - Assert dry command output includes `gh issue create --parent` for new child issues and `gh issue edit --add-sub-issue` for existing child attachment.
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Expected: failure because the hierarchy planner does not exist yet.

- [ ] **Step 3: Implement shared hierarchy helpers**
  - Create `skills/create-issues/scripts/lib/issue-hierarchy.sh` with functions for reading field values, normalizing hierarchy mode, normalizing role, checking executable role consistency, checking rollup policy, and parsing GitHub hierarchy fixture JSON.
  - Keep helper output as typed Bash objects so callers do not parse text receipts.

- [ ] **Step 4: Implement hierarchy validation**
  - Create `skills/create-issues/scripts/validate-issue-hierarchy.sh` with parameters `-IssueMirrorPath`, `-GitHubIssueFixturePath`, `-MilestoneRequired`, and `-Json`.
  - Validate `Hierarchy Mode`, `Sub-Issue Role`, `Executable`, `Parent Issue`, `Parent Mirror`, `Child Issues`, `Rollup Policy`, and `Title Policy`.
  - When GitHub fixture data is present, compare mirror parent and child fields to `parent`, `subIssues`, and `subIssuesSummary`.

- [ ] **Step 5: Extend mirror validation**
  - Update `skills/create-issues/scripts/validate-issue-mirror.sh` to call the hierarchy validator when hierarchy fields are present.
  - Preserve existing validation for outcome proof, classification, goal command, workflow metadata, merge metadata, and bug repro fields.

- [ ] **Step 6: Implement dry hierarchy planner**
  - Create `skills/create-issues/scripts/build-issue-hierarchy-plan.sh` with parameters for source plan path, hierarchy mode, GitHub milestone title, parent title, wrapper titles, leaf titles, existing child issue URLs, labels, issue types, and `-Json`.
  - Validate every title with `validate-issue-title-policy.sh`.
  - Emit publication order, mirror field payloads, and dry `gh` commands without modifying GitHub.

- [ ] **Step 7: Validate and commit**
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Commit: `git add skills/create-issues/scripts && git commit -m "feat: validate issue hierarchy mirrors"`

## Task 3: Create-Issues Publication, Hydration, And Routing

**Use Cases:**
- `create-issues` recommends issue-set mode for a grouped multi-issue plan and asks native approval before publication.
- A pseudo sub-milestone creates clean-title parent, wrapper, and leaf mirrors in the same order as dry GitHub commands.
- External issue hydration reads GitHub hierarchy fields and repairs local mirror metadata before execution.
- Publication cutover is blocked when approved hierarchy metadata cannot be represented in GitHub.

**Files:**
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/hydrate-external-issue.sh`
- Modify: `skills/create-issues/scripts/test-scenarios.sh`
- Create: `docs/superpowers/examples/sub-issues-workflow-examples.md`
- Test: `skills/create-issues/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing route and hydration fixtures**
  - Add native-question fixture expectations for hierarchy mode, parent title, wrapper use, child list, labels/types, milestone, publication order, and mutation approval.
  - Add hydration fixture JSON with `parent`, `subIssues`, `subIssuesSummary`, `milestone`, `labels`, and `issueType`.
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Expected: failure naming missing hierarchy routing and hydration support.

- [ ] **Step 2: Update create-issues instructions**
  - Update `skills/create-issues/SKILL.md` to define `flat`, `issue-set`, and `sub-milestone` creation paths.
  - Add native approval gates for hierarchy mode, parent issue title, wrapper issue titles, child list, GitHub Milestone, labels or issue types, and live mutation.
  - State that clean-title validation runs before any GitHub mutation.

- [ ] **Step 3: Update compact skill metadata**
  - Update `skills/create-issues/agents/openai.yaml` so agents know hierarchy exists, but still read `SKILL.md` for route details.
  - Keep metadata concise and avoid embedding a second route tree.

- [ ] **Step 4: Extend external issue hydration**
  - Update `skills/create-issues/scripts/hydrate-external-issue.sh` so `gh issue view` requests `body,parent,subIssues,subIssuesSummary,milestone,labels,issueType,title,url,number`.
  - Write hierarchy fields into the local mirror.
  - Validate hydrated mirrors through `validate-issue-mirror.sh` before downstream routing.

- [ ] **Step 5: Add examples**
  - Create or update `docs/superpowers/examples/sub-issues-workflow-examples.md` with flat, issue-set, pseudo sub-milestone, hydration, and selective migration examples.
  - Ensure example issue titles are clean and GitHub Milestone fields carry milestone identity.

- [ ] **Step 6: Validate and commit**
  - Run: `./skills/create-issues/scripts/test-scenarios.sh`
  - Commit: `git add skills/create-issues docs/superpowers/examples/sub-issues-workflow-examples.md && git commit -m "feat: route create issues through github hierarchy"`

## Task 4: Leaf-Only Execution Guards

**Use Cases:**
- A parent mirror fails `resolve-issue` preflight before branch setup.
- A plan-wrapper mirror fails worker handoff before creating any worker state.
- A leaf mirror under a parent still resolves inline when all execution metadata is valid.
- Execution cutover evidence proves old flat mirrors still run while non-leaf hierarchy records cannot run.

**Files:**
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/scripts/preflight.sh`
- Modify: `skills/resolve-issue/scripts/prepare-execution.sh`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/scripts/prepare-worker-handoff.sh`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.sh`
- Test: `skills/resolve-issue/scripts/test-scenarios.sh`
- Test: `skills/orchestrate-issues/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing direct execution guard tests**
  - Add parent, wrapper, leaf-with-parent, and old flat mirror fixtures to `skills/resolve-issue/scripts/test-scenarios.sh`.
  - Assert parent and wrapper mirrors fail with reasons naming role and `Executable: false`.
  - Run: `./skills/resolve-issue/scripts/test-scenarios.sh`
  - Expected: failure because non-leaf mirrors are not blocked yet.

- [ ] **Step 2: Add failing worker execution guard tests**
  - Add equivalent fixtures to `skills/orchestrate-issues/scripts/test-scenarios.sh`.
  - Assert worker identity is derived only for leaf mirrors.
  - Run: `./skills/orchestrate-issues/scripts/test-scenarios.sh`
  - Expected: failure because non-leaf mirrors are not blocked yet.

- [ ] **Step 3: Implement direct route guard**
  - Update `skills/resolve-issue/scripts/preflight.sh` and `skills/resolve-issue/scripts/prepare-execution.sh` to reject mirrors where `Sub-Issue Role` is `parent` or `plan-wrapper`, or where `Executable` is `false`.
  - Allow old flat mirrors with no hierarchy fields to use the current validation path.
  - Update `skills/resolve-issue/SKILL.md` with the leaf-only contract.

- [ ] **Step 4: Implement worker route guard**
  - Update `skills/orchestrate-issues/scripts/prepare-worker-handoff.sh` to reject non-leaf hierarchy records before worker packet creation.
  - Update `skills/orchestrate-issues/SKILL.md` with the same leaf-only contract.

- [ ] **Step 5: Validate and commit**
  - Run: `./skills/resolve-issue/scripts/test-scenarios.sh`
  - Run: `./skills/orchestrate-issues/scripts/test-scenarios.sh`
  - Commit: `git add skills/resolve-issue skills/orchestrate-issues && git commit -m "feat: enforce leaf only issue execution"`

## Task 5: Merge Rollup, Align Migration Audit, And Loop Selection

**Use Cases:**
- A leaf closeout records parent and wrapper rollup evidence without closing rollup issues automatically.
- A parent or wrapper closes only after all required children are closed or explicitly skipped and native approval is recorded.
- `align-project` reports historical title drift and parent-child drift as selective migration candidates.
- `loop-controller` selects executable leaf issues for implementation and reports non-leaf items for tracker repair or rollup closeout.

**Files:**
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/scripts/collect-closeout-ledger.sh`
- Modify: `skills/merge-changes/scripts/closeout.sh`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Modify: `skills/align-project/SKILL.md`
- Modify: `skills/align-project/scripts/align-project.sh`
- Modify: `skills/align-project/scripts/test-scenarios.sh`
- Modify: `skills/loop-controller/SKILL.md`
- Modify: `skills/loop-controller/scripts/select-candidate.sh`
- Modify: `skills/loop-controller/scripts/test-scenarios.sh`
- Test: `skills/merge-changes/scripts/test-scenarios.sh`
- Test: `skills/align-project/scripts/test-scenarios.sh`
- Test: `skills/loop-controller/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing merge rollup tests**
  - Add fixtures where a closed leaf has open siblings, all siblings closed, and one child intentionally skipped with evidence.
  - Assert closeout receipts include parent URL, wrapper URL when present, child counts, open child list, skipped child list, and native approval requirement for rollup closeout.
  - Run: `./skills/merge-changes/scripts/test-scenarios.sh`
  - Expected: failure naming missing hierarchy rollup evidence.

- [ ] **Step 2: Add failing align and loop tests**
  - Add `align-project` fixtures for missing hierarchy labels/types, GitHub parent-child drift, local mirror drift, and historical title drift.
  - Add `loop-controller` fixtures proving non-leaf hierarchy records are excluded from implementation candidate selection.
  - Run: `./skills/align-project/scripts/test-scenarios.sh`
  - Run: `./skills/loop-controller/scripts/test-scenarios.sh`
  - Expected: failures naming missing hierarchy audit and selection behavior.

- [ ] **Step 3: Implement merge rollup receipts**
  - Update `skills/merge-changes/scripts/collect-closeout-ledger.sh` to collect `parent`, `subIssues`, and `subIssuesSummary` from GitHub JSON or fixtures.
  - Update `skills/merge-changes/scripts/closeout.sh` to record rollup state and require approval before parent or wrapper closeout.
  - Update `skills/merge-changes/SKILL.md` with explicit rollup closeout rules.

- [ ] **Step 4: Implement align-project hierarchy audit**
  - Update `skills/align-project/scripts/align-project.sh` to report hierarchy label/type gaps, GitHub/local parent-child drift, title drift, and selective migration candidates.
  - Update `skills/align-project/SKILL.md` to require proposed parent, children, labels/types, milestone, title changes, and approval gate before GitHub mutation.

- [ ] **Step 5: Implement loop leaf selection**
  - Update `skills/loop-controller/scripts/select-candidate.sh` to prefer executable leaf issues for implementation candidates and report parent or wrapper records as rollup or tracker-maintenance candidates.
  - Update `skills/loop-controller/SKILL.md` to define the selection boundary.

- [ ] **Step 6: Validate and commit**
  - Run: `./skills/merge-changes/scripts/test-scenarios.sh`
  - Run: `./skills/align-project/scripts/test-scenarios.sh`
  - Run: `./skills/loop-controller/scripts/test-scenarios.sh`
  - Commit: `git add skills/merge-changes skills/align-project skills/loop-controller && git commit -m "feat: add hierarchy rollup and audit routes"`

## Task 6: Workflow Examples, Generated Docs, And Validation Wiring

**Use Cases:**
- A new maintainer can read examples and understand that GitHub Milestones carry milestone tracking while titles stay clean.
- Generated workflow docs include sub-issue hierarchy without duplicating route trees.
- Full validation catches stale examples, stale generated outcome docs, and missing hierarchy tests.
- Cutover proof includes live-sync validation and cleanup before completion.

**Files:**
- Modify: `docs/superpowers/examples/workflow-golden-paths.md`
- Modify: `docs/superpowers/examples/sub-issues-workflow-examples.md`
- Modify: `scripts/validate-workflow-examples.sh`
- Modify: `scripts/test-workflow-examples.sh`
- Modify: `scripts/generate-outcome-workflow-summary.sh`
- Modify: `scripts/test-outcome-workflow-summary.sh`
- Modify: `scripts/validate.sh`
- Modify: `README.md`
- Test: `scripts/test-workflow-examples.sh`
- Test: `scripts/test-outcome-workflow-summary.sh`
- Test: `scripts/validate.sh`

- [ ] **Step 1: Add failing example tests**
  - Add workflow example assertions for flat mode, issue-set mode, pseudo sub-milestone mode, hydration, rollup closeout, and selective migration.
  - Assert examples use clean titles and put milestone identity in GitHub Milestone fields.
  - Run: `./scripts/test-workflow-examples.sh`
  - Expected: failure naming missing sub-issue examples.

- [ ] **Step 2: Update examples and generated docs**
  - Update `docs/superpowers/examples/workflow-golden-paths.md` and `docs/superpowers/examples/sub-issues-workflow-examples.md`.
  - Update `scripts/generate-outcome-workflow-summary.sh` and `README.md` with the GitHub-native hierarchy model.
  - Regenerate `docs/superpowers/OUTCOME_WORKFLOW.md` through the existing generator.

- [ ] **Step 3: Wire validation**
  - Update `scripts/validate.sh` so the relevant hierarchy scenario tests and workflow example tests are part of full repo validation.
  - Keep each targeted test runnable on its own for issue-slice proof.

- [ ] **Step 4: Run final source validation**
  - Run every command listed in the Proof Oracle except live sync first.
  - Fix any failure in the owning slice before proceeding.

- [ ] **Step 5: Validate live sync and cleanup**
  - Run: `./scripts/sync-live.sh --validate`
  - Run: `./scripts/get-agent-plugin-version.sh`
  - Run: `"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .`
  - Run: `git status --short --branch`
  - Expected: live-sync validation passes, version freshness reports the source version, cleanup reports no repo-owned process cleanup needed, and Git status is clean after committed work.

- [ ] **Step 6: Commit final docs and validation wiring**
  - Commit: `git add docs/superpowers/examples docs/superpowers/OUTCOME_WORKFLOW.md scripts README.md && git commit -m "docs: document github sub issue workflow"`

## Implementation Notes

- Use `superpowers:test-driven-development` for each feature slice.
- Use `superpowers:verification-before-completion` before any worker claims a slice complete.
- For live GitHub mutation, show the exact planned `gh` commands and require native approval before running them.
- Keep old flat mirrors valid unless a separate approved migration updates them.
- Keep canonical artifacts under flat `docs/superpowers/specs`, `docs/superpowers/plans`, and `docs/superpowers/issues` roots.
