---
name: milestone-writing-issue-plan
description: Use when writing or revising a detailed implementation plan for a GitHub issue in a repo that uses docs/milestones issue files.
---

# Milestone Writing Issue Plan

This is the Milestones-native adaptation of `superpowers:writing-plans`. It writes the detailed execution plan into the synced local issue file for exactly one GitHub issue.

**Announce at start:** "I'm using the milestone-writing-issue-plan skill to create the Milestones issue plan."

## Destination Contract

Save the plan only in the issue file:

- Issue number known: `docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md`
- Issue number not yet known: `docs/milestones/<milestone-folder>/issues/<slug>.md`

Never write Milestones issue plans to `docs/superpowers/plans`. Also do not create `docs/plans`, `docs/milestones/<milestone-folder>/plans`, or a separate non-issue plan file.

## Required Intake

Do not write the plan until the issue record, user, or repo docs provide every item below:

- GitHub issue URL
- Issue title
- Issue type
- Milestone title and milestone folder
- Acceptance criteria
- Non-goals
- Proof oracle
- Candidate files, or the explicit statement `candidate files unknown`

If candidate files are unknown, perform a narrow repo inspection before writing implementation tasks. If exact files still cannot be named, stop with `Blocked by skill contract: candidate files remain unknown after inspection`.

## Scope

This skill writes or revises the local issue plan only. It does not implement product code, create branches, start GoalBuddy boards, open PRs, merge, close issues, or migrate milestone setup.

Use `$milestones-doctor` for milestone workflow audits or repairs. Use `$resolve-issue-with-goal` when the issue is ready for execution.

## Issue File Shape

Every issue plan must include these sections near the top of the local issue file:

```markdown
# <Issue Title> Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**GitHub Issue:** <GitHub issue URL>
**Issue Type:** <bug|feature|task|repo-supported type>
**Milestone:** <milestone title> (`docs/milestones/<milestone-folder>`)

**Goal:** <one sentence describing the finished outcome>
**Architecture:** <2-3 sentences about the approach and boundaries>
**Tech Stack:** <languages, frameworks, packages, test tools, and commands>

**Acceptance Criteria:**
- <criterion>

**Non-Goals:**
- <excluded work>

**Proof Oracle:** <exact evidence that proves completion>

**Candidate Files:**
- `<exact/path>`

---
```

Replace angle-bracket examples with real content before saving. The saved plan must not contain placeholders.

## Planning Discipline

Preserve the `superpowers:writing-plans` standard:

- Start with Goal, Architecture, and Tech Stack.
- Map exact files before task decomposition.
- Use checkbox tasks with `- [ ]` for every step.
- Each task names exact files to create, modify, and test.
- Each step is bite-sized and executable.
- Code-changing steps include complete code or exact patch instructions.
- Verification steps include exact commands and exact expected results.
- Keep DRY and YAGNI.
- Use frequent commits when execution will happen across multiple tasks.

## Test And Debug Discipline

- Feature and bug plans require `superpowers:test-driven-development` unless the user explicitly opts out in the issue plan.
- Debugging plans require `superpowers:systematic-debugging` before proposing a fix.
- Completion steps require `superpowers:verification-before-completion` before any worker claims the issue is complete.
- A proof oracle is mandatory: it must name the command, user-visible behavior, artifact, or GitHub evidence that proves the issue is done.

## Task Structure

Use this shape for each task:

````markdown
### Task N: <specific component or behavior>

**Files:**
- Create: `exact/path/to/new-file.ext`
- Modify: `exact/path/to/existing-file.ext`
- Test: `exact/path/to/test-file.ext`

- [ ] **Step 1: Write the failing test**

```text
<complete test code or exact test edit>
```

- [ ] **Step 2: Run the test and verify it fails for the expected reason**

Run: `<exact command>`
Expected: `<exact failing result>`

- [ ] **Step 3: Implement the minimal change**

```text
<complete implementation code or exact patch instruction>
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `<exact command>`
Expected: `<exact passing result>`

- [ ] **Step 5: Commit the task**

Run: `git add <exact files> && git commit -m "<message>"`
````

Adjust the steps to the repo's actual tools and issue type. Do not leave generic commands, unknown files, or vague expected results.

## No Placeholders

These are plan failures:

- `TBD`, `TODO`, `later`, or `fill in details`
- "Add appropriate error handling" without exact cases and code
- "Write tests" without exact test content
- "Similar to previous task"
- "Run relevant tests"
- References to functions, types, files, or commands not defined in the plan

## Self-Review Before Saving

Before reporting the plan complete:

1. Confirm the save path is under `docs/milestones/<milestone-folder>/issues/`.
2. Confirm the file is not under `docs/superpowers/plans`.
3. Check every required intake field is present in the issue file.
4. Check each acceptance criterion maps to at least one task.
5. Check every task has exact files and exact verification.
6. Search the plan for placeholder language and remove it.
7. Check feature and bug tasks use TDD, or record the user's explicit opt-out.
8. Check debugging tasks require systematic debugging.
9. Check completion tasks require verification before completion.

## Completion Response

After saving the issue plan, report:

- The local issue file path.
- The GitHub issue URL.
- The milestone title and folder.
- The proof oracle.
- Any explicit user opt-out from TDD.

Do not start execution unless the user asks for execution next.
