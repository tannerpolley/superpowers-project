---
name: project-plan
description: Use when an approved Superpowers Project spec or issue mirror needs a detailed implementation plan before code changes.
---

# Project Plan

Project Plan is the Superpowers Project adapter for `superpowers:writing-plans`. It writes durable implementation plans under `docs/superpowers/plans` and keeps links to source specs, issue mirrors, milestones, and proof oracles.

**Announce at start:** "I'm using the project-plan skill with superpowers:writing-plans."

## Required Method

Use `superpowers:writing-plans` as the base workflow. Do not touch implementation code while writing the plan.

Require one of these inputs before planning:

- an approved source spec under `docs/superpowers/specs`
- an issue mirror under `docs/superpowers/issues` with a linked source spec or source plan
- an explicit user decision to plan directly from the current conversation

If the request is still an idea, naming choice, product direction, architecture direction, scope boundary, or other unresolved brainstorming decision, route back to `$project-brainstorm` before writing an implementation plan.

If assumptions remain material, run a short planning grill before writing tasks:

`Interview me relentlessly about every aspect of this plan`

Use `request_user_input` in Default mode when the tool is callable and a decision affects scope, acceptance criteria, sequencing, proof oracle, or TDD policy.

## Native Question Debug Mode

For explicit non-interactive smoke tests, use `debug_question_mode` instead of `request_user_input` only when the prompt authorizes debug defaults or when a background-thread native prompt is proven stuck in `waitingOnUserInput`. Record a Native Question Debug Ledger entry with the skill name, question id, prompt, options, recommended option, selected answer, and answer source (`recommended-default` or `user-provided-debug-answer`). Debug mode must not be used for normal planning or to pretend a live user approved scope, acceptance criteria, sequencing, proof oracle, or TDD policy.

## Destination Contract

Save plans to `docs/superpowers/plans/YYYY-MM-DD-<slug>-plan.md` unless the user explicitly chooses another repo-local Superpowers Project path.

When an issue mirror already exists, include linkage to `docs/superpowers/issues` in the plan header or intake section and keep the plan aligned with the issue acceptance checklist.

Plans are part of the flat canonical roots model. The lifecycle is `spec -> plan -> issue`: plans link one or more loose specs or a raw approved idea, organize implementation-facing work, assign milestone/package ownership when that ownership matters, and prepare work for `$project-issue`. Keep canonical plans in `docs/superpowers/plans`; never place canonical plans under `docs/superpowers/milestones/<milestone>/plans`.

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

After saving and self-reviewing the plan, summarize the plan in chat before asking the continuation question. The summary must name the saved plan path, source spec or issue mirror, acceptance coverage, proof oracle, TDD/debug policy, and recommended next route.

Ask a native continuation question when `request_user_input` is callable. This question is executable routing, not advisory text.

Question id: `project_plan_next_step`

Prompt: `How should I continue from this project plan?`

Options:

- `Project Issue First`: continue to `$project-issue` using the saved plan path.
- `Quick Apply`: apply a small, explicitly approved local-main change through the bundled Quick Apply gate.
- `Review First`: stop for user review before issue creation or execution.
- `Revise Plan`: continue `$project-plan` to revise the saved plan.
- `Stop`: stop after the plan closeout.

Recommend `Project Issue First` for repos using the Superpowers Project GitHub issue backbone. Recommend `Quick Apply` only for small, guarded, explicitly approved local-main work that passes its gate.

After the user selects an option, start the selected next skill in the same turn when tools and state allow it. Carry forward the saved plan path, source spec or issue mirror path, decisions, acceptance criteria, and proof oracle. Do not only tell the user what to prompt next.

If the selected next skill needs its own material decision, ask that next skill's native UI question. If the route needs unavailable tools or an external write that still requires approval, stop with a clear pending state and exact resume target.

## Self-Review

Before reporting the plan ready:

1. Confirm the save path is under `docs/superpowers/plans`.
2. Confirm the source spec, source issue mirror, or direct-plan approval is named.
3. Confirm every acceptance criterion maps to at least one task.
4. Confirm each task names exact files and exact verification.
5. Confirm feature and bug work uses `superpowers:test-driven-development` or records the user's explicit opt-out.
6. Confirm bug work uses `superpowers:systematic-debugging` or diagnose discipline.
7. Confirm completion requires `superpowers:verification-before-completion`.
