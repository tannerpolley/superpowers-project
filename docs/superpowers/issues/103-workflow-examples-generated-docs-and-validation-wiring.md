# Workflow Examples, Generated Docs, And Validation Wiring
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/103
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve issue: Workflow Examples, Generated Docs, And Validation Wiring using docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** leaf
**Executable:** true
**Parent Issue:** https://github.com/tannerpolley/superpowers-project/issues/97
**Parent Mirror:** docs/superpowers/issues/97-github-sub-issues-workflow.md
**Child Issues:** None
**Rollup Policy:** none
**Title Policy:** Clean GitHub title
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary
**Outcome Source:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md#outcome-proof
**Intent:** Document the GitHub-native hierarchy workflow and wire full validation and live-sync proof.
**Target Output:** Updated examples, generated outcome docs, README, validation wiring, and final proof receipts.
**Owner:** docs/superpowers/examples, scripts/validate.ps1, generated outcome docs, and README.md
**Interface:** Workflow examples, generated Markdown, root validation, live-sync validation, and cleanup proof.
**Cutover:** Make hierarchy examples and validators part of normal repo validation.
**Replaced Path:** Docs that describe only flat issue workflows for grouped plans.
**Acceptance Proof:** workflow examples, outcome summary tests, tracker proof, full validation, live sync, version freshness, cleanup, and Git status pass.
**Stop Criteria:** Stop if generated docs are stale, live-sync validation fails, or Git status contains unintended changes.
**Avoid:** Do not claim final completion without source validation, live-sync validation, cleanup, and clean Git proof.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Update examples, generated docs, README, and validation wiring for the hierarchy workflow.

## GitHub Parent/Sub-Issue Contract

- Examples must show the same model users see in GitHub: parent issue with a Sub-issues section, nested child rows, progress summary, and parent links on child issues.
- Docs must distinguish GitHub Milestones from pseudo sub-milestone parent issues: milestones track roadmap buckets, parent issues group work inside a milestone.
- Validation must prove flat, issue-set, and pseudo sub-milestone workflows end with clean titles and synchronized GitHub/local hierarchy metadata.
- Final proof must include source validation, live-sync validation, version freshness, cleanup, clean Git state, and GitHub parent progress.

## Acceptance Criteria

- [ ] Examples cover flat, issue-set, pseudo sub-milestone, hydration, rollup, and migration.
- [ ] Examples include GitHub UI concepts: Sub-issues section, child parent link, nested rows, and progress count.
- [ ] Generated docs are current.
- [ ] Full validation and live-sync validation pass.
- [ ] Cleanup and Git status proof are recorded.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/102

## Non-goals

- Do unrelated refactors.
- Edit deployed plugin copies directly.
- Bypass the proof oracle.

## Proof Oracle

- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-outcome-workflow-summary.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
