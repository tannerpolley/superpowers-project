# Distribution And Maintenance Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a smaller explicit runtime package, report the next revision gate, support clean local merges without push proof, and establish reproducible release evidence.

**Architecture:** Use one explicit Runtime Package Manifest Module as the inclusion and provenance source of truth. Extend the existing version Interface with read-only revision status, separate local-merge evidence from remote publication evidence, and consume pinned dependency plus real-agent receipts in release preparation.

**Tech Stack:** Python 3.12, Bash, JSON, YAML, Git, Codex CLI, GitHub Actions.

## Global Constraints

- Canonical project history remains in source even when excluded from the installed runtime package.
- Revision status is read-only and never commits, synchronizes, installs, tags, pushes, or publishes.
- Local branch merge does not require remote push or PR proof.
- Remote push, tag publication, and GitHub writes require separate explicit authority.
- Runtime reads absent from the package manifest fail validation.

---

## Source Evidence

- Source spec: `docs/superpowers/specs/2026-07-09-distribution-maintenance-clarity-design.md`
- Auto authorization: `.superpowers/runs/2026-07-09-complete-remediation/auto-mode-authorization.json`
- Package roots: `scripts/lib/package_provenance.py`
- Revision loop: `AGENTS.md` and `README.md`
- Release rules: `docs/superpowers/RELEASE_POLICY.md`

## Test Complete And Metrics

- Runtime package file and byte totals decrease; all runtime read paths remain included.
- Included file content or mode changes alter the package hash; excluded historical plan/spec edits do not.
- Revision status returns one exact next gate for six fixture states.
- Local-branch merge contract passes with zero push or PR fields and still requires clean validation, premerge, merge, cleanup, and main proof.
- CI installs exact dependency versions.
- Release preparation ties manifest version, base version, current commit, agent receipt, validation, sync, installation, and cleanup evidence together.
- Full validation exits zero.

## Outcome Proof

**Intent:** Reduce maintenance churn and make installation, local integration, and release state explicit.

**Current Behavior:** Historical docs alter runtime provenance, revision progress must be inferred, local plan work requires push proof, dependencies drift, and no immutable tag identifies a completed release.

**Expected Outcome:** Only runtime-required files affect the installed hash; the version command names the next gate; local merge proof is local; and release evidence is reproducible.

**Target Output:** Runtime package manifest, read-path validator, revision status, local-merge contract, dependency pins, updated release policy, and release receipt support.

**Owner:** Distribution owner.

**Interface:** Package manifest, `get-agent-plugin-version.sh` revision-status mode, local-branch proof schema, and release receipt JSON.

**Cutover:** Prove runtime-read completeness, switch provenance/sync to the manifest, add status fixtures, split local proof, then update release metadata.

**Replaced Path:** Whole-history package roots, manual next-gate inference, and push-required local merge evidence.

**Evidence:** Package manifests and hashes, status fixtures, local merge fixtures, pinned CI install output, validation summary, sync proof, installed-version proof, and release receipt.

**Acceptance Proof:** Package/read-path tests pass; revision status is exact; local merge needs no push; dependencies are pinned; final source/live/install proof matches.

**Stop Criteria:** Stop when a runtime read is excluded, local merge proof weakens validation, revision status would mutate, or release evidence is stale.

**Avoid:** Mutation wrappers, direct deployment edits, hidden cache repair, forced remote publication, unpinned validation dependencies, and version tags containing build metadata.

**Risk:** Excluding a required runtime file can break installed operation; the distribution owner mitigates this with runtime-read-path tests and isolated installation proof.

## Implementation Boundaries

**Files To Create:** `.codex-plugin/runtime-package.yml`, `scripts/validate-runtime-package.py`, `tests/test_runtime_package.py`, revision-status fixtures, and pinned validation dependency input.

**Files To Modify:** `scripts/lib/package_provenance.py`, `scripts/sync-live.sh`, `scripts/get-agent-plugin-version.sh`, `scripts/lib/superpowers_project_cli.py` or its extracted distribution Module, `skills/implement-plan/SKILL.md`, `skills/merge-changes/SKILL.md`, merge contract helpers, `.github/workflows/validate.yml`, `CHANGELOG.md`, `.codex-plugin/plugin.json`, `README.md`, and release policy.

**Files To Avoid:** Deployed plugin copies before the final sync gate, plugin cache files, issue mirrors, and unrelated source history.

**Source Of Truth:** `.codex-plugin/runtime-package.yml` for installed contents and release receipts for final distribution state.

**Read Path:** Package manifest to provenance/sync; version command to source/live/install receipts; local merge Adapter to plan and verification evidence.

**Write Path:** Sync writes only deployed copies after commit; release preparation writes evidence only; local merge writes Git history and cleanup receipts.

**Integration Points:** Package hashing, sync, marketplace installation, workflow skills, CI, release preparation, and required post-revision loop.

**Migration Or Cutover:** Add failing package tests, adopt explicit manifest, add status and local-proof behavior, then update version and changelog for the completed minor release.

**Replaced Path Handling:** Remove whole-root inclusion and push-required local proof; preserve separate push and PR routes for user-authorized publication.

**Acceptance Proof Gate:** Focused distribution tests, full validation, local merge proof, sync, plugin refresh, version freshness, cleanup, and clean Git state.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Runtime inclusion | Source spec | Explicit package manifest | Reduces hash churn and makes omissions testable | No | Distribution owner |
| Status behavior | Approved revision-loop design | Extend existing version Interface read-only | Names the next gate without hiding approvals | No | Distribution owner |
| Local merge proof | User instruction | No remote push or PR requirement | Reduces friction and preserves external-write authority | No | Merge owner |
| Dependency policy | CI audit | Pin exact validation versions | Makes CI reproducible | No | CI owner |
| Release version | Existing version policy | Use the next minor version for new workflow capabilities | Gives the completed revision set an immutable identity | No | Release owner |
| Publication | User scope | Create local release evidence and tag; do not push | Completes local identity without unauthorized remote mutation | No | Release owner |

### Task 1: Define and validate the runtime package manifest

**Use Cases:**
- Runtime-required skills, scripts, assets, and contracts ship and hash deterministically.
- Historical specs, plans, and receipts remain in source but do not force installation refresh.
- A newly introduced runtime read absent from the manifest fails validation.
- Package cutover acceptance proof shows every runtime read remains included while the displaced whole-history path no longer controls the hash.

**Files:**
- Create: `.codex-plugin/runtime-package.yml`
- Create: `scripts/validate-runtime-package.py`
- Create: `tests/test_runtime_package.py`
- Modify: `scripts/lib/package_provenance.py`
- Modify: `scripts/sync-live.sh`

**Interfaces:**
- Produces: `load_runtime_package`, `runtime_manifest`, `runtime_contract_hash`, and `validate_runtime_reads`.
- Consumes: explicit include globs and runtime read-path evidence.

- [ ] **Step 1: Write failing package tests** for included changes, excluded history changes, missing runtime reads, and file modes.
- [ ] **Step 2: Run RED** and verify whole-history roots alter the current hash.
- [ ] **Step 3: Add the explicit package manifest** and use it for hashing and sync inclusion.
- [ ] **Step 4: Add static and fixture runtime-read validation** for scripts, skills, manifest assets, and machine contracts.
- [ ] **Step 5: Run GREEN** and compare package file/byte metrics before and after.
- [ ] **Step 6: Commit** with `refactor: define the runtime package`.

### Task 2: Add read-only revision status

**Use Cases:**
- A maintainer sees whether validation, commit, sync, installation, freshness, cleanup, or fresh session is next.
- Dirty and stale states report exact evidence without mutation.
- Machine-readable JSON and a concise banner convey the same state.

**Files:**
- Modify: `scripts/get-agent-plugin-version.sh`
- Modify: `scripts/lib/commands/distribution.py`
- Create: `tests/test_revision_status.py`
- Modify: `README.md`

**Interfaces:**
- Produces: `-RevisionStatus` and JSON fields `state`, `next_gate`, `evidence`, and `fresh_session_required`.
- Consumes: source Git state, validation receipt, deployment hash, installed plugin listing, and cleanup receipt.

- [ ] **Step 1: Write six failing status fixtures** for clean-current, dirty, missing validation, stale deployment, stale installation, and machine-complete/fresh-session states.
- [ ] **Step 2: Run RED** and confirm the version Interface lacks status output.
- [ ] **Step 3: Implement pure state evaluation** and expose it through the existing launcher.
- [ ] **Step 4: Prove the status path performs no writes** with filesystem snapshots in tests.
- [ ] **Step 5: Run GREEN** and document the read-only command.
- [ ] **Step 6: Commit** with `feat: report plugin revision status`.

### Task 3: Separate local merge proof from remote publication

**Use Cases:**
- An approved implementation branch merges locally after clean premerge proof without being pushed.
- A PR route still requires branch push, PR, checks, and issue linkage.
- Future agents do not infer push authority from local merge authority.

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/implement-plan/scripts/lib/contract.sh`
- Modify: `skills/merge-changes/scripts/lib/contract.sh`
- Modify: affected command handlers
- Modify: affected skill scenario tests

**Interfaces:**
- Produces: separate `local_branch_proof` and `remote_publication_proof` validation paths.
- Consumes: approved plan, branch, verification, readiness review, merge decision, and cleanup evidence.

- [ ] **Step 1: Write failing local-merge fixtures** that omit push and PR proof but contain every local safety field.
- [ ] **Step 2: Run RED** and verify current contracts reject the safe local route.
- [ ] **Step 3: Split proof schemas and handler validation** without weakening PR requirements.
- [ ] **Step 4: Slim skill instructions around the two explicit routes** and remove push gates from local-only execution.
- [ ] **Step 5: Run GREEN** for local and PR accepted/rejected fixtures plus skill scenarios.
- [ ] **Step 6: Commit** with `fix: keep local merge proof local`.

### Task 4: Pin release dependencies and version evidence

**Use Cases:**
- CI installs the same validation dependencies on every run.
- Release preparation rejects stale agent receipts and mismatched versions.
- Local build metadata does not appear in tags.

**Files:**
- Create: `requirements-validation.txt`
- Modify: `.github/workflows/validate.yml`
- Modify: `scripts/prepare-release.sh`
- Modify: release handler and tests
- Modify: `docs/superpowers/RELEASE_POLICY.md`

**Interfaces:**
- Produces: pinned dependency install and release receipt fields for package hash, agent receipt, validation, sync, installation, cleanup, version, and base tag.
- Consumes: current commit and proof receipts.

- [ ] **Step 1: Write failing release fixtures** for unpinned dependencies, stale agent receipt, missing installed proof, and build-metadata tag names.
- [ ] **Step 2: Run RED** against current release preparation.
- [ ] **Step 3: Pin validation dependencies** and update CI to install from the pinned file.
- [ ] **Step 4: Extend release evidence validation** with current package and agent receipt equality.
- [ ] **Step 5: Run GREEN** across release, lifecycle, and full validation tests.
- [ ] **Step 6: Commit** with `build: make release evidence reproducible`.

### Task 5: Establish the completed release identity

**Use Cases:**
- The completed capability set has a clear manifest and changelog version.
- The local tag names the exact clean merged commit.
- No remote publication occurs without separate authority.

**Files:**
- Modify: `.codex-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `docs/superpowers/RELEASE_POLICY.md`
- Test: release preparation and version freshness tests

**Interfaces:**
- Produces: manifest version `0.3.0`, changelog entry `0.3.0 - 2026-07-09`, and base tag `v0.3.0` after final proof.
- Consumes: clean merged `main`, validation, sync, installed freshness, real-agent receipt, and cleanup evidence.

- [ ] **Step 1: Add failing version-alignment tests** requiring manifest, changelog, and release policy to agree on `0.3.0`.
- [ ] **Step 2: Run RED** and verify current build version does not satisfy the new release identity.
- [ ] **Step 3: Update manifest, changelog, and release policy** with the completed revision scope.
- [ ] **Step 4: Run full validation and release check-only proof** on the implementation branch.
- [ ] **Step 5: Commit** with `release: prepare superpowers project 0.3.0`.
- [ ] **Step 6: After local merge and all post-revision gates pass, create local tag `v0.3.0`** without pushing it.
