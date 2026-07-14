---
name: merge-changes
description: Use when a PR-backed issue, worker handoff, or approved local branch needs reviewed integration and clean terminal proof.
---

# Project Merge

Own premerge review, approval, integration, cleanup, and terminal proof.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, and `native.user-input` from `docs/superpowers/capabilities.yml`; add `github` for PR or remote publication. Stop before premerge when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates. Require `superpowers:verification-before-completion` proof and use `superpowers:finishing-a-development-branch` for integration.

## Intake And Procedure

`pr-issue` requires a pushed branch, PR, successful checks, closing issue linkage, source artifacts, outcome proof, readiness review, and publication proof. `local-branch` requires an approved plan, development branch, validation receipts, changed-file inventory, readiness review, and clean main. It needs no push or PR proof, though the current authenticated premerge validator still requires provider-state evidence.

1. Run `skills/merge-changes/scripts/premerge.sh` with the current `pr_ready` receipt and retain the `premerge` hash.
2. Require true `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` review fields.
3. Use `skills/merge-changes/scripts/prepare-local-branch-closeout.sh` for local work; validate checks and issue linkage for PR work. `validate-merge-decision.sh` consumes the current premerge receipt.
4. Show the Artifact Review Card and resolve `project_merge_approval`. Manual asks; Auto or Looping selects Merge only within immutable authority and clean proof.
5. Integrate without pushing a local-only route. `apply-local-branch-closeout.sh` consumes only the current merge-decision receipt. Re-run validation, remove goal-owned state, run cleanup, replay events, and run `closeout.sh` with that receipt.

The receipt chain is `pr_ready -> premerge -> merge_decision -> closeout`; each transition binds its predecessor, repository, workflow, source, and stable target. Missing, stale, cross-candidate, legacy, or boolean evidence fails closed. Validators never collect replacement evidence.

Use the existing `workspace_receipt`. Remove only plugin-owned `local_git_worktree` state with proven provenance. `codex_app`, user-owned, and detached workspaces never grant physical deletion or publication authority.

## Final Health

Stop on missing approval, failed checks, stale evidence, conflicts, dirty main, uncertain cleanup ownership, or source mismatch. Use `project_merge_next_step` for repair. `Done` is verified final only at `project_merge_final_health_gate` after integration, validation, cleanup, closeout, workflow completion, and a clean worktree; otherwise retain `Stop`.
