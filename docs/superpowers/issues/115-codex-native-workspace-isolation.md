# Add Codex-Native Workspace Isolation

**Pre-Publication:** false
**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/115
**Source Artifact:** `docs/superpowers/specs/2026-07-10-codex-native-workspace-isolation-design.md`
**Source Plan:** `docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md`
**Milestone:** M1
**Labels:** `type:feature`, `status:ready`
**Dependencies:** Blocked by the execution-kernel and Auto/Loop lifecycle issues. Rebase onto current `main` after both merge; register workspace evidence through the kernel and bind it to lifecycle identity.
**Hierarchy Mode:** flat
**Sub-Issue Role:** leaf
**Executable:** true
**Parent Issue:** none
**Parent Mirror:** none
**Child Issues:** none
**Rollup Policy:** This leaf owns the complete user-visible workspace-isolation outcome.
**Title Policy:** Clean capability title without hierarchy or milestone markers.
**Goal Command:** `/goal Implement Codex-native workspace isolation from docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md, prove both native and local provider paths, and return merge-ready evidence.`

## Workflow Metadata

**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Execute after the kernel and lifecycle issues; within this issue, the provider kernel, owner-route migration, and lifecycle trials remain serially consistent.
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Follow the validated provider receipt: app-owned worktrees receive logical disposition, user-owned worktrees remain untouched, and only the exact plugin-owned local worktree may be removed after merge.
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Scope

Implement the three lean tasks in the revised source plan:

- add one small provider-selection policy and mutation-free launcher;
- strengthen the existing issue #113 `workspace_receipt` rule for provider, branch, and ownership semantics;
- update owner skills to prefer/adopt native Codex worktrees, use vanilla local fallback only when appropriate, and enforce provider-owned publication and cleanup.

The shell adapter returns an untrusted action decision. The active Codex agent performs native task operations and records cooperative provider observations through the existing evidence kernel. Codex exposes no signed task receipt, so this issue does not claim host cryptographic attestation.

## Acceptance Criteria

- Required or preferred isolation in Codex desktop adopts or requests a project-bound `codex_managed_worktree` before considering local fallback.
- A matching current Codex worktree is adopted without creating a duplicate workspace.
- A `shared_subagent` is classified as delegation and cannot produce or satisfy an isolated-workspace receipt.
- Terminal-only environments retain safe `local_git_worktree` fallback through the unmodified `superpowers:using-git-worktrees` skill.
- The existing `workspace_receipt` is schema-versioned, canonically hashed, and bound to repository identity, workflow run, candidate, workspace, Git common directory, and observed head.
- Native isolation creates no repository-local `.worktrees` directory and does not invoke vanilla worktree creation.
- Detached HEAD is accepted for implementation and validation, while push and pull-request actions fail until a matching branch-bound provider transition exists.
- Native fallback to a local worktree is forbidden after a native task has been created.
- Worker handoffs and kernel gates reject missing, stale, shared-subagent, repository-mismatched, run-mismatched, candidate-mismatched, and head-mismatched workspace evidence.
- Workspace receipts never authorize filesystem deletion; app/user workspaces are preserved and plugin-owned local cleanup remains governed by independent vanilla worktree provenance.
- Focused policy and scenario tests prove native adoption/request behavior, detached publication rejection, vanilla fallback, and exact cleanup ownership without committing generated trial runs.
- All focused unit tests, owner-skill scenario tests, worker packet tests, workspace-isolation trial tests, and `./scripts/validate.sh` pass.
- The required post-revision validation, commit, sync, marketplace refresh, version check, cleanup, and clean-status sequence completes before final release claims.

## Proof Oracle

- `python3 -m unittest tests.test_workspace_isolation tests.test_gate_pr_ready tests.test_gate_premerge tests.test_gate_closeout tests.test_command_registry tests.test_command_surface -v`
- `./skills/implement-plan/scripts/test-scenarios.sh`
- `./skills/resolve-issue/scripts/test-scenarios.sh`
- `./skills/orchestrate-issues/scripts/test-scenarios.sh`
- `./skills/merge-changes/scripts/test-scenarios.sh`
- `./scripts/test-worker-packets.sh`
- `./scripts/validate-plan-outcome-proof.sh -PlanPath docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md`
- `./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md`
- `./scripts/validate-decision-ledger.sh -Path docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md -Kind plan`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `codex plugin add superpowers-project@personal --json`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
- `git status --short --branch`

## Non-Goals

- Do not edit, fork, shadow, or deploy a modified vanilla `superpowers:using-git-worktrees` skill.
- Do not redesign Codex app worktree internals or manipulate app-managed metadata with Git commands.
- Do not require isolation for every implementation when the approved requirement is `none`.
- Do not treat collaboration subagents, agent names, branch names, or narrative summaries as filesystem-isolation proof.
- Do not create both native and local worktrees for one candidate.
- Do not support arbitrary external IDE worktree providers in this release.
- Do not redesign Auto/Loop authorization, release evidence gates, workflow graph normalization, or distribution architecture.
- Do not auto-archive completed Codex tasks; record logical disposition and leave app lifecycle state to explicit policy.
- Do not publish this mirror until separate GitHub publication approval exists.

## Outcome Summary

**Outcome Source:** `docs/superpowers/specs/2026-07-10-codex-native-workspace-isolation-design.md` and `docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md`

**Intent:** Make coding-agent isolation use visible, app-managed Codex project worktrees when available while retaining safe terminal-only local Git worktrees and preventing same-checkout delegation from being mislabeled as isolation.

**Target Output:** One provider policy and launcher, stronger existing workspace-receipt rules, concise owner-skill routing, and focused native/local behavior tests.

**Owner:** Superpowers Project workspace-isolation runtime and its implementation, orchestration, issue-resolution, and merge route owners.

**Interface:** `resolve_workspace_isolation` plus the existing registered `workspace_receipt`, `EvidenceEnvelope`, and gate-receipt chain.

**Cutover:** All new implementation, worker-handoff, publication, and cleanup evidence switches from prose worktree policy and skill-name membership to validated provider receipts and transitions in the same source revision.

**Replaced Path:** Branch labels, worker names, `required_skills` entries, and `branch_worktree_policy` remain descriptive only and cannot establish isolation or authorize cleanup.

**Acceptance Proof:** Focused unit/gate tests, four owner-skill scenario suites, worker packet validation, full repository validation, independent review, CI, and clean post-revision deployment receipts.

**Stop Criteria:** Stop before mutation or publication when project identity, provider capability, separate-checkout evidence, repository/run/candidate binding, native operation output, branch transition, or cleanup ownership cannot be proven; after native task creation, retain and report that app-owned task instead of creating a local fallback.

**Avoid:** Avoid editing vanilla skills, fabricating native observations, leaking real task IDs or absolute paths into committed evidence, broad `git worktree prune`, app metadata deletion, duplicate workspaces, or remote publication without its separate approval.
