---
name: resolve-issue
description: Use when one ready GitHub issue mirror under docs/superpowers/issues must be implemented directly in the current thread through native goal activation, Superpowers execution, pushed branch, opened PR, and PR-ready handoff.
---

# Project Resolve

Directly implement one ready executable leaf issue in the current thread and produce verified PR-ready evidence for merge-changes.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, `github`, `goals`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before preflight when a capability is absent.

## Required Superpowers Pairings

Use `superpowers:executing-plans`; use `superpowers:using-git-worktrees` only when the workspace provider selects local fallback. Require `superpowers:test-driven-development` unless the approved source plan records an explicit opt-out. Use `superpowers:systematic-debugging` for failures and unclear behavior. Require `superpowers:verification-before-completion` before PR-ready claims and `superpowers:finishing-a-development-branch` before PR creation.

## Shared Policy

Follow `skills/advanced-user-input/SKILL.md` for global continuation and artifact review. This route owns route-specific issue setup, goal, push, PR-ready, and handoff gates only. Canonical labels live in `docs/superpowers/workflow-contract.yml`.

## Preconditions

Require `docs/superpowers/issues/<number>-<slug>.md` with `Sub-Issue Role: leaf`, `Executable: true`, issue URL, source plan, Outcome Summary, acceptance criteria, and proof oracle. Run `skills/resolve-issue/scripts/preflight.sh`, `./scripts/validate-plan-outcome-proof.sh`, and `./scripts/validate-plan-task-use-cases.sh`. Parent, wrapper, `Source Plan: TBD`, and malformed mirrors are blocking.

## Workspace Isolation

Before editing, call `scripts/workspace-isolation.sh` with required isolation and observed capabilities. Treat its result as an untrusted action decision: adopt or request `codex_managed_worktree`, or invoke `superpowers:using-git-worktrees` only for `local_git_worktree`. A shared subagent is delegation, not isolation. Local fallback is forbidden after native task creation. Record the provider observation as the existing `workspace_receipt`; detached native work may implement, but `project_resolve_push_permission` requires a fresh branch-bound receipt.

## Execution

1. Inspect setup with `prepare-execution.sh`, activate the native goal, satisfy Workspace Isolation, and validate setup with `validate-setup.sh`.
2. Start or reuse the immutable `scripts/workflow-run.sh` run and record selection/mutations.
3. Execute each plan task with TDD/debug discipline and commit scoped checkpoints.
4. Verify acceptance coverage, proof oracle, repo tests, cleanup, outcome-proof carry-forward, and readiness review.
5. Show full branch and verification evidence, then ask `project_resolve_push_permission`. Push/open PR only after explicit permission or valid preauthorization that includes remote publication.
6. Collect and validate the PR-ready ledger, then hand off to `$superpowers-project:merge-changes`.

## Evidence Gate Contract

Collection and validation are separate operations. `collect-pr-ready-ledger.sh` must receive a complete `CollectionRequestJson` or `CollectionRequestPath` and emits a version-1 repository-bound evidence envelope only when `OutputPath` is explicit. `validate-pr-ready.sh` requires exactly one `EvidenceEnvelopeJson` or `EvidenceEnvelopePath`; it returns a hash-bound `pr_ready` receipt or a structured nonzero error. Missing evidence is `evidence_missing`, and legacy ledgers or bare `ok: true` objects are `legacy_evidence_unsupported` rather than compatibility passes.

Resolve terminal closeout is final lifecycle closeout: it consumes the current `merge_decision` receipt after integration, a matching closeout envelope, and an explicit terminal decision. PR-ready proof is handed to merge-changes as the immediately preceding input to premerge; no route skips or splices the authenticated receipt chain.

## Stop Conditions And Closeout

Stop on invalid setup, non-leaf issue, missing goal, failed proof, scope drift, missing push authority, CI failure, or stale PR evidence. Record the graph-owned continuation decision. `Stop` requires terminal closeout validation; PR readiness is not verified final `Done`.
