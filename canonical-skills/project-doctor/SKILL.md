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

For active issue work, verify that issue mirrors include source plan linkage, AFK/HITL classification, Goal Command for AFK work, acceptance criteria, proof oracle, and native goal setup expectations consumed by `$resolve-issue-with-goal`.

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
