---
name: implement-plan
description: Use when an approved plan should be implemented on a development branch without creating a GitHub issue.
---

# Implement Plan

Execute one approved plan and hand verified local-branch proof to `$superpowers-project:merge-changes`.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, `goals`, and `native.user-input` from `docs/superpowers/capabilities.yml`; add `subagents` for Worker topology. Stop before setup when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates.

Use `superpowers:executing-plans`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`. Use `superpowers:systematic-debugging` for failures and `superpowers:subagent-driven-development` for Worker topology. A plan may record an explicit TDD opt-out.

## Execution

1. Require a plan under `docs/superpowers/plans/`; run `./scripts/validate-plan-outcome-proof.sh -PlanPath <plan>`, `./scripts/validate-plan-task-use-cases.sh -PlanPath <plan>`, and `./scripts/validate-decision-ledger.sh -Path <plan> -Kind plan`.
2. Start or reuse one immutable run with `./scripts/workflow-run.sh`; record selection, mutations, acceptance, verification, and completion.
3. Activate a goal and resolve `implement_plan_topology`.
4. Before editing, call `scripts/workspace-isolation.sh` with request and capability JSON. Adopt or request `codex_managed_worktree`; use `superpowers:using-git-worktrees` only for `local_git_worktree`. Shared subagents do not prove isolation, and native task creation forbids later local fallback. Record `workspace_receipt`; detached work needs a fresh branch-bound receipt before publication.
5. Implement plan tasks with their proof oracles and scoped commits. Do not create issue mirrors.
6. Run plan and repository validation, cleanup, and readiness review for plan alignment, correctness, maintainability, and reality evidence.

Prepare the branch, validation, and readiness evidence required by merge-changes. Resolve `implement_plan_push_permission` before any remote publication; local integration needs no push or PR proof.

## Closeout

Stop on invalid plan proof, missing goal or isolation, failed verification, scope drift, dirty unsafe state, or decisions outside authorization. Show files, acceptance coverage, commands, review, branch state, and workflow receipt through `project_implement_next_step`. Retain `Stop`; verified final `Done` requires merge closeout.
