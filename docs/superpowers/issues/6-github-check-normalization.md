# Normalize GitHub check states consistently

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/6
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/6 from docs/superpowers/issues/6-github-check-normalization.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/github-check-normalization
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Create a shared GitHub check normalization helper and use it in merge gates so skipped, failed, pending, and successful checks are interpreted consistently.

## Acceptance Criteria

- [ ] `scripts/lib/github-checks.ps1` exists with shared normalization helpers.
- [ ] Skipped optional checks pass only when explicitly optional.
- [ ] Skipped required checks block.
- [ ] Pending, failed, cancelled, timed-out, or missing required checks block.
- [ ] `$project-merge` premerge uses the shared helper instead of loose regex matching.

## Blocked by

- None

## Non-goals

- Do not weaken required-check enforcement.
- Do not depend on live GitHub network for unit fixtures.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-github-checks.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
