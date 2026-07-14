---
name: write-plan
description: Use when an approved spec or issue mirror needs a detailed implementation plan before code changes.
---

# Project Plan

Pair with `superpowers:writing-plans` and produce a project plan. Do not edit implementation code.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before planning when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates.

Follow the repository verification policy selected by its applicable `AGENTS.md`. Use `superpowers:test-driven-development` only when that policy selects TDD. Use `superpowers:systematic-debugging` for bugs, regressions, CI, or performance, and `superpowers:verification-before-completion` for implementation completion.

## Plan Contract

Write `docs/superpowers/plans/YYYY-MM-DD-<slug>-plan.md` linked to its approved source. Include Goal, Architecture, Tech Stack, Global Constraints, Source Evidence, Test Complete and Metrics, Outcome Proof, Implementation Boundaries, Decision Ledger, and numbered Tasks.

Outcome Proof names Intent, Current Behavior, Expected Outcome, Target Output, Owner, Interface, Cutover, Replaced Path, Evidence, Acceptance Proof, Stop Criteria, Avoid, and Risk. Boundaries name files to create, modify, and avoid; sources of truth; read/write paths; integrations; migration; replaced paths; and acceptance gate.

Each task contains non-empty Use Cases, exact Files and Interfaces, the selected Verification Method, Acceptance Evidence, commands with expected results, and a checkpoint commit. Prefer vertical tasks.

Run:

- `./scripts/validate-plan-outcome-proof.sh -PlanPath <plan>`
- `./scripts/validate-plan-task-use-cases.sh -PlanPath <plan>`
- `./scripts/validate-decision-ledger.sh -Path <plan> -Kind plan`

## Closeout

Stop on unapproved scope, unresolved architecture, unmeasurable completion, missing oracle, or failed validation. Show the plan and receipts through `project_plan_next_step`; resolve its work route from the workflow contract instead of the upstream direct handoff. In Auto, a safe forward route continues in the same run without user input; a finished plan never completes the outcome. Revisit revises or reviews, `Stop` remains intermediate, and planning never claims verified final `Done`.
