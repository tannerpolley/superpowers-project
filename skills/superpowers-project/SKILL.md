---
name: superpowers-project
description: Route Superpowers Project extension requests to project context, brainstorming, planning, issue creation, issue triage, doctor, or goal-backed resolution workflows.
---

# Superpowers Project

This skill is the router for the Superpowers Project extension. It does not replace Superpowers. It routes project-backed work to extension skills and routes method work to Superpowers skills.

## Routing

- Project setup, roadmap context, or large-scope project map: `$project-context`
- Brainstorming, specs, PRDs, broad product design, architecture design, or any unresolved early project decision: `$project-brainstorm`
- Implementation planning from a spec, issue mirror, or approved direct request: `$project-plan`
- Quick Apply small-work escape hatch after an approved `$project-plan`: local-main execution on clean synced `main` only after `project_quick_apply_approval` and `validate-quick-apply.ps1`.
- Issue decomposition, GitHub issue creation, issue mirror creation, or milestone assignment: `$project-issue`
- One ready issue execution with native `/goal` proof: `$project-resolve`
- PR URL, worker handoff, merge approval, issue close verification, branch/worktree cleanup, or clean repo proof: `$project-merge`
- Drift audit, migration, label review, milestone review, or live sync review: `$project-doctor`

The issue-backed `$project-issue` plus `$project-resolve` execution path remains the default for non-trivial work, risky changes, multi-issue scope, branch-backed implementation, and anything expected to end in a PR.

## Artifact Root

Canonical project artifacts live under `docs/superpowers`.

- Project context: `docs/superpowers/PROJECT_CONTEXT.md`
- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

## Method Routing

Use Superpowers skills for method: `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:subagent-driven-development`, and `superpowers:verification-before-completion`.

## Continuation Routing

At major handoffs, use native continuation questions and treat the selected answer as executable routing. The agent should start the selected next skill in the same turn when possible instead of ending with a prompt suggestion.

## Native Continuation Gate

Every Superpowers Project skill must summarize its artifact or result in chat before a closeout continuation question. The summary should name created or changed artifacts, validation or proof status, unresolved decisions, and the recommended next route.

When `request_user_input` is callable, ask the skill-specific native continuation question and include `Review First` or another review route plus a `Stop` option. Treat selected native answers as executable routing: start the selected next skill in the same turn when tools and state allow it.

If routing cannot continue because tools, permissions, GitHub state, or user approval are missing, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests and never counts as live approval.

## Native User Input

When the task needs user choices and the `request_user_input` tool is callable, use it from Default mode for one to three short, decision-oriented questions. Batch independent questions together. Ask dependent questions one step at a time after the prior answer changes the branch.

For `$project-brainstorm`, use native UI more aggressively: if there is any unresolved idea, naming, scope, tradeoff, route, or assumption decision, inspect project context and relevant code first, then ask through `request_user_input` instead of resolving the decision in prose.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only when the user explicitly asks for non-interactive smoke testing, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer that modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Instead, record a Native Question Debug Ledger in the active smoke issue mirror or final smoke report. Each ledger entry must include the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults. Debug mode must not be used as a substitute for native UI in normal work; it is test-only evidence and never counts as a live user decision.

## Goal Routing

Issue implementation must use `$project-resolve` and native `/goal` activation or goal-tool proof before implementation begins. Goal success criteria come from the issue mirror acceptance checklist and the linked source plan. After `$project-resolve` creates PR-ready evidence, final integration must route to `$project-merge`.
