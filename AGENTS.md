# Superpowers Project Plugin Repo

This repository is the canonical source of truth for the local Superpowers Project Codex plugin and its user-level skills.

## Rules

- Treat this repo as source. Treat `C:\Users\Tanner\plugins\milestones` and `C:\Users\Tanner\.agents\skills\<superpowers-project-skill>` as deployed copies.
- Do not edit the live deployed copies directly when this repo is available; edit this repo, validate, then run `scripts\sync-live.ps1`.
- For routine revisions and fixes to this project plugin's own skills, use the vanilla Superpowers workflow by default: `$superpowers:brainstorming`, `$superpowers:writing-plans`, then `$superpowers:executing-plans`. Do not route ordinary project-plugin maintenance through `$project-issue`, `$project-resolve`, or `$project-merge` unless the user explicitly asks for GitHub issue/PR workflow coverage.
- Keep skills self-contained and testable with their bundled scenario scripts.
- Canonical specs, PRDs, plans, issue mirrors, and milestone pages for this repo belong under `docs/superpowers/`.
- New specs or PRDs belong under `docs/superpowers/specs/`.
- New implementation plans belong under `docs/superpowers/plans/`.
- Local GitHub issue mirrors belong under `docs/superpowers/issues/`.
- Roadmap milestone pages belong under `docs/superpowers/milestones/`.
- Do not create canonical artifacts under `docs/ideas`, root-level `docs/issues`, root-level `docs/plans`, or retired `docs/milestones/<milestone-folder>/ideas|issues|plans`.

## Validation

Before reporting repo changes complete, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Before updating the live install, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```
