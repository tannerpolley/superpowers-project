# Lean Auto And Loop Lifecycle Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` and `superpowers:test-driven-development`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one startup selection govern a complete Auto outcome and make Looping repeat bounded candidates without routine downstream questions.

**Architecture:** Extend the existing governance policy and `WorkflowRuntime` ledger. Share mode behavior through `advanced-user-input`; do not create a parallel lifecycle framework.

**Tech Stack:** Python 3, YAML, JSONL, Markdown skills, Bash launchers, and `unittest`.

## Global Constraints

- Add no new runtime modules.
- Reuse #113 authorization hashes, event replay, and integration receipts.
- Treat this as cooperative local-agent policy, not host attestation.
- Keep production additions below 500 lines unless a failing acceptance test proves more is necessary.
- Do not commit generated usability-trial runs or unrelated documentation regeneration.
- Use TDD for each behavior change.

## Implementation Boundaries

**Files To Create:** One focused test file may be created for mode-aware gate behavior; no production file is created.

**Files To Modify:** `scripts/lib/workflow_policy.py`, `scripts/lib/workflow_runtime.py`, `scripts/lib/workflow_state.py`, `scripts/lib/commands/workflow.py`, `scripts/lib/superpowers_project_cli.py`, focused tests, `docs/superpowers/governance-profiles.yml`, `docs/superpowers/loop-mode-contract.yml`, `docs/superpowers/workflow-contract.yml`, `skills/advanced-user-input/SKILL.md`, `skills/initiate-workflow/SKILL.md`, `skills/loop-controller/SKILL.md`, `skills/merge-changes/SKILL.md`, and small public summaries generated from the workflow contract.

**Files To Avoid:** New lifecycle/authorization/gate/issue/Loop modules, #113 gate internals, workspace-provider code, distribution code, deployed copies, plugin caches, historical plans/specs, SVGs, and trial receipt corpora.

**Source Of Truth:** The startup mode ledger owns mode and scope; `workflow_policy.py` owns ask/decide/block behavior; the existing event ledger owns recorded decisions; #113 receipts own integration proof.

**Read Path:** Raw request, startup mode ledger, current repository, candidate scope, gate options and recommendation, Loop budget/health, and existing proof receipts.

**Write Path:** The existing `.superpowers/runs/<run-id>/events.jsonl` ledger and normal owner-skill artifacts.

**Integration Points:** Workflow startup, shared user-input policy, owner-skill continuation gates, Loop selection, and merge authorization consumption.

**Migration Or Cutover:** Accept new Auto ledgers from `project_workflow_mode`; reject old second-question ledgers with a clear restart requirement.

**Replaced Path Handling:** Retire `project_auto_mode_authorization`, one-route wording, hardcoded direct-inline issue routing, and mandatory `project_loop_next_step` continuation.

**Acceptance Proof Gate:** Focused policy/runtime tests, skill contract scenarios, workflow-contract validation, full `./scripts/validate.sh`, and a clean diff with no generated trial corpus.

### Task 1: Startup Authority Means One Outcome

**Use Cases:**

- Acceptance evidence proves a raw request can authorize Auto before a spec exists.
- Cutover rejects the old second-question and hardcoded direct-route contract.

**Files:**

- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `docs/superpowers/governance-profiles.yml`
- Modify: `docs/superpowers/workflow-contract.yml`
- Test: focused Auto and workflow-mode contract tests

- [ ] **Step 1: Write failing tests** for `project_workflow_mode`, `one-outcome-lifecycle`, raw-request fingerprint, evidence-based issue routing, and rejection of old authorization.
- [ ] **Step 2: Run the focused tests** and confirm they fail for the old one-route/source-spec contract.
- [ ] **Step 3: Make the smallest validator and contract changes** needed to pass.
- [ ] **Step 4: Run the focused tests** and confirm they pass.

### Task 2: One Shared Gate Decision

**Use Cases:**

- Operator-visible proof shows Manual asks, Auto and Looping decide, and unsafe gates block.
- Migration evidence shows owner skills share one policy instead of duplicating per-skill Auto rules.

**Files:**

- Modify: `scripts/lib/workflow_policy.py`
- Modify: `scripts/lib/workflow_runtime.py`
- Modify: `scripts/lib/workflow_state.py`
- Modify: `scripts/lib/commands/workflow.py`
- Modify: `skills/advanced-user-input/SKILL.md`
- Test: `tests/test_workflow_policy.py`, `tests/test_workflow_runtime_integration.py`

- [ ] **Step 1: Write failing policy tests** for ask, decide, caller-selected rejection, and block.
- [ ] **Step 2: Run them RED.**
- [ ] **Step 3: Implement a small `GateDecision` and `resolve_gate`** in `workflow_policy.py`.
- [ ] **Step 4: Write failing runtime tests** proving resolved decisions are recorded in the existing event ledger.
- [ ] **Step 5: Extend the existing runtime and command adapter minimally.**
- [ ] **Step 6: Run policy and runtime tests GREEN.**

### Task 3: Bounded Loop And Skill Cutover

**Use Cases:**

- Acceptance proof shows Looping advances to a second candidate after recorded budget, health, and continuation evidence without a native question.
- Old mandatory continuation-question wording is retired from active contracts and skill instructions.

**Files:**

- Modify: `docs/superpowers/loop-mode-contract.yml`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/loop-controller/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: small README/plugin summaries that describe startup semantics
- Test: Loop runtime and skill scenario tests

- [ ] **Step 1: Write or update failing contract tests** for automatic budget/health continuation and one startup Auto question.
- [ ] **Step 2: Run them RED.**
- [ ] **Step 3: Update only the shared and contradictory active skill text.**
- [ ] **Step 4: Regenerate text workflow indexes from the contract.**
- [ ] **Step 5: Run focused tests, `./scripts/validate.sh`, and the cleanup audit.**

## Outcome Proof

**Intent:** Make Auto and Looping low-friction outcome modes without building a second workflow engine.

**Current Behavior:** Auto is one-route, requires a second authorization tied to an existing spec, hardcodes direct issue routing, and downstream routes can ask again; Looping requires a user continuation question.

**Expected Outcome:** One startup selection carries a raw request through a complete scoped outcome; Manual asks; Auto and Looping resolve safe routine gates; Looping remains finite through budget and health.

**Target Output:** A small policy helper, minimal extensions to the existing run ledger, corrected validators/contracts, and focused tests.

**Owner:** Superpowers Project workflow maintainer.

**Interface:** `resolve_gate(profile, gate_id, options, recommendation, authorized)` plus existing `WorkflowRuntime` and `scripts/workflow-run.sh` entrypoints.

**Cutover:** New runs use `project_workflow_mode`; old `project_auto_mode_authorization` ledgers restart explicitly.

**Replaced Path:** The second Auto question, one-route completion, hardcoded direct-inline issue routing, duplicated downstream Auto prompts, and mandatory between-candidate Loop questions.

**Evidence:** Focused unit/integration tests, scenario scripts, generated contract checks, full repository validation, and diff-size review.

**Acceptance Proof:** A raw-request Auto fixture completes an outcome with one startup selection; Manual returns an input request; Auto/Loop gate fixtures record decisions; a two-candidate Loop fixture advances without a question and stops at policy.

**Stop Criteria:** Stop on scope expansion, missing safe option, invalid/tampered ledger, failed proof, failed health, budget exhaustion, or user interruption.

**Avoid:** New subsystems, speculative threat-model features, generated trial corpora, broad documentation rewrites, SVG changes, and unrelated refactoring.

**Risk:** Skill instructions are cooperative policy; tests can prove source behavior but cannot cryptographically attest host UI calls.

