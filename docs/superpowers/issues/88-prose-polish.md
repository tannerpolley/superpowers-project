# Skill Prose Polish And Artifact Card Clarity

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/88
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md
**Source Plan:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve Skill Prose Polish And Artifact Card Clarity using docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md and docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md. Complete acceptance criteria and proof oracle, then hand off to merge-changes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md#outcome-proof
**Intent:** Remove machine-patched duplicate route prose while preserving strict Artifact Review Card gates and route-specific inventories.
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

Remove machine-patched duplicate route prose while preserving strict Artifact Review Card gates and route-specific inventories.

## Acceptance Criteria

- [ ] No duplicate summary fragments remain in SKILL.md files.
- [ ] Route-specific Artifact Review Card paragraphs are concise and exact.
- [ ] Global findings-summary policy remains centralized in advanced-user-input.
- [ ] Global policy deduplication and Artifact Review Card tests pass.

## Blocked by

- None

## Non-goals

- Create a new workflow skill.
- Bypass issue-backed execution or merge closeout.
- Treat generated runtime state as canonical documentation.

## Proof Oracle

- `rg -n "Add the helper-required findings summary|permission question:\\.|artifacts are shown.*Add the helper" skills`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-global-policy-deduplication.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
