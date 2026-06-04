# Native Q&A Continuation Recommendation Design

## Purpose

Fix friction in the Superpowers Project native question flow where `Stop / Done` can appear as the recommended option and where nested route questions repeat `Stop / Done` immediately after the user already chose the progress path.

This spec covers native Q&A behavior and skill contract wording. It does not change the SVG or Mermaid diagrams directly unless implementation planning decides the diagrams need companion updates.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines native user-input grilling and durable workflow routing as core Superpowers Project behavior.
- `skills/advanced-user-input/SKILL.md` says project workflow closeouts should begin with the three-way `Continue?` gate: `Yes`, `Revisit`, and `No / Stop / Done`.
- `skills/advanced-user-input/SKILL.md` also says peer routes should be asked only after the top-level route is selected, but its large-menu example still includes `Stop` after the user has selected `Yes`.
- Active project skills consistently repeat `Right: Stop / Done` in nested route questions after a user selects a progress or revisit branch.
- The native input tool presents the recommended option first, so any skill wording or agent habit that puts `Stop / Done` first makes stopping look like the preferred path.
- User feedback from June 4, 2026: `Stop / Done` is often recommended, and selecting the down/continue path still leads to another question with `Stop / Done`.

## User Decisions

- After the user chooses `Yes` or `Continue`, nested route questions should be forward-only.
- `Stop / Done` should almost never be recommended.
- Save this as a brainstorm spec before planning or implementation.

## Recommended Behavior

Formal top-level closeout gates keep the three-way model:

- `Yes`: progress to the next workflow depth.
- `Revisit`: review, revise, repair, rerun, recover, or gather evidence.
- `No / Stop / Done`: break the workflow loop.

After `Yes` is selected, nested route questions should only present real forward routes. They should not include `Stop / Done` as a routine third option.

After `Revisit` is selected, nested route questions should only present real revisit routes. They should not include `Stop / Done` as a routine third option. Revisit routes should show evidence or ask focused follow-up questions, then return to the originating `Continue?` gate.

`Stop / Done` remains available at:

- formal top-level closeout gates;
- explicit final `Healthy? -> Done` gates;
- risky permission or approval gates where decline/cancel is the actual decision;
- blocker states where there is no safe executable next route;
- custom user input that clearly asks to stop, pause, or be done.

## Recommendation Policy

The recommended option should be the first option shown to the native UI.

For top-level closeout gates:

- Recommend `Yes` when at least one safe, valid next workflow route exists and the user has not asked to pause.
- Recommend `Revisit` when evidence is incomplete, the artifact has unresolved material ambiguity, validation failed, or the next safe action is review/repair.
- Recommend `No / Stop / Done` only when the workflow has reached an explicit terminal state, there is no safe next route, or the user has explicitly indicated they want to stop.

For nested `Yes` branch questions:

- Recommend the safest or most natural forward route.
- Do not include `Stop / Done`.
- If no forward route is safe, do not ask the nested route question; return to the top-level gate or ask a blocker-specific question.

For nested `Revisit` branch questions:

- Recommend the revisit action that removes the strongest remaining ambiguity or risk.
- Do not include `Stop / Done`.
- Return to the originating top-level gate after the revisit action.

For approval gates:

- Use domain-specific labels such as `Approve`, `Decline`, `Review First`, `Push`, `Keep Local`, `Merge`, or `Do Not Merge`.
- Do not label approval decline as `Stop / Done` unless it actually ends the workflow.
- Recommend the action supported by clean evidence. For example, recommend `Merge` only after merge proof is clean.

## Skill Contract Changes Needed

Update `advanced-user-input` so it explicitly distinguishes:

- top-level closeout gates, which include `No / Stop / Done`;
- nested route menus after `Yes`, which are forward-only;
- nested route menus after `Revisit`, which are revisit-only;
- permission gates, which use approval-specific labels and recommendations.

Update every project skill that currently puts `Right: Stop / Done` inside nested route questions:

- `setup-project`
- `brainstorm-spec`
- `write-plan`
- `create-issues`
- `resolve-issue`
- `orchestrate-issues`
- `implement-plan`
- `merge-changes`
- `audit-project`
- `initiate-workflow` shared continuation guidance

Update `agents/openai.yaml` metadata for the same skills so the runtime prompt no longer teaches agents to include `Stop / Done` in nested branch prompts.

Update tests so they enforce:

- top-level closeout gates include `Yes`, `Revisit`, and `No / Stop / Done`;
- nested `Yes` branch questions do not include `Stop / Done`;
- nested `Revisit` branch questions do not include `Stop / Done`;
- `No / Stop / Done` is never recommended when a safe forward route exists;
- approval gates use action-specific decline/cancel labels instead of generic `Stop / Done`;
- final `Healthy? -> Done` remains the only progress-path terminal exception.

## Tradeoffs

Forward-only nested routes make the workflow feel less repetitive after the user has already chosen progress. The cost is that a user who changes their mind inside a nested prompt must use the client-provided custom answer, back out through a later top-level gate, or select a review/decline option when the gate is an approval gate.

Keeping `Stop / Done` only at formal closeout gates makes the flowchart model clearer: stop is a top-level right branch, not a repeated option at every depth. This is less mechanically symmetric than the original Down / Left / Right model, but it better matches observed user experience.

## Non-Goals

- Do not remove the top-level `No / Stop / Done` option.
- Do not make the workflow impossible to stop.
- Do not remove `Decline`, `Cancel`, `Keep Local`, or other domain-specific safe-exit choices from approval gates.
- Do not change issue, merge, or implementation semantics beyond native question routing.
- Do not rely on invisible defaults or automatic recommended answers.

## Milestone Linkage

- `M0 - Governance`: native Q&A state-machine contract and validation.
- `M1 - Source Of Truth`: skill and metadata alignment across source and live plugin deployment.

## Proof Oracle Candidates

- `scripts/test-advanced-user-input-policy.ps1` rejects nested `Yes` branch examples containing `Stop / Done`.
- `scripts/test-native-continuation-loop.ps1` distinguishes top-level closeout gates from nested branch menus.
- Scenario tests for `brainstorm-spec`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `implement-plan`, `merge-changes`, `audit-project`, and `setup-project` reject nested route options that include `Stop / Done`.
- Metadata scans reject default prompts that tell agents to put `Stop / Done` in nested route questions.
- A debug-mode smoke transcript shows `Continue? -> Yes -> route menu` without a nested stop option.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` deploys the updated source contract to the live plugin.

## Open Questions For Planning

- Should nested route menus include a `Back To Continue?` option, or should they be strictly forward/revisit choices with Custom Other handling unexpected back-out requests?
- Should approval gates be classified separately in `advanced-user-input` so they are not confused with workflow continuation gates?
- Should the SVG and Mermaid companion be updated to visually communicate that `Stop / Done` only exists at formal top-level gates?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: this spec preserves top-level stopping while removing redundant nested stop prompts.
- Scope check: this is one focused workflow-contract change with tests and docs updates.
- Ambiguity check: the only remaining questions are implementation-planning choices.
