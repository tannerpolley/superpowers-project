# Leaf-Only Execution Guards
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/101
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve issue: Leaf-Only Execution Guards using docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
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
**Intent:** Prevent parent and wrapper issues from entering direct or worker execution routes.
**Target Output:** resolve-issue and orchestrate-issues reject non-leaf hierarchy records while old flat mirrors still execute.
**Owner:** skills/resolve-issue and skills/orchestrate-issues preflight scripts
**Interface:** Preflight receipts and worker handoff validation.
**Cutover:** Use Sub-Issue Role and Executable fields as execution gates when hierarchy metadata is present.
**Replaced Path:** Execution preflight that treats every valid mirror as runnable work.
**Acceptance Proof:** resolve-issue and orchestrate-issues scenario tests pass for parent, wrapper, leaf, and flat mirrors.
**Stop Criteria:** Stop if a parent or wrapper mirror can create a branch, worker packet, or PR-ready state.
**Avoid:** Do not block old flat mirrors that lack hierarchy fields but otherwise pass current validation.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add leaf-only guards to direct and worker issue execution paths.

## Acceptance Criteria

- [ ] Parent mirrors fail direct execution preflight.
- [ ] Wrapper mirrors fail worker handoff preparation.
- [ ] Leaf mirrors under a parent pass when execution metadata is valid.
- [ ] Existing flat mirrors remain compatible.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/99

## Non-goals

- Do unrelated refactors.
- Edit deployed plugin copies directly.
- Bypass the proof oracle.

## Proof Oracle

- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
