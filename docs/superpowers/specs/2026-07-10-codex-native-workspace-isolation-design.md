# Codex-Native Workspace Isolation Design

## Status

Approved, revised after issues #113 and #114 landed.

## Problem

Superpowers Project currently says implementation should use a worktree, but it does not consistently distinguish three different things:

- a Codex project task backed by an app-managed worktree;
- a local Git worktree created through `superpowers:using-git-worktrees`;
- a collaboration subagent sharing its parent checkout.

Only the first two provide filesystem isolation. A shared subagent is delegation, not a workspace provider.

## Outcome

When isolation is preferred or required, owner skills:

1. adopt a matching current Codex worktree when already inside one;
2. otherwise request a Codex project worktree when a native task operation is available;
3. otherwise use the unchanged vanilla local-worktree skill;
4. fail closed when isolation is required and neither provider is available.

Once a native task has been created, the workflow may not create a local fallback for the same candidate.

## Provider Policy

| Provider | Separate checkout | Owner | Publication requirement | Cleanup |
|---|---:|---|---|---|
| `codex_managed_worktree` | yes | `codex_app` | named branch matching the current head | logical disposition only |
| `local_git_worktree` | yes | `plugin` or `user` | named branch matching the current head | vanilla finishing provenance only; user-owned is preserved |
| `current_checkout` | no | `user` | route-specific | never treated as isolation |
| `shared_subagent` | no | current task | not applicable | never treated as isolation |

Native selection suppresses vanilla worktree creation. Local fallback delegates directory choice and safety checks to `superpowers:using-git-worktrees`; this plugin does not impose a repository-local `.worktrees` directory.

## Existing Kernel Integration

Issue #113 already added the registered `workspace_receipt` evidence kind and the PR-ready, premerge, and closeout workspace rule. This issue extends that existing contract instead of creating `workspace_reality`, a second serializer, or workspace-specific gate receipts.

A version-1 workspace receipt contains the provider observation needed by the existing rule:

```yaml
schema_version: 1
provider: codex_managed_worktree | local_git_worktree
workspace_id: <provider workspace identity>
repository_root: <canonical repository root>
git_common_dir: <canonical Git common directory>
run_id: <workflow run>
candidate_id: <candidate>
task_id: <Codex task or null>
thread_id: <Codex task/thread or local marker>
observed_head: <40-character commit>
head_mode: branch | detached
branch: <name or null>
owner: codex_app | plugin | user
disposition: active | integrated | preserved
```

The execution kernel canonicalizes and hashes the evidence item, binds it to the repository/run/candidate envelope, and rechecks the current repository head. Publication additionally requires `head_mode: branch` and a branch matching the target branch. Detached native worktrees remain valid for editing and validation but cannot publish until a supported Codex branch or Handoff transition has occurred and a fresh receipt is recorded.

## Trust Boundary

Codex does not expose a signed host receipt for project-task creation. Native task identity and workspace fields are therefore cooperative provider observations supplied by the active local agent/app adapter. The kernel provides deterministic binding, freshness, ordering, and replay resistance; it does not claim cryptographic host attestation.

Caller-selected mode, candidate, repository, or head values cannot widen the lifecycle envelope. A mismatched or stale receipt fails the existing gate. This is sufficient for a cooperative local automation agent and honest about what the host can prove.

## Owner Routes

`implement-plan`, `resolve-issue`, and `orchestrate-issues` resolve provider policy before editing or delegation. They must state that:

- a collaboration subagent alone does not satisfy isolation;
- native worktree selection prevents invoking vanilla worktree creation;
- local fallback is allowed only before native task creation;
- detached native work is allowed, but publication requires a fresh branch-bound receipt.

`merge-changes` consumes the existing kernel receipt chain. It never deletes app-owned or user-owned workspaces. The receipt carries no deletion path and grants no physical-removal authority; plugin-owned local cleanup remains governed by the vanilla finishing skill's independently established worktree provenance.

## Non-Goals

- Implementing Codex task creation in shell code.
- Inspecting or modifying Codex app metadata.
- Editing or shadowing vanilla Superpowers.
- Adding another evidence collector, serializer, receipt type, or lifecycle controller.
- Treating a branch name, task label, subagent name, or prose summary as isolation proof.
- Committing native task IDs, private machine paths, or generated trial runs.

## Acceptance Criteria

- Native capability selects or adopts `codex_managed_worktree`; terminal-only capability selects `local_git_worktree`.
- `shared_subagent` cannot satisfy preferred or required isolation.
- A matching existing Codex worktree is adopted without requesting a duplicate.
- Local fallback is blocked after native task creation.
- The existing `workspace_receipt` kernel rule validates schema, provider, repository, run, candidate, task/thread, head, branch, and owner bindings.
- Detached native receipts pass execution policy but fail publication policy.
- Workspace receipts never authorize physical deletion; any plugin-owned local cleanup remains subject to independent vanilla worktree provenance.
- Owner skills use one provider policy and leave vanilla Superpowers unchanged.
- Focused tests, owner scenario tests, the full validator, and required deployment gates pass.

## Decision Ledger

| Decision | Answer | Reason |
|---|---|---|
| Evidence model | Extend `workspace_receipt` | #113 already owns hashing and gate receipts. |
| Native proof | Cooperative provider observation | Codex exposes no signed task receipt. |
| Native preference | Adopt, then fork/create | Avoid duplicate workspaces and preserve app visibility. |
| Local fallback | Vanilla skill only | Preserve existing terminal safety behavior. |
| Shared subagents | Delegation only | They share the parent checkout. |
| Detached HEAD | Editing allowed, publication blocked | Matches Codex worktree behavior without weakening Git publication safety. |
| Cleanup | Provider-owned | Prevent deletion of app/user state. |
