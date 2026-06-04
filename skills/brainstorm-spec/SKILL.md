---
name: brainstorm-spec
description: Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need Superpowers brainstorming plus project context and native user-input grilling.
---

# Project Brainstorm

Project Brainstorm is the Superpowers Project adapter for `superpowers:brainstorming`. It keeps the Superpowers design-first flow, adds project context and roadmap awareness, and uses native Default mode questions for decisions that should not become assumptions.

**Announce at start:** "I'm using the brainstorm-spec skill with superpowers:brainstorming."

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or `Done`. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` or `Done` option is terminal. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

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

Use the same grilling pressure as `$project:brainstorm-spec` plus `grill-me`. Do not settle for the first plausible interpretation when a term, boundary, owner, workflow, success criterion, or tradeoff can be sharpened.

Treat `grill-with-docs` as source behavior for repo-aware challenge: compare the user's terms against context docs, ADRs, project context, milestones, and code reality. Surface contradictions directly and turn them into decisions.

## Supporting Skill Routes

Use the smallest supporting set:

- `grill-with-docs` behavior for docs-aware challenge and terminology pressure
- `to-prd` behavior only for product-shaped work that needs user, market, scope, success metric, and release framing
- `improve-codebase-architecture` for module boundaries, package layout, dependency direction, duplicated paths, or testability concerns
- `diagnose` or `superpowers:systematic-debugging` when the request is actually a bug or regression, then return to brainstorming once the failure shape is understood

## Output Contract

Save approved specs to `docs/superpowers/specs/<yyyy-mm-dd>-<slug>.md` unless the user explicitly chooses a different repo-local Superpowers Project destination. A `-design`, `-prd`, or similar suffix is allowed when it clarifies the artifact type, but the date and slug are the required filename parts.

Project Brainstorm writes loose specs in the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: brainstorming produces loose specs, `$project:write-plan` turns approved source material into milestone-aware execution design, and `$project:create-issues` creates official implementation records. For loose specs, milestone identity is optional and only used when naturally helpful; do not require GitHub issue metadata, source plans, implementation branches, proof oracles, or issue-ready execution metadata.

Milestone pages are index views. They should link to flat canonical specs, plans, and issues rather than owning nested copies. Represent milestone/category views through frontmatter plus milestone indexes. If a brainstorm finds `docs/superpowers/milestones/<milestone>/specs`, `plans`, or `issues` being treated as canonical, report that nested canonical milestone artifact folders are drift and route to `$project:audit-project` or `$project:write-plan` for migration guidance.

A saved spec should include:

- project context evidence used
- user decisions and open questions
- recommended approach with tradeoffs
- non-goals
- optional milestone linkage from `docs/superpowers/milestones`
- GitHub issue or PRD linkage when already known
- proof oracle candidates for later planning

Before reporting the spec ready, self-review for placeholders, contradictions, ambiguous wording, and scope that should be split before `write-plan` runs.

## Native Continuation Gate

After saving or revising the brainstorm artifact, summarize the spec, PRD, architecture decision, or unresolved decision set in chat before asking the continuation question. The summary must name the artifact path when one was saved, the key decisions made, assumptions removed, remaining open questions, and the recommended next route. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions with `request_user_input` when callable. Use flowchart geometry: Down is default progress, Left is revise/review/repair/rerun/recover, and Right is `Stop / Done`. Use as many native questions and options as the decision requires. Prefer the simple Down / Left / Right shape for generic continuation gates, but show all real peer routes when that is clearer. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree.

Question id: `project_brainstorm_next_step`

Prompt: `How should I continue from this brainstorm?`

Options:

- Down: `Continue From Spec`: choose how to turn the brainstorm artifact into planning work.
- Left: `Revise / Review Brainstorm`: revise, review, ask follow-ups, or run another brainstorm loop.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Continue From Spec`, ask:

Question id: `project_brainstorm_plan_route`

Prompt: `How should planning start from this brainstorm?`

Options:

- Down: `Create One Plan`: create one `$project:write-plan` from the recently generated spec.
- Left: `Multi-Spec Planning`: choose whether to create one plan from multiple specs or multiple related plans.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Multi-Spec Planning`, ask:

Question id: `project_brainstorm_multi_spec_route`

Prompt: `How should multiple specs become plans?`

Options:

- Down: `Plan Multiple Specs`: create one `$project:write-plan` from multiple existing specs; prompt for spec selection if not already known.
- Left: `Create Multiple Plans`: create multiple related plans from multiple specs; prompt for spec-to-plan grouping if not already known.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Revise / Review Brainstorm`, ask:

Question id: `project_brainstorm_reiteration_route`

Prompt: `How should I revisit this brainstorm output?`

Options:

- Down: `Revise Spec`: continue `$project:brainstorm-spec` with follow-up questions to revise the saved spec or decision summary.
- Left: `Review Or Restart`: choose whether to review the current artifact or brainstorm another idea.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Review Or Restart`, ask:

Question id: `project_brainstorm_review_restart_route`

Prompt: `Should I review this brainstorm or start another one?`

Options:

- Down: `Review First`: show the rendered artifact and ask for follow-up confirmation, then return to `project_brainstorm_next_step`.
- Left: `Re-run Brainstorm`: start another `$project:brainstorm-spec` cycle for a new feature, idea, or major alternative.
- Right: `Stop / Done`: break the continuation loop.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

