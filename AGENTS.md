# Superpowers Project Plugin Repo

This repository is the canonical source of truth for the local Superpowers Project Codex plugin.

## Rules

- Treat this repo as source. Treat `/home/tnnrpolley21/.codex/plugins/superpowers-project` as the deployed plugin copy.
- Do not edit the live deployed copy directly when this repo is available; edit this repo, validate, then run `scripts/sync-live.sh`.
- For routine revisions and fixes to this project plugin's own skills, choose the smallest workflow that fits the task. This repo policy does not require a default skill sequence, and ordinary project-plugin maintenance should not route through `$superpowers-project:create-issues`, `$superpowers-project:resolve-issue`, or `$superpowers-project:merge-changes` unless the user explicitly asks for GitHub issue/PR workflow coverage.
- Keep skills self-contained and testable with their bundled scenario scripts.
- Canonical specs, PRDs, plans, issue mirrors, and milestone pages for this repo belong under `docs/superpowers/`.
- New specs or PRDs belong under `docs/superpowers/specs/`.
- New implementation plans belong under `docs/superpowers/plans/`.
- Local GitHub issue mirrors belong under `docs/superpowers/issues/`.
- Roadmap milestone pages belong under `docs/superpowers/milestones/`.
- Do not create canonical artifacts under `docs/ideas`, root-level `docs/issues`, root-level `docs/plans`, or retired `docs/milestones/<milestone-folder>/ideas|issues|plans`.

## Required Post-Revision Loop

Changes under `.codex-plugin/`, `skills/`, `assets/`, `scripts/`, or runtime-included `docs/superpowers/` paths change the installable plugin surface. This repo applies the same loop to all `docs/superpowers/` revisions to keep the policy simple. Before reporting such a revision complete, future agents must complete this sequence in order:

1. Run `./scripts/validate.sh`.
2. Commit the intended source changes. If commit authorization is absent, request it and stop before live deployment.
3. Run `./scripts/sync-live.sh --validate`.
4. Run `codex plugin add superpowers-project@personal --json` to install or refresh the supported marketplace snapshot.
5. Run `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`.
6. Run `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`.
7. Confirm `git status --short --branch` shows the expected clean branch state.
8. Tell the user to start a fresh Codex session so the updated prompt and skill text load.

Report every skipped or failed gate. Validation-only and sync-only sequences do not complete an installable-surface revision. Never edit deployed copies or plugin cache files to bypass this loop.

Changes outside the listed installable paths require proportionate validation and cleanup, but do not require live sync or plugin refresh unless they alter runtime behavior.

## Validation

Before reporting repo changes complete, run:

```bash
./scripts/validate.sh
```

Before updating the live install, run:

```bash
./scripts/sync-live.sh --validate
```
