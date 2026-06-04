# Project Namespace And Skill Surface Migration

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/26
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-03-project-plugin-namespace-skill-naming-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md
**Classification:** HITL
**Labels:** type:feature, status:triage
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

Migrate the public skill surface and plugin runtime namespace only after the final naming decision is confirmed. Keep the migration test-driven and remove stale names instead of preserving compatibility wrappers.

## Acceptance Criteria

- [ ] The final target namespace and skill names are confirmed through native UI before mutation.
- [ ] Active source skills match the approved target set exactly.
- [ ] Skill frontmatter, plugin manifest prompts, README references, and metadata use the approved names.
- [ ] Retired names fail repo validation if reintroduced as active skills or durable docs.
- [ ] Directory moves use Git history-preserving operations where practical.
- [ ] Live sync removes only owned retired copies after ownership checks.

## Blocked by

- User approval of final namespace and deployment policy.

## Non-goals

- Do not create compatibility wrappers.
- Do not rename the local workspace folder.
- Do not make remote GitHub repository changes in this issue unless separately approved.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-project-namespace-migration.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
