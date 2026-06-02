---
name: superpowers-project
description: Route Superpowers Project extension requests to project context, brainstorming, planning, issue creation, issue triage, doctor, or goal-backed resolution workflows.
---

# Superpowers Project

This skill is the router for the Superpowers Project extension. It does not replace Superpowers. It routes project-backed work to extension skills and routes method work to Superpowers skills.

## Routing

- Project setup, roadmap context, or large-scope project map: `$project-context`
- Brainstorming, specs, PRDs, broad product design, or architecture design: `$project-brainstorm`
- Implementation planning from a spec, issue mirror, or approved direct request: `$project-writing-plan`
- Issue decomposition, GitHub issue creation, issue mirror creation, or milestone assignment: `$plan-to-issue`
- One ready issue execution with native `/goal` proof: `$resolve-issue-with-goal`
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

## Goal Routing

Issue execution must use `$resolve-issue-with-goal` and native `/goal` activation or goal-tool proof before implementation begins. Goal success criteria come from the issue mirror acceptance checklist and the linked source plan.
