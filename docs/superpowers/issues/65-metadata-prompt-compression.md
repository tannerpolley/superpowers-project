# Compress Skill Metadata Prompts Against Workflow Contract

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/65
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Compress workflow skill metadata prompts and validate them against the canonical workflow contract.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Keep metadata prompts useful for skill selection without duplicating the full route contract.
**Target Output:** Maintainers can review compact `agents/openai.yaml` prompts and a validator catches metadata drift.
**Owner:** `skills/*/agents/openai.yaml` owns compact skill-selection metadata; the workflow contract owns route details.
**Interface:** Metadata validation compares prompt route summaries against `docs/superpowers/workflow-contract.yml`.
**Cutover:** Metadata prompts refer to `SKILL.md` and the workflow contract instead of repeating full continuation and route policy.
**Replaced Path:** Large duplicated metadata prompt walls stop being the second copy of route behavior.
**Acceptance Proof:** Metadata contract tests, metadata readability tests, and repo validation pass with the known `write-plan` drift removed.
**Stop Criteria:** Stop before merge if metadata still lists `Stop` inside `project_plan_issue_execution_route` or duplicates full global policy.
**Avoid:** Do not weaken skill selection triggers or remove hard boundaries needed for routing.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add metadata contract validation and shrink workflow skill metadata prompts to compact route-selection summaries.

## Acceptance Criteria

- [ ] `skills/write-plan/agents/openai.yaml` lists only `Resolve Issue` and `Orchestrate Issues` under `project_plan_issue_execution_route`.
- [ ] No workflow metadata prompt duplicates full native continuation, artifact-review, or route-table policy.
- [ ] A metadata contract validator fails when metadata contradicts the registry.
- [ ] `scripts/test-skill-metadata-readability.ps1` passes.
- [ ] `scripts/validate.ps1` includes the metadata contract proof.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/63

## Non-goals

- Do not rewrite `SKILL.md` route contracts in this issue.
- Do not change live deployed copies directly.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-readability.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Compress `agents/openai.yaml` prompts so they select skills and point to the authoritative contract instead of duplicating full workflow behavior.
