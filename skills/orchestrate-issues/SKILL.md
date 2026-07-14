---
name: orchestrate-issues
description: Use when a ready executable issue should be delegated to an isolated Codex worker while the current thread reviews and integrates.
---

# Project Orchestrate

Delegate one leaf issue. The current thread reviews and merges; workers never merge.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, `subagents`, and `native.user-input` from `docs/superpowers/capabilities.yml`; add `github` for issue or PR evidence. Stop before worker creation when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates.

Use `superpowers:subagent-driven-development`, `superpowers:executing-plans`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`. Follow the repository verification policy; include `superpowers:test-driven-development` in a worker handoff only when that policy selects TDD. Use `superpowers:using-git-worktrees` only for local fallback.

## Handoff And Review

1. Require a mirror with `Sub-Issue Role: leaf`, `Executable: true`, valid source plan, acceptance criteria, and proof oracle.
2. Call `scripts/workspace-isolation.sh` with `RequestJson|Path` and `CapabilitiesJson|Path`. Adopt or request `codex_managed_worktree`; use local worktrees only for `local_git_worktree`. Shared subagents do not prove isolation, and native task creation forbids later local fallback. Bind `workspace_receipt` to the handoff and refresh it before publication.
3. Run `skills/orchestrate-issues/scripts/derive-worker-identity.sh -IssueFile <mirror>`.
4. Run `skills/orchestrate-issues/scripts/prepare-worker-handoff.sh` with `-IssueFile`, workspace receipt, workflow run ID, candidate ID, and output path; run `skills/orchestrate-issues/scripts/validate-worker-handoff.sh -HandoffPath <handoff>` and compare `docs/superpowers/examples/worker-handoff-packets.md`.
5. Send the immutable packet and record workflow selection and mutations.
6. Review the diff, task evidence, tests, branch, and PR-ready packet against repository evidence. Send accepted work to `$superpowers-project:merge-changes`.

## Closeout

Stop on rollup issues, missing plan or oracle, identity collision, unsafe topology, invalid handoff, scope drift, failed verification, or absent reviewer capacity. Show identity, packet, artifacts, verification, and next owner through `project_orchestrate_next_step`. Retain `Stop`; this route has no verified final `Done`.
