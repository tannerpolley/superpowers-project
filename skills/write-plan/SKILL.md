---
name: write-plan
description: Use when an approved Superpowers Project spec or issue mirror needs a detailed implementation plan before code changes.
---

# Project Plan

Project Plan is the Superpowers Project adapter for `superpowers:writing-plans`. It writes durable implementation plans under `docs/superpowers/plans` and keeps links to source specs, issue mirrors, milestones, and proof oracles.

**Announce at start:** "I'm using the write-plan skill with superpowers:writing-plans."

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or `Done`. After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal. Only a user-selected `Stop` or `Done` option is terminal. If the selected route can continue with available tools and state, start it in the same turn; if it is blocked, ask or report the exact blocker through the next native question instead of silently stopping.

## Required Method

Use `superpowers:writing-plans` as the base workflow. Do not touch implementation code while writing the plan.

Require one of these inputs before planning:

- an approved source spec under `docs/superpowers/specs`
- an issue mirror under `docs/superpowers/issues` with a linked source spec or source plan
- an explicit user decision to plan directly from the current conversation

If the request is still an idea, naming choice, product direction, architecture direction, scope boundary, or other unresolved brainstorming decision, route back to `$project:brainstorm-spec` before writing an implementation plan.

## Planning Grill Gate

Before saving any new plan, run a planning grill whenever material assumptions, scope choices, sequencing choices, proof-oracle choices, naming choices, branch strategy choices, or routing choices remain.

Use the `$grill-me` behavior verbatim:

`Interview me relentlessly about every aspect of this plan`

When `request_user_input` is callable, the grill is a native UI hard gate, not optional prose. Batch independent material questions into native Q&A calls with recommended options first. Ask sequential follow-ups when one answer changes the next branch. Do not save the plan until material decisions have been answered or explicitly deferred in the plan with a named risk owner.

If a question can be answered by inspecting the repo, inspect first instead of asking. If the planning agent realizes it skipped the grill after drafting a plan, stop, run the native grill, and revise the saved plan before presenting it as ready.

Use `request_user_input` in Default mode when the tool is callable and a decision affects scope, acceptance criteria, sequencing, proof oracle, TDD policy, branch strategy, routing, publish behavior, or live mutation.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal planning or to pretend a live user approved scope, acceptance criteria, sequencing, proof oracle, or TDD policy.

## Destination Contract

Save plans to `docs/superpowers/plans/YYYY-MM-DD-<slug>-plan.md` unless the user explicitly chooses another repo-local Superpowers Project path.

When an issue mirror already exists, include linkage to `docs/superpowers/issues` in the plan header or intake section and keep the plan aligned with the issue acceptance checklist.

Plans are part of the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: plans link one or more loose specs or a raw approved idea, organize implementation-facing work, assign milestone/package ownership when that ownership matters, and prepare work for `$project:create-issues`. Keep canonical plans in `docs/superpowers/plans`; never place canonical plans under `docs/superpowers/milestones/<milestone>/plans`.

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
- acceptance criteria mapped to tasks
- non-goals
- proof oracle with exact command, artifact, user-visible behavior, or GitHub evidence
- risk and dependency notes where sequencing matters
- frequent commit checkpoints

## Test And Debug Discipline

Feature and bug plans require `superpowers:test-driven-development` unless the user explicitly opts out in the plan. Bug, regression, CI, or performance plans require `superpowers:systematic-debugging` or equivalent diagnose discipline before proposing the fix. Completion tasks require `superpowers:verification-before-completion` before any worker claims the plan is complete.

## Task Shape

Use the Superpowers task shape:

````markdown
### Task N: [Component Name]

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

After saving and self-reviewing the plan, summarize the plan in chat before asking the continuation question. The summary must name the saved plan path, source spec or issue mirror, acceptance coverage, proof oracle, TDD/debug policy, and recommended next route. Show exact artifact paths and links, and show rendered Markdown artifacts in chat when created or changed artifacts are Markdown and reasonably sized.

Ask native continuation questions when `request_user_input` is callable. These questions are executable routing, not advisory text. Use flowchart geometry: Down is default progress, Left is revise/review/repair/rerun/recover, and Right is `Stop / Done`. Use as many native questions and options as the decision requires. Show four or more native options when they are real peer routes. Use `advanced-user-input` for large peer route menus, bulk independent gates, or sequential branching when one answer determines the next prompt. Custom Other is not terminal unless it explicitly asks to stop or be done; otherwise turn it into the next best follow-up question or baseline route tree.

Question id: `project_plan_next_step`

Prompt: `How should I continue from this project plan?`

Options:

- Down: `Continue Into Work`: choose the issue-backed, plan-implementation, or later execution route.
- Left: `Revise / Review Plan`: choose whether to revise, review, ask follow-up questions, or re-run the planning grill.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Continue Into Work`, immediately ask:

Question id: `project_plan_work_route`

Prompt: `Which work route should follow this project plan?`

Options:

- Down: `Create Work Artifact`: create issues or prepare the upcoming plan implementation route.
- Left: `Execute Existing Work`: choose an existing issue execution route.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Create Work Artifact`, ask:

Question id: `project_plan_artifact_route`

Prompt: `Which work artifact should follow this plan?`

Options:

- Down: `Create Issue`: Project Issue First; continue to `$project:create-issues` using the saved plan path.
- Left: `Plan Implementation`: Project Implement; continue to `$project:implement-plan` using the saved plan path without creating issue mirrors.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Create Issue` or `Project Issue First`, ask:

Question id: `project_plan_issue_count`

Prompt: `How many issues should be created from this plan?`

Options:

- Down: `One Issue`: create one vertical-slice issue.
- Left: `Multiple Issues`: choose whether to create two issues or three or more.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Multiple Issues`, ask:

Question id: `project_plan_issue_count_multiple`

Prompt: `How many multiple issues should this plan create?`

Options:

- Down: `Two Issues`: create two coordinated vertical-slice issues.
- Left: `Three Or More`: create three or more issues, then use nested questions to group issue count and dependencies.
- Right: `Stop / Done`: break the continuation loop.

If milestone selection is still unresolved, inspect existing GitHub milestones and project roadmap first. Ask no more than three milestone choices in a native question; when exact milestone names or many milestones are possible, ask a focused normal-chat value prompt instead of inventing weak native categories.

If the user selects `Plan Implementation` or `Project Implement`, ask:

Question id: `project_plan_implementation_route`

Prompt: `Which plan implementation route should be prepared?`

Options:

- Down: `Implement Recent Plan`: Project Implement; continue to `$project:implement-plan` using the recently created plan path.
- Left: `Implement Different Plan`: ask for the exact plan path, then prepare that plan for implementation.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Execute Existing Work`, ask:

Question id: `project_plan_execution_route`

Prompt: `Which existing execution route should I use?`

Options:

- Down: `Resolve Issue`: start `$project:resolve-issue` for an existing ready issue mirror.
- Left: `Orchestrate Issues`: start `$project:orchestrate-issues` for worker-thread execution.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Revise / Review Plan`, immediately ask:

Question id: `project_plan_review_route`

Prompt: `How should I revisit this plan?`

Options:

- Down: `Revise Plan`: continue `$project:write-plan` with follow-up questions to revise the saved plan.
- Left: `Review Or Grill`: choose whether to review the plan or re-run the planning grill.
- Right: `Stop / Done`: break the continuation loop.

If the user selects `Review Or Grill`, ask:

Question id: `project_plan_review_grill_route`

Prompt: `Should I review this plan or re-run the planning grill?`

Options:

- Down: `Review First`: show the rendered artifact and ask for follow-up confirmation, then return to `project_plan_next_step`.
- Left: `Re-run Planning Grill`: run the planning grill again for an existing spec with no ready plan.
- Right: `Stop / Done`: break the continuation loop.

Recommend `Continue Into Work`, then `Project Issue First`, when the GitHub issue backbone is desired. Recommend `Project Implement` for branch-backed non-issue implementation. Quick Apply remains only for small, guarded, explicitly approved implementation work on clean synced `main`.

Route summary:

- `Project Implement`: continue to `$project:implement-plan` using the saved plan path.
- `Project Issue First`: continue to `$project:create-issues` using the saved plan path.
- Project Implement does not create issue mirrors.
- Recommend `Project Implement` for branch-backed non-issue implementation.
- Recommend `Project Issue First` when the GitHub issue backbone is desired.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the saved plan path, source spec or issue mirror path, decisions, acceptance criteria, and proof oracle. Do not only tell the user what to prompt next.

If the selected next skill needs its own material decision, ask that next skill's native UI question. If the route needs unavailable tools or an external write that still requires approval, stop with a clear pending state and exact resume target.

## Quick Apply Approval Gate

Quick Apply is only for small, low-risk plan follow-up work on clean synced `main`. Non-trivial, risky, multi-issue, branch-backed, or PR-bound implementation stays on the default `$project:create-issues` and `$project:resolve-issue` path.

Before any edits, ask a second native approval question when `request_user_input` is callable:

Question id: `project_quick_apply_approval`

Prompt: `Apply this small plan directly on local main?`

Options:

- `Apply on Main`: approve the local-main Quick Apply path.
- `Use Issue Flow`: route to `$project:create-issues` instead.
- `Stop`: stop without edits.

Only `Apply on Main` records `selected_action: apply`. Treat every other answer as a stop or issue-backed route, not approval to edit.

Validate the Quick Apply ledger with `skills/write-plan/scripts/validate-quick-apply.ps1`. The gate requires clean synced `main`, the `project_quick_apply_approval` ledger, passed verification commands, and a passed cleanup hook result. After a successful local commit, ask the next continuation or permission question with `request_user_input` when callable, including whether to push, review, revise, or stop. Run the gate before edits for approval and repository state, then again after focused verification and cleanup evidence are available.

## Self-Review

Before reporting the plan ready:

1. Confirm the save path is under `docs/superpowers/plans`.
2. Confirm the source spec, source issue mirror, or direct-plan approval is named.
3. Confirm every acceptance criterion maps to at least one task.
4. Confirm each task names exact files and exact verification.
5. Confirm feature and bug work uses `superpowers:test-driven-development` or records the user's explicit opt-out.
6. Confirm bug work uses `superpowers:systematic-debugging` or diagnose discipline.
7. Confirm completion requires `superpowers:verification-before-completion`.

