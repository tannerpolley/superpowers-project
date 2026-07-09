# Distribution And Maintenance Clarity Design

## Purpose

Reduce package churn, make revision status obvious without adding a mutation wrapper, remove unnecessary push requirements from local-branch implementation, and establish an immutable release identity after the runtime and workflow gates pass.

## Project Context Evidence

- The current package provenance includes 262 files and about 2.85 MB.
- Historical material under `docs/superpowers` contributes 89 files and about 1.46 MB to every installed package hash.
- The required post-revision loop is documented and mandatory, but maintainers must infer which gate remains.
- The repository has no Git tags; release policy names `v0.2.0`, the changelog has a `0.2.0` section, and the manifest uses local build metadata.
- `implement-plan` requires branch push proof even for a local-branch merge, while repository policy requires explicit push authorization and the requested route is local merge.

## Design Alternatives

### Design 1: Explicit runtime manifest and read-only status

Package only runtime-required files plus canonical machine-readable contracts, extend the existing version checker with revision status, separate local-branch proof from PR/push proof, pin validation dependencies, and prepare an immutable release only after all gates pass.

Tradeoff: package inclusion becomes an explicit maintained contract. Tests must fail whenever a runtime dependency is omitted.

### Design 2: Continue hashing and copying the whole project history

Keep the current package roots and only improve documentation.

Tradeoff: simplest packaging logic, but every historical edit changes installed provenance and forces a refresh even when runtime behavior is unchanged.

### Design 3: Add an all-in-one revision mutation command

Create one command that validates, commits, synchronizes, installs, and publishes.

Tradeoff: fewer typed commands, but it hides approval seams and contradicts the approved post-revision design that excluded a mutation wrapper.

## Selected Design

Design 1. It improves clarity while preserving explicit commit, merge, sync, installation, and publication decisions.

## Architecture

A Runtime Package Manifest Module names the files shipped and hashed for installation. The existing version command gains a read-only revision-status Interface that reports source, deployment, installation, validation, and release evidence without mutating anything. Local-branch merge evidence becomes a separate Adapter from PR evidence, so a local merge does not require a remote push.

Release preparation consumes exact receipts from validation, sync, installation, provenance, cleanup, and clean Git state. Tag creation remains a deliberate Git action after all release blockers are closed.

## Modules

### Runtime Package Manifest Module

- Includes `.codex-plugin`, `assets`, `skills`, runtime scripts, and explicit machine-readable workflow contracts.
- Excludes historical specs, plans, issue mirrors, and milestone receipts from the installed package.
- Validates that every runtime read path is represented in the package manifest.
- Computes the same deterministic path, mode, length, and SHA-256 manifest used by source/live proof.

### Revision Status Module

- Extends `get-agent-plugin-version.sh` rather than adding another wrapper.
- Reports the current commit, dirty state, runtime hash, deployed hash, installed version, validation receipt, and next required gate.
- Reports the fresh-session requirement when machine gates pass.
- Performs no commit, synchronization, installation, tag, push, or publish operation.

### Local Merge Proof Adapter

- Requires an approved plan, development branch, verification, readiness review, clean premerge, local merge, cleanup, and clean main proof.
- Does not require remote branch push or PR evidence.
- Keeps push as a separate user-authorized route.

### Release Evidence Module

- Pins Python validation dependencies used in CI.
- Requires a current real-agent usability receipt tied to the runtime hash.
- Produces a release receipt containing every gate and exact source commit.
- Supports base-version tags without local build metadata.

## Data Flow

1. Source changes alter only the runtime package hash when an included file changes.
2. Validation writes or reports a source receipt for the current commit.
3. The revision-status Interface compares source, deployment, and installed evidence and names the next gate.
4. Local implementation merges through local proof without a push.
5. The required post-revision loop synchronizes and refreshes the installed snapshot after the merge commit exists.
6. Release preparation consumes the final receipts and permits tag creation only from clean `main`.

## Error Handling

- A runtime read path absent from the package manifest fails package validation.
- A historical documentation edit outside the runtime manifest does not pretend to be an installed runtime change.
- Revision status reports missing or stale receipts rather than guessing that a gate passed.
- Local merge blocks on missing verification or premerge proof, but not on absent push proof.
- Release preparation blocks on missing real-agent receipts, unpinned dependencies, dirty state, version mismatch, or missing changelog evidence.

## Testing

- Package tests prove included changes alter the hash and excluded historical edits do not.
- Runtime-read-path tests prove every packaged read dependency is included.
- Revision-status fixtures cover clean, dirty, stale deployment, stale installation, missing validation, and ready-for-fresh-session states.
- Local-branch contract tests prove clean local merge is allowed without push and PR routes still require remote proof.
- Release tests prove dependency pins, receipt freshness, version/tag normalization, and dirty-state rejection.

## Non-Goals

- Automatically committing, pushing, tagging, or publishing.
- Editing deployed copies or runtime-generated cache locations directly.
- Removing canonical history from the source repository.
- Requiring a GitHub issue or pull request for local approved-plan work.

## Proof Oracle Candidates

- The runtime package contains only declared runtime files and machine-readable contracts.
- Historical spec edits do not alter the runtime package hash.
- Revision status names one exact next gate for every fixture state.
- Local-branch merge proof passes without remote push proof.
- CI uses pinned validation dependencies.
- Release preparation produces a clean receipt for the final `main` commit.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Package scope | Package-size audit | Ship explicit runtime files and machine-readable contracts | Reduces refresh churn while preserving runtime provenance | No | Distribution owner |
| Maintenance command shape | Approved post-revision design | Extend the existing read-only version Interface | Improves clarity without adding a mutation wrapper | No | Distribution owner |
| Local branch publication | User requested local implementation branch merge | Do not require push or PR proof for local merge | Preserves explicit external-write authorization and reduces friction | No | Merge owner |
| Release identity | Release policy plus missing tags | Prepare an immutable base-version release after blockers close | Gives users one stable install identity | No | Release owner |
| Dependency reproducibility | CI audit | Pin validation dependencies | Reduces CI drift | No | CI owner |
| Runtime history | Canonical artifact policy | Keep history in source but outside the installed runtime manifest | Preserves project memory without inflating every package refresh | No | Plugin maintainer |

