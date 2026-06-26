# Metadata Geometry Guardrails

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/84
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md
**Source Plan:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve Metadata Geometry Guardrails using docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md and docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md. Complete acceptance criteria and proof oracle, then hand off to merge-changes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md#outcome-proof
**Intent:** Prevent compact metadata prompts from flattening nested child routes into top-level continuation gates.
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

Prevent compact metadata prompts from flattening nested child routes into top-level continuation gates.

## Acceptance Criteria

- [x] Metadata validator rejects flattened *_next_step summaries that list child routes beside Stop.
- [x] Metadata validator rejects unsupported options for registered gates.
- [x] Named metadata prompts use safe nested summaries or pointers to SKILL.md and workflow-contract.yml.
- [x] Metadata prompts remain compact.

## Blocked by

- None

## Non-goals

- Create a new workflow skill.
- Bypass issue-backed execution or merge closeout.
- Treat generated runtime state as canonical documentation.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-metadata-contract.ps1 -RepoRoot .`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## Implementation Receipt

- `scripts/validate-skill-metadata-contract.ps1` now checks every registered gate window against sibling options from the skill's full gate set, so top-level summaries cannot list child route labels.
- The metadata option matcher now treats underscores as identifier characters, preventing gate ids such as `project_merge_next_step` from satisfying sibling option labels.
- `scripts/test-skill-metadata-contract.ps1` covers flattened top-level route summaries, unsupported terminal labels in nested routes, duplicated global policy prose, compact passing prompts, and the gate-id boundary regression.
- Compact skill metadata prompts now point top-level continuation gates back to `SKILL.md` and `docs/superpowers/workflow-contract.yml` for child-route detail instead of listing nested options beside terminal choices.
