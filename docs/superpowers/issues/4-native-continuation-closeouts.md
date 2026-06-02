# Enforce native continuation closeouts across project skills

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/4
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/4 from docs/superpowers/issues/4-native-continuation-closeouts.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/native-continuation-closeouts
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

Make every Superpowers Project skill summarize its output and end with a native continuation question that includes stop/review plus relevant next workflow routes.

## Acceptance Criteria

- [ ] All project skills document native continuation closeout requirements.
- [ ] `$project-brainstorm` includes Project Plan, Review First, and Revise Spec closeout options.
- [ ] `$project-plan` includes Project Issue First, Quick Apply, Review First, and Revise Plan closeout options.
- [ ] Scenario tests fail without closeout summary and native continuation text.
- [ ] Router metadata treats selected native answers as executable routing.

## Blocked by

- None

## Non-goals

- Do not remove existing skill responsibilities.
- Do not use `debug_question_mode` as live approval.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-brainstorm\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
