# Add Loop Controller verifier terminal closeout and metrics contracts

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/55
**GitHub Milestone:** M0 - Governance
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md
**Source Plan:** docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/55-loop-controller-verifier-terminal-closeout-and-metrics-contracts.md using docs/superpowers/plans/2026-06-15-auto-mode-loop-controller-plan.md Tasks 5 and 6 after https://github.com/tannerpolley/superpowers-project/issues/54 is complete.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add verifier ledger validation, terminal closeout validation, metrics report generation, and a local end-to-end contract fixture covering the Loop Controller evidence chain.

## Acceptance Criteria

- [ ] Verifier ledger validation enforces high-risk independent proof and low-risk script-backed proof.
- [ ] Terminal closeout rejects missing run ledger, verifier, metrics, clean-state, and terminal-decision proof.
- [ ] Terminal closeout distinguishes paused Stop from verified final Done.
- [ ] Metrics report records elapsed time, attempts, validation failures, retry count, human input count, mutation counts, final outcome, and accepted-change evidence.
- [ ] Local end-to-end scenario covers run ledger, budget, candidate selection, verifier proof, terminal closeout, and metrics.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/54

## Non-goals

- Do not add real scheduled automations.
- Do not claim token, billing, or cost metrics unless runtime data is explicitly available.
- Do not sync live or merge without the owning approval gates.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`

