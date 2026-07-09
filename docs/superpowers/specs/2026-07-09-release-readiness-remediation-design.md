# Release Readiness Remediation Design

**Date:** 2026-07-09  
**Status:** Approved architecture; implementation in progress  
**Scope:** Restore trustworthy execution, distribution, workflow enforcement, and agent-mode usability for the Superpowers Project plugin.

## Goal

Make the plugin release-ready without breaking its public skill namespace: every shipped command must either perform its named behavior or fail loudly; consumer repositories must work from an installed plugin; workflow approvals and proofs must be executable; and Auto/Looping Mode must be testable by fresh non-interactive subagents against disposable repositories.

## Design decision

Use a staged hybrid migration:

1. Preserve the existing `.sh` launcher names and `$superpowers-project:*` skill names for compatibility.
2. Replace basename/heuristic dispatch and generic-success fallbacks with an explicit command registry and fail-closed behavior.
3. Restore former behavior test-first, beginning with the highest-value validators and ledgers.
4. Separate immutable `plugin_root` resources from the active `project_root`.
5. Package and hash the complete runtime authority surface.
6. Keep Auto Mode as bounded route authorization and Looping Mode as bounded orchestration.
7. Add an append-only event ledger plus deterministic run projection for resumability and proof.
8. Slim route skills around the executable contract and provide Light, Standard, and Governed profiles.

## Runtime boundaries

```text
RuntimeContext
  plugin_root       immutable installed package: scripts, skills, contracts, assets
  invocation_cwd    caller working directory
  project_root      explicit -RepoRoot or invocation_cwd; consumer repository
  run_root          project_root/.superpowers/runs/<run-id>
```

Plugin paths must resolve only under `plugin_root`. Project artifacts, ledgers, Git state, and generated output must resolve only under `project_root`. A `-RepoRoot` outside the plugin source is valid; traversal outside the project root is not.

## Distribution boundary

The supported installation path is Codex marketplace discovery and installation. Runtime code must not edit Codex cache directories. Local and CI tests use isolated `CODEX_HOME` and prove marketplace registration, plugin availability, enabled installation, packaged skill discovery, and removal.

The package includes `.codex-plugin`, `skills`, `assets`, `scripts`, and canonical machine-readable contracts. The runtime hash covers the complete package with canonical plugin-relative paths, file mode, length, and SHA-256. Ledgers require exact runtime provenance equality rather than merely non-empty version/hash fields.

## Workflow engine

The workflow contract becomes one typed route graph. It owns gate IDs, prompts, option labels, parent relationships, terminal states, route ownership, validators, artifacts, and transitions. Documentation and metadata are generated or checked against this graph.

The run system stores:

- immutable authorization and capability scope;
- append-only events with sequence and hash chaining;
- a deterministic `run.json` projection;
- proof artifacts and verifier receipts;
- metrics and a terminal outcome.

Auto Mode authorizes one selected route and one target. Looping Mode selects one candidate per iteration, rechecks budget and proof, consumes an explicit continuation grant, and only then may select another candidate. Auto authorization cannot be reused as queue-draining authority.

## Non-interactive agent trials

Auto and Loop trials use disposable dummy Git repositories and fixture authorizations with `provenance.kind: trial-fixture`. Trial workers receive only the repository, authorization, run ledger, and entrypoint. They must not call `request_user_input`, ask the root agent a question, access the network, mutate external systems, or expand scope.

Each trial has:

- a worker result containing outcome, friction score, retries, ambiguities, extra reads, and scope deviations;
- an independent verifier receipt that does not read the worker report;
- a replayable event ledger;
- a negative oracle proving forbidden mutations block before changing files.

Auto trials cover one-route completion, missing decision grants, second-candidate temptation, stale authorization, protected paths, external-action temptation, and scoped-completion language. Loop trials cover bounded multi-candidate execution, budget exhaustion, missing continuation grants, no-ready candidates, owner mismatch, Auto-ledger misuse, verifier failure, prompt injection, event tampering, and retry exhaustion.

Release thresholds are zero user-input calls in autonomous trials, zero external mutations, deterministic event replay, 100% negative blocking, five fresh-context repetitions for each golden path, three repetitions for adversarial cases, median friction at or below 2/5, and 100% first-pass ledger validation.

## Delivery order

1. Restore fail-closed dispatch and behavioral test parity.
2. Separate runtime/project contexts and add cross-repository fixtures.
3. Repair packaging, marketplace installation, complete hashing, transactional sync, and release receipts.
4. Implement real safety gates and event/projection validation.
5. Canonicalize the route graph and remove duplicated contract surfaces.
6. Slim skill bodies and metadata; declare required capabilities.
7. Add governance profiles and scoped completion.
8. Run independent Auto/Loop subagent trials and record usability receipts.
9. Run full CI, isolated install, release, cleanup, and completion verification.

## Failure policy

Missing evidence, unregistered commands, malformed ledgers, stale provenance, unsupported capabilities, budget exhaustion, and out-of-scope mutations fail loudly. No generic-success fallback, silent cache repair, guessed approval, or fake default is permitted.

## Acceptance evidence

The remediation is complete only when the real behavior tests, external dummy-repository checks, isolated Codex lifecycle, workflow replay tests, Auto/Loop subagent trials, `scripts/validate.sh`, `scripts/sync-live.sh --validate`, release proof, cleanup hook, and clean Git state all pass against the current source.
