---
name: implement-plan
description: Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof.
---

# Implement Plan

Implement Plan is the non-issue execution route for an approved plan under `docs/superpowers/plans`. It does not create issue mirrors and must not claim GitHub issue closure.

**Announce at start:** "I'm using the implement-plan skill to execute this approved plan without creating a GitHub issue."

## Required Inputs

Require an approved plan path under `docs/superpowers/plans`. If the request names a loose idea, spec, issue mirror, or external document instead of an approved plan, route to `$project:write-plan` or `$project:create-issues` as appropriate before execution.

Require native `/goal` activation before code changes. The goal must name the approved plan path and the intended execution route. Record proof as structured evidence, not a prose claim.

## Non-Issue Boundary

This route is for branch-backed plan implementation without a GitHub issue. Do not create issue mirrors, do not hydrate GitHub issues, and do not claim issue closure in commits, PR text, ledgers, or handoffs.

Use the issue-backed `$project:create-issues` and `$project:resolve-issue` route when the work should close a GitHub issue, needs tracker ownership, or should be split into multiple issue mirrors.

## Execution Gate

Before edits, create or switch to a development branch. Never implement this route directly on `main`.

When `request_user_input` is callable, ask native execution topology before starting implementation:

Question id: `implement_plan_topology`

Prompt: `How should this approved plan be implemented?`

Options:

- `Inline`: implement in this thread on a development branch.
- `Worker`: delegate to a worker thread with an explicit plan handoff and reporting path.
- `Stop`: stop without edits.

Only use worker mode when the worker handoff names the orchestrator, role, plan path, branch, reporting path, and reason the worker may ask for `request_agent_input`. Otherwise fail loudly and use inline execution only after native approval.

## Implementation Discipline

Use `superpowers:test-driven-development` for feature and bug work unless the approved plan explicitly opted out. Use `superpowers:executing-plans` to execute the plan task-by-task, and use `superpowers:verification-before-completion` before any success claim, commit, push, or PR.

Follow the approved plan's proof oracle. If a task needs a decision that the plan did not make, ask through native UI when callable and stop until the decision is answered. Do not invent broad policy during implementation.

## Publish Permission Gate

After focused verification and cleanup evidence exist, ask native publish permission before pushing, preparing local merge-ready output, or holding the branch:

Question id: `implement_plan_publish_permission`

Prompt: `How should I publish this implemented plan?`

Options:

- `Push`: push the development branch and prepare a pull request.
- `Local Merge Ready`: keep the development branch local and produce merge-ready evidence.
- `Hold`: stop with the branch preserved.

Only `Push` records `selected_action: push`. Only `Local Merge Ready` records `selected_action: local-merge-ready`. Only `Hold` records `selected_action: hold`.

## Merge-Ready Output

Produce a merge-ready handoff that includes:

- approved plan path
- branch name and commit list
- verification commands and results
- cleanup hook result
- publish permission ledger
- PR URL when pushed
- explicit statement that no issue mirror was created and no GitHub issue closure is claimed

Route merge-ready output to `$project:merge-changes` or another approved merge route. Use non-issue merge mode such as `pr-no-issue` for PRs that came from this route.

## Contract Helper

Use `skills/implement-plan/scripts/lib/contract.ps1` to validate structured handoff ledgers in tests or worker closeout automation. The helper requires the approved plan, native `/goal` activation, a development branch, topology selection, passed verification, native publish permission, merge-ready evidence, and no issue closure claim.

