---
name: advanced-user-input
description: Use when choosing native user-input prompts, bulk question gates, large option menus, sequential branch prompts, Custom answers, or worker-to-orchestrator input.
---

# Advanced User Input

Use the richest input shape that makes the decision clear. Native `request_user_input` is the default for bounded choices, including large option sets and bulk decision checkpoints. Normal chat is for exact text. `request_agent_input` is a written worker-to-orchestrator protocol, not a runtime tool.

## Core Rule

Use the smallest native question shape that preserves the real decision tree.

## Lifecycle Mode Policy

For a started Superpowers Project workflow, resolve every routine graph-owned gate through `scripts/workflow-run.sh -Action resolve-gate` and reuse the existing run root and authorization ledger.

- `Manual` returns `ask`; render native input, then record the user's option with `-SelectedOption`.
- `Auto` and `Looping` return `decide` for the owner skill's safe recommendation without native input.
- Every mode returns `block` when no option remains inside startup scope or existing proof policy.

Auto covers one requested outcome across skill boundaries, not one skill invocation. Looping applies the same rule inside each candidate and uses its startup budget and health checks between candidates. Never pass `-SelectedOption` for Auto or Looping, widen the startup scope, or treat a recommendation as permission to bypass proof.

This lifecycle mode policy takes precedence over the Manual-oriented prompting instructions below: where they say to ask a workflow gate, Auto and Looping resolve that gate through the runtime instead.

Do not collapse real routes into fake categories just to fit old 1-3 question or 2-3 option guidance. Current Codex Desktop testing showed much larger native prompts work, including 20 questions and 20 options. Treat that as current runtime-permissive behavior, not a public guarantee.

For project workflow closeout gates, always ask the three-way trajectory question first. Ask the top-level closeout as Continue? Use Yes for the progress route. Use Revisit as the standard go-back route label unless a more specific local label is materially clearer. Use Stop for mid-loop exits. Use Done only for verified final states. Do not flatten closeout into a five-option or larger peer menu. If Yes or Revisit needs more detail, ask the nested branch question after that answer.

Use larger native prompts only inside a selected branch, in data-backed selection menus, or for independent bulk decisions that are all needed before one action.

If the active runtime rejects a large prompt, fail loudly, explain the rejected shape, and retry with sequential branch prompts. Do not silently remove routes, merge distinct actions, or proceed on a fake default.

## Observed Codex Desktop Behavior

Observed Codex Desktop behavior accepted native prompts larger than the visible guidance, including at least 20 questions in one call and 20 options on one question. Use that capability when it improves workflow correctness, but keep the rejection path above because future runtimes may validate more strictly.

## Native Question Debug Mode

`debug_question_mode` is not a normal workflow path. Use it only for explicit non-interactive smoke tests, or when a background-thread native prompt is proven stuck in `waitingOnUserInput` and no tool exists to answer the modal prompt.

Record a Native Question Debug Ledger before executing the selected answer. Each ledger entry must include:

- `skill_name`
- `thread_id`
- `observed_status: waitingOnUserInput`
- `question_id`
- `prompt`
- `options`
- `recommended_option`
- `selected_answer`
- `answer_source: recommended-default | user-provided-debug-answer`
- 
o_answer_tool_available: true`
- `mutation_allowed: false`

`debug_question_mode` must not approve mutation, substitute for a live user decision in normal work, publish, push, merge, create worker threads, grant scope approval, or grant route approval. If the route would mutate external state or rely on live user permission, stop with the exact pending state or ask the next native question instead.

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

- 3-option workflow closeout trajectory gates.
- 4+ options inside a selected Yes or Revisit branch when all options are real peer routes.
- 4+ questions when the answers are independent and all are needed at the same checkpoint.
- formal workflow gates such as continue routes, publish approval, merge approval, branch strategy, verification level, cleanup choice, or orchestration topology.
- strict state-machine routing where every option maps to a real next action.

Keep prompts smaller when fewer choices are clearer. Small prompts are a usability preference, not a hard runtime limit. For project workflow closeout, the top-level question is always the three-way Continue? gate, even when the Yes branch has several real next skills.

Do not add an explicit `Other` option. The client provides free-form Other. When the user chooses Other, validate the custom answer before executing it. Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other. Do not infer terminal intent from ambiguity, frustration, or a loose completion claim. Otherwise ask the next best native follow-up or normal-chat clarification and keep the workflow running.

## Sequential Branching

Native prompts do not expose dynamic fields such as `showIf`, `dependsOn`, or 
extQuestion`. Use agent-controlled sequential branching:

1. Ask the top-level route.
2. Read the selected route.
3. Ask only that route's follow-up questions.
4. Skip unrelated branch questions.
5. Repeat until the decision reaches an executable route, explicit stop, or blocker.

Use this when the first answer changes which questions matter.

Example:

```text
Question: Continue?
Options: Yes, Revisit, Stop

If Yes -> ask Plan, Issue, Implement, Resolve, Align, or other valid progress route.
If Revisit -> show evidence, ask the review/revision route, then return to the same closeout gate.
If Stop -> stop.
```

Nested Yes-route menus must not include terminal options. They show only real forward routes. If no forward route is safe, do not ask a nested Yes-route menu; report the blocker or return to the top-level gate with evidence.

Nested Revisit-route menus must not include terminal options. They show only real review, revise, repair, rerun, recover, or evidence-gathering routes and then return to the originating top-level gate.

## Bulk Question Sets

Use one larger native call when every question is independent and needed before the next action.

Good bulk gate:

- publish now or keep local;
- branch or worktree strategy;
- verification depth;
- cleanup behavior;
- whether to show generated artifacts.

Bad bulk gate:

- questions for `Resolve` mixed with questions that only apply to `Align`;
- implementation details that depend on a branch the user has not chosen;
- exact text fields disguised as multiple choice.

Use stable question IDs because answer order may not be meaningful.

## Large Option Sets

Show all peer options at once only after the top-level closeout trajectory is already selected, or when the prompt is not a workflow closeout gate.

Good large menu:

```text
Yes selected.
Project Plan
Project Issue
Project Implement
Project Resolve
Project Orchestrate
Project Merge
Project Align
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

- Down is shown to the user as Yes and means progress or default move-on.
- Left is shown to the user as Revisit and means revise, review, repair, rerun, recover, or gather more evidence.
- Right is shown as Stop during unfinished workflow closeout and Done only at proven final closeout.

Use Stop for mid-loop exits. Use Done only for verified final states.

Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop. A saved spec, saved plan, created issue set, PR-ready branch, or PR-ready worker handoff is not final completion.

Final clean closeout gates may use Yes, Revisit, and Done only after verified final proof and a clean worktree. custom answers that claim completion before proof exists are treated as Stop only after the explicit terminal confirmation gate; otherwise they remain non-terminal Revisit behavior.

Verified final health gates use exactly three top-level options: Done, Revisit, and Stop. Done is valid only after a skill proves a final state, such as clean merge closeout proof or an explicit healthy audit gate with no remaining repair route, and the repo worktree is clean. Done is invalid whenever `git status --short` is non-empty. A verified final Done gate requires final proof and a clean worktree.

Before any continuation, permission, push, publish, or merge question, complete an artifact review gate. Strict artifact display is mandatory and must happen before the summary or native question. Do not merely say something changed. Show what was created or revised for every produced or materially changed artifact with an exact path or identifier. Render human-readable Markdown artifacts when reasonably sized, including the chosen brainstorm design/spec, the full plan task and step list, and the full issue mirror or created issue body. For implementation or issue-resolution work, show the full changed-artifact inventory before push, plus verification commands, exact test values/results, cleanup evidence, branch state, push/PR proof when present, and any machine-readable ledgers with their key fields and decisions. If an artifact is too large for full chat rendering, show its path, type, action, exact sections changed, representative diff or snippet, and the reason the full render is omitted. Say when an expected artifact type was not produced.

### Artifact Review Card Schema

Use an Artifact Review Card for every continuation, push, publish, and merge gate. The card is a display-before-question artifact: show it in chat before the findings summary and before the native question. Route skills may add route-specific artifact inventory, but they must not remove these fields:

- `Gate`: continuation, push, publish, or merge.
- `Created/changed`: exact paths or stable external identifiers for every produced or materially changed artifact, plus the action taken.
- `Proof`: commands, validator receipts, issue/PR evidence, cleanup proof, and exact pass/fail status.
- `Decisions`: selected route, approval, merge, publish, or continuation decisions that matter for the next action.
- `Risks`: remaining risk, caveat, or explicit none statement, with a risk owner for every listed item.
- `Recommended next route`: the next workflow route or terminal gate that the evidence supports.

Large artifact excerpt rule: when a full render is too large for chat, the card must still list the exact path or identifier, artifact type, action taken, exact sections changed, representative excerpt or diff, why the full render is omitted, and where the complete artifact exists.

After the artifact review gate, add a separate findings summary that states what was done, what was fixed, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the results say, what the agent thinks those results mean, what that means for the active goal, what that means for the broader project context, and what next steps are now recommended.

Push, publish, and merge approval questions are invalid until the artifact review gate and findings summary have been shown.

If observed behavior conflicts with repo-owned workflow contracts, treat it as a stale-thread recovery case. Warn that the loaded thread may still be using older skill text, identify the missed gate or missing route, re-ask that gate natively, and continue from the corrected route instead of treating the skipped step as terminal or implicit approval.

Revisit is non-terminal. Yes must start the selected progress route or ask the blocking child question. Revisit must show/review/repair/gather evidence, ask follow-up questions when needed, and return to the originating continuation gate. Review First is not a terminal answer. Only Stop can end an intermediate continuation loop before a verified final Done gate. The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion. Do not recommend Stop merely because a clean forward route exists, because the current branch is already healthy, or because the original request was narrower than the selected workflow route when the user has not asked to stop.

This model is the first prompt for every project workflow closeout. Ask exactly three top-level options: Yes, Revisit, and Stop. If Yes has multiple possible next skills, ask a nested route menu after Yes; for example, Write Plan -> Yes -> Create Issues or Implement Plan. If Revisit has multiple possible reiteration routes, ask a nested review menu after Revisit. Do not put Continue children beside Revisit and Stop in the same top-level question. Do not compress the top-level Continue? gate and a nested route decision into one prompt, one prose acknowledgement, or one inferred selection. If multiple forward or review routes exist, ask the top-level gate first and then the matching nested question.

In Manual, do not end a loop until the user chooses Stop or reaches a verified final Done gate through a built-in terminal option. Custom Other never terminates a workflow directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels instead of terminating from Other. Do not infer terminal intent from a Custom answer. Custom answers that request revision, review, repair, more evidence, a different route, or stronger loop behavior are Revisit behavior. Custom answers that ask for another route, review, revision, repair, explanation, or continued work are non-terminal and must continue through the next follow-up question or route. Custom answers that claim completion before proof exists are invalid terminal claims; report the remaining lifecycle state and continue with the next follow-up question instead of converting them to Stop. After executable routes, Manual asks the next native gate; Auto and Looping resolve it through the runtime.

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
| Flattening a closeout gate into five or more options | Ask Continue? with Yes, Revisit, and Stop first; ask peer routes only inside the selected branch. |
| Asking dependent branch questions in one bulk prompt | Ask the route first, then only the selected follow-up. |
| Using choices for exact text | Ask in normal chat. |
| Treating Custom as executable without validation | Clarify or route it deliberately. |
| Treating Review First as a stopping point | Show evidence, ask follow-up questions, then return to the originating continuation gate. |
| Omitting the terminal gate option | Keep `Stop` available at intermediate top-level closeout gates and `Done` available only at verified final gates. |
| Proceeding after a rejected native prompt | Fail loudly, then retry sequentially without losing routes. |
