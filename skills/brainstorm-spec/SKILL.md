---
name: brainstorm-spec
description: Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need Superpowers brainstorming plus project context and native user-input grilling.
---

# Project Brainstorm

Project Brainstorm is the Superpowers Project adapter for `superpowers:brainstorming`. It keeps the Superpowers design-first flow, adds project context and roadmap awareness, and uses native Default mode questions for decisions that should not become assumptions.

**Announce at start:** "I'm using the brainstorm-spec skill with superpowers:brainstorming."

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question. Final completion must use an explicit final health gate with `Done`, not a `Yes` option. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Required Method

Use `superpowers:brainstorming` as the base workflow. Do not implement code, create issues, write implementation plans, start issue execution, create branches, open PRs, or merge work from this skill.

Native UI is mandatory for brainstorming decisions. If there is the slightest hint of a shared decision, fork, preference, naming choice, scope boundary, tradeoff, assumption, or path to figure out, call `request_user_input` when the tool is callable. Do not answer a brainstorming decision in prose when `request_user_input` is callable.

Use the smallest native question shape that preserves the real decision tree. Batch independent questions; ask dependent branches sequentially. Use more than three options only inside a selected branch, for data-backed selections, or for independent bulk decisions. Put the recommended option first when codebase evidence supports one, but still ask unless the user explicitly authorized automatic recommended defaults.

## Upstream Brainstorming Checklist Gate

The upstream `superpowers:brainstorming` checklist is mandatory. The project adapter may add repo context, native questions, artifact display, and continuation routing, but it must not weaken, reorder, compress, or skip the upstream design-first gate.

For every brainstorm run, the agent MUST create checklist tasks and complete them in order before moving to the next phase:

1. Explore project context before asking user-facing questions unless the repo cannot be read.
2. Offer visual companion in its own message when visual or spatial questions are ahead.
3. Ask clarifying questions one at a time until the decision shape is sharp enough to design.
4. Propose 2-3 approaches named `Design 1`, `Design 2`, and optional `Design 3`, each with tradeoffs and a recommendation. At least Design 1 and Design 2 must be real alternatives; do not collapse them into one preferred answer.
5. The agent must present design sections and get approval after each section. Required sections include architecture, components, data flow, error handling, and testing.
6. Write design doc to `docs/superpowers/specs/<yyyy-mm-dd>-<slug>.md` or the user-selected repo-local Superpowers Project spec path.
7. Spec self-review for placeholders, contradictions, unclear scope, ambiguous wording, and missing proof oracles; fix issues before calling the spec ready.
8. User reviews written spec before proceeding. Do not infer approval from silence, prior enthusiasm, a custom `Other` answer, or a stale thread state.
9. Transition only to `$superpowers-project:write-plan` or `superpowers:writing-plans` after the checklist, written spec, self-review, artifact display, and user review are complete.

Do NOT invoke implementation, issue creation, branch work, PR work, merge work, or planning before this gate is satisfied. Auto Mode authorization is forbidden until the same gate is satisfied and the saved spec has passed the artifact review and user-review checks.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not pretend a live user approved product, architecture, PRD, or scope decisions.
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

Use the same grilling pressure as `$superpowers-project:brainstorm-spec` plus `grill-me`. Do not settle for the first plausible interpretation when a term, boundary, owner, workflow, success criterion, or tradeoff can be sharpened.

Treat `grill-with-docs` as source behavior for repo-aware challenge: compare the user's terms against context docs, ADRs, project context, milestones, and code reality. Surface contradictions directly and turn them into decisions.

## Supporting Skill Routes

Use the smallest supporting set:

- `grill-with-docs` behavior for docs-aware challenge and terminology pressure
- `to-prd` behavior only for product-shaped work that needs user, market, scope, success metric, and release framing
- `improve-codebase-architecture` for module boundaries, package layout, dependency direction, duplicated paths, or testability concerns
- `diagnose` or `superpowers:systematic-debugging` when the request is actually a bug or regression, then return to brainstorming once the failure shape is understood

## Companion Interface Opt-In

When the user asks for the companion, or when rendered specs, design alternatives, project-context evidence, or saved spec previews would be too large for chat, use `$superpowers-project:companion-interface` to create or refresh a repo-owned Agent-Native visual-plan MDX artifact. Include project context evidence, design alternatives, user decisions, open questions, saved spec path, and recommended next route.

The companion is an evidence surface only; native approval, user review, and continuation decisions still happen through chat or `request_user_input`.

## Output Contract

Save approved specs to `docs/superpowers/specs/<yyyy-mm-dd>-<slug>.md` unless the user explicitly chooses a different repo-local Superpowers Project destination. A `-design`, `-prd`, or similar suffix is allowed when it clarifies the artifact type, but the date and slug are the required filename parts.

Project Brainstorm writes loose specs in the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: brainstorming produces loose specs, `$superpowers-project:write-plan` turns approved source material into milestone-aware execution design, and `$superpowers-project:create-issues` creates official implementation records. For loose specs, milestone identity is optional and only used when naturally helpful; do not require GitHub issue metadata, source plans, implementation branches, proof oracles, or issue-ready execution metadata.

Milestone pages are index views. They should link to flat canonical specs, plans, and issues rather than owning nested copies. Represent milestone/category views through frontmatter plus milestone indexes. If a brainstorm finds `docs/superpowers/milestones/<milestone>/specs`, `plans`, or `issues` being treated as canonical, report that nested canonical milestone artifact folders are drift and route to `$superpowers-project:align-project` or `$superpowers-project:write-plan` for migration guidance.

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

After saving or revising the brainstorm artifact, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show the saved artifact and every produced or materially changed brainstorm artifact, including the chosen design plan, spec, PRD, architecture decision, or unresolved decision set. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize any machine-readable artifacts with their exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names the artifact path when one was saved, the key decisions made, assumptions removed, remaining open questions, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the result means for the next workflow step, what it means for the active goal, what it means for the broader project context, and the recommended next route.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_brainstorm_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: choose how to turn the brainstorm artifact into planning work.
- Revisit: revise, review, ask follow-ups, or run another brainstorm loop.
- Stop: break the continuation loop.

If the user selects `Continue From Spec`, ask:

Question id: `project_brainstorm_start_route`

Prompt: `Should I continue manually or authorize Auto Mode?`

Options:

- `Manual Planning`: choose the next planning route yourself.
- `Auto Mode`: authorize the agent to choose the route, plan, implement, verify, and merge within the bounded policy.

If the user selects `Manual Planning`, ask:

Question id: `project_brainstorm_plan_route`

Prompt: `How should planning start from this brainstorm?`

Options:

- `Create One Plan`: create one `$superpowers-project:write-plan` from the recently generated spec.
- `Multi-Spec Planning`: choose whether to create one plan from multiple specs or multiple related plans.

If the user selects `Auto Mode`, ask:

Question id: `project_auto_mode_authorization`

Prompt: `Authorize bounded Auto Mode for this saved spec?`

Options:

- `Bounded Auto Merge`: create an Auto Mode authorization ledger and continue without more user input through planning, implementation, verification, premerge proof, merge, closeout proof, and live-sync proof when applicable.
- `Manual Planning`: return to `project_brainstorm_plan_route`.

`Bounded Auto Merge` is the only valid Auto Mode approval. It must record an Auto Mode authorization ledger before the next skill starts. The ledger must include:

- `question_id: project_auto_mode_authorization`
- `source: request_user_input`
- `selected_authority: bounded-auto-merge`
- `source_spec: docs/superpowers/specs/<yyyy-mm-dd>-<slug>.md`
- `route_policy.selected_mode: agent-chooses`
- `route_policy.issue_route: direct-inline-resolve-issue`
- `decision_policy.selected_mode: recorded-defaults`
- `decision_policy.stop_outside_policy: true`
- `merge_permission.selected_mode: preauthorized-after-clean-premerge`
- `merge_permission.require_clean_premerge: true`
- `mutation_scope` containing `current-repo` and `development-branch`
- `required_proof` containing `plan-proof-oracle`, `verification-receipts`, `cleanup-hook`, `premerge-proof`, and `closeout-proof`
- `stop_conditions` containing `missing-proof`, `dirty-unsafe-state`, `failed-validation`, and `decision-outside-policy`

If a saved-spec closeout appears to omit `project_brainstorm_start_route`, `project_auto_mode_authorization`, or `Bounded Auto Merge`, treat that as stale-thread recovery. Warn that the loaded thread may still be using older skill text, re-ask the missed native route, and continue from the corrected path instead of stopping or inferring approval from the stale behavior.

Validate the ledger with the plugin-provided Auto Mode validator (`scripts/validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`). If the ledger does not pass, do not continue into Auto Mode.

If the user selects `Multi-Spec Planning`, ask:

Question id: `project_brainstorm_multi_spec_route`

Prompt: `How should multiple specs become plans?`

Options:

- `Plan Multiple Specs`: create one `$superpowers-project:write-plan` from multiple existing specs; prompt for spec selection if not already known.
- `Create Multiple Plans`: create multiple related plans from multiple specs; prompt for spec-to-plan grouping if not already known.

If the user selects `Revise / Review Brainstorm`, ask:

Question id: `project_brainstorm_reiteration_route`

Prompt: `How should I revisit this brainstorm output?`

Options:

- `Revise Spec`: continue `$superpowers-project:brainstorm-spec` with follow-up questions to revise the saved spec or decision summary.
- `Review Or Restart`: choose whether to review the current artifact or brainstorm another idea.

If the user selects `Review Or Restart`, ask:

Question id: `project_brainstorm_review_restart_route`

Prompt: `Should I review this brainstorm or start another one?`

Options:

- `Review First`: show the rendered artifact and ask for follow-up confirmation, then return to `project_brainstorm_next_step`.
- `Re-run Brainstorm`: start another `$superpowers-project:brainstorm-spec` cycle for a new feature, idea, or major alternative.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
