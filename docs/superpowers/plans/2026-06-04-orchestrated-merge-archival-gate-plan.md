# Orchestrated Merge Archival Gate Implementation Plan

**Source:** https://github.com/tannerpolley/milestones-plugin/issues/22

## Goal

Add a hard closeout gate for PRs produced by orchestrated worker threads so `$project:merge-changes` requires worker thread archival evidence after merge and before physical worktree-folder removal.

## Implementation Tasks

- Extend merge closeout ledgers with `merge_context`, worker thread identity, archival proof, and physical-folder cleanup order evidence.
- Update closeout validation so orchestrated merges fail when worker archival proof is missing or folder removal happens before archival.
- Keep inline/current-thread closeout behavior unchanged.
- Update orchestrate-issues handoff evidence so merge can identify orchestrated work.
- Add scenario coverage for orchestrated success, inline success, missing archival failure, and deletion-before-archive failure.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

