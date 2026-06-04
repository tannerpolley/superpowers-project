# Setup Orchestration Board And Worker Identity

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/30
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-03-setup-orchestration-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-setup-orchestration-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Finish project setup and orchestration identity support, including approved GitHub Project board creation/configuration evidence.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Approval Decision

Native approval selected `Create Board`: Project setup may create or configure the live GitHub Project board after validation and must record structured board evidence.

## What To Build

Finish the setup and orchestration layer: GitHub Project board setup after native approval, canonical worker identity, issue/worktree naming, and orchestration handoff validation.

## Acceptance Criteria

- [ ] `setup` can prepare GitHub Project board setup and records config only after native approval.
- [ ] `orchestrate-issues` derives consistent worker thread title, branch name, worktree path, evidence path, and PR title hints from an issue mirror.
- [ ] Worker handoff ledgers carry enough evidence for reviewer and merge closeout.
- [ ] `resolve-issue` remains the direct current-thread route and does not create worker threads.
- [ ] Router docs clearly ask whether to resolve directly or orchestrate when the route is ambiguous.
- [ ] Scenario tests cover identity derivation, worker handoff validation, and setup board approval.

## Blocked by

- None.

## Non-goals

- Do not make GitHub Projects canonical for specs, plans, or issue mirrors.
- Do not let worker threads merge their own PRs by default.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

