---
name: setup-project
description: Create or maintain the Superpowers Project setup, milestone map, GitHub tracker configuration, GitHub Project board configuration, and roadmap artifacts under docs/superpowers.
---

# Setup Project

Create or repair the minimal project context, roadmap, tracker, and optional GitHub Project evidence used by downstream routes.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Require `github` only for live tracker or board work. Stop before setup when a required capability is absent.

## Shared Policy

Use `skills/advanced-user-input/SKILL.md` for global native questions and artifact review. This route keeps route-specific setup scope, board approval, and tracker decisions local. Read labels and ownership from `docs/superpowers/workflow-contract.yml`.

## Required Artifacts

Maintain `docs/superpowers/PROJECT_CONTEXT.md`, milestone index pages under `docs/superpowers/milestones/`, and `docs/agents/project-roadmap.json`. Specs, plans, and issues stay in their flat `docs/superpowers/` roots. Milestone pages are dashboards, not replacements for GitHub milestones.

Project context records product purpose, architecture, source-of-truth roles, validation commands, tracker policy, artifact roots, and current constraints. Roadmap JSON records repository, templates, labels, triage states, hierarchy labels, and optional board evidence.

## Board Boundary

Run `skills/setup-project/scripts/prepare-github-project-board.sh -Mode Plan` before approval. Ask `project_setup_board_approval`. `Create Board` requires explicit native evidence; `Verify Only` is read-only; `Stop` prevents mutation. Validate existing configuration with `-Mode ValidateConfig`.

## Validation And Closeout

Run `./scripts/validate-tracker-roadmap-proof.sh`, `./scripts/validate-workflow-contract.sh`, and `./scripts/validate.sh`. Stop on ambiguous ownership, conflicting tracker state, missing approval, or validation failure. Show changed setup files and receipts, then use `project_setup_next_step`; `Stop` is intermediate and this route has no final `Done` claim.
