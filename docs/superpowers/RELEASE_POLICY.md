# Release Policy

Superpowers Project releases are immutable tags on a clean, verified `main` commit. The source repository keeps project history; `.codex-plugin/runtime-package.yml` defines the installed package.

## Current Release

`v0.3.0` is the workflow-runtime and agent-usability release. It includes typed command ownership, replayable governance, generated graph references, capability-aware concise skills, real-agent proof, explicit package provenance, and read-only revision status.

## Required Evidence

Before creating a local release tag, prove all of the following against the same commit and runtime package hash:

- `./scripts/validate.sh` exits zero;
- source changes are committed;
- `./scripts/sync-live.sh --validate` exits zero;
- `codex plugin add superpowers-project@personal --json` refreshes the supported marketplace snapshot;
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent` confirms source/live freshness;
- five Auto golden and three Looping adversarial fresh-agent receipts pass independent verification;
- the cleanup hook exits zero;
- `git status --short --branch` is clean;
- `./scripts/prepare-release.sh` validates the assembled release evidence.

Validation, sync, installation, cleanup, and agent receipts must name the same commit, package hash, and manifest version where applicable. `-CheckOnly` verifies release wiring during branch work without claiming publish readiness.

## Version And Tag Rules

- Patch versions cover compatible fixes.
- Minor versions cover new skill, workflow, or plugin capabilities.
- Major versions cover breaking prompt namespace, artifact-root, or installation contracts.
- Build metadata may identify a local snapshot but never appears in a tag.
- Tags use `v<major>.<minor>.<patch>`; `0.3.0+local` therefore maps to `v0.3.0`.

Create `v0.3.0` locally only after every gate passes. Do not push the tag unless the user grants separate remote-publication authority.

```bash
git tag v0.3.0
```

The release receipt and local tag do not authorize a push, GitHub release, package publication, or cache mutation.
