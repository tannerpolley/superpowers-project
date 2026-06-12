# Plan Task Use Cases Strict Contract

## Purpose

Implementation plans must make the behavioral coverage for each task explicit before work starts. Numbered tasks without concrete use cases leave implementers to infer scope during code changes, which is too soft for plan implementation and issue resolution.

## Contract

Every actual implementation plan under `docs/superpowers/plans` must include `Task # Use Cases`:

- every numbered `Task N` section must include `**Use Cases:**`;
- the use-case block must appear before files and checkbox steps;
- the block must contain at least one concrete bullet describing user behavior, system behavior, issue acceptance, failure/recovery, validation, or workflow coverage;
- empty use-case blocks fail validation;
- issue acceptance criteria alone do not substitute for task-level use cases.

## Enforcement Points

`$superpowers-project:write-plan` must run the validator before presenting a plan as ready or routing into work.

`$superpowers-project:implement-plan` must run the validator against the approved plan before branch setup, worker handoff, or code edits.

`$superpowers-project:resolve-issue` must run the validator against the linked source plan after source plan validation and before native goal activation, branch setup, or code edits.

The authoritative command is:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <plan>
```

## Recovery

If validation fails, route back to `$superpowers-project:write-plan` with `Revise Plan`. Do not convert missing use cases into implementation assumptions, worker notes, deferred cleanup, or issue-resolution judgment calls.

## Validation

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-task-use-cases.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
