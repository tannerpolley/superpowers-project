---
name: loop-controller
description: Use when Superpowers Project should coordinate repeated bounded outcome lifecycles across candidates.
---

# Loop Controller

Select candidates and verify iteration evidence; owner routes perform the work.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before selection when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates.

## Loop Contract

Store generated evidence under `.superpowers/runs/<run-id>/`. Candidate source precedence lives in `docs/superpowers/loop-mode-contract.yml`; pass `select-candidate.sh` a JSON `-InventoryPath` whose ready items were derived from those sources. The Markdown backlog is not a selector input. Validate run, budget, verifier, state machine, and terminal ledgers with `skills/loop-controller/scripts/`.

For each iteration:

1. Check elapsed, token, and candidate budgets with `validate-budget.sh`.
2. Select one ready executable candidate with `select-candidate.sh -InventoryPath <inventory>`, record it through `scripts/workflow-run.sh -Action select`, and invoke its graph owner.
3. Record mutations, acceptance, and independent verification.
4. Run `scripts/workflow-run.sh -Action recheck-budget -BudgetEvidencePath <budget-ledger> -HealthEvidencePath <verifier-ledger>`, then `-Action grant-continuation` before another candidate. The runtime hashes and validates both ledgers.
5. Let runtime actions replay the event ledger; never edit `run.json`. Run `write-metrics-report.sh -MetricsInputPath <metrics> -OutputPath <report>`.

Auto cannot drain a backlog or reuse Looping continuation authority. Parent and wrapper issues are not implementation candidates.

## Closeout

Block on tampering, no ready candidate, exhausted budget, failed verification, dirty unsafe state, owner mismatch, or missing continuation proof. `iteration` completion requires acceptance, verification, budget, and continuation evidence. Resolve `project_loop_final_health_gate` through shared mode policy; `Done` requires terminal proof and a clean worktree.
