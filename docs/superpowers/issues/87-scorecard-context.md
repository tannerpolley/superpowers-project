# Scorecard Proof Receipt And Project Context Narrative

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/87
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md
**Source Plan:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve Scorecard Proof Receipt And Project Context Narrative using docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md and docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md. Complete acceptance criteria and proof oracle, then hand off to merge-changes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md#outcome-proof
**Intent:** Record validator-backed 9+ score evidence and clarify the source-of-truth roles of contract, backlog, examples, receipts, .chatgpt, and .superpowers.
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

Record validator-backed 9+ score evidence and clarify the source-of-truth roles of contract, backlog, examples, receipts, .chatgpt, and .superpowers.

## Acceptance Criteria

- [x] Scorecard receipt exists and validates every target area at >= 9.
- [x] Receipt includes command receipts and source artifact links.
- [x] M0 and M1 milestone pages link the receipt.
- [x] Project context and README explain contract, active backlog, examples, receipts, .chatgpt, and .superpowers roles.
- [x] Docs do not call .chatgpt or .superpowers canonical project docs.

## Implementation Receipt

- Added `docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md` with scorecard rows, command receipts, source artifact links, Looping Mode proof, live sync/tracker proof, and source-role notes.
- Added `scripts/validate-scorecard-proof.ps1` and `scripts/test-scorecard-proof.ps1` with fixtures for valid receipts, below-9 targets, missing command receipts, missing loop proof, and generated-state canonical claims.
- Linked the receipt from `docs/superpowers/milestones/M0-governance.md` and `docs/superpowers/milestones/M1-source-of-truth.md`.
- Updated `README.md`, `docs/superpowers/PROJECT_CONTEXT.md`, and generated `docs/superpowers/OUTCOME_WORKFLOW.md` to explain workflow contract, active backlog, examples, packet examples, receipts, `.chatgpt/**`, and `.superpowers/**` roles.
- Wired scorecard proof validation into `scripts/validate.ps1`.

## Blocked by

- None

## Non-goals

- Create a new workflow skill.
- Bypass issue-backed execution or merge closeout.
- Treat generated runtime state as canonical documentation.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-scorecard-proof.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-scorecard-proof.ps1 -RepoRoot .`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
