---
name: project-issue
description: Use when a Superpowers Project spec, plan, PRD, or approved scope needs vertical-slice GitHub issues and synced issue mirrors.
---

# Project Issue

Project Issue turns approved Superpowers Project source material into GitHub issues and local issue mirrors. It borrows `to-issues` tracer-bullet behavior, keeps issues independently grabbable, and records enough structure for `$project-resolve` to execute one issue at a time.

## Inputs

Read the source material and project map before proposing issues:

- `docs/superpowers/specs`
- `docs/superpowers/plans`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones`
- existing `docs/superpowers/issues`
- tracker label vocabulary from `docs/agents/triage-labels.md` or `docs/agents/project-roadmap.json` when present
- GitHub labels, GitHub milestones, and open GitHub issues when the repo is linked

Use `request_user_input` when callable to approve granularity, dependencies, milestone assignment, and whether each slice is AFK or HITL.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not publish GitHub issues and must not be used to pretend a live user approved issue boundaries, dependencies, labels, milestones, AFK/HITL classification, or publication.

## Slice Rules

Create vertical slices. Each issue should deliver a narrow end-to-end path with its own proof, not a horizontal layer-only task.

For each proposed slice, show:

- Title
- AFK or HITL classification
- Blocked by
- GitHub Milestone
- Labels from the configured tracker vocabulary, including the ready status label for AFK slices or the blocked/triage status label for HITL slices
- Acceptance Criteria
- Proof oracle
- Goal Command for AFK slices

Prefer AFK where the acceptance criteria and proof oracle allow a Codex agent to finish the issue without more human choices. Use HITL when design review, policy decisions, access, or unclear scope requires a person.

## Approval Gate

Before publishing, ask the user to approve:

- issue count and issue boundaries
- dependency order and Blocked by relationships
- AFK/HITL classification
- labels and milestone assignment
- Acceptance Criteria and proof oracle
- which slices are ready for agent execution and which must stay triage or blocked

Publish issues in dependency order so blockers get real GitHub issue identifiers first.

## Issue Mirror Contract

Write issue mirrors to `docs/superpowers/issues/<issue-number>-<slug>.md` after GitHub publication, or `docs/superpowers/issues/<slug>.md` before publication.

Each mirror must include:

- GitHub Issue
- GitHub Milestone
- Issue Type
- Source Spec or Source Plan
- Classification: AFK or HITL
- Labels
- Goal Command for AFK issues
- Execution Mode
- Worktree Policy
- Integration Policy
- TDD Policy
- Parallelization Plan
- Reviewer Role
- Script Gate Mode
- Project Merge section
- Merge Owner
- Merge Gate
- Merge Policy
- Worktree Cleanup Policy
- Orchestrator Wakeup Policy
- Acceptance Criteria as checkboxes
- Blocked by
- Non-goals
- Proof oracle
- GitHub body text or a close mirror of it

Workflow metadata guides `$project-resolve`. Missing metadata is advisory during migration, but malformed metadata should be corrected before publication because it creates ambiguous execution instructions. `Execution Mode` should normally be `Ask at runtime` so the resolver asks whether to solve inline or open a worker worktree thread.

Bug mirrors must include either a Reproduction section or a Feedback Loop section so the fixing agent has a concrete failure to prove.

## GitHub Issue Body

Use this shape for each issue body and mirror:

```markdown
# <Issue Title>

**GitHub Issue:** <url or pre-publication>
**GitHub Milestone:** <milestone title or none>
**Issue Type:** <bug|feature|task>
**Source Spec:** <path or none>
**Source Plan:** <path or none>
**Classification:** <AFK|HITL>
**Labels:** <configured ready/status label>, <type label>
**Goal Command:** /goal <objective for AFK execution>
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

<one vertical slice outcome>

## Acceptance Criteria

- [ ] <criterion>

## Blocked by

- <issue URL or None>

## Non-goals

- <excluded work>

## Proof Oracle

- <command, artifact, review state, or visible behavior>
```

For HITL issues, use the configured triage or blocked status label until the missing human decision is resolved.

## Mirror Validation

Use the bundled `scripts/validate-issue-mirror.ps1 -IssueFile <docs/superpowers/issues/file.md>` before publishing an issue mirror or handing it to `$project-resolve`.

Validation must prove:

- the mirror path is under `docs/superpowers/issues`
- source spec or source plan exists
- GitHub Issue is present or the mirror is explicitly pre-publication
- GitHub Milestone is present when milestone policy is hard
- Acceptance Criteria are checkboxes
- AFK/HITL classification is present
- Goal Command is present for AFK issues
- bug mirrors include Reproduction or Feedback Loop evidence
- workflow metadata is present or reported as advisory migration drift
- Project Merge metadata is present and valid

## Execution Boundary

This skill creates and updates issue tracker artifacts only. It does not create implementation branches, edit product code, open PRs, merge, start `/goal`, or close issues. After publication, hand off each ready AFK issue to `$project-resolve`.

## Native Continuation Gate

After approved issue mirrors or GitHub issues are created and validated, summarize the issue set in chat before asking the continuation question. The summary must name the created or updated issue mirrors, GitHub issue links when present, AFK/HITL split, blockers, and recommended next route.

Ask a native continuation question with `request_user_input` when callable.

Question id: `project_issue_next_step`

Prompt: `How should I continue from these project issues?`

Options:

- `Resolve First Ready`: start `$project-resolve` on the first ready AFK issue.
- `Resolve Selected`: start `$project-resolve` on a user-selected ready issue.
- `Review First`: stop for user review before execution.
- `Stop`: stop after issue creation.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
