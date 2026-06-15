# Add Loop Controller skill and run-ledger contract

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/53
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md
**Source Plan:** docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/53-loop-controller-skill-and-run-ledger-contract.md using docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md Tasks 1 and 2.
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

Add the loop-controller skill contract, metadata, plugin/docs registration, validation wiring, run-ledger shared library, run-ledger validator, and focused run-ledger scenario coverage.

## Acceptance Criteria

- [ ] `$superpowers-project:loop-controller` skill and metadata exist.
- [ ] README, PROJECT_CONTEXT, plugin prompt, changelog, validation, and final-capable contract are updated.
- [ ] Run-ledger shared library and validator exist under `skills/loop-controller/scripts`.
- [ ] Run-ledger scenarios prove valid ledgers pass and missing required fields fail.
- [ ] Focused Loop Controller contract and scenario tests pass.

## Blocked by

- None

## Non-goals

- Do not add budget, candidate, verifier, terminal, or metrics validators in this issue.
- Do not add scheduled automation behavior.
- Do not sync live or merge without the owning approval gates.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`

