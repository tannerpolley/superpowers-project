# Bundle Advanced User Input With Flexible Native Prompt Policy

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/25
**GitHub Milestone:** M0 - Governance
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-03-project-implement-and-integration-workflow-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Bundle advanced-user-input into the plugin and update Superpowers Project native prompt policy using docs/superpowers/issues/bundle-advanced-user-input-flexible-native-prompts.md and docs/superpowers/plans/2026-06-03-project-namespace-and-implementation-expansion-plan.md.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Bundle `advanced-user-input` as an official plugin skill and replace the stale three-option limit with a flexible native prompt policy that supports large peer route menus, bulk independent gates, and sequential branching.

## Acceptance Criteria

- [ ] `skills/advanced-user-input/SKILL.md` exists in the plugin source tree and validates as a skill.
- [ ] The skill says to use as many native questions and options as the decision requires.
- [ ] The skill documents observed Codex Desktop permissive behavior and the fail-loud fallback if a runtime rejects a large prompt.
- [ ] Project workflow skills no longer say native prompts must have no more than three options.
- [ ] Repo validation includes a contract test preventing the old hard limit from returning.
- [ ] Live sync deploys the skill to the plugin and user-level skill locations according to the current repo policy.

## Blocked by

- None

## Non-goals

- Do not create a runtime `request_agent_input` tool.
- Do not remove native `Stop / Done` routes from formal continuation gates.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1`
- `py -3.12 .\scripts\quick-validate-skill.py .\skills\advanced-user-input`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
