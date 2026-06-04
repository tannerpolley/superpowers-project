# Plugin Deployment Policy And Live Sync

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/28
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-03-public-release-readiness-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md
**Classification:** HITL
**Labels:** type:task, status:triage
**Goal Command:** None
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

Reconcile the deployment policy with the latest decision that `advanced-user-input` should remain useful as both a plugin-owned skill and a user-level skill, while other project workflow skills may eventually become plugin-only.

## Acceptance Criteria

- [ ] The source plan is updated or superseded so it no longer blindly removes all user-level copies.
- [ ] The sync policy distinguishes broadly reusable skills from plugin-specific workflow skills.
- [ ] `sync-live.ps1` ownership checks remain loud and path-safe.
- [ ] Validation proves the plugin source, live plugin, and intended user-level skill copies are synchronized.
- [ ] Retired live plugin roots are removed only when owned by this plugin.
- [ ] Documentation explains which skills are installed globally and why.

## Blocked by

- User decision on whether project workflow skills should remain user-level skills or become plugin-only after namespace migration.

## Non-goals

- Do not delete user-authored skills outside the repo-owned deployment set.
- Do not remove `advanced-user-input` from user-level skills if it remains the shared cross-project helper.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plugin-only-live-sync.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sync-live.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
