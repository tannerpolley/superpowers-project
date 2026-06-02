# Clean closed issue mirrors during merge closeout

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/8
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/8 from docs/superpowers/issues/8-closed-mirror-cleanup.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/closed-mirror-cleanup
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

Make closed issue mirror cleanup part of project-merge closeout: delete closed mirrors by default, allow explicit retention, and preserve milestone history as closed summaries.

## Acceptance Criteria

- [ ] `closeout.ps1` requires mirror deletion or retention evidence for closed issues.
- [ ] `collect-closeout-ledger.ps1` records mirror cleanup and milestone closed-summary evidence.
- [ ] `docs/superpowers/issues/README.md` documents closed mirror lifecycle.
- [ ] `$project-doctor` reports stale closed mirrors as repairable drift.
- [ ] Milestone pages keep closed issue summaries with GitHub issue and PR links.

## Blocked by

- https://github.com/tannerpolley/milestones-plugin/issues/7

## Non-goals

- Do not delete retained mirrors marked `Mirror Retention: Keep`.
- Do not remove durable milestone history.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
