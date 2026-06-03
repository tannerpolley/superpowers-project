---
name: project-doctor
description: Use when a Superpowers Project repo needs drift audit, migration review, tracker alignment, live sync verification, or repair planning.
---

# Project Doctor

Project Doctor audits Superpowers Project structure and reports drift before any repair. It is report-first: no mutation without user approval.

## Audit Scope

Inspect and report on:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones`
- `docs/superpowers/specs`
- `docs/superpowers/plans`
- `docs/superpowers/issues`
- GitHub issue mirror fields
- GitHub milestone linkage
- label vocabulary
- retired docs/milestones canonical usage
- live plugin sync drift
- active issue goal execution checks

## Flat Artifact Root Audit

Doctor enforces flat canonical roots for the `spec -> plan -> issue` lifecycle:

- loose specs belong in `docs/superpowers/specs`
- implementation plans belong in `docs/superpowers/plans`
- GitHub issue mirrors belong in `docs/superpowers/issues`

Milestone pages are index views. They should link to flat canonical artifacts and may group by milestone, package, or category through frontmatter plus milestone indexes. They must not own canonical nested copies. Report nested canonical milestone artifact folders are drift when `docs/superpowers/milestones/<milestone>/specs`, `docs/superpowers/milestones/<milestone>/plans`, or `docs/superpowers/milestones/<milestone>/issues` exists, unless the folder is explicitly marked as generated index/view output.

Migration guidance: move canonical files back to the flat roots, preserve milestone identity in frontmatter and filenames where applicable, then regenerate milestone README/dashboard views as links. Specs stay loose; move implementation-only metadata into the matching plan or issue mirror.

GitHub checks should compare issue URLs, issue states, milestone titles, labels, and issue mirror bodies when credentials and target repo context allow it. Local-docs-only audits may skip GitHub calls but must say which GitHub checks were skipped.

## Report Categories

Group findings as:

- blocking: breaks execution, publication, validation, or source-of-truth safety
- repairable: can be fixed with an approved docs or tracker repair
- informational: worth knowing but does not block the current workflow
- healthy: explicitly verified as aligned

## Migration Report

When old Milestones artifacts are present, produce a migration report from retired docs/milestones canonical usage to the new Superpowers Project model. Do not move, delete, rewrite, or publish those files until the user approves an exact repair plan.

## Drift Checks

Check for drift across:

- project context intent vs milestone pages
- milestone pages vs GitHub milestones
- specs vs plans
- plans vs issue mirrors
- issue mirrors vs GitHub issues
- issue labels vs label vocabulary
- issue execution fields vs native `/goal` requirements
- live plugin install vs source repo, including retired skill directories and active wrappers

## Goal Execution Checks

For active issue work, verify that issue mirrors include source plan linkage, AFK/HITL classification, Goal Command for AFK work, acceptance criteria, proof oracle, and native goal setup expectations consumed by `$project-resolve`.

## Repair Policy

Default mode is audit-only. If repairs are needed, ask the user which repair set to apply with `request_user_input` when callable. A repair plan must list exact files and GitHub objects before any change.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not perform repairs and must not be used to pretend a live user approved mutation.

Allowed repairs after approval are limited to project docs, issue mirrors, labels, milestone metadata, wrappers, and live sync cleanup owned by this plugin. Do not edit product code, implementation tests, runtime config, branches, PRs, merges, issue close state, or native goals from Project Doctor.

## Report Shape

A useful report includes:

- target repo and repo root
- audit mode: local-docs-only or GitHub-aware
- checked artifacts
- findings grouped as blocking, repairable, informational, and healthy
- migration report
- proposed repairs, if any
- validation commands to run after approved repairs

## Native Continuation Gate

After the audit report or approved repair proof is ready, summarize the Doctor result in chat before asking the continuation question. The summary must name blocking findings, repairable findings, healthy checks, skipped checks, proposed repair artifacts, and recommended next route.

Ask a native continuation question with `request_user_input` when callable.

Question id: `project_doctor_next_step`

Prompt: `How should I continue from this project audit?`

Options:

- `Apply Repair`: apply an approved, exact repair plan.
- `Create Planning Spec`: start `$project-brainstorm` or `$project-plan` for a larger repair design.
- `Run Audit Again`: rerun `$project-doctor` after changes or new GitHub evidence.
- `Review First`: stop for user review before mutation.
- `Stop`: stop after the Doctor closeout.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.
