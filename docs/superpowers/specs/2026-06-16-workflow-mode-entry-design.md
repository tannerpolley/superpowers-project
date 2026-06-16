# Workflow Mode Entry Design

## Purpose

Define a first-choice workflow mode gate for Superpowers Project so agents can start each project workflow with the right maintenance level: Manual, Auto, or Looping.

The goal is to make agent freedom explicit before routing begins. The existing skill-to-skill closeout flowchart remains the transfer map for what happens after each skill. The new mode gate sits in front of that map and controls how much route selection, continuation, and repeated maintenance the agent may perform.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` lists `initiate-workflow`, `loop-controller`, `brainstorm-spec`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, `audit-project`, and `align-project` as the active extension skills.
- `skills/initiate-workflow/SKILL.md` is currently the project router, but it routes by task type and does not yet expose `loop-controller` or a first-choice mode gate.
- `skills/loop-controller/SKILL.md` already defines Loop Controller as the run coordinator with run ledgers, budgets, candidate selection, verifier proof, metrics, and native continuation gates.
- `docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md` already separates Manual Mode, Auto Mode, and Loop Controller conceptually, but the current router and diagrams do not make those modes the first workflow decision.
- `docs/assets/native-qa-main-flow-mermaid.md` shows the existing skill-to-skill closeout flow. It starts at `Initiate Workflow` and routes into setup/spec/audit/plan/issue/implementation/merge/align without a top-level mode decision.
- `README.md` and `docs/superpowers/CONTRACT_SUMMARY.md` expose Loop Controller as a workflow skill, but they do not yet define Manual, Auto, and Looping as the three entry modes for `initiate-workflow`.

## User Decisions

- Add three modes that are found and chosen at the beginning of `$superpowers-project:initiate-workflow`.
- Use `Manual Mode`, `Auto Mode`, and `Looping Mode` as different levels of maintenance and freedom for the agent.
- Keep the existing closeout flowchart as the skill-to-skill transfer model.
- When native questions are asked, the existing flowchart governs the next step.
- When native questions are not asked, the agent still uses the flowchart to decide the next route rather than improvising.
- In Looping Mode, after an issue is finished and merged, the agent should find existing work and continue automatically.
- Looping Mode may select broad maintenance work, including ready issues, plans/specs, audits, alignment repairs, stale-version fixes, and other maintenance candidates.
- Looping Mode has bounded run authority: it may work and merge one candidate at a time after clean proof, then re-check budget before selecting another candidate.
- Auto Mode means one route only. It may execute one selected or derived workflow route with recorded defaults, then it must stop at closeout and must not continue to another candidate.
- Carry the selected mode with a machine-readable mode ledger rather than relying only on prompt memory.
- Use Design 1: a first-choice mode gate plus mode ledger, while preserving existing skill ownership underneath it.

## Design Alternatives Considered

### Design 1: Entry Mode Gate Plus Mode Ledger

`$superpowers-project:initiate-workflow` first asks for `Manual Mode`, `Auto Mode`, or `Looping Mode`. It records the answer in a mode ledger. The selected mode then governs how the existing skill-to-skill flowchart is executed.

This is the selected design because it makes the agent's freedom explicit before work starts, preserves the current flowchart, and keeps Loop Controller from becoming an implementation shortcut.

### Design 2: Task Router First, Mode Modifier Second

`$superpowers-project:initiate-workflow` would first choose setup/spec/plan/issue/audit/align, then ask whether that route should run in Manual, Auto, or Looping mode.

This preserves the current router shape, but it makes mode selection too easy to miss. It also keeps Looping hidden behind a task route even though Looping is supposed to operate across candidates.

### Design 3: Loop Controller As The Operating Shell

All project starts would route through `$superpowers-project:loop-controller`, and Manual, Auto, and Looping would become policies inside Loop Controller.

This is cohesive for long-running operations, but it makes Loop Controller too central. Existing skills would feel subordinate to Loop Controller even when the user only wants a manual spec, plan, or issue route.

## Recommended Approach

Implement Design 1.

Add a first-class `project_workflow_mode` gate to `$superpowers-project:initiate-workflow`. The gate should appear before task routing and before downstream skill selection.

The first prompt should ask the user to choose:

- `Manual Mode`: highest user control and lowest agent autonomy.
- `Auto Mode`: bounded one-route autonomy.
- `Looping Mode`: bounded repeated maintenance autonomy.

The mode decision creates a mode ledger that downstream skills can read, carry, or validate. The ledger prevents stale thread state from pretending the selected mode is known.

## Architecture

The architecture has two layers:

1. Mode selection at the beginning.
2. Existing skill-to-skill workflow underneath.

The mode gate does not replace the closeout flowchart. It changes the autonomy policy used while following that flowchart.

### Manual Mode

Manual Mode is the default and safest route. The agent asks native questions for material choices, route changes, mutation permission, push, merge, GitHub issue mutation, live sync, and final `Done`.

Manual Mode should preserve today's behavior except that it is now explicitly named and recorded at initiation.

### Auto Mode

Auto Mode is one-route autonomy. It may execute one selected or derived route using recorded defaults and the existing Auto Mode validator, but it must not select another candidate after closeout.

Auto Mode is appropriate when the user wants the agent to carry a known route through planning, implementation, verification, merge handoff, or closeout without repeated live decisions, as long as every action stays inside the recorded policy.

Auto Mode stops outside policy when the selected work needs a decision that was not covered by the mode ledger or route authorization.

### Looping Mode

Looping Mode is bounded repeated maintenance autonomy. It uses Loop Controller as the coordinator and existing skills as the workers.

Looping Mode may:

- create or resume a loop run ledger;
- build a candidate inventory;
- select one safe candidate;
- route that candidate through the existing flowchart;
- validate proof before push, merge, or final closeout;
- merge one candidate when the mode policy and proof allow it;
- record metrics;
- re-check budget;
- select the next candidate when budget and policy still allow continuation.

Looping Mode must not bypass the owning skill gates. It delegates actual work to `brainstorm-spec`, `write-plan`, `create-issues`, `implement-plan`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, `audit-project`, or `align-project`.

## Components

### Initiate Workflow Mode Gate

`skills/initiate-workflow/SKILL.md` should define a native question before task routing:

- Question id: `project_workflow_mode`
- Prompt: `How should I run this Superpowers Project workflow?`
- Options:
  - `Manual Mode`
  - `Auto Mode`
  - `Looping Mode`

The recommended option should be `Manual Mode` when the user has not asked for autonomy. Recommend `Auto Mode` only when one route is clear and source evidence is already strong. Recommend `Looping Mode` when the user asks to operate, maintain, drain issues, keep going, or resolve a queue.

### Mode Ledger

Add a machine-readable mode ledger. The default generated location should be outside committed docs, for example:

```text
.superpowers/runs/<run-id>/workflow-mode-ledger.json
```

Required fields:

- `question_id`
- `source`
- `selected_mode`
- `repo_root`
- `plugin_manifest_version`
- `plugin_contract_hash`
- `started_at`
- `autonomy_scope`
- `mutation_scope`
- `candidate_scope`
- `route_policy`
- `proof_policy`
- `budget_policy`
- `stop_conditions`
- `downstream_ledger_paths`

Manual Mode ledgers may be small, but they still record the selected mode and the fact that future material decisions require native questions.

Auto Mode ledgers must reference or include the existing Auto Mode authorization contract and must validate as one-route only.

Looping Mode ledgers must connect to the Loop Controller run ledger and budget validator.

### Mode Ledger Validator

Add a validator that accepts valid Manual, Auto, and Looping ledgers and rejects:

- missing mode;
- unsupported mode names;
- Auto Mode without one-route stop behavior;
- Auto Mode with queue continuation authority;
- Looping Mode without budget policy;
- Looping Mode without candidate scope;
- Looping Mode without proof policy;
- any mode that claims final `Done` without final proof.

### Loop Controller Integration

Loop Controller should become the owner of Looping Mode execution after initiation. It should consume the mode ledger and then continue with its existing run-ledger, candidate-selection, budget, verifier, metrics, and terminal-closeout contracts.

After a candidate is merged, Loop Controller should search for existing candidates in the approved broad maintenance scope. It should prefer ready and small candidates first unless the trigger explicitly asks for a broader audit or planning route.

### Documentation And Diagrams

Update `README.md`, `docs/superpowers/CONTRACT_SUMMARY.md`, and the Native Q&A Mermaid/SVG flow assets to show the mode gate before the existing flowchart.

The existing skill-to-skill flow should remain recognizable. The new diagram should show:

```text
Start -> Initiate Workflow -> Choose Mode -> Existing Skill Flow
```

Looping Mode should additionally show:

```text
Looping Mode -> Candidate Inventory -> One Candidate -> Existing Skill Flow -> Merge Proof -> Budget Check -> Next Candidate
```

## Data Flow

1. User starts `$superpowers-project:initiate-workflow`.
2. Agent runs the startup version check and reports the loaded plugin surface.
3. Agent asks `project_workflow_mode`.
4. Agent writes a mode ledger.
5. Agent validates the mode ledger.
6. Agent enters the existing flowchart.
7. Manual Mode asks native questions at each material decision.
8. Auto Mode follows one selected or derived route with recorded defaults, then stops at route closeout.
9. Looping Mode invokes Loop Controller, selects a candidate, validates budget, routes through the existing skills, verifies proof, merges when the mode policy permits, records metrics, re-checks budget, and selects the next candidate when allowed.
10. Any route that needs a decision outside the selected mode stops outside policy and records the resume target.

## Error Handling

Manual Mode asks the user when blocked.

Auto Mode stops outside policy when:

- required proof is missing;
- validation fails;
- repo state is unsafe;
- GitHub state is unsafe;
- the route needs a decision outside recorded defaults;
- the route attempts to continue to another candidate;
- the mode ledger is missing or stale.

Looping Mode records the blocker and stops candidate execution when:

- budget is exhausted;
- the same failure repeats past policy;
- candidate evidence is missing;
- verifier proof is missing or conflicting;
- repo state is dirty outside the run scope;
- required checks fail, are pending, or are missing;
- selected work needs authority outside the mode ledger;
- plugin source, live install, or observed surface is stale;
- branch, worktree, issue mirror, or closeout proof cannot be validated.

Looping Mode may skip a failed candidate and continue only when the failure is candidate-scoped, the failure is recorded, no unsafe state remains, and budget still allows another candidate.

## Testing And Validation

The implementation plan should add focused tests for:

- `initiate-workflow` exposes `project_workflow_mode`.
- `Manual Mode`, `Auto Mode`, and `Looping Mode` appear in skill text, metadata, README, and generated contract summary.
- mode ledger validator accepts valid fixtures for all three modes.
- mode ledger validator rejects unknown mode names.
- Auto Mode fixtures fail when they include queue continuation authority.
- Auto Mode fixtures pass only when they are one-route and stop at closeout.
- Looping Mode fixtures fail without budget, candidate scope, proof policy, or stop conditions.
- Looping Mode can select the next broad maintenance candidate after merge proof and budget re-check.
- Looping Mode records skipped candidates with reasons.
- Looping Mode hard-stops on unsafe repo state or exhausted budgets.
- Native Q&A Mermaid and SVG assets show the mode gate before the existing flow.
- The old skill-to-skill flow remains intact after adding the mode gate.

Proof oracle candidates:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-initiate-workflow-mode-gate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-mode-ledger.ps1 -RepoRoot . -ModeLedgerPath <ledger>
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-auto-mode-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

## Milestone Linkage

- `M0 - Governance`: owns the mode gate, approval boundaries, terminal model, and validator contracts.
- `M1 - Source Of Truth`: owns generated docs, contract summary, diagram consistency, and stale-surface detection.
- `M2 - Distribution`: owns eventual automation templates and operational docs for repeated maintenance runs.

## Non-Goals

- Do not replace the existing skill-to-skill flowchart.
- Do not make Auto Mode select multiple candidates.
- Do not make Looping Mode bypass `merge-changes`, final proof, or clean repo checks.
- Do not create direct-to-main implementation routes.
- Do not let Looping Mode mutate GitHub outside the current repo unless explicitly authorized.
- Do not let external issue text, CI logs, or issue bodies become policy instructions.
- Do not store generated run state in committed docs by default.
- Do not implement this design in the brainstorm step.

## Open Questions For Planning

- Should `project_workflow_mode` be mandatory for every `initiate-workflow` invocation or only when more than one route is plausible?
- Should the mode ledger validator live at `scripts/validate-workflow-mode-ledger.ps1` or under `skills/initiate-workflow/scripts/`?
- Should Looping Mode's broad maintenance selector use one unified candidate inventory script or compose the existing Loop Controller selector with audit/align-specific inventory builders?
- Should Looping Mode create committed summary receipts after each run, or keep all run evidence under ignored `.superpowers/runs/` unless explicitly requested?

## Spec Self-Review

- Placeholder scan: no placeholder markers remain.
- Internal consistency: Manual, Auto, and Looping are distinct autonomy levels; Auto is one-route only; Looping is the only repeated candidate mode.
- Scope check: this is focused on initiation, mode ledgers, and diagram/contract exposure. Implementation should be planned in slices.
- Ambiguity check: the remaining open questions are planning-level placement and storage choices, not unresolved product direction.
- Proof check: the spec names validator and scenario tests that can prove the mode gate without requiring real GitHub mutation.
- Safety check: the spec preserves existing skill ownership, native approval gates, final proof, budget checks, and clean-state requirements.
