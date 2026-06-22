# Centralize Native Continuation And Artifact Review Policy

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/66
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Centralize global native continuation and artifact review policy in advanced-user-input and validate route-specific references.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Make global native continuation and artifact review behavior easier to maintain by owning it in one helper skill.
**Target Output:** Workflow skills reference `advanced-user-input` for global behavior and keep only skill-specific gates and outputs.
**Owner:** `skills/advanced-user-input/SKILL.md` owns global native continuation and artifact-review policy.
**Interface:** Route skills keep references plus question IDs, prompts, options, validators, and route-specific artifact lists.
**Cutover:** Duplicated global policy walls are replaced by central helper text and validation.
**Replaced Path:** Repeated native continuation and artifact-review prose across non-helper workflow skills stops being current.
**Acceptance Proof:** Global-policy deduplication tests, native continuation tests, advanced-user-input policy tests, and repo validation pass.
**Stop Criteria:** Stop before merge if a non-helper workflow skill loses required route-specific gates or reintroduces duplicated global policy.
**Avoid:** Do not compress away hard route failures, approval gates, or final Done requirements.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Move common native continuation and artifact-review policy into `advanced-user-input`, replace duplicated walls in route skills with references, and validate the new structure.

## Acceptance Criteria

- [ ] `advanced-user-input` contains the global continuation and artifact-review policy.
- [ ] Route skills reference the helper and preserve skill-specific native question contracts.
- [ ] Duplicate global-policy paragraphs in non-helper workflow skills fail validation.
- [ ] `scripts/test-native-continuation-loop.ps1` passes after the centralization.
- [ ] `scripts/test-advanced-user-input-policy.ps1` passes.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/63

## Non-goals

- Do not alter route ownership or skip native continuation gates.
- Do not change metadata prompt compression in this issue.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-global-policy-deduplication.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Centralize global native continuation and artifact review policy in `advanced-user-input` while keeping route-specific gates in each owning skill.
