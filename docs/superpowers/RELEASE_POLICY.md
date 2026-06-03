# Release Policy

Superpowers Project plugin releases are tags on the canonical source repository.

## Gates

Before creating a release tag:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` exits zero.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` exits zero.
- `CHANGELOG.md` contains the version entry.
- The live plugin and user-level skill copies match source after sync.

## Versioning

- Use `v0.2.0` for the first release after the Superpowers Project rename and artifact-model migration.
- Use patch releases for validation, sync, docs, and workflow fixes after `v0.2.0`.
- Use minor releases for new skill behavior or new plugin capabilities.

## v0.2.0 Scope

`v0.2.0` represents the migration from the parallel Milestones workflow to the Superpowers Project extension model:

- plugin identity is `superpowers-project`;
- canonical artifacts live under `docs/superpowers`;
- issue mirrors live under `docs/superpowers/issues`;
- issue execution uses native `/goal` proof and Superpowers execution skills;
- retired Milestones skills are removed from source and live sync.

## Tag Command

Run tags from `main` only after the gates pass:

```powershell
git tag v0.2.0
git push origin v0.2.0
```
