---
name: create-issues
description: Use when a Superpowers Project spec, plan, PRD, or approved scope needs vertical-slice GitHub issues and synced issue mirrors.
---

# Project Issue

Project Issue turns approved Superpowers Project source material into GitHub issues and local issue mirrors. It borrows `to-issues` tracer-bullet behavior, keeps issues independently grabbable, and records enough structure for `$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues` to execute one issue at a time with their mandatory Superpowers companion skills.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question. Final completion must use an explicit final health gate with `Done`, not a `Yes` option. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

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

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with the plugin-provided Auto Mode validator (`scripts/validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `route_policy.issue_route: direct-inline-resolve-issue`, and `stop_outside_policy: true`.

Auto Mode may create issue mirrors and GitHub issues only from the authorized source spec or a plan derived from that source spec. It may classify AFK/HITL, choose issue count, assign proof oracles, and hand the first ready AFK issue to `$superpowers-project:resolve-issue` for direct current-thread execution when repo evidence supports the choice. Auto Mode must not route issue execution to `$superpowers-project:orchestrate-issues`. If issue boundaries, labels, milestone, dependencies, publication, GitHub auth, proof policy, or delegated worker execution require a decision outside the ledger, stop outside policy before publishing or handing issues to execution.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not publish GitHub issues or pretend a live user approved issue boundaries, dependencies, labels, milestones, AFK/HITL classification, or publication.
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

Issue mirrors live in the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: specs stay loose, plans become milestone-aware execution design, and issue mirrors are the official implementation records. Do not create canonical issue mirrors under `docs/superpowers/milestones/<milestone>/issues`.

Published issue mirrors include the GitHub issue number in the filename, using `docs/superpowers/issues/<issue-number>-<slug>.md`. Pre-publication drafts may omit the number until GitHub returns one. Milestone pages are index views: they link to flat canonical issues instead of owning copies, and milestone/category views are represented through frontmatter plus milestone indexes. Treat nested canonical milestone artifact folders are drift.

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
- Outcome Summary
- Outcome Source
- Intent
- Target Output
- Owner
- Interface
- Cutover
- Replaced Path
- Acceptance Proof
- Stop Criteria
- Avoid
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

Workflow metadata guides `$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues`. Missing or malformed workflow metadata is blocking for every issue mirror because it creates ambiguous execution instructions. Issue metadata must keep downstream routing compatible with the mandatory Superpowers companion skills used by those execution routes. `Execution Mode` should normally be `Ask at runtime` so the resolver asks whether to solve inline or open a worker worktree thread.

Every issue mirror must include `## Outcome Summary`. The summary carries the plan's outcome proof into issue execution and must include `Outcome Source`, `Intent`, `Target Output`, `Owner`, `Interface`, `Cutover`, `Replaced Path`, `Acceptance Proof`, `Stop Criteria`, and `Avoid`. The summary may narrow a multi-issue slice, but it must not drop or contradict the source plan's owner, interface, cutover, replaced path handling, acceptance proof, stop criteria, or avoid list.

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

## Outcome Summary

**Outcome Source:** <source plan path>#outcome-proof
**Intent:** <issue slice intent>
**Target Output:** <target person or operator-visible result>
**Owner:** <module, artifact, or process that owns durable truth>
**Interface:** <interface consumed by downstream execution>
**Cutover:** <delete, redirect, demote, shim with removal trigger, or explicitly keep>
**Replaced Path:** <old behavior, artifact, route, doc, or source file>
**Acceptance Proof:** <target-perspective proof>
**Stop Criteria:** <condition that blocks or retires temporary paths>
**Avoid:** <moves that would create wrong ownership, duplicate truth, or fake proof>

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

Use the bundled `scripts/validate-issue-mirror.ps1 -IssueFile <docs/superpowers/issues/file.md>` before publishing an issue mirror or handing it to `$superpowers-project:resolve-issue`.

Validation must prove:

- the mirror path is under `docs/superpowers/issues`
- source spec or source plan exists
- GitHub Issue is present or the mirror is explicitly pre-publication
- GitHub Milestone is present when milestone policy is hard
- Acceptance Criteria are checkboxes
- AFK/HITL classification is present
- Goal Command is present for AFK issues
- bug mirrors include Reproduction or Feedback Loop evidence
- workflow metadata is present and valid
- Outcome Summary is present and valid
- Outcome Source does not use `docs/goals`
- Interface, Cutover, Acceptance Proof, Stop Criteria, and Avoid are concrete
- Project Merge metadata is present and valid

## External GitHub Issue Hydration

External GitHub issues are intake, not ready execution inputs, until they have local mirrors and source artifacts. In routing checks, external GitHub issues are intake until the local mirror and source plan validation passes. Use `scripts/hydrate-external-issue.ps1` when a GitHub issue exists before `docs/superpowers/issues/<issue-number>-<slug>.md` or when the issue body contains `Source Plan: TBD`.

Protocol:

1. Read the GitHub issue body from `IssueBodyPath` for fixture work or from `gh issue view <url>` for live tracker work.
2. Create or update `docs/superpowers/issues/<issue-number>-<slug>.md`.
3. Preserve the issue URL, title, milestone, labels, branch/worktree policy, acceptance criteria, proof oracle, and goal command.
4. Create or update `## Outcome Summary` with `Outcome Source`, `Interface`, `Cutover`, `Acceptance Proof`, `Stop Criteria`, and `Avoid` before validation.
5. If `Source Spec` or `Source Plan` is missing or `TBD`, create a defensible source plan under `docs/superpowers/plans` from the issue body and repo context before execution.
6. Validate the local mirror with `scripts/validate-issue-mirror.ps1`.
7. Only then route to `$superpowers-project:resolve-issue` or `$superpowers-project:orchestrate-issues`.

Hydration may create a source plan and pass mirror validation in the same command, but the original GitHub issue remains intake until the local mirror and source plan exist and validation has passed. Do not hand raw GitHub issue text to execution skills.

Script contract:

```powershell
scripts/hydrate-external-issue.ps1 -RepoRoot . -IssueUrl <github-issue-url> [-IssueBodyPath <body.md>] [-IssueTitle <title>] [-OutputPlanSlug <slug>]
```

## Execution Boundary

This skill creates and updates issue tracker artifacts only. It does not create implementation branches, edit product code, open PRs, merge, start `/goal`, or close issues. After publication, hand off each ready AFK issue to `$superpowers-project:resolve-issue`.

## Native Continuation Gate

After approved issue mirrors or GitHub issues are created and validated, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed issue-publication artifact, including each created or updated issue mirror, full issue body, GitHub issue link when present, AFK/HITL classification, blockers, dependencies, and validation result. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names the created or updated issue mirrors, GitHub issue links when present, AFK/HITL split, blockers, dependencies, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_issue_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: choose direct resolve or worker orchestration.
- Revisit: revise, reslice, review, or repair issue mirrors.
- Stop: break the continuation loop.

If the user selects `Continue Issue Execution`, ask:

Question id: `project_issue_execution_route`

Prompt: `How should these issues be executed?`

Options:

- `Resolve Issues`: choose a direct current-thread issue resolution route.
- `Orchestrate Issues`: choose a worker-thread orchestration route.

If the user selects `Resolve Issues`, ask:

Question id: `project_issue_resolve_route`

Prompt: `Which issue should be resolved directly?`

Options:

- `Resolve First Ready`: start `$superpowers-project:resolve-issue` on the first ready AFK issue.
- `Resolve Selected`: ask for or use a selected ready issue mirror, then start `$superpowers-project:resolve-issue`.

If the user selects `Orchestrate Issues`, ask:

Question id: `project_issue_orchestrate_route`

Prompt: `Which issue should be delegated to a worker?`

Options:

- `Orchestrate First Ready`: start `$superpowers-project:orchestrate-issues` on the first ready worker-suitable issue.
- `Orchestrate Selected`: ask for or use a selected ready issue mirror, then start `$superpowers-project:orchestrate-issues`.

If the user selects `Revise / Review Issues`, ask:

Question id: `project_issue_reiteration_route`

Prompt: `How should I revisit this issue set?`

Options:

- `Revise Or Reslice Issues`: revise issue boundaries or reslice the set, then return to `project_issue_next_step`.
- `Review Or Repair Issues`: choose whether to review the issue set or repair mirrors.

If the user selects `Review Or Repair Issues`, ask:

Question id: `project_issue_review_repair_route`

Prompt: `Should I review the issues or repair mirrors?`

Options:

- `Review First`: show rendered issue mirrors and ask for follow-up confirmation, then return to `project_issue_next_step`.
- `Repair Issue Mirrors`: repair local mirror drift, then return to `project_issue_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

