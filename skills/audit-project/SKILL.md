---
name: audit-project
description: Use when code, workflows, tests, skills, or repository behavior need evidence-backed findings before repair planning.
---

# Project Audit

Diagnose and specify findings without implementing them.

## Capability Preflight

Require `filesystem.read` and `shell` from `docs/superpowers/capabilities.yml`; add `native.user-input` for material scope or closeout choices. Stop before inspection when a capability is missing.

Follow `skills/advanced-user-input/SKILL.md` for shared gates; `initiate-workflow` owns Auto authorization.

## Method

1. Derive the goal and observable behavior from repository evidence.
2. Use `diagnose` for failures, `thermo-nuclear-code-quality-review` for maintainability, `improve-codebase-architecture` for boundaries, or `react-doctor` for React.
3. Reproduce behavioral claims with the narrowest useful command; label prose-only findings as contract or maintainability findings and separate defects from preference.
4. Record P0-P3 findings with location, evidence, impact, correction, and verification oracle. Include healthy checks, skipped checks, questions, and false-positive risks.
5. Save repair-ready findings with Outcome Proof and Decision Ledger under `docs/superpowers/specs/`.

## Closeout

Stop on ambiguous scope, missing evidence, required mutation, or preference-only conclusions. Show the findings spec and evidence through `project_audit_next_step`. This route has no final `Done`; use Yes, Revisit, or `Stop` through the shared policy.
