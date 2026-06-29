# Create-Issues Publication, Hydration, And Routing
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/100
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-29-github-sub-issues-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Resolve issue: Create-Issues Publication, Hydration, And Routing using docs/superpowers/plans/2026-06-29-github-sub-issues-workflow-plan.md
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
**Intent:** Teach create-issues to route hierarchy decisions, publish parent and child issues, and hydrate external GitHub hierarchy.
**Target Output:** Updated create-issues skill instructions, metadata, hydration script, and examples.
**Owner:** skills/create-issues/SKILL.md and skills/create-issues/scripts/hydrate-external-issue.ps1
**Interface:** Native approval gates, gh issue commands, hydrated issue mirrors, and examples.
**Cutover:** Route grouped multi-issue plans through hierarchy-aware publication instead of flat-only issue creation.
**Replaced Path:** Create-issues guidance that cannot represent parent/sub-issue relationships.
**Acceptance Proof:** create-issues scenarios pass for hierarchy routing, publication order, and hydration fields.
**Stop Criteria:** Stop if live mutation can happen before native approval or hydration omits parent/sub-issue JSON fields.
**Avoid:** Do not duplicate the route tree in compact metadata and do not publish unvalidated titles.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Update create-issues instructions, metadata, external hydration, and hierarchy examples.

## GitHub Parent/Sub-Issue Contract

- `create-issues` should offer hierarchy only when grouped work exists; single-issue and flat projects stay flat.
- Publication must create or attach issues in GitHub UI order: parent first, optional wrapper second, executable leaves last.
- New child publication should use GitHub-native parent/sub-issue fields rather than encoding parent, milestone, or order in titles.
- External hydration must read GitHub parent/sub-issue state and write the same hierarchy metadata into local mirrors before execution routing.
- Any GitHub mutation that creates, attaches, detaches, or reorders sub-issues requires native approval and a dry command receipt first.

## Acceptance Criteria

- [ ] Native gates cover hierarchy mode, parent title, child list, milestone, labels, and publication approval.
- [ ] Dry publication receipts show `gh issue create --parent` or the supported equivalent for new children and `gh issue edit --add-sub-issue` for existing child attachment.
- [ ] Hydration reads parent, subIssues, subIssuesSummary, milestone, labels, issueType, title, url, and number.
- [ ] Hydrated mirrors preserve parent URL, child issue URLs, rollup policy, title policy, role, and executability.
- [ ] Examples show clean titles, GitHub Milestone fields, and GitHub parent/sub-issue relationships.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/99

## Non-goals

- Do unrelated refactors.
- Edit deployed plugin copies directly.
- Bypass the proof oracle.

## Proof Oracle

- pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
