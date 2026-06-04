# Implement Plan Non-Issue Execution Route

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/27
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-03-project-implement-and-integration-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Add the implement-plan non-issue execution route using docs/superpowers/issues/implement-plan-non-issue-execution-route.md and docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md.
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

## What To Build

Create the `implement-plan` route for approved plans that should be implemented without creating a GitHub issue while still requiring native goal proof, a development branch, TDD, verification, publish approval, and merge-ready evidence.

## Acceptance Criteria

- [ ] `skills/implement-plan` exists with `SKILL.md`, metadata, scenario tests, and any required contract helper.
- [ ] The skill accepts an approved plan under `docs/superpowers/plans`.
- [ ] The skill does not create issue mirrors and does not claim GitHub issue closure.
- [ ] Native `/goal` activation, branch strategy, execution topology, publish permission, and verification proof are required.
- [ ] `project-plan` can route an approved plan to `implement-plan`.
- [ ] Merge-ready output can be consumed by `project-merge` or the approved merge route.

## Blocked by

- None

## Non-goals

- Do not replace the issue-backed path for non-trivial GitHub-tracked work.
- Do not allow local-main quick edits to bypass the existing Quick Apply gate.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
