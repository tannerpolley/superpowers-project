# M1 Execution Kernel And Release Trust Receipt

## Purpose

This durable index defines the evidence required to accept issue [#113](https://github.com/tannerpolley/superpowers-project/issues/113). It intentionally does not record a current commit, package hash, installed identity, or publish receipt: those values are valid only after the final source commit and deployment.

## Sources

- Spec: `docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md`
- Plan: `docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md`
- Acceptance matrix: `tests/fixtures/execution-kernel/acceptance-matrix.json`
- Ephemeral release evidence: `.superpowers/runs/execution-kernel-<commit>/release/`

## Durable Acceptance Contract

The final proof must record:

- zero uncovered acceptance-matrix rows and zero surviving required-rule receipt mutations;
- lifecycle entries containing gate, envelope hash, receipt hash, prior receipt hash, repository identity, candidate identity, head, and rule results;
- validator identities `pr-ready-validator@1`, `premerge-validator@1`, `merge-decision-validator@1`, `closeout-validator@1`, and `publish-ready-validator@1`;
- source commit and runtime package `HashRef` values;
- installed plugin version, package identity, installation root, and source/installed agreement;
- observed trial events, derived tool-call and external-mutation counts, and receipt identities;
- source validation, live-sync validation, plugin refresh, version freshness, release-receipt consumption, cleanup, and clean Git results.

## Proof Commands

1. `python3 -m unittest discover -s tests -p 'test_*.py'`
2. `./skills/resolve-issue/scripts/test-scenarios.sh`
3. `./skills/merge-changes/scripts/test-scenarios.sh`
4. `./scripts/test-prepare-release.sh`
5. `./scripts/validate.sh`
6. Commit the complete source surface.
7. `./scripts/sync-live.sh --validate`
8. `codex plugin add superpowers-project@personal --json`
9. `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
10. Generate and consume the ignored publish-ready envelope and receipt for the committed source.
11. `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
12. `git status --short --branch`

## Remaining Risk

Version 1 authenticates stable provider identifiers, raw observation hashes, and live corroboration. Provider signatures remain deferred; provider unavailability therefore blocks authorization rather than being inferred as success.
