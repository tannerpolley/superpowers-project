# GitHub Sub-Issues Workflow
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/97
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** HITL
**Labels:** type:feature, status:triage
**Goal Command:** Non-executable rollup issue
**Hierarchy Mode:** sub-milestone
**Sub-Issue Role:** parent
**Executable:** false
**Parent Issue:** None
**Parent Mirror:** None
**Child Issues:** https://github.com/tannerpolley/superpowers-project/issues/98, https://github.com/tannerpolley/superpowers-project/issues/99, https://github.com/tannerpolley/superpowers-project/issues/100, https://github.com/tannerpolley/superpowers-project/issues/101, https://github.com/tannerpolley/superpowers-project/issues/102, https://github.com/tannerpolley/superpowers-project/issues/103
**Rollup Policy:** all-required-children-closed
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
**Intent:** Track the full GitHub sub-issues workflow implementation as one pseudo sub-milestone inside the real GitHub Milestone.
**Target Output:** A validated source change with sub-issue hierarchy support, local mirrors, execution guards, rollup proof, docs, live-sync validation, and merged issue slices.
**Owner:** GitHub Milestone and parent issue hierarchy own tracker grouping; local issue mirrors own execution readiness.
**Interface:** GitHub parent issue, child sub-issues, local mirrors, validator receipts, and merge closeout receipts.
**Cutover:** Replace title-encoded milestone tracking with GitHub Milestone fields and parent/sub-issue links for new issue publication.
**Replaced Path:** New issue titles that encode manual milestone identity or hierarchy order.
**Acceptance Proof:** All child issues close with proof, rollup evidence is recorded, full validation passes, live-sync validation passes, and cleanup proof is clean.
**Stop Criteria:** Stop rollup closeout if any required child issue remains open without explicit skipped-child evidence or if validation fails.
**Avoid:** Do not run this parent issue as implementation work, do not place milestone identity in titles, and do not close the rollup before child proof exists.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Coordinate the six executable sub-issues that implement optional GitHub sub-issue hierarchy across the Superpowers Project workflow.

## Acceptance Criteria

- [ ] All six child issues are published as clean-title sub-issues under this parent.
- [ ] Each child issue has a local mirror with source plan linkage and proof oracle.
- [ ] Rollup closeout evidence records child state before this parent closes.

## Blocked by

- No blocking issue; this is the rollup parent.

## Non-goals

- Implement product code directly from this parent issue.
- Replace GitHub Milestones.
- Rename historical issues without native approval.

## Proof Oracle

- Child issue closeout receipts prove each slice.
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
