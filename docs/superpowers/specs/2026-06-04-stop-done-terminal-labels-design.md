# Stop Done Terminal Labels Design

## Purpose

Improve Superpowers Project continuation gates so `Stop` is used while a workflow loop is still in progress and `Done` is used only after the loop reaches a verified terminal state.

## Project Context Evidence

- `README.md` currently says top-level closeout options are always `Yes`, `Revisit`, and `No / Stop / Done`.
- `README.md` also says only `No / Stop / Done` or the explicit final `Healthy? -> Done` route ends the continuation loop.
- `skills/advanced-user-input/SKILL.md` defines the reusable native Q&A shape and currently describes `No / Stop / Done` as the right-side terminal option.
- `skills/initiate-workflow/SKILL.md` repeats the top-level `No / Stop / Done` contract and treats `Stop` and `Done` together as terminal answers.
- Every primary project skill repeats the same continuation loop language and uses `Right: Stop / Done` in intermediate nested routes.
- `skills/merge-changes/SKILL.md` has the strongest final closeout proof contract: merged PR or local branch merge, default branch sync, branch/worktree cleanup, prune, cleanup hook, issue mirror cleanup when applicable, milestone summary when applicable, and clean repo state.
- `skills/audit-project/SKILL.md` already has the concept of a final healthy path where `Healthy -> Done` is allowed.

## User Decisions

- `Done` should mean clean closeout only: a verified final state, not merely a completed intermediate artifact.
- Intermediate workflow exits should be labeled `Stop`.
- The preferred design is a phase-sensitive contract: intermediate gates use `Yes / Revisit / Stop`; final clean gates may use `Yes / Revisit / Done`.

## Problem Statement

The current `No / Stop / Done` label combines three meanings:

- no, do not continue this branch
- stop, pause this workflow before final completion
- done, the project workflow is complete

That wording is too loose for a workflow that treats specs, plans, issue mirrors, PR-ready output, merge closeout, and audits as different lifecycle states. A saved spec or plan can be complete as an artifact while the project workflow is still unfinished. The UI should not imply that the larger loop is done at those mid-loop checkpoints.

## Recommended Approach

Adopt a shared phase-sensitive terminal label contract.

The new contract:

- Use `Stop` when the current skill can pause or exit but required downstream workflow may remain.
- Use `Done` only when the current skill can prove a final terminal state.
- Keep `Yes` as the progress route and `Revisit` as the review/revision route.
- Do not show `Done` on intermediate closeouts.
- Do not show `Stop / Done` as a combined label.

Final terminal states should be explicit. The two expected first-class final states are:

- `merge-changes` has passed closeout proof for the selected mode and no required cleanup remains.
- `audit-project` reports a healthy final state with no blocking or repairable findings, then asks the explicit healthy completion gate.

If a final-stage skill finds unresolved work, pending checks, drift, cleanup work, or a failed proof gate, its terminal option should remain `Stop`, not `Done`.

## Workflow Design

Intermediate closeout shape:

```text
Continue?

Options:
- Yes
- Revisit
- Stop
```

Final clean closeout shape:

```text
Continue?

Options:
- Yes
- Revisit
- Done
```

Skill-specific expectations:

- `brainstorm-spec`: after a spec is saved, terminal option is `Stop`.
- `write-plan`: after a plan is saved, terminal option is `Stop`.
- `create-issues`: after issues or mirrors are created, terminal option is `Stop`.
- `implement-plan`: after branch work is merge-ready, terminal option is `Stop`.
- `resolve-issue`: after PR-ready issue output, terminal option is `Stop`.
- `orchestrate-issues`: after worker PR-ready output, terminal option is `Stop`.
- `merge-changes`: before clean closeout proof, terminal option is `Stop`; after clean closeout proof, terminal option may be `Done`.
- `audit-project`: if findings remain, terminal option is `Stop`; if the audit is healthy and no repair route remains, terminal option may be `Done`.
- `setup-project`: terminal option is normally `Stop`, because setup can lead into brainstorm, plan, issues, or audit work.
- `initiate-workflow`: describes routing only; it should defer `Done` to the skill that can prove final state.

## Implementation Surface

Update the shared policy first, then propagate it to skill docs and tests.

Likely files:

- `skills/advanced-user-input/SKILL.md`
- `skills/initiate-workflow/SKILL.md`
- `skills/setup-project/SKILL.md`
- `skills/brainstorm-spec/SKILL.md`
- `skills/write-plan/SKILL.md`
- `skills/create-issues/SKILL.md`
- `skills/implement-plan/SKILL.md`
- `skills/resolve-issue/SKILL.md`
- `skills/orchestrate-issues/SKILL.md`
- `skills/merge-changes/SKILL.md`
- `skills/audit-project/SKILL.md`
- `README.md`
- native workflow SVG/Mermaid assets if the visible diagram still shows combined Stop/Done semantics
- scenario scripts under `skills/*/scripts/test-scenarios.ps1`
- repo-level validation scripts that enforce native continuation contracts

## Validation Expectations

Scenario and repo validation should prove:

- intermediate skill docs no longer contain `Right: Stop / Done`
- shared policy docs explain `Stop` and `Done` separately
- `Done` appears only in final clean completion contracts
- `merge-changes` allows `Done` only after closeout proof passes
- `audit-project` allows `Done` only through a healthy final gate
- README no longer says top-level closeout options are always `No / Stop / Done`
- native workflow assets do not present `Stop / Done` as a single universal terminal label
- custom answers that mean a mid-loop exit are treated as `Stop`
- custom answers that claim completion before proof exists are treated as invalid or as `Stop`, not `Done`

## Error Handling

If the workflow cannot prove a final state, it should not offer or accept `Done`.

Examples:

- saved spec with no plan yet: `Stop`
- saved plan with no implementation yet: `Stop`
- PR-ready work not merged yet: `Stop`
- merge declined or premerge failed: `Stop`
- audit has blocking or repairable findings: `Stop`
- closeout proof cannot show clean repo state: `Stop`

The agent should report the current lifecycle state and the next valid resume route when the user selects `Stop`.

## Tradeoffs

The phase-sensitive contract is more precise than the current universal label, but it requires coordinated wording changes across every skill and workflow asset. That coordination is worthwhile because it makes the native UI reflect actual project state.

Keeping the existing combined label and only tightening prose would be easier, but users would still see `Done` at points where the workflow is not done. Removing `Done` everywhere would be simpler, but it would lose the useful final-completion signal after a clean merge or healthy audit.

## Non-Goals

- Do not change the meaning of `Yes` or `Revisit`.
- Do not remove the ability to stop an intermediate workflow.
- Do not allow `Done` before merge closeout, healthy audit, or another explicitly proven final state.
- Do not use `Done` as a synonym for "current artifact saved."
- Do not weaken merge, cleanup, or audit proof requirements.
- Do not add a separate project-management state store only to track this label change.

## Milestone Linkage

- `M0 - Governance`: continuation semantics, terminal-state proof, and native Q&A contracts.
- `M1 - Source Of Truth`: README, skill docs, scenario tests, and workflow assets should agree on the same label model.

## Proof Oracle Candidates

- `rg -n "Stop / Done" skills README.md docs/assets` returns no universal continuation labels after implementation, except historical specs or plans that are intentionally not active contracts.
- Scenario tests for intermediate skills require `Stop` and reject `Stop / Done`.
- `merge-changes` scenario tests require `Done` only in clean closeout wording.
- `audit-project` scenario tests require `Done` only in healthy final wording.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` passes before updating the live install.
- The user-level repo cleanup hook passes before closeout.

## Open Questions For Planning

- Should historical specs and plans be excluded from the text-level `Stop / Done` scan, or should the validator scan only active docs, README, skill docs, and assets?
- Should `merge-changes` use `Done` immediately after closeout proof, or should it ask an explicit final `Healthy?` gate similar to Doctor?
- Should the public SVG/Mermaid update be part of the first implementation plan or a follow-up documentation task?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the spec consistently uses `Stop` for in-progress exits and `Done` only for verified final states.
- Scope check: this can be one implementation plan with coordinated docs, skill contract, test, and asset tasks.
- Ambiguity check: the remaining open questions are planning details about validation scope and asset sequencing.
