# Milestones Plugin Repo

This repository is the canonical source of truth for the local Milestones Codex plugin and its user-level skills.

## Rules

- Treat this repo as source. Treat `C:\Users\Tanner\plugins\milestones` and `C:\Users\Tanner\.agents\skills\<milestones-skill>` as deployed copies.
- Do not edit the live deployed copies directly when this repo is available; edit this repo, validate, then run `scripts\sync-live.ps1`.
- Keep skills self-contained and testable with their bundled scenario scripts.
- New idea briefs for this repo belong under `docs/milestones/<milestone-folder>/ideas/`.
- Local issue files for this repo belong under `docs/milestones/<milestone-folder>/issues/`.
- Do not create `docs/ideas`, `docs/issues`, `docs/plans`, or `docs/milestones/<milestone-folder>/plans`.

## Validation

Before reporting repo changes complete, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Before updating the live install, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```
