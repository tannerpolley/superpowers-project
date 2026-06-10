---
name: audit-project
description: Use when code, workflows, tests, skills, or repo behavior need evidence-backed review findings before repair planning.
---

# Project Audit

Project Audit is the findings-first sibling to Project Brainstorm. Use it when the user wants to find, diagnose, review, or fix what already exists instead of inventing a new feature direction.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question. Final completion must use an explicit final health gate with `Done`, not a `Yes` option. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Routing Role

Use this route for:

- codebase audits, review findings, bug families, workflow failures, brittle tests, confusing abstractions, or repo behavior that needs repair
- converting review results into a Superpowers Project spec under `docs/superpowers/specs/`
- evidence-backed repair work that should later route to `$superpowers-project:write-plan`, `$superpowers-project:create-issues`, or `$superpowers-project:implement-plan`

Do not use Project Audit for new feature ideation, product brainstorming, or unresolved design exploration. Use `$superpowers-project:brainstorm-spec` for that.

Do not use Project Audit for Superpowers Project structure, tracker, milestone, issue mirror, migration, or live install drift. Use `$superpowers-project:align-project` for that.

## Companion Skills

Load the narrowest applicable review skill before writing findings:

- `diagnose` for known bugs, regressions, performance problems, CI failures, or unclear failure modes
- `thermo-nuclear-code-quality-review` for strict maintainability, abstraction, duplication, giant-file, and dead-code findings
- `improve-codebase-architecture` for architecture, module boundary, domain language, testability, and dependency findings
- `react-doctor` for React behavior, component, hook, state, render, or accessibility findings

If more than one applies, use each for its own evidence lane and merge the results into one findings spec.

## Findings Format

Every finding must be evidence-backed and priority-coded:

- `P0`: blocks correctness, data safety, security, release, or core execution
- `P1`: likely user-visible breakage, high-risk workflow failure, or major maintainability blocker
- `P2`: meaningful repair that reduces risk, confusion, duplication, or future breakage
- `P3`: polish, cleanup, naming, documentation, or low-risk follow-up

Each finding must include:

- priority and short title
- exact file path and line reference when available
- observed evidence
- impact
- repair requirement
- proof oracle or validation command candidate

Do not create findings from vibes. If evidence is missing, record the missing evidence as a question or revisit route, not as a finding.

## Output Spec

Save the audit output as a Markdown spec:

`docs/superpowers/specs/YYYY-MM-DD-<slug>-audit-findings.md`

The spec must include:

- scope and review question
- companion skills used
- checked artifacts
- P-coded findings
- non-findings or healthy checks when relevant
- recommended repair route
- proof oracle candidates
- open questions that block planning

After saving the spec, the default forward route is `$superpowers-project:write-plan` when the findings are ready for implementation planning. Use `$superpowers-project:create-issues` only when the findings are already issue-ready.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not perform repairs and must not be used to pretend a live user approved mutation.

## Native Continuation Gate

After the findings spec is ready, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed audit artifact, including the findings spec, evidence snippets, P0/P1/P2/P3 findings, healthy checks, skipped checks, open questions, and any machine-readable artifacts when present. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names P0, P1, P2, and P3 findings, healthy checks, skipped checks, open questions, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_audit_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: turn the findings spec into repair planning or issue work.
- Revisit: review findings, gather more evidence, or rerun a narrower audit lane.
- Stop: break the continuation loop.

If the user selects `Prepare Repair Work`, ask:

Question id: `project_audit_progress_route`

Prompt: `Which repair route should start from the findings spec?`

Options:

- `Write Plan`: start `$superpowers-project:write-plan` from the findings spec.
- `Create Issues`: start `$superpowers-project:create-issues` only when the findings are issue-ready.

If the user selects `Review Or Extend Findings`, ask:

Question id: `project_audit_revisit_route`

Prompt: `How should I revisit these findings?`

Options:

- `Review First`: show the findings spec and evidence summary, then return to `project_audit_next_step`.
- `Gather More Evidence`: inspect the requested source or load another companion skill, then return to `project_audit_next_step`.
- `Rerun Focused Audit`: rerun the applicable companion skill on a narrower scope, then return to `project_audit_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
