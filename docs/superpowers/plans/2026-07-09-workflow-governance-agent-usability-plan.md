# Workflow Governance And Agent Usability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish one typed workflow graph, capability-aware concise skills, scoped completion, and real Codex-agent usability proof.

**Architecture:** Load route facts through one typed Workflow Graph Module and generate review surfaces from that graph. Compose governance profiles, event-derived completion claims, capability declarations, concise skill Adapters, and independently verified real-agent trial receipts.

**Tech Stack:** Python 3.12, YAML, Bash, Markdown, JSON Schema, Codex CLI, `unittest`.

## Global Constraints

- The graph owns route IDs, prompts, labels, parents, owners, artifacts, validators, and transitions.
- Global native-input and artifact-review policy has one owner in `advanced-user-input`.
- Route skills retain judgment, ownership, inputs, outputs, stop reasons, and required Superpowers pairings.
- Real-agent trials use disposable repositories and may not mutate external systems.
- Generated docs fail check mode when stale; validation does not silently rewrite them.

---

## Source Evidence

- Source spec: `docs/superpowers/specs/2026-07-09-workflow-governance-agent-usability-design.md`
- Auto authorization: `.superpowers/runs/2026-07-09-complete-remediation/auto-mode-authorization.json`
- Current graph validator: `scripts/validate-workflow-graph.py`
- Current synthetic trials: `tests/test_auto_loop_trials.py`

## Test Complete And Metrics

- Nine malformed graph fixture classes fail with exact findings; valid graph generation is byte-stable across five runs.
- All four governance profiles and four completion claims have accepted and rejected fixtures.
- Every skill declares required capabilities; duplicated global-policy findings are zero.
- Route `SKILL.md` total line count falls by at least 30% without removing required method pairings or route ownership.
- Real-agent golden scenarios pass five repetitions and adversarial scenarios block three repetitions; median friction is at most 2/5; user-input calls and external mutations are zero in autonomous trials.
- Full validation exits zero.

## Outcome Proof

**Intent:** Make workflow routing machine-verifiable and reduce the instruction burden on future Codex agents.

**Current Behavior:** Route facts are duplicated, graph checks are shallow, completion scope is ambiguous, skill text is large, and agent trials are synthetic.

**Expected Outcome:** One typed graph and governance contract drive concise skills, scoped completion, generated summaries, and real-agent proof.

**Target Output:** Workflow graph Module, governance profiles, completion Module, capability contract, slimmed skills, generators, trial runner, receipt schema, oracles, and validated receipts.

**Owner:** Workflow owner.

**Interface:** Canonical YAML contracts, concise route skills, workflow runtime completion claims, and agent trial receipt JSON.

**Cutover:** Validate the expanded graph, generate summaries, slim one skill family at a time, then require capability and trial receipts in validation and release proof.

**Replaced Path:** Duplicated route facts, prose-only completion semantics, and synthetic-only usability claims.

**Evidence:** Malformed graph fixtures, deterministic generation, profile tests, skill metrics, fresh-agent receipts, independent oracle results, and full validation.

**Acceptance Proof:** All graph/profile/capability gates pass; skill text shrinks by target; real-agent thresholds pass; full validation exits zero.

**Stop Criteria:** Stop when graph ownership is ambiguous, generation would delete judgment guidance, a capability cannot be detected, or a trial attempts external mutation.

**Avoid:** Unowned question IDs, duplicated global policy, generated judgment prose, hidden defaults, network-dependent CI, and self-verified agent narratives.

**Risk:** Graph and skill migrations can create instruction gaps; the workflow owner mitigates this with byte-stable generation, scenario tests, and real-agent oracles.

## Implementation Boundaries

**Files To Create:** `scripts/lib/workflow_graph.py`, `scripts/lib/workflow_completion.py`, `docs/superpowers/governance-profiles.yml`, `docs/superpowers/capabilities.yml`, graph fixtures, skill-slimming tests, and `tests/workflow-trials/` schemas, scenarios, repositories, oracles, and receipts.

**Files To Modify:** `docs/superpowers/workflow-contract.yml`, `docs/superpowers/OUTCOME_WORKFLOW.md`, `scripts/validate-workflow-graph.py`, `scripts/generate-outcome-workflow-summary.sh`, `scripts/validate.sh`, all route skills and metadata, workflow policy/runtime Modules, and release proof.

**Files To Avoid:** Deployed plugin copies, runtime-generated cache locations, unrelated project history, and external user repositories.

**Source Of Truth:** Typed workflow graph, governance profiles, capability contract, and replayed event ledger.

**Read Path:** Startup metadata to capability check to skill Adapter to graph-owned route to runtime completion claim.

**Write Path:** Graph generator writes review docs; runtime writes events; agent trials write scoped receipts under the trial result root.

**Integration Points:** Native question policy, route metadata, workflow runtime, package provenance, CI validation, and release evidence.

**Migration Or Cutover:** Strengthen graph first, add completion/capabilities, slim skills incrementally, then add real-agent release proof.

**Replaced Path Handling:** Delete duplicated policy blocks after their shared owner and scenario proof exist; retire synthetic usability claims while retaining fast unit tests for policy mechanics.

**Acceptance Proof Gate:** Focused graph, governance, capability, skill, and trial tests followed by full validation.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Graph ownership | Source spec | One typed graph owns route facts | Eliminates drift and enables generation | No | Workflow owner |
| Completion scope | Audit finding | Four explicit event-derived claims | Prevents overstated completion | No | Workflow owner |
| Capability policy | Source spec | Declarative required and optional capabilities | Produces exact preflight failures | No | Runtime owner |
| Skill shape | Writing-skills guidance | Concise route Adapters plus shared policy | Reduces prompt load and repeated instructions | No | Skill owner |
| Agent trials | User request to address all revisions | Fresh Codex workers plus independent verifiers | Tests real instruction following | No | Validation owner |
| CI policy | Trial safety | Deterministic receipt validation in CI; real runs at release gate | Avoids secret-dependent ordinary CI | No | Release owner |

### Task 1: Build the typed Workflow Graph Module

**Use Cases:**
- Conflicting duplicate question IDs fail with both owner paths.
- Wrong parents, missing owners, illegal terminal labels, and unreachable routes fail before generation.
- A valid graph exposes exact route facts to docs and tests.

**Files:**
- Create: `scripts/lib/workflow_graph.py`
- Modify: `scripts/validate-workflow-graph.py`
- Create: `tests/test_workflow_graph.py`
- Create: `tests/fixtures/workflow_graph/`
- Modify: `docs/superpowers/workflow-contract.yml`

**Interfaces:**
- Produces: `load_workflow_graph(path) -> WorkflowGraph`, `validate_workflow_graph(graph, root) -> list[Finding]`, and `render_outcome_workflow(graph) -> str`.
- Consumes: canonical workflow YAML and plugin root.

- [ ] **Step 1: Write nine malformed fixtures** for boolean labels, conflicting IDs, wrong parents, illegal terminals, missing owners, missing artifacts, missing validators, unreachable routes, and missing transitions.
- [ ] **Step 2: Run RED** and prove the current validator accepts at least the known unsupported cases.
- [ ] **Step 3: Implement typed loading and validation** with deterministic ordered findings.
- [ ] **Step 4: Normalize graph ownership and references** in the canonical YAML.
- [ ] **Step 5: Run GREEN** across graph tests and existing workflow contract tests.
- [ ] **Step 6: Commit** with `feat: make workflow graph authoritative`.

### Task 2: Generate workflow review surfaces

**Use Cases:**
- Maintainers update one graph fact and regenerate the outcome summary.
- Check mode detects stale generated text without rewriting files.
- Route skills can link to one generated route index.

**Files:**
- Modify: `scripts/generate-outcome-workflow-summary.sh`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`
- Create: `docs/superpowers/WORKFLOW_ROUTE_INDEX.md`
- Create: `tests/test_workflow_generation.py`
- Modify: `scripts/validate.sh`

**Interfaces:**
- Consumes: `render_outcome_workflow` and graph route records.
- Produces: deterministic outcome summary and route index plus `--check` behavior.

- [ ] **Step 1: Write failing byte-comparison tests** for generated summary and route index.
- [ ] **Step 2: Run RED** and verify current hand-authored output drifts.
- [ ] **Step 3: Implement generation and check mode** without mutating during validation.
- [ ] **Step 4: Regenerate both artifacts** and review the diff for lost judgment guidance.
- [ ] **Step 5: Run GREEN** across generation and full graph tests.
- [ ] **Step 6: Commit** with `docs: generate workflow route references`.

### Task 3: Add governance profiles and scoped completion

**Use Cases:**
- Candidate completion does not imply project completion.
- Auto Mode closes one authorized route and cannot carry continuation authority.
- Looping Mode closes only after its event and continuation requirements pass.

**Files:**
- Create: `docs/superpowers/governance-profiles.yml`
- Create: `scripts/lib/workflow_completion.py`
- Modify: `scripts/lib/workflow_policy.py`
- Modify: `scripts/lib/workflow_runtime.py`
- Create: `tests/test_workflow_completion.py`
- Modify: `tests/test_workflow_policy.py`

**Interfaces:**
- Produces: `load_profiles`, `allowed_completion_claims`, and `validate_completion_claim`.
- Consumes: governance mode, authorization, and replayed run projection.

- [ ] **Step 1: Write failing profile and completion tests** for every accepted and rejected claim.
- [ ] **Step 2: Run RED** and verify scoped claims do not exist.
- [ ] **Step 3: Add declarative profiles and completion evaluation** tied to replayed events.
- [ ] **Step 4: Integrate completion with production runtime closeout** and reject direct projection claims.
- [ ] **Step 5: Run GREEN** across completion, policy, state, and runtime tests.
- [ ] **Step 6: Commit** with `feat: add scoped workflow completion`.

### Task 4: Declare capabilities and slim route skills

**Use Cases:**
- A route fails before execution when a required capability is absent.
- Future agents read one global continuation policy instead of fourteen copies.
- Required Superpowers method pairings remain explicit and searchable.

**Files:**
- Create: `docs/superpowers/capabilities.yml`
- Create: `scripts/validate-skill-slimming.py`
- Create: `scripts/test-skill-slimming.sh`
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: all route `skills/*/SKILL.md`
- Modify: all `skills/*/agents/openai.yaml`
- Modify: affected scenario tests

**Interfaces:**
- Produces: `load_capabilities`, `validate_route_capabilities`, size metrics, and duplicate-policy findings.
- Consumes: skill metadata, canonical graph ownership, and available runtime capability names.

- [ ] **Step 1: Write failing skill tests** for missing declarations, duplicated policy, unresolved paths, and size limits.
- [ ] **Step 2: Run RED** and record current line/word metrics plus exact duplicates.
- [ ] **Step 3: Add capability declarations** to the canonical contract and route metadata.
- [ ] **Step 4: Slim one route family at a time** by replacing repeated global policy with required canonical references while retaining local judgment.
- [ ] **Step 5: Run each skill scenario after its edit** and restore any omitted method or stop rule.
- [ ] **Step 6: Run GREEN** with at least 30% total line reduction and zero duplicate-policy findings.
- [ ] **Step 7: Commit** with `refactor: deepen skill workflow contracts`.

### Task 5: Add real Codex-agent usability trials

**Use Cases:**
- A fresh Auto worker completes one authorized route without prompting or leaving the disposable repo.
- A fresh Looping worker blocks before a second mutation when continuation proof is absent.
- An independent verifier catches a worker narrative that disagrees with repository and event evidence.

**Files:**
- Create: `tests/workflow-trials/trial-report.schema.json`
- Create: `tests/workflow-trials/scenarios/auto/`
- Create: `tests/workflow-trials/scenarios/loop/`
- Create: `tests/workflow-trials/oracles/`
- Create: `scripts/run-agent-usability-trials.sh`
- Create: `scripts/validate-agent-usability-receipt.sh`
- Create: `tests/test_agent_usability_receipts.py`
- Modify: `scripts/validate.sh`
- Modify: `scripts/prepare-release.sh`

**Interfaces:**
- Produces: one JSON receipt per fresh worker plus an independent verifier receipt tied to package hash.
- Consumes: disposable repo, authorization, run root, task entrypoint, and installed plugin ID.

- [ ] **Step 1: Write failing receipt-schema and oracle tests** covering missing metrics, self-verification, scope drift, and stale package hash.
- [ ] **Step 2: Run RED** and confirm current synthetic trial output cannot satisfy the schema.
- [ ] **Step 3: Implement disposable-repo and Codex worker invocation** with explicit noninteractive trial provenance and no external mutation authority.
- [ ] **Step 4: Implement independent verification** from repository state, events, and untouched oracle only.
- [ ] **Step 5: Run golden and adversarial trials** using fresh agents; record five and three repetitions respectively when the trial runtime is authorized.
- [ ] **Step 6: Validate friction and safety thresholds** and tie receipts to the current runtime hash.
- [ ] **Step 7: Commit** with `test: add real agent usability proof`.

### Task 6: Integrate workflow governance proof

**Use Cases:**
- Ordinary CI validates graph, capabilities, skills, and checked receipt structure without secrets.
- Release proof requires a current real-agent receipt.
- Maintainers see exact metrics and failure owners.

**Files:**
- Modify: `scripts/validate.sh`
- Modify: `scripts/prepare-release.sh`
- Modify: `.github/workflows/validate.yml`
- Modify: `README.md`
- Modify: `docs/superpowers/RELEASE_POLICY.md`

**Interfaces:**
- Consumes: graph, profile, capability, skill, and trial receipts.
- Produces: validation summary entries and release readiness findings.

- [ ] **Step 1: Add failing integration assertions** for each missing governance proof.
- [ ] **Step 2: Run RED** against an intentionally stale trial receipt and generated summary.
- [ ] **Step 3: Wire deterministic checks into ordinary validation** and current-agent receipt checks into release preparation.
- [ ] **Step 4: Document exact local and CI commands** without runtime deployment paths.
- [ ] **Step 5: Run GREEN** with focused tests and `./scripts/validate.sh`.
- [ ] **Step 6: Commit** with `ci: require workflow governance proof`.

