# Contract And Distribution Simplification Plan

> Execute with TDD from current `main`. Keep the change net-negative and do not add new subsystems.

## Goal

Stop duplicate global helper deployment and remove non-runtime design history from the installed plugin while preserving all public behavior.

## Architecture

Use the existing sync command, runtime manifest, provenance functions, graph validator, and generated workflow views. The implementation deletes obsolete behavior and broad manifest patterns; it adds no launcher or domain module.

## Tech Stack

Python standard library, YAML runtime manifest, existing Bash launchers, `unittest`, Git, and GitHub Actions.

## Global Constraints

- Preserve stable skill and launcher names.
- Do not edit vanilla Superpowers, deployed copies, or plugin caches directly.
- Do not delete an existing global helper; merely stop managing it.
- Keep all direct runtime reads included and fail closed on drift.
- Require focused tests, full validation, PASS/PASS review, release loop, and CI.

## Source Evidence

- `sync-live` currently copies `advanced-user-input` to the global user-skill root.
- The same skill is already included under the plugin's `skills/` directory.
- The runtime manifest includes 32 specs (466,506 bytes) and 32 plans (628,504 bytes).
- The workflow graph is already version 2 and its generated views are drift-checked.
- Command locality already passes for the deep handlers named by the original plan.

## Outcome Proof

**Intent:** Reduce installed size and external side effects without changing workflow semantics.

**Current Behavior:** Sync rewrites one global helper and the runtime package ships all canonical specs and plans.

**Expected Outcome:** Sync touches only plugin/marketplace state; global skills remain byte-identical; only directly read release artifacts ship from spec/plan history.

**Target Output:** A smaller runtime manifest, a plugin-only sync path, focused regression tests, and concise source documentation.

**Owner:** Superpowers Project distribution and runtime-package code.

**Interface:** Existing `scripts/sync-live.sh`, `runtime_manifest()`, `validate_runtime_reads()`, and repository validation.

**Cutover:** The next sync stops user-skill management immediately; existing global files remain untouched.

**Replaced Path:** `USER_SKILLS` copying and broad `docs/superpowers/specs/**` / `plans/**` package patterns.

**Evidence:** Detached isolated sync snapshots, runtime package/hash tests, full validation, release loop, independent review, and CI.

**Acceptance Proof:** All proof-oracle commands pass and the final branch is net-negative against main.

**Stop Criteria:** Stop if a required runtime read becomes excluded, global sentinel content changes, public launchers drift, or validation fails.

**Avoid:** Avoid schema migrations, route-slice trees, dependency/cache probing, revision classifiers, artifact registries, and compatibility shims.

**Risk:** Legacy global helper users may expect updates. Preserve their files and document that plugin installation no longer manages them.

## Implementation Boundaries

**Files To Create:** None.

**Files To Modify:** `.codex-plugin/runtime-package.yml`, `scripts/lib/superpowers_project_cli.py`, `tests/test_runtime_package.py`, `AGENTS.md`, `README.md`, and the #116 spec/plan/mirror.

**Files To Avoid:** Vanilla Superpowers, app-managed plugin caches, live deployed roots during source editing, workflow/lifecycle kernels, and unrelated canonical history.

**Source Of Truth:** Runtime membership stays in `.codex-plugin/runtime-package.yml`; plugin skills stay under `skills/`.

**Read Path:** Runtime manifest expansion, static runtime-read validation, isolated sync roots, and sentinel snapshots.

**Write Path:** Source files first; committed source then deploys through the required sync/install loop.

**Integration Points:** `command_sync_live`, `validate_skill_source_contract`, runtime provenance, version banner, and full repository validation.

**Migration Or Cutover:** Stop future global helper writes without deleting legacy state; future runtime documents must be explicitly added when runtime-read validation requires them.

**Replaced Path Handling:** Delete the user-skill copy loop and broad manifest globs; do not leave dormant flags or aliases.

**Acceptance Proof Gate:** No merge until focused tests, full validation, PASS/PASS review, live release loop, and CI pass.

## Test Complete And Metrics

- User-skill sentinel tree: unchanged before/after sync.
- Deployed global skills: zero.
- Non-runtime spec/plan files in package: zero.
- Runtime reads excluded: zero.
- Runtime package size: lower than main by roughly 1 MB.
- New production modules or launchers: zero.

## Tasks

### Task 1: Stop Global Helper Deployment

**Use Cases:**

- A normal sync installs the plugin-scoped helper without creating a global copy.
- A pre-existing legacy helper remains byte-identical.
- An unrelated global skill remains byte-identical.
- Acceptance evidence proves the cutover retires duplicate global writes without deleting old state.

1. Extend the isolated sync test with legacy-helper and unrelated-skill sentinels; run it RED.
2. Replace the split plugin/user skill constants with one plugin-skill set.
3. Remove user-skill directory creation and copy behavior from sync.
4. Keep the stable sync launcher and marketplace behavior.
5. Run the isolated sync, install transaction, skill-source, and full command tests GREEN.

### Task 2: Trim The Runtime Package

**Use Cases:**

- Runtime contracts and direct release source reads remain installed.
- Unrelated specs and plans remain repository history only.
- Editing excluded history does not change runtime provenance.
- Package proof shows the displaced broad-glob path no longer contributes files.

1. Add package tests that reject broad spec/plan inclusion; run them RED.
2. Replace the two broad manifest globs with the two direct release-trust source paths.
3. Update source documentation to describe plugin-only sync and explicit runtime membership.
4. Run runtime package/provenance tests and `validate_runtime_reads()` GREEN.
5. Run `./scripts/validate.sh`, independent reviews, the required post-revision loop, and CI.

## Proof Oracle

- `python3 -m unittest tests.test_runtime_package tests.test_package_provenance -v`
- `./scripts/test-plugin-only-live-sync.sh`
- `./scripts/test-install-transaction.sh`
- `./scripts/validate-runtime-package.py --repo-root .`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `codex plugin add superpowers-project@personal --json`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
- `git status --short --branch`

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Workflow work | Existing v2 graph and validators | Keep current implementation. | No duplicate generator or migration. | No | Contract owner |
| Helper deployment | Isolated sync inventory | Plugin-scoped only. | Global skills are not mutated. | No | Distribution owner |
| Legacy helper | User-owned state boundary | Preserve it unchanged. | No destructive cleanup. | No | Distribution owner |
| Runtime history | Runtime manifest inventory | Retain only direct reads. | About 1.1 MB removed from installs. | No | Package owner |
| Dependency declaration | Unsupported manifest field | Keep existing canonical pairings/preflight. | No cache probing or parallel manifest. | No | Runtime owner |
| Release process | Current repository policy | Keep strict loop for installable changes. | No revision classifier subsystem. | No | Maintainer |
