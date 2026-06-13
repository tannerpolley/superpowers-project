# Integrate Companion Reporting With Planning Workflows

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/47
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-12-superpowers-html-companion-interface-design.md
**Source Plan:** docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/47-companion-planning-workflow-integration.md using docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md Tasks 5 and 6 after the companion renderer issues are complete.
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

Add opt-in companion reporting guidance to `brainstorm-spec` and `write-plan`, extend metadata and validation so the companion can be used for rich design and planning artifacts, then prove full validation, live-sync validation, and cleanup readiness.

## Acceptance Criteria

- [ ] `skills/brainstorm-spec/SKILL.md` includes companion-interface opt-in guidance for large design artifacts and saved spec previews.
- [ ] `skills/brainstorm-spec/agents/openai.yaml` mentions opt-in companion reporting.
- [ ] `skills/write-plan/SKILL.md` includes companion-interface opt-in guidance for long implementation plans, task use cases, proof oracles, and validation receipts.
- [ ] `skills/write-plan/agents/openai.yaml` mentions opt-in companion reporting.
- [ ] Companion reporting guidance explicitly keeps native continuation, issue creation, implementation, push, publish, merge, and final Done decisions in chat or `request_user_input`.
- [ ] `scripts/test-companion-interface.ps1` asserts the opt-in integration text and metadata are present.
- [ ] `brainstorm-spec`, `write-plan`, companion tests, full repo validation, and live-sync validation pass.
- [ ] Cleanup proof reports no leftover repo-owned companion processes.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/46

## Non-goals

- Do not integrate the companion into every governed skill in this slice.
- Do not add GitHub issue publication behavior.
- Do not allow the companion report to record approvals.
- Do not remove the existing chat artifact review gate before companion reporting is proven stable.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
