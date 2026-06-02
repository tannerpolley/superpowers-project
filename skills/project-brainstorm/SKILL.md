---
name: project-brainstorm
description: Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need Superpowers brainstorming plus project context and native user-input grilling.
---

# Project Brainstorm

Project Brainstorm is the Superpowers Project adapter for `superpowers:brainstorming`. It keeps the Superpowers design-first flow, adds project context and roadmap awareness, and uses native Default mode questions for decisions that should not become assumptions.

**Announce at start:** "I'm using the project-brainstorm skill with superpowers:brainstorming."

## Required Method

Use `superpowers:brainstorming` as the base workflow. Do not implement code, create issues, write implementation plans, start issue execution, create branches, open PRs, or merge work from this skill.

Use `request_user_input` in Default mode when the tool is callable and a material decision needs the user. Ask one to three short questions per call. Batch independent questions; ask dependent branches sequentially.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal brainstorming or to pretend a live user approved product, architecture, PRD, or scope decisions.

## Context First

Inspect the project context before grilling or designing:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones`
- existing `docs/superpowers/specs`
- existing `docs/superpowers/plans`
- existing `docs/superpowers/issues`
- `CONTEXT.md`, context maps, and `docs/adr` when present
- relevant code, tests, workflows, GitHub issues, labels, and milestones when the topic touches them

Use this evidence to challenge fuzzy terms, stale claims, hidden dependencies, duplicated workflows, and scope that is too large for one spec.

## Matt-Style Grilling

Carry this grill-me wording verbatim into brainstorming and planning questions when assumptions are still loose:

`Interview me relentlessly about every aspect of this plan`

Treat `grill-with-docs` as source behavior for repo-aware challenge: compare the user's terms against context docs, ADRs, project context, milestones, and code reality. Surface contradictions directly and turn them into decisions.

## Supporting Skill Routes

Use the smallest supporting set:

- `grill-with-docs` behavior for docs-aware challenge and terminology pressure
- `to-prd` behavior only for product-shaped work that needs user, market, scope, success metric, and release framing
- `improve-codebase-architecture` for module boundaries, package layout, dependency direction, duplicated paths, or testability concerns
- `diagnose` or `superpowers:systematic-debugging` when the request is actually a bug or regression, then return to brainstorming once the failure shape is understood

## Output Contract

Save approved specs to `docs/superpowers/specs/YYYY-MM-DD-<slug>-design.md` unless the user explicitly chooses a different repo-local destination.

A saved spec should include:

- project context evidence used
- user decisions and open questions
- recommended approach with tradeoffs
- non-goals
- milestone linkage from `docs/superpowers/milestones`
- GitHub issue or PRD linkage when already known
- proof oracle candidates for later planning

Before reporting the spec ready, self-review for placeholders, contradictions, ambiguous wording, and scope that should be split before `project-writing-plan` runs.
