# Command Runtime Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every shipped launcher perform its named behavior and integrate governance plus event replay into production workflow commands.

**Architecture:** Keep Bash launchers as the stable public Adapter, replace the shallow string registry with a typed command catalog Interface, and move command behavior into focused Python Modules. Add one Workflow Runtime Module over governance, append-only events, deterministic projection, and scoped completion.

**Tech Stack:** Bash, Python 3.12, `unittest`, JSON/JSONL, YAML, Git.

## Global Constraints

- Preserve every supported launcher path and PowerShell-style flag unless the launcher is proven obsolete and deleted with all references.
- Do not retain generic failing handlers, compatibility wrappers, fake success defaults, or silent fallbacks.
- Project writes stay under the explicit consumer repository root; plugin reads stay under the immutable plugin root.
- New or changed behavior follows red-green-refactor with focused tests before Implementation edits.
- Do not push, open a pull request, or create GitHub issues from this local implementation route.

---

## Source Evidence

- Source spec: `docs/superpowers/specs/2026-07-09-command-runtime-completion-design.md`
- Auto authorization: `.superpowers/runs/2026-07-09-complete-remediation/auto-mode-authorization.json`
- Reproduction: `./scripts/validate-workflow-contract.sh` exits nonzero while `./scripts/validate.sh` exits zero.
- Registry evidence: 49 entries target the generic failing handler; 23 substantive command functions are defined but not registered.

## Test Complete And Metrics

- All public Bash Adapters return a successful dispatch probe naming the exact registered handler.
- Zero command catalog entries target a generic failing handler.
- Every distinct handler has at least one behavioral fixture and every mutating handler has a rejected unsafe fixture.
- Direct `./scripts/validate-workflow-contract.sh` exits zero.
- Workflow event replay is deterministic across five repeats; tampering and illegal second-candidate selection fail 100% of the time.
- `python3 -m unittest discover -s tests -v` and `./scripts/validate.sh` exit zero.
- Tolerances and numerical error bounds are not applicable because the outputs are exact JSON receipts, paths, exit codes, hashes, and state transitions.

## Outcome Proof

**Intent:** Complete the installed Linux command runtime and make workflow governance executable in production paths.

**Current Behavior:** The top-level suite passes, but many public launchers route to a generic failure, while workflow policy and event state are used mainly by tests.

**Expected Outcome:** Every shipped launcher resolves to substantive behavior, every handler is covered, and real Auto or Looping commands write replayable workflow evidence.

**Target Output:** A typed command catalog, focused command Modules, a production Workflow Runtime Interface, complete launcher tests, and zero generic failing mappings.

**Owner:** Runtime owner.

**Interface:** Existing Bash launcher paths, structured JSON receipts, and the new workflow-run command Interface.

**Cutover:** Replace the literal string registry and monolithic handler ownership in one branch after all launcher probes and behavior fixtures pass.

**Replaced Path:** Generic failing handler mappings and direct test-only use of workflow state.

**Evidence:** Focused unit tests, launcher probe matrix, direct validator invocation, workflow replay receipts, and the full validation summary.

**Acceptance Proof:** Zero generic failing mappings; every launcher probe passes; every distinct handler has behavior evidence; full validation exits zero.

**Stop Criteria:** Stop before commit or merge when a launcher lacks named behavior, a registry mapping is ambiguous, a state transition is not covered, or any validation fails.

**Avoid:** Compatibility aliases, guessed handlers, success fallbacks, direct projection edits, and project writes through plugin-root paths.

**Risk:** Central dispatch changes can break many launchers; the runtime owner mitigates this with probe-all and handler-behavior gates before cutover.

## Implementation Boundaries

**Files To Create:** `scripts/lib/command_catalog.py`, `scripts/lib/command_support.py`, `scripts/lib/workflow_runtime.py`, `scripts/lib/commands/__init__.py`, focused command Modules under `scripts/lib/commands/`, `scripts/workflow-run.sh`, `tests/test_command_surface.py`, and `tests/test_workflow_runtime_integration.py`.

**Files To Modify:** `scripts/lib/superpowers_project_cli.py`, `scripts/lib/superpowers_project_command_registry.py`, `scripts/lib/workflow_policy.py`, `scripts/lib/workflow_state.py`, `scripts/validate.sh`, affected Bash launchers, and route skills that invoke production workflow state.

**Files To Avoid:** Plugin deployment copies, runtime-generated cache paths, unrelated historical specs, and GitHub issue mirrors.

**Source Of Truth:** The typed command catalog for launcher ownership and the workflow event ledger for run state.

**Read Path:** Bash Adapter to dispatcher to command catalog to focused command Module; workflow commands then replay authorization and events.

**Write Path:** Named handlers emit JSON receipts; workflow mutations append `events.jsonl` and regenerate `run.json` by replay.

**Integration Points:** `run-script.sh`, project-root resolution, package provenance, route skill script references, validation summary, and release proof.

**Migration Or Cutover:** Add failing catalog/surface tests, complete behavior, extract Modules, then delete the generic handler and old registry.

**Replaced Path Handling:** Remove obsolete launchers and references; map supported launchers to one substantive handler; do not redirect retired behavior.

**Acceptance Proof Gate:** Run focused command and workflow tests, direct public validators, then the full source validation suite.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Runtime design | Source spec | Typed catalog plus focused Modules | Keeps the public Interface stable while improving Locality | No | Runtime owner |
| Test strategy | Audit reproduction | Probe every launcher and behavior-test every distinct handler | Detects dispatch success without named behavior | No | Validation owner |
| Workflow state | Source spec | Production routes append and replay events | Makes autonomy proof executable | No | Workflow owner |
| TDD policy | Auto recorded defaults | Required for every behavior change | Produces red-green evidence for the central cutover | No | Runtime owner |
| Branch strategy | User instruction | One isolated implementation worktree | Keeps main stable until verification passes | No | Integration owner |
| Publication | User instruction and repo policy | Local merge only; no push or PR | Avoids unauthorized external writes | No | Integration owner |

### Task 1: Make incomplete command ownership fail first

**Use Cases:**
- A maintainer sees an exact failing test for every generic registry mapping.
- A new launcher without a catalog entry fails before release.
- A catalog entry naming a missing handler fails before user invocation.

**Files:**
- Create: `scripts/lib/command_catalog.py`
- Modify: `tests/test_command_registry.py`
- Test: `tests/test_command_registry.py`

**Interfaces:**
- Produces: `CommandSpec(path: str, handler: str, kind: str, mutation: str)` and `load_command_catalog(plugin_root: Path) -> dict[str, CommandSpec]`.
- Consumes: discovered Bash launcher paths and Python handler names.

- [ ] **Step 1: Write failing tests** asserting zero generic handler mappings, unique paths, known kinds, valid mutation classes, and callable handlers.
- [ ] **Step 2: Run RED** with `python3 -m unittest tests.test_command_registry -v`; expect failures listing the incomplete mappings.
- [ ] **Step 3: Add the typed catalog shape** while preserving current mappings so failures remain behavior-specific.
- [ ] **Step 4: Run the tests** and confirm only incomplete ownership failures remain.
- [ ] **Step 5: Commit** with `test: expose incomplete command ownership`.

### Task 2: Complete every launcher mapping and named behavior

**Use Cases:**
- Direct validators return their named phase instead of a generic failure.
- Issue, loop, merge, setup, and worker helpers execute their existing substantive Implementations.
- Obsolete paths disappear from source, docs, metadata, and the catalog together.
- Cutover acceptance proof shows every supported launcher has named behavior and every displaced path has been removed.

**Files:**
- Modify: `scripts/lib/superpowers_project_command_registry.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: affected `scripts/*.sh` and `skills/*/scripts/*.sh`
- Test: `tests/test_command_registry.py`
- Create: `tests/test_command_surface.py`

**Interfaces:**
- Consumes: `CommandSpec` entries from Task 1.
- Produces: substantive handler ownership for every public Adapter.

- [ ] **Step 1: Add a failing direct-launcher fixture** for `scripts/validate-workflow-contract.sh` and one launcher from each incomplete skill family.
- [ ] **Step 2: Run RED** and verify each launcher fails because of generic routing.
- [ ] **Step 3: Map existing handlers** for flat roots, metadata, workflow examples, issue mirrors, loop state, worker handoff, premerge, closeout, and execution preparation.
- [ ] **Step 4: Implement missing named handlers** by porting the exact accepted/rejected behavior already exercised by the corresponding tests.
- [ ] **Step 5: Delete the generic failing handler** and any obsolete launcher whose named behavior has no supported owner.
- [ ] **Step 6: Run GREEN** with registry and direct-launcher tests; expect zero incomplete mappings and correct named phases.
- [ ] **Step 7: Commit** with `fix: complete public command behavior`.

### Task 3: Execute the full public launcher Interface in tests

**Use Cases:**
- Every Bash Adapter proves it reaches the catalog and exact handler.
- Mutating commands can be probed without changing repositories or external systems.
- A handler mapped to an unrelated phase fails the surface test.

**Files:**
- Modify: `scripts/lib/run-script.sh`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `scripts/lib/command_catalog.py`
- Test: `tests/test_command_surface.py`
- Modify: `scripts/validate.sh`

**Interfaces:**
- Produces: `-DispatchProbe` returning `path`, `handler`, `kind`, `mutation`, and `ok` without invoking behavior.
- Consumes: every shipped public Bash Adapter.

- [ ] **Step 1: Write a failing probe-all test** that invokes every launcher and rejects missing or mismatched probe receipts.
- [ ] **Step 2: Run RED** and confirm launchers do not yet recognize `-DispatchProbe`.
- [ ] **Step 3: Implement dispatch probing** before behavior invocation while retaining normal failure semantics for ordinary calls.
- [ ] **Step 4: Add a handler-evidence matrix** requiring at least one accepted fixture per distinct handler and a rejected fixture for mutating handlers.
- [ ] **Step 5: Run GREEN** with `python3 -m unittest tests.test_command_surface -v`.
- [ ] **Step 6: Wire the surface test into `scripts/validate.sh`** and commit with `test: execute the public command surface`.

### Task 4: Add the production Workflow Runtime Module

**Use Cases:**
- Auto Mode records one selected target and cannot continue to another.
- Looping Mode records one candidate per iteration and blocks without acceptance, verification, budget, and continuation evidence.
- Tampered event history prevents further mutation or completion.

**Files:**
- Create: `scripts/lib/workflow_runtime.py`
- Create: `scripts/workflow-run.sh`
- Modify: `scripts/lib/workflow_policy.py`
- Modify: `scripts/lib/workflow_state.py`
- Modify: `scripts/lib/command_catalog.py`
- Test: `tests/test_workflow_runtime_integration.py`

**Interfaces:**
- Produces: `WorkflowRuntime.start`, `select`, `mutate`, `accept`, `verify`, `recheck_budget`, `grant_continuation`, `block`, and `complete`.
- Consumes: governance profile, immutable authorization, package provenance, project root, and run root.

- [ ] **Step 1: Write failing integration tests** through `scripts/workflow-run.sh` for Auto, Looping, tampering, and illegal completion.
- [ ] **Step 2: Run RED** and verify the production Interface is absent.
- [ ] **Step 3: Implement the minimal runtime** by composing governance validation with append-only event replay.
- [ ] **Step 4: Add provenance and project-root equality checks** before the first mutating event.
- [ ] **Step 5: Run GREEN** across integration and existing state/policy tests.
- [ ] **Step 6: Commit** with `feat: connect production workflow state`.

### Task 5: Split the monolithic command Implementation

**Use Cases:**
- A maintainer can change validation without reading installation or merge logic.
- Tests import focused Modules without initializing the whole CLI.
- The dispatcher remains the only public Python entrypoint.

**Files:**
- Create: `scripts/lib/command_support.py`
- Create: `scripts/lib/commands/__init__.py`
- Create: `scripts/lib/commands/validation.py`
- Create: `scripts/lib/commands/workflow.py`
- Create: `scripts/lib/commands/project.py`
- Create: `scripts/lib/commands/distribution.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Test: `tests/test_command_registry.py`
- Test: `tests/test_command_surface.py`

**Interfaces:**
- Consumes: shared `Context`, argument parsing, path resolution, process execution, and JSON receipt helpers.
- Produces: focused handler maps loaded by the command catalog.

- [ ] **Step 1: Add failing import-locality tests** requiring handlers to live in the owning focused Module.
- [ ] **Step 2: Run RED** and capture the monolithic ownership failures.
- [ ] **Step 3: Move shared mechanics to `command_support.py`** without behavior changes.
- [ ] **Step 4: Move handlers by ownership** and expose one `HANDLERS` mapping per Module.
- [ ] **Step 5: Reduce the CLI** to parsing, Context construction, catalog resolution, dispatch, and top-level failure receipts.
- [ ] **Step 6: Run registry, surface, workflow, and full validation tests** after each Module move.
- [ ] **Step 7: Commit** with `refactor: deepen command modules`.

### Task 6: Integrate production state with route skills

**Use Cases:**
- Auto planning, implementation, and merge reuse one immutable run authorization.
- Loop Controller uses event evidence before selecting another candidate.
- Future agents can locate the workflow-run Interface without deployment-path instructions.

**Files:**
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/loop-controller/SKILL.md`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: affected `skills/*/scripts/test-scenarios.sh`
- Test: `scripts/test-workflow-runtime.sh`

**Interfaces:**
- Consumes: `scripts/workflow-run.sh` and the Auto authorization ledger.
- Produces: route instructions that record real workflow events at mutation and completion gates.

- [ ] **Step 1: Add failing skill scenario assertions** for production run start, mutation, proof, and completion commands.
- [ ] **Step 2: Run RED** with affected scenario scripts.
- [ ] **Step 3: Add the minimal route instructions** using canonical skill and script names.
- [ ] **Step 4: Run GREEN** for every affected skill scenario and workflow runtime test.
- [ ] **Step 5: Run `./scripts/validate.sh`** and commit with `docs: require production workflow receipts`.
