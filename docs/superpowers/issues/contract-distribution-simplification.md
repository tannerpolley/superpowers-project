# Simplify Workflow Contracts And Plugin Distribution

Pre-Publication: true

GitHub Issue: Pending publication
Source Spec: docs/superpowers/specs/2026-07-10-contract-distribution-simplification-design.md
Source Plan: docs/superpowers/plans/2026-07-10-contract-distribution-simplification-plan.md
Milestone: M2 - Distribution
Labels: type:feature, status:ready
Dependencies: Blocked by the execution-kernel, Auto/Loop lifecycle, and Codex-native workspace-isolation issues. Rebase onto current `main` after all three merge and migrate their final consumers during schema-v2 generation.
Sub-Issue Role: leaf
Executable: true
Goal Command: Implement and verify `docs/superpowers/plans/2026-07-10-contract-distribution-simplification-plan.md` task by task.

**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Sequential plan tasks; no concurrent Git writers
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Summary

Normalize workflow contract ownership, generate per-skill route slices, validate the vanilla Superpowers dependency, stop ordinary global helper deployment, complete command locality, classify revision impact from the shipped surface, and validate canonical artifact lifecycle.

## Acceptance Criteria

- [ ] One normalized graph record owns every gate, option, transition, and owner skill.
- [ ] Per-skill route slices, runtime lookup data, contract digest, and fixtures are generated deterministically and fail validation on drift.
- [ ] Setup reports compatible, missing, incompatible, and incomplete vanilla Superpowers states without editing vanilla or cache files.
- [ ] Ordinary install, sync, refresh, and uninstall leave unrelated global user skills byte-identical.
- [ ] Remaining distribution-domain handlers live in focused modules behind stable public launchers.
- [ ] Revision classification covers specs, plans, skills, scripts, runtime-read documents, tests, ambiguous reads, and mixed changes.
- [ ] Active indexes reject missing or Superseded artifacts while receipt-bound history remains valid.
- [ ] Full validation, isolated plugin lifecycle tests, required deployment gates, cleanup, and clean-main proof pass.

## Proof Oracle

- `python3 -m unittest tests.test_workflow_graph tests.test_workflow_generation -v`
- `python3 -m unittest tests.test_dependency_contract tests.test_plugin_namespace -v`
- `python3 -m unittest tests.test_command_locality tests.test_revision_impact tests.test_artifact_lifecycle -v`
- `./scripts/validate-generated-state.sh`
- `./scripts/test-plugin-only-live-sync.sh`
- `./scripts/test-install-transaction.sh`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `codex plugin add superpowers-project@personal --json`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
- `git status --short --branch`

## Non-Goals

- Redefining Auto and Looping lifecycle semantics.
- Implementing evidence-gate rules owned by the execution kernel.
- Selecting or provisioning workspace providers.
- Vendoring or modifying vanilla Superpowers.
- Replacing stable public skill or launcher names.

## Branch Policy

Use `codex/issue-<number>-contract-distribution-simplification`. Do not implement directly on `main`. The main thread owns review, PR, merge, and cleanup.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Outcome Summary

**Outcome Source:** `docs/superpowers/specs/2026-07-10-contract-distribution-simplification-design.md` and `docs/superpowers/plans/2026-07-10-contract-distribution-simplification-plan.md`

**Intent:** Remove duplicated workflow authority and distribution side effects so agents consume a smaller, trustworthy plugin contract.

**Target Output:** Normalized workflow graph, generated route slices, dependency preflight, plugin-scoped helper behavior, focused modules, revision classifier, and artifact lifecycle validator.

**Owner:** Superpowers Project contract and distribution maintainer.

**Interface:** `compile_route_slices`, `validate_contract_ownership`, `inspect_superpowers_dependency`, `classify_revision`, and `validate_artifact_lifecycle` behind stable launchers.

**Cutover:** Generate and validate contract projections first, isolate dependency and namespace behavior second, then replace directory-only revision policy after classifier proof passes.

**Replaced Path:** Hand-copied gate facts, implicit vanilla availability, ordinary global helper writes, broad distribution handlers, and directory-only deployment classification.

**Acceptance Proof:** All Acceptance Criteria and Proof Oracle commands pass from a clean checkout and isolated Codex home with no vanilla or unrelated user-skill mutations.

**Stop Criteria:** Stop on unstable public route IDs, unobservable dependency identity, ambiguous runtime reads that cannot select strict gates, user-owned helper deletion risk, or failed validation.

**Avoid:** Do not edit plugin caches, vendor vanilla, create a second graph authority, keep permissive compatibility paths, or delete receipt-bound historical artifacts.
