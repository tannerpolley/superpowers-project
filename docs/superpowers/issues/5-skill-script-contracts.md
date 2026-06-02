# Validate skill docs against script parameters

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/5
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement https://github.com/tannerpolley/milestones-plugin/issues/5 from docs/superpowers/issues/5-skill-script-contracts.md using docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/skill-script-contracts
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

Add a validation gate that catches drift between skill documentation and exposed PowerShell script parameters, including the `IssueFile` versus `IssueMirror` failure mode.

## Acceptance Criteria

- [ ] `scripts/validate-skill-script-contract.ps1` exists and has fixture coverage for renamed parameters.
- [ ] `scripts/validate.ps1` runs the contract validator.
- [ ] Skill docs reference exposed script parameters that actually exist.
- [ ] Repo contract tests assert the validator is wired into validation.

## Blocked by

- None

## Non-goals

- Do not require docs to mention private implementation-only parameters.
- Do not rewrite unrelated skill docs.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-script-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
