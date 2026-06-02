# Add scripted Project Doctor drift audit

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/10
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/10 from docs/superpowers/issues/10-project-doctor-audit-gate.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/project-doctor-audit-gate
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add a Project Doctor audit script that reports structured blocking, repairable, informational, and healthy findings for project docs, GitHub tracker state, live sync, ignored files, native UI contracts, and closed mirror lifecycle drift.

## Acceptance Criteria

- [ ] `audit-project.ps1` exists with LocalDocs and GitHubAware modes.
- [ ] Doctor scenarios cover milestone membership drift, mirror versus GitHub issue drift, label drift, closed mirror lifecycle drift, native UI closeout drift, ignored-path traps, and live sync drift.
- [ ] Doctor remains report-first and requires native repair approval before mutation.
- [ ] Repo contract tests assert `audit-project.ps1` is present and documented.

## Blocked by

- https://github.com/tannerpolley/milestones-plugin/issues/4
- https://github.com/tannerpolley/milestones-plugin/issues/5
- https://github.com/tannerpolley/milestones-plugin/issues/8
- https://github.com/tannerpolley/milestones-plugin/issues/9

## Non-goals

- Do not let Doctor edit product code or merge PRs.
- Do not mutate docs or tracker state without native approval.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
