# Project Doctor flags absent source skill file as repairable in product repos

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/23
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** bug
**Source Plan:** docs/superpowers/plans/2026-06-04-audit-project-source-scope-audit-plan.md
**Classification:** AFK
**Labels:** type:bug, status:ready
**Goal Command:** /goal Fix Project Doctor so absent Doctor source skill files in product repos are informational or skipped, not repairable.
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

## Feedback Loop

Project Doctor previously reported `skills/audit-project/SKILL.md` as a repairable `native-ui-closeout` finding when auditing a product repo that did not own that source file.

## What To Build

Scope native UI closeout wording checks to repos that own the Doctor source skill file. Product repos without that file should receive no repairable source-skill finding.

## Acceptance Criteria

- [ ] Project Doctor only runs the `native-ui-closeout` wording check when the audited repo owns the Doctor source skill file.
- [ ] Product repos without the Doctor source file do not receive a repairable `native-ui-closeout` finding.
- [ ] Repos that own the Doctor source file still receive repairable findings when required wording is missing.
- [ ] Live sync comparison still runs when source exists and skips clearly when source is absent.
- [ ] Scenario tests cover product-repo skipped behavior and source-repo repairable/healthy behavior.

## Blocked by

- None.

## Non-goals

- Do not vendor Doctor source files into product repos.
- Do not weaken the closeout wording check for the plugin source repo.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

