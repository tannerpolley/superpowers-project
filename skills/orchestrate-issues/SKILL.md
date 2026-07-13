---
name: orchestrate-issues
description: Use when a ready Superpowers Project issue should be delegated to a Codex worktree worker thread while the current thread acts as orchestrator and reviewer.
---

# Project Orchestrate

Delegate one executable leaf issue while the current thread remains reviewer and integration owner. Workers never merge their own work.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, `subagents`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Require `github` for issue/PR evidence. Stop before worker creation when any required capability is absent.

## Required Superpowers Pairings

The orchestrator uses `superpowers:subagent-driven-development`. Every handoff requires `superpowers:test-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`, plus `superpowers:executing-plans` or the delegated method. Require `superpowers:using-git-worktrees` only for local fallback.

## Shared Policy

Use `skills/advanced-user-input/SKILL.md` for global continuation and artifact review. This route keeps route-specific worker identity, packet, review, and integration gates local. Read question labels from `docs/superpowers/workflow-contract.yml`.

## Workspace Isolation

Before worker creation, call `scripts/workspace-isolation.sh`. Adopt or request `codex_managed_worktree`; invoke vanilla worktree creation only for `local_git_worktree`. A shared subagent is delegation, not isolation, and its identity cannot replace `workspace_receipt` evidence. Local fallback is forbidden after native task creation. Bind the receipt to the handoff, and require a fresh branch-bound receipt before publication.

## Procedure

1. Require a ready mirror with `Sub-Issue Role: leaf`, `Executable: true`, a valid source plan, acceptance criteria, and proof oracle.
2. Run `skills/orchestrate-issues/scripts/derive-worker-identity.sh` and `prepare-worker-handoff.sh`.
3. Validate the handoff with `validate-worker-handoff.sh` and the examples contract in `docs/superpowers/examples/worker-handoff-packets.md`.
4. Satisfy Workspace Isolation, then create the worker and send the immutable packet. Record workflow selection and mutations.
5. Review the worker's diff, task evidence, tests, branch state, and PR-ready packet independently. Reject narrative that disagrees with repository evidence.
6. Route accepted work to `$superpowers-project:merge-changes`; the main thread owns approval and merge.

## Stop Conditions And Closeout

Stop on a rollup issue, missing plan/proof oracle, identity collision, unsafe topology, incomplete handoff, worker scope drift, failed verification, or absent reviewer capacity. Show the worker identity, packet, changed artifacts, verification, and next owner. Use graph-owned orchestration routes; `Stop` is intermediate and this skill never claims verified final `Done`.
