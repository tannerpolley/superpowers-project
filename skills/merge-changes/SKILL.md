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

1. Consume the exact current `pr_ready` receipt when validating the version-1 premerge envelope; retain the resulting `premerge` receipt hash.
2. Require readiness review fields `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` to be true.
3. For local work, run `skills/merge-changes/scripts/prepare-local-branch-closeout.sh`; for PR work, validate checks and issue linkage. The merge-decision launcher consumes the current premerge receipt and the local closeout launcher consumes only `MergeDecisionReceiptJson|Path`.
4. Show the Artifact Review Card, then resolve `project_merge_approval` through the shared lifecycle mode policy. Manual asks; Auto or Looping selects Merge only when the immutable authorization permits it and clean premerge proof passes.
5. Integrate using the selected mode. Never push during local-only closeout.
6. Re-run validation, remove only goal-owned branch/worktree state, run cleanup, replay workflow events, and validate closeout with the exact current `merge_decision` receipt.

## Evidence Gate Contract

The authenticated chain is `pr_ready -> premerge -> merge_decision -> closeout`: every transition names the immediately preceding receipt and preserves repository, workflow, source, and stable target bindings. Missing, stale, cross-candidate, legacy, or bare boolean evidence fails nonzero with a stable error; validators never collect replacement evidence. Local integration may mutate Git only after consuming a current passing `merge_decision` receipt.

For isolated work, consume the existing version-1 `workspace_receipt`. `codex_app` and user-owned workspaces receive logical disposition only; never perform physical removal. The receipt grants no deletion path; a plugin-owned `local_git_worktree` is cleaned only through the finishing skill's independently proven worktree provenance after integration. Detached receipts cannot authorize publication.

## Stop Conditions And Final Health

Stop on missing approval, failed checks/validation, stale evidence, conflicts, dirty main, ambiguous cleanup ownership, or mismatched source plan. Use `project_merge_next_step` for repair/review routes. `Done` is a verified final state only at `project_merge_final_health_gate` after merge, validation, cleanup, closeout receipt, workflow completion, and a clean worktree; otherwise retain `Stop` as the terminal choice.
