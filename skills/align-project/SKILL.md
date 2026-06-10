---
name: align-project
description: Use when a Superpowers Project repo needs structure alignment, migration review, tracker alignment, live sync verification, or repair planning.
---

# Project Align

Project Align audits Superpowers Project structure and reports drift before any repair. It is report-first: no mutation without user approval.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question. Final completion must use an explicit final health gate with `Done`, not a `Yes` option. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Scripted Audit Gate

Run `skills/align-project/scripts/align-project.ps1` before proposing or applying repairs.

Supported modes:

- `-Mode LocalDocs`: inspect local project docs, issue mirrors, native UI contracts, ignored-path traps, closed mirror lifecycle policy, and live sync surfaces without network.
- `-Mode GitHubAware`: include GitHub tracker comparisons for milestone membership drift, mirror versus GitHub issue body/state/labels/milestone drift, label drift, and closed mirror lifecycle drift. Use `-IssueFixturePath`, `-MilestoneFixturePath`, `-LabelFixturePath`, and `-ProjectFixturePath` for deterministic smoke tests.
- `-TrackerHygiene`: inspect GitHub issue routing-label drift and canonical Project V2 state drift. Reports closed/open status mismatches, missing `status:*` routing labels on open issues, missing Project items, mirror-to-Project field drift, and remaining Project V2 draft items.
- `-ApplyTrackerRepairs`: after native approval, emit a repair receipt for conservative tracker repairs: remove `status:*` labels from closed issues, mark closed Project items `Done`, add mirrored open issues back to the canonical Project, and sync valid Project fields from mirror metadata.

The script reports JSON findings grouped as `blocking`, `repairable`, `informational`, and `healthy`. It is audit-only: repairs require native repair approval through `request_user_input` before mutation.

Tracker hygiene policy is intentionally narrow. Open issues carry `status:*` routing labels. Closed issues use GitHub closed state plus Project `Done`; closed issues should not keep `status:*` routing labels. Project V2 draft items are reported separately and are not published, converted, or deleted automatically.

## Audit Scope

Inspect and report on:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones`
- `docs/superpowers/specs`
- `docs/superpowers/plans`
- `docs/superpowers/issues`
- GitHub issue mirror fields
- GitHub milestone linkage
- label vocabulary
- retired docs/milestones canonical usage
- live plugin sync drift
- active issue goal execution checks

## Flat Artifact Root Audit

Project Align enforces flat canonical roots for the `spec -> plan -> issue` lifecycle:

- loose specs belong in `docs/superpowers/specs`
- implementation plans belong in `docs/superpowers/plans`
- GitHub issue mirrors belong in `docs/superpowers/issues`

Milestone pages are index views. They should link to flat canonical artifacts and may group by milestone, package, or category through frontmatter plus milestone indexes. They must not own canonical nested copies. Report nested canonical milestone artifact folders are drift when `docs/superpowers/milestones/<milestone>/specs`, `docs/superpowers/milestones/<milestone>/plans`, or `docs/superpowers/milestones/<milestone>/issues` exists, unless the folder is explicitly marked as generated index/view output.

Migration guidance: move canonical files back to the flat roots, preserve milestone identity in frontmatter and filenames where applicable, then regenerate milestone README/dashboard views as links. Specs stay loose; move implementation-only metadata into the matching plan or issue mirror.

GitHub checks should compare issue URLs, issue states, milestone titles, labels, and issue mirror bodies when credentials and target repo context allow it. Local-docs-only audits may skip GitHub calls but must say which GitHub checks were skipped.

## Report Categories

Group findings as:

- blocking: breaks execution, publication, validation, or source-of-truth safety
- repairable: can be fixed with an approved docs or tracker repair
- informational: worth knowing but does not block the current workflow
- healthy: explicitly verified as aligned

## Migration Report

When old Milestones artifacts are present, produce a migration report from retired docs/milestones canonical usage to the new Superpowers Project model. Do not move, delete, rewrite, or publish those files until the user approves an exact repair plan.

## Drift Checks

Check for drift across:

- project context intent vs milestone pages
- milestone pages vs GitHub milestones
- specs vs plans
- plans vs issue mirrors
- issue mirrors vs GitHub issues
- closed mirror lifecycle drift
- issue labels vs label vocabulary
- issue execution fields vs native `/goal` requirements
- live plugin install vs source repo, including retired skill directories and active wrappers

Run `skills/align-project/scripts/align-project.ps1 -RepoRoot . -Mode LocalDocs` for a local-docs audit, or `skills/align-project/scripts/align-project.ps1 -RepoRoot . -Mode GitHubAware` when GitHub or fixture evidence is available. The scripted audit reports stale closed issue mirrors as repairable drift unless the mirror is explicitly marked `**Mirror Retention:** Keep`.

Run `skills/align-project/scripts/align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` for tracker hygiene. Use `-ApplyTrackerRepairs` only after native approval and include the `repair_receipt` in the handoff or audit report.

For repositories that support native GitHub issue types, GitHub-aware audits must inspect issue type state through GraphQL issue evidence in addition to compatibility labels such as `type:task`, `type:bug`, and `type:feature`. If GraphQL reports no native issue type on an issue or no enabled repository issue types, report explicit label-only behavior rather than treating missing high-level `gh issue --type` flags as proof that native issue types are unavailable.

## Goal Execution Checks

For active issue work, verify that issue mirrors include source plan linkage, AFK/HITL classification, Goal Command for AFK work, acceptance criteria, proof oracle, and native goal setup expectations consumed by `$superpowers-project:resolve-issue`.

## Repair Policy

Default mode is audit-only. If repairs are needed, ask the user which repair set to apply with `request_user_input` when callable. A repair plan must list exact files and GitHub objects before any change.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not perform repairs and must not be used to pretend a live user approved mutation.

Allowed repairs after approval are limited to project docs, issue mirrors, labels, milestone metadata, wrappers, and live sync cleanup owned by this plugin. Do not edit product code, implementation tests, runtime config, branches, PRs, merges, issue close state, or native goals from Project Align.

## Report Shape

A useful report includes:

- target repo and repo root
- audit mode: local-docs-only or GitHub-aware
- checked artifacts
- findings grouped as blocking, repairable, informational, and healthy
- migration report
- proposed repairs, if any
- validation commands to run after approved repairs

## Native Continuation Gate

After the audit report or approved repair proof is ready, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed alignment artifact, including audit output, blocking findings, repairable findings, healthy checks, skipped checks, proposed repair artifacts, repair receipts, and any machine-readable artifacts when present. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names blocking findings, repairable findings, healthy checks, skipped checks, proposed repair artifacts, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

Done is valid only at `project_align_final_health_gate`. For `align-project`, that means a healthy audit result with no blocking or repairable findings, no remaining repair route, and a clean git worktree. If `git status --short` is non-empty, `Done` is invalid and the workflow must continue through commit, push, repair, or hold routing instead. Stop remains the terminal option when findings remain.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_align_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: apply an exact repair or create repair planning work.
- Revisit: rerun the audit, review findings, revise repair direction, or gather evidence.
- Stop: break the continuation loop.

If the audit is healthy with no blocking or repairable findings, no remaining repair route, and clean `git status --short`, ask:

Question id: `project_align_final_health_gate`

Prompt: `Alignment is healthy. Should I close this workflow as done?`

Options:

- Done: close only when the audit has no blocking or repairable findings, no remaining repair route, cleanup passed, and `git status --short` is clean.
- Revisit: review findings, rerun Align, or gather more evidence before deciding.
- Stop: pause without claiming final completion.

If the user selects `Apply Or Prepare Repair`, ask:

Question id: `project_align_repair_group`

Prompt: `How should this audit turn into repair work?`

Options:

- `Apply Repair`: apply an approved, exact repair plan.
- `Prepare Repair Work`: create a planning or issue route for larger repair work.

If the user selects `Prepare Repair Work`, ask:

Question id: `project_align_prepare_route`

Prompt: `Which repair artifact should be prepared?`

Options:

- `Create Planning Spec`: start `$superpowers-project:brainstorm-spec` for a larger repair design.
- `Plan Or Issue Repair`: choose whether to plan repair work or create an issue.

If the user selects `Plan Or Issue Repair`, ask:

Question id: `project_align_plan_issue_route`

Prompt: `Should I plan the repair or create an issue?`

Options:

- `Plan Repair`: start `$superpowers-project:write-plan` from the audit findings.
- `Create Issue`: start `$superpowers-project:create-issues` only when the repair is already issue-ready.

If the user selects `Rerun / Review Alignment`, ask:

Question id: `project_align_reiteration_route`

Prompt: `How should I revisit this audit?`

Options:

- `Run Align Again`: rerun `$superpowers-project:align-project` after changes or new GitHub evidence.
- `Review Or Gather Evidence`: choose whether to review the audit or inspect more evidence.

If the user selects `Review Or Gather Evidence`, ask:

Question id: `project_align_review_evidence_route`

Prompt: `Should I review the audit or gather more evidence?`

Options:

- `Review First`: show the audit summary and rendered artifacts for user review, then return to `project_align_next_step`.
- `Gather More Evidence`: inspect the requested source, then return to `project_align_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
