---
name: align-project
description: Use when a Superpowers Project repo needs structure, tracker, migration, or live-sync alignment.
---

# Project Align

Find structural and tracker drift, then prepare or apply approved repairs.

## Capability Preflight

Require `filesystem.read`, `shell`, and `git` from `docs/superpowers/capabilities.yml`; add `github` for GitHub checks and `native.user-input` for repair approval. Stop with the missing capability name.

Follow `skills/advanced-user-input/SKILL.md` for shared gates and `docs/superpowers/workflow-contract.yml` for labels.

## Procedure

1. Run `skills/align-project/scripts/align-project.sh -RepoRoot . -Mode LocalDocs`. Inspect GitHub tracker state directly when the approved scope and capabilities include it.
2. Classify findings as blocking, repairable, informational, or healthy. Record path, observed value, expected contract, and owner.
3. Treat `docs/superpowers/specs`, `plans`, `issues`, and `milestones` as flat roots; nested retired roots are drift.
4. Obtain native approval before tracker or live mutations and record receipts.
5. Re-run the same checks plus `./scripts/validate.sh` after repair. Run `./scripts/sync-live.sh --validate` only when approved live-sync verification is in scope.

## Closeout

Stop on ambiguous roots, conflicting evidence, missing GitHub access, unapproved repair, or failed validation. Report findings, skipped checks, repair plan or receipt, and owner route through `project_align_next_step`. `Done` is verified final only at `project_align_final_health_gate` with no repairable findings and a clean worktree; otherwise retain `Stop`.
