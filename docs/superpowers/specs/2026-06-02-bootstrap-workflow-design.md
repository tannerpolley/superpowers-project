# Bootstrap Workflow Design

Date: 2026-06-02

## Status

Historical bootstrap record. The validation repair, live sync cleanup, CI workflow, and initial GitHub-backed project workflow have since been implemented by later plans and merged PRs. Do not create a retroactive implementation plan for this spec unless release/tag policy is reopened as new work.

## Context

The Milestones plugin repo is the canonical source for the local plugin and its user-level skills. The live plugin at `C:\Users\Tanner\plugins\milestones` and user skills under `C:\Users\Tanner\.agents\skills` are deployed copies.

The repo is currently clean on `main`, source and deployed copies are byte-for-byte synced, GitHub Issues and Projects are enabled, required labels exist, and the three GitHub milestones mirror `docs/milestones/PROJECT_CONTEXT.md`.

Full validation is not green. `scripts/validate.ps1` fails on wrapper wording assertions, and the `project-resolve` scenario suite does not finish within a two-minute bound during manual review.

## Solidified Findings

The bootstrap work is driven by these findings:

- `scripts/validate.ps1` fails because scenario tests expect wrapper wording that the current source and deployed wrappers do not contain.
- `canonical-skills/using-milestones/scripts/test-scenarios.ps1` and `canonical-skills/milestone-writing-issue-plan/scripts/test-scenarios.ps1` validate wrappers through deployed live paths instead of source wrapper paths.
- `canonical-skills/project-resolve/scripts/lib/contract.ps1` runs external processes with redirected output, synchronous stream reads, and no timeout. The matching scenario suite inherits that behavior and can hang validation.
- `canonical-skills/convert-idea-to-issue/scripts/lib/contract.ps1` uses the same unbounded process helper pattern, even though its current scenario suite passes.
- `scripts/sync-live.ps1` deploys known source skills but does not remove stale deployed Milestones-owned skill directories after a source skill is removed or renamed.
- There is no `.github/workflows` directory.
- There are no GitHub issues and no local milestone idea or issue files yet.
- Source and deployed copies are currently in sync, so the validation failures are source issues rather than stale deployment residue.

## Goal

Create a staged bootstrap path that restores trustworthy validation, hardens source-to-live deployment, and starts the repo's own milestone-backed issue workflow.

## Non-Goals

- Do not implement product behavior inside this design step.
- Do not publish a release tag while full validation is red.
- Do not create `docs/ideas`, `docs/issues`, `docs/plans`, or milestone `plans` folders.
- Do not delete user-authored live skills or plugin files outside the Milestones-owned deployment set.

## Recommended Approach

Use a staged bootstrap repair:

1. Make validation green and bounded.
2. Harden live sync and drift checks.
3. Add CI and initial milestone-backed work items.
4. Define a small release and tag policy after validation is trustworthy.

This order keeps the first outcome focused on proof. CI, issues, and release policy should build on a validation command that exits reliably and reports precise failures.

## Components

### Validation Entrypoint

`scripts/validate.ps1` remains the top-level proof command. It should report which check failed and should not allow one scenario suite to hang without a bounded failure result.

### Scenario Suites

`canonical-skills/*/scripts/test-scenarios.ps1` owns skill-level behavior checks. Wrapper assertions should inspect repo source wrappers under `skills/` or receive explicit wrapper paths from the validator. Scenario tests should not treat deployed live copies as source evidence.

### Process Execution Helper

The shared external process helper in skill script libraries should capture stdout and stderr safely, enforce a timeout, and stop only the child process it launched when a timeout occurs.

### Live Sync

`scripts/sync-live.ps1` owns deployment from source to live paths. It should deploy source skills, remove only stale Milestones-owned deployed skill directories, and verify drift after deployment.

### GitHub Workflow

CI should run the same PowerShell validation command used locally:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

The first workflow should run on pull requests and pushes to `main`.

## Data Flow

The intended flow is:

```text
repo source -> validation -> sync-live -> drift check -> GitHub issue and CI evidence
```

Repo source remains authoritative. Live plugin and user skill directories are deploy targets and verification targets, not inputs for source-level scenario assertions.

## Failure Handling

Validation failures should be loud and specific:

- Wrapper assertion failures name the source wrapper path and missing contract text.
- Scenario failures include skill name, scenario name, and reason.
- Timed-out external commands report the executable, arguments, working directory, and timeout duration.
- Timed-out child processes are stopped by owned process handle.
- Sync cleanup refuses paths outside the approved live plugin root and approved user skill root.
- Stale live cleanup removes only directories whose names are part of the Milestones-owned skill set.

## Testing Plan

The implementation plan should include regression tests or script scenarios for:

- Wrapper tests read repo source wrappers and pass.
- Full `scripts/validate.ps1` exits successfully.
- A synthetic hung helper returns a timeout failure and does not leave its child process running.
- Stale deployed Milestones skill cleanup removes an approved stale skill directory and preserves unrelated directories.
- Post-sync drift checks compare source wrappers to live wrappers and canonical skills to deployed user skills.
- CI invokes the same validation command as local development.

## Bootstrap Artifacts

Initial issue work should be milestone-backed:

- `M0 - Governance`: validation repair and bounded process execution.
- `M1 - Source Of Truth`: source-based wrapper tests and source/live drift checks.
- `M2 - Distribution`: sync stale cleanup, CI, and release/tag policy.

The first CI workflow should be intentionally small. A broader matrix can wait until the plugin has a reason to prove more environments.

Release policy should stay lightweight:

- No release tag while full validation is red.
- Once validation is green and CI exists, tag `v0.1.0` for the initial canonical repo state or `v0.1.1` if repair commits change behavior before tagging.
- Future version bumps require green validation, validated live sync, and a changelog update.

## Approved Design Decisions

- Use staged bootstrap repair rather than tracker-first or release-pipeline-first work.
- Keep the four ownership boundaries: validation entrypoint, scenario suites, live sync, and GitHub workflow.
- Add bounded process execution and a hung-helper regression test.
- Write this brainstorming spec under `docs/superpowers/specs/` and keep implementation issue mirrors under `docs/superpowers/issues/`.
