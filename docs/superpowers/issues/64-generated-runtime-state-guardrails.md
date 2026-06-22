# Guard Generated Runtime State

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/64
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:ready, type:task
**Goal Command:** /goal Add generated-state guardrails that keep .superpowers runtime ledgers untracked and non-canonical.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Keep generated runtime state from becoming source-of-truth clutter.
**Target Output:** Validation fails if `.superpowers/**` generated ledgers become tracked or cited as canonical docs.
**Owner:** `.gitignore` and generated-state validators own runtime-state guardrails.
**Interface:** Validation reads Git tracked files and docs references to detect generated-state drift.
**Cutover:** Generated run state remains local proof unless a workflow intentionally reviews it.
**Replaced Path:** Repo audits stop treating `.superpowers/**` as ordinary canonical artifact inventory.
**Acceptance Proof:** Generated-state tests and repo validation pass.
**Stop Criteria:** Stop before merge if tracked `.superpowers/**` files or canonical documentation references are detected.
**Avoid:** Do not delete active local run ledgers while a workflow is using them.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add validation and tests that keep `.superpowers/**` ignored and non-canonical.

## Acceptance Criteria

- [ ] `.gitignore` keeps `.superpowers/` ignored.
- [ ] Validator fails if `git ls-files .superpowers` returns tracked files.
- [ ] Validator fails when docs present `.superpowers/**` as canonical project docs.
- [ ] Local untracked run ledgers remain allowed for active workflow proof.
- [ ] Generated-state validation runs from `scripts/validate.ps1`.

## Blocked by

- No blockers.

## Non-goals

- Do not remove active local run artifacts.
- Do not change canonical artifact roots.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-generated-state.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-generated-state.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Add generated-state guardrails so `.superpowers/**` remains local runtime proof instead of source-of-truth clutter.
