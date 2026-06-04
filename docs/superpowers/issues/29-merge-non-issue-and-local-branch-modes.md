# Merge Non-Issue And Local Branch Modes

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/29
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-03-project-implement-and-integration-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Extend project-merge for non-issue PR and local branch modes using docs/superpowers/issues/merge-non-issue-and-local-branch-modes.md and docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md.
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

Extend merge handling so the integration skill can close out issue-backed PRs, non-issue PRs, and approved local branches without pretending non-issue work closes GitHub issues.

## Acceptance Criteria

- [ ] Merge closeout supports `pr-issue`, `pr-no-issue`, and `local-branch` modes.
- [ ] Issue-close verification is required only for issue-backed PRs.
- [ ] Non-issue PR and local branch modes still require native merge approval.
- [ ] Branch/worktree cleanup and clean repo proof remain required.
- [ ] Reassessment routes can send work back to planning or implementation when merge approval is declined.
- [ ] Tests cover happy and blocking paths for each mode.

## Blocked by

- None

## Non-goals

- Do not let worker threads merge their own PRs by default.
- Do not skip verification-before-completion evidence for non-issue work.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
