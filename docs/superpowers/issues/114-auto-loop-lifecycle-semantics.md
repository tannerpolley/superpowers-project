# Make Auto And Looping Complete Outcome Lifecycles

Pre-Publication: false

GitHub Issue: https://github.com/tannerpolley/superpowers-project/issues/114
Source Spec: docs/superpowers/specs/2026-07-10-auto-loop-lifecycle-semantics-design.md
Source Plan: docs/superpowers/plans/2026-07-10-auto-loop-lifecycle-semantics-plan.md
Milestone: M0 - Governance
Labels: type:bug, status:ready
Dependencies: Blocked by the execution-kernel issue. Rebase onto current `main` after that issue merges and reuse its `HashRef`, serializer, evidence, and receipt interfaces.
Sub-Issue Role: leaf
Executable: true
Goal Command: Implement and verify `docs/superpowers/plans/2026-07-10-auto-loop-lifecycle-semantics-plan.md` task by task.

**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Sequential plan tasks; no concurrent Git writers
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Summary

Replace the contradictory one-route Auto contract with one raw-request authority and a typed lifecycle across specification, planning, route selection, execution, verification, integration, and closeout. Make Looping repeat bounded candidate lifecycles without intra-candidate questions.

## Acceptance Criteria

- [ ] Raw requests enter Auto or Looping before a spec exists.
- [ ] Root authority is immutable and generated spec/plan hashes bind through append-only events.
- [ ] Auto records one startup native-input call and zero routine downstream calls.
- [ ] Manual Mode still renders every graph-owned material gate.
- [ ] Owner skills consume one lifecycle controller and gate-decision interface.
- [ ] Direct versus real issue-backed execution is selected by a recorded evidence rubric.
- [ ] Auto consumes merge authority after current fail-closed proof without asking bounded merge again.
- [ ] Looping supports multiple sequential candidates and stops on budgets, no-ready, health, repeated blocker, expiry, or interruption.
- [ ] Installed-plugin trials report observed tool/input/provider metrics instead of hardcoded counters.
- [ ] Full validation, required deployment gates, cleanup, and clean-main proof pass.

## Proof Oracle

- `python3 -m unittest tests.test_lifecycle_authorization tests.test_lifecycle_controller -v`
- `python3 -m unittest tests.test_gate_resolver tests.test_issue_route -v`
- `python3 -m unittest tests.test_loop_lifecycle tests.test_workflow_policy -v`
- `python3 -m unittest tests.test_auto_lifecycle_e2e tests.test_loop_lifecycle_e2e -v`
- `./skills/loop-controller/scripts/test-scenarios.sh`
- `./scripts/test-loop-controller.sh`
- `./scripts/run-agent-usability-trials.sh`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `codex plugin add superpowers-project@personal --json`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
- `git status --short --branch`

## Non-Goals

- Unlimited Auto permission or unrelated backlog draining.
- Weakening fail-closed validation.
- Selecting workspace providers.
- Modifying vanilla Superpowers.
- Silently accepting ambiguous historical ledgers.

## Branch Policy

Use `codex/issue-<number>-auto-loop-lifecycle-semantics`. Do not implement directly on `main`. The main thread owns review, PR, merge, and cleanup.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Outcome Summary

**Outcome Source:** `docs/superpowers/specs/2026-07-10-auto-loop-lifecycle-semantics-design.md` and `docs/superpowers/plans/2026-07-10-auto-loop-lifecycle-semantics-plan.md`

**Intent:** Make Auto and Looping behave as low-friction, bounded outcome workflows instead of repeated manual routes.

**Target Output:** Root authorization, lifecycle controller, artifact binding, shared gate resolver, issue rubric, merge consumption, finite Loop controller, and observed behavior trials.

**Owner:** Superpowers Project workflow and governance maintainer.

**Interface:** `create_root_authorization`, `bind_artifact`, `transition_lifecycle`, `resolve_gate`, `decide_issue_route`, and `evaluate_loop` behind stable workflow entrypoints.

**Cutover:** Land authority/state first, migrate owner gates second, enable issue/merge resolution third, complete Looping fourth, and remove obsolete prompt paths only after trials pass.

**Replaced Path:** Post-spec Auto re-entry, future-spec prerequisite, one-skill completion, per-route Auto questions, hardcoded direct-inline route, bounded-merge prompt, and intra-candidate Loop questions.

**Acceptance Proof:** Natural-language installed-plugin trials and adversarial unit fixtures prove exact question counts, artifact/event binding, provider-observed mutations, terminal reasons, and clean verified closeout.

**Stop Criteria:** Stop on invalid authority, no safe gate option, stale artifacts, out-of-envelope mutation, provider mismatch, exhausted loop policy, or failed final health.

**Avoid:** Do not infer unlimited permission, ask routine fallback questions, drain unrelated work, weaken proof, modify vanilla, or silently migrate old ledgers.
