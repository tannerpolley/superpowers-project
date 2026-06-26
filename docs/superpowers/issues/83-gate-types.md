# Authoritative Gate Types And Exact Option Validation

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/83
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md
**Source Plan:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve Authoritative Gate Types And Exact Option Validation using docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md and docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md. Complete acceptance criteria and proof oracle, then hand off to merge-changes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md#outcome-proof
**Intent:** Make workflow-contract.yml authoritative for gate type and exact option labels parsed from active SKILL.md route blocks.
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

Make workflow-contract.yml authoritative for gate type and exact option labels parsed from active SKILL.md route blocks.

## Acceptance Criteria

- [x] workflow-contract.yml defines typed gates for material native questions.
- [x] Validator parses Question id, Prompt, and Options blocks from active SKILL.md files.
- [x] Exact option-label mismatches fail validation.
- [x] Known align-project, setup-project, merge-changes, and implement-plan option drift is repaired.
- [x] Unregistered native-question-like identifiers fail unless allowlisted with reasons.

## Implementation Receipt

- Added typed gate metadata to `docs/superpowers/workflow-contract.yml`, including gate type, prompt, exact option labels, effects, and allowlisted native identifier reasons.
- Added SKILL.md native gate parsing and contract option helpers in `scripts/lib/workflow-contract.ps1`.
- Hardened `scripts/validate-workflow-contract.ps1` to compare exact option labels, enforce typed gate rules, and fail unregistered native-question-like identifiers.
- Expanded `scripts/test-workflow-contract.ps1` fixture coverage for typed gates, exact option drift, and missing gate declarations.
- Raised the GitHub validation job timeout from 20 to 30 minutes after CI logs showed all checks passing before timeout cleanup.

## Proof Receipt

- [x] `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`
- [x] `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1 -RepoRoot .`
- [x] `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## Blocked by

- None

## Non-goals

- Create a new workflow skill.
- Bypass issue-backed execution or merge closeout.
- Treat generated runtime state as canonical documentation.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1 -RepoRoot .`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

