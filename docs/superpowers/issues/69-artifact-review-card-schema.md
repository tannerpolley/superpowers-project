# Standardize Artifact Review Card Schema

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/69
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Add a standard Artifact Review Card schema and fixtures for continuation, push, publish, and merge gates.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Preserve proof-first artifact review while reducing noisy closeout dumps.
**Target Output:** Agents use a standard card with exact changed paths, proof, decisions, risks, and recommended next route.
**Owner:** `skills/advanced-user-input/SKILL.md` owns the card schema; route skills own route-specific artifact lists.
**Interface:** Scenario validators read card fixtures and fail missing path, proof, decision, risk, or next-route fields.
**Cutover:** Route skills reference the standard card schema instead of repeating long artifact-display prose.
**Replaced Path:** Free-form artifact-review paragraphs stop being the only review shape.
**Acceptance Proof:** Artifact-card tests and native continuation tests pass.
**Stop Criteria:** Stop before merge if the card schema permits closeout without exact artifacts or proof.
**Avoid:** Do not make artifact review optional or replace native approval gates.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Define an Artifact Review Card schema, add fixtures, and update route skills to reference it.

## Acceptance Criteria

- [ ] `advanced-user-input` defines the card schema.
- [ ] The schema requires changed paths, proof, decisions, risks, and recommended next route.
- [ ] Large artifact excerpt rules are documented.
- [ ] Scenario tests cover continuation, push, publish, and merge gates.
- [ ] Route skills keep strict display-before-question behavior.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/66

## Non-goals

- Do not remove route-specific artifact inventories.
- Do not shorten proof requirements below the current safety level.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Add a standard Artifact Review Card schema so agents show proof consistently without burying continuation gates in noisy dumps.
