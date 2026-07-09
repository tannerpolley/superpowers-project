# Required Post-Revision Loop Design

**Date:** 2026-07-09
**Status:** Approved design

## Purpose

Future Codex agents must finish plugin revisions through the same source, deployment, installation, and freshness checks. The repository remains the only editable source. Live plugin and user-skill locations remain deployment targets.

## Scope

The required loop applies when a revision changes any installable plugin surface:

- `.codex-plugin/`
- `skills/`
- `assets/`
- `scripts/`
- `docs/superpowers/`

Changes outside those paths still require proportionate validation, Git hygiene, and repo cleanup. They do not require live sync or plugin refresh unless they affect runtime behavior.

## Repository Contract

Add a `Required Post-Revision Loop` section to `AGENTS.md`. Future agents must complete these steps in order before reporting an installable-surface revision complete:

1. Run `./scripts/validate.sh`.
2. Commit the intended source changes so the version checker can report a clean source commit.
3. Run `./scripts/sync-live.sh --validate`.
4. Run `codex plugin add superpowers-project@personal --json` to install or refresh the supported marketplace snapshot.
5. Run `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`.
6. Run `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`.
7. Confirm `git status --short --branch` shows the expected clean branch state.
8. Tell the user to start a fresh Codex session because loaded prompt and skill text cannot change inside the current model context.

Agents must report any skipped or failed gate. They must not edit the deployed plugin, deployed user skill, or plugin cache as a substitute for this loop.

## Maintainer Runbook

Add a `Revision And Refresh Loop` section to `README.md` next to the existing sync and installation guidance. The runbook will show one copyable command sequence and explain these boundaries:

- `validate.sh` proves source integrity.
- `sync-live.sh --validate` deploys the source-owned plugin surface and personal marketplace metadata.
- `codex plugin add` installs or refreshes the Codex-owned snapshot and may be rerun after later revisions.
- `get-agent-plugin-version.sh` proves source/live equality.
- A fresh session loads the updated installed plugin.

Release publication remains separate. Maintainers should update the plugin version and changelog for a named release, but local revision loops can refresh the current marketplace entry without inventing a release version for each edit.

## Validation

Implementation is complete when:

- `AGENTS.md` states the required gate and its path-based scope;
- `README.md` contains the matching copyable runbook;
- both documents use the same command order and fresh-session rule;
- `./scripts/validate.sh` passes;
- `./scripts/sync-live.sh --validate` passes;
- `codex plugin add superpowers-project@personal --json` succeeds;
- the strict version check reports source/live current;
- cleanup passes and Git reports the expected state.

## Exclusions

- No new wrapper script.
- No direct cache mutation.
- No compatibility alias for older deployment behavior.
- No issue or pull-request workflow requirement for routine plugin maintenance.
