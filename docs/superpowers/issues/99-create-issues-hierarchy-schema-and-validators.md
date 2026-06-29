# Create-Issues Hierarchy Schema And Validators
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/99
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve issue: Create-Issues Hierarchy Schema And Validators using docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
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
**Intent:** Add hierarchy mirror fields, validators, and dry command planning for flat, issue-set, and pseudo sub-milestone modes.
**Target Output:** Reusable hierarchy helper scripts, mirror validation, and dry publication receipts.
**Owner:** skills/create-issues/scripts/lib/issue-hierarchy.ps1 and create-issues validators
**Interface:** Issue mirror fields, validator JSON, and dry GitHub command plans.
**Cutover:** Require hierarchy role and executability metadata when create-issues generates hierarchy mirrors.
**Replaced Path:** Flat-only mirror validation for grouped plans.
**Acceptance Proof:** create-issues scenario tests pass for flat, parent, wrapper, leaf, invalid role, and dry command fixtures.
**Stop Criteria:** Stop if parent or wrapper mirrors validate as executable or GitHub fixture parity is not checked.
**Avoid:** Do not parse issue hierarchy with ad hoc string checks when structured helpers can own the logic.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Create shared hierarchy helpers, hierarchy validator, and dry hierarchy planning script.

## GitHub Parent/Sub-Issue Contract

- Model GitHub's real parent/sub-issue shape, including parent links on child issues, nested child rows on parent issues, and `subIssuesSummary` progress.
- Treat `flat`, `issue-set`, and `sub-milestone` as explicit hierarchy modes; flat mirrors stay valid without parent fields.
- Treat `parent` and `plan-wrapper` mirrors as rollup records with `Executable: false`.
- Treat `leaf` mirrors as the only executable hierarchy records and require a valid parent link when hierarchy is active.
- Validate mirror fields against GitHub JSON fixture fields instead of relying only on title text or local checklist state.

## Acceptance Criteria

- [ ] Flat mirrors remain valid.
- [ ] Parent and wrapper mirrors require Executable false.
- [ ] Leaf mirrors require Executable true and parent metadata.
- [ ] GitHub fixture parity checks compare mirror parent and child fields to `parent`, `subIssues`, and `subIssuesSummary`.
- [ ] Dry commands include parent-first publication order and child attachment order.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/98

## Non-goals

- Do unrelated refactors.
- Edit deployed plugin copies directly.
- Bypass the proof oracle.

## Proof Oracle

- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
