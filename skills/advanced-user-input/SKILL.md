---
name: advanced-user-input
description: Use when choosing native user-input prompts, bulk decision gates, sequential branch prompts, Custom answers, or worker-to-orchestrator input.
---

# Advanced User Input

Use the smallest input shape that preserves the decision tree. Native `request_user_input` handles bounded choices; normal chat collects exact text. `request_agent_input` is a written worker protocol, not a runtime tool.

## Lifecycle Mode Policy

After a Superpowers Project workflow starts, resolve graph-owned gates through `scripts/workflow-run.sh -Action resolve-gate` with the existing run root. Pass only `-GateId` and the owner skill's `-Recommendation`; the runtime loads authorization and options from `docs/superpowers/workflow-contract.yml`. Caller-supplied options or authority are invalid.

- `Manual` returns `ask`; render native input and record the user's choice with `-SelectedOption`.
- `Auto` and `Looping` return `decide` when the safe recommendation remains authorized.
- Every mode returns `block` when proof or startup scope excludes every option.

Auto owns one requested outcome across routes. Looping applies that policy to one candidate at a time and requires budget, health, and continuation proof between candidates. Never pass `-SelectedOption` for Auto or Looping or widen startup scope.

## Question Shapes

| Need | Input |
|---|---|
| Bounded choice, approval, route, mode, or checklist | `request_user_input` |
| Two or three independent decisions required before one action | One bulk native call |
| A later question depends on an earlier answer | Sequential native calls |
| Exact name, path, URL, ID, command, or prose | Normal chat |
| A worker needs orchestrator direction | `request_agent_input` protocol |

Inspect repository and thread evidence before asking. The current native schema accepts one to three questions with two or three options each. Preserve larger route sets through parent and child questions; never drop a route or choose a default to fit the limit.

Do not add an explicit Other option; the client supplies it. Validate Custom answers before execution. Custom Other never terminates a workflow directly. A Custom request for Stop or Done requires a new native confirmation with built-in terminal labels. Treat review, revision, repair, more evidence, or another route as Revisit behavior.

## Sequential And Bulk Branching

Use sequential calls when an answer changes which questions matter:

1. Ask the parent route.
2. Read its answer.
3. Ask only that branch's follow-ups.
4. Continue until an executable route, confirmed terminal choice, or blocker.

Nested Yes menus contain forward routes. Nested Revisit menus contain review, repair, rerun, recovery, or evidence routes and return to the parent gate. Neither nested menu contains terminal options. Page route sets larger than three through another named branch question. Use one bulk call only when every answer is independent and required before the same action. Use stable question IDs.

## Continuation Gates

Ask the top-level trajectory before child routes.

- Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop.
- Verified final health gates use exactly three top-level options: Done, Revisit, and Stop.

Use Stop for mid-loop exits. Use Done only for verified final states. A verified final Done gate requires final proof and a clean worktree. Saved artifacts, created issues, and PR-ready handoffs remain intermediate.

Revisit is non-terminal: review, repair, or gather evidence, then return to the same gate. Yes starts its route or asks the blocking child question. Manual continues until the user confirms Stop or reaches verified Done. Auto and Looping resolve the next gate through the runtime. The agent never recommends Stop while a safe forward route exists.

A completion claim without proof is non-terminal. Report the missing proof and continue; only the built-in Stop option can stop the workflow.

## Artifact Review Gate

Before continuation, push, publish, or merge, display changed artifacts and proof before asking. Render reasonably sized Markdown. For large artifacts, provide the exact path or identifier, type, action, sections changed, representative excerpt or diff, omission reason, and location of the complete artifact. State when an expected artifact was not produced.

Use an Artifact Review Card with:

- `Gate`: continuation, push, publish, or merge.
- `Created/changed`: every material path or stable external identifier and action.
- `Proof`: commands, receipts, external evidence, cleanup, and pass/fail status.
- `Decisions`: choices that govern the next action.
- `Risks`: each remaining risk and owner, or `none`.
- `Recommended next route`: evidence-supported route or terminal gate.

Follow the card with a concise findings summary: completed work, remaining defects or risk, result interpretation, goal impact, and recommendation. Push, publish, and merge approval are invalid before both displays.

If observed behavior conflicts with repository contracts, identify the stale rule, warn that the thread may hold old skill text, and re-ask the missed native gate.

## Native Question Debug Mode

Use `debug_question_mode` only for explicit non-interactive smoke tests or a background thread proven stuck in `waitingOnUserInput` with no answer tool. Record `skill_name`, `thread_id`, status, question ID, prompt, options, recommendation, selected answer, answer source, `no_answer_tool_available: true`, and `mutation_allowed: false`.

Debug mode cannot approve mutation, publication, push, merge, worker creation, scope, or routing. Stop when the pending route needs live permission.

## request_agent_input Protocol

Workers use this written shape when an orchestrator must decide scope, approval, routing, or conflicts:

```text
request_agent_input

Context:
- <relevant facts>

Questions:
1. <header>: <question>
   A. <recommended option> - <impact>
   B. <option> - <impact>
   Custom: <required details>

Response format: answer by number and option; add details only when needed.
Waiting for orchestrator response.
```

Root threads use native user input or normal chat. Workers ask dependent follow-ups after the orchestrator answers the current batch.

## Failure Handling

If native input is unavailable, state that and use normal chat. If a native prompt fails validation, report the rejected shape, preserve every route, and retry with smaller sequential calls.
