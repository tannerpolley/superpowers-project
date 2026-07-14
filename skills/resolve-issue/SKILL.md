---
name: resolve-issue
description: Use when one ready executable GitHub issue mirror must be implemented directly and handed off with PR-ready evidence.
---

# Project Resolve

Implement one executable leaf issue in the current thread and hand verified PR-ready evidence to merge-changes.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `git`, `github`, `goals`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before preflight when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates.

Use `superpowers:executing-plans`; use `superpowers:using-git-worktrees` only for local fallback. Require `superpowers:test-driven-development` unless the source plan opts out, `superpowers:systematic-debugging` for failures, `superpowers:verification-before-completion` before PR-ready claims, and `superpowers:finishing-a-development-branch` before PR creation.

## Preconditions And Execution

1. Require `docs/superpowers/issues/<number>-<slug>.md` with leaf/executable state, issue URL, source plan, Outcome Summary, acceptance criteria, and proof oracle. Run `skills/resolve-issue/scripts/preflight.sh -IssueMirrorPath <mirror>`, `./scripts/validate-plan-outcome-proof.sh -PlanPath <source-plan>`, and `./scripts/validate-plan-task-use-cases.sh -PlanPath <source-plan>`. Parent, wrapper, `Source Plan: TBD`, or malformed mirrors block.
2. Call `scripts/workspace-isolation.sh` with request and capability evidence. Adopt or request `codex_managed_worktree`; use `superpowers:using-git-worktrees` only for `local_git_worktree`. Shared subagents do not prove isolation, and native task creation forbids later local fallback. Publication needs a fresh branch-bound `workspace_receipt`.
3. Run `skills/resolve-issue/scripts/prepare-execution.sh`, activate the goal, and validate its setup ledger with `skills/resolve-issue/scripts/validate-setup.sh -SetupLedgerPath <ledger>`.
4. Start or reuse the immutable workflow run; record selection and mutations. Execute plan tasks with scoped commits.
5. Verify acceptance, proof oracle, tests, cleanup, outcome proof, and readiness review.
6. Resolve `project_resolve_push_permission`; push and open a PR only with explicit permission or matching publication preauthorization.

## Evidence And Closeout

`skills/resolve-issue/scripts/collect-pr-ready-ledger.sh` requires one complete `CollectionRequestJson|Path` and persists its repository-bound envelope only when `OutputPath` is set. `skills/resolve-issue/scripts/validate-pr-ready.sh` accepts one `EvidenceEnvelopeJson|Path` and returns a bound `pr_ready` receipt or structured failure; missing evidence and legacy objects fail closed. Hand that receipt to merge-changes without skipping the authenticated chain.

After integration, `skills/resolve-issue/scripts/validate-terminal-closeout.sh` consumes the current `merge_decision` receipt, matching closeout envelope, and explicit terminal decision.

Stop on invalid setup, non-leaf work, missing goal, failed proof, scope drift, missing publication authority, CI failure, or stale evidence. Record the graph continuation decision. `Stop` requires terminal closeout; PR readiness is not verified final `Done`.
