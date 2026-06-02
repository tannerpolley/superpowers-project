---
name: using-milestones
description: Routes Milestones workflow requests to the right setup, audit, exploration, issue planning, execution-planning, or execution skill. Use when a user mentions milestone workflows, docs/milestones, milestone-backed ideas/issues, GitHub milestones, or asks which Milestones skill to use.
---

# Using Milestones

This is a meta-router only. It chooses the owning skill for the user's current Milestones workflow phase, then stops and follows that routed skill exactly. Do not duplicate setup, audit, issue creation, implementation planning, or execution behavior here.

## Route First

- First-time setup for a GitHub-backed repo: use `$setup-project-milestones`.
- Existing workflow audit, cleanup, migration, drift repair, or verification: use `$milestones-doctor`.
- Broad repo idea exploration, scope discovery, roadmap-area questions, or fuzzy feature/design intent: use `$explore-ideas` and apply `superpowers:brainstorming` patterns.
- GitHub issue creation from an idea brief or broad intent: use `$convert-idea-to-issue`.
- Issue-file implementation planning for an already selected local issue file: use `$milestone-writing-issue-plan`.
- Execution of one ready or externally sourced GitHub issue: use `$resolve-issue-with-goal`.

When a request mixes phases, route to the earliest unfinished phase. For example, do not execute work that has not yet been converted into a scoped issue, and do not run setup when the user is asking to repair an existing setup.

## Superpowers Routes

- `superpowers:using-superpowers`: use at conversation start or whenever skill routing is uncertain.
- `superpowers:brainstorming`: use for vague feature, behavior, design, or product questions before planning or implementation.
- `superpowers:writing-plans`: use when a settled scope needs a written multi-step implementation plan.
- `superpowers:test-driven-development`: use before implementation of a feature or bugfix when tests can drive the change.
- `superpowers:systematic-debugging`: use for bugs, regressions, failing tests, CI failures, or unclear failure modes.
- `superpowers:subagent-driven-development`: use when an implementation plan has independent tasks that can be delegated safely.
- `superpowers:requesting-code-review`: use after substantial implementation before merge or closeout.
- `superpowers:receiving-code-review`: use when addressing review feedback.
- `superpowers:verification-before-completion`: use before claiming any work is complete, fixed, passing, merged, or cleaned up.

## Milestone Path Contract

For milestone-backed repos, enforce these durable locations:

- Idea briefs belong under `docs/milestones/<milestone-folder>/ideas`.
- Local issue files belong under `docs/milestones/<milestone-folder>/issues`.
- `docs/ideas` is legacy only for pre-migration idea briefs. New cross-cutting ideas require an owning milestone or an approved cross-cutting milestone folder such as `docs/milestones/cross-cutting/ideas`.
- Do not create or route new milestone issue plans to `docs/plans`, `docs/issues`, `docs/milestones/<milestone-folder>/plans`, or issue-level files under `docs/roadmaps`.

If an upstream skill allows a non-milestone fallback, use it only when the repo is explicitly not milestone-backed or not yet migrated. For strict Milestones work, milestone-local `ideas` and `issues` folders win.

## Routing Checks

Before invoking the routed skill, identify:

1. The explicit `target_repo` and `target_repo_root` when repo or GitHub work is involved.
2. Whether the repo is first-time setup, existing setup audit/repair, broad exploration, issue creation, issue-file implementation planning, or execution.
3. Whether a milestone folder is already selected. If not, let the routed skill ask the required `request_user_input` question.
4. Whether the user is asking for mutation. Meta-routing itself must not edit repo product code, create branches, open PRs, merge, or run GoalBuddy.

## Blocked Response

If the correct downstream skill cannot be loaded or the request cannot be routed without a material decision, respond with:

```text
Blocked by using-milestones contract: <reason>
```

## Validation

Before reporting this skill package complete after edits:

- run `scripts\test-scenarios.ps1`;
- validate the canonical `SKILL.md`, `agents\openai.yaml`, and plugin wrapper mention all required route names and milestone path contracts;
- run the repo-scoped cleanup hook from the active repo root.
