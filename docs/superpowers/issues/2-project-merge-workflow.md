# Add Project Merge Workflow And Continuation Gates

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/2
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-merge-skill-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-merge-skill-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/2 from docs/superpowers/issues/2-project-merge-workflow.md using docs/superpowers/plans/2026-06-02-project-merge-skill-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/project-merge-workflow
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

Implement the Superpowers Project workflow upgrade that adds `$project-merge`, narrows `$project-resolve` to PR-ready handoff, adds native continuation gates across handoffs, and updates issue mirrors, router metadata, validation, live sync, and documentation.

## Acceptance Criteria

- [x] `scripts/validate.ps1` treats `project-merge` as an active skill.
- [x] `skills/project-merge` exists with `SKILL.md`, `agents/openai.yaml`, merge gate scripts, and scenario tests.
- [x] `$project-resolve` no longer owns merge, issue close, or final cleanup and completes its native goal at PR-ready evidence.
- [x] Worker-mode `$project-resolve` records a lightweight Dynamic Work Packet Map in the setup ledger or worker handoff.
- [x] Issue mirrors include a `## Project Merge` section with merge owner, merge gate, merge policy, cleanup policy, and wakeup policy.
- [x] `$project-plan`, `$project-issue`, `$project-resolve`, and `$project-merge` document native continuation gates that immediately start the selected next skill when feasible.
- [x] `$project-merge` asks native UI approval before merging and accepts only `Merge` or `Decline` decisions after clean premerge proof.
- [x] Full repo validation and live sync validation pass.

## Blocked by

- None

## Non-goals

- Do not add GoalBuddy boards or `docs/goals`.
- Do not make `$project-merge` require a native `/goal` by default.
- Do not create `.workflow/<slug>` folders for ordinary issue resolution.
- Do not let worker threads merge their own PR by default.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-merge\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-issue\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-dummy-repo.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
