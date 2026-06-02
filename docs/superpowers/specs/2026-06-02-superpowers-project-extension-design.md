# Superpowers Project Extension Design

## Context

This spec consolidates the plugin redesign decisions from the conversation on June 2, 2026. The current Milestones plugin accidentally created a parallel artifact model: milestone idea files behave like Superpowers specs, and milestone issue files behave like Superpowers plans. The new direction is to stop competing with Superpowers and instead extend it.

The plugin becomes a Superpowers expansion pack:

- Superpowers remains the base workflow for brainstorming, writing plans, executing plans, TDD, debugging, code review, subagents, verification, and branch finish.
- The extension adds project memory, roadmap and milestone context, native user-input grilling, GitHub issue and milestone linkage, local issue mirrors, and native `/goal` execution.
- GoalBuddy boards are not part of the default workflow. Native `/goal` plus Superpowers execution is the primary long-running execution guard.

Working name: **Superpowers Project**.

## Problem

Superpowers is strong at method but intentionally local and task-shaped. It creates specs and plans, then executes them, but it does not provide a durable project backbone that explains why repeated specs and plans matter over time. It also predates the current native `/goal` mechanism and does not own GitHub milestone or issue synchronization.

The existing Milestones plugin provides some of that backbone, but it does so with a separate tree:

```text
docs/milestones/<milestone>/ideas/
docs/milestones/<milestone>/issues/
```

That split duplicates Superpowers concepts and invites drift. The better design is to keep the Superpowers artifact model and add project/GitHub/goal capabilities around it.

## Goals

- Preserve vanilla Superpowers behavior and file locations as the canonical artifact model.
- Add a large-scope project context and roadmap layer under `docs/superpowers`.
- Add milestone pages under `docs/superpowers/milestones`.
- Add issue mirrors under `docs/superpowers/issues` that correspond to GitHub issues.
- Use Matt Pocock style grilling to challenge assumptions during brainstorming and planning.
- Use native `request_user_input` in Default mode when it is available, without requiring Plan mode.
- Use `to-issues` style vertical slicing when converting specs or plans into GitHub issues.
- Use `diagnose` style feedback-loop discipline for bug issues.
- Use `improve-codebase-architecture` style deepening opportunities for roadmap and architecture work.
- Use `/goal` or native goal tools for issue execution.
- Remove GoalBuddy board setup from the default issue-resolution flow.
- Validate the full extension in a dummy repo before treating it as ready.

## Non-Goals

- Do not replace Superpowers skills.
- Do not mirror full specs or plans into a second milestone tree.
- Do not maintain `docs/milestones/<milestone>/ideas` or `docs/milestones/<milestone>/issues` as canonical paths in the new design.
- Do not require Matt Pocock support files for the first working version.
- Do not build a GitHub Projects workflow beyond evidence and optional dashboard linking.
- Do not use GoalBuddy boards as the default project or issue execution state.

## Recommended Artifact Model

All canonical project artifacts live under `docs/superpowers`.

```text
docs/superpowers/
  PROJECT_CONTEXT.md
  specs/
    YYYY-MM-DD-<topic>-design.md
    YYYY-MM-DD-<feature>-prd.md
  plans/
    YYYY-MM-DD-<topic>-plan.md
  issues/
    <issue-number>-<slug>.md
  milestones/
    README.md
    <milestone-slug>.md
```

`docs/superpowers/PROJECT_CONTEXT.md` is the big-picture project context. It explains what the project is trying to become, how milestones fit together, and why the specs and plans matter.

`docs/superpowers/specs` remains the Superpowers brainstorming output location. PRDs can also live here when a feature is product-shaped and needs many user stories.

`docs/superpowers/plans` remains the Superpowers writing-plans output location. Plans are execution detail and should remain richer than GitHub issue bodies.

`docs/superpowers/issues` contains local mirrors of GitHub issues. An issue mirror is the tracker contract: title, GitHub URL, milestone, source spec, source plan, acceptance checkboxes, blocked-by links, and goal command. It is not the full implementation plan.

`docs/superpowers/milestones` contains the roadmap index and milestone pages. Milestone pages link to relevant specs, plans, issues, GitHub milestones, and open questions.

Optional Matt-compatible docs remain supported:

```text
CONTEXT.md
docs/adr/
docs/agents/issue-tracker.md
docs/agents/triage-labels.md
docs/agents/domain.md
```

These files help Matt-style skills share vocabulary, ADRs, tracker config, triage labels, and domain-doc location. They are useful but not required for the first extension version.

## Canonical Workflow

### Project Setup

The extension initializes project-level Superpowers context.

```text
docs/superpowers/PROJECT_CONTEXT.md
docs/superpowers/milestones/README.md
docs/superpowers/specs/
docs/superpowers/plans/
docs/superpowers/issues/
```

If the repo uses GitHub, setup also records:

- repository slug;
- issue tracker policy;
- label vocabulary;
- milestone policy;
- GitHub Projects policy if applicable.

### Brainstorming

Project brainstorming uses Superpowers brainstorming as the base process and adds grilling.

The extension must:

- inspect project context, milestone pages, existing specs, plans, issues, code, tests, and GitHub state where relevant;
- use native `request_user_input` in Default mode when it is available;
- batch independent questions through the native UI;
- ask sequentially when one answer changes the next valid question;
- include the `grill-me` wording as the core interrogation posture:

```text
Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions. For each question, provide your recommended answer.
```

- answer questions from code/docs instead of asking the user when local evidence is sufficient;
- challenge vague language against `CONTEXT.md`, ADRs, project context, and code reality when those files exist;
- write the final spec to `docs/superpowers/specs`.

### PRDs

PRDs are optional and should be used only for large product-shaped work. They belong in `docs/superpowers/specs` with a `-prd.md` suffix. The PRD flow borrows from `to-prd`:

- synthesize from known conversation and repo context;
- write problem statement, solution, user stories, implementation decisions, testing decisions, out of scope, and notes;
- do not require a PRD for small bugs, refactors, CI repairs, or maintenance.

### Planning

Project planning uses Superpowers writing-plans as the base process.

The extension must:

- read source spec, PRD if present, project context, milestone pages, and relevant issue mirrors;
- use native `request_user_input` in Default mode when it is available;
- run the same grilling posture before freezing scope;
- include exact files, exact verification commands, proof oracle, and required Superpowers sub-skills;
- write the plan to `docs/superpowers/plans`;
- never write implementation plans into `docs/milestones`.

### Plan To Issues

Plan-to-issue conversion uses `to-issues` vertical slicing.

The extension must:

- split plans into thin vertical slices that are independently verifiable;
- classify each slice as `AFK` or `HITL`;
- record blocked-by relationships;
- generate issue mirrors in `docs/superpowers/issues`;
- create or update GitHub issues from those mirrors;
- apply labels and milestones;
- publish issues in dependency order when creating multiple issues;
- keep issue bodies concise and tracker-oriented rather than copying the full plan.

Issue mirror shape:

```markdown
# #123 <Issue Title>

**GitHub Issue:** <url>
**GitHub Milestone:** <milestone title>
**Local Milestone:** `docs/superpowers/milestones/<milestone>.md`
**Source Spec:** `docs/superpowers/specs/<spec>.md`
**Source Plan:** `docs/superpowers/plans/<plan>.md`
**Slice Type:** AFK | HITL
**Blocked By:** <issue links or None>
**Goal Command:** `/goal <objective>`

## GitHub Issue Body

<the issue body to publish>

## Acceptance Criteria

- [ ] <criterion>
```

### Bug Work

Bug issues borrow `diagnose` discipline. A bug issue should be AFK-ready only when it either contains a reproducible feedback loop or includes explicit steps to build one.

Bug acceptance criteria should include:

- reproduce the user-reported symptom;
- capture a deterministic or high-rate feedback loop;
- write a regression test at the correct seam when one exists;
- fix the root cause;
- rerun the original repro;
- remove temporary instrumentation;
- document architecture follow-up when the code lacks a good test seam.

### Architecture Work

Architecture-heavy work borrows `improve-codebase-architecture` concepts. The extension should use the terms module, interface, implementation, depth, seam, adapter, leverage, and locality when presenting architecture opportunities.

Architecture opportunities can feed:

- `docs/superpowers/PROJECT_CONTEXT.md`;
- milestone pages;
- brainstorming specs;
- refactor issue mirrors;
- ADR suggestions when decisions are hard to reverse, surprising, and tradeoff-driven.

### Issue Triage

The extension should support the `triage` role model for GitHub issues:

- `bug`;
- `enhancement`;
- `needs-triage`;
- `needs-info`;
- `ready-for-agent`;
- `ready-for-human`;
- `wontfix`.

Actual GitHub label strings should be configurable. The first version can store this in project context or `docs/agents/triage-labels.md`.

### Issue Resolution

Issue resolution uses `/goal` plus Superpowers execution.

Default execution stack:

```text
native /goal or goal tools
superpowers:executing-plans
superpowers:subagent-driven-development when useful
superpowers:test-driven-development for features and bugs
superpowers:systematic-debugging or diagnose discipline for failures
superpowers:verification-before-completion before claims
superpowers:finishing-a-development-branch for integration choices
```

The extension must not set up GoalBuddy boards by default.

When native goal tools are callable, the resolver should create and verify the goal directly. When slash-command activation is the only route, it should produce the exact `/goal` command and stop before execution until the goal exists.

Goal objective shape:

```text
Resolve <GitHub issue URL> using <issue mirror> and <source plan>. Finish only after acceptance criteria are checked, required validation passes, PR is merged, issue is closed, and cleanup evidence is recorded.
```

## Skills

The redesigned plugin should expose a small set of extension skills.

### `superpowers-project`

Router for project extension workflows. It decides whether the user needs setup, project context, brainstorming, PRD, planning, issue generation, triage, doctor, or goal-backed resolution.

### `project-context`

Creates and maintains `docs/superpowers/PROJECT_CONTEXT.md` and `docs/superpowers/milestones`. It owns the large-scope explanation of why specs, plans, and issues exist.

### `project-brainstorm`

Runs Superpowers brainstorming with Matt-style grilling, native UI questions, project context, and milestone awareness. Writes specs under `docs/superpowers/specs`.

### `project-writing-plan`

Runs Superpowers writing-plans with project context, source spec/PRD linkage, issue linkage when present, native UI questions, and grilling. Writes plans under `docs/superpowers/plans`.

### `plan-to-issue`

Converts approved specs or plans into vertical-slice issue mirrors and GitHub issues. It owns AFK/HITL classification, blocked-by relationships, acceptance checkboxes, GitHub labels, and milestone assignment.

### `resolve-issue-with-goal`

Executes one issue through native `/goal` and Superpowers methods. It reads the issue mirror and source plan, verifies GitHub linkage, starts or verifies the goal, executes, validates, merges, closes, syncs, and records cleanup evidence.

### `project-doctor`

Audits drift between project context, milestone pages, specs, plans, issue mirrors, GitHub issues, GitHub milestones, labels, ADRs, and live plugin deployment.

## Migration From Current Milestones Plugin

The existing Milestones plugin can be migrated without preserving the separate artifact model.

Map old concepts to new ones:

```text
docs/milestones/PROJECT_CONTEXT.md
  -> docs/superpowers/PROJECT_CONTEXT.md
  -> docs/superpowers/milestones/*.md

docs/milestones/<milestone>/ideas/*.md
  -> docs/superpowers/specs/*.md

docs/milestones/<milestone>/issues/*.md
  -> docs/superpowers/issues/*.md or docs/superpowers/plans/*.md depending on content
```

When a current issue file is a detailed implementation plan, migrate it to `docs/superpowers/plans`.

When a current issue file is a GitHub issue mirror or tracker contract, migrate it to `docs/superpowers/issues`.

## Validation Strategy

The first implementation should remain vanilla Superpowers until the extension works in a dummy repo.

Validation should include:

- plugin manifest validation;
- skill quick validation;
- scenario tests for every extension skill;
- path-contract tests proving artifacts use `docs/superpowers`;
- no writes to `docs/milestones` for canonical specs, plans, or issues;
- dummy repo setup;
- dummy repo project context creation;
- dummy repo brainstorm/spec creation using native UI contract checks where testable;
- dummy repo plan creation;
- dummy repo plan-to-issue mirror generation;
- dummy GitHub issue creation path through fixtures or a dry-run mode;
- dummy issue resolution setup proving `/goal` is required and GoalBuddy boards are not created;
- final sync-live validation.

## Open Decisions Resolved

- Canonical artifact root: `docs/superpowers`.
- Separate `docs/milestones` tree: removed from the target model.
- Milestones remain as project concepts under `docs/superpowers/milestones`.
- Issue mirrors belong under `docs/superpowers/issues`.
- PRDs live under `docs/superpowers/specs` with a `-prd.md` suffix.
- Matt-style files are optional compatibility/context helpers.
- GoalBuddy boards are not part of default issue resolution.
- Native `/goal` is required for issue execution.
- Dummy repo validation is required before considering the extension ready.
