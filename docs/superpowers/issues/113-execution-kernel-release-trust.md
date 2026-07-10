# Make execution and release gates fail closed

**Pre-Publication:** false
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/113
**Source Artifact:** `docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md`
**Source Plan:** `docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md`
**Milestone:** M1
**Labels:** `type:bug`, `status:ready`
**Dependencies:** None
**Classification:** bug
**Sub-Issue Role:** leaf
**Executable:** true
**Goal Command:** `/goal Implement docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md completely, prove every acceptance criterion, and stop before merge for main-thread review.`

## Workflow Metadata

**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Branch Policy:** Create `codex/execution-kernel-release-trust` from current `main`; do not implement on `main`.
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Parallelize only isolated test or review work; keep production trust-kernel ownership in one implementation worker.
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Problem

Several mutation-adjacent launchers currently report success without receiving the evidence they claim to validate. Terminal closeout trusts boolean fields, local integration accepts an unbound premerge success object, and release readiness is derived inside the distribution handler instead of consuming a current trusted receipt. Autonomous workflows cannot safely rely on these gates until missing, stale, forged, incomplete, or mismatched evidence fails closed.

## Scope

Implement the complete source plan as one vertical trust-kernel repair. Preserve the public shell launcher paths while introducing canonical evidence envelopes, read-only collectors, focused gate validators, hash-bound receipts, receipt-consuming mutation boundaries, adversarial tests, installed-plugin proof, and release trust evidence.

The implementation must complete all seven plan tasks in order and use a RED, GREEN, refactor cycle for every production behavior change.

## Acceptance Criteria

- [ ] The existing PR-ready, premerge, merge-decision, closeout, and publish-ready public launchers preserve their paths and machine-readable output conventions.
- [ ] No-argument lifecycle validators exit nonzero with `error.code == "evidence_missing"`.
- [ ] Version-1 evidence envelopes bind repository identity, workflow run, candidate, authorization, source hashes, target identity, evidence payload hashes, prior event hash, and envelope hash.
- [ ] Duplicate JSON keys, unsupported versions, unknown trust-sensitive fields, invalid hashes, path traversal, symlink escape, unsupported collectors, and tampered payloads fail closed.
- [ ] Collectors observe Git, source artifacts, commands, reviews, provider state, authorization, package state, installation state, trials, and cleanup without mutating repository or provider state.
- [ ] PR-ready validation independently corroborates implementation verification, review disposition, source-plan conformance, cleanup, and target identity.
- [ ] Premerge validation independently corroborates PR identity, required checks, approval policy, base/head identity, review disposition, and current provider state.
- [ ] Merge-decision validation requires a current premerge receipt, matching authorization, a supported strategy, and unchanged target state.
- [ ] Local integration rejects bare `{"ok": true}` inputs and consumes an exact current merge-decision receipt before mutation.
- [ ] Closeout validation requires integration proof, final repository health, completion state, workspace disposition, and cleanup evidence bound to the same run and candidate.
- [ ] Release preparation consumes a current publish-ready receipt covering source cleanliness, runtime package, version consistency, provenance, validation, sync, installation, observed agent trials, revision classification, and cleanup.
- [ ] Legacy evidence returns `legacy_evidence_unsupported` and never receives a compatibility pass.
- [ ] Every gate rejects cross-repository, cross-run, cross-candidate, stale-source, stale-head, changed-target, tampered-chain, incomplete-command, forged-success, and provider-unavailable fixtures with the expected stable error and rule.
- [ ] A temporary-repository lifecycle proceeds through PR-ready, premerge, merge decision, and closeout, with receipt hashes and observed Git state matching independent inspection.
- [ ] Required-rule mutation tests have zero surviving mutations.
- [ ] The installed plugin trial proves one missing-evidence failure and one valid fixture pass using observed calls, mutations, package identity, envelope hashes, and receipt hashes rather than hardcoded counters.
- [ ] The milestone receipt records the acceptance matrix, negative results, positive lifecycle trace, installed-plugin trace, release receipt, cleanup proof, and exact source/package identities.
- [ ] Full repository validation, required route scenarios, release tests, live sync validation, supported plugin refresh, version freshness, cleanup, and final clean Git state pass.

## Proof Oracle

- `python3 -m unittest discover -s tests -p 'test_*.py'`
- `./skills/resolve-issue/scripts/test-scenarios.sh`
- `./skills/merge-changes/scripts/test-scenarios.sh`
- `./scripts/test-prepare-release.sh`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `codex plugin add superpowers-project@personal --json`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
- `git status --short --branch`

Expected proof: every command exits zero; the acceptance matrix has no uncovered rows; required-rule mutation survival is zero; lifecycle, installed-package, release, and Git identities agree; cleanup succeeds; and the implementation branch is clean before merge handoff.

## Non-Goals

- Change Auto or Looping Mode lifecycle semantics.
- Decide whether work should use a GitHub issue or direct implementation route.
- Implement Codex-native workspace selection or cleanup.
- Normalize the workflow graph or redesign plugin distribution beyond release receipt consumption.
- Add a replacement public command surface.
- Certify or translate legacy permissive receipts into version-1 proof.
- Replace GitHub, Git, or Codex with an internal execution service.
- Edit deployed plugin copies or plugin cache files directly.

## Outcome Summary

**Outcome Source:** `docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md#outcome-proof`
**Intent:** Make autonomous implementation, integration, closeout, and release decisions depend on evidence bound to current repository and provider reality.
**Target Output:** A focused execution trust kernel with canonical envelopes, read-only collectors, five fail-closed gates, hash-bound receipts, receipt-consuming integration and release paths, adversarial proof, and an auditable milestone receipt.
**Owner:** The implementation worker owns the isolated branch; `scripts/lib/evidence_schema.py` owns envelope identity, gate modules own rule requirements, `scripts/lib/gate_receipts.py` owns receipt serialization, and the main-thread orchestrator owns review and merge.
**Interface:** Existing public shell launchers accept exactly one evidence envelope input, focused Python validators return a `GateReceipt` or stable `EvidenceError`, and mutation commands consume the exact current receipt hash.
**Cutover:** Add test-first trust primitives, move public handlers behind focused adapters, require receipts at integration boundaries, then switch release preparation to consume publish-ready proof.
**Replaced Path:** No-argument success, self-validating collection, bare success booleans, permissive legacy receipts, and independently inferred publish readiness are removed without compatibility passes.
**Acceptance Proof:** The proof oracle passes from a clean checkout, every negative matrix row fails at its expected rule, the positive lifecycle agrees with independent Git inspection, installed/source identities agree, and mutation survival is zero.
**Stop Criteria:** Stop before implementation or merge if the source plan is unavailable, a gate can pass without evidence, a collector mutates state, a receipt can be replayed after bound state changes, provider unavailability passes, installed behavior differs from source, or any proof-oracle command fails.
**Avoid:** Do not broaden into Auto/Looping routing, issue-selection policy, Codex workspace implementation, workflow graph normalization, direct deployed-copy edits, legacy receipt certification, or a new workflow service.
