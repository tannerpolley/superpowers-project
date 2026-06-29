# Tracker Vocabulary And Clean-Title Policy
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/98
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve issue: Tracker Vocabulary And Clean-Title Policy using docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** leaf
**Executable:** true
**Parent Issue:** https://github.com/tannerpolley/superpowers-project/issues/97
**Parent Mirror:** docs/superpowers/issues/97-github-sub-issues-workflow.md
**Child Issues:** None
**Rollup Policy:** none
**Title Policy:** Clean GitHub title
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary
**Outcome Source:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md#outcome-proof
**Intent:** Add tracker vocabulary and clean-title validation so new issue titles never carry manual milestone identity.
**Target Output:** Tracker docs, setup metadata, title-policy validator, and tests proving GitHub Milestones own milestone identity.
**Owner:** docs/agents and skills/create-issues/scripts/validate-issue-title-policy.ps1
**Interface:** Tracker docs, roadmap JSON, setup receipts, and title-policy validator JSON.
**Cutover:** Move new issue milestone tracking out of titles and into GitHub Milestone fields plus hierarchy metadata.
**Replaced Path:** Manual title prefixes, bracketed milestone tags, and leading hierarchy numbers in new issue titles.
**Acceptance Proof:** setup-project scenarios, create-issues title-policy scenarios, and tracker roadmap proof pass.
**Stop Criteria:** Stop if clean-title validation accepts title-encoded milestone metadata or tracker vocabulary is incomplete.
**Avoid:** Do not create hierarchy labels without documenting their tracker role and do not make hierarchy mandatory for flat projects.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Update tracker vocabulary, setup guidance, roadmap proof, and clean-title validation.

## Acceptance Criteria

- [ ] Hierarchy labels or native issue-type equivalents are documented in tracker vocabulary.
- [ ] Clean-title validator rejects title-encoded milestone identity and hierarchy ordering.
- [ ] Flat projects remain supported without parent issues.

## Blocked by

- No blocking issue.

## Non-goals

- Do unrelated refactors.
- Edit deployed plugin copies directly.
- Bypass the proof oracle.

## Proof Oracle

- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup-project\scripts\test-scenarios.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-tracker-roadmap-proof.ps1
