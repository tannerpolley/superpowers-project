# Add guarded Quick Apply path after project-plan

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/9
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/9 from docs/superpowers/issues/9-project-plan-quick-apply.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/project-plan-quick-apply
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

Add a guarded Quick Apply path for small, low-risk work after project-plan, with native approval and local-main verification instead of issue publication.

## Acceptance Criteria

- [ ] `project_plan_next_step` includes Quick Apply, Review First, and Revise Plan where relevant.
- [ ] `validate-quick-apply.ps1` blocks dirty, unsynced, non-main, missing approval, missing verification, missing cleanup, and unapproved push states.
- [ ] Quick Apply asks `project_quick_apply_approval` before edits.
- [ ] Router docs keep issue-backed execution as default for non-trivial work.
- [ ] README documents Quick Apply as a small-work escape hatch.

## Blocked by

- https://github.com/tannerpolley/milestones-plugin/issues/4

## Non-goals

- Do not use Quick Apply for risky multi-issue implementation.
- Do not skip verification or cleanup hook.
- Do not push main without approval.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
