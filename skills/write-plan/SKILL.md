---
name: write-plan
description: Use when an approved Superpowers Project spec or issue mirror needs a detailed implementation plan before code changes.
---

# Project Plan

Turn approved design or issue scope into a durable implementation plan. Announce the pairing with `superpowers:writing-plans`. Do not edit implementation code in this route.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. `browser` is optional for requested visual review. Stop before planning when a required capability is absent.

## Required Superpowers Pairings

Use `superpowers:writing-plans` as the base. Plans for features/bugs require `superpowers:test-driven-development` unless the user records an explicit opt-out. Bug/regression/CI/performance plans require `superpowers:systematic-debugging`. Every plan requires `superpowers:verification-before-completion` before implementation completion.

## Shared Policy

Read `skills/advanced-user-input/SKILL.md` for global continuation and artifact review. This route keeps route-specific planning grill, artifact, review, and execution-route decisions local. Use `docs/superpowers/workflow-contract.yml` for labels.

## Plan Contract

Write `docs/superpowers/plans/YYYY-MM-DD-<slug>-plan.md` linked to its approved source. Include Goal, Architecture, Tech Stack, Global Constraints, Source Evidence, Test Complete and Metrics, Outcome Proof, Implementation Boundaries, Decision Ledger, and numbered Tasks.

Outcome Proof must specify Intent, Current Behavior, Expected Outcome, Target Output, Owner, Interface, Cutover, Replaced Path, Evidence, Acceptance Proof, Stop Criteria, Avoid, and Risk. Boundaries identify files to create/modify/avoid, source of truth, read/write paths, integrations, migration, replaced-path handling, and acceptance gate.

Every Task includes non-empty `**Use Cases:**`, exact Files and Interfaces, RED/GREEN/refactor steps, commands with expected results, and a checkpoint commit. Prefer vertical end-to-end tasks.

Validate before readiness:

- `./scripts/validate-plan-outcome-proof.sh -PlanPath <plan>`
- `./scripts/validate-plan-task-use-cases.sh -PlanPath <plan>`
- `./scripts/validate-decision-ledger.sh -Path <plan> -Kind plan`

## Stop Conditions And Closeout

Stop on unapproved source scope, unresolved architecture, unmeasurable completion, missing proof oracle, or failed validators. Show the full plan and validator receipts, then use `project_plan_next_step`. Yes routes to create-issues or implement-plan; Revisit reviews/revises; `Stop` is intermediate. Planning never claims verified final `Done`.
