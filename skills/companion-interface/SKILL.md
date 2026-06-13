---
name: companion-interface
description: Use when a Superpowers Project workflow should create or update the local HTML companion report for rich artifact review.
---

# Companion Interface

Companion Interface is the Superpowers Project evidence and interpretation channel. It writes repo-scoped report sessions and renders a static HTML workbench for the Codex in-app browser.

Use this skill when the user asks to show rich artifacts, when a workflow produces large specs or plans, or when implementation evidence includes plots, tables, validation receipts, screenshots, diagrams, or long summaries.

## Approval Boundary

The companion must not record approval, push, publish, merge, live sync, GitHub mutation, or final Done. Native Codex chat and `request_user_input` remain the decision authority.

## Report Model

Use `scripts/new-report-session.ps1 -WorkflowName <name> -Title <title>` to create a session.

Use `scripts/append-event.ps1 -ReportRoot <relative-report-root> -Type <event-type> -Title <title>` to add structured evidence.

Use `scripts/render-report.ps1 -ReportRoot <relative-report-root>` to regenerate `index.html`.

Generated reports live under `.superpowers/reports/<yyyy-mm-dd>/<run-id>`.

## Required Closeout

After updating a report, tell the user the exact `index.html` path and the artifact types added. Keep chat concise and point detailed review to the companion.

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

Show the created or revised report session, generated `index.html`, manifest, events file, artifact paths, rendered Markdown artifacts when present, and machine-readable artifacts with exact paths plus key fields.

Do not merely say something changed. State what was done, what remains unsatisfactory or risky, the agent's own feedback/opinion, what the agent thinks those results mean, the active-goal impact, the broader project context, and the recommended next route.
