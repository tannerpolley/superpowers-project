---
name: setup-project
description: Create or maintain the Superpowers Project setup, milestone map, GitHub tracker configuration, GitHub Project board configuration, and roadmap artifacts under docs/superpowers.
---

# Setup Project

Use this skill when a repo needs the Superpowers Project setup layer: durable intent, roadmap framing, milestone pages, tracker rules, approved GitHub Project board configuration, and the shared map that makes Superpowers specs, plans, and issues add up to a coherent project.

## Purpose

Project setup gives agents the bigger picture before they brainstorm, plan, split issues, or execute work. It should explain why the project exists, what milestones mean, how GitHub is linked, which optional board surfaces exist, and which artifacts are canonical.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` option or verified final `Done` gate is terminal. Revisit is non-terminal. Yes must start the selected progress route or ask its blocking child question; the only Yes terminal exception is an explicit final Healthy -> Done gate. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can break an intermediate loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

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

Use `request_user_input` when callable in Default mode for decisions that affect roadmap shape, milestone boundaries, GitHub policy, or `/goal` issue execution criteria. Ask concise mutually exclusive choices when the UI supports it, and use more than three peer options or independent questions when that is the clearest honest menu. If a choice depends on the answer to an earlier question, ask it after that answer.

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

When a repo is GitHub-linked, `$superpowers-project:setup-project` can create or verify a GitHub Project board after native approval.

Board setup is optional project-management evidence. GitHub Projects must not become canonical storage for specs, plans, issue mirrors, or milestone pages. The canonical artifacts remain under `docs/superpowers`.

Before creating or mutating a board, summarize the proposed board title, repository, milestone/status fields, issue-linking scope, and dry-run evidence, then ask native question `project_setup_board_approval` with `Create Board`, `Verify Only`, and `Stop` options. Do not call `gh project` mutation commands unless the selected action is `create`.

Use `scripts/prepare-github-project-board.ps1 -Mode Plan` before native approval. After native approval selects `Create Board`, use `-Mode Create` with structured `NativeApprovalJson`; the script creates or reuses the board, ensures required fields, links approved issue URLs, and records board configuration in `docs/agents/project-roadmap.json`. Use `-Mode ValidateConfig` for existing-board evidence. When useful for humans, mirror the board summary in `docs/agents/project-roadmap.md`.

For repositories that support native GitHub issue types, setup must inspect `repository.issueTypes` through GraphQL and use `UpdateIssueInput.issueTypeId` when assigning the local issue mirror's `Issue Type` to a GitHub issue. Keep compatibility labels such as `type:task`, `type:bug`, and `type:feature`. If GraphQL reports no enabled native issue types, say so explicitly and continue with label-only behavior. Do not conclude native issue types are unavailable merely because high-level `gh issue create` or `gh issue edit` lacks a `--type` flag.

## Validation

Before reporting setup or repair complete, verify:

- `docs/superpowers/PROJECT_CONTEXT.md` exists and names the artifact model.
- `docs/superpowers/milestones` exists and contains a README or milestone pages.
- GitHub tracker config names the repository when issue mirrors or milestones are used.
- `/goal` execution criteria are present for issue work that can be assigned to an agent.
- Superpowers Project skill names are listed where agents will discover them, including `$superpowers-project:setup-project`.

## Native Continuation Gate

After creating, auditing, or repairing project setup, complete the artifact review gate before asking the continuation question. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show every produced or materially changed setup artifact, including changed or verified setup docs, tracker config evidence, board evidence, roadmap or tracker decisions, and any machine-readable artifacts when present. Show exact artifact paths and links, render created or revised Markdown artifacts in chat when reasonably sized, and summarize machine-readable artifacts with exact path plus key fields. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative excerpt, and why the full render is omitted. After artifacts are shown, add a separate findings summary that names the changed or verified artifacts, unresolved roadmap or tracker decisions, GitHub Project board status when relevant, what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and the recommended next route.

Ask native continuation questions with `request_user_input` when callable. These questions are executable routing, not advisory text. The top-level closeout question must be asked as `Continue?`. The top-level closeout question must use exactly three trajectory options: `Yes` for progress, `Revisit` for the standard go-back route, and `Stop` for the normal terminal route. Do not show Continue children beside Revisit and Stop in the same top-level question. Do not show Continue children as peer top-level options. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question. If Yes has multiple next skills, ask a nested Yes route question after the user selects Yes. If Revisit has multiple reiteration paths, ask a nested review route question after the user selects Revisit. Nested Yes-route menus must not include terminal options; they include only real forward routes. Nested Revisit-route menus must not include terminal options; they include only real review, revise, repair, rerun, recover, or evidence-gathering routes. Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires. Recommend Yes when at least one safe forward route exists. Recommend Revisit when review, repair, or missing evidence is the next safe action. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Use `advanced-user-input` sequential branching when a branch answer changes the follow-up questions. Custom Other never terminates a workflow directly. If it appears to ask for Stop or Done, ask a fresh confirmation question instead of terminating from Other; otherwise turn it into the next best follow-up question or baseline route tree and keep the workflow running. Do not infer terminal intent from a custom answer. Review First is not a terminal answer; show evidence or rendered artifacts, ask follow-up questions, and return to the originating continuation gate.

Question id: `project_setup_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: choose the next project workflow.
- Revisit: revisit setup, review output, or audit drift.
- Stop: break the continuation loop.

If the user selects `Continue Project Work`, ask:

Question id: `project_setup_work_route`

Prompt: `Which project workflow should start from setup?`

Options:

- `Brainstorm New Spec`: start `$superpowers-project:brainstorm-spec` for a spec, PRD, architecture idea, or product direction.
- `Write Plan`: start `$superpowers-project:write-plan` from an approved spec or issue mirror.
- `Create Issues`: start `$superpowers-project:create-issues` for vertical slices and GitHub issue mirrors.

If the user selects `Revise / Review Setup`, ask:

Question id: `project_setup_reiteration_group`

Prompt: `How should I revisit this setup work?`

Options:

- `Review / Revise Setup`: choose a local review or revision route.
- `Run Align`: start `$superpowers-project:align-project` for drift alignment or repair planning.

If the user selects `Review / Revise Setup`, ask:

Question id: `project_setup_reiteration_route`

Prompt: `Should I review or revise setup?`

Options:

- `Review Setup`: show the setup summary and rendered artifacts for user review, then return to `project_setup_next_step`.
- `Revise Setup`: update setup artifacts from follow-up answers, then return to `project_setup_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
