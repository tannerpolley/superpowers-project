---
name: audit-project
description: Use when code, workflows, tests, skills, or repo behavior need evidence-backed review findings before repair planning.
---

# Project Audit

Project Audit is the findings-first sibling to Project Brainstorm. Use it when the user wants to find, diagnose, review, or fix what already exists instead of inventing a new feature direction.

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
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

If more than one applies, use each for its own evidence source and merge the results into one findings spec.

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

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not perform repairs or pretend a live user approved mutation.
## Native Continuation Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before asking any route continuation or permission question, with this route-specific artifact inventory: the findings spec, evidence snippets, P0/P1/P2/P3 findings, healthy checks, skipped checks, open questions, and any machine-readable artifacts when present.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

Question id: `project_audit_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: turn the findings spec into repair planning or issue work.
- Revisit: review findings, gather more evidence, or rerun a narrower audit lane.
- Stop: break the continuation loop.

If the user selects `Yes`, ask:

Question id: `project_audit_progress_route`

Prompt: `Which repair route should start from the findings spec?`

Options:

- `Write Plan`: start `$superpowers-project:write-plan` from the findings spec.
- `Auto Mode`: authorize bounded Auto Mode for the saved findings spec.
- `Create Issues`: start `$superpowers-project:create-issues` only when the findings are issue-ready.

If the user selects `Auto Mode`, ask:

Question id: `project_auto_mode_authorization`

Prompt: `Authorize bounded Auto Mode for this saved audit findings spec?`

Options:

- `Bounded Auto Merge`: create an Auto Mode authorization ledger and continue without more user input through planning, implementation, verification, premerge proof, merge, closeout proof, and live-sync proof when applicable.
- `Manual Planning`: return to `project_audit_progress_route`.

Auto Mode starts only after the findings spec is saved, self-reviewed, and shown through the artifact review gate. `Bounded Auto Merge` is the only valid Auto Mode approval. It must record an Auto Mode authorization ledger before `$superpowers-project:write-plan` starts. The ledger must include:

- `question_id: project_auto_mode_authorization`
- `source: request_user_input`
- `selected_authority: bounded-auto-merge`
- `source_spec: docs/superpowers/specs/<yyyy-mm-dd>-<slug>-audit-findings.md`
- `route_policy.selected_mode: agent-chooses`
- `route_policy.issue_route: direct-inline-resolve-issue`
- `decision_policy.selected_mode: recorded-defaults`
- `decision_policy.stop_outside_policy: true`
- `merge_permission.selected_mode: preauthorized-after-clean-premerge`
- `merge_permission.require_clean_premerge: true`
- `mutation_scope` containing `current-repo` and `development-branch`
- `required_proof` containing `plan-proof-oracle`, `verification-receipts`, `cleanup-hook`, `premerge-proof`, and `closeout-proof`
- `stop_conditions` containing `missing-proof`, `dirty-unsafe-state`, `failed-validation`, and `decision-outside-policy`

Validate the ledger with the plugin-provided Auto Mode validator from the loaded Superpowers Project plugin root:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File <Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>
```

If the ledger passes, continue into `$superpowers-project:write-plan` with the audit findings spec as the source spec. If validation fails or a needed decision falls outside the ledger policy, stop outside policy and return to manual planning instead of inventing approval.

If the user selects `Revisit`, ask:

Question id: `project_audit_revisit_route`

Prompt: `How should I revisit these findings?`

Options:

- `Review First`: show the findings spec and evidence summary, then return to `project_audit_next_step`.
- `Gather More Evidence`: inspect the requested source or load another companion skill, then return to `project_audit_next_step`.
- `Rerun Focused Audit`: rerun the applicable companion skill on a narrower scope, then return to `project_audit_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
