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

## Looping Mode Input

When invoked from `project_workflow_mode`, require a validated workflow mode ledger with `selected_mode: looping` before selecting another candidate. Looping Mode is bounded repeated maintenance autonomy: it may select one ready candidate at a time from issue mirrors, approved plans, approved specs, audit findings, alignment drift, version drift, or live-sync drift, then route the actual work to the owning Superpowers Project skill.

After a candidate is merged, closed, or paused, re-check the budget and continuation gate before choosing another candidate. Auto Mode remains one-route autonomy and must not use Loop Controller to continue to another candidate.

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

## Current Required Gates

Validate run ledgers with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\validate-run-ledger.ps1 -RepoRoot <repo-root> -RunLedgerPath <ledger-path>
```

Validate budget ledgers with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\validate-budget.ps1 -RepoRoot <repo-root> -BudgetLedgerPath <ledger-path>
```

Select deterministic safe candidates with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\select-candidate.ps1 -RepoRoot <repo-root> -InventoryPath <inventory-path>
```

Validate verifier ledgers with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\validate-verifier-ledger.ps1 -RepoRoot <repo-root> -VerifierLedgerPath <ledger-path>
```

Validate terminal closeout with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\validate-terminal-closeout.ps1 -RepoRoot <repo-root> -RunResultPath <run-result-path>
```

Write metrics reports with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\write-metrics-report.ps1 -RepoRoot <repo-root> -MetricsInputPath <input-path> -OutputPath <output-path>
```

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Native Continuation Gate

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

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

Terminal Done requires the terminal closeout validator from the later closeout slice to pass. Final Done also requires `git status --short` to show the worktree is clean unless the run is explicitly scoped to non-repo state. A saved plan, pushed branch, created issue, synced live plugin, or completed validator run is not terminal by itself.

## Artifact Review Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before any loop closeout or permission question. Route-specific artifact inventory must include the created or revised run ledger, validation receipts, selected candidate evidence, route decision, rendered Markdown artifacts when present, metrics artifacts, and machine-readable artifacts with exact paths plus key fields. Add the helper-required findings summary with route-specific status for loop progress, verifier proof, metrics, active-goal impact, broader project context, and recommended next route.
