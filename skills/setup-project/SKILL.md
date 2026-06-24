---
name: setup-project
description: Create or maintain the Superpowers Project setup, milestone map, GitHub tracker configuration, GitHub Project board configuration, and roadmap artifacts under docs/superpowers.
---

# Setup Project

Use this skill when a repo needs the Superpowers Project setup layer: durable intent, roadmap framing, milestone pages, tracker rules, approved GitHub Project board configuration, and the shared map that makes Superpowers specs, plans, and issues add up to a coherent project.

## Purpose

Project setup gives agents the bigger picture before they brainstorm, plan, split issues, or execute work. It should explain why the project exists, what milestones mean, how GitHub is linked, which optional board surfaces exist, and which artifacts are canonical.

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
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

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not pretend a live user approved roadmap, milestone, GitHub, board creation, setup mutation, or `/goal` execution decisions.
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

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` before asking this route's native continuation or permission question. Route-specific artifact inventory must include changed or verified setup docs, tracker config evidence, board evidence, roadmap or tracker decisions, and any machine-readable artifacts when present. Add the helper-required findings summary with route-specific status for the changed or verified artifacts, unresolved roadmap or tracker decisions, GitHub Project board status when relevant.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

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
