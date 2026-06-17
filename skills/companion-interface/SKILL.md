---
name: companion-interface
description: Use when a Superpowers Project workflow should create or update a repo-owned Agent-Native visual-plan MDX artifact for rich review.
---

# Companion Interface

Companion Interface is the Superpowers Project rich review channel. It creates or refreshes repo-owned BuilderIO/Agent-Native visual-plan MDX artifacts.

Use this skill when a governed workflow produces specs, plans, issue evidence, validation receipts, screenshots, diagrams, plots, tables, or long summaries that need structured review outside chat.

## Approval Boundary

The companion must not record approval, push, publish, merge, live sync, GitHub mutation, or final Done. Native Codex chat and `request_user_input` remain the decision authority.

## Visual-Plan Source Model

Write local review artifacts under `plans/<slug>/`.

Required:

- `plans/<slug>/plan.mdx`

Optional:

- `plans/<slug>/canvas.mdx` when static visual review is useful.
- `plans/<slug>/prototype.mdx` when interaction review is useful.
- `plans/<slug>/.plan-state.json` when Agent-Native local tooling writes editor state.

Canonical Superpowers specs, implementation plans, issue mirrors, and milestone pages remain under `docs/superpowers/`.

## Tooling

Before authoring MDX, fetch the Agent-Native block catalog with an available schema-only tool or:

```powershell
npx @agent-native/core@latest plan blocks --out <catalog-path>
```

After writing or revising the folder, run:

```powershell
npx @agent-native/core@latest plan local preview --dir plans/<slug> --kind plan --open
```

Report the `plan.mdx` path and returned preview URL or exact failure.

## Hosted Plan Tools

If hosted Plan MCP tools are visible in the active session, they may be used for hosted creation or publishing when the workflow permits it. When tools are not visible, use local-files mode and do not repeat failed hosted authentication polling.

## Native Continuation Loop

Do not end the turn or report the workflow complete until a native continuation question returns `Stop` or reaches a verified final `Done` gate.

After every completed action, summarize the result and ask another native continuation question when `request_user_input` is callable.

Only a user-selected `Stop` option or verified final `Done` gate is terminal. A pushed commit, merged PR, created issue, saved plan, completed audit, or synced live plugin is not terminal.

Revisit is non-terminal. Only Stop can break an intermediate loop before a verified final Done gate. Review First is not a terminal answer.

The agent must not get out of the loop by itself, and ending a turn after a governed workflow action is invalid until the next native continuation or permission question is answered.

The agent must not recommend Stop before verified final completion.

## Native Continuation Gate

Ask the top-level closeout question as Continue? with exactly these trajectory options: Yes, Revisit, and Stop.

The top-level closeout question must use exactly three trajectory options. Do not show Continue children as peer top-level options.

Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires.

Custom Other never terminates a workflow directly. If Custom Other requests Stop or Done, ask a fresh confirmation question with separate built-in labels instead of terminating from Other.

Nested Yes-route menus must not include terminal options. Nested Revisit-route menus must not include terminal options.

Recommend Yes when at least one safe forward route exists. Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion.

Revisit routes must show or gather evidence, ask follow-up questions when needed, and return to the originating continuation gate.

## Artifact Review Gate

Before any closeout or permission question, complete the artifact review gate. Strict artifact display is mandatory.

Show the created or revised visual-plan folder, `plan.mdx`, optional `canvas.mdx` or `prototype.mdx`, preview URL or failure, linked canonical Superpowers artifact paths, rendered Markdown artifacts when present, and machine-readable artifacts with exact paths plus key fields.

Do not merely say something changed. State what was done, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the agent thinks those results mean, the active-goal impact, the broader project context, and the recommended next route.
