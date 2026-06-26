# Decision Ledger Examples

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/89
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md
**Source Plan:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md
**Classification:** AFK
**Labels:** type:task, status:blocked
**Goal Command:** /goal Resolve Decision Ledger Examples using docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md and docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md. Complete acceptance criteria and proof oracle, then hand off to merge-changes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md#outcome-proof
**Intent:** Add practical spec and plan Decision Ledger examples that validate and are referenced by brainstorm-spec and write-plan.
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

Add practical spec and plan Decision Ledger examples that validate and are referenced by brainstorm-spec and write-plan.

## Acceptance Criteria

- [ ] Decision Ledger examples file exists.
- [ ] Spec-style and plan-style examples validate.
- [ ] Examples include user answer, repo evidence, planning grill, and deferred decision sources.
- [ ] Deferred example includes concrete risk owner and downstream impact.
- [ ] brainstorm-spec and write-plan reference the examples.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/87

## Non-goals

- Create a new workflow skill.
- Bypass issue-backed execution or merge closeout.
- Treat generated runtime state as canonical documentation.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-decision-ledger.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-decision-ledger.ps1 -Path .\docs\superpowers\specs\2026-06-26-score-9-loop-mode-hardening-spec.md -Kind spec`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-decision-ledger.ps1 -Path .\docs\superpowers\plans\2026-06-26-score-9-loop-mode-hardening-plan.md -Kind plan`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

