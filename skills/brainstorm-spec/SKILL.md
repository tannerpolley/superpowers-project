---
name: brainstorm-spec
description: Use when repo-backed ideas, specs, PRDs, architecture concepts, or broad feature requests need design decisions.
---

# Project Brainstorm

Pair `$superpowers-project:brainstorm-spec` with `superpowers:brainstorming`. This route produces an approved design before planning or implementation.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, and `native.user-input` from `docs/superpowers/capabilities.yml`. The paired skill owns browser transport. Stop with the missing capability.

Follow `skills/advanced-user-input/SKILL.md` for shared question geometry and `docs/superpowers/workflow-contract.yml` for labels.

## Method

Inspect knowable context, ask one unresolved decision at a time, compare two or three viable approaches, recommend one, and present design sections for approval. Use the upstream visual companion only when comparison benefits from visuals; native input remains authoritative. Treat `.superpowers/brainstorm/` as ignored generated state and stop its server after use. This project gate replaces the upstream commit and direct planning handoff.

Write `docs/superpowers/specs/YYYY-MM-DD-<slug>-design.md` with context, goals, non-goals, alternatives, selected design, interfaces, data flow, errors, testing, risks, unresolved decisions, and Decision Ledger. Run `./scripts/validate-decision-ledger.sh -Path <saved-spec-path> -Kind spec`.

Do not implement, branch, create issues, or write a plan in this route.

## Closeout

Stop on unresolved material design, rejected approaches, or claims unsupported by repository evidence. Show the spec and decisions through `project_brainstorm_next_step`; Yes plans, Revisit revises or reviews, and `Stop` exits. In Auto, an approved spec continues to planning in the same run. This route has no verified final `Done`.
