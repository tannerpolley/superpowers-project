# Generate resolve and merge evidence ledgers

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/7
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/7 from docs/superpowers/issues/7-workflow-ledger-generators.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/workflow-ledger-generators
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

Add helper scripts that generate PR-ready, premerge, and closeout ledgers from local and GitHub evidence so agents do not hand-author JSON for normal runs.

## Acceptance Criteria

- [ ] `collect-pr-ready-ledger.ps1` emits evidence accepted by `validate-pr-ready.ps1`.
- [ ] `collect-premerge-ledger.ps1` emits evidence accepted by `premerge.ps1`.
- [ ] `collect-closeout-ledger.ps1` emits evidence accepted by `closeout.ps1`.
- [ ] Generated ledgers use temp output by default and can copy selected final evidence into handoff artifacts.
- [ ] Resolver and merge docs tell agents to use collectors before gate scripts.

## Blocked by

- https://github.com/tannerpolley/milestones-plugin/issues/6

## Non-goals

- Do not make collectors replace gate scripts.
- Do not write generated ledgers into the repo by default.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
