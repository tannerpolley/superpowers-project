---
name: loop-controller
description: Use when Superpowers Project should coordinate repeated bounded outcome lifecycles across candidates.
---

# Loop Controller

Coordinate bounded repeated maintenance. It selects candidates and verifies iteration evidence; owning route skills perform the actual work.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before candidate selection when any capability is absent.

## Shared Policy

Use `skills/advanced-user-input/SKILL.md` for global continuation and artifact review. This skill keeps route-specific loop budget, inventory, verifier, continuation, and final-health rules local. Read route ownership from `docs/superpowers/workflow-contract.yml`.

## Loop Contract

Generated state lives under `.superpowers/runs/<run-id>/`; it is evidence, not canonical backlog. Prefer `docs/superpowers/backlog/ACTIVE.md` as the ready-candidate source. Validate run, budget, verifier, state-machine, and terminal ledgers with the scripts under `skills/loop-controller/scripts/`.

For each iteration:

1. Recheck elapsed/token/candidate budgets with `validate-budget.sh`.
2. Select exactly one ready executable candidate with `select-candidate.sh`.
3. Record selection through `scripts/workflow-run.sh` and route to the graph owner.
4. Record mutations, acceptance, and independent verifier proof.
5. Recheck budget and health, then record policy-sourced `grant-continuation` evidence before any second candidate. Do not ask a routine continuation question unless startup policy explicitly requires a checkpoint.
6. Replay the event ledger; never edit `run.json` directly.
7. Write metrics with `write-metrics-report.sh`.

Auto Mode is not a backlog drain and cannot reuse Looping continuation authority. Parent and plan-wrapper issues are rollup work, not implementation candidates.

## Stop Conditions And Completion

Block on tampering, no ready candidate, budget exhaustion, failed verification, dirty unsafe state, owner mismatch, or missing continuation proof. `iteration` completion requires acceptance, verification, budget, and policy continuation evidence. Resolve `project_loop_final_health_gate` through the shared lifecycle mode policy; `Done` is valid only after terminal proof and a clean worktree.
