# Add Worker Handoff And PR-Ready Packets

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/70
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Add sample worker handoff and PR-ready packets with validation for orchestrated issue work.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Make delegated issue execution predictable and reviewable.
**Target Output:** Worker handoff and PR-ready packet examples include source plan, issue mirror, branch, validation, proof oracle, and merge handoff fields.
**Owner:** `skills/orchestrate-issues/SKILL.md` and `docs/superpowers/examples/worker-handoff-packets.md` own worker packet guidance.
**Interface:** Worker handoff validators read packet fields and scenario fixtures before orchestration uses them.
**Cutover:** Orchestrated worker handoffs use packet examples instead of free-form handoff summaries.
**Replaced Path:** Incomplete worker handoffs stop being acceptable orchestration evidence.
**Acceptance Proof:** Worker packet tests, orchestrate scenario tests, and repo validation pass.
**Stop Criteria:** Stop before merge if packet validation allows missing source plan, issue mirror, branch, validation, or merge handoff fields.
**Avoid:** Do not let worker threads merge or close issues directly.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add worker handoff and PR-ready packet examples, extend validation, and reference packets from `orchestrate-issues`.

## Acceptance Criteria

- [ ] Worker handoff packet includes source plan, issue mirror, goal, branch/worktree policy, proof oracle, validation, and reviewer role.
- [ ] PR-ready packet includes branch, diff scope, validation receipt, issue mirror, source plan, proof oracle, and merge route.
- [ ] Packet fixtures include passing and failing cases.
- [ ] `skills/orchestrate-issues/scripts/test-scenarios.ps1` passes.
- [ ] `scripts/test-worker-packets.ps1` passes.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/69

## Non-goals

- Do not change merge ownership.
- Do not require worker orchestration for every issue.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Add sample worker handoff and PR-ready packets so orchestrated issue execution has complete, validated handoff data.
