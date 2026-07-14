---
name: setup-project
description: Use when Superpowers Project context, roadmap, tracker, milestone, or optional GitHub Project configuration needs creation or repair.
---

# Setup Project

Maintain the project context and tracker artifacts used by downstream routes.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`; add `github` for live tracker or board work. Stop before setup when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates and `docs/superpowers/workflow-contract.yml` for question labels.

## Artifacts And Board

Maintain `docs/superpowers/PROJECT_CONTEXT.md`, milestone indexes under `docs/superpowers/milestones/`, and `docs/agents/project-roadmap.json`. Keep specs, plans, and issues in flat roots. Milestone pages are dashboards; GitHub milestones remain tracker records.

Project context records purpose, architecture, source-of-truth roles, validation, tracker policy, artifact roots, and constraints. Roadmap JSON records repository, templates, tracker labels, triage states, hierarchy labels, and optional board evidence.

Run `skills/setup-project/scripts/prepare-github-project-board.sh -Mode Plan`, then ask `project_setup_board_approval`. `Verify Only` is read-only; `Stop` blocks mutation. An approved Create Board choice hands mutation to the authenticated GitHub workflow owner; the helper does not create the board. Validate configuration with `-Mode ValidateConfig`.

## Closeout

Run `./scripts/validate-tracker-roadmap-proof.sh`, `./scripts/validate-workflow-contract.sh`, and `./scripts/validate.sh`. Stop on ambiguous ownership, conflicting tracker state, missing approval, or failed validation. Show files and receipts through `project_setup_next_step`; retain `Stop`. This route has no verified final `Done`.
