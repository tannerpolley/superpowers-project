# Smoke Test Superpowers Project Workflow

**GitHub Issue:** pre-publication
**Pre-Publication:** true
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-02-superpowers-project-extension-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-superpowers-project-extension-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Validate the Superpowers Project extension workflow in tannerpolley/milestones-plugin using docs/superpowers/issues/smoke-test-workflow.md and docs/superpowers/plans/2026-06-02-superpowers-project-extension-plan.md.

## What To Build

Use this repository as a smoke-test fixture for the Superpowers Project extension workflow: project context, brainstorming/spec output, writing-plan output, issue mirror validation, native-goal setup gates, and project-doctor drift checks.

## Acceptance Criteria

- [ ] `docs/superpowers/PROJECT_CONTEXT.md` contains the project context sections required by `$project-context`.
- [ ] `docs/superpowers/issues/` exists and contains at least one valid issue mirror.
- [ ] The issue mirror validator accepts this pre-publication mirror with milestone enforcement.
- [ ] The resolve-issue setup gate accepts structured native goal proof and rejects missing proof in the dummy repo validation.
- [ ] Project validation catches stale canonical artifact routing outside `docs/superpowers`.

## Blocked by

- None

## Non-goals

- Do not create, close, or mutate real GitHub issues from this smoke fixture without an explicit publication gate.
- Do not create `docs/goals`, GoalBuddy state, or local live board artifacts.

## Native Question Debug Ledger

- Skill: `superpowers-project`
  - Question id: `smoke_scope_policy`
  - Prompt: choose the smoke-test scope and artifact policy.
  - Options: full local workflow smoke with pre-publication mirrors; GitHub-published smoke issues; local docs-only structure audit.
  - Recommended option: full local workflow smoke with pre-publication mirrors.
  - Selected answer: full local workflow smoke with pre-publication mirrors, no real GitHub issue publication, no `docs/goals`, use configured milestones and labels.
  - Answer source: `user-provided-debug-answer`
  - Evidence: background smoke thread entered `waitingOnUserInput`; the thread API exposed no native prompt answer operation.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
