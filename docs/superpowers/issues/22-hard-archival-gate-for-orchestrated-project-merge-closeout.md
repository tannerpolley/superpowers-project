# Add hard archival gate for orchestrated merge-changes closeout

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/22
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Plan:** docs/superpowers/plans/2026-06-04-orchestrated-merge-archival-gate-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Add orchestrated merge closeout archival gates so worker-thread PR merges require archival proof before physical worktree folder removal.
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

Add an orchestrated-merge closeout gate to `$project:merge-changes` / `merge-changes`. When a PR came from `$project:orchestrate-issues`, closeout must require worker thread archival proof after merge and before physical worktree-folder removal.

## Acceptance Criteria

- [ ] Orchestrated merge closeout evidence identifies worker thread identity and worktree path.
- [ ] Orchestrated merge closeout requires worker-thread archival proof after PR merge.
- [ ] Physical worktree-folder removal is rejected when it happens before worker thread archival.
- [ ] Inline/current-thread merge closeout does not require worker-thread archival.
- [ ] Scenario tests cover orchestrated success, inline success, missing archival failure, and folder deletion before archival failure.
- [ ] Documentation states the intended cleanup order.

## Blocked by

- None.

## Non-goals

- Do not require worker-thread archival for inline/current-thread merges.
- Do not allow worker threads to merge their own PRs by default.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

