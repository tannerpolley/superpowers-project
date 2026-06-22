# Add Decision Ledger Requirements

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/67
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:blocked, type:task
**Goal Command:** /goal Require Decision Ledger sections for brainstorm and planning artifacts and validate their required fields.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Make grilling and planning decisions durable and auditable.
**Target Output:** Specs and plans include Decision Ledger sections that record decision source, answer, impact, deferred state, and risk owner.
**Owner:** `skills/brainstorm-spec/SKILL.md` and `skills/write-plan/SKILL.md` own the artifact output requirements.
**Interface:** A validator reads Markdown Decision Ledger tables and checks required columns and concrete deferred-risk ownership.
**Cutover:** Decision proof moves from conversational memory into canonical spec and plan artifacts.
**Replaced Path:** Unstructured "questions were asked" claims stop being sufficient planning evidence.
**Acceptance Proof:** Decision-ledger validator tests and repo validation pass.
**Stop Criteria:** Stop before merge if a ready spec or plan can omit the Decision Ledger or defer a decision without a risk owner.
**Avoid:** Do not require issue mirrors to repeat every upstream decision when the source plan link already carries the ledger.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Add Decision Ledger requirements to brainstorm and planning skills, plus validator coverage for required fields.

## Acceptance Criteria

- [ ] `brainstorm-spec` output contract requires `## Decision Ledger`.
- [ ] `write-plan` output contract requires or carries forward `## Decision Ledger`.
- [ ] Validator checks `Decision`, `Source`, `Answer`, `Impact`, `Deferred?`, and `Risk owner`.
- [ ] Deferred decisions require concrete risk owners and downstream impact.
- [ ] Decision-ledger tests pass.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/63

## Non-goals

- Do not change issue execution routing in this issue.
- Do not weaken planning grill requirements.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-decision-ledger.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-decision-ledger.ps1 -Path .\docs\superpowers\plans\2026-06-21-m0-m1-workflow-contract-normalization-plan.md -Kind plan`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## GitHub Body

Require durable Decision Ledger sections in brainstorm and planning artifacts so repo-aware grilling decisions survive handoff and merge closeout.
