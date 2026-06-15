# Validate Loop Controller contract summary and live-sync readiness

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/56
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md
**Source Plan:** docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/56-validate-loop-controller-contract-summary-and-live-sync-readiness.md using docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md Task 7 after https://github.com/tannerpolley/superpowers-project/issues/55 is complete.
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

Regenerate and validate the contract summary, run focused Loop Controller proof, full source validation, live-sync validation, and cleanup proof for the contracts-first Loop Controller slice.

## Acceptance Criteria

- [ ] Plan Task # Use Cases validator passes for the Loop Controller plan.
- [ ] Contract summary includes `loop-controller`, `project_loop_next_step`, and `project_loop_final_health_gate`.
- [ ] Focused Loop Controller tests pass.
- [ ] Full repo validation passes.
- [ ] `scripts/sync-live.ps1 -Validate` passes.
- [ ] Cleanup hook reports no matching leftover repo-owned processes.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/55

## Non-goals

- Do not add new Loop Controller behavior beyond validation closeout.
- Do not publish releases or tags.
- Do not bypass native live-sync, push, merge, or final Done gates.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-contract-summary.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
