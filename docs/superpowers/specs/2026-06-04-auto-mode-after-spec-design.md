# Auto Mode After Spec Design

## Purpose

Add an Auto Mode option after a Superpowers Project spec is created so an agent can run continuously from an approved spec through planning, implementation, verification, publication, and merge without additional user input, while still using the existing project workflow gates and stopping loudly when evidence is incomplete or unsafe.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the durable lifecycle as `spec -> plan -> issue`, with execution handled by native `/goal` or goal tools plus Superpowers execution skills.
- `README.md` documents native continuation gates where each skill asks `Continue?` with `Yes`, `Revisit`, and `No / Stop / Done`, then asks nested route questions.
- `skills/brainstorm-spec/SKILL.md` owns spec creation and currently routes from a saved spec into planning choices.
- `skills/write-plan/SKILL.md` requires planning grills and native user input when material decisions remain before a plan is saved.
- `skills/implement-plan/SKILL.md` provides non-issue execution from an approved plan, requires native `/goal`, development branch execution, publish permission, and merge-ready proof.
- `skills/create-issues/SKILL.md`, `skills/resolve-issue/SKILL.md`, and `skills/orchestrate-issues/SKILL.md` own the issue-backed path for tracked, risky, or multi-slice work.
- `skills/merge-changes/SKILL.md` supports `pr-issue`, `pr-no-issue`, and `local-branch` closeout modes, and requires clean premerge and closeout proof before success.
- Recent history includes `b9b3d29 Remove quick apply route`, so Auto Mode should not recreate a direct-to-main shortcut or weaken the current evidence gates.

## User Decisions

- Auto Mode authority is bounded auto-merge: one upfront native authorization allows the agent to plan, implement, push, open a PR when appropriate, and merge only after every scripted gate passes.
- Auto Mode route selection is agent-chosen: the agent chooses direct `implement-plan` for narrow work or issue-backed `create-issues -> resolve-issue/orchestrate-issues -> merge-changes` for tracked, risky, broad, milestone-owned, or multi-slice work.
- Auto Mode decision behavior uses recorded defaults: the authorization ledger defines what the agent may decide; the agent stops when a material choice falls outside those rules.
- Auto Mode appears immediately after spec creation, inside the nested continuation route from `brainstorm-spec`.

## Recommended Approach

Implement Auto Mode as a workflow contract over existing skills, not as a new execution engine.

`brainstorm-spec` should keep the fixed top-level continuation geometry:

- `Yes`
- `Revisit`
- `No / Stop / Done`

When the user selects `Yes`, the nested route should offer Auto Mode as the path that starts continuous execution from the saved spec. Selecting Auto Mode asks one native authorization question, tentatively named `project_auto_mode_authorization`, and writes or carries a structured authorization ledger.

The ledger should include:

- source spec path
- selected authority: bounded auto-merge
- route policy: agent chooses the appropriate route and records the reason
- decision policy: use recorded defaults, stop outside policy
- merge permission: pre-authorized only after clean premerge proof
- mutation scope: the current repository, development branches, GitHub issues, PRs, and merge operations required by the selected route
- required proof: plan proof oracle, verification receipts, cleanup hook result, PR or local branch evidence, and closeout proof
- stop conditions: unclear acceptance criteria, missing proof oracle, dirty unsafe state, failed validation, GitHub/auth failure, failed or pending required checks, premerge failure, closeout failure, or any material decision not covered by the ledger

Downstream skills should accept the ledger only when it matches their existing contracts. They should not silently downgrade behavior. If a skill needs live user input that the ledger does not already authorize, it should stop with the exact blocker.

## Workflow Design

1. `brainstorm-spec` saves and self-reviews the approved spec.
2. The nested continuation route offers Auto Mode after the top-level `Yes` answer.
3. Auto Mode asks `project_auto_mode_authorization`.
4. The authorization ledger is attached to the workflow state and named in every downstream summary.
5. `write-plan` consumes the ledger, inspects the repo, writes an implementation plan from the spec, and records all agent-chosen defaults.
6. The route chooser decides between:
   - `implement-plan` for narrow, locally verifiable, non-issue work.
   - `create-issues` plus `resolve-issue` or `orchestrate-issues` for work that needs tracker ownership, milestone visibility, dependency handling, worker orchestration, or multiple vertical slices.
7. Implementation uses the existing branch, goal, TDD, execution, verification, publish, and PR-ready proof requirements.
8. `merge-changes` consumes the ledger as native merge permission only after premerge proof is clean.
9. Closeout still requires the existing cleanup hook, branch/worktree cleanup proof, default branch sync, mirror cleanup when issue-backed, and clean repo proof.

## Route Selection Rules

Prefer `implement-plan` when all of these are true:

- the spec can become one coherent plan
- the work is narrow enough for one implementation branch
- no GitHub issue closure is needed
- acceptance criteria and proof oracle are clear
- the implementation is locally verifiable

Prefer the issue-backed route when any of these are true:

- the spec naturally splits into multiple vertical slices
- GitHub tracking or milestone history matters
- risk calls for issue mirror metadata and acceptance checklists
- worker orchestration is useful
- dependencies or blockers need durable tracker records
- closing a GitHub issue is part of the desired outcome

If both routes are plausible, the agent should choose the route with the least process that still preserves proof, reviewability, and cleanup. The reason must be written into the plan or issue creation summary.

## Error Handling

Auto Mode stops loudly when the current evidence is insufficient. It should not invent missing policy during execution.

Blocking examples:

- source spec is not saved under `docs/superpowers/specs`
- the spec lacks acceptance criteria or proof oracle candidates
- route choice needs a product or policy decision not covered by the ledger
- repo state is dirty in a way that affects the work
- a required command, scenario test, validator, GitHub check, or cleanup hook fails
- GitHub auth or network state prevents required tracker or PR operations
- premerge proof is incomplete, failed, or pending while policy requires it
- closeout proof cannot show merged state, cleanup, and clean repo status

When Auto Mode stops, the active skill should report the exact pending state, the evidence already gathered, and the safest resume route.

## Tradeoffs

This design gives the user a true unattended path after spec approval while preserving the plugin's current separation between idea, plan, issue, execution, and merge. The cost is a stricter authorization ledger that every downstream skill must learn to validate.

Adding Auto Mode only after `write-plan` would be easier, but it would not satisfy the requested "after a spec is created" workflow. Reusing `debug_question_mode` would be simpler mechanically, but the existing skills correctly reserve that behavior for smoke tests and stuck prompt diagnostics.

## Non-Goals

- Do not use `debug_question_mode` for normal Auto Mode execution.
- Do not edit directly on `main`.
- Do not bypass validation, cleanup, PR-ready, premerge, or closeout proof.
- Do not merge without clean premerge proof.
- Do not create compatibility wrappers or forwarding skills for old workflow names.
- Do not let non-issue work claim GitHub issue closure.
- Do not continue when the recorded defaults do not cover a material decision.
- Do not make worker threads merge their own PRs by default.

## Milestone Linkage

- `M0 - Governance`: native authorization, decision policy, proof gates, stop conditions, and merge approval semantics.
- `M1 - Source Of Truth`: spec-to-plan-to-issue routing, artifact ownership, route records, and workflow documentation.

## Proof Oracle Candidates

- `skills/brainstorm-spec/scripts/test-scenarios.ps1` proves Auto Mode is offered only after spec creation and only under the nested continuation route.
- `skills/write-plan/scripts/test-scenarios.ps1` proves Auto Mode ledgers can satisfy planning gates only when recorded defaults cover material decisions.
- `skills/implement-plan/scripts/test-scenarios.ps1` proves Auto Mode still requires approved plan, native goal proof, development branch, verification, publish evidence, and no issue closure claim.
- `skills/create-issues/scripts/test-scenarios.ps1` proves Auto Mode issue creation records AFK/HITL classification, route reason, labels, milestone, proof oracle, and publication evidence.
- `skills/resolve-issue/scripts/test-scenarios.ps1` and `skills/orchestrate-issues/scripts/test-scenarios.ps1` prove Auto Mode can execute ready issue mirrors without live route prompts only when the authorization ledger covers the selected topology.
- `skills/merge-changes/scripts/test-scenarios.ps1` proves Auto Mode merge permission is accepted only after clean premerge proof and rejected when premerge or closeout evidence is missing.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` passes before updating the live install.
- The user-level repo cleanup hook passes before closeout.

## Open Questions For Planning

- Should the authorization ledger live as a generated evidence file, be embedded in handoff ledgers, or be carried only as structured thread state plus downstream summaries?
- Should Auto Mode support both direct current-thread execution and worker-thread execution in the first implementation, or should worker support be limited to the existing issue-backed orchestration path?
- Which shared helper should validate the Auto Mode ledger so the contract is not duplicated across every skill's scenario tests?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the design preserves the fixed top-level continuation geometry and uses Auto Mode only in nested routing.
- Scope check: this is large enough for one implementation plan with multiple task groups; issue-backed decomposition may be appropriate if planning finds too many independent slices.
- Ambiguity check: the remaining open questions are implementation-planning choices, not hidden product requirements.
