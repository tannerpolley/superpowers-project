---
name: merge-changes
description: Use when a Superpowers Project issue-backed PR, worker handoff, or approved local branch must be reviewed, approved, merged, cleaned up, and recorded with clean repo proof.
---

# Project Merge

Own premerge review, native approval, integration, cleanup, and terminal proof for either a PR-backed issue or a local implementation branch.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Require `github` only for PR and remote-publication routes. Stop before premerge when a required capability is absent.

## Required Superpowers Pairings

Require upstream `superpowers:verification-before-completion` proof. Use `superpowers:finishing-a-development-branch` for branch integration and cleanup. Merge-time review cannot substitute for missing execution-time verification.

## Shared Policy

Read `skills/advanced-user-input/SKILL.md` for global continuation, artifact display, and terminal behavior. This route owns route-specific approval, evidence, cleanup, and final health. Labels are graph-owned in `docs/superpowers/workflow-contract.yml`.

## Intake Modes

`pr-issue` requires pushed branch, PR, successful checks, closing issue linkage, source plan/mirror, outcome proof, readiness review, and remote publication proof.

`local-branch` requires approved plan, named development branch, validation receipts, changed-file inventory, readiness review, clean main, and local branch proof. It does not require push, PR, or GitHub evidence. Remote publication is a separate route and permission boundary.

## Procedure

1. Collect premerge evidence and validate source-plan/branch linkage.
2. Require readiness review fields `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` to be true.
3. For local work, run `skills/merge-changes/scripts/prepare-local-branch-closeout.sh`; for PR work, validate checks and issue linkage.
4. Show the Artifact Review Card, then ask `project_merge_approval`. Do not infer approval from Auto unless the immutable authorization explicitly permits merge after clean premerge.
5. Integrate using the selected mode. Never push during local-only closeout.
6. Re-run validation, remove only goal-owned branch/worktree state, run cleanup, replay workflow events, and prove clean repository state.

## Stop Conditions And Final Health

Stop on missing approval, failed checks/validation, stale evidence, conflicts, dirty main, ambiguous cleanup ownership, or mismatched source plan. Use `project_merge_next_step` for repair/review routes. `Done` is a verified final state only at `project_merge_final_health_gate` after merge, validation, cleanup, closeout receipt, workflow completion, and a clean worktree; otherwise retain `Stop` as the terminal choice.
