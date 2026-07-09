# Auto Mode Loop Controller Design

## Purpose

Define the next automation layer for Superpowers Project without overloading Auto Mode. Auto Mode stays a bounded authorization contract for a known workflow route. A new Loop Controller layer owns repeated discovery, candidate selection, budgets, retries, verification assignment, metrics, and next-run decisions across workflow runs.

The goal is to move from "the agent may continue through this approved route" to "the project can safely discover work, select a candidate, run the right existing skill path, verify the result, record metrics, and decide whether another candidate should run."

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the durable artifact roots and the execution model: setup, spec, plan, issue mirrors, native `/goal`, direct issue resolution, worker orchestration, and merge closeout.
- `docs/superpowers/specs/2026-06-04-auto-mode-after-spec-design.md` defines Auto Mode as bounded auto-merge over existing skills, with recorded defaults, mutation scope, proof requirements, stop conditions, and clean premerge merge permission.
- `scripts/lib/auto-mode-contract.sh` validates Auto Mode authorization fields such as `project_auto_mode_authorization`, `bounded-auto-merge`, `recorded-defaults`, `stop_outside_policy`, `mutation_scope`, `required_proof`, and `stop_conditions`.
- `docs/superpowers/specs/2026-06-11-plugin-operational-maturity-design.md` already added CI, release receipts, stale contract detection, local-branch closeout helpers, e2e smoke tests, and generated contract summaries. Loop Controller should build on those mature surfaces instead of replacing them.
- `README.md` documents strict native continuation geometry: intermediate gates use `Yes`, `Revisit`, and `Stop`; final health gates use `Done`, `Revisit`, and `Stop`; saved artifacts, pushed branches, created issues, merged PRs, completed audits, and live sync are not terminal by themselves.
- `docs/superpowers/OUTCOME_WORKFLOW.md` records the current approval boundaries: push, publish, merge, board creation, GitHub mutation, Auto Mode authorization, and final `Done` require explicit proof and owning gates.
- Recent issue #44 resolution proved why loop terminal behavior must be script-backed: PR-ready evidence is not terminal without a structured continuation decision or a follow-on `merge-changes` route.

## External Reference Inputs

- [Loop Engineering](https://addyosmani.com/blog/loop-engineering/) frames the ideal loop as automations, worktrees, skills, plugins/connectors, subagents, and durable state outside the single conversation.
- [12-Factor Agents](https://github.com/humanlayer/12-factor-agents) emphasizes owning control flow, context, tool results, and execution state rather than leaving the loop shape inside model improvisation.
- [Codex Automations](https://developers.openai.com/codex/app/automations) provides scheduled or background entrypoints that can call skills and route findings into a triage surface.
- [Codex Subagents](https://developers.openai.com/codex/subagents) provides specialized parallel agents that can be used for exploration, implementation, and verification roles.
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks-guide) is a useful adjacent model for deterministic lifecycle guards such as protected-file blocking, post-edit formatting, permission notifications, and rule enforcement.
- [OpenHands Software Agent SDK](https://docs.openhands.dev/sdk) and [SWE-agent Agent-Computer Interface](https://swe-agent.com/0.7/background/aci/) reinforce the need for typed execution state, tool-facing interfaces, and agent-optimized feedback.

## User Decisions

- Create one combined spec, not separate specs for Auto Mode and Loop Controller.
- Use Design 1: layered Loop Controller over Auto Mode.
- Keep Auto Mode as the authorization layer.
- Add Loop Controller as the orchestration layer above existing skills.
- Preserve existing skill ownership: `brainstorm-spec`, `write-plan`, `create-issues`, `implement-plan`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, `audit-project`, and `align-project` still perform the actual work.
- Do not make Loop Controller an implementation shortcut, direct-to-main path, or issue-closure bypass.

## Design Alternatives Considered

### Design 1: Layered Loop Controller Over Auto Mode

Keep Auto Mode as the permission and recorded-defaults contract. Add Loop Controller as a separate layer that owns triggers, candidate selection, run state, budgets, retries, verifier roles, metrics, and next-run decisions.

This is the selected design because it keeps approval boundaries inspectable. Loop Controller decides what should run next. Auto Mode decides whether a selected route may continue without additional live user input. Existing skills still own planning, execution, verification, issue work, and merge closeout.

### Design 2: Auto Mode v2 As The Whole Loop

Expand Auto Mode itself into scheduling, triage, retries, verification, merge, metrics, and continuation. This would be easier to name, but it would make "Auto Mode" mean both authority and orchestration. That would make mutation approval harder to audit and would blur the current stop-outside-policy boundary.

### Design 3: Automation-First Loop Specs

Start with scheduled automation templates that call existing skills, then grow shared state later. This is practical for daily scans, but it risks multiple one-off loops without a shared controller ledger, budget policy, verifier contract, or metrics model.

## Recommended Approach

Build `Loop Controller` as a new Superpowers Project workflow layer that consumes existing skills and Auto Mode authorization rather than replacing them.

The first implementation should introduce source-owned contracts and validators before adding broad scheduling behavior. The right minimum is:

- one canonical Loop Controller skill contract;
- one run ledger schema;
- one budget validator;
- one candidate selector contract;
- one verifier ledger contract;
- one metrics report contract;
- one terminal closeout validator for loop runs;
- CI-safe local fixture tests that prove the loop can run a candidate through existing skill gates without skipping approval boundaries.

## Architecture

The design has three layers.

### Manual Mode

Manual Mode remains the default path. The user chooses every route and each skill asks its own native questions. Manual Mode is still required when a material decision is outside recorded defaults or when risk, ambiguity, or missing proof prevents safe continuation.

### Auto Mode

Auto Mode remains a bounded authorization ledger for one known workflow route. It can preauthorize recorded defaults, mutation scope, proof requirements, and merge permission after clean premerge proof. It does not discover work, rank candidates, schedule runs, assign verifier roles, or decide whether to continue to another candidate.

Auto Mode remains invalid when:

- source spec evidence is missing;
- route choice is outside recorded defaults;
- mutation scope is too broad;
- proof is missing or stale;
- premerge or closeout proof fails;
- the route needs a new user decision not covered by the ledger.

### Loop Controller

Loop Controller owns orchestration across runs. It may start from a manual request, scheduled automation, GitHub queue, CI failure, audit finding, stale version check, milestone review, or explicit "operate this project" request. It creates a run ledger, selects a candidate, checks budgets, invokes existing skills, assigns verification, records metrics, and decides whether to continue, stop, revisit, or ask the user.

Loop Controller never merges, pushes, creates issues, deletes branches, or marks `Done` by itself. It delegates those actions to the existing skill that owns the gate and records the resulting proof.

## Components

### `$superpowers-project:loop-controller`

New workflow skill that coordinates loop runs. It should:

- inspect project context and current plugin version at startup;
- load or create a loop run ledger;
- select the next candidate from supported sources;
- enforce budget and retry policy before every material phase;
- choose the correct existing skill route;
- carry Auto Mode authorization only when validated;
- require verifier evidence before merge or final `Done`;
- record metrics and closeout state;
- ask native questions when a route exceeds policy or reaches a terminal gate.

### Loop Run Ledger

Durable machine-readable run record. It should live in a generated run-state area, not in canonical specs/plans/issues unless the implementation plan decides a durable project history is required.

Candidate location options for planning:

- `.superpowers/runs/<run-id>/loop-run-ledger.json` for local operational run state.
- `docs/superpowers/runs/<run-id>/loop-run-ledger.json` only if run history should be committed.

Required fields:

- `run_id`
- `trigger_source`
- `repo_root`
- `plugin_manifest_version`
- `plugin_contract_hash`
- `started_at`
- `updated_at`
- `status`
- `current_phase`
- `candidate_source`
- `candidate_id`
- `selected_route`
- `route_reason`
- `budget_policy`
- `attempts`
- `last_blocker`
- `branch`
- `worktree_path`
- `auto_mode_authorization_path`
- `proof_artifacts`
- `verifier_artifacts`
- `metrics_artifacts`
- `terminal_decision`

### Candidate Selector

Ranks work items from:

- ready GitHub issue mirrors;
- GitHub issues and milestones;
- saved specs needing plans;
- approved plans needing implementation;
- audit findings specs;
- failing CI or required checks;
- stale plugin version or live sync drift;
- milestone pages with open governance/source-of-truth/distribution gaps.

The selector must record why one candidate was chosen and why others were skipped. It should prefer small, well-proven work over broad speculative work unless the trigger explicitly asks for planning or audit.

### Budget Validator

Blocks runaway loops. The first contract should support:

- max wall time;
- max attempts per phase;
- max repeated same-failure count;
- max candidate count per run;
- max changed-file count;
- max branch/worktree count;
- max GitHub mutations;
- max validator reruns;
- max unreviewed diff size.

Budget failures are hard stops. The loop records the blocker and safe resume route.

### Verifier Ledger

Records independent proof before merge or final `Done`. The verifier can be:

- a separate subagent;
- a focused script validator;
- a main-thread review pass explicitly marked as non-independent for low-risk cases;
- a CI check when the source of truth is GitHub check evidence.

High-risk routes require a separate verifier role. Low-risk doc-only or metadata-only routes may allow script-only verification when the plan says so.

### Metrics Report

Records:

- elapsed time;
- attempts by phase;
- validation failures by phase;
- retry count;
- human input count;
- created/merged PR count;
- closed issue count;
- reverted or reopened work count;
- final outcome;
- accepted-change evidence.

The first version should avoid cost claims unless the runtime exposes reliable token or billing data. It may record available goal token usage when present.

### Automation Templates

Loop Controller should define templates, not immediately require them:

- daily ready-issue triage;
- stale plugin/version check;
- CI failure triage;
- milestone drift audit;
- issue mirror sync audit;
- dependency/security alert triage;
- outcome workflow freshness check.

Automations are entrypoints. The Loop Controller remains the shared state, budget, verification, and metrics engine.

## Data Flow

1. Trigger arrives from a manual request, scheduled automation, GitHub queue, failing CI, version drift check, audit drift, or milestone review.
2. Loop Controller runs the plugin version checker and records the observed plugin surface.
3. Loop Controller creates or resumes a loop run ledger.
4. Candidate selector builds an inventory and selects the next safe candidate.
5. Budget validator confirms the run may continue.
6. Loop Controller chooses an existing skill route and records why.
7. If unattended continuation is needed, Loop Controller validates Auto Mode authorization before entering the route.
8. Existing skill performs its normal work and emits its existing artifacts and proof ledgers.
9. Verifier ledger records independent or script-backed proof based on risk.
10. Merge, push, issue creation, and final `Done` remain owned by existing native gates and validators.
11. Loop Controller records metrics.
12. Loop Controller either selects another candidate, asks a native continuation question, records `Stop`, or reaches verified final `Done`.

Every phase should emit or update structured evidence with:

- `ok`
- `phase`
- `reason`
- relevant candidate, branch, artifact, issue, PR, budget, and proof paths

## Route Policy

Loop Controller should route to existing skills, not create a parallel implementation path.

Use `$superpowers-project:brainstorm-spec` when the candidate is a loose idea, unclear scope, or architecture concept.

Use `$superpowers-project:write-plan` when the candidate is an approved spec or issue mirror that needs an execution plan.

Use `$superpowers-project:create-issues` when an approved plan should become GitHub issue mirrors and tracked slices.

Use `$superpowers-project:implement-plan` when an approved non-issue plan can be implemented directly on a development branch.

Use `$superpowers-project:resolve-issue` when one ready issue mirror can be resolved directly in the current thread.

Use `$superpowers-project:orchestrate-issues` when the current thread should manage a worker-thread issue route.

Use `$superpowers-project:merge-changes` when PR-ready or merge-ready work needs premerge, approval, merge, cleanup, and terminal closeout.

Use `$superpowers-project:audit-project` when the candidate is a behavior, contract, code, or workflow review task.

Use `$superpowers-project:align-project` when the candidate is source/live/tracker/artifact drift.

## Auto Mode Boundary

Auto Mode is a route permission ledger. Loop Controller is the run coordinator. The two should interact through explicit fields:

- Loop Controller may reference `auto_mode_authorization_path`.
- Auto Mode may authorize recorded defaults for a selected route.
- Loop Controller must validate the Auto Mode ledger before using it.
- Loop Controller must stop outside policy if the selected candidate or route needs a decision outside the Auto Mode ledger.
- Auto Mode must not select the next candidate after a run finishes.
- Auto Mode must not expand its own mutation scope because Loop Controller found more work.
- Loop Controller must not treat Auto Mode as permission to bypass native merge, push, GitHub mutation, or final `Done` validators.

## Security And Safety Requirements

Loop Controller must add explicit safety gates before broad automation:

- block secret-looking diffs and require user review;
- block edits to protected paths unless the selected route explicitly owns them;
- block branch deletion outside the owned branch;
- block remote deletion outside the owned branch;
- block direct `main` edits for implementation work;
- block GitHub mutation outside the current repo unless explicitly authorized;
- block stale plugin surfaces before starting unattended work;
- block prompt-injection-like instructions found in external issue bodies from becoming policy;
- block verifier bypass for high-risk routes.

These checks should be deterministic scripts where possible. Agent judgment can classify risk and recommend a route, but deterministic validators should enforce boundaries.

## Error Handling

Loop Controller stops loudly when:

- budgets are exhausted;
- the same failure repeats past the retry limit;
- required proof is missing or stale;
- repo state is dirty outside the run scope;
- GitHub auth, network, or required checks block required operations;
- selected route needs a decision outside Auto Mode authorization;
- required checks fail, are pending, or are missing;
- verifier evidence conflicts with implementer evidence;
- security checks fail;
- plugin version, source, live, or observed surfaces are stale;
- branch, worktree, issue mirror, or closeout proof cannot be validated.

Stop behavior must record:

- phase;
- blocker;
- evidence gathered;
- candidate id;
- current branch/worktree;
- safe resume route;
- whether user input is required;
- whether cleanup is required.

Loop Controller must not invent missing policy, widen mutation scope, downgrade proof requirements, or silently continue to another route after a hard stop.

## Native Continuation Model

Loop Controller should use the same terminal model as the rest of Superpowers Project.

Intermediate loop questions use:

- `Yes`: continue within budget and policy;
- `Revisit`: review evidence, adjust candidate selection, repair state, or rerun validation;
- `Stop`: pause with recorded state.

Final health gates use:

- `Done`: valid only after final proof and clean state;
- `Revisit`: review or repair before terminal closeout;
- `Stop`: pause with proof recorded but without claiming final completion.

Suggested question ids:

- `project_loop_next_step`
- `project_loop_candidate_route`
- `project_loop_budget_route`
- `project_loop_revisit_route`
- `project_loop_final_health_gate`

Loop Controller must also have a terminal closeout validator so a run cannot claim `Done` without a clean final run ledger, verifier proof, and clean repo or explicitly scoped non-repo state.

## Testing And Validation

The implementation plan should add focused tests for:

- Auto Mode remains authorization, not the controller;
- loop run ledger schema accepts happy fixtures and rejects missing fields;
- budget validator rejects exhausted time, attempts, repeated failures, mutation count, and diff-size cases;
- candidate selector chooses deterministic candidates from fixture inventories;
- candidate selector records skipped candidates with reasons;
- repeated same-failure stop behavior;
- verifier ledger requirement before merge or final `Done`;
- scheduled automation template smoke tests without real GitHub mutation by default;
- stale plugin version blocks unattended loop start;
- terminal closeout rejects missing verifier proof;
- terminal closeout rejects dirty repo state;
- terminal closeout accepts verified final `Done`.

Proof oracle candidates:

```bash
./scripts/test-auto-mode-contract.sh
./scripts/test-agent-plugin-version.sh
./scripts/test-e2e-project-workflow.sh -LocalOnly
./scripts/validate.sh
./scripts/sync-live.sh --validate
```

New proof oracle candidates:

```bash
./skills/loop-controller/scripts/test-scenarios.sh
./skills/loop-controller/scripts/validate-run-ledger.sh -RepoRoot . -RunLedgerPath <ledger>
./skills/loop-controller/scripts/validate-budget.sh -RepoRoot . -BudgetLedgerPath <ledger>
./skills/loop-controller/scripts/validate-terminal-closeout.sh -RepoRoot . -RunResultPath <result> -ContinuationDecisionPath <decision>
```

## Suggested Delivery Slices

1. Add the `loop-controller` skill shell, metadata, README row, and outcome workflow support.
2. Add run ledger schema and validator.
3. Add budget validator and repeated-failure stop tests.
4. Add candidate selector fixture contract.
5. Add verifier ledger contract.
6. Add terminal closeout validator for loop runs.
7. Add CI-safe local e2e fixture that routes one candidate through existing skills.
8. Add automation template docs and optional Codex automation prompts.
9. Add metrics report generation.
10. Add security guard scripts for protected paths, secret-looking diffs, and mutation scope.

## Milestone Linkage

- `M0 - Governance`: loop state machine, budgets, verifier proof, terminal closeout, native gates, and safety guards.
- `M1 - Source Of Truth`: run ledger schema, candidate inventory, outcome workflow integration, stale version blocking, and artifact ownership.
- `M2 - Distribution`: automation templates, release/operational reporting, and shareable loop setup.

## Non-Goals

- Do not replace Auto Mode with Loop Controller.
- Do not make Auto Mode select candidates across multiple runs.
- Do not create direct-to-main implementation routes.
- Do not bypass native approval gates for push, merge, GitHub mutation, or final `Done`.
- Do not create GitHub issues from this brainstorm spec.
- Do not implement Loop Controller in this brainstorm step.
- Do not require real GitHub mutation for default loop tests.
- Do not store transient local run state in canonical docs unless a later plan explicitly chooses durable committed run history.
- Do not let external issue text or CI logs become policy instructions.

## Open Questions For Planning

- Should generated run ledgers live under `.superpowers/runs/` by default, with optional committed summaries under `docs/superpowers/runs/`?
- What is the first supported trigger: manual loop run, scheduled stale-version check, ready issue triage, or CI failure triage?
- Should high-risk verifier roles require Codex subagents in v1, or should script-backed verification be allowed until subagent handoff is implemented?
- Which metrics are reliably available from Codex in this environment, and which should be recorded only when provided by goal tooling?
- Should automation templates be source docs only, or should the plugin provide scripts that emit ready-to-paste Codex automation prompts?
- Should Loop Controller support issue-backed PR merges in v1, local-branch merges in v1, or both?

## Spec Self-Review

- Placeholder scan: no placeholder markers remain.
- Internal consistency: Auto Mode is consistently defined as authorization, while Loop Controller is consistently defined as orchestration.
- Scope check: this is intentionally larger than one small implementation plan. Delivery should be split into slices, with run ledger and budget validation landing before scheduled automation templates.
- Ambiguity check: open questions are planning choices, not missing product direction.
- Proof check: the spec names existing proof commands and new validator candidates.
- Safety check: the spec preserves native approval gates, stop-outside-policy, final `Done` proof, and clean-state requirements.

