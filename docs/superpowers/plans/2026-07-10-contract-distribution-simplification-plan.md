# Contract And Distribution Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one normalized workflow contract generate skill-facing route slices, declare the vanilla Superpowers dependency, isolate plugin helpers, modularize remaining command responsibilities, and classify revision gates from the shipped surface.

**Architecture:** Extend the existing `workflow_graph.py` generator rather than adding a second policy engine. Add pure dependency, revision-impact, and artifact-lifecycle modules behind the current CLI launchers, then make sync and repository validation consume their results. Preserve public skill names and command paths while removing global helper deployment from the ordinary plugin transaction.

**Tech Stack:** Python 3 standard library, YAML through the repository's pinned validator environment, Bash launchers, `unittest`, Markdown, JSON, and Codex plugin manifests.

## Global Constraints

- Vanilla Superpowers remains an external dependency and its files are never copied, edited, or patched by this repository.
- Existing public skill names and shell launcher paths remain stable.
- One normalized contract owns every gate, option, transition, and owner skill.
- Generated files identify their source and generator version and fail validation on drift.
- Ordinary plugin install, sync, refresh, and uninstall do not mutate unrelated global user skills.
- Revision gates are derived from runtime package membership and runtime reads, not directory names alone.
- Ambiguous revision impact selects the stricter gate set.
- Receipt-bound historical artifacts are retained; unreferenced Superseded artifacts cannot appear in active milestone indexes.
- Apply TDD for every behavior change and use fresh verification before completion.
- Execute only after the execution-kernel, lifecycle, and workspace-isolation issues merge; rebase onto current `main` before editing shared graph, CLI, skill, or validation files.

---

## Source Evidence

- Approved source: `docs/superpowers/specs/2026-07-10-contract-distribution-simplification-design.md`
- Umbrella diagnosis: `docs/superpowers/specs/2026-07-10-autonomous-workflow-and-codex-worktree-audit-findings.md`
- Current graph loader and generator: `scripts/lib/workflow_graph.py`
- Current runtime package authority: `.codex-plugin/runtime-package.yml` and `scripts/lib/package_provenance.py`
- Current global helper mutation: `scripts/lib/superpowers_project_cli.py` and `scripts/lib/project-skills.sh`
- Current command decomposition: `scripts/lib/commands/`
- Current revision state evaluator: `scripts/lib/revision_status.py`

## Architecture And Interfaces

The plan adds these stable internal interfaces:

```python
def compile_route_slices(graph: dict[str, object]) -> dict[str, str]: ...
def validate_contract_ownership(graph: dict[str, object]) -> list[str]: ...
def inspect_superpowers_dependency(plugin_root: Path, codex_home: Path) -> DependencyResult: ...
def classify_revision(plugin_root: Path, changed_paths: Sequence[str]) -> RevisionImpact: ...
def validate_artifact_lifecycle(plugin_root: Path) -> list[str]: ...
```

`DependencyResult` records status, observed version, required range, missing skills, and recovery command. `RevisionImpact` records changed paths, runtime membership, runtime-read references, selected class, ambiguity findings, and required gates.

## Implementation Boundaries

**Files To Create:** `scripts/lib/dependency_contract.py`, `scripts/lib/revision_impact.py`, `scripts/lib/artifact_lifecycle.py`, `scripts/validate-superpowers-dependency.py`, `scripts/classify-revision.py`, `scripts/validate-artifact-lifecycle.py`, `tests/test_dependency_contract.py`, `tests/test_revision_impact.py`, and `tests/test_artifact_lifecycle.py`.

**Files To Modify:** `docs/superpowers/workflow-contract.yml`, `scripts/lib/workflow_graph.py`, `scripts/lib/gate_resolver.py`, `scripts/generate-outcome-workflow-summary.sh`, `scripts/validate-workflow-graph.py`, `scripts/lib/commands/distribution.py`, `scripts/lib/superpowers_project_cli.py`, `scripts/lib/project-skills.sh`, `scripts/sync-live.sh`, `scripts/install.sh`, `scripts/validate.sh`, `.codex-plugin/plugin.json`, `.codex-plugin/runtime-package.yml`, `tests/test_workflow_graph.py`, `tests/test_workflow_generation.py`, `tests/test_gate_resolver.py`, `tests/test_auto_lifecycle_e2e.py`, `tests/test_loop_lifecycle_e2e.py`, `tests/test_command_locality.py`, `tests/test_runtime_package.py`, and relevant skill route references generated from the contract.

**Files To Avoid:** every file under the installed vanilla Superpowers plugin, every app-managed plugin cache path, `$CODEX_HOME/worktrees`, and unrelated user-level skills.

**Source Of Truth:** workflow behavior comes from `docs/superpowers/workflow-contract.yml`; shipped membership comes from `.codex-plugin/runtime-package.yml`; artifact status comes from explicit canonical artifact metadata or the validated registry chosen in Task 4.

**Read Path:** Validators and classifiers read the repository contract, manifest, runtime package, static runtime reads, Git changed paths, supported Codex plugin metadata, generated route slices, and canonical artifact indexes.

**Write Path:** Source commands write generated repository projections, the plugin-scoped live copy, the marketplace source snapshot, and canonical metadata selected by this plan. Dependency inspection and revision classification are read-only.

**Integration Points:** Codex plugin metadata and CLI, vanilla Superpowers canonical skill names, Git diff path inventory, repository validation, live sync, and release readiness.

**Migration Or Cutover:** Rebase after the three preceding issues. Schema v1 graph data is converted deterministically to schema v2. Existing stable gate and option IDs are preserved where semantics are unchanged. `gate_resolver` and its Manual, Auto, and Loop consumers migrate in the same task. The global helper copy is removed only after all plugin consumers resolve the plugin-scoped helper.

**Replaced Path Handling:** Remove duplicated nested gate facts after generated slices validate; remove `USER_SKILLS` deployment behavior from ordinary sync; replace directory-wide post-revision assumptions only after the classifier is integrated into policy and tests.

**Acceptance Proof Gate:** All task tests, `./scripts/validate.sh`, isolated sync/install tests, dependency preflight fixtures, revision classification fixtures, generated-state checks, namespace snapshots, cleanup, and clean Git state pass.

## Test Complete And Metrics

- Contract ownership report contains zero duplicate owners and zero dangling IDs.
- Generated route slices are stable across two runs and drift tests reject four mutation classes.
- Dependency tests cover compatible, missing, incompatible, and missing-capability installs.
- Namespace snapshots show zero global user-skill mutations during ordinary plugin lifecycle operations.
- Revision tests cover spec-only, plan-only, skill, script, runtime-document, test-only, ambiguous, and mixed changes.
- Artifact lifecycle tests reject dangling supersession and active-index violations while retaining receipt-bound history.
- Command locality tests show domain logic outside `superpowers_project_cli.py`.

## Outcome Proof

**Intent:** Reduce plugin friction and semantic drift by making workflow and distribution facts single-owned, generated, dependency-aware, namespace-safe, and impact-classified.

**Current Behavior:** Gate facts are duplicated, helper policy leaks into a global namespace, vanilla dependency availability is assumed, command responsibilities remain partly broad, and specs-only changes trigger runtime deployment gates despite package exclusion.

**Expected Outcome:** One graph generates route projections, setup reports exact dependency state, normal plugin lifecycle leaves global user skills unchanged, domain modules own their behavior, and each revision receives the gate set required by its actual shipped impact.

**Target Output:** Schema-v2 contract, generated route slices and digest, dependency preflight, plugin-scoped helper deployment, focused domain modules, revision classifier, and artifact lifecycle validator.

**Owner:** Superpowers Project architecture and distribution owner.

**Interface:** The five Python interfaces under Architecture And Interfaces plus stable existing shell launchers and skills.

**Cutover:** Land normalized graph generation first, then dependency and namespace isolation, then revision and artifact classification. Keep current strict revision policy until the new classifier is validated and documented.

**Replaced Path:** Hand-copied gate facts, global helper mutation during plugin sync, implicit vanilla dependency, remaining broad command handlers, and directory-only deployment classification.

**Evidence:** Behavioral unit tests, generated drift fixtures, isolated Codex-home install snapshots, runtime manifest/read reports, artifact index validation, full plugin validation, and clean closeout receipts.

**Acceptance Proof:** All metrics above pass from a clean checkout and an isolated Codex home, with no edits to vanilla or global user skills.

**Stop Criteria:** Stop if the supported Codex metadata cannot establish vanilla dependency identity, a generated slice cannot preserve a stable public route, runtime reads cannot be classified safely, or namespace isolation would delete a user-owned helper.

**Avoid:** Editing cache contents, vendoring vanilla, adding a second graph authority, compatibility passes for ambiguous revisions, line-count-driven skill deletion, or broad deletion of receipt-bound history.

**Risk:** Contract migration and namespace cutover can break loaded sessions or standalone helper users. Preserve stable IDs, validate isolated installs, emit explicit recovery guidance, and require a fresh session after deployed changes.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Plan topology | Four-spec decomposition approved by user | Keep this plan scoped to contract and distribution work. | Trust, lifecycle, and workspace changes retain separate plans and issues. | No | Program owner |
| Contract source | Approved source spec | Normalize `workflow-contract.yml` and generate projections. | Gate facts gain one owner. | No | Contract owner |
| Vanilla relationship | Extension architecture | Declare and inspect an external dependency. | Setup fails clearly without modifying vanilla. | No | Distribution owner |
| Helper deployment | Namespace leakage finding | Keep helpers plugin-scoped in ordinary lifecycle operations. | Global user policy is not silently changed. | No | Distribution owner |
| Revision gates | Runtime package mismatch finding | Classify from shipped membership and runtime reads. | Specs-only work can use document gates while ambiguous work stays strict. | No | Maintenance owner |
| Artifact retention | Receipt dependency evidence | Validate status and inbound references before deletion. | Active truth shrinks without breaking historical proof. | No | Documentation owner |
| Issue dependency | Umbrella order and cross-plan review | Execute last and rebase onto all prior merged issues. | Schema and distribution migration preserve the final kernel, lifecycle, and workspace interfaces. | No | Program owner |

### Task 1: Normalize Graph Ownership And Generate Route Slices

**Use Cases:**

- A skill loads only its owned gates.
- A contract change updates every projection.
- Validator evidence proves duplicate or dangling gate facts fail before packaging and the old copied-policy path is retired at cutover.

**Files:**
- Modify: `docs/superpowers/workflow-contract.yml`
- Modify: `scripts/lib/workflow_graph.py`
- Modify: `scripts/validate-workflow-graph.py`
- Modify: `scripts/generate-outcome-workflow-summary.sh`
- Modify: `tests/test_workflow_graph.py`
- Modify: `tests/test_workflow_generation.py`
- Modify: `scripts/lib/gate_resolver.py`
- Modify: `tests/test_gate_resolver.py`
- Modify: `tests/test_auto_lifecycle_e2e.py`
- Modify: `tests/test_loop_lifecycle_e2e.py`
- Create: `docs/superpowers/generated/routes/README.md`
- Create: generated route slices under `docs/superpowers/generated/routes/`

**Interfaces:**
- Consumes: `load_workflow_graph(path: Path) -> dict[str, object]`
- Produces: `validate_contract_ownership(graph) -> list[str]` and `compile_route_slices(graph) -> dict[str, str]`

- [ ] **Step 1: Write failing ownership and projection tests**

Add tests that require schema version 2, one gate owner, referenced transition IDs, deterministic per-skill slices, a source/generator header, and rejection of duplicate owner, dangling effect, unknown transition, and generated drift fixtures.

Add compatibility fixtures proving the lifecycle gate resolver consumes schema-v2 gates and generated slices without changing Manual question behavior, Auto decisions, or Loop candidate decisions.

```python
def test_route_slices_are_single_owned_and_stable(self):
    graph = load_workflow_graph(CONTRACT)
    self.assertEqual([], validate_contract_ownership(graph))
    first = compile_route_slices(graph)
    second = compile_route_slices(graph)
    self.assertEqual(first, second)
    self.assertIn("initiate-workflow", first)
    self.assertIn("Generated from `docs/superpowers/workflow-contract.yml`", first["initiate-workflow"])
```

- [ ] **Step 2: Run RED tests**

Run: `python3 -m unittest tests.test_workflow_graph tests.test_workflow_generation tests.test_gate_resolver tests.test_auto_lifecycle_e2e tests.test_loop_lifecycle_e2e -v`

Expected: FAIL because schema v2 ownership validation and route-slice generation do not exist.

- [ ] **Step 3: Implement normalized graph and generators**

Add schema-v2 `modes`, normalized `gates`, and `transitions`. Preserve stable question/option IDs. Implement pure ownership validation and deterministic Markdown route slices ordered by skill and gate ID.

```python
def compile_route_slices(graph: dict[str, object]) -> dict[str, str]:
    slices: dict[str, list[tuple[str, dict[str, object]]]] = {}
    for gate_id, gate in sorted(graph["gates"].items()):
        slices.setdefault(gate["owner_skill"], []).append((gate_id, gate))
    return {owner: render_route_slice(owner, gates) for owner, gates in sorted(slices.items())}
```

- [ ] **Step 4: Generate projections and verify GREEN**

Run: `./scripts/generate-outcome-workflow-summary.sh && python3 -m unittest tests.test_workflow_graph tests.test_workflow_generation tests.test_gate_resolver tests.test_auto_lifecycle_e2e tests.test_loop_lifecycle_e2e -v && ./scripts/validate-generated-state.sh`

Expected: all tests pass and generated state reports `findings: []`.

- [ ] **Step 5: Refactor duplicated graph rendering**

Share sorting, header, and digest helpers between route slices and existing summary/index generation. Re-run Step 4.

- [ ] **Step 6: Checkpoint commit**

```bash
git add docs/superpowers/workflow-contract.yml docs/superpowers/generated scripts/lib/workflow_graph.py scripts/lib/gate_resolver.py scripts/validate-workflow-graph.py scripts/generate-outcome-workflow-summary.sh tests/test_workflow_graph.py tests/test_workflow_generation.py tests/test_gate_resolver.py tests/test_auto_lifecycle_e2e.py tests/test_loop_lifecycle_e2e.py
git commit -m "feat: normalize workflow graph projections"
```

### Task 2: Declare And Validate The Vanilla Superpowers Dependency

**Use Cases:**

- Setup accepts a compatible vanilla install.
- Setup blocks a missing or incompatible install with one recovery command.
- Dependency checks never edit vanilla or cache files.

**Files:**
- Create: `scripts/lib/dependency_contract.py`
- Create: `scripts/validate-superpowers-dependency.py`
- Create: `tests/test_dependency_contract.py`
- Modify: `.codex-plugin/plugin.json`
- Modify: `.codex-plugin/runtime-package.yml`
- Modify: `scripts/install.sh`
- Modify: `scripts/validate.sh`

**Interfaces:**
- Consumes: plugin manifest, Codex plugin metadata, required canonical skill set
- Produces: `inspect_superpowers_dependency(plugin_root, codex_home) -> DependencyResult`

- [ ] **Step 1: Write dependency-state tests**

```python
def test_compatible_dependency_reports_ready(self):
    result = inspect_superpowers_dependency(self.plugin_root, self.codex_home)
    self.assertEqual("ready", result.status)
    self.assertEqual([], result.missing_skills)

def test_missing_dependency_is_read_only_and_actionable(self):
    before = snapshot_tree(self.codex_home)
    result = inspect_superpowers_dependency(self.plugin_root, self.empty_home)
    self.assertEqual("missing", result.status)
    self.assertIn("codex plugin", result.recovery_command)
    self.assertEqual(before, snapshot_tree(self.codex_home))
```

- [ ] **Step 2: Run RED test**

Run: `python3 -m unittest tests.test_dependency_contract -v`

Expected: FAIL because `dependency_contract` does not exist.

- [ ] **Step 3: Implement pure dependency inspection**

Define a manifest-owned required capability block or repository-owned dependency contract accepted by current plugin validation. Inspect supported metadata only. Return `ready`, `missing`, `incompatible`, or `incomplete`; never install or mutate during inspection.

- [ ] **Step 4: Add launcher and setup preflight**

Make `scripts/validate-superpowers-dependency.py` print structured JSON and exit nonzero for non-ready states. Call it from install/setup validation before workflows execute.

- [ ] **Step 5: Verify GREEN and mutation safety**

Run: `python3 -m unittest tests.test_dependency_contract -v && python3 scripts/validate-superpowers-dependency.py --plugin-root . --codex-home "$CODEX_HOME"`

Expected: fixtures pass; local result is structured and no vanilla/cache file changes.

- [ ] **Step 6: Checkpoint commit**

```bash
git add .codex-plugin scripts/lib/dependency_contract.py scripts/validate-superpowers-dependency.py scripts/install.sh scripts/validate.sh tests/test_dependency_contract.py
git commit -m "feat: validate vanilla superpowers dependency"
```

### Task 3: Isolate Helper Deployment And Complete Command Locality

**Use Cases:**

- Normal plugin lifecycle changes only plugin-owned paths.
- Standalone helper users receive no silent overwrite.
- Domain logic imports without the CLI router.

**Files:**
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `scripts/lib/project-skills.sh`
- Modify: `scripts/lib/commands/distribution.py`
- Modify: `scripts/sync-live.sh`
- Modify: `scripts/test-plugin-only-live-sync.sh`
- Modify: `tests/test_command_locality.py`
- Create or modify: `tests/test_plugin_namespace.py`

**Interfaces:**
- Consumes: source plugin root, live plugin root, explicit standalone-helper flag absent by default
- Produces: plugin-only sync receipt with `global_user_skill_mutations: []`

- [ ] **Step 1: Write failing lifecycle and locality tests**

Snapshot a sentinel global helper before install, sync, refresh, and uninstall fixtures. Assert byte identity afterward. Add import tests that reject remaining distribution-domain command bodies in `superpowers_project_cli.py`.

- [ ] **Step 2: Run RED tests**

Run: `python3 -m unittest tests.test_command_locality tests.test_plugin_namespace -v`

Expected: FAIL because ordinary sync still deploys `advanced-user-input` globally or locality rules are incomplete.

- [ ] **Step 3: Remove ordinary global helper writes**

Resolve `advanced-user-input` from the plugin namespace. Remove it from `USER_SKILLS` and normal sync copy lists. Preserve existing user-owned standalone files. Emit the global-mutation receipt field.

- [ ] **Step 4: Move remaining distribution handlers**

Move cohesive distribution functions into `scripts/lib/commands/distribution.py`. Keep only compatibility imports and registry dispatch at the CLI boundary.

- [ ] **Step 5: Verify GREEN and isolated lifecycle**

Run: `python3 -m unittest tests.test_command_locality tests.test_plugin_namespace -v && ./scripts/test-plugin-only-live-sync.sh && ./scripts/test-install-transaction.sh`

Expected: all pass; global snapshot unchanged; plugin live tree current.

- [ ] **Step 6: Checkpoint commit**

```bash
git add scripts/lib/superpowers_project_cli.py scripts/lib/project-skills.sh scripts/lib/commands/distribution.py scripts/sync-live.sh scripts/test-plugin-only-live-sync.sh tests/test_command_locality.py tests/test_plugin_namespace.py
git commit -m "fix: keep plugin helpers namespace scoped"
```

### Task 4: Classify Revision Impact And Validate Artifact Lifecycle

**Use Cases:**

- A specs-only edit receives canonical-design gates.
- A runtime-read document receives runtime gates.
- Mixed or ambiguous edits receive the strictest gates.
- Active indexes cannot reference deleted or Superseded files.

**Files:**
- Create: `scripts/lib/revision_impact.py`
- Create: `scripts/lib/artifact_lifecycle.py`
- Create: `scripts/classify-revision.py`
- Create: `scripts/validate-artifact-lifecycle.py`
- Create: `tests/test_revision_impact.py`
- Create: `tests/test_artifact_lifecycle.py`
- Modify: `scripts/lib/revision_status.py`
- Modify: `scripts/lib/commands/distribution.py`
- Modify: `scripts/validate.sh`
- Modify: `AGENTS.md`
- Modify: active milestone indexes and canonical artifact status metadata selected during implementation

**Interfaces:**
- Consumes: changed paths, runtime manifest, runtime-read inventory, artifact metadata, milestone indexes, receipt references
- Produces: `classify_revision(...) -> RevisionImpact` and `validate_artifact_lifecycle(...) -> list[str]`

- [ ] **Step 1: Write revision matrix and lifecycle tests**

```python
def test_spec_only_revision_uses_document_gates(self):
    impact = classify_revision(self.root, ["docs/superpowers/specs/new-design.md"])
    self.assertEqual("canonical_design", impact.selected_class)
    self.assertNotIn("sync-live", impact.required_gates)

def test_runtime_read_document_is_runtime_surface(self):
    impact = classify_revision(self.root, ["docs/superpowers/milestones/receipt.md"])
    self.assertEqual("runtime_surface", impact.selected_class)

def test_active_index_rejects_superseded_artifact(self):
    self.assertIn("active index references Superseded artifact", validate_artifact_lifecycle(self.root)[0])
```

- [ ] **Step 2: Run RED tests**

Run: `python3 -m unittest tests.test_revision_impact tests.test_artifact_lifecycle -v`

Expected: FAIL because both modules are absent.

- [ ] **Step 3: Implement impact classification**

Build runtime membership from `runtime_manifest`, static runtime reads from existing provenance validation, and path classes from explicit rules. Return strictest class for mixed changes and an ambiguity finding when a read cannot be resolved.

- [ ] **Step 4: Implement artifact lifecycle validation**

Choose frontmatter or a registry consistently. Validate allowed statuses, named supersession targets, active milestone membership, inbound references, and receipt-bound Historical retention.

- [ ] **Step 5: Integrate policy and validate GREEN**

Update repository policy only after tests prove the classifier. Add both validators to `scripts/validate.sh`.

Run: `python3 -m unittest tests.test_revision_impact tests.test_artifact_lifecycle tests.test_revision_status -v && python3 scripts/classify-revision.py --plugin-root . --base HEAD && python3 scripts/validate-artifact-lifecycle.py --plugin-root .`

Expected: unit tests pass; classifier prints paths, class, and gates; lifecycle findings are empty.

- [ ] **Step 6: Commit the complete source revision**

```bash
git add AGENTS.md .codex-plugin docs/superpowers scripts tests
git commit -m "feat: simplify contract and distribution lifecycle"
```

- [ ] **Step 7: Run complete acceptance proof from committed source**

Run: `./scripts/validate.sh && ./scripts/sync-live.sh --validate && codex plugin add superpowers-project@personal --json && ./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent && bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root . && git status --short --branch`

Expected: all commands pass and final status is clean after committed source and generated changes.

## Plan Self-Review

- Every source-spec goal maps to a numbered task.
- Every behavior-changing task begins with a failing test and names the expected failure.
- Interfaces are stable across tasks and do not introduce a second workflow authority.
- Namespace isolation precedes removal of ordinary global helper writes.
- Revision policy changes only after classifier tests pass.
- No task edits vanilla Superpowers or app-managed cache files.
- No placeholder requirements remain.
