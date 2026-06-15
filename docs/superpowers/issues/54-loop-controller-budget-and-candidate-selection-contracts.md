# Add Loop Controller budget and candidate selection contracts

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/54
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md
**Source Plan:** docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/54-loop-controller-budget-and-candidate-selection-contracts.md using docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md Tasks 3 and 4 after https://github.com/tannerpolley/superpowers-project/issues/53 is complete.
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

Add budget validation and candidate selection contracts so the Loop Controller can stop exhausted runs and choose deterministic safe candidates from local fixture inventories.

## Acceptance Criteria

- [ ] Budget validator rejects exhausted candidate, retry, same-failure, mutation, validator rerun, changed-file, and diff-size budgets.
- [ ] Budget validator accepts a low-risk fixture within policy.
- [ ] Candidate selector chooses the deterministic low-risk ready candidate from a fixture inventory.
- [ ] Skipped candidates include concrete reasons.
- [ ] No live GitHub mutation is required in tests.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/53

## Non-goals

- Do not add verifier, terminal closeout, or metrics contracts in this issue.
- Do not create scheduled automation entrypoints.
- Do not execute selected candidates against real GitHub issues.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`

