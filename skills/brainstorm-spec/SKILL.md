---
name: brainstorm-spec
description: Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need Superpowers brainstorming plus project context and native user-input grilling.
---

# Project Brainstorm

Use this design-only adapter before planning or implementation. Announce that `$superpowers-project:brainstorm-spec` is paired with `superpowers:brainstorming`.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, and `native.user-input` from `docs/superpowers/capabilities.yml`. The paired upstream skill owns any browser transport. Stop with an exact missing-capability finding.

## Required Method

Run `superpowers:brainstorming` without weakening its checklist: inspect knowable context, ask one unresolved decision at a time, compare two or three viable approaches, recommend one, present architecture/components/data flow/error handling/testing in reviewable sections, obtain approval, write the spec, and invite review. Honor its just-in-time visual companion when a question genuinely benefits from visual comparison; browser events are advisory and native Codex input remains authoritative. Treat `.superpowers/brainstorm/` as generated ignored state, stop its server after use, and do not invent a second companion route. Do not implement, branch, create issues, or write an implementation plan here.

## Shared Policy

Use `skills/advanced-user-input/SKILL.md` for global question geometry and artifact review. Keep route-specific spec decisions and gates local. Canonical labels and ownership live in `docs/superpowers/workflow-contract.yml`.

## Spec Contract

Write `docs/superpowers/specs/YYYY-MM-DD-<slug>-design.md` with context, goals, non-goals, alternatives, selected design, interfaces, data flow, errors, testing, risks, unresolved decisions, and a Decision Ledger. Validate with `./scripts/validate-decision-ledger.sh -Path <saved-spec-path> -Kind spec`.

## Stop Conditions And Closeout

Stop when a material design decision remains unresolved, the user rejects all viable approaches, or the artifact cannot be grounded in repository evidence. Show the saved spec and decision summary, then use `project_brainstorm_next_step`. Yes routes to planning, Revisit revises/reviews/restarts, and `Stop` is the intermediate terminal choice. This route never claims verified final `Done`.
