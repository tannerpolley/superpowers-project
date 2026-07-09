---
name: audit-project
description: Use when code, workflows, tests, skills, or repo behavior need evidence-backed review findings before repair planning.
---

# Project Audit

Produce evidence-backed findings before repair planning. This route diagnoses and specifies; it does not implement findings.

## Capability Preflight

Require `filesystem.read` and `shell` from `docs/superpowers/capabilities.yml`. Require `native.user-input` for material scope and closeout choices. Stop before inspection when a required capability is absent.

## Shared Policy

Follow `skills/advanced-user-input/SKILL.md` for global native continuation and artifact review. This skill retains route-specific findings, artifacts, validators, and routing only. Read question ownership from `docs/superpowers/workflow-contract.yml`; Auto authorization is owned by `initiate-workflow`.

## Audit Method

1. Establish the project goal and observable behavior from repository evidence.
2. Select the matching specialist: `diagnose` for failures, `thermo-nuclear-code-quality-review` for maintainability, `improve-codebase-architecture` for domain boundaries, or `react-doctor` for React.
3. Reproduce claims with the narrowest useful command. Do not infer defects from prose alone.
4. Record P0 through P3 findings with location, evidence, impact, recommended correction, and verification oracle.
5. Also record healthy checks, skipped checks, open questions, and false-positive risks.
6. Save repair-ready findings under `docs/superpowers/specs/` with an Outcome Proof and Decision Ledger.

## Stop Conditions

Stop when the audit scope is materially ambiguous, evidence is unavailable, a command would mutate state, or findings cannot distinguish observed behavior from preference.

## Route Closeout

Show the findings spec and evidence inventory, then use `project_audit_next_step`. Yes routes through the graph-owned progress choices; Revisit gathers or reviews evidence; `Stop` is the intermediate terminal choice. A `Done` claim is valid only for a verified final audit with no remaining repair route and a clean worktree.
