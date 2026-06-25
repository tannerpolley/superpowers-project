# Run Live-Sync Tracker And Align Drift Validation

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/72
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md
**Source Plan:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md
**Classification:** AFK
**Labels:** status:ready, type:task
**Goal Command:** /goal Run and record live-sync, tracker, and align drift proof after workflow normalization changes merge.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Outcome Summary

**Outcome Source:** docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md#outcome-proof
**Intent:** Prove the source repo, live install, tracker, issue mirrors, and align surfaces remain current after the repair program.
**Target Output:** Merge closeout has concrete receipts for repo validation, live sync validation, version freshness, tracker state, issue mirror state, and cleanup.
**Owner:** `merge-changes` owns final integration proof; `align-project` owns drift evidence when selected.
**Interface:** Validation commands and tracker checks produce receipts recorded in issue mirrors or merge closeout packets.
**Cutover:** Final repair confidence comes from script-backed receipts instead of prose review alone.
**Replaced Path:** Informal live-sync and tracker confidence stops being sufficient final proof.
**Acceptance Proof:** `scripts/validate.ps1`, `scripts/sync-live.ps1 -Validate`, version check, align/tracker proof, cleanup hook, and clean Git state all pass.
**Stop Criteria:** Stop before final Done if source/live, tracker, issue mirror, or cleanup proof is incomplete.
**Avoid:** Do not call the workflow complete with only local tests when plugin-surface changes need live-sync validation.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Run and record validation receipts after the preceding slices land, then route through merge closeout with clean proof.

## Validation Receipt

- `docs/superpowers/milestones/M1-workflow-normalization-validation-receipt.md`

## Acceptance Criteria

- [ ] `scripts/validate.ps1` passes.
- [ ] `scripts/sync-live.ps1 -Validate` passes.
- [ ] `scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent` reports source/live current.
- [ ] Tracker milestones and labels match project-roadmap config.
- [ ] Issue mirrors validate and milestone pages link current artifacts.
- [ ] Cleanup hook passes and Git state is clean before Done.

## Blocked by

- None

## Non-goals

- Do not create new feature behavior beyond validation and proof receipts.
- Do not mutate GitHub Projects unless a separate setup-project gate approves it.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`

## GitHub Body

Run and record source/live, tracker, align, validation, cleanup, and clean Git proof after the workflow normalization repair slices land.
