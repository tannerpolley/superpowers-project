---
name: resolve-issue
description: Use when one ready GitHub issue mirror under docs/superpowers/issues must be implemented directly in the current thread through native goal activation, Superpowers execution, pushed branch, opened PR, and PR-ready handoff.
---

# Project Resolve

This skill is the issue-backed Superpowers Project adapter for `superpowers:executing-plans`. It owns direct current-thread implementation for one ready GitHub issue. It starts from a synced issue mirror under `docs/superpowers/issues`, validates the linked source plan and Outcome Summary, activates a native `/goal`, executes with Superpowers discipline, and ends with PR-ready evidence for the main thread orchestrator: covered acceptance criteria, passed verification, pushed branch, opened PR that closes the linked issue, structured readiness review, native goal completion proof, and a handoff to `$superpowers-project:merge-changes`.

If the user wants delegated worker-thread implementation, route to `$superpowers-project:orchestrate-issues` before setup. `$superpowers-project:resolve-issue` must not create worker threads or worker handoff ledgers.

**Announce at start:** "I'm using the resolve-issue skill with superpowers:executing-plans for direct issue implementation."

GoalBuddy boards are outside the default execution model. Do not create `docs/goals`, GoalBuddy board files, GoalBuddy state, or local live boards from this skill unless the user explicitly requests separate GoalBuddy work outside this default issue-resolution path.

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization`. Validate it with the plugin-provided Auto Mode validator from the loaded Superpowers Project plugin root (`<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy, `route_policy.issue_route: direct-inline-resolve-issue`, and `stop_outside_policy: true`.

Auto Mode may choose direct current-thread issue resolution, create or verify native goal proof, execute the source plan, run verification, push PR-ready work, and route to merge without additional user input when the ready issue mirror came from the authorized source spec or derived plan. Carry the Auto Mode authorization ledger into PR-ready handoff evidence. If the issue mirror is not ready, proof is missing, checks fail, branch state is unsafe, or implementation needs a decision outside recorded defaults, stop outside policy before pushing or handoff.

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
## Artifact Source Of Truth

Project Resolve executes the `spec -> plan -> issue` lifecycle from flat canonical roots. It accepts one issue mirror from `docs/superpowers/issues`, requires a source plan from `docs/superpowers/plans`, and may read upstream loose specs from `docs/superpowers/specs`. Milestone pages are index views: they link to the flat canonical artifacts and do not own nested implementation records.

Before implementation, block or route to `$superpowers-project:align-project` when an issue mirror, source plan, or related spec is presented from `docs/superpowers/milestones/<milestone>/issues`, `docs/superpowers/milestones/<milestone>/plans`, or `docs/superpowers/milestones/<milestone>/specs`. Those nested canonical milestone artifact folders are drift unless explicitly marked as generated index/view output. Keep milestone identity in frontmatter plus milestone indexes, filenames where applicable, and GitHub milestone fields.

## Task # Use Cases Gate

Task # Use Cases are a strict requirement for issue resolution because this skill executes the linked source plan. After source plan validation and before native goal activation, branch setup, or code edits, run the repo-root validator against the linked source plan:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <source-plan-path>
```

Every numbered `Task N` in the linked source plan MUST include a non-empty `**Use Cases:**` block with concrete user, system, acceptance, failure/recovery, validation, or workflow cases. If validation fails, stop issue execution and route back to `$superpowers-project:write-plan` with `Revise Plan` for the source plan. Do not treat issue acceptance criteria alone as a substitute for Task # Use Cases.

## Hard Failures

Stop immediately when any of these are true:

- No single GitHub issue or issue mirror is named.
- The target is only a raw GitHub issue URL, an external intake issue, or a mirror with `Source Plan: TBD`.
- The issue mirror is outside `docs/superpowers/issues`.
- The issue mirror has no linked source plan under `docs/superpowers/plans`.
- The linked source plan does not exist.
- The linked source plan fails `scripts/validate-plan-task-use-cases.ps1`.
- The issue mirror lacks acceptance criteria, proof oracle, AFK/HITL classification, or Outcome Summary.
- The issue mirror is a GitHub hierarchy parent or plan-wrapper, or has `Executable: false`; direct execution is leaf-only.
- Native goal proof is missing, a plain string, inactive, or not from `get_goal`.
- Setup ledger lacks structured `outcome_proof`, or contains `goal_board_path`, `goalbuddy_checker`, or `docs/goals`.
- Code edits or implementation tests begin before setup validation passes.
- PR-ready evidence does not close the exact linked GitHub issue.
- PR-ready evidence does not show outcome proof proof, readiness review proof, push permission proof, acceptance coverage, verification proof, branch push proof, handoff proof, and native goal completion proof.
- A terminal success or final closeout is attempted without a structured continuation decision ledger that records explicit `Stop`.

## State Machine

Follow this order exactly:

1. `repo gate`: verify the active repo and explicit target when needed.
2. `issue mirror validation`: inspect `docs/superpowers/issues/<issue>.md`, including its Outcome Summary.
3. `source plan validation`: read the linked `docs/superpowers/plans/<plan>.md`.
4. `Task # Use Cases validation`: run `scripts/validate-plan-task-use-cases.ps1` against the linked source plan.
5. `preflight`: verify the repo is ready for one issue execution.
6. `route check`: if worker-thread execution is requested, stop and route to `$superpowers-project:orchestrate-issues`.
7. `native goal activation`: call `get_goal`, create or activate the native `/goal`, then call `get_goal` again and capture structured proof.
8. `setup validation`: write and validate the setup ledger for direct current-thread execution, including structured `outcome_proof`.
9. `worktree and branch setup`: create or verify the current-thread worktree/branch.
10. `Superpowers execution`: use Superpowers execution, TDD, debugging, dynamic workflow, and verification skills as applicable.
11. `development branch finish`: use `superpowers:finishing-a-development-branch`, with PR as the default finish path.
12. `push permission`: ask native push permission before pushing the branch or opening the PR.
13. `PR-ready validation`: validate outcome proof carry-forward, readiness review proof, push permission, branch push, PR URL, closing issue reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
14. `handoff`: send or record the worker/main-thread handoff and route final integration to `$superpowers-project:merge-changes`.
15. `terminal closeout`: before ending this skill as complete, collect a continuation decision ledger and validate that the user explicitly selected `Stop`. Any non-terminal route must keep the workflow running.

## Route Check

`$superpowers-project:resolve-issue` is the direct current-thread route. If the user wants a worker thread, use `$superpowers-project:orchestrate-issues`.

If the user gives only a GitHub issue URL, no local mirror exists, or the mirror has an unresolved source plan, use `$superpowers-project:create-issues` hydration first. `$superpowers-project:resolve-issue` starts only after the local mirror and source plan exist and mirror validation passes.

GitHub sub-issue parent and plan-wrapper mirrors are rollup records, not executable work. When hierarchy metadata is present, only `Sub-Issue Role: leaf` with `Executable: true` can enter direct execution. Old flat mirrors with no hierarchy fields keep the existing execution path.

When the requested route is ambiguous and `request_user_input` is callable, the router should ask native question `project_issue_resolution_route` before starting either skill. If `$superpowers-project:resolve-issue` receives an execution decision whose selected mode is `orchestrated-worker`, stop immediately with the reason: `orchestrated worker execution is owned by orchestrate-issues; use resolve-issue only for direct current-thread execution`.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not execute issue work, push branches, choose execution topology, or pretend a live user approved issue execution.
## Worker Route Boundary

Worker-thread orchestration is owned by `$superpowers-project:orchestrate-issues`. That skill derives the canonical worker thread title, branch name, evidence folder, and worker handoff, then routes PR-ready output to `$superpowers-project:merge-changes`.

## Scripted Gates

Run bundled scripts from this skill package with explicit `-RepoRoot`:

- `scripts/prepare-execution.ps1 -Mode Inspect`: reads the issue mirror, validates the source plan and Outcome Summary, and emits handoff JSON plus the exact native goal objective.
- `scripts/preflight.ps1`: validates issue mirror, source plan, branch, proof oracle, and clean starting state.
- `scripts/prepare-execution.ps1 -Mode ApplySetup`: creates or verifies the implementation branch and prints the native goal objective.
- `scripts/prepare-execution.ps1 -Mode FinalizeSetup`: accepts structured `get_goal` proof and writes the native setup ledger with the issue outcome proof.
- `scripts/validate-setup.ps1`: rejects GoalBuddy board fields and requires issue mirror, source plan, branch, proof oracle, goal id or thread goal proof, structured outcome proof, and structured native goal proof.
- `scripts/collect-pr-ready-ledger.ps1 -RepoRoot . -SetupLedgerPath <setup-ledger.json> -PrJson <json> -VerificationCommands <commands> -PushPermissionJson <json-or-path> -AcceptanceCoverageJson <json> -HandoffProofJson <json> -ReadinessReviewJson <json-or-path> -GoalCompletionProofJson <json> -OutputDir <temp-or-handoff-dir>`: generates the PR-ready ledger from PR evidence, outcome proof carry-forward, readiness review proof, push permission proof, acceptance coverage, verification receipts, handoff proof, and native goal completion proof.
- `scripts/validate-pr-ready.ps1`: validates outcome proof carry-forward, readiness review proof, push permission proof, branch push proof, PR closing reference, acceptance coverage, verification proof, handoff proof, and native goal completion proof.
- `scripts/collect-continuation-ledger.ps1 -RepoRoot . -QuestionId <id> -Prompt <text> -Source <request_user_input|debug_question_mode> -SelectedOptionId <id> -RecommendedOptionId <id> -TerminalState <stop|continue|revisit> -OptionIds <id1,id2,id3> -OutputDir <temp-or-handoff-dir>`: records the structured continuation decision after a PR-ready native route question.
- `scripts/validate-terminal-closeout.ps1 -RepoRoot . -PrReadyResultJson <json-or-path> -ContinuationDecisionJson <json-or-path>`: blocks terminal success unless the PR-ready gate passed and the continuation decision records explicit `Stop`.

All scripts emit JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script reason.

## Temp Plus Evidence

Normal runs should use `scripts/collect-pr-ready-ledger.ps1` before `scripts/validate-pr-ready.ps1`. The collector writes generated ledgers to a temp directory by default, or to an explicit output directory when the final handoff needs selected evidence artifacts. This keeps generated ledgers passed to existing gates without making agents hand-build JSON during ordinary resolution. The validator remains authoritative; collector output is convenience evidence, not a replacement for the PR-ready gate.

Terminal closeout is separate from PR-ready proof. If the thread is about to stop after PR-ready, collect the continuation decision with `scripts/collect-continuation-ledger.ps1` and pass it to `scripts/validate-terminal-closeout.ps1`. That terminal validator is authoritative for whether `resolve-issue` may end the workflow; PR-ready proof alone is not terminal permission.

There is no hand-authored JSON requirement for normal runs. Hand-authored JSON is acceptable only for fixture tests, debug smoke tests, or unusual recovery work where the collector cannot access the source evidence.

## Setup Ledger Shape

The setup ledger must include:

```json
{
  "issue_url": "https://github.com/<owner>/<repo>/issues/<n>",
  "issue_mirror": "docs/superpowers/issues/<issue-number>-<slug>.md",
  "source_plan": "docs/superpowers/plans/<date>-<slug>-plan.md",
  "branch": "codex/<slug>",
  "goal_id": "<native goal id or thread goal proof id>",
  "goal_objective": "<exact native goal objective>",
  "goal_activation_proof": {
    "source": "get_goal",
    "active": true,
    "goal_id": "<id>",
    "objective": "<active objective>"
  },
  "execution_decision": {
    "question_id": "resolve_execution_topology",
    "source": "request_user_input",
    "selected_mode": "inline",
    "recommended_mode": "inline",
    "options": ["orchestrated-worker", "inline"]
  },
  "outcome_proof": {
    "source": "docs/superpowers/plans/<date>-<slug>-plan.md#outcome-proof",
    "intent": "<source plan intent>",
    "target_output": "<maintainer-visible target output>",
    "owner": "<owner for the proof>",
    "interface": "<ledger, script, API, or file boundary>",
    "cutover": "<active cutover>",
    "replaced_path": "<old path displaced by this work>",
    "acceptance_proof": "<evidence that proves the outcome>",
    "stop_criteria": "<condition that blocks handoff>",
    "avoid": ["<moves that would violate the proof>"]
  },
  "workflow_policy": {
    "worktree_policy": "Native Codex worktree thread first",
    "integration_policy": "Current thread owns PR",
    "tdd_policy": "Required",
    "reviewer_role": "Main thread orchestrator",
    "script_gate_mode": "Safety only"
  },
  "worker_handoff": null,
  "dynamic_work_packet_map": null,
  "proof_oracle": ["<commands, artifacts, review state, or visible behavior>"],
  "branch_inventory_before": {
    "local": ["main"],
    "remote": ["main"]
  }
}
```

Plain strings do not count as native goal, verification, or completion proof.

## Readiness Review Proof

Before PR-ready handoff, collect structured `readiness_review` evidence:

```json
{
  "plan_alignment": true,
  "correctness": true,
  "maintainability": true,
  "reality_evidence": true
}
```

`plan_alignment` means the implementation still matches the linked source plan and issue Outcome Summary. `correctness` means the implementation satisfies the acceptance criteria. `maintainability` means the change does not leave duplicate replaced paths, loose compatibility wrappers, or stale instructions. `reality_evidence` means the proof came from actual artifacts, commands, rendered output, PR metadata, or file diffs rather than a claim. Missing or false readiness review blocks PR-ready validation.

## Native Goal Policy

If native goal tools are callable, use them:

- Call `get_goal` before activation. If an unrelated active goal exists, block.
- Activate the exact `/goal` objective from `prepare-execution.ps1`.
- Call `get_goal` again and pass that structured proof to `FinalizeSetup`.
- At PR-ready, call native goal completion when tool support exists and record the structured result in the PR-ready ledger.

If the run uses a slash-command flow instead of tools, record the exact `/goal` activation and completion evidence in ledgers. Do not continue from a plain-text claim.

## Superpowers Method Contract

This skill is the issue-backed Superpowers Project adapter for `superpowers:executing-plans`. The companion method contract is mandatory inside this GitHub lifecycle:

- Always use `superpowers:using-git-worktrees` before implementation work begins.
- Always use `superpowers:executing-plans` as the base execution workflow for the linked source plan.
- Require `superpowers:test-driven-development` for feature or bug code unless the source plan records an explicit opt-out.
- Require `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes.
- `$superpowers-project:orchestrate-issues` when the issue needs an orchestrator/worker split.
- `codex-dynamic-workflows` only through `$superpowers-project:orchestrate-issues` when the issue meets the heavier orchestration decision rule or the user explicitly requests it.
- `superpowers:dispatching-parallel-agents` only when independent packets can run in parallel and the selected route supports delegation.
- Require `superpowers:verification-before-completion` before PR-ready claims.
- Require `superpowers:finishing-a-development-branch` after verification and before PR creation.

Do not collapse this into generic "Superpowers execution". If a required companion skill cannot be applied, stop and surface the blocker instead of continuing with ad hoc execution.

GitHub specialists can be used for CI or review-thread work, but bundled gate scripts remain authoritative.

## Push Permission Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before asking any route continuation or permission question, with this route-specific artifact inventory: full changed-artifact inventory, exact paths, changed sections or representative diffs/snippets, issue acceptance coverage, verification evidence, verification commands, exact test values/results, cleanup evidence when present, branch state, and PR-ready draft evidence before asking whether to push or open the PR. If a changed artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative diff or snippet, and why the full render is omitted. Do not ask for push approval first and explain later. After the Artifact Review Card and helper-owned findings summary are shown, ask native push permission before pushing the branch or opening the PR.

Question id: `project_resolve_push_permission`

Prompt: `Should I push this branch and create the PR now?`

Options:

- `Push And Open PR`: push the branch, open the PR, and continue to PR-ready handoff.
- `Hold`: keep the branch local and stop with explicit hold state.

Only `Push And Open PR` records `selected_action: push-pr`. Only `Hold` records `selected_action: hold`. PR-ready evidence is invalid unless this gate was answered and approved before the push/PR step.

## Native Continuation Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` using the helper's Artifact Review Card schema before asking any route continuation or permission question, with this route-specific artifact inventory: the PR URL, branch, issue mirror, source plan, outcome proof, readiness review evidence, changed files, changed sections or representative diffs/snippets, acceptance coverage, verification commands, exact test values/results, branch push proof, handoff proof, and native goal completion proof.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

Question id: `project_resolve_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: merge this work or continue issue execution.
- Revisit: review, revise, fix checks, or re-run verification.
- Stop: break the continuation loop.

If the user selects `Yes`, ask:

Question id: `project_resolve_integration_route`

Prompt: `What should happen with this PR-ready issue?`

Options:

- `Merge`: start `$superpowers-project:merge-changes` from the PR URL or worker handoff.
- `Continue Another Issue`: choose direct resolve or worker orchestration for another issue.

If the user selects `Continue Another Issue`, ask:

Question id: `project_resolve_another_issue_route`

Prompt: `How should the next issue be executed?`

Options:

- `Resolve Another`: start `$superpowers-project:resolve-issue` for another ready issue mirror.
- `Orchestrate Another`: start `$superpowers-project:orchestrate-issues` for another worker-suitable issue.

If the user selects `Revisit`, ask:

Question id: `project_resolve_reiteration_route`

Prompt: `How should I revisit this PR-ready work?`

Options:

- `Review First`: show PR-ready evidence for main-thread review, then return to `project_resolve_next_step`.
- `Revise Or Fix Branch`: choose branch revision or CI/check repair.

If the user selects `Revise Or Fix Branch`, ask:

Question id: `project_resolve_fix_route`

Prompt: `Should I revise the branch or address checks?`

Options:

- `Revise Branch`: continue implementation on the branch, then return to `project_resolve_next_step`.
- `Address CI / Checks`: inspect and fix checks, then return to `project_resolve_next_step`.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Treat selected native answers as executable routing, not advisory text. If the route needs unavailable tools, stop with the exact pending state and resume target. Debug mode is only for explicit non-interactive smoke tests.

Record the selected route in a structured continuation decision ledger. If the answer is `Stop`, collect the ledger and run `scripts/validate-terminal-closeout.ps1` before any final success-style response. If the answer is any non-terminal route such as `Merge`, `Resolve Another`, `Orchestrate Another`, `Review First`, `Revise Branch`, or `Address CI / Checks`, the ledger must still be recorded, and the thread must continue into that route instead of terminating.

## Completion Rule

Do not send a success-style final response until PR-ready proof shows:

- Acceptance criteria are covered.
- Outcome proof is carried from setup into PR-ready proof.
- Readiness review has true `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence`.
- Push permission was explicitly approved.
- Verification passed.
- Branch is pushed.
- PR is opened and closes the exact linked issue.
- Native resolve goal is marked complete.
- PR-ready handoff was sent or recorded for `$superpowers-project:merge-changes`.
- A structured continuation decision ledger was collected for the last native continuation answer.
- `scripts/validate-terminal-closeout.ps1` passes with explicit `Stop`.
