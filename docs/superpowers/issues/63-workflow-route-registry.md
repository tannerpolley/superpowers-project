# Add Canonical Workflow Route Registry

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/63
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:ready, type:task
**Goal Command:** /goal Add the canonical workflow contract registry and validator for Superpowers Project route surfaces.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Make workflow route behavior predictable by introducing one authoritative registry for active route contracts.
**Target Output:** Maintainers and agents can inspect `docs/superpowers/workflow-contract.yml` and run a validator that catches route drift before merge.
**Owner:** `docs/superpowers/workflow-contract.yml` owns workflow route data.
**Interface:** PowerShell validators read the registry plus skill and metadata surfaces and return pass/fail proof.
**Cutover:** Registry-backed route data becomes the durable reference for validators and generated summaries.
**Replaced Path:** Hand-maintained route summaries stop being the durable source for route structure.
**Acceptance Proof:** `scripts/test-workflow-contract.ps1`, `scripts/validate-workflow-contract.ps1`, and `scripts/validate.ps1` pass.
**Stop Criteria:** Stop before merge if any active workflow skill, question ID, nested route, final gate, validator, artifact, or transition is missing from the registry.
**Avoid:** Do not add a new workflow skill or bypass existing route owners.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add `docs/superpowers/workflow-contract.yml`, registry loading helpers, a validator, and fixture tests that prove the contract catches route drift.

## Acceptance Criteria

- [x] `docs/superpowers/workflow-contract.yml` includes every active workflow skill.
- [x] The contract includes native question IDs, top-level options, nested options, final gates, validators, artifacts, and next-skill transitions.
- [x] `scripts/validate-workflow-contract.ps1` fails when a nested Yes route includes `Stop`.
- [x] `scripts/test-workflow-contract.ps1` passes.
- [x] `scripts/validate.ps1` runs the new registry test or validator.

## Blocked by

- No blockers.

## Non-goals

- Do not shrink metadata prompts in this issue.
- Do not centralize repeated global policy in this issue.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Add the canonical workflow route registry and registry validator described in the source plan. This is the first dependency for the workflow contract normalization program.
