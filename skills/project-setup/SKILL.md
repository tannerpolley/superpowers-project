---
name: project-setup
description: Create or maintain the Superpowers Project setup, milestone map, GitHub tracker configuration, GitHub Project board configuration, and roadmap artifacts under docs/superpowers.
---

# Project Setup

Use this skill when a repo needs the Superpowers Project setup layer: durable intent, roadmap framing, milestone pages, tracker rules, approved GitHub Project board configuration, and the shared map that makes Superpowers specs, plans, and issues add up to a coherent project.

## Purpose

Project setup gives agents the bigger picture before they brainstorm, plan, split issues, or execute work. It should explain why the project exists, what milestones mean, how GitHub is linked, which optional board surfaces exist, and which artifacts are canonical.

## Required Artifacts

A Superpowers Project repo must keep these artifacts current:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones/`
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
- `docs/superpowers/issues/`

Create missing directories only when the repo is adopting Superpowers Project or when the user explicitly asks to repair project structure.

## Artifact Source Of Truth

Superpowers Project uses flat canonical roots for the implementation artifact lifecycle:

- loose specs live under `docs/superpowers/specs`
- implementation plans live under `docs/superpowers/plans`
- GitHub issue mirrors live under `docs/superpowers/issues`

The lifecycle is `spec -> plan -> issue`. Specs are loose specs: idea, design, PRD, or brainstorming records that may mention related milestones, packages, categories, or future issue candidates, but they do not need GitHub issue metadata, source plans, implementation branches, proof oracles, or issue-ready execution fields. Plans become the milestone-aware execution design when work is implementation-facing. Issues are the official implementation records and require tracker metadata, milestone ownership, acceptance criteria, proof oracle, AFK/HITL classification, branch, and worktree execution fields.

Milestone pages are index views. They may list related specs, plans, and issues, but they link to the flat canonical roots instead of owning nested canonical copies. Represent milestone/category views through artifact frontmatter plus milestone indexes. Treat nested canonical milestone artifact folders are drift, including `docs/superpowers/milestones/<milestone>/specs`, `docs/superpowers/milestones/<milestone>/plans`, and `docs/superpowers/milestones/<milestone>/issues`, unless an approved generator explicitly marks the path as generated index/view output.

## Native Question Policy

Use `request_user_input` when callable in Default mode for decisions that affect roadmap shape, milestone boundaries, GitHub policy, or `/goal` issue execution criteria. Ask one to three short questions, with mutually exclusive choices when the UI supports it. If a choice depends on the answer to an earlier question, ask it after that answer.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal project setup or to pretend a live user approved roadmap, milestone, GitHub, board creation, or `/goal` execution decisions.

## Project Context Shape

`docs/superpowers/PROJECT_CONTEXT.md` should include these sections:

- Durable Intent
- Artifact Model
- Roadmap And Milestones
- GitHub Tracker Config
- Execution Model
- Extension Skills
- Current Open Questions

Durable Intent should state what Superpowers Project adds on top of Superpowers. Artifact Model should name the canonical `docs/superpowers` paths. Execution Model should state that issue execution uses native `/goal` or goal tools plus Superpowers execution skills.

## Milestone page shape

Each page under `docs/superpowers/milestones` should describe one roadmap bucket and include:

- Purpose
- GitHub Milestone
- Related Specs
- Related Plans
- Related Issues
- Success Criteria

Milestones are durable project map entries, not one-off task notes. Keep them short enough to scan and specific enough to guide issue decomposition.

## GitHub tracker config

When the repo is GitHub-linked, record the tracker config in project docs and keep it consistent with issue mirrors:

- Repository owner/name
- GitHub Issue labels
- GitHub Milestone titles
- Issue mirror path: `docs/superpowers/issues/<issue-number>-<slug>.md`
- Source spec or source plan path
- AFK/HITL classification policy
- Goal Command or native goal activation expectations

Issue mirrors should match GitHub issue body and status closely enough that an agent can audit drift before changing code.

## GitHub Project Board Setup

When a repo is GitHub-linked, `$project-setup` can create or verify a GitHub Project board after native approval.

Board setup is optional project-management evidence. GitHub Projects must not become canonical storage for specs, plans, issue mirrors, or milestone pages. The canonical artifacts remain under `docs/superpowers`.

Before creating or mutating a board, summarize the proposed board title, repository, milestone/status fields, issue-linking scope, and dry-run evidence, then ask native question `project_setup_board_approval` with `Create Board`, `Verify Only`, and `Stop` options. Do not call `gh project` mutation commands unless the selected action is `create`.

Record board configuration in `docs/agents/project-roadmap.json` and, when useful for humans, `docs/agents/project-roadmap.md`.

## Validation

Before reporting setup or repair complete, verify:

- `docs/superpowers/PROJECT_CONTEXT.md` exists and names the artifact model.
- `docs/superpowers/milestones` exists and contains a README or milestone pages.
- GitHub tracker config names the repository when issue mirrors or milestones are used.
- `/goal` execution criteria are present for issue work that can be assigned to an agent.
- Superpowers Project skill names are listed where agents will discover them, including `$project-setup`.

## Native Continuation Gate

After creating, auditing, or repairing project setup, summarize the setup result in chat before asking the continuation question. The summary must name changed or verified artifacts, unresolved roadmap or tracker decisions, GitHub Project board status when relevant, and the recommended next workflow.

Ask a native continuation question with `request_user_input` when callable.

Question id: `project_setup_next_step`

Prompt: `How should I continue from this project setup work?`

Options:

- `Project Brainstorm`: start `$project-brainstorm` for a spec, PRD, architecture idea, or product direction.
- `Project Plan`: start `$project-plan` from an approved spec or issue mirror.
- `Project Issue`: start `$project-issue` for vertical slices and GitHub issue mirrors.
- `Project Doctor`: start `$project-doctor` for drift audit or repair planning.
- `Review First`: stop for user review before routing.
- `Stop`: stop after the project context closeout.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
