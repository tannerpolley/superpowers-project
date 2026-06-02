---
name: project-context
description: Create or maintain the Superpowers Project context, milestone map, GitHub tracker configuration, and roadmap artifacts under docs/superpowers.
---

# Project Context

Use this skill when a repo needs the Superpowers Project large-context layer: durable intent, roadmap framing, milestone pages, tracker rules, and the shared map that makes Superpowers specs, plans, and issues add up to a coherent project.

## Purpose

Project context gives agents the bigger picture before they brainstorm, plan, split issues, or execute work. It should explain why the project exists, what milestones mean, how GitHub is linked, and which artifacts are canonical.

## Required Artifacts

A Superpowers Project repo must keep these artifacts current:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones/`
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
- `docs/superpowers/issues/`

Create missing directories only when the repo is adopting Superpowers Project or when the user explicitly asks to repair project structure.

## Native Question Policy

Use `request_user_input` when callable in Default mode for decisions that affect roadmap shape, milestone boundaries, GitHub policy, or `/goal` issue execution criteria. Ask one to three short questions, with mutually exclusive choices when the UI supports it. If a choice depends on the answer to an earlier question, ask it after that answer.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal project setup or to pretend a live user approved roadmap, milestone, GitHub, or `/goal` execution decisions.

## Project context shape

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

## Validation

Before reporting setup or repair complete, verify:

- `docs/superpowers/PROJECT_CONTEXT.md` exists and names the artifact model.
- `docs/superpowers/milestones` exists and contains a README or milestone pages.
- GitHub tracker config names the repository when issue mirrors or milestones are used.
- `/goal` execution criteria are present for issue work that can be assigned to an agent.
- Superpowers Project skill names are listed where agents will discover them.
