---
name: align-project
description: Use when a Superpowers Project repo needs structure alignment, migration review, tracker alignment, live sync verification, or repair planning.
---

# Project Align

Audit structure and tracker drift, explain the evidence, and prepare or apply only approved repairs. This route owns alignment findings; it does not own implementation planning or merge approval.

## Capability Preflight

Require `filesystem.read`, `shell`, and `git` from `docs/superpowers/capabilities.yml`. Require `github` before GitHub-aware checks and `native.user-input` before an interactive repair gate. Stop with the missing capability name before execution.

## Shared Policy

Read `skills/advanced-user-input/SKILL.md` once for global continuation and artifact-review rules. Keep only route-specific evidence, gates, and stop conditions here. Route facts and question labels come from `docs/superpowers/workflow-contract.yml`.

## Procedure

1. Run `skills/align-project/scripts/align-project.sh -RepoRoot . -Mode LocalDocs` for repository-only checks.
2. Use `-Mode GitHubAware` only when GitHub or a supplied fixture is in scope. Use `-TrackerHygiene` for tracker drift.
3. Classify each finding as blocking, repairable, informational, or healthy. Cite the path, observed value, expected contract, and repair owner.
4. Treat `docs/superpowers/specs`, `plans`, `issues`, and `milestones` as flat canonical roots. Nested retired roots are drift.
5. Never apply tracker or live mutations without the route's native approval. Record repair receipts.
6. Re-run the same checks after repair and run `./scripts/validate.sh` for repo-wide proof.

## Stop Conditions

Stop when the project root is ambiguous, evidence sources conflict, GitHub access is required but absent, a repair needs approval, or validation fails. A dirty worktree blocks verified final completion.

## Output

Report scope, blocking and repairable findings, healthy checks, skipped checks, exact repair plan or receipt, and recommended owner route. Use the graph-owned `project_align_next_step` branches. `Done` is valid only at `project_align_final_health_gate` after no blocking or repairable findings remain and `git status --short` is empty; otherwise use the shared intermediate `Stop` route.
