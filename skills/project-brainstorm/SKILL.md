---
name: project-brainstorm
description: Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need Superpowers brainstorming plus project context and native user-input grilling.
---

# Project Brainstorm

Project Brainstorm is the Superpowers Project adapter for `superpowers:brainstorming`. It keeps the Superpowers design-first flow, adds project context and roadmap awareness, and uses native Default mode questions for decisions that should not become assumptions.

**Announce at start:** "I'm using the project-brainstorm skill with superpowers:brainstorming."

## Required Method

Use `superpowers:brainstorming` as the base workflow. Do not implement code, create issues, write implementation plans, start issue execution, create branches, open PRs, or merge work from this skill.

Native UI is mandatory for brainstorming decisions. If there is the slightest hint of a shared decision, fork, preference, naming choice, scope boundary, tradeoff, assumption, or path to figure out, call `request_user_input` when the tool is callable. Do not answer a brainstorming decision in prose when `request_user_input` is callable.

Ask one to three short questions per call. Batch independent questions; ask dependent branches sequentially. Put the recommended option first when codebase evidence supports one, but still ask unless the user explicitly authorized automatic recommended defaults.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal brainstorming or to pretend a live user approved product, architecture, PRD, or scope decisions.

## Context First

For repo-backed work, inspect codebase and project context before asking user-facing questions unless the repo cannot be read. Inspect:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones`
- existing `docs/superpowers/specs`
- existing `docs/superpowers/plans`
- existing `docs/superpowers/issues`
- `CONTEXT.md`, context maps, and `docs/adr` when present
- relevant code, tests, workflows, GitHub issues, labels, and milestones when the topic touches them

After inspection, report back with evidence gathered, decision points, and assumptions to remove, then use native UI to resolve those choices. Use this evidence to challenge fuzzy terms, stale claims, hidden dependencies, duplicated workflows, and scope that is too large for one spec.

## Matt-Style Grilling

Carry this grill-me wording verbatim into brainstorming and planning questions when assumptions are still loose:

`Interview me relentlessly about every aspect of this plan`

Use the same grilling pressure as `$project-brainstorm` plus `grill-me`. Do not settle for the first plausible interpretation when a term, boundary, owner, workflow, success criterion, or tradeoff can be sharpened.

Treat `grill-with-docs` as source behavior for repo-aware challenge: compare the user's terms against context docs, ADRs, project context, milestones, and code reality. Surface contradictions directly and turn them into decisions.

## Supporting Skill Routes

Use the smallest supporting set:

- `grill-with-docs` behavior for docs-aware challenge and terminology pressure
- `to-prd` behavior only for product-shaped work that needs user, market, scope, success metric, and release framing
- `improve-codebase-architecture` for module boundaries, package layout, dependency direction, duplicated paths, or testability concerns
- `diagnose` or `superpowers:systematic-debugging` when the request is actually a bug or regression, then return to brainstorming once the failure shape is understood

## Output Contract

Save approved specs to `docs/superpowers/specs/<yyyy-mm-dd>-<slug>.md` unless the user explicitly chooses a different repo-local Superpowers Project destination. A `-design`, `-prd`, or similar suffix is allowed when it clarifies the artifact type, but the date and slug are the required filename parts.

Project Brainstorm writes loose specs in the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: brainstorming produces loose specs, `$project-plan` turns approved source material into milestone-aware execution design, and `$project-issue` creates official implementation records. For loose specs, milestone identity is optional and only used when naturally helpful; do not require GitHub issue metadata, source plans, implementation branches, proof oracles, or issue-ready execution metadata.

Milestone pages are index views. They should link to flat canonical specs, plans, and issues rather than owning nested copies. Represent milestone/category views through frontmatter plus milestone indexes. If a brainstorm finds `docs/superpowers/milestones/<milestone>/specs`, `plans`, or `issues` being treated as canonical, report that nested canonical milestone artifact folders are drift and route to `$project-doctor` or `$project-plan` for migration guidance.

A saved spec should include:

- project context evidence used
- user decisions and open questions
- recommended approach with tradeoffs
- non-goals
- optional milestone linkage from `docs/superpowers/milestones`
- GitHub issue or PRD linkage when already known
- proof oracle candidates for later planning

Before reporting the spec ready, self-review for placeholders, contradictions, ambiguous wording, and scope that should be split before `project-plan` runs.

## Native Continuation Gate

After saving or revising the brainstorm artifact, summarize the spec, PRD, architecture decision, or unresolved decision set in chat before asking the continuation question. The summary must name the artifact path when one was saved, the key decisions made, remaining open questions, and the recommended next route.

Ask a native continuation question with `request_user_input` when callable.

Question id: `project_brainstorm_next_step`

Prompt: `How should I continue from this brainstorm?`

Options:

- `Project Plan`: start `$project-plan` from the approved spec or decision summary.
- `Review First`: stop for user review before planning or issue creation.
- `Revise Spec`: continue `$project-brainstorm` to revise the saved spec or decision summary.
- `Stop`: stop after the brainstorm closeout.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
