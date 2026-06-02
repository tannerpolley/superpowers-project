# Release Policy

Milestones plugin releases are tags on the canonical source repository.

## Gates

Before creating a release tag:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` exits zero.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` exits zero.
- `CHANGELOG.md` contains the version entry.
- The live plugin and user-level skill copies match source after sync.

## Versioning

- Use `v0.1.0` for the first green canonical baseline if no repair commit changes behavior before tagging.
- Use `v0.1.1` if validation, sync, CI, or release-policy repair commits land before the first tag.
- Use patch releases for validation, sync, docs, and workflow fixes.
- Use minor releases for new skill behavior or new plugin capabilities.

## Tag Command

Run tags from `main` only after the gates pass:

```powershell
git tag v0.1.1
git push origin v0.1.1
```
