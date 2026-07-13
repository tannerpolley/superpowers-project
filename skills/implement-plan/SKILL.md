---
name: implement-plan
description: Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof.
---

# Implement Plan

Execute one approved plan on a development branch without creating issue mirrors. The route ends at verified local-branch handoff to `$superpowers-project:merge-changes`.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, `goals`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Require `subagents` only when Worker topology is selected. Stop before setup when a required capability is absent.

## Required Superpowers Pairings

Use `superpowers:executing-plans` as the base. Use `superpowers:test-driven-development` for feature and bug work unless the approved plan records an explicit opt-out. Use `superpowers:systematic-debugging` for failures or unclear behavior. Use `superpowers:verification-before-completion` before success or merge readiness and `superpowers:finishing-a-development-branch` for integration handoff. Worker topology additionally requires `superpowers:subagent-driven-development`; these pairings are mandatory, not suggestions.

## Shared Policy

Read `skills/advanced-user-input/SKILL.md` for global continuation and artifact review. This route keeps route-specific setup, topology, push, and handoff decisions local. Read labels from `docs/superpowers/workflow-contract.yml`.

## Workspace Isolation

Before editing, call `scripts/workspace-isolation.sh` with the lifecycle requirement and observed capabilities. Treat its result as an untrusted action decision: adopt or request `codex_managed_worktree`, or invoke `superpowers:using-git-worktrees` only for `local_git_worktree`. A shared subagent is delegation, not isolation. Local fallback is forbidden after native task creation. Record the provider observation as the existing `workspace_receipt`; detached native work may implement, but publication requires a fresh branch-bound receipt.

## Execution

1. Require an approved plan under `docs/superpowers/plans/` and run `./scripts/validate-plan-outcome-proof.sh`, `./scripts/validate-plan-task-use-cases.sh`, and `./scripts/validate-decision-ledger.sh -Kind plan`.
2. Start or reuse one immutable workflow run with `./scripts/workflow-run.sh`; record start, candidate selection, every mutation, acceptance, verification, and route completion.
3. Activate a native goal, choose Inline or Worker through `implement_plan_topology`, and satisfy the Workspace Isolation policy.
4. Implement each task with its proof oracle. Commit intentional checkpoints; do not create issue mirrors or claim issue closure.
5. Run the plan validations, repo suite, cleanup, and a structured readiness review covering plan alignment, correctness, maintainability, and reality evidence.
6. Prepare `local_branch_proof` for merge-changes. Local integration requires no push or PR proof. `remote_publication_proof` is separate and only required when the user explicitly selects a remote route.

## Stop Conditions And Closeout

Stop on invalid plan proof, missing goal/branch isolation, failed verification, scope drift, dirty unsafe state, or a decision outside Auto authorization. Show changed files, acceptance coverage, commands/results, readiness review, branch state, and workflow receipt. Use `project_implement_next_step`; `Stop` remains the intermediate terminal choice. This route cannot claim verified final `Done` before merge closeout.
