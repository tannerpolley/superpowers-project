# Auto And Loop Lifecycle Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one startup mode selection authorize a complete Auto outcome lifecycle and make Looping repeat finite Auto-like candidates without routine intra-candidate questions.

**Architecture:** Add a versioned lifecycle controller and gate resolver beside the existing hash-chained workflow runtime. Preserve owner skills, but require them to consume shared lifecycle context and gate decisions instead of rendering autonomous questions. Bind raw-request authority first, append spec and plan bindings later, then route direct or issue-backed execution through an evidence-based rubric.

**Tech Stack:** Python 3, PyYAML, JSON/JSONL event ledgers, Bash launchers, Markdown skills, `unittest`, GitHub CLI/provider fixtures, and Codex native input instrumentation.

## Global Constraints

- Auto authorizes one requested outcome lifecycle, not one skill invocation.
- Auto asks one startup mode/authority question and zero routine downstream questions.
- Looping asks zero questions inside a candidate and remains finite through budgets and stop conditions.
- Root authorization binds the raw request and repository before a spec exists.
- Spec and plan attachment uses append-only hash-chained events; root authority is immutable.
- Manual Mode retains native questions at material gates.
- Every autonomous gate decision records selected and rejected options, evidence, and rationale.
- Issue creation, push, PR, and merge stay inside the current-repository mutation envelope and require fail-closed proof.
- No destructive Git, unrelated repository mutation, or broad queue drain is authorized.
- Apply TDD to every behavior change and require independent review plus fresh verification.
- Execute only after the execution-kernel issue is merged, rebase onto current `main`, and reuse its `HashRef`, canonical serializer, evidence kinds, and receipt interfaces.

---

## Source Evidence

- Approved source: `docs/superpowers/specs/2026-07-10-auto-loop-lifecycle-semantics-design.md`
- Umbrella audit: `docs/superpowers/specs/2026-07-10-autonomous-workflow-and-codex-worktree-audit-findings.md`
- Current policy contradiction: `scripts/lib/workflow_policy.py`
- Current runtime and event projection: `scripts/lib/workflow_runtime.py` and `scripts/lib/workflow_state.py`
- Current mode and Auto validators: `scripts/lib/superpowers_project_cli.py`
- Current question ownership: `skills/advanced-user-input/SKILL.md` and owner workflow skills
- Current graph authority: `docs/superpowers/workflow-contract.yml`

## Architecture And Interfaces

```python
def create_root_authorization(request: AuthorizationRequest) -> RootAuthorization: ...
def bind_artifact(state: LifecycleState, binding: ArtifactBinding) -> LifecycleEvent: ...
def transition_lifecycle(state: LifecycleState, transition: TransitionRequest) -> LifecycleEvent: ...
def resolve_gate(gate: GateRequest, context: LifecycleContext) -> GateDecision: ...
def decide_issue_route(evidence: IssueRouteEvidence) -> IssueRouteDecision: ...
def evaluate_loop(state: LoopState, policy: LoopPolicy) -> LoopDecision: ...
```

`RootAuthorization` binds repository identity, request fingerprint, candidate root, selected mode, provenance, interaction policy, mutation envelope, stop policy, and canonical hash. `GateDecision` records every option, evidence, selected action, rationale, resolver version, and event binding.

## Implementation Boundaries

**Files To Create:** `scripts/lib/lifecycle_authorization.py`, `scripts/lib/lifecycle_controller.py`, `scripts/lib/gate_resolver.py`, `scripts/lib/issue_route.py`, `scripts/lib/loop_lifecycle.py`, `scripts/lib/commands/lifecycle.py`, `tests/test_lifecycle_authorization.py`, `tests/test_lifecycle_controller.py`, `tests/test_gate_resolver.py`, `tests/test_issue_route.py`, `tests/test_loop_lifecycle.py`, `tests/test_auto_lifecycle_e2e.py`, and `tests/test_loop_lifecycle_e2e.py`.

**Files To Modify:** `scripts/lib/workflow_policy.py`, `scripts/lib/workflow_runtime.py`, `scripts/lib/workflow_state.py`, `scripts/lib/workflow_completion.py`, `scripts/lib/superpowers_project_cli.py`, `scripts/lib/command_catalog.py`, `docs/superpowers/workflow-contract.yml`, `docs/superpowers/governance-profiles.yml`, `docs/superpowers/loop-mode-contract.yml`, `skills/initiate-workflow/SKILL.md`, `skills/brainstorm-spec/SKILL.md`, `skills/write-plan/SKILL.md`, `skills/create-issues/SKILL.md`, `skills/implement-plan/SKILL.md`, `skills/resolve-issue/SKILL.md`, `skills/merge-changes/SKILL.md`, `skills/loop-controller/SKILL.md`, their focused scenario scripts, `scripts/run-agent-usability-trials.py`, and `scripts/validate.sh`.

**Files To Avoid:** evidence-gate internals owned by the execution-kernel plan, workspace-provider internals, distribution migration internals, vanilla Superpowers files, deployed cache files, unrelated repositories, and historical receipts.

**Source Of Truth:** `RootAuthorization` owns authority, lifecycle events own state transitions and artifact bindings, `workflow-contract.yml` owns gate IDs/options, and the gate resolver owns mode-specific question versus autonomous-decision behavior.

**Read Path:** Raw request and explicit mode selection, canonical repository identity, workflow contract gates, current event projection, bound spec/plan hashes, route evidence, provider receipts, validation receipts, loop budgets, and user interruptions.

**Write Path:** Append-only run events under `.superpowers/runs`, canonical specs/plans/issues through owner skills, current-repository implementation branches, and authorized GitHub issue/PR/merge operations after required proof.

**Integration Points:** Initiate workflow, brainstorming, plan writing, issue creation, direct implementation, issue resolution, merge closeout, Loop controller, workflow graph generation, GitHub provider observations, and installed-plugin trials.

**Migration Or Cutover:** After the execution kernel merges, rebase this issue onto current `main`. Add version-1 root authority and lifecycle events beside current ledgers, reuse the kernel `HashRef` and canonical serializer for every authorization, artifact, and receipt hash, migrate owner skills to the shared resolver, reject unsupported old Auto ledgers with an explicit restart route, then remove post-spec Auto and per-route autonomous question paths.

**Replaced Path Handling:** Retire source-spec-before-authorization validation, post-spec Auto re-entry, one-route-as-one-skill completion, hardcoded direct-inline issue routing, per-skill Auto questions, and bounded-merge prompting after valid Auto authority.

**Acceptance Proof Gate:** Each task needs focused RED/GREEN evidence and review; final acceptance requires raw-request Auto, issue-backed Auto, Manual, multi-candidate Looping, interruption, adversarial authorization, installed-plugin trials, full validation, deployment, cleanup, and clean-main proof.

## Test Complete And Metrics

- Raw-request Auto records one startup native-input call and zero downstream calls.
- Issue-backed Auto records a provider-observed issue and PR instead of hardcoded mutation counters.
- Manual fixtures render every required material gate.
- Looping fixtures record zero intra-candidate questions and stop on every specified terminal condition.
- Every lifecycle transition and artifact rebind has positive and negative fixtures.
- Every owner skill routes autonomous decisions through one resolver interface.
- Stale, cross-repository, cross-candidate, and expanded-scope authority fails.

## Outcome Proof

**Intent:** Deliver the user's intended Auto and Looping experience while keeping proof, scope, and stop conditions explicit.

**Current Behavior:** Production startup provenance is contradictory, raw requests cannot satisfy source-spec authorization, owner skills ask repeated questions, issue routing is hardcoded, bounded merge is asked again, and Looping candidate semantics are incomplete.

**Expected Outcome:** One startup selection drives spec, plan, route decision, execution, verification, integration, and closeout; Looping repeats bounded candidate lifecycles; Manual remains interactive; unsafe or out-of-scope work blocks without an invented default.

**Target Output:** Root authorization schema, lifecycle controller, artifact-binding events, gate resolver, issue rubric, merge authorization consumption, Loop controller, behavioral instrumentation, and installed-plugin traces.

**Owner:** Superpowers Project workflow and governance maintainer.

**Interface:** The six Python interfaces under Architecture And Interfaces plus stable workflow skill and shell entrypoints.

**Cutover:** Land authority and state transitions first, migrate owner gates second, enable issue and merge decisions third, complete Looping fourth, then remove obsolete prompt paths after behavior trials pass.

**Replaced Path:** Second Auto authorization, required future source spec, one-owner-route completion, repeated downstream prompts, hardcoded inline issue route, and intra-candidate Loop questions.

**Evidence:** Question-call instrumentation, event replay, artifact hashes, route-decision receipts, real provider observations, mutation receipts, focused tests, fresh installed-plugin trials, and final repository state.

**Acceptance Proof:** A raw idea completes Auto with exactly one startup input; an issue-backed request creates and integrates tracked work without bounded-merge prompting; Looping completes multiple scoped candidates and stops by policy; all adversarial fixtures fail correctly.

**Stop Criteria:** Stop on invalid authority, missing safe gate option, changed artifact without rebind, out-of-envelope mutation, provider state mismatch, budget exhaustion, repeated blocker threshold, or failed final health.

**Avoid:** Do not treat Auto as unlimited permission, drain unrelated backlog, weaken evidence gates, ask routine fallback questions, modify vanilla, or silently migrate ambiguous old ledgers.

**Risk:** Loaded sessions and historical ledgers can carry obsolete semantics. Version events, reject unsupported ledgers clearly, instrument every native-input call, and require fresh-session cutover.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Issue dependency | Umbrella implementation order and cross-plan review | Execute after the execution kernel and rebase onto current `main`. | Lifecycle authorization and merge decisions reuse current kernel receipt interfaces. | No | Program owner |
| Auto unit | Approved spec | One requested outcome lifecycle. | Owner skills no longer create new permission boundaries. | No | Workflow owner |
| Authority anchor | Raw-request contradiction | Bind request fingerprint before spec creation. | Fresh ideas can start valid Auto. | No | Governance owner |
| Artifact binding | Immutable root authority | Append hash-chained binding events. | Spec and plan changes invalidate derived decisions without rewriting authority. | No | State owner |
| Gate behavior | Downstream prompt audit | Use one shared mode-aware resolver. | Manual asks; Auto and Looping decide and record. | No | Workflow owner |
| Issue route | User requirement | Apply evidence-based direct-versus-issue rubric. | Real issues are created when tracking or handoff adds value. | No | Planning owner |
| Merge | User rejection of second prompt | Consume Auto merge authority after fail-closed proof. | Bounded merge remains a policy limit without another routine question. | No | Merge owner |
| Looping | Existing incomplete state machine | Repeat finite candidate lifecycles with budgets and health. | No open-ended queue drain occurs. | No | Loop owner |

### Task 1: Root Authorization And Append-Only Artifact Binding

**Use Cases:**

- A raw request receives valid Auto or Looping authority before a spec exists.
- Validator evidence rejects forged, stale, cross-repository, and expanded-scope authority.
- Migration cutover retires source-spec-before-authorization and binds later artifacts through events.

**Files:**
- Create: `scripts/lib/lifecycle_authorization.py`
- Create: `tests/test_lifecycle_authorization.py`
- Modify: `scripts/lib/workflow_policy.py`
- Modify: `scripts/lib/workflow_runtime.py`
- Modify: `scripts/lib/workflow_state.py`

**Interfaces:**
- Consumes: `AuthorizationRequest`, raw request, repository identity, explicit mode provenance
- Produces: `create_root_authorization(...) -> RootAuthorization` and `bind_artifact(...) -> LifecycleEvent`

- [ ] **Step 1: Write failing authority and binding tests**

```python
def test_raw_request_authority_does_not_require_spec(self):
    authorization = create_root_authorization(raw_auto_request())
    self.assertEqual("no-routine-prompts", authorization.interaction_policy)
    self.assertNotIn("source_spec", authorization.to_dict())

def test_bound_spec_is_append_only(self):
    event = bind_artifact(started_state(), spec_binding("docs/superpowers/specs/x.md", "a" * 64))
    self.assertEqual("spec_bound", event.type)
```

- [ ] **Step 2: Run RED**

Run: `python3 -m unittest tests.test_lifecycle_authorization -v`

Expected: FAIL because the authorization module and binding events do not exist.

- [ ] **Step 3: Implement minimal schema, canonical hash, and events**

Use frozen dataclasses, canonical JSON, repository-bound paths, explicit mutation envelope fields, and versioned event payloads. Split authorization provenance from interaction policy.

- [ ] **Step 4: Verify GREEN and refactor shared canonical hashing**

Run: `python3 -m unittest tests.test_lifecycle_authorization tests.test_workflow_state tests.test_workflow_policy -v`

Expected: all pass and old production provenance contradiction is replaced by explicit startup provenance checks.

- [ ] **Step 5: Checkpoint commit**

```bash
git add scripts/lib/lifecycle_authorization.py scripts/lib/workflow_policy.py scripts/lib/workflow_runtime.py scripts/lib/workflow_state.py tests/test_lifecycle_authorization.py tests/test_workflow_policy.py tests/test_workflow_state.py
git commit -m "feat: bind raw request lifecycle authority"
```

### Task 2: Typed Candidate Lifecycle Controller

**Use Cases:**

- Owner skills advance one candidate through explicit states instead of declaring one skill route complete.
- Transition proof rejects skipped, repeated, wrong-owner, wrong-candidate, and stale-artifact changes.
- Cutover redirects completion claims from opaque route state to verified lifecycle state.

**Files:**
- Create: `scripts/lib/lifecycle_controller.py`
- Create: `tests/test_lifecycle_controller.py`
- Create: `scripts/lib/commands/lifecycle.py`
- Modify: `scripts/lib/workflow_completion.py`
- Modify: `scripts/lib/command_catalog.py`
- Modify: `scripts/lib/superpowers_project_cli.py`

**Interfaces:**
- Consumes: current event projection and `TransitionRequest`
- Produces: `transition_lifecycle(...) -> LifecycleEvent` and structured blocker

- [ ] **Step 1: Write failing full transition matrix tests**

Test requested through completed plus direct, issue, blocked, stopped, wrong-owner, stale-binding, and invalid-skip cases.

- [ ] **Step 2: Run RED**

Run: `python3 -m unittest tests.test_lifecycle_controller -v`

Expected: FAIL because typed lifecycle state does not exist.

- [ ] **Step 3: Implement transition table and command adapters**

```python
ALLOWED_TRANSITIONS = {
    "requested": {"authorized", "blocked", "stopped"},
    "authorized": {"specifying", "blocked", "stopped"},
    "specifying": {"spec_reviewed", "blocked", "stopped"},
    "spec_reviewed": {"planning", "specifying", "blocked", "stopped"},
    "planning": {"plan_reviewed", "blocked", "stopped"},
    "plan_reviewed": {"route_decided", "planning", "blocked", "stopped"},
    "route_decided": {"executing_direct", "executing_issue", "blocked", "stopped"},
    "executing_direct": {"verifying", "blocked", "stopped"},
    "executing_issue": {"verifying", "blocked", "stopped"},
    "verifying": {"integrating", "executing_direct", "executing_issue", "blocked", "stopped"},
    "integrating": {"closing_out", "verifying", "blocked", "stopped"},
    "closing_out": {"completed", "integrating", "blocked", "stopped"},
    "completed": set(),
    "blocked": set(),
    "stopped": set(),
}
```

- [ ] **Step 4: Verify GREEN and event replay**

Run: `python3 -m unittest tests.test_lifecycle_controller tests.test_workflow_runtime_integration tests.test_workflow_completion -v`

Expected: all pass; completion requires verified closeout state.

- [ ] **Step 5: Checkpoint commit**

```bash
git add scripts/lib/lifecycle_controller.py scripts/lib/commands/lifecycle.py scripts/lib/workflow_completion.py scripts/lib/command_catalog.py scripts/lib/superpowers_project_cli.py tests/test_lifecycle_controller.py tests/test_workflow_runtime_integration.py tests/test_workflow_completion.py
git commit -m "feat: add candidate lifecycle controller"
```

### Task 3: Mode-Aware Gate Resolver And Owner-Skill Migration

**Use Cases:**

- Manual renders the graph-owned question while Auto and Looping record evidence-based decisions.
- Instrumentation proves zero downstream questions after Auto startup and zero intra-candidate Loop questions.
- Migration retires copied per-skill autonomous prompt paths without losing decisions.

**Files:**
- Create: `scripts/lib/gate_resolver.py`
- Create: `tests/test_gate_resolver.py`
- Modify: `docs/superpowers/workflow-contract.yml`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`

**Interfaces:**
- Consumes: graph gate, options, recommendation, evidence, lifecycle context
- Produces: `resolve_gate(...) -> GateDecision`

- [ ] **Step 1: Write failing Manual/Auto/Loop resolver tests**

Assert Manual returns a question request, Auto selects authorized options, Loop matches Auto inside candidate, forbidden gates block, and decision events contain rejected options and rationale.

- [ ] **Step 2: Run RED**

Run: `python3 -m unittest tests.test_gate_resolver -v`

Expected: FAIL because shared resolution does not exist.

- [ ] **Step 3: Implement resolver and migrate owner contracts**

Keep gate IDs/options graph-owned. Make every owner call the resolver and remove local statements that force a question regardless of mode.

- [ ] **Step 4: Verify GREEN with scenario instrumentation**

Run: `python3 -m unittest tests.test_gate_resolver tests.test_auto_loop_trials -v && for s in skills/{brainstorm-spec,write-plan,create-issues,implement-plan,resolve-issue,merge-changes}/scripts/test-scenarios.sh; do "$s"; done`

Expected: all pass; call metrics match each mode.

- [ ] **Step 5: Checkpoint commit**

```bash
git add scripts/lib/gate_resolver.py docs/superpowers/workflow-contract.yml skills/brainstorm-spec skills/write-plan skills/create-issues skills/implement-plan skills/resolve-issue skills/merge-changes tests/test_gate_resolver.py tests/test_auto_loop_trials.py
git commit -m "feat: resolve workflow gates by mode"
```

### Task 4: Issue Route Rubric And Auto Merge Consumption

**Use Cases:**

- A cohesive current-session plan selects direct implementation with recorded evidence.
- Tracking, handoff, or policy needs select a real issue and provider proof verifies publication.
- Acceptance proof retires hardcoded direct-inline routing and the second bounded-merge question.

**Files:**
- Create: `scripts/lib/issue_route.py`
- Create: `tests/test_issue_route.py`
- Modify: `scripts/lib/gate_resolver.py`
- Modify: `scripts/lib/lifecycle_controller.py`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `docs/superpowers/workflow-contract.yml`

**Interfaces:**
- Consumes: `IssueRouteEvidence`, repository policy, lifecycle authority, current premerge receipt
- Produces: `decide_issue_route(...) -> IssueRouteDecision` and Auto merge `GateDecision`

- [ ] **Step 1: Write failing rubric and merge tests**

Cover every required-issue condition, direct conjunction, conflicting evidence, observed provider mutation, valid premerge consumption, changed PR head, and unauthorized merge.

- [ ] **Step 2: Run RED**

Run: `python3 -m unittest tests.test_issue_route tests.test_local_merge_contract -v`

Expected: FAIL because issue route is hardcoded and merge does not consume lifecycle authority consistently.

- [ ] **Step 3: Implement rubric and merge resolver**

Return every rubric result and rationale. Auto selects merge strategy only from repository policy after current fail-closed proof; otherwise return a blocker without prompting.

- [ ] **Step 4: Verify GREEN**

Run: `python3 -m unittest tests.test_issue_route tests.test_local_merge_contract tests.test_workflow_runtime_integration -v`

Expected: all pass; no unconditional route remains.

- [ ] **Step 5: Checkpoint commit**

```bash
git add scripts/lib/issue_route.py scripts/lib/gate_resolver.py scripts/lib/lifecycle_controller.py skills/create-issues/SKILL.md skills/merge-changes/SKILL.md docs/superpowers/workflow-contract.yml tests/test_issue_route.py tests/test_local_merge_contract.py
git commit -m "feat: decide autonomous issue and merge routes"
```

### Task 5: Finite Looping Candidate Controller

**Use Cases:**

- The initial raw request can be candidate one and later candidates remain inside authorized scope.
- Verifier proof covers budget, no-ready, final-health, repeated-blocker, expiry, and interruption stops.
- Migration retires multiple-candidate rejection and removes intra-candidate continuation questions.

**Files:**
- Create: `scripts/lib/loop_lifecycle.py`
- Create: `tests/test_loop_lifecycle.py`
- Modify: `skills/loop-controller/SKILL.md`
- Modify: `skills/loop-controller/scripts/lib/loop-controller.sh`
- Modify: `docs/superpowers/loop-mode-contract.yml`
- Modify: `docs/superpowers/governance-profiles.yml`
- Modify: `scripts/lib/workflow_policy.py`

**Interfaces:**
- Consumes: `LoopState`, `LoopPolicy`, authorized candidate source, candidate outcome, budget, health, interruption
- Produces: `evaluate_loop(...) -> LoopDecision`

- [ ] **Step 1: Write failing finite-loop tests**

Test raw candidate one, successful continuation, optional between-candidate checkpoint, no-ready, every budget, final health, repeated blocker, expiry, and user interruption.

- [ ] **Step 2: Run RED**

Run: `python3 -m unittest tests.test_loop_lifecycle tests.test_workflow_policy -v`

Expected: FAIL because current policy rejects multiple Loop candidates and lacks lifecycle stops.

- [ ] **Step 3: Implement loop decisions and update contract**

Permit one active candidate at a time, not one candidate for the entire loop. Bind every candidate to startup authority. Keep an optional startup-configured between-candidate checkpoint.

- [ ] **Step 4: Verify GREEN and state-machine scenarios**

Run: `python3 -m unittest tests.test_loop_lifecycle tests.test_workflow_policy tests.test_workflow_runtime_integration -v && ./skills/loop-controller/scripts/test-scenarios.sh && ./scripts/test-loop-controller.sh`

Expected: all pass with explicit terminal reasons.

- [ ] **Step 5: Checkpoint commit**

```bash
git add scripts/lib/loop_lifecycle.py scripts/lib/workflow_policy.py skills/loop-controller docs/superpowers/loop-mode-contract.yml docs/superpowers/governance-profiles.yml tests/test_loop_lifecycle.py tests/test_workflow_policy.py tests/test_workflow_runtime_integration.py
git commit -m "feat: run finite looping candidate lifecycles"
```

### Task 6: End-To-End Mode Trials And Cutover

**Use Cases:**

- Operator-visible evidence proves raw Auto, issue-backed Auto, Manual, and multi-candidate Looping behavior.
- Installed-plugin metrics come from observed questions, tool calls, provider mutations, and final state.
- Cutover removes obsolete prompt paths only after acceptance proof passes.

**Files:**
- Create: `tests/test_auto_lifecycle_e2e.py`
- Create: `tests/test_loop_lifecycle_e2e.py`
- Modify: `scripts/run-agent-usability-trials.py`
- Modify: `scripts/run-agent-usability-trials.sh`
- Modify: `scripts/validate.sh`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: route metadata under affected skills

**Interfaces:**
- Consumes: installed plugin, natural-language trial request, instrumented native input/provider adapters
- Produces: complete lifecycle trace and observed metrics receipt

- [ ] **Step 1: Write failing end-to-end tests**

Require one startup call for raw Auto, zero later calls, observed issue/PR for issue-backed Auto, Manual question calls, multiple Loop candidates, and exact terminal reasons.

- [ ] **Step 2: Run RED**

Run: `python3 -m unittest tests.test_auto_lifecycle_e2e tests.test_loop_lifecycle_e2e -v`

Expected: FAIL against current one-route and hardcoded-metric behavior.

- [ ] **Step 3: Wire trials and remove obsolete paths**

Collect real adapter observations, append them to receipts, remove hardcoded counters, and update initiation/metadata to describe the lifecycle contract.

- [ ] **Step 4: Verify focused and full GREEN**

Run: `python3 -m unittest tests.test_auto_lifecycle_e2e tests.test_loop_lifecycle_e2e -v && ./scripts/run-agent-usability-trials.sh && ./scripts/validate.sh`

Expected: all pass with observed metrics and no stale generated state.

- [ ] **Step 5: Commit the complete source revision**

```bash
git add scripts/lib/lifecycle_authorization.py scripts/lib/lifecycle_controller.py scripts/lib/gate_resolver.py scripts/lib/issue_route.py scripts/lib/loop_lifecycle.py scripts/lib/commands/lifecycle.py scripts/lib/workflow_policy.py scripts/lib/workflow_runtime.py scripts/lib/workflow_state.py scripts/lib/workflow_completion.py scripts/lib/command_catalog.py scripts/lib/superpowers_project_cli.py docs/superpowers/workflow-contract.yml docs/superpowers/governance-profiles.yml docs/superpowers/loop-mode-contract.yml skills scripts/run-agent-usability-trials.py scripts/run-agent-usability-trials.sh scripts/validate.sh tests
git commit -m "feat: implement autonomous lifecycle semantics"
```

- [ ] **Step 6: Run deployment and final proof from committed source**

Run: `./scripts/sync-live.sh --validate && codex plugin add superpowers-project@personal --json && ./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent && bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root . && git status --short --branch`

Expected: source/live/observed surfaces are current and repository state is clean after committed changes.

## Plan Self-Review

- All source-spec goals map to numbered tasks.
- Every behavior task starts with a failing test and names the expected failure.
- Root authority, lifecycle state, gate decisions, and proof remain separate.
- Manual Mode stays interactive.
- Issue and merge mutations remain bounded and evidence-gated.
- Looping remains finite and candidate-scoped.
- No task modifies vanilla Superpowers, workspace-provider internals, or unrelated repositories.
- No placeholder requirements remain.
