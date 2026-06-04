---
name: audit-project
description: Use when a Superpowers Project repo needs drift audit, migration review, tracker alignment, live sync verification, or repair planning.
---

# Project Doctor

Project Doctor audits Superpowers Project structure and reports drift before any repair. It is report-first: no mutation without user approval.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or `Done`. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` or `Done` option is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only No / Stop / Done can break the loop before that final Done gate. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Scripted Audit Gate

Run `skills/audit-project/scripts/audit-project.ps1` before proposing or applying repairs.

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

Doctor enforces flat canonical roots for the `spec -> plan -> issue` lifecycle:

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

Run `scripts/audit-project.ps1 -RepoRoot . -Mode LocalDocs` for a local-docs audit, or `scripts/audit-project.ps1 -RepoRoot . -Mode GitHubAware` when GitHub or fixture evidence is available. The scripted audit reports stale closed issue mirrors as repairable drift unless the mirror is explicitly marked `**Mirror Retention:** Keep`.

Run `scripts/audit-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` for tracker hygiene. Use `-ApplyTrackerRepairs` only after native approval and include the `repair_receipt` in the handoff or audit report.

## Goal Execution Checks

For active issue work, verify that issue mirrors include source plan linkage, AFK/HITL classification, Goal Command for AFK work, acceptance criteria, proof oracle, and native goal setup expectations consumed by `$project:resolve-issue`.

## Repair Policy

Default mode is audit-only. If repairs are needed, ask the user which repair set to apply with `request_user_input` when callable. A repair plan must list exact files and GitHub objects before any change.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not perform repairs and must not be used to pretend a live user approved mutation.

Allowed repairs after approval are limited to project docs, issue mirrors, labels, milestone metadata, wrappers, and live sync cleanup owned by this plugin. Do not edit product code, implementation tests, runtime config, branches, PRs, merges, issue close state, or native goals from Project Doctor.

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

After the audit report or approved repair proof is ready, summarize the Doctor result in chat before asking the continuation question. The summary must name blocking findings, repairable findings, healthy checks, skipped checks, proposed repair artifacts, and recommended next route. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `No / Stop / Done` for the normal terminal route. Do not show Continue children beside Revisit and No in the same top-level question. Do not show Continue children as peer top-level options. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_doctor_next_step`

Prompt: `How should I continue from this project audit?`

Options:

- Down: `Apply Or Prepare Repair`: apply an exact repair or create repair planning work.
- Left: `Rerun / Review Audit`: rerun the audit, review findings, revise repair direction, or gather evidence.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Apply Or Prepare Repair`, ask:

Question id: `project_doctor_repair_group`

Prompt: `How should this audit turn into repair work?`

Options:

- Down: `Apply Repair`: apply an approved, exact repair plan.
- Left: `Prepare Repair Work`: create a planning or issue route for larger repair work.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Prepare Repair Work`, ask:

Question id: `project_doctor_prepare_route`

Prompt: `Which repair artifact should be prepared?`

Options:

- Down: `Create Planning Spec`: start `$project:brainstorm-spec` for a larger repair design.
- Left: `Plan Or Issue Repair`: choose whether to plan repair work or create an issue.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Plan Or Issue Repair`, ask:

Question id: `project_doctor_plan_issue_route`

Prompt: `Should I plan the repair or create an issue?`

Options:

- Down: `Plan Repair`: start `$project:write-plan` from the audit findings.
- Left: `Create Issue`: start `$project:create-issues` only when the repair is already issue-ready.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Rerun / Review Audit`, ask:

Question id: `project_doctor_reiteration_route`

Prompt: `How should I revisit this audit?`

Options:

- Down: `Run Audit Again`: rerun `$project:audit-project` after changes or new GitHub evidence.
- Left: `Review Or Gather Evidence`: choose whether to review the audit or inspect more evidence.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Review Or Gather Evidence`, ask:

Question id: `project_doctor_review_evidence_route`

Prompt: `Should I review the audit or gather more evidence?`

Options:

- Down: `Review First`: show the audit summary and rendered artifacts for user review, then return to `project_doctor_next_step`.
- Left: `Gather More Evidence`: inspect the requested source, then return to `project_doctor_next_step`.
- Right: `Stop / Done`: break the continuation loop.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.



