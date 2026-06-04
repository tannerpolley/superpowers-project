---
name: advanced-user-input
description: Use when choosing native user-input prompts, bulk question gates, large option menus, sequential branch prompts, Custom answers, or worker-to-orchestrator input.
---

# Advanced User Input

Use the richest input shape that makes the decision clear. Native `request_user_input` is the default for bounded choices, including large option sets and bulk decision checkpoints. Normal chat is for exact text. `request_agent_input` is a written worker-to-orchestrator protocol, not a runtime tool.

## Core Rule

Use as many native questions and options as the decision requires.

Do not collapse real routes into fake categories just to fit old 1-3 question or 2-3 option guidance. Current Codex Desktop testing showed much larger native prompts work, including 20 questions and 20 options. Treat that as current runtime-permissive behavior, not a public guarantee.

If the active runtime rejects a large prompt, fail loudly, explain the rejected shape, and retry with sequential branch prompts. Do not silently remove routes, merge distinct actions, or proceed on a fake default.

## Observed Codex Desktop Behavior

Observed Codex Desktop behavior accepted native prompts larger than the visible guidance, including at least 20 questions in one call and 20 options on one question. Use that capability when it improves workflow correctness, but keep the rejection path above because future runtimes may validate more strictly.

## Input Choice

| Need | Use |
|---|---|
| Bounded choices, approvals, routes, modes, checklists | `request_user_input` |
| Many independent decisions needed before one action | One bulk `request_user_input` call |
| Later questions depend on an earlier answer | Sequential native calls |
| Exact names, paths, URLs, IDs, commands, prose | Normal chat |
| Worker agent needs direction from orchestrator agent | `request_agent_input` protocol |

Before asking, inspect what the repo, files, logs, GitHub state, or thread context can answer. Ask only for decisions that remain genuinely unresolved.

## Native Prompt Policy

Use native Q&A confidently for:

- 4+ options when all options are real peer routes.
- 4+ questions when the answers are independent and all are needed at the same checkpoint.
- formal workflow gates such as continue routes, publish approval, merge approval, branch strategy, verification level, cleanup choice, or orchestration topology.
- strict state-machine routing where every option maps to a real next action.

Keep prompts smaller when fewer choices are clearer. Small prompts are a usability preference, not a hard limit.

Do not add an explicit `Other` option. The client provides free-form Other. When the user chooses Other, validate the custom answer before executing it. If it clearly means stop or done, stop. Otherwise ask the next best native follow-up or normal-chat clarification.

## Sequential Branching

Native prompts do not expose dynamic fields such as `showIf`, `dependsOn`, or `nextQuestion`. Use agent-controlled sequential branching:

1. Ask the top-level route.
2. Read the selected route.
3. Ask only that route's follow-up questions.
4. Skip unrelated branch questions.
5. Repeat until the decision reaches an executable route, explicit stop, or blocker.

Use this when the first answer changes which questions matter.

Example:

```text
Question: How should this continue?
Options: Plan, Issue, Implement, Resolve, Doctor, Stop

If Plan -> ask plan scope questions.
If Resolve -> ask issue, branch, and verification questions.
If Stop -> stop.
```

## Bulk Question Sets

Use one larger native call when every question is independent and needed before the next action.

Good bulk gate:

- publish now or keep local;
- branch or worktree strategy;
- verification depth;
- cleanup behavior;
- whether to show generated artifacts.

Bad bulk gate:

- questions for `Resolve` mixed with questions that only apply to `Doctor`;
- implementation details that depend on a branch the user has not chosen;
- exact text fields disguised as multiple choice.

Use stable question IDs because answer order may not be meaningful.

## Large Option Sets

Show all peer options at once when that makes the workflow easier to understand.

Good large menu:

```text
Project Plan
Project Issue
Project Implement
Project Resolve
Project Orchestrate
Project Merge
Project Doctor
Stop
```

Bad large menu:

```text
Option 1
Option 2
Option 3
Option 4
...
```

Each option needs a short label, a concrete action, and a distinct consequence. If the list is long because it is selecting from data, show the data in chat or a file first, then ask the native route question.

## Continuation Gates

For workflow closeout, preserve the user's direction model:

- Down means progress or default move-on.
- Left means revise, review, repair, rerun, recover, or gather more evidence.
- Right means stop or done.

This model is a visual and mental default. It does not require exactly three options. If there are more real forward routes, show them. If a top-level Down / Left / Right prompt would clarify the first decision, use it, then show the selected branch's full option set.

Do not end a loop until the user chooses an executable route, explicit stop/done, or provides a Custom answer that clearly means stop/done.

## Normal Chat For Exact Text

Use normal chat for values that should not be approximated:

- names, titles, paths, URLs, issue numbers, branch names, labels, commands, IDs;
- paragraphs, requirements, rationale, acceptance criteria, or review notes;
- anything where choices would bias the answer.

Ask for exact text directly:

```text
Please reply with only the branch name:
```

For several values:

```text
Please reply with:
Title:
Path:
Success criteria:
```

## request_agent_input

`request_agent_input` is a written protocol for worker agents asking orchestrator agents for direction. It is not a runtime tool.

Use it only when:

- the current agent is clearly a worker/subagent;
- another agent or thread is clearly the orchestrator;
- the worker needs planning, scope, approval, routing, or conflict-resolution input.

Do not use it in an ordinary user-facing root thread. Use native `request_user_input` or normal chat there.

Format:

```text
request_agent_input

Context:
- <one to five relevant facts>

Questions:
1. <short header>
   Question: <specific question>
   Options:
   A. <recommended option> - <impact>
   B. <option> - <impact>
   C. <option> - <impact>
   D. <option if useful> - <impact>
   Custom: <what to provide if none fit>

Response format:
- Answer each question by number and option letter/name.
- Add details after the answer only when needed.

Waiting for orchestrator response.
```

Ask as many questions and options as the orchestrator decision requires. If later questions depend on earlier answers, ask the current blocking batch first, then ask the follow-up after the orchestrator responds.

## Failure Handling

If native Q&A is unavailable, say so and ask in normal chat.

If a large native prompt fails because of runtime validation:

1. Report the failed shape, such as `5 questions x 8 options`.
2. Retry with sequential branch prompts.
3. Preserve every real route from the original prompt.
4. Do not invent a default or drop an option to keep moving.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Forcing all prompts into three options | Show all real peer routes when the UI supports it. |
| Asking dependent branch questions in one bulk prompt | Ask the route first, then only the selected follow-up. |
| Using choices for exact text | Ask in normal chat. |
| Treating Custom as executable without validation | Clarify or route it deliberately. |
| Hiding stop/done | Always make stop/done available at formal workflow gates. |
| Proceeding after a rejected native prompt | Fail loudly, then retry sequentially without losing routes. |
