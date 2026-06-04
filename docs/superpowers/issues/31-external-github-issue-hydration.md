# External GitHub Issue Hydration

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/31
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-03-project-setup-orchestration-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Add external GitHub issue hydration using docs/superpowers/issues/external-github-issue-hydration.md and docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md.
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

Add a safe hydration route for GitHub issues that exist before local Superpowers Project artifacts, so resolve/orchestrate cannot start until a local mirror and source plan exist.

## Acceptance Criteria

- [ ] A hydration command reads an existing GitHub issue body and preserves issue URL, title, milestone, labels, branch policy, acceptance criteria, proof oracle, and goal command.
- [ ] Hydration creates or updates a local mirror under `docs/superpowers/issues`.
- [ ] When needed, hydration creates or links a source plan before execution.
- [ ] The route refuses to hand off to `project-resolve` or `project-orchestrate` until mirror validation passes.
- [ ] Tests cover missing source plan, successful hydration, and body-to-mirror field preservation.
- [ ] Documentation distinguishes GitHub intake issues from ready execution mirrors.

## Blocked by

- None

## Non-goals

- Do not auto-publish draft Project items.
- Do not infer missing proof or acceptance criteria without marking the issue HITL or triage.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-issue\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-orchestrate\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
