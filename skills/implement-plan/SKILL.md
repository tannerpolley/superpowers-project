---
name: implement-plan
description: Use when an approved Superpowers Project plan should be implemented without creating a GitHub issue, using a native goal, development branch, verification, and merge-ready proof.
---

# Implement Plan

Implement Plan is the Superpowers Project adapter for `superpowers:executing-plans` on non-issue approved plans. Use it when an approved plan under `docs/superpowers/plans` should be executed without creating a GitHub issue. It does not create issue mirrors and must not claim GitHub issue closure.

**Announce at start:** "I'm using the implement-plan skill with superpowers:executing-plans to execute this approved plan without creating a GitHub issue."

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
## Required Inputs

Require an approved plan path under `docs/superpowers/plans`. If the request names a loose idea, spec, issue mirror, or external document instead of an approved plan, route to `$superpowers-project:write-plan` or `$superpowers-project:create-issues` as appropriate before execution.

Require native `/goal` activation before code changes. The goal must name the approved plan path and the intended execution route. Record proof as structured evidence, not a prose claim.

Require the approved plan's outcome proof before code changes. Restate the plan's `Intent`, `Owner`, `Interface`, `Cutover`, `Replaced Path`, `Acceptance Proof`, `Stop Criteria`, and `Avoid` before editing. Carry these fields as structured `outcome_proof` evidence in the implementation ledger.

## Task # Use Cases Gate

Task # Use Cases are a strict requirement before actual plan implementation. Before creating branches, activating worker handoffs, or editing code, run the repo-root validator against the approved plan:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <approved-plan-path>
```

Every numbered `Task N` in the approved plan MUST include a non-empty `**Use Cases:**` block with concrete user, system, acceptance, failure/recovery, validation, or workflow cases. If validation fails, stop before implementation and route back to `$superpowers-project:write-plan` with `Revise Plan`. Do not convert missing use cases into an implementation assumption, worker note, or deferred cleanup item.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization` before execution. Validate it with the plugin-provided Auto Mode validator from the loaded Superpowers Project plugin root (`<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `merge_permission.selected_mode: preauthorized-after-clean-premerge`, and `stop_outside_policy: true`.

Auto Mode may select inline execution, create or verify native goal proof, use the approved plan proof oracle, run verification, run the cleanup hook, and prepare merge-ready output without additional user input when those actions stay inside the ledger policy. Auto Mode must still record the topology, verification receipts, cleanup evidence, and merge-ready proof. If the plan needs a decision outside the recorded defaults policy, verification fails, the repo is dirty in an unsafe way, or merge-ready proof is missing, stop outside policy before code changes, publish, or merge handoff.

## Non-Issue Boundary

This route is for branch-backed plan implementation without a GitHub issue. Do not create issue mirrors, do not hydrate GitHub issues, do not open pull requests, and do not claim issue closure in commits, ledgers, or handoffs. Pull request routes are allowed only for issue-backed work with a companion issue mirror.

Use the issue-backed `$superpowers-project:create-issues` and `$superpowers-project:resolve-issue` route when the work should close a GitHub issue, needs tracker ownership, or should be split into multiple issue mirrors.

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

## Superpowers Method Contract

This skill is the Superpowers Project adapter for `superpowers:executing-plans` on non-issue approved plans. The method pairing is mandatory:

- Always use `superpowers:executing-plans` as the base implementation workflow.
- Require `superpowers:test-driven-development` for feature and bug work unless the approved plan records an explicit opt-out.
- Require `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, CI failures, performance work, or unclear failure modes.
- Require `superpowers:verification-before-completion` before any success claim, commit, or local merge.
- If worker topology is selected, require `superpowers:subagent-driven-development` for delegation and reporting discipline.

Do not treat these companion skills as optional suggestions. If a required companion skill cannot be applied, stop and report the blocker instead of silently continuing with ad hoc execution.

## Implementation Discipline

Follow the approved plan's proof oracle and outcome proof. If a task needs a decision that the plan did not make, or would change owner, interface, cutover, replaced path handling, acceptance proof, stop criteria, or avoid list, ask through native UI when callable and stop until the decision is answered. Do not invent broad policy during implementation.

Before push permission, merge-ready output, or local branch handoff, collect structured `readiness_review` evidence with:

- `plan_alignment: true`
- `correctness: true`
- `maintainability: true`
- `reality_evidence: true`

Missing or failed readiness review blocks merge-ready output even when tests pass.

## Push Permission Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before asking any route continuation or permission question, with this route-specific artifact inventory: full changed-artifact inventory, exact paths, changed sections or representative diffs/snippets, verification commands, exact test values/results, cleanup evidence, branch state, and any merge-ready drafts before asking whether to push. If a changed artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative diff or snippet, and why the full render is omitted. Do not ask for push approval first and explain later. After the Artifact Review Card and helper-owned findings summary are shown, ask native push permission before pushing the branch, preparing merge-ready output, or holding the branch.

Question id: `implement_plan_push_permission`

Prompt: `Should I push this implementation branch before merge routing?`

Options:

- `Push Branch`: push the development branch and continue toward merge-ready evidence.
- `Hold`: stop with the branch preserved.

Only `Push Branch` records `selected_action: push-branch`. Only `Hold` records `selected_action: hold`. Merge routing is unavailable until this push gate is answered and, when approved, the branch push proof exists.

## Merge-Ready Output

Produce a merge-ready handoff that includes:

- approved plan path
- outcome proof
- branch name and commit list
- verification commands and results
- readiness review evidence covering plan alignment, correctness, maintainability, and reality evidence
- cleanup hook result
- push permission ledger
- branch push proof
- merge mode `local-branch`
- explicit statement that no issue mirror was created, no pull request was opened, and no GitHub issue closure is claimed

Route merge-ready output to `$superpowers-project:merge-changes` or another approved merge route in `local-branch` mode only.

## Native Continuation Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before asking any route continuation or permission question, with this route-specific artifact inventory: the approved plan path, changed files, changed sections or representative diffs/snippets, branch, commit list, verification commands, exact test values/results, cleanup hook status, push decision, branch push status, merge-ready proof, merge mode, and the fact that no issue mirror was created and no pull request was opened.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

Question id: `project_implement_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: start `$superpowers-project:merge-changes` with the merge-ready proof.
- Revisit: review, fix, rerun verification, or update push permission.
- Stop: break the continuation loop.

If the user selects `Revise / Review Branch`, ask:

Question id: `project_implement_reiteration_route`

Prompt: `How should I revisit this implemented plan?`

Options:

- `Revise Branch`: continue implementation on the current development branch.
- `Review Evidence`: show the rendered handoff and verification evidence, then return to `project_implement_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the approved plan path, branch, verification evidence, push permission ledger, branch push proof, and merge-ready proof. Do not only tell the user what to prompt next.

## Contract Helper

Use `skills/implement-plan/scripts/lib/contract.ps1` to validate structured handoff ledgers in tests or worker closeout automation. The helper requires the approved plan, outcome proof, readiness review evidence, native `/goal` activation, a development branch, topology selection, passed verification, native push permission, branch push proof, merge-ready evidence, and no issue closure claim.
