# Superpowers Project Plugin

Superpowers Project is a local Codex plugin and skill family that extends Superpowers with GitHub-backed project management:

- durable project context under `docs/superpowers`;
- roadmap and milestone pages;
- native question UI for grilling assumptions;
- GitHub issue mirrors and milestone linkage;
- native `/goal` issue resolution with Superpowers execution skills.

This repository is the canonical source. The live Codex install is a deployment target.

## Current Skills

- `$superpowers-project`: routes extension workflows.
- `$project-context`: creates and maintains project context and milestone pages.
- `$project-brainstorm`: runs Superpowers brainstorming with native grilling.
- `$project-plan`: writes Superpowers implementation plans with project context.
- `$project-issue`: creates GitHub issue mirrors and GitHub issues from approved plans/specs.
- `$project-resolve`: resolves one issue with native `/goal` and Superpowers execution.
- `$project-merge`: reviews and merges PR-ready issue work, verifies linked issue closure, cleans owned branches and worktrees, prunes, and records clean repo proof.
- `$project-doctor`: audits project, GitHub, migration, and live-sync drift.

## Quick Apply

Quick Apply is the small-work escape hatch after `$project-plan`: it can apply a narrow, low-risk plan directly on local clean synced `main` only after the native `project_quick_apply_approval` question selects `Apply on Main`.

Use the bundled `skills/project-plan/scripts/validate-quick-apply.ps1` gate to require approval, focused verification commands, cleanup hook evidence, and explicit push approval before any push. The issue-backed `$project-issue` and `$project-resolve` execution path remains the default for non-trivial work, risky changes, multi-issue scope, branch-backed work, and PR-bound implementation.

## Canonical Layout

```text
.codex-plugin/plugin.json
skills/<skill-name>/
scripts/install.ps1
scripts/sync-live.ps1
scripts/validate.ps1
docs/superpowers/PROJECT_CONTEXT.md
docs/superpowers/specs/
docs/superpowers/plans/
docs/superpowers/issues/
docs/superpowers/milestones/
```

`skills/` contains the full skill implementations and is the only skill source root.

The retired Milestones artifact model is migration history only. New Superpowers Project artifacts should not be written under the old Milestones issue or idea folders, root-level issue folders, root-level plan folders, or milestone-local plan folders.

## Validate

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## CI And Releases

GitHub Actions runs the same validation command used locally:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Release gates and tag rules are documented in `docs/milestones/M2-distribution/RELEASE_POLICY.md`. The first release after this migration is `v0.2.0`.

## Sync To Live Codex Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

The sync script deploys this repo's plugin manifest and full skill implementations to:

- `C:\Users\Tanner\plugins\milestones`

It also deploys the same skill implementations to:

- `C:\Users\Tanner\.agents\skills`

## Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```
