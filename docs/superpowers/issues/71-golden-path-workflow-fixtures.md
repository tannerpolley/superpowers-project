# Add Golden-Path Workflow Fixtures

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/71
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Add golden-path workflow examples and validators for common Superpowers Project routes.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Make common workflow routes easier for fresh agents to follow and verify.
**Target Output:** Four example routes show question IDs, artifacts, validators, and stop points, and tests compare them to the workflow contract.
**Owner:** `docs/superpowers/examples/workflow-golden-paths.md` owns examples; the workflow contract owns route truth.
**Interface:** Example validators read Markdown examples and compare route names and question IDs against the registry.
**Cutover:** Golden-path fixtures become the durable examples for expected end-to-end route behavior.
**Replaced Path:** Ad hoc route explanations stop being the only examples for Auto Mode and Looping Mode behavior.
**Acceptance Proof:** Workflow example tests and repo validation pass.
**Stop Criteria:** Stop before merge if Auto Mode examples continue to another candidate or Looping Mode examples skip budget recheck.
**Avoid:** Do not turn examples into alternate route contracts.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add four golden-path examples and validators that compare examples to the registry.

## Acceptance Criteria

- [ ] Examples cover idea to local merge, spec to issues to merge, audit to Auto Mode single route, and Looping Mode candidate selection with budget recheck.
- [ ] Each example includes question IDs, artifacts, validators, and stop point.
- [ ] Example validator compares route names and question IDs against the workflow contract.
- [ ] `scripts/test-workflow-examples.ps1` passes.
- [ ] `scripts/validate.ps1` runs the example proof.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/63
- https://github.com/tannerpolley/superpowers-project/issues/66
- https://github.com/tannerpolley/superpowers-project/issues/69

## Non-goals

- Do not create a separate docs source of truth for route contracts.
- Do not add browser companion artifacts for these text examples.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-examples.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Add contract-validated golden-path workflow examples so common routes are easier to follow and harder to misinterpret.
