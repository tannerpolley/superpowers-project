# Merge Rollup, Align Migration Audit, And Loop Selection
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/102
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve issue: Merge Rollup, Align Migration Audit, And Loop Selection using docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
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
**Intent:** Add rollup closeout evidence, selective migration audit, and leaf-only loop candidate selection.
**Target Output:** merge-changes rollup receipts, align-project hierarchy audit, and loop-controller leaf selection.
**Owner:** skills/merge-changes, skills/align-project, and skills/loop-controller
**Interface:** Closeout ledger JSON, align reports, and loop candidate receipts.
**Cutover:** Use rollup evidence for parent closeout and reserve parent or wrapper issues for repair or rollup routes.
**Replaced Path:** Leaf closeout that does not report parent progress and loop selection that cannot distinguish rollup records.
**Acceptance Proof:** merge, align, and loop-controller scenario tests pass for rollup, drift, and candidate selection.
**Stop Criteria:** Stop if parent closeout can happen without required child proof or if loop selection chooses a non-leaf implementation issue.
**Avoid:** Do not automatically rename or reparent historical issues during audit.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Implement hierarchy rollup receipts, align-project drift reporting, and loop-controller leaf filtering.

## Acceptance Criteria

- [ ] Leaf closeout records parent and child state.
- [ ] Parent closeout requires child proof and native approval.
- [ ] align-project reports title and hierarchy drift.
- [ ] loop-controller excludes parent and wrapper implementation candidates.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/100
- https://github.com/tannerpolley/superpowers-project/issues/101

## Non-goals

- Do unrelated refactors.
- Edit deployed plugin copies directly.
- Bypass the proof oracle.

## Proof Oracle

- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\test-scenarios.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
