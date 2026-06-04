# Make Project Continuation Gates Impossible To Skip

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/24
**GitHub Milestone:** M0 - Governance
**Issue Type:** bug
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** type:bug, status:ready
**Goal Command:** /goal Make Superpowers Project continuation gates impossible to skip, using docs/superpowers/issues/24-make-project-continuation-gates-impossible-to-skip.md and docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md.
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

Make required native continuation gates explicit workflow state so an agent cannot treat casual prose or artifact creation as completion when `request_user_input` is available.

## Acceptance Criteria

- [ ] A skill that declares a required native continuation gate records or enforces a pending gate state after writing its artifact.
- [ ] The workflow cannot report completion until that gate is asked, answered, explicitly unavailable, or skipped by a named allowed policy.
- [ ] If `request_user_input` is callable, implicit prose such as "we will go from there" cannot satisfy the gate.
- [ ] The final response or workflow ledger names the gate result and selected next route.
- [ ] A test or smoke fixture covers `project-plan` saving a plan and requiring `project_plan_next_step` before completion.

## Blocked by

- None

## Non-goals

- Do not weaken continuation gates for `project-brainstorm`, `project-plan`, or `project-issue`.
- Do not replace native UI gates with plain chat prompts when `request_user_input` is callable.

## Feedback Loop

- Reproduce with a skill that saves an artifact and ends without asking its declared native continuation gate.
- Verify the new tests fail before the fix and pass after the fix.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
