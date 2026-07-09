# Release Readiness Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore trustworthy, cross-repository, installable, executable Superpowers Project behavior and prove Auto/Looping Mode usability with non-interactive fresh-context subagent trials.

**Architecture:** Preserve the public launcher and skill names while replacing heuristic dispatch with a fail-closed command registry. Introduce explicit plugin/project runtime contexts, a complete package provenance hash, a typed workflow graph, and an append-only event ledger with deterministic projection. Keep Auto Mode as one-route authorization and Looping Mode as bounded orchestration over owner skills.

**Tech Stack:** Bash launchers, Python 3.10+ runtime modules, PyYAML, JSON Schema-style fixture validation, Git, Codex CLI, disposable Git repositories, isolated `CODEX_HOME`, and Codex multi-agent workers.

## Global Constraints

- Missing evidence, unsupported capabilities, stale provenance, unregistered commands, and out-of-scope mutations fail loudly.
- `plugin_root` contains installed plugin resources; `project_root` contains consumer-repository state. Never require a consumer repository to contain plugin scripts or contracts.
- No direct Codex cache mutation. Installation and discovery use the supported marketplace/plugin CLI lifecycle in isolated test homes.
- Auto Mode authorizes one target and one route. Looping Mode selects one candidate per iteration and needs an explicit bounded continuation grant before another candidate.
- Autonomous trial workers must not call `request_user_input`, ask the root agent a question, access the network, or mutate external systems.
- Every new production behavior follows RED → GREEN → REFACTOR, with a recorded failing test before implementation.
- Do not add generic success or guessed approval fallbacks.
- Canonical artifacts remain under `docs/superpowers/`; generated run state remains under ignored `.superpowers/runs/`.
- Each task ends with targeted tests, a review checkpoint, and a commit owned by the main thread.

---

### Task 1: Replace heuristic dispatch with a fail-closed command registry

**Files:**
- Create: `tests/test_command_registry.py`
- Create: `scripts/lib/superpowers_project_command_registry.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `scripts/lib/run-script.sh`
- Modify: `scripts/validate.sh`
- Modify: every registered launcher only when its relative path is missing from the registry
- Test: `scripts/test-command-registry.sh`

**Interfaces:**
- `build_command_registry(plugin_root: Path) -> dict[str, str]`
- `resolve_command(script_rel: str) -> str` raises `ScriptError` for an unregistered path.
- `dispatch_command(ctx: RuntimeContext, command_name: str, args: dict[str, Any]) -> int` calls exactly one named handler.
- Generic test/validator success handlers are deleted.

- [ ] **Step 1: Write the failing registry test**

  Assert that every shipped launcher has exactly one registry entry, a known former library file is not classified as a test, and an invented `scripts/test-unknown.sh` path raises a nonzero `unregistered script path` error.

- [ ] **Step 2: Run the focused test to verify RED**

  Run: `python3 -m unittest tests/test_command_registry.py -v`

  Expected: FAIL because current dispatch routes unknown and generic paths to success.

- [ ] **Step 3: Implement the explicit registry and fail-closed dispatch**

  Define a relative-path registry, remove `command_generic_test`, remove `command_generic_validate`, and make every unregistered launcher exit nonzero with JSON fields `ok: false`, `phase`, `reason`, and `script`.

- [ ] **Step 4: Restore the first four behavioral validator suites**

  Port the former `test-plan-task-use-cases.ps1`, `test-plan-outcome-proof.ps1`, `test-decision-ledger.ps1`, and `test-workflow-mode-ledger.ps1` into real Bash/Python fixtures. Each suite must include one accepted fixture and one rejected fixture.

- [ ] **Step 5: Run targeted and migration tests**

  Run: `python3 -m unittest tests/test_command_registry.py -v`, `bash scripts/test-plan-task-use-cases.sh`, `bash scripts/test-plan-outcome-proof.sh`, `bash scripts/test-decision-ledger.sh`, `bash scripts/test-workflow-mode-ledger.sh`, `bash scripts/test-linux-migration.sh`.

  Expected: all pass; invalid fixtures fail inside the test and are reported as expected failures.

- [ ] **Step 6: Commit**

  Commit message: `fix: make command dispatch fail closed`

### Task 2: Separate plugin and project runtime contexts

**Files:**
- Create: `scripts/lib/superpowers_project_context.py`
- Create: `tests/test_runtime_context.py`
- Create: `scripts/test-cross-repo-runtime.sh`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: all handlers that currently call `resolve_under(ctx.repo_root, ...)`
- Test: `scripts/test-auto-mode-contract.sh`, `scripts/test-workflow-mode-ledger.sh`

**Interfaces:**
- `RuntimeContext(script_path, plugin_root, invocation_cwd, script_rel)`.
- `resolve_project_root(ctx, args) -> Path` defaults to invocation CWD and accepts an external absolute repository.
- `resolve_project_path(project_root, value, label) -> Path` rejects traversal outside the project.
- `resolve_plugin_path(plugin_root, value, label) -> Path` rejects traversal outside the package.

- [ ] **Step 1: Write failing sibling-repository tests**

  Create a temporary Git repository beside the plugin. Invoke packaged workflow and Auto validators from the plugin root with `-RepoRoot <sibling>`. Assert success for valid ledgers, rejection for `../outside`, and zero writes inside the plugin.

- [ ] **Step 2: Run RED**

  Run: `python3 -m unittest tests/test_runtime_context.py -v`.

  Expected: FAIL with `RepoRoot is outside repo root` from current containment logic.

- [ ] **Step 3: Implement the dual-root context**

  Rename the discovered package root to `plugin_root`, resolve project paths from explicit `RepoRoot` or invocation CWD, and move artifact containment checks to `project_root`.

- [ ] **Step 4: Run the external dummy-repository fixture**

  Run: `bash scripts/test-cross-repo-runtime.sh`.

  Expected: external valid repository passes; plugin-relative and project-relative traversal attempts fail; no plugin files are created or modified.

- [ ] **Step 5: Commit**

  Commit message: `fix: separate plugin and project runtime roots`

### Task 3: Repair package provenance, marketplace installation, and sync

**Files:**
- Create: `scripts/lib/package_provenance.py`
- Create: `tests/test_package_provenance.py`
- Create: `scripts/test-codex-marketplace-lifecycle.sh`
- Create: `scripts/test-install-transaction.sh`
- Create: `scripts/test-release-proof.sh`
- Modify: `.codex-plugin/plugin.json`
- Modify: `scripts/install.sh`, `scripts/sync-live.sh`, `scripts/prepare-release.sh`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `README.md`, `docs/superpowers/RELEASE_POLICY.md`, `.github/workflows/validate.yml`

**Interfaces:**
- `runtime_manifest(plugin_root) -> list[PackageEntry]` with canonical relative path, mode, length, and SHA-256.
- `runtime_contract_hash(plugin_root) -> str` covers manifest, skills, assets, scripts, and packaged contracts.
- `verify_runtime_provenance(ledger, plugin_root, project_root) -> None` requires exact manifest/hash/project equality.
- Marketplace lifecycle uses `codex plugin marketplace add`, `codex plugin add`, `codex plugin list`, and `codex plugin remove` only in isolated homes.

- [ ] **Step 1: Write failing provenance and isolated-home tests**

  Assert that changing a contract, wrapper, skill, or executable bit changes the hash; forged ledger hashes fail; a sibling copy has the same hash; and an isolated Codex home can discover and install the plugin.

- [ ] **Step 2: Run RED**

  Run: `python3 -m unittest tests/test_package_provenance.py -v` and `bash scripts/test-codex-marketplace-lifecycle.sh`.

  Expected: hash does not include current contracts correctly, forged provenance is accepted, and the current custom install path is not discoverable.

- [ ] **Step 3: Implement complete package hashing and packaged authorities**

  Include canonical package-relative paths and contracts in the hash. Move or package `workflow-contract.yml` and `loop-mode-contract.yml` with the plugin surface, and make runtime ledgers compare exact provenance.

- [ ] **Step 4: Implement supported marketplace install and transactional validation**

  Stage package content, update the supported marketplace source, call the Codex CLI lifecycle, and remove custom cache scanning, cache refresh, and direct cache mutation. A failed update must leave the previous installed version intact.

- [ ] **Step 5: Run install, transaction, release, and sync checks**

  Run: `bash scripts/test-codex-marketplace-lifecycle.sh`, `bash scripts/test-install-transaction.sh`, `bash scripts/test-release-proof.sh`, `bash scripts/sync-live.sh --validate`.

  Expected: isolated install/list/remove passes, invalid update preserves the previous install, missing release receipts fail, and source/package/live proof is explicit.

- [ ] **Step 6: Commit**

  Commit message: `fix: make package installation and provenance real`

### Task 4: Implement fail-closed safety gates and the run ledger

**Files:**
- Create: `docs/superpowers/run-ledger.schema.json`
- Create: `docs/superpowers/run-event.schema.json`
- Create: `scripts/lib/workflow_state.py`
- Create: `scripts/lib/workflow_policy.py`
- Create: `scripts/lib/workflow_completion.py`
- Create: `tests/test_workflow_state.py`
- Create: `scripts/test-workflow-runtime.sh`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: merge, resolve, implement, and loop validators

**Interfaces:**
- `append_event(run_root, event) -> None` hash-chains event sequence.
- `replay_events(events_path) -> RunProjection` deterministically rebuilds `run.json`.
- `validate_authorization(auth, project_root, plugin_root) -> None` enforces profile, capabilities, provenance, target, and budgets.
- `validate_terminal_closeout(projection) -> None` requires the exact terminal completion contract and proof.

- [ ] **Step 1: Write failing negative gate tests**

  Missing PR-ready, premerge, merge-decision, closeout, and verifier evidence must fail. A transition that selects a second candidate before acceptance, budget recheck, and continuation grant must fail.

- [ ] **Step 2: Run RED**

  Run: `python3 -m unittest tests/test_workflow_state.py -v`.

  Expected: current validators pass missing evidence and do not reject invalid transition order.

- [ ] **Step 3: Implement append-only events and deterministic projection**

  Add event sequence, actor, iteration, artifact references, previous-event digest, event digest, and explicit blocked/failed/stopped/completed outcomes. Reject direct projection mutation.

- [ ] **Step 4: Replace fail-open safety handlers**

  Require exact evidence fields and provenance in PR-ready, premerge, merge-decision, closeout, Auto authorization, verifier, and release validators. Unknown operations fail through the command registry.

- [ ] **Step 5: Run focused runtime tests**

  Run: `python3 -m unittest tests/test_workflow_state.py -v`, `bash scripts/test-workflow-runtime.sh`, `bash scripts/test-loop-controller.sh`.

- [ ] **Step 6: Commit**

  Commit message: `fix: enforce workflow proofs and run state`

### Task 5: Canonicalize the workflow graph and generated surfaces

**Files:**
- Create: `scripts/validate-workflow-graph.py`
- Create: `scripts/test-workflow-graph.sh`
- Modify: `docs/superpowers/workflow-contract.yml`, `docs/superpowers/loop-mode-contract.yml`
- Modify: `README.md`, `docs/superpowers/OUTCOME_WORKFLOW.md`
- Modify: all `skills/*/SKILL.md` and route metadata that contain gate IDs/options

**Interfaces:**
- `load_workflow_graph(path) -> WorkflowGraph` rejects YAML booleans where labels are required.
- `validate_workflow_graph(graph, skill_sources, metadata_sources) -> list[Finding]` checks exact IDs, labels, parents, terminal states, owners, validators, artifacts, and transitions.
- `generate_outcome_workflow(graph) -> str` produces the summary from the graph.

- [ ] **Step 1: Write failing drift fixtures**

  Add fixtures for boolean `true` in place of `Yes`, duplicate Auto IDs with conflicting prompts, wrong nested parent, terminal option in a nested route, missing owner, and missing transition.

- [ ] **Step 2: Run RED**

  Run: `bash scripts/test-workflow-graph.sh`.

  Expected: current validator accepts the malformed fixtures; the new test must fail.

- [ ] **Step 3: Implement typed graph validation and generate the summary**

  Quote exact labels, define each gate once, validate every skill and metadata surface, and generate the outcome summary from the graph.

- [ ] **Step 4: Run graph and full contract checks**

  Run: `bash scripts/test-workflow-graph.sh`, `bash scripts/test-workflow-contract.sh`, `./scripts/validate.sh`.

- [ ] **Step 5: Commit**

  Commit message: `fix: make workflow routes executable and canonical`

### Task 6: Slim skills, metadata, and capability contracts

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: all route `SKILL.md` files with duplicated continuation/debug policy
- Modify: all `skills/*/agents/openai.yaml`
- Create: `docs/superpowers/capabilities.yml`
- Create: `scripts/validate-skill-slimming.py`
- Create: `scripts/test-skill-slimming.sh`

**Interfaces:**
- `capabilities.yml` defines native input, goals, GitHub, threads, worktrees, and Agent-Native availability.
- Route skills retain trigger, ownership, inputs, outputs, stop reasons, and one engine invocation.
- Metadata contains concise discovery text and dependency declarations; detailed route policy lives in the graph and references.

- [ ] **Step 1: Write failing duplication and capability tests**

  Assert that duplicated global policy outside the helper, malformed debug fields, oversized route metadata, missing dependencies, and unresolved plugin-relative paths fail validation.

- [ ] **Step 2: Run RED**

  Run: `bash scripts/test-skill-slimming.sh`.

  Expected: current duplicated skill bodies and metadata fail the new checks.

- [ ] **Step 3: Centralize and slim policy**

  Remove repeated continuation/artifact/debug blocks from downstream skills, fix native-input instructions to match the callable tool contract, declare capabilities, and export the shared helper only once.

- [ ] **Step 4: Run skill and metadata validation**

  Run: `bash scripts/test-skill-slimming.sh`, `python3 scripts/validate-plugin.py .`, `./scripts/validate.sh`.

- [ ] **Step 5: Commit**

  Commit message: `refactor: slim skills around executable workflow contracts`

### Task 7: Add governance profiles and scoped completion

**Files:**
- Create: `docs/superpowers/governance-profiles.yml`
- Create: `scripts/test-governance-profiles.sh`
- Modify: `skills/initiate-workflow/SKILL.md`, `skills/audit-project/SKILL.md`, `skills/loop-controller/SKILL.md`
- Modify: `scripts/lib/workflow_completion.py`, `docs/superpowers/OUTCOME_WORKFLOW.md`

**Interfaces:**
- Profiles: `manual.interactive`, `auto.one-route`, `loop.bounded`, and test-only `trial.local`.
- Completion claims: `candidate-complete`, `authorized-scope-complete`, `run-closed`, and `project-complete`.
- `trial.local` forbids network and external mutation and accepts only fixture provenance in a marked temporary repository.

- [ ] **Step 1: Write failing profile tests**

  Assert that a completed requested plan can terminate as `candidate-complete`, Auto cannot select a second target, Loop cannot drain without a continuation grant, and trial authorization cannot claim `request_user_input` provenance.

- [ ] **Step 2: Run RED**

  Run: `bash scripts/test-governance-profiles.sh`.

  Expected: current global continuation policy rejects scoped completion and accepts ambiguous Auto semantics.

- [ ] **Step 3: Implement profile and completion policy**

  Make profile capabilities executable and record out-of-scope work as preserved/report-only. Remove the requirement to continue a workflow after the user’s requested artifact is complete.

- [ ] **Step 4: Run focused profile tests**

  Run: `bash scripts/test-governance-profiles.sh`, `bash scripts/test-workflow-runtime.sh`.

- [ ] **Step 5: Commit**

  Commit message: `feat: add scoped governance and completion profiles`

### Task 8: Run fresh-context non-interactive Auto/Loop subagent trials

**Files:**
- Create: `tests/workflow-trials/scenarios/auto/*.json`
- Create: `tests/workflow-trials/scenarios/loop/*.json`
- Create: `tests/workflow-trials/repos/`
- Create: `tests/workflow-trials/oracles/`
- Create: `tests/workflow-trials/trial-report.schema.json`
- Create: `scripts/validate-agent-usability-receipt.sh`
- Create: `scripts/test-agent-usability-trials.sh`
- Modify: `scripts/validate.sh`

**Interfaces:**
- Trial worker input: dummy repo path, authorization path, run path, and task entrypoint only.
- Trial worker output: JSON with `trial_id`, `outcome_claimed`, `friction_score`, `friction_events`, `ease_points`, `ambiguities`, `extra_skill_reads`, `retries`, `scope_deviations`, and `recommended_change`.
- Independent verifier input excludes worker report and verifies the untouched oracle plus resulting repository.

- [ ] **Step 1: Write trial fixtures and failing receipt tests**

  Add one Auto happy path, one Auto missing-grant block, one Loop two-candidate path, one Loop budget-exhausted path, and one Auto-ledger misuse path. Assert zero `request_user_input` calls, zero network calls, and correct file-level scope.

- [ ] **Step 2: Run RED with current skills**

  Run: `bash scripts/test-agent-usability-trials.sh --baseline`.

  Expected: current skills cannot complete fixture authorization truthfully or provide deterministic run proof; the baseline receipt records the concrete friction.

- [ ] **Step 3: Dispatch fresh non-interactive subagents**

  Use one fresh worker per trial and one independent verifier per completed trial. Workers must finish with JSON, not questions. Any ambiguity must become `POLICY_BLOCKED`, never a root-agent request.

- [ ] **Step 4: Validate and aggregate receipts**

  Run: `bash scripts/validate-agent-usability-receipt.sh tests/workflow-trials/results`; `bash scripts/test-agent-usability-trials.sh --after`.

  Expected: five repetitions per golden path, three per adversarial path, all negative cases block before mutation, median friction at or below 2/5, and deterministic event replay.

- [ ] **Step 5: Commit**

  Commit message: `test: add noninteractive auto and loop usability trials`

### Task 9: Integrate CI, release proof, and full verification

**Files:**
- Modify: `.github/workflows/validate.yml`
- Modify: `scripts/validate.sh`, `scripts/sync-live.sh`, `scripts/prepare-release.sh`
- Modify: `docs/superpowers/RELEASE_POLICY.md`, `CHANGELOG.md`
- Create: `docs/superpowers/milestones/M2-release-readiness-receipt.md`

**Interfaces:**
- CI runs source, negative, cross-repo, isolated marketplace, workflow replay, and trial checks without user secrets.
- Release proof records source commit, manifest version, complete package hash, Codex CLI version, marketplace/plugin IDs, and every required gate receipt.

- [ ] **Step 1: Write failing release assertions**

  Missing any required gate receipt, mismatched commit/hash, untagged candidate, or isolated install failure must produce `publish_ready: false`.

- [ ] **Step 2: Run RED**

  Run: `bash scripts/test-release-proof.sh`.

  Expected: current receipt implementation reports readiness without executing gates.

- [ ] **Step 3: Implement CI and release evidence consumption**

  Make release proof consume actual JSON receipts, add isolated Codex lifecycle CI where available, and clearly distinguish source-only checks from installed-runtime checks.

- [ ] **Step 4: Run the complete verification sequence**

  Run: `./scripts/validate.sh`; `./scripts/sync-live.sh --validate`; `bash scripts/test-cross-repo-runtime.sh`; `bash scripts/test-codex-marketplace-lifecycle.sh`; `bash scripts/test-workflow-runtime.sh`; `bash scripts/test-agent-usability-trials.sh --after`; `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`; `git status --short --branch`.

  Expected: every command exits 0, trial receipts meet thresholds, cleanup completes, and Git is clean.

- [ ] **Step 5: Commit**

  Commit message: `chore: prove release readiness`

## Requirement-to-evidence matrix

| Requirement | Evidence |
|---|---|
| No generic-success path | command registry tripwire and negative unknown-command test |
| Former behavior restored | real validator/scenario fixtures with accepted/rejected cases |
| Consumer repos work | sibling dummy-repo cross-root suite |
| Complete runtime packaged | provenance hash mutation tests and installed package inspection |
| Supported installation | isolated `CODEX_HOME` marketplace/add/list/remove suite |
| Safety gates fail closed | missing-evidence and transition-order tests |
| One route authority | typed workflow graph and generated summary drift tests |
| Minimal friction | skill-size, duplicate-policy, capability, and scoped-completion tests |
| Auto/Loop noninteractive behavior | fresh worker/verifier trial receipts and zero-input tripwire |
| Release-ready proof | CI, release receipts, sync validation, cleanup, and clean Git state |
