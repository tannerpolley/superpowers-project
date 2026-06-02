---
name: superpowers-project
description: Route Superpowers Project extension requests to project context, brainstorming, planning, issue creation, issue triage, doctor, or goal-backed resolution workflows.
---

# Superpowers Project

This skill is the router for the Superpowers Project extension. It does not replace Superpowers. It routes project-backed work to extension skills and routes method work to Superpowers skills.

## Routing

- Project setup, roadmap context, or large-scope project map: `$project-context`
- Brainstorming, specs, PRDs, broad product design, or architecture design: `$project-brainstorm`
- Implementation planning from a spec, issue mirror, or approved direct request: `$project-plan`
- Issue decomposition, GitHub issue creation, issue mirror creation, or milestone assignment: `$project-issue`
- One ready issue execution with native `/goal` proof: `$project-resolve`
- Drift audit, migration, label review, milestone review, or live sync review: `$project-doctor`

## Artifact Root

Canonical project artifacts live under `docs/superpowers`.

- Project context: `docs/superpowers/PROJECT_CONTEXT.md`
- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

## Method Routing

Use Superpowers skills for method: `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:subagent-driven-development`, and `superpowers:verification-before-completion`.

## Native User Input

When the task needs user choices and the `request_user_input` tool is callable, use it from Default mode for one to three short, decision-oriented questions. Batch independent questions together. Ask dependent questions one step at a time after the prior answer changes the branch.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger in the active smoke issue mirror or final smoke report. Each ledger entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults. Debug mode must not be used as a substitute for native UI in normal work; it is test-only evidence and never counts as a live user decision.

## Goal Routing

Issue execution must use `$project-resolve` and native `/goal` activation or goal-tool proof before implementation begins. Goal success criteria come from the issue mirror acceptance checklist and the linked source plan.
