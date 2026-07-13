# Simplify Workflow Contracts And Plugin Distribution

Pre-Publication: false

GitHub Issue: https://github.com/tannerpolley/superpowers-project/issues/116
Source Spec: docs/superpowers/specs/2026-07-10-contract-distribution-simplification-design.md
Source Plan: docs/superpowers/plans/2026-07-10-contract-distribution-simplification-plan.md
Milestone: M2 - Distribution
Labels: type:feature, status:ready
Dependencies: Issues #113, #114, and #115 are merged. Implement from current `main`.
Sub-Issue Role: leaf
Executable: true
Goal Command: Implement and verify `docs/superpowers/plans/2026-07-10-contract-distribution-simplification-plan.md` task by task.

## Summary

Resolve the two remaining distribution problems without adding another framework:

- stop copying the plugin-owned `advanced-user-input` skill into the global user-skill directory;
- stop shipping all historical specs and plans in the runtime package.

The existing version-2 workflow graph, generated views, runtime-read validator, and focused command modules remain unchanged.

## Acceptance Criteria

- [ ] Normal sync/install does not create, replace, or delete global user skills.
- [ ] A legacy global helper and an unrelated skill remain byte-identical in isolated sync tests.
- [ ] `advanced-user-input` remains available inside `superpowers-project`.
- [ ] Broad spec/plan runtime globs are removed.
- [ ] The two release-trust source artifacts directly read by the publish path remain packaged.
- [ ] Other spec/plan edits do not change runtime provenance.
- [ ] Runtime-read validation, full validation, PASS/PASS review, deployment gates, cleanup, and CI pass.
- [ ] The final change is net-negative and adds no production module or launcher.

## Proof Oracle

- `python3 -m unittest tests.test_runtime_package tests.test_package_provenance -v`
- `./scripts/test-plugin-only-live-sync.sh`
- `./scripts/test-install-transaction.sh`
- `./scripts/validate-runtime-package.py --repo-root .`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `codex plugin add superpowers-project@personal --json`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
- `git status --short --branch`

## Non-Goals

- Rewriting the already-versioned workflow graph or generating route-slice files.
- Adding dependency/cache inspection unsupported by the plugin manifest.
- Building revision-classification or artifact-lifecycle subsystems.
- Refactoring command handlers that already satisfy locality tests.
- Deleting a pre-existing global helper.
- Changing Auto, Loop, execution-kernel, or workspace semantics.

## Branch Policy

Use `codex/issue-116-contract-distribution-simplification`. The main thread owns review, PR, merge, and cleanup.

## Outcome Summary

**Outcome Source:** `docs/superpowers/specs/2026-07-10-contract-distribution-simplification-design.md` and `docs/superpowers/plans/2026-07-10-contract-distribution-simplification-plan.md`

**Intent:** Make plugin distribution smaller and stop accidental global policy writes.

**Target Output:** Plugin-only sync behavior, a precise runtime manifest, focused regression tests, and corrected source docs.

**Owner:** Superpowers Project distribution and runtime-package code.

**Interface:** Existing `scripts/sync-live.sh`, `runtime_manifest()`, and `validate_runtime_reads()` interfaces.

**Cutover:** Future syncs stop managing global helpers immediately; existing global files remain untouched.

**Replaced Path:** The `USER_SKILLS` copy loop and broad spec/plan runtime globs.

**Acceptance Proof:** Focused tests, full validation, independent PASS/PASS review, release loop, CI, and clean main.

**Stop Criteria:** Stop on a changed global sentinel, excluded runtime read, package drift, failed validation, or non-clean closeout.

**Avoid:** Avoid new schemas, generators, classifiers, cache reads, compatibility shims, and destructive legacy cleanup.
