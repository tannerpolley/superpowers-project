# Native Continuation Decision Tree Source Alignment Design

## Purpose

Align the actual Superpowers Project skill sources, metadata, docs, and validation tests with the newly documented native continuation decision tree.

The current readable tree documents the desired behavior, but the active skill files and skill metadata still contain old direction labels and nested Stop routes. This spec turns the audit findings into a focused repair target before broad implementation begins.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the durable lifecycle as `spec -> plan -> issue`, with workflow skills under `skills/` as the source of truth.
- The repo policy says this repository is source and live deployed plugin copies are deployment targets only.
- `docs/superpowers/closeout-startup-decision-tree.md` defines the desired readable decision tree with `Q<n>` and `A<n><letter>` notation, visible `Yes`, `Revisit`, and `Stop` top-level options, and no nested Stop after top-level Yes or Revisit.
- `docs/superpowers/closeout-startup-decision-tree-dev.md` preserves current source route IDs and explicitly records that many concrete source menus still include nested `Right: Stop`.
- `README.md` and `docs/assets/native-qa-main-flow-mermaid.md` mostly describe the new top-level `Yes / Revisit / Stop` story, but source skills still carry the old direction-coded route definitions.
- `scripts/validate.sh` passes even while active source drift remains, so validation coverage is currently incomplete for this exact contract.

## Audit Findings To Repair

### P1: Actual Skills Still Use Old Direction Labels

The readable tree says top-level closeout options should be visible as `Yes`, `Revisit`, and `Stop`. The active skill sources still define visible `Down`, `Left`, and `Right` options in the native continuation gate examples.

Representative evidence:

- `skills/audit-project/SKILL.md:134` starts old direction-coded closeout options.
- `skills/brainstorm-spec/SKILL.md:95` starts old direction-coded closeout options.
- `skills/create-issues/SKILL.md:218` starts old direction-coded closeout options.
- `skills/implement-plan/SKILL.md:112` starts old direction-coded closeout options.
- `skills/setup-project/SKILL.md:127` starts old direction-coded closeout options.
- `skills/write-plan/SKILL.md:149` starts old direction-coded closeout options.

The audit counted 150 old direction option lines across 9 active `SKILL.md` files.

### P1: Nested Route Menus Still Repeat Stop

The desired decision tree says that after top-level `Yes` or `Revisit`, nested route questions should not repeat `Stop`. They should list only the real forward, review, repair, rerun, recovery, or evidence routes for that selected branch.

Representative evidence:

- `skills/audit-project/SKILL.md:140` starts nested repair routing that still includes `Right: Stop`.
- `skills/brainstorm-spec/SKILL.md:101` starts nested start routing that still includes `Right: Stop`.
- `skills/create-issues/SKILL.md:224` starts nested issue execution routing that still includes `Right: Stop`.
- `skills/implement-plan/SKILL.md:118` starts nested implementation reiteration routing that still includes `Right: Stop`.
- `skills/setup-project/SKILL.md:145` starts nested setup reiteration routing that still includes `Right: Stop`.
- `skills/write-plan/SKILL.md:167` starts nested plan issue-count routing that still includes `Right: Stop`.

The audit counted 38 nested Stop route blocks across active `SKILL.md` files.

### P1: Skill Metadata Still Advertises Old Route Wording

The `agents/openai.yaml` metadata for major skills still uses old route language such as `with Down`, `Down Continue`, `Down Merge`, and `Right Stop`.

Representative evidence:

- `skills/setup-project/agents/openai.yaml:5`
- `skills/brainstorm-spec/agents/openai.yaml:5`
- `skills/audit-project/agents/openai.yaml:5`
- `skills/create-issues/agents/openai.yaml:5`
- `skills/implement-plan/agents/openai.yaml:5`
- `skills/merge-changes/agents/openai.yaml:5`
- `skills/orchestrate-issues/agents/openai.yaml:5`
- `skills/resolve-issue/agents/openai.yaml:5`
- `skills/write-plan/agents/openai.yaml:5`

This makes the plugin capable of loading old wording even when user-facing docs are correct.

### P1: Validation Has A False Green

`scripts/validate.sh` passed while active skill sources still contain direction labels and nested Stop routes. The native continuation validation checks currently forbid nested `Right: terminal label`, but they do not catch plain nested `Right: Stop`.

Representative evidence:

- `scripts/test-native-continuation-loop.sh:202` forbids `Right: terminal label`.
- `scripts/test-native-continuation-loop.sh:203` forbids `Right terminal label`.
- The same test does not fail on nested `Right: Stop`.

Validation should fail when active skill source contradicts the desired tree.

### P2: README Still Has Stale Recommendation Wording

`README.md:40` still says the recommended option should be `stale terminal option` only in terminal, blocked, or user-requested stop states. The current visible option vocabulary should be `Yes`, `Revisit`, and `Stop`, with `Done` reserved for verified final gates.

### P2: Dev Decision Tree Needs Canonical Role Clarification

`docs/superpowers/closeout-startup-decision-tree-dev.md:762` says the document preserves concrete source drift rather than normalizing it. That is useful as an audit map, but it should not be treated as the canonical developer version of the desired tree unless it clearly separates:

- desired contract
- current source drift
- exact source route IDs and line references
- repair target

## User Decisions Captured

- Top-level closeout option names should be `Yes`, `Revisit`, and `Stop`.
- The detailed route text should appear as hint or description text, and in Markdown docs it can appear in parentheses.
- After a top-level `Yes` or `Revisit` choice, the nested route question should not include Stop again.
- Nested route options should use their real option names, such as `Create One Plan`, `Review First`, or `Repair Issue Mirrors`.
- In the readable Markdown tree, every decision set should have matching question and answer depth labels, such as `Q0` with `A0a`, `A0b`, and `A0c`.
- In the readable Markdown tree, answer letters should distinguish multiple options at the same depth.
- The developer version may keep route IDs and line references, but the non-developer version should avoid internal names such as `project_plan_work_route`.

## Desired Contract

### Non-Escape Loop Rule

The continuation loop is mandatory runtime behavior, not descriptive guidance. A governed workflow action is not finished merely because the agent saved a spec, created a plan, created issues, pushed a branch, merged work, synced live files, ran validation, or wrote a final response.

The agent must not get out of the loop by itself. Before a verified final Done gate, the agent may not infer terminal intent from:

- a completed artifact
- a passing validation command
- a clean worktree
- a prior user request that only named the immediate task
- a custom answer that does not explicitly select a built-in terminal option
- an agent-authored summary or final message
- absence of an obvious next step

If `request_user_input` is callable, ending a turn after a governed workflow action is invalid until the agent has asked the required native continuation gate and handled the selected answer as executable routing.

If the user selects a forward or revisit branch, the agent must start that branch in the same turn when tools and state allow it. If the branch cannot start, the agent must ask or report the exact blocking condition through the next native question and remain in the workflow state instead of silently stopping.

Custom answers are non-terminal unless they are confirmed through a fresh built-in terminal question. A custom answer that asks for revision, review, repair, more evidence, different wording, a different route, or stronger loop behavior must be treated as `Revisit` and routed back into the workflow.

### Top-Level Closeout Gate

Every governed workflow closeout gate should ask `Should I continue on with the workflow?` or the skill-approved equivalent.

Visible top-level option names:

- `Yes`
- `Revisit`
- `Stop`

The option description or hint carries the route detail. In Markdown documentation, that detail may be shown in parentheses:

- `Yes (Continue Project Work)`
- `Revisit (Revise / Review Setup)`
- `Stop (pause here)`

The active skill text and metadata should not present `Down`, `Left`, or `Right` as user-visible option names for closeout routing.

### Nested Yes Routes

If the user selects `Yes`, the next question should ask the actual progress route only when multiple progress routes exist.

Nested Yes-route menus should include only real forward routes. They should not include `Stop`, `stale terminal label`, `Right: Stop`, or direction-coded labels.

Examples of valid nested Yes-route options:

- `Brainstorm New Spec`
- `Write Plan`
- `Create Issues`
- `Merge`
- `Resolve Another`
- `Orchestrate Another`
- `Apply Repair`
- `Prepare Repair Work`

### Nested Revisit Routes

If the user selects `Revisit`, the next question should ask the actual review, revision, repair, rerun, recovery, or evidence route only when multiple revisit routes exist.

Nested Revisit-route menus should not include `Stop`, `stale terminal label`, `Right: Stop`, or direction-coded labels.

Examples of valid nested Revisit-route options:

- `Review First`
- `Revise Spec`
- `Review Or Restart`
- `Repair Issue Mirrors`
- `Run Audit Again`
- `Gather More Evidence`
- `Re-run Cleanup`

### Stop And Done Semantics

`Stop` is a top-level terminal pause for an intermediate workflow. It does not prove completion.

`Done` is valid only at a verified final clean gate. A final Done gate requires the relevant closeout proof and a clean worktree when the governing skill requires clean repo proof.

Intermediate nested route menus should not use Stop as an escape route after `Yes` or `Revisit`. If the user needs to stop from a nested branch, the workflow should return to the originating top-level gate or ask an explicit terminal confirmation question rather than mixing Stop into every nested route menu.

### Stop Recommendation Rule

`Stop` may remain selectable at the top-level gate for user control, but the agent must not recommend `Stop` before the workflow is finally finished.

Before verified final completion, the recommended route must be:

- `Yes` when any safe forward route exists
- `Revisit` when review, repair, validation, evidence gathering, source alignment, sync, or clarification is still needed

The active skill text and metadata should remove or replace any language that lets the agent recommend Stop merely because:

- the immediate artifact was saved
- validation passed
- the repo is clean
- the current step is locally complete
- the agent thinks the user's original request was narrow
- the next route requires another workflow skill
- the agent has no preference between available next routes

If the workflow is not verified final, Stop can be shown but should not be the recommended option. The agent's recommendation should stay on the route that continues, revisits, repairs, validates, syncs, or completes the remaining lifecycle work.

### Permission Gates

Permission gates such as push, publish, and merge approval are separate from Yes/Revisit route refinement. They should use domain-specific labels such as `Push`, `Hold`, `Merge`, or `Decline` when those labels are clearer than closeout labels.

Permission gates must still honor the artifact review and evidence-summary contract before asking for approval.

### Readable Documentation

The readable tree should continue to use:

- color-coded question and answer text
- `Q<n>` and `A<n><letter>` labels
- matching depth numbers between questions and answers
- answer letters reset per question
- parentheses for route details
- no internal route IDs

### Developer Documentation

The developer tree should either:

- become a canonical desired-contract map with route IDs, or
- remain an audit map of current source drift.

It should not blur those roles. If it remains an audit map, it should clearly say that source drift entries are defects to repair, not desired behavior.

## Recommended Approach

Implement the repair in one coordinated pass, but keep the work grouped by contract surface:

1. Update active `SKILL.md` native continuation gate examples.
2. Update active `agents/openai.yaml` metadata summaries.
3. Update README and workflow docs to remove stale `stale terminal option` recommendation wording.
4. Clarify the developer decision-tree document role.
5. Harden validation so source drift fails.
6. Run repo validation and live-sync validation.
7. Sync the live install only after source validation passes.

This should be broad enough to avoid partial drift, but still guided by this exact spec instead of improvised file-by-file edits.

## Implementation Surface

Likely source files:

- `skills/audit-project/SKILL.md`
- `skills/brainstorm-spec/SKILL.md`
- `skills/create-issues/SKILL.md`
- `skills/implement-plan/SKILL.md`
- `skills/merge-changes/SKILL.md`
- `skills/orchestrate-issues/SKILL.md`
- `skills/resolve-issue/SKILL.md`
- `skills/setup-project/SKILL.md`
- `skills/write-plan/SKILL.md`
- `skills/*/agents/openai.yaml` for the same governed workflow skills
- `skills/advanced-user-input/SKILL.md`
- `skills/advanced-user-input/agents/openai.yaml`

Likely docs and assets:

- `README.md`
- `docs/assets/native-qa-main-flow-mermaid.md`
- `docs/assets/native-qa-main-flow.svg`
- `docs/superpowers/closeout-startup-decision-tree.md`
- `docs/superpowers/closeout-startup-decision-tree-dev.md`

Likely validation:

- `scripts/test-native-continuation-loop.sh`
- `scripts/test-advanced-user-input-policy.sh`
- `scripts/test-native-qa-svg.sh`
- skill-specific `scripts/test-scenarios.sh` files under governed skills

## Validation Expectations

Validation should prove:

- no active governed `SKILL.md` closeout gate exposes `Down`, `Left`, or `Right` as user-visible route labels
- no nested Yes-route or Revisit-route block contains `Right: Stop`, `stale terminal label`, or equivalent terminal wording
- active `agents/openai.yaml` metadata does not advertise `Down`, `Left`, or `Right Stop` route wording for closeout gates
- governed skill text says the agent must not get out of the loop by itself before Stop or verified final Done
- governed skill text treats custom revision, review, repair, evidence, or route-change answers as non-terminal Revisit behavior
- governed skill text does not allow Stop to be recommended before verified final completion
- README uses `Yes`, `Revisit`, and `Stop` for top-level closeout recommendations
- `Done` is documented only as a verified final clean gate
- the readable decision-tree document keeps valid `Q<n>` and `A<n><letter>` depth labels
- the developer decision-tree document has an explicit canonical role
- scenario tests fail when nested Stop is reintroduced after top-level Yes or Revisit
- scenario tests fail when old direction-coded closeout labels are reintroduced

## Proof Oracle Candidates

- `rg -n '^- (Down|Left|Right):' skills -g SKILL.md`
- ``rg -n 'Right: `Stop|Right: Stop|stale terminal label|stale terminal option' skills README.md docs/assets docs/superpowers/closeout-startup-decision-tree*.md``
- `rg -n 'with Down|Down Continue|Down Merge|Right Stop|Down default progress' skills -g openai.yaml`
- ``rg -n 'must not get out of the loop by itself|ending a turn.*invalid|must not recommend `Stop` before' skills README.md docs/superpowers/closeout-startup-decision-tree*.md``
- `rg -n 'Recommend Stop only|recommended.*Stop.*blocker|Stop.*recommended.*locally complete|Stop.*recommended.*validation passed' skills README.md docs/superpowers/closeout-startup-decision-tree*.md`
- a structural checker for `docs/superpowers/closeout-startup-decision-tree.md` that verifies each `Q<n>` has matching `A<n><letter>` children
- a nested-route checker that scans `Question id:` blocks and fails on nested terminal options after non-top-level route questions
- a recommendation-policy checker that fails if governed skill text allows Stop to be recommended before verified final completion
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`

## Tradeoffs

The repair will touch many skill and metadata files. A narrow patch to only the readable document would be quicker, but it would leave the actual plugin behavior out of sync with the desired tree.

The stricter nested-route policy also removes a convenient repeated Stop option from child menus. That is intentional. It keeps the top-level continuation decision meaningful and prevents every nested branch from acting like an independent terminal gate.

## Non-Goals

- Do not edit live deployed plugin copies directly while this source repo is available.
- Do not create GitHub issues as part of this spec-writing step.
- Do not change the core Superpowers method pairings for brainstorm, planning, execution, verification, or merge.
- Do not weaken final Done proof requirements.
- Do not make the non-developer readable tree expose internal route IDs.
- Do not treat a passing current validation run as proof that the source already matches the desired tree.

## Milestone Linkage

- `M0 - Governance`: native continuation contract, validation hardening, and terminal state semantics.
- `M1 - Source Of Truth`: source skill text, metadata, docs, validation, and live install alignment.

## Open Questions For Planning

- Should the repair be implemented as one mechanical sweep across all governed skills, or split into one skill-source pass and one metadata/docs/tests pass?
- Should the developer decision-tree document become the desired canonical route-ID map, or remain an audit map that records current and historical drift?
- Should the nested-route validation infer top-level questions by `_next_step` naming only, or should each governed skill declare its top-level closeout question IDs explicitly?
- Should final health gates use `Yes (Done)` in the readable tree, or should the visible option be `Done` when the gate is explicitly final?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the spec consistently separates top-level terminal options from nested route refinement.
- Scope check: this is one repair slice across source skills, metadata, docs, and validation.
- Ambiguity check: the remaining open questions are implementation-shape choices, not blockers to the core contract.
