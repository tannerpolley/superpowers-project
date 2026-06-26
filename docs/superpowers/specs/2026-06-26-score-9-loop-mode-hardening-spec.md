# Superpowers Project Score 9+ And Looping Mode Hardening Spec

**Date:** 2026-06-26
**Repo:** `tannerpolley/superpowers-project`
**Current audited HEAD:** `3517b412e133255ed01bec6b63037bd3773b06c1`
**Source:** ChatGPT re-audit after workflow-normalization changes landed
**Status:** Canonical Superpowers Project spec promoted from `.chatgpt` handoff for issue creation and implementation planning

## Purpose

This packet turns the latest re-audit into a concrete follow-up spec. The goal is to raise every workflow-quality score to at least 9/10 and to make Looping Mode a predictable, validator-backed state machine rather than a broad autonomy concept.

The previous repair wave landed the major architecture pieces:

- `docs/superpowers/workflow-contract.yml`
- compact `skills/*/agents/openai.yaml`
- centralized global continuation policy in `skills/advanced-user-input/SKILL.md`
- `Decision Ledger` requirements and validator
- `Artifact Review Card` schema and validator
- `docs/superpowers/backlog/ACTIVE.md`
- generated-state guardrails
- golden-path workflow examples
- worker handoff packet examples
- expanded `scripts/validate.ps1` coverage

The next wave should make those pieces authoritative enough that a fresh agent cannot accidentally flatten route menus, misread Looping Mode as open-ended autonomy, or trust a stale workflow-contract entry that disagrees with a `SKILL.md` route block.

## Target Scorecard

The target is not merely “tests pass.” The project should hit or exceed these scores in the next audit.

| Area | Current re-audit estimate | Target | Required change to reach target |
|---|---:|---:|---|
| Full workflow coverage | 9.2 | 9.3+ | Register every material gate, including board approval and issue-resolution route gates. |
| Project context + issues | 8.8 | 9.1+ | Tie active backlog, issue mirrors, workflow contract, examples, and milestone receipts into one source-of-truth narrative. |
| Decision gates | 8.0 | 9.2+ | Add gate types and exact option validation from `SKILL.md` against `workflow-contract.yml`. |
| Grilling behavior | 8.5 | 9.1+ | Make Decision Ledger required in example/golden-path specs and plans, not only validator fixtures. |
| Clear goals/outputs | 9.0 | 9.2+ | Polish Artifact Review Card wording and eliminate machine-patched duplicate summary fragments. |
| Predictability | 7.8 | 9.1+ | Eliminate registry/SKILL/YAML option drift; metadata must not flatten Yes/Revisit/Stop geometry. |
| Friction/clutter | 7.0 | 9.0+ | Keep metadata short and skill-local prose clean while retaining exact route blocks. |
| Ship confidence | 8.0 local, 7.3 public | 9.0+ | Add end-to-end Looping Mode fixtures, scorecard validation receipt, and clean source/live/tracker proof. |

## Executive Findings From Latest Re-Audit

### What is now good

1. The repo is clean on `main`.
2. The workflow contract exists and is wired into validation.
3. Metadata prompts are significantly smaller and point to `SKILL.md` plus `docs/superpowers/workflow-contract.yml`.
4. `advanced-user-input` now clearly owns global native continuation, artifact-review, Stop/Revisit/Done, and Custom Other behavior.
5. `brainstorm-spec` and `write-plan` now require a `Decision Ledger`.
6. Artifact Review Card schema exists.
7. Active backlog exists and separates ready candidates from historical plan checkboxes.
8. Generated runtime state guardrails exist.
9. Workflow golden paths and worker packets exist.
10. `scripts/validate.ps1` has much broader coverage than before.

### What still blocks a 9+ score

The main blocker is that `workflow-contract.yml` is still more of a question-ID index than a truly authoritative route contract. It validates that question IDs exist, but it does not reliably validate exact option labels, gate type, or metadata geometry against actual `SKILL.md` route blocks.

Concrete mismatches observed:

- `workflow-contract.yml` says `project_align_prepare_route` has `[Prepare Repair, Prepare Issues]`; `skills/align-project/SKILL.md` says `Create Planning Spec` and `Plan Or Issue Repair`.
- `workflow-contract.yml` says `project_align_repair_group` has `[Repair Local, Repair Tracker]`; `skills/align-project/SKILL.md` says `Apply Repair` and `Prepare Repair Work`.
- `workflow-contract.yml` says `project_setup_work_route` has `[Create Roadmap, Configure Tracker]`; `skills/setup-project/SKILL.md` says `Brainstorm New Spec`, `Write Plan`, and `Create Issues`.
- `workflow-contract.yml` says `project_merge_approval` has `[Merge, Hold]`; `skills/merge-changes/SKILL.md` says `Merge` and `Decline`.
- `workflow-contract.yml` says `implement_plan_push_permission` has `[Push And Open PR, Hold]`; `skills/implement-plan/SKILL.md` says `Push Branch` and `Hold`.

Second blocker: several compact metadata prompts still flatten continuation geometry. For example, metadata says `project_setup_next_step has Brainstorm New Spec, Write Plan, Create Issues, Run Align, and Stop`, but `project_setup_next_step` is a top-level continuation gate whose visible options should be `Yes`, `Revisit`, and `Stop`. The child routes belong under nested questions.

Third blocker: material gates such as `project_setup_board_approval` and `project_issue_resolution_route` appear in prose but are not registered as canonical `Question id:` blocks in the workflow contract.

Fourth blocker: Looping Mode needs a stricter state machine and end-to-end fixtures that prove it chooses one candidate, routes to the owner skill, returns after closeout, re-checks budget, and asks a continuation gate before selecting another candidate.

## Selected Design

Use a registry-authoritative hardening pass. The workflow contract becomes the canonical source for every material native gate, but every gate must also be checked against the real `SKILL.md` route blocks. The contract is not allowed to drift silently. Metadata can summarize only in safe shapes, and Looping Mode must be modeled as a state machine with explicit phase ledgers and budget/candidate checks.

Do not create a new user-facing workflow skill for this repair. This is a governance and validation hardening pass over the existing architecture.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Canonical source promotion | User request and `.chatgpt` handoff | Promote this audit packet into `docs/superpowers/specs` as the canonical source spec. | Planning, issue creation, and implementation use this repo-owned spec instead of the `.chatgpt` handoff path. | No | `write-plan` |
| Execution topology | User request to integrate until full merge plus workflow mode gate | Use Looping Mode with issue-backed slices. | The program can create multiple issues and resolve them one at a time with merge proof after each route. | No | `loop-controller` |
| Implementation strategy | Spec Agent Instructions | Prefer issue-backed slices and avoid one giant branch. | Workstreams become independently verifiable issue mirrors before implementation. | No | `create-issues` |
| Highest-risk area | Re-audit finding | Harden Looping Mode as a strict state machine before claiming score 9+. | Loop state-machine validators and fixtures are required for final Done. | No | `resolve-issue` |
| Final proof | Final Done Criteria | Require validate, sync-live, version freshness, exact-option, metadata, loop state, scorecard, align/tracker, cleanup, and clean Git proof. | Merge closeout cannot rely on prose or partial local tests. | No | `merge-changes` |

## Workstream A: Make `workflow-contract.yml` Authoritative

### Goal

Make the workflow contract validate exact gate types and exact option labels against `SKILL.md`, not just question IDs.

### Required changes

Add `gate_type` to every question entry. Replace the current loose `nested_routes` model with typed gates. Recommended gate types:

```yaml
- workflow_mode
- top_level_continuation
- nested_yes_route
- nested_revisit_route
- approval
- permission
- topology
- final_health
- repair_choice
- data_selection
```

Each gate should include:

```yaml
question_id: project_plan_issue_execution_route
gate_type: nested_yes_route
prompt: Which ready-issue execution route should continue from this plan?
parent_question_id: project_plan_work_route
parent_option: Use Ready Issue
options:
  - label: Resolve Issue
    terminal_state: continue
    next_route: resolve-issue
  - label: Orchestrate Issues
    terminal_state: continue
    next_route: orchestrate-issues
```

For approval/permission gates, the validator must allow non-Yes/Revisit/Stop labels and must not force nested-route rules. Example:

```yaml
question_id: project_merge_approval
gate_type: approval
options:
  - label: Merge
    approval_effect: approve-merge
  - label: Decline
    approval_effect: decline-merge
```

For topology gates, terminal options may be valid only when explicitly allowed:

```yaml
question_id: implement_plan_topology
gate_type: topology
allow_terminal_options: true
options:
  - label: Inline
  - label: Worker
  - label: Stop
```

### Validator requirements

Update `scripts/validate-workflow-contract.ps1` so it:

1. Parses every `Question id: ` block from every workflow `SKILL.md`.
2. Extracts the nearest following `Prompt:` and `Options:` block.
3. Extracts option labels exactly as written, including backtick labels.
4. Compares each skill gate's option labels against `workflow-contract.yml`.
5. Fails when the contract contains options that do not exist in `SKILL.md`.
6. Fails when `SKILL.md` contains options missing from the contract.
7. Applies gate-type rules:
   - top-level continuation: exactly `Yes`, `Revisit`, `Stop`.
   - final health: exactly `Done`, `Revisit`, `Stop`.
   - nested Yes route: no `Stop`, no `Done`, no `Revisit` unless explicitly a data choice and justified.
   - nested Revisit route: no `Stop`, no `Done`, no `Yes` unless explicitly a data choice and justified.
   - approval: labels must map to `approval_effect` values.
   - permission: labels must map to `permission_effect` values.
   - topology: labels must map to execution topologies; `Stop` is allowed only when declared.
8. Fails when a native-question-like identifier appears in prose but is not registered.

Native-question-like identifiers include regex patterns like:

```regex
project_[a-z0-9_]+|implement_plan_[a-z0-9_]+
```

If the identifier is intentionally not a native gate, it must be listed in a contract allowlist with reason.

### Acceptance criteria

- [ ] Every material native gate in every active `SKILL.md` appears in `docs/superpowers/workflow-contract.yml`.
- [ ] Every workflow-contract gate maps to an actual `Question id:` block in a `SKILL.md`, unless it is explicitly generated/legacy/allowlisted with a reason.
- [ ] Exact option-label mismatches fail validation.
- [ ] The known mismatches in `align-project`, `setup-project`, `merge-changes`, and `implement-plan` are fixed.
- [ ] `project_setup_board_approval` is either registered with exact prompt/options or rewritten into a canonical `Question id:` block and registered.
- [ ] `project_issue_resolution_route` is either registered with exact prompt/options or removed from active prose and replaced by a registered gate.
- [ ] `scripts/test-workflow-contract.ps1` has fixtures for exact-option mismatch, missing gate registration, invalid terminal option in nested route, approval gate, permission gate, topology gate, and final health gate.

### Proof oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Workstream B: Prevent Metadata From Flattening Route Geometry

### Goal

Compact metadata should help select the skill, not restate route trees incorrectly. It must never present nested child routes as top-level options beside `Stop`.

### Required changes

Update `scripts/validate-skill-metadata-contract.ps1` so it can distinguish top-level gate summaries from child-route summaries. Metadata may mention routes only in one of these safe forms:

Safe form 1:

```text
Read SKILL.md and docs/superpowers/workflow-contract.yml for exact route geometry.
```

Safe form 2:

```text
Top-level gate: Yes, Revisit, Stop. Yes child routes include Brainstorm New Spec, Write Plan, and Create Issues.
```

Unsafe form:

```text
project_setup_next_step has Brainstorm New Spec, Write Plan, Create Issues, Run Align, and Stop.
```

Because that flattens a child menu into a top-level continuation gate.

### Acceptance criteria

- [ ] Metadata validator fails if a `*_next_step` top-level continuation gate summary lists child options directly beside `Stop`.
- [ ] Metadata validator fails if metadata lists unsupported options for a registered gate.
- [ ] Metadata validator allows either no route summary or a clearly nested summary.
- [ ] `skills/setup-project/agents/openai.yaml`, `skills/create-issues/agents/openai.yaml`, `skills/merge-changes/agents/openai.yaml`, `skills/resolve-issue/agents/openai.yaml`, and `skills/brainstorm-spec/agents/openai.yaml` no longer flatten child routes into top-level gate summaries.
- [ ] All metadata prompts remain compact and point to `SKILL.md` plus `docs/superpowers/workflow-contract.yml`.

### Proof oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-metadata-contract.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Workstream C: Clean Skill Prose After Centralization

### Goal

The first normalization pass removed major duplication but left awkward machine-patched text in several route-specific sections. Clean it without weakening any gate.

### Examples to fix

Patterns like:

```text
After artifacts are shown, add a separate findings summary...
Add the helper-required findings summary...
```

and:

```text
before asking native push permission:. Add the helper-required...
```

These should be replaced by clear route-local wording:

```text
Before this push gate, show the helper Artifact Review Card. Route-specific card inventory must include branch, changed files, verification receipts, cleanup proof, readiness review, and push decision state.
```

### Acceptance criteria

- [ ] No `SKILL.md` contains duplicate sentence fragments caused by the previous rewrite.
- [ ] No route-specific Artifact Review Card paragraph repeats the full helper findings-summary paragraph.
- [ ] Every route-specific section still lists the artifacts that are unique to that route.
- [ ] `validate-global-policy-deduplication.ps1` still passes.
- [ ] `test-artifact-review-card.ps1` still passes.

### Proof oracle

```powershell
rg -n "Add the helper-required findings summary|permission question:\.|artifacts are shown.*Add the helper" skills
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-global-policy-deduplication.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Workstream D: Make Looping Mode A Strict State Machine

### Goal

Looping Mode should be a validated coordinator that runs one candidate at a time, routes to the owning skill, returns after completion or pause, re-checks budget, records proof, and asks `project_loop_next_step` before selecting another candidate. It must never become open-ended Auto Mode or a route-gate bypass.

### Required Looping Mode phases

Define these phases in a loop mode state contract, either in `docs/superpowers/workflow-contract.yml` under `loop-controller` or in a dedicated file such as `docs/superpowers/loop-mode-contract.yml`.

```text
1. mode_intake
2. workflow_mode_ledger_validated
3. budget_ledger_validated
4. candidate_inventory_loaded
5. candidate_selected
6. owner_route_handoff_created
7. owner_route_running
8. owner_route_result_collected
9. verifier_ledger_validated
10. metrics_written
11. budget_rechecked
12. loop_continuation_gate_asked
13. next_candidate_allowed_or_terminal
```

### Looping Mode invariants

Looping Mode must enforce these invariants:

1. It starts only from `project_workflow_mode` with `Looping Mode`, or from an explicitly resumed loop ledger.
2. A validated workflow-mode ledger with `selected_mode: looping` is required before candidate selection.
3. Auto Mode authorization must not be used to select another candidate.
4. A loop run may select only one candidate before returning to the loop continuation gate.
5. Candidate source precedence is explicit:
   - explicit user-selected candidate;
   - active backlog ready row;
   - explicit run inventory;
   - no candidate.
6. Historical plan checkboxes are not candidate sources unless linked from active backlog or a ready issue mirror.
7. Generated `.superpowers/runs/**` ledgers are runtime evidence, not canonical backlog.
8. Each selected candidate must have:
   - candidate id;
   - route owner;
   - source artifact;
   - readiness reason;
   - proof target;
   - budget estimate or budget effect;
   - stop condition.
9. The owning skill must execute the actual work. Loop Controller must not implement route work directly.
10. After the owner route returns, Loop Controller must validate verifier proof and budget before selecting another candidate.
11. `project_loop_next_step` must be asked before another candidate is selected.
12. `project_loop_final_health_gate` can use `Done` only when run ledger, verifier proof, metrics, and clean repo or explicitly scoped non-repo state are proven.
13. Looping Mode must block if there is a dirty worktree that is not explicitly scoped to generated local state.
14. If there are no ready candidates, the loop should produce a no-ready-candidate proof and ask Stop/Revisit/final health according to the contract.

### Required ledgers

Looping Mode should produce or validate these ledgers:

```text
.superpowers/runs/<run-id>/workflow-mode-ledger.json
.superpowers/runs/<run-id>/budget-ledger.json
.superpowers/runs/<run-id>/candidate-inventory.json
.superpowers/runs/<run-id>/candidate-selection.json
.superpowers/runs/<run-id>/owner-route-handoff.json
.superpowers/runs/<run-id>/owner-route-result.json
.superpowers/runs/<run-id>/verifier-ledger.json
.superpowers/runs/<run-id>/metrics-report.json
.superpowers/runs/<run-id>/loop-continuation-decision.json
```

Some files can be absent when the phase is not reached, but absence must be explainable in the run ledger.

### Validator requirements

Add or extend validators so they prove:

- phase order is valid;
- only one candidate is selected per loop iteration;
- no next candidate is selected before `project_loop_next_step` is answered;
- candidate source is allowed;
- owner route matches workflow contract;
- owner route result has a proof target and status;
- budget was checked before and after the owner route;
- final Done is blocked without clean proof;
- no-ready-candidate runs produce explicit no-candidate evidence;
- Auto Mode ledgers cannot authorize Looping Mode candidate selection.

Likely files:

```text
skills/loop-controller/SKILL.md
skills/loop-controller/scripts/select-candidate.ps1
skills/loop-controller/scripts/validate-run-ledger.ps1
skills/loop-controller/scripts/validate-budget.ps1
skills/loop-controller/scripts/validate-verifier-ledger.ps1
skills/loop-controller/scripts/validate-terminal-closeout.ps1
skills/loop-controller/scripts/validate-loop-state-machine.ps1
skills/loop-controller/scripts/test-scenarios.ps1
scripts/test-loop-controller.ps1
scripts/validate-workflow-examples.ps1
scripts/validate.ps1
docs/superpowers/workflow-contract.yml
docs/superpowers/examples/workflow-golden-paths.md
docs/superpowers/backlog/ACTIVE.md
```

### End-to-end loop fixtures

Add fixtures for at least these cases:

1. **One ready candidate, manual continuation:** Loop selects exactly one active backlog item, routes to owner, records verifier proof, re-checks budget, asks `project_loop_next_step`, then stops.
2. **Two ready candidates, no auto-drain:** Loop selects candidate A only. Candidate B remains unselected until the continuation gate is answered.
3. **No ready candidates:** Loop records no-ready proof and asks a terminal/revisit gate without pretending work is done.
4. **Auto Mode cannot drive Looping Mode:** An Auto Mode authorization ledger with `bounded-auto-merge` cannot be used to select a second candidate.
5. **Budget exhausted:** Loop blocks next selection and asks continuation/revisit instead of selecting more work.
6. **Dirty repo:** Loop blocks final Done or next selection unless dirty state is explicitly allowed generated local state.
7. **Owner mismatch:** A candidate whose route owner is not in `workflow-contract.yml` fails selection.
8. **Historical checkbox:** A plan checkbox not linked from active backlog fails candidate selection.

### Acceptance criteria

- [ ] Looping Mode phases are documented in a source-owned contract.
- [ ] Looping Mode phase validator exists and is wired into `scripts/validate.ps1`.
- [ ] Looping Mode cannot select a second candidate without a recorded `project_loop_next_step` answer.
- [ ] Looping Mode cannot use Auto Mode authorization as broad queue-draining authority.
- [ ] Candidate source precedence is explicit and tested.
- [ ] Active backlog ready rows are accepted; historical plan checkboxes are rejected.
- [ ] No-ready-candidate state is explicit and tested.
- [ ] Budget exhaustion blocks candidate selection and final Done unless the final health rules are satisfied.
- [ ] `project_loop_final_health_gate` is validated against run ledger, verifier proof, metrics, and clean state.
- [ ] Golden-path Looping Mode example matches the real state machine.

### Proof oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\validate-loop-state-machine.ps1 -RepoRoot . -RunRoot .superpowers/runs/<fixture-run>
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-examples.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Workstream E: Add A Scorecard Validator And Receipt

### Goal

Create a durable proof that the workflow has reached the intended 9+ standard. This should not be subjective fluff; each score should map to concrete validators and evidence.

### Scorecard schema

Create a file such as:

```text
docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md
```

The receipt should include:

```markdown
# Score 9+ And Looping Mode Hardening Receipt

## Scorecard

| Area | Target | Evidence | Result |
|---|---:|---|---|
| Full workflow coverage | >=9 | all gates registered, exact option validator passes | pass |
| Project context + issues | >=9 | backlog, issue mirror, milestone, workflow contract links pass | pass |
| Decision gates | >=9 | gate types + exact option validation pass | pass |
| Grilling behavior | >=9 | Decision Ledger validators and examples pass | pass |
| Clear goals/outputs | >=9 | Outcome Proof + Artifact Review Card validators pass | pass |
| Predictability | >=9 | contract/SKILL/YAML/example drift checks pass | pass |
| Friction/clutter | >=9 | metadata compactness and duplicate-policy validator pass | pass |
| Ship confidence | >=9 | validate, sync-live, loop E2E, tracker/align proof pass | pass |

## Command Receipts

| Command | Result | Notes |
|---|---|---|
```

Add a validator such as:

```text
scripts/validate-scorecard-proof.ps1
scripts/test-scorecard-proof.ps1
```

### Acceptance criteria

- [ ] Scorecard receipt exists and is linked from M0/M1 milestone pages.
- [ ] Every score area has at least one command receipt and at least one source artifact link.
- [ ] Validator fails if any target score is below 9.
- [ ] Validator fails if any command receipt is missing or not marked pass.
- [ ] Receipt includes Looping Mode end-to-end proof.
- [ ] Receipt includes live sync and tracker/align proof.

### Proof oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-scorecard-proof.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-scorecard-proof.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Workstream F: Improve Project Context And Issue Readiness Narrative

### Goal

Raise `Project context + issues` from 8.8 to 9+ by making the relationship between context, workflow contract, active backlog, issue mirrors, milestone receipts, and Looping Mode explicit.

### Required changes

Update canonical docs to state:

- `docs/superpowers/workflow-contract.yml` is the route contract.
- `docs/superpowers/backlog/ACTIVE.md` is the active loop candidate source.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface, not a source of truth.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence.
- `docs/superpowers/milestones/*receipt*.md` files are validation receipts, not active backlog.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs.

Likely files:

```text
docs/superpowers/PROJECT_CONTEXT.md
README.md
docs/superpowers/OUTCOME_WORKFLOW.md
docs/superpowers/milestones/M0-governance.md
docs/superpowers/milestones/M1-source-of-truth.md
docs/superpowers/backlog/ACTIVE.md
```

### Acceptance criteria

- [ ] Project context names workflow contract, active backlog, examples, receipts, and generated state roles.
- [ ] README describes Looping Mode state-machine behavior without implying open-ended Auto Mode.
- [ ] Milestone pages link the scorecard receipt and loop-mode hardening result.
- [ ] No doc calls `.chatgpt/**` or `.superpowers/**` canonical.

### Proof oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-generated-state.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-active-backlog.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-scorecard-proof.ps1 -RepoRoot .
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Workstream G: Keep Grilling At 9+ With Real Examples

### Goal

Decision Ledger requirements exist, but examples and docs should show actual high-quality grilling decisions, not only validators. This raises the grilling score above 9.

### Required changes

Add examples for:

1. brainstorm spec with repo-derived decisions, user decisions, and deferred decisions;
2. implementation plan carrying forward source spec decisions;
3. planning grill decision that changes owner/interface/cutover/acceptance proof.

These can live under:

```text
docs/superpowers/examples/decision-ledger-examples.md
```

or be added to golden paths.

### Acceptance criteria

- [ ] At least one spec-style Decision Ledger example validates.
- [ ] At least one plan-style Decision Ledger example validates.
- [ ] Examples include source types: user answer, repo evidence, planning grill, deferred decision.
- [ ] Deferred example includes risk owner and downstream impact.
- [ ] `brainstorm-spec` and `write-plan` both reference the examples.

### Proof oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-decision-ledger.ps1 -Path <example-spec> -Kind spec
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-decision-ledger.ps1 -Path <example-plan> -Kind plan
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-decision-ledger.ps1
```

## Proposed Issue Slices

Create or implement as issue-backed slices in this order.

### Issue 1: Authoritative Gate Types And Exact Option Validation

**Priority:** P1  
**Route owner:** `write-plan` then `resolve-issue` or direct implementation  
**Goal:** Make `workflow-contract.yml` authoritative over gate type and option labels.

Acceptance criteria:

- [ ] `workflow-contract.yml` defines typed gates.
- [ ] Exact option labels are parsed from `SKILL.md` and compared.
- [ ] Known mismatches are fixed.
- [ ] Missing gate registration fails.
- [ ] Gate type rules are enforced.

### Issue 2: Metadata Geometry Guardrails

**Priority:** P1  
**Goal:** Prevent metadata from flattening nested child routes into top-level continuation gates.

Acceptance criteria:

- [ ] Metadata validator rejects flattened top-level gate summaries.
- [ ] Metadata prompts mention route geometry only safely.
- [ ] No metadata prompt says a `*_next_step` has child routes beside `Stop`.

### Issue 3: Register All Material Native Gates

**Priority:** P1  
**Goal:** Convert prose-only gates into canonical `Question id:` blocks and registry entries.

Acceptance criteria:

- [ ] `project_setup_board_approval` registered or removed from active prose.
- [ ] `project_issue_resolution_route` registered or removed from active prose.
- [ ] Validator fails for unregistered native-question-like identifiers.

### Issue 4: Looping Mode State Machine

**Priority:** P1  
**Goal:** Make Looping Mode a strict, validated state machine.

Acceptance criteria:

- [ ] Loop phases documented.
- [ ] Loop state validator exists.
- [ ] One-candidate-per-iteration rule enforced.
- [ ] Budget recheck required before next candidate.
- [ ] No-ready, budget-exhausted, dirty-repo, auto-mode-misuse, and historical-checkbox fixtures pass/fail correctly.

### Issue 5: Scorecard Proof Receipt

**Priority:** P2  
**Goal:** Record validator-backed evidence that every quality score is 9+.

Acceptance criteria:

- [ ] Scorecard receipt exists.
- [ ] Receipt is validated.
- [ ] Milestone pages link receipt.
- [ ] Full validate/sync-live/tracker/align/loop proof appears in receipt.

### Issue 6: Skill Prose Polish And Artifact Card Clarity

**Priority:** P2  
**Goal:** Remove machine-patched awkward wording while preserving strict gates.

Acceptance criteria:

- [ ] No duplicate summary fragments remain.
- [ ] Route-specific Artifact Review Card inventory is concise and exact.
- [ ] Global policy remains centralized.

### Issue 7: Decision Ledger Examples

**Priority:** P2  
**Goal:** Raise grilling behavior to 9+ with practical examples.

Acceptance criteria:

- [ ] Spec and plan Decision Ledger examples exist and validate.
- [ ] Examples show user, repo, grill, and deferred sources.
- [ ] `brainstorm-spec` and `write-plan` reference examples.

## Final Done Criteria For This Hardening Program

The program is complete only when all of these are true:

- [ ] `scripts/validate.ps1` passes.
- [ ] `scripts/sync-live.ps1 -Validate` passes.
- [ ] `scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent` passes.
- [ ] New workflow contract exact-option validator passes.
- [ ] New metadata geometry validator passes.
- [ ] New Looping Mode state-machine validator passes.
- [ ] New scorecard proof validator passes with every score target >= 9.
- [ ] `skills/align-project/scripts/align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` passes or produces only documented non-blocking findings.
- [ ] Repo cleanup hook passes.
- [ ] `git status --short --branch` is clean.
- [ ] Milestone receipt records command proof.
- [ ] Active backlog has no ready candidates unless deliberately left for a follow-up.

## Agent Instructions

1. Treat the original `.chatgpt` file as the handoff source and this file as the canonical project spec.
2. Prefer creating issue-backed slices from the proposed issue list.
3. Do not implement everything in one giant branch unless the user explicitly chooses a direct implementation route.
4. Preserve strict proof behavior; do not weaken native user gates to make validation easier.
5. Make the workflow contract stricter before adding more docs.
6. Looping Mode is the highest behavioral-risk area and should be tested as a state machine before claiming score 9+.

## Summary

The previous changes moved the project from “good but cluttered” to “well-structured but not fully authoritative.” The next step is to make the new registry and Looping Mode rigorous enough that a fresh coding agent cannot accidentally choose the wrong option shape, skip a gate, continue a loop without permission, or rely on stale metadata.

If this spec is implemented with the acceptance criteria above, the project should plausibly reach these final scores:

| Area | Expected score after this spec |
|---|---:|
| Full workflow coverage | 9.4 |
| Project context + issues | 9.2 |
| Decision gates | 9.3 |
| Grilling behavior | 9.1 |
| Clear goals/outputs | 9.2 |
| Predictability | 9.2 |
| Friction/clutter | 9.0 |
| Ship confidence | 9.0 |
