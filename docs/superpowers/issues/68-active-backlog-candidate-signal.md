# Clean Active Backlog And Candidate Signal

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/68
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Add an active backlog source and candidate validator so Loop Controller ignores historical checklist noise.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Make Loop Controller candidate selection focus on active work instead of historical plan checkboxes.
**Target Output:** Maintainers can inspect an active backlog source and candidate validation returns only eligible active items.
**Owner:** `docs/superpowers/backlog/ACTIVE.md` or the selected active backlog file owns active candidate inventory.
**Interface:** Loop Controller and validators read active candidate entries with source artifact, route owner, priority, status, and proof target.
**Cutover:** Active backlog entries become the normal candidate source for maintenance selection.
**Replaced Path:** Historical plan checkbox scans stop being the normal backlog signal.
**Acceptance Proof:** Active-backlog tests, loop-controller scenario tests, and repo validation pass.
**Stop Criteria:** Stop before merge if candidate selection returns archived, implemented, or generated run-state entries as normal active work.
**Avoid:** Do not make local `.superpowers/runs/**` ledgers canonical backlog entries.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add an active backlog source and update loop-controller candidate selection tests to exclude historical noise.

## Acceptance Criteria

- [ ] Active backlog source exists under `docs/superpowers/backlog/`.
- [ ] Candidate entries include route owner, source artifact, priority, status, and proof target.
- [ ] Historical plan checkboxes do not become normal candidates.
- [ ] Loop Controller tests cover archived historical checkboxes and one active item.
- [ ] Active-backlog validation runs from `scripts/validate.ps1`.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/63

## Non-goals

- Do not move existing canonical specs, plans, or issues.
- Do not create a GitHub Project requirement.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-active-backlog.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Add an active backlog source and candidate validation so Loop Controller selects real current work instead of historical checklist noise.
