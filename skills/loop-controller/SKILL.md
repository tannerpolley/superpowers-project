---
name: loop-controller
description: Use when Superpowers Project should coordinate repeated workflow runs across candidates while preserving Auto Mode authorization and native approval gates.
---

# Loop Controller

Loop Controller is the Superpowers Project orchestration layer for repeated workflow runs. It creates or resumes a local run ledger, selects one safe candidate, enforces budgets, routes to existing skills, records verifier proof, writes metrics, and asks native continuation questions.

**Announce at start:** "I'm using the loop-controller skill."

## Startup Version Gate

Before selecting candidates, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent
```

If the loaded plugin or skill root is known, pass `-ObservedPluginRoot` or `-ObservedSkillRoot`. Print the banner before routing.

Canonical marker: `scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent`.

## Boundary

Auto Mode is a route permission ledger. Loop Controller is the run coordinator. Loop Controller may validate and carry an Auto Mode authorization path, but it must not treat Auto Mode as permission to select unrelated work, widen mutation scope, bypass proof, push, merge, mutate GitHub, sync live, or claim final Done.

Existing skills own work:

- `$superpowers-project:brainstorm-spec` owns idea shaping and specs.
- `$superpowers-project:write-plan` owns implementation plans.
- `$superpowers-project:create-issues` owns issue creation.
- `$superpowers-project:implement-plan` owns branch-backed plan execution.
- `$superpowers-project:resolve-issue` owns direct issue resolution.
- `$superpowers-project:orchestrate-issues` owns worker-thread issue execution.
- `$superpowers-project:merge-changes` owns merge closeout.
- `$superpowers-project:audit-project` owns evidence-backed audit findings.
- `$superpowers-project:align-project` owns source/live/tracker drift repair.

## Run State

Default generated run state lives under `.superpowers/runs/<run-id>`. Do not commit generated run ledgers unless a later approved plan explicitly requests durable committed run history.

## Required Gates

- Validate run ledgers with `skills/loop-controller/scripts/validate-run-ledger.ps1`.
- Validate budget ledgers with `skills/loop-controller/scripts/validate-budget.ps1`.
- Select candidates with `skills/loop-controller/scripts/select-candidate.ps1`.
- Validate verifier evidence with `skills/loop-controller/scripts/validate-verifier-ledger.ps1`.
- Validate terminal closeout with `skills/loop-controller/scripts/validate-terminal-closeout.ps1`.
- Write metrics with `skills/loop-controller/scripts/write-metrics-report.ps1`.

## Native Continuation Gate

Question id: `project_loop_next_step`

Prompt: `Should I continue on with the loop workflow?`

Options:

- Yes: select or run the next candidate route within budget and policy.
- Revisit: review evidence, repair run state, adjust candidate selection, or rerun validation.
- Stop: pause the loop with recorded run state.

If Yes has multiple route choices, ask a nested route question before starting the selected skill. Do not merge route children into the top-level question.

## Final Health Gate

Question id: `project_loop_final_health_gate`

Prompt: `Is this loop run fully complete?`

Options:

- Done: valid only after clean run ledger, verifier proof, metrics, and clean repo or explicitly scoped non-repo state.
- Revisit: review or repair evidence before terminal closeout.
- Stop: pause with run state recorded, without claiming final completion.

Terminal Done requires `validate-terminal-closeout.ps1` to pass. A saved plan, pushed branch, created issue, synced live plugin, or completed validator run is not terminal by itself.
