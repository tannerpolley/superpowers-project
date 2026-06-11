# Release Policy

Superpowers Project plugin releases are tags on the canonical source repository.

## Gates

Before creating a release tag:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` exits zero.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` exits zero.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-release.ps1 -CheckOnly` exits zero and records the source commit, plugin version, changelog evidence, dirty status, and required gates.
- `CHANGELOG.md` contains the version entry.
- The live plugin and user-level skill copies match source after sync.
- `git status --short` is empty before tagging.

## Release Receipts

`scripts/prepare-release.ps1` creates a release receipt. The receipt is evidence only: it does not publish, tag, push, sync live copies, or approve mutation. A release receipt records:

- plugin manifest name and version;
- release base version after removing local build metadata;
- source branch and commit;
- dirty worktree status;
- changelog evidence for `Unreleased` or the target version;
- the validation and live-sync gates that still need to pass before tagging.

Use `-CheckOnly` during normal validation so in-flight branch work can prove the release process is wired without requiring a clean worktree. Omit `-CheckOnly` only at an actual release gate, where dirty status and the versioned changelog entry must pass.

## Versioning

- Use `v0.2.0` for the first release after the Superpowers Project rename and artifact-model migration.
- Use patch releases for validation, sync, docs, and workflow fixes after `v0.2.0`.
- Use minor releases for new skill behavior or new plugin capabilities.
- Use major releases only for breaking prompt namespace, artifact-root, or live-sync contract changes.
- Keep local build metadata such as `+codex.YYYYMMDDHHMMSS` out of Git tags. Tags use the base version, for example `v0.2.1`.

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
