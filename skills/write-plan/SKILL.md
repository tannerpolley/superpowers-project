---
name: write-plan
description: Use when an approved Superpowers Project spec or issue mirror needs a detailed implementation plan before code changes.
---

# Project Plan

Project Plan is the Superpowers Project adapter for `superpowers:writing-plans`. It writes durable implementation plans under `docs/superpowers/plans` and keeps links to source specs, issue mirrors, milestones, and proof oracles.

**Announce at start:** "I'm using the write-plan skill with superpowers:writing-plans."

## Native Continuation Loop

Follow `skills/advanced-user-input/SKILL.md` for global native continuation, Custom Other, Revisit, Stop, verified Done, and artifact review policy. This skill keeps route-specific gates, artifacts, validators, ledgers, and routing rules local.

After every completed route-specific action, ask the next native continuation or permission question when `request_user_input` is callable. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.
## Required Method

Use `superpowers:writing-plans` as the base workflow. Do not touch implementation code while writing the plan.

Require one of these inputs before planning:

- an approved source spec under `docs/superpowers/specs`
- an issue mirror under `docs/superpowers/issues` with a linked source spec or source plan
- an explicit user decision to plan directly from the current conversation

## Auto Mode Input

When invoked from Auto Mode, require an Auto Mode authorization ledger from `project_auto_mode_authorization` before planning. Validate it with the plugin-provided Auto Mode validator from the loaded Superpowers Project plugin root (`<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`); the valid authority is `bounded-auto-merge`, with `recorded-defaults` / recorded defaults decision policy and `stop_outside_policy: true`.

Auto Mode may choose the recommended planning route and record defaults for scope, sequencing, proof oracle, TDD policy, branch strategy, routing, publish behavior, and live mutation choices only when the source spec and repo evidence make the choice inside the ledger policy. Carry the Auto Mode authorization ledger into the plan intake/source evidence. If a required planning decision is outside the recorded defaults policy, proof is missing, validation fails, or the source spec is not under `docs/superpowers/specs`, stop outside policy and do not save a ready plan.

If the request is still an idea, naming choice, product direction, architecture direction, scope boundary, or other unresolved brainstorming decision, route back to `$superpowers-project:brainstorm-spec` before writing an implementation plan.

## Planning Grill Gate

Before saving any new plan, run a planning grill whenever material assumptions, scope choices, sequencing choices, proof-oracle choices, naming choices, branch strategy choices, or routing choices remain.

Use the `$grill-me` behavior verbatim:

`Interview me relentlessly about every aspect of this plan`

When `request_user_input` is callable, the grill is a native UI hard gate, not optional prose. Batch independent material questions into native Q&A calls with recommended options first. Ask sequential follow-ups when one answer changes the next branch. Do not save the plan until material decisions have been answered or explicitly deferred in the plan with a named risk owner.

If a question can be answered by inspecting the repo, inspect first instead of asking. If the planning agent realizes it skipped the grill after drafting a plan, stop, run the native grill, and revise the saved plan before presenting it as ready.

Use `request_user_input` in Default mode when the tool is callable and a decision affects scope, acceptance criteria, sequencing, proof oracle, TDD policy, branch strategy, routing, publish behavior, live mutation, owner, interface, cutover, replaced path, evidence fields, stop criteria, or avoid list.

## Test-Complete And Metrics Gate

Before presenting a plan as ready, ask or record direct answers for:

- what counts as test complete
- what proof demonstrates that status
- what metrics define pass versus fail
- whether tolerances, edge-case thresholds, or error bounds matter

When the project is scientific or engineering-oriented, ask for numerical metrics, thresholds, tolerances, units, and validation coverage. Record those answers in the plan acceptance criteria and proof oracle. If those prompts are not applicable, record that with a clear reason before routing into work.

Do not route to `Continue Into Work` until the test-complete and metrics answers exist or are explicitly marked not applicable with a clear reason.

## Outcome Proof Gate

Every implementation plan MUST include a `## Outcome Proof` section before task decomposition. This section is mandatory for all implementation plans, not only high-risk plans.

Required `## Outcome Proof` fields:

- `Intent`
- `Current Behavior`
- `Expected Outcome`
- `Target Output`
- `Owner`
- `Interface`
- `Cutover`
- `Replaced Path`
- `Evidence`
- `Acceptance Proof`
- `Stop Criteria`
- `Avoid`
- `Risk`

Every implementation plan MUST also include a `## Implementation Boundaries` section before task decomposition.

Required `## Implementation Boundaries` fields:

- `Files To Create`
- `Files To Modify`
- `Files To Avoid`
- `Source Of Truth`
- `Read Path`
- `Write Path`
- `Integration Points`
- `Migration Or Cutover`
- `Replaced Path Handling`
- `Acceptance Proof Gate`

Before saving or presenting a plan as ready, run the repo-root validator:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-outcome-proof.ps1 -PlanPath <saved-plan-path>
```

If the validator fails, revise the plan before artifact review. Do not route to `$superpowers-project:create-issues`, `$superpowers-project:implement-plan`, `$superpowers-project:resolve-issue`, or `$superpowers-project:orchestrate-issues` until the saved plan passes.

Task # Use Cases must cover acceptance proof and cutover or replaced path handling. A plan is not ready when tasks can pass local tests but do not prove target output, owner, interface, cutover, replaced path, evidence, stop criteria, and avoid list.

## Task # Use Cases Gate

Task # Use Cases are a strict requirement for every actual implementation plan. Every numbered `Task N` section MUST include a `**Use Cases:**` block before files and checkbox steps. Each block must list concrete user, system, issue-acceptance, failure, recovery, validation, or workflow cases that the task is responsible for covering.

The use-case block is not optional context. It is the bridge from plan making to implementation. A plan is not ready if any numbered task lacks use cases, has an empty use-case block, or only describes generic intent without concrete cases.

Before saving or presenting a plan as ready, run the repo-root validator:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <saved-plan-path>
```

If the validator fails, revise the plan before artifact review. Do not route to `$superpowers-project:create-issues`, `$superpowers-project:implement-plan`, `$superpowers-project:resolve-issue`, or `$superpowers-project:orchestrate-issues` until the saved plan passes.

## Native Question Debug Mode

Normal runs must use `request_user_input` when it is callable and a material user decision is needed. Use `debug_question_mode` only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

In `debug_question_mode`, do not call `request_user_input`. Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include `skill_name`, `thread_id`, `observed_status: waitingOnUserInput`, `question_id`, `prompt`, `options`, `recommended_option`, `selected_answer`, `answer_source: recommended-default | user-provided-debug-answer`, `no_answer_tool_available: true`, and `mutation_allowed: false`. Selecting the recommended answer is allowed only when the user or smoke prompt authorized recommended defaults.

Debug mode must not approve mutation. Debug mode must not pretend a live user approved scope, acceptance criteria, sequencing, proof oracle, TDD policy, or planning mutation.
## Destination Contract

Save plans to `docs/superpowers/plans/YYYY-MM-DD-<slug>-plan.md` unless the user explicitly chooses another repo-local Superpowers Project path.

When an issue mirror already exists, include linkage to `docs/superpowers/issues` in the plan header or intake section and keep the plan aligned with the issue acceptance checklist.

Plans are part of the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: plans link one or more loose specs or a raw approved idea, organize implementation-facing work, assign milestone/package ownership when that ownership matters, and prepare work for `$superpowers-project:create-issues`. Keep canonical plans in `docs/superpowers/plans`; never place canonical plans under `docs/superpowers/milestones/<milestone>/plans`.

Plan filenames must include creation date and slug. For implementation-facing work, plans include creation date and milestone identity where applicable, using a shape such as `docs/superpowers/plans/<yyyy-mm-dd>-<milestone-or-category>-<slug>-plan.md`. If no milestone identity is meaningful, use `docs/superpowers/plans/<yyyy-mm-dd>-<slug>-plan.md`.

Milestone pages are index views. They link to flat canonical plans and issues, and may list loose upstream specs as context. Represent milestone/category views through frontmatter plus milestone indexes. Treat nested canonical milestone artifact folders are drift, including nested `specs`, `plans`, or `issues` directories under `docs/superpowers/milestones`, unless an approved generator explicitly marks them as generated index/view output.

## Plan Document Header

Every plan MUST start with this header exactly:

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Planning Discipline

Before decomposing tasks, map exact files to create, modify, and test. Each task should be self-contained and shippable, with checkbox steps and exact commands.

Required plan content:

- source spec or direct-plan approval evidence
- issue mirror linkage when applicable
- milestone linkage when applicable
- `## Outcome Proof` with owner, interface, cutover, replaced path, evidence, acceptance proof, stop criteria, avoid list, and risk
- `## Implementation Boundaries` with source of truth, read/write path, integration points, migration or cutover, replaced path handling, and acceptance proof gate
- acceptance criteria mapped to tasks
- non-goals
- proof oracle with exact command, artifact, user-visible behavior, or GitHub evidence
- risk and dependency notes where sequencing matters
- frequent commit checkpoints

## Test And Debug Discipline

Feature and bug plans require `superpowers:test-driven-development` unless the user explicitly opts out in the plan. Bug, regression, CI, or performance plans require `superpowers:systematic-debugging` or equivalent diagnose discipline before proposing the fix. Completion tasks require `superpowers:verification-before-completion` before any worker claims the plan is complete.

## Companion Interface Opt-In

When the user asks for the companion, or when the saved implementation plan is too large for chat rendering, use `$superpowers-project:companion-interface` to create or refresh a repo-owned Agent-Native visual-plan MDX artifact. Include source spec linkage, Outcome Proof, Implementation Boundaries, task list, Task # Use Cases blocks, proof oracle, test-complete definition, plan validation receipt, and recommended next route.

The companion is an evidence surface only. Native continuation, issue creation, implementation, push, publish, merge, and final Done decisions still happen through chat or `request_user_input`.

## Task Shape

Use the Superpowers task shape:

````markdown
### Task N: [Component Name]

**Use Cases:**
- [Concrete behavior, acceptance scenario, failure/recovery path, validation case, or workflow case this task must cover]

**Files:**
- Create: `exact/path/to/file.ext`
- Modify: `exact/path/to/existing.ext`
- Test: `exact/path/to/test.ext`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run the test and verify the expected failure**
- [ ] **Step 3: Implement the minimal change**
- [ ] **Step 4: Run the test and verify it passes**
- [ ] **Step 5: Commit**
````

Replace generic labels with real file paths, code, commands, and expected results before saving. A plan is not ready while any step relies on vague wording, missing files, or unspecified verification.

## Native Continuation Gate

Complete the artifact review gate required by `skills/advanced-user-input/SKILL.md` before asking this route's native continuation or permission question. Route-specific artifact inventory must include the saved plan, the Outcome Proof, the Implementation Boundaries, the full task list, every Task # Use Cases block, the full step list, the source spec or issue mirror linkage, acceptance coverage, proof oracle, TDD/debug policy, and what counts as test complete. Add the helper-required findings summary with route-specific status for the saved plan path, source spec or issue mirror, Outcome Proof validation, Implementation Boundaries validation, acceptance coverage, proof oracle, TDD/debug policy, Task # Use Cases validation, what counts as test complete, whether scientific or engineering numerical metrics were required.

Use `skills/advanced-user-input/SKILL.md` for global native question geometry, Custom Other handling, Revisit behavior, Stop and verified Done terminal rules, and nested-route rules. This skill keeps only route-specific question IDs, route labels, validators, ledgers, artifact lists, and execution routes. Ask the skill-specific native continuation question with `request_user_input` when callable; selected answers are executable routing.

Question id: `project_plan_next_step`

Prompt: `Should I continue on with the workflow?`

Options:

- Yes: choose the issue-backed, plan-implementation, or later execution route.
- Revisit: choose whether to revise, review, ask follow-up questions, or re-run the planning grill.
- Stop: break the continuation loop.

If the user selects `Continue Into Work`, immediately ask:

Question id: `project_plan_work_route`

Prompt: `Which workflow should continue from this plan?`

Options:

- `Project Issue First`: continue to `$superpowers-project:create-issues` using the saved plan path.
- `Project Implement`: continue to `$superpowers-project:implement-plan` using the saved plan path without creating issue mirrors.
- `Use Ready Issue`: choose an existing ready issue execution route.

If the user selects `Create Issue` or `Project Issue First`, ask:

Question id: `project_plan_issue_count`

Prompt: `How many issues should be created from this plan?`

Options:

- `One Issue`: create one vertical-slice issue.
- `Multiple Issues`: choose whether to create two issues or three or more.

If the user selects `Multiple Issues`, ask:

Question id: `project_plan_issue_count_multiple`

Prompt: `How many multiple issues should this plan create?`

Options:

- `Two Issues`: create two coordinated vertical-slice issues.
- `Three Or More`: create three or more issues, then use nested questions to group issue count and dependencies.

If milestone selection is still unresolved, inspect existing GitHub milestones and project roadmap first. Show the real milestone choices in native UI when that is clearer, including more than three options when useful. When exact milestone names, free-form grouping, or a long data-backed list would be clearer as text, ask a focused normal-chat value prompt instead of inventing weak native categories.

If the user selects `Use Ready Issue`, ask:

Question id: `project_plan_issue_execution_route`

Prompt: `Which ready-issue execution route should continue from this plan?`

Options:

- `Resolve Issue`: start `$superpowers-project:resolve-issue` for an existing ready issue mirror.
- `Orchestrate Issues`: start `$superpowers-project:orchestrate-issues` for worker-thread execution.

If the user selects `Revise / Review Plan`, immediately ask:

Question id: `project_plan_review_route`

Prompt: `How should I revisit this plan?`

Options:

- `Revise Plan`: continue `$superpowers-project:write-plan` with follow-up questions to revise the saved plan.
- `Review Or Grill`: choose whether to review the plan or re-run the planning grill.

If the user selects `Review Or Grill`, ask:

Question id: `project_plan_review_grill_route`

Prompt: `Should I review this plan or re-run the planning grill?`

Options:

- `Review First`: show the rendered artifact and ask for follow-up confirmation, then return to `project_plan_next_step`.
- `Re-run Planning Grill`: run the planning grill again for an existing spec with no ready plan.

Recommend `Continue Into Work`, then `Project Issue First`, when the GitHub issue backbone is desired. Recommend `Project Implement` for branch-backed non-issue implementation. Recommend `Use Ready Issue` only when a compatible ready issue mirror already exists and the plan should route into that execution path.

Route summary:

- `Project Implement`: continue to `$superpowers-project:implement-plan` using the saved plan path.
- `Project Issue First`: continue to `$superpowers-project:create-issues` using the saved plan path.
- `Use Ready Issue`: choose between `$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues` for an existing ready issue mirror.
- Project Implement does not create issue mirrors.
- Recommend `Project Implement` for branch-backed non-issue implementation.
- Recommend `Project Issue First` when the GitHub issue backbone is desired.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the saved plan path, source spec or issue mirror path, decisions, acceptance criteria, and proof oracle. Do not only tell the user what to prompt next.

If the selected next skill needs its own material decision, ask that next skill's native UI question. If the route needs unavailable tools or an external write that still requires approval, stop with a clear pending state and exact resume target.

## Self-Review

Before reporting the plan ready:

1. Confirm the save path is under `docs/superpowers/plans`.
2. Confirm the source spec, source issue mirror, or direct-plan approval is named.
3. Confirm every acceptance criterion maps to at least one task.
4. Confirm each task names exact files and exact verification.
5. Confirm the plan has `## Outcome Proof`, `## Implementation Boundaries`, and `scripts/validate-plan-outcome-proof.ps1 -PlanPath <saved-plan-path>` passes.
6. Confirm every numbered task has a non-empty `**Use Cases:**` block and `scripts/validate-plan-task-use-cases.ps1 -PlanPath <saved-plan-path>` passes.
7. Confirm feature and bug work uses `superpowers:test-driven-development` or records the user's explicit opt-out.
8. Confirm bug work uses `superpowers:systematic-debugging` or diagnose discipline.
9. Confirm completion requires `superpowers:verification-before-completion`.
