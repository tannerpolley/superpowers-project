# Looping Mode State Machine

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/86
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md
**Source Plan:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve Looping Mode State Machine using docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md and docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md. Complete acceptance criteria and proof oracle, then hand off to merge-changes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md#outcome-proof
**Intent:** Make Looping Mode a strict validated coordinator with phase order, one-candidate iteration, budget recheck, and continuation gates.
**Target Output:** A validator-backed source change that satisfies the score 9+ hardening slice and can be merged independently.
**Owner:** Superpowers Project source repo workflow contracts, skills, docs, and validators touched by this slice.
**Interface:** Issue mirror acceptance criteria, proof oracle commands, GitHub issue state, and merge closeout receipts consumed by downstream workflow agents.
**Cutover:** Replace loose or drift-prone behavior with validated source-owned contracts and remove obsolete prose or summaries for this slice.
**Replaced Path:** The audit-identified weak behavior for this slice stops being accepted as sufficient proof.
**Acceptance Proof:** Focused proof oracle commands pass, followed by repo validation for the changed surface.
**Stop Criteria:** Stop before merge if any focused validator fails, if source/live proof is incomplete when required, or if the slice weakens native workflow gates.
**Avoid:** Do not weaken native gates, do not treat .chatgpt or .superpowers as canonical docs, and do not add duplicate source-of-truth surfaces.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Make Looping Mode a strict validated coordinator with phase order, one-candidate iteration, budget recheck, and continuation gates.

## Acceptance Criteria

- [x] Loop phases and invariants are documented in source-owned contract.
- [x] Loop state-machine validator exists and is wired into validation.
- [x] Second candidate selection is blocked until project_loop_next_step is recorded.
- [x] Auto Mode authorization cannot drive Looping Mode queue draining.
- [x] No-ready, budget-exhausted, dirty-repo, owner-mismatch, and historical-checkbox fixtures pass or fail correctly.

## Implementation Receipt

- Added `docs/superpowers/loop-mode-contract.yml` as the source-owned Looping Mode phase and invariant contract.
- Added `skills/loop-controller/scripts/validate-loop-state-machine.ps1` to enforce one-candidate iterations, continuation gates, budget checks, clean-repo gates, no-ready proof, owner routing, historical checkbox handling, Auto Mode separation, and final Done proof.
- Wired the state-machine validator into loop-controller docs, scenario fixtures, golden-path example validation, and `scripts/validate.ps1`.
- Verified the focused proof oracle with `scripts/test-loop-controller.ps1`, `skills/loop-controller/scripts/test-scenarios.ps1`, `scripts/validate-workflow-examples.ps1`, and `git diff --check`.

## Blocked by

- None

## Non-goals

- Create a new workflow skill.
- Bypass issue-backed execution or merge closeout.
- Treat generated runtime state as canonical documentation.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
