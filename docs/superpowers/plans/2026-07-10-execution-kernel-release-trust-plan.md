# Execution Kernel And Release Trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fail-open workflow and release checks with repository-bound evidence envelopes, read-only collectors, fail-closed gate validators, and current hash-bound receipts while preserving the existing public shell launchers.

**Architecture:** The public launcher catalog remains stable. Launchers delegate through a focused `commands.gates` adapter into a canonical evidence schema, read-only collectors, one validator module per gate, and a receipt serializer; every validator independently corroborates the envelope against the active repository before returning a disposition. Release preparation consumes a current `publish_ready` receipt, and mutation commands consume exact passing receipts instead of trusting bare success booleans.

**Tech Stack:** Python 3 standard library, existing Bash launcher adapter, JSON evidence envelopes and receipts, Git CLI, GitHub CLI JSON observations where available, `unittest`, temporary Git repository fixtures, existing runtime-package and installed-plugin validation scripts.

## Global Constraints

- Preserve every existing public shell launcher path and machine-readable JSON/exit-code convention.
- Missing, malformed, stale, forged, incomplete, cross-repository, or cross-candidate evidence exits nonzero.
- Collectors are read-only and never decide whether a gate passes.
- Validators never collect missing evidence, rewrite evidence, or infer an empty evidence set.
- Paths resolve inside the bound repository after canonical symlink resolution.
- Hashes use SHA-256 over deterministic UTF-8 canonical JSON with sorted keys and compact separators.
- Every digest crosses an interface as a `HashRef` string encoded exactly as `sha256:<64 lowercase hexadecimal characters>`; raw 64-character digests are invalid at contract boundaries.
- The kernel canonical serializer and `HashRef` type are shared infrastructure for lifecycle authorization, artifact identity, workspace receipts, evidence payloads, envelopes, and gate receipts. Companion lifecycle and workspace plans must import this contract rather than define another serializer or hash format.
- Unknown schema versions, gate names, evidence kinds, collector IDs, or collector versions fail closed.
- Legacy receipt shapes return `legacy_evidence_unsupported`; they never receive a compatibility pass.
- Provider outages and unreadable state are blockers, not successful observations.
- No mutation may consume a receipt whose repository, run, candidate, authorization, source hashes, target state, or head commit no longer matches.
- Workspace providers register versioned workspace receipts as kernel evidence. Gates that require isolation consume the registered receipt and its provider-specific extension validator while retaining the common repository, run, candidate, authorization, and target bindings.
- Every deployment follows this order without exception: run source validation, commit every intended source/index/receipt-template change, run live sync, install or refresh the plugin, then verify the installed version. No sync, install, or version proof may precede the source commit it claims to deploy.
- Use `superpowers:test-driven-development` for every behavior change and `superpowers:systematic-debugging` for every reproduced failure.
- Use `superpowers:verification-before-completion` before any checkpoint or final completion claim.

---

## Source Evidence

- Approved source: `docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md`.
- Umbrella audit: `docs/superpowers/specs/2026-07-10-autonomous-workflow-and-codex-worktree-audit-findings.md`.
- Reproduced fail-open handlers: `command_validate_pr_ready`, `command_premerge`, `command_closeout`, and `command_validate_terminal_closeout` in `scripts/lib/superpowers_project_cli.py`.
- Reproduced unbound mutation input: `command_apply_local_branch_closeout` accepts any object with `ok: true` as premerge proof.
- Release path: `scripts/lib/commands/distribution.py::command_prepare_release` derives `publish_ready` inside the command instead of consuming a gate receipt.
- Existing positive-only coverage: `tests/test_local_merge_contract.py`, launcher scenario scripts, and release evidence tests do not reject cross-repository, cross-candidate, stale-head, or tampered-envelope inputs.

## Test Complete And Metrics

Test complete requires all of the following:

- The four current no-argument lifecycle launchers exit nonzero with `error.code == "evidence_missing"`.
- Every supported evidence kind round-trips through canonical serialization with a stable SHA-256 hash.
- Schema tests reject duplicate JSON keys, unknown trust-sensitive fields, unsupported versions, invalid hashes, path traversal, and symlink escape.
- Every gate rejects missing envelope, empty evidence, wrong repository, wrong run, wrong candidate, wrong authorization, stale source artifact, stale commit, changed branch, changed PR head, tampered prior-event hash, incomplete command result, forged success boolean, and unsupported collector version with the expected stable error code.
- A temporary repository fixture completes `pr_ready -> premerge -> merge_decision -> closeout`, and independent Git inspection agrees with every receipt identity and state hash.
- Mutation tests remove or invert one required rule per gate and demonstrate that the gate suite fails.
- An installed-plugin trial proves one missing-evidence failure and one valid fixture pass through the public launchers, with observed tool calls, external mutations, and receipt identities.
- `python3 -m unittest discover -s tests -p 'test_*.py'`, focused shell scenarios, `./scripts/validate.sh`, runtime-package validation, cleanup, and clean Git closeout pass with zero failures.

Metrics are exact command exit codes, stable error codes, rule-result counts, expected versus actual receipt hashes, fixture Git identities, observed provider identifiers, mutation-survival count of zero, and full-suite failure count of zero.

## Outcome Proof

**Intent:** Make autonomous implementation, integration, closeout, and release decisions depend on evidence that is bound to current repository and provider reality.
**Current Behavior:** Multiple lifecycle launchers return success without evidence, terminal closeout trusts boolean fields, local merge accepts an unbound premerge success object, and release readiness is assembled inside one distribution handler.
**Expected Outcome:** Every safety-critical launcher fails closed, every passing decision emits a rule-level hash-bound receipt, every mutation consumes the exact current receipt, and release publication consumes a current `publish_ready` receipt derived from independently validated evidence.
**Target Output:** Focused trust-kernel modules, preserved public launchers, adversarial and positive behavioral tests, an acceptance matrix, installed-plugin traces, release proof, a committed milestone receipt template/index, and a current ephemeral publish-ready receipt generated against the final source commit and deployed installation.
**Owner:** `scripts/lib/evidence_schema.py` owns envelope parsing and canonical identity; gate modules own required rules; `scripts/lib/gate_receipts.py` owns receipt serialization; public route skills own when their launchers are invoked.
**Interface:** Shell launchers accept exactly one `EvidenceEnvelopeJson` or `EvidenceEnvelopePath`; gate functions accept a parsed `EvidenceEnvelope` plus an explicit repository root and return a `GateReceipt` or raise `EvidenceError` with a stable code. Every digest is a `HashRef` encoded as `sha256:<64 lowercase hexadecimal characters>`, and workspace providers register `workspace_receipt` evidence through the kernel evidence-kind registry.
**Cutover:** Add strict schema and gate tests first, route legacy launchers through focused modules second, require exact receipts at mutation boundaries third, commit all source/index/receipt-template changes, deploy that commit through sync/install/version verification, then generate and consume the current ephemeral `publish_ready` receipt without another source edit.
**Replaced Path:** No-argument success handlers, self-validating collection handlers, bare `ok: true` mutation inputs, and release readiness inferred from disconnected booleans are retired rather than shimmed.
**Evidence:** Negative-fixture JSON receipts, temporary-repository traces, rule mutation results, public-launcher results, installed-plugin observations, independent Git/provider inspection, runtime-package proof, the committed milestone receipt template/index, and the current ephemeral publish-ready receipt under the task-owned run directory.
**Acceptance Proof:** From the final clean source commit, the acceptance-matrix test proves every specified rejection code, the positive lifecycle test proves receipt and Git identity agreement, sync/install/version verify that exact commit, and a newly generated ephemeral publish-ready receipt corroborates the current source and installed state.
**Stop Criteria:** Stop if a gate can pass without an envelope, a validator mutates or manufactures evidence, a receipt can be replayed after state changes, provider unavailability passes, a mutation accepts an unbound boolean, or the installed snapshot differs from source behavior.
**Avoid:** Do not change Auto or Looping routing, implement Codex worktree selection, redesign the workflow graph, add a second public launcher surface, certify legacy receipts, or replace GitHub/Git/Codex with an internal service.
**Risk:** Strict identity binding can reveal hidden reliance on permissive ledgers and nondeterministic provider output; narrow evidence kinds, canonical identifiers, explicit migration failures, and adversarial tests contain that risk.

## Implementation Boundaries

**Files To Create:** `scripts/lib/evidence_schema.py`, `scripts/lib/evidence_collectors.py`, `scripts/lib/gate_receipts.py`, `scripts/lib/gate_common.py`, `scripts/lib/gate_pr_ready.py`, `scripts/lib/gate_premerge.py`, `scripts/lib/gate_merge_decision.py`, `scripts/lib/gate_closeout.py`, `scripts/lib/gate_publish_ready.py`, `scripts/lib/commands/gates.py`, `tests/test_evidence_schema.py`, `tests/test_evidence_collectors.py`, `tests/test_gate_pr_ready.py`, `tests/test_gate_premerge.py`, `tests/test_gate_merge_decision.py`, `tests/test_gate_closeout.py`, `tests/test_gate_publish_ready.py`, `tests/test_execution_kernel_lifecycle.py`, `tests/test_execution_kernel_mutations.py`, `tests/fixtures/execution-kernel/acceptance-matrix.json`, and `docs/superpowers/milestones/M1-execution-kernel-release-trust-receipt.md`.
**Files To Modify:** `scripts/lib/commands/__init__.py`, `scripts/lib/commands/distribution.py`, `scripts/lib/superpowers_project_cli.py`, `scripts/lib/command_catalog.py`, `tests/test_local_merge_contract.py`, `tests/test_release_evidence.py`, `tests/test_runtime_package.py`, `skills/resolve-issue/SKILL.md`, `skills/resolve-issue/scripts/test-scenarios.sh`, `skills/merge-changes/SKILL.md`, `skills/merge-changes/scripts/test-scenarios.sh`, `scripts/test-prepare-release.sh`, `scripts/run-agent-usability-trials.sh`, `.codex-plugin/runtime-package.yml`, and `scripts/validate.sh`.
**Files To Avoid:** Auto/Looping lifecycle contracts, workspace-isolation implementation, workflow graph normalization owned by companion specs, deployed live plugin copies, plugin cache contents, unrelated historical specs/plans, and provider state outside test-owned fixtures.
**Source Of Truth:** The approved spec owns behavior; `canonical_json` and `HashRef` own cross-plan identity encoding; `EvidenceEnvelope` owns input identity; the evidence-kind registry owns workspace and lifecycle evidence extensions; `GATE_REQUIREMENTS` in each gate module owns required evidence; `GateReceipt` owns decision output; the acceptance matrix owns required negative cases.
**Read Path:** Collectors read repository paths, Git state, command results, GitHub JSON, source artifacts, authorization events, review data, cleanup state, package provenance, and installation receipts without mutation.
**Write Path:** Collection launchers may write envelopes beneath an explicit repo-owned output directory; validators write nothing; workflow owners may persist returned receipts as append-only run artifacts; implementation edits remain in this source repository.
**Integration Points:** Public shell launchers, `command_catalog.py`, `commands.load_handlers`, resolve-issue PR readiness, merge-changes premerge/merge/closeout, lifecycle authorization receipts, registered Codex workspace receipts, local branch merge, release preparation, runtime packaging, agent usability trials, and `scripts/validate.sh`.
**Migration Or Cutover:** Legacy input is detected and rejected with `legacy_evidence_unsupported`; callers migrate by collecting a version-1 envelope and passing its resulting receipt hash to the next mutation or gate.
**Replaced Path Handling:** Delete fail-open handler bodies only after public dispatch tests target the focused adapters; do not retain fallback success branches or translate legacy booleans into version-1 receipts.
**Acceptance Proof Gate:** A task is checkpoint-ready only after its focused RED/GREEN/refactor cycle and neighboring tests pass; program closeout additionally requires the acceptance matrix, lifecycle trace, mutation suite, installed-plugin trace, full validation, cleanup, and clean Git proof.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Public command surface | Approved spec compatibility requirement | Preserve shell launcher paths and dispatch names. | Skills and users gain strict behavior without learning a replacement CLI. | No | Runtime owner |
| Internal decomposition | Reproduced broad-handler coupling | Add focused schema, collector, gate, receipt, and adapter modules. | Trust logic becomes independently testable and reviewable. | No | Validation owner |
| Missing evidence | Approved fail-closed requirement | Return `evidence_missing` and exit nonzero. | No gate can treat absence as an empty passing set. | No | Validation owner |
| JSON parsing | Duplicate-key and ambiguous-field threat model | Parse with duplicate-key rejection and strict top-level/nested key sets. | Canonical hashing cannot hide conflicting values. | No | Schema owner |
| Receipt currency | Cross-run and stale-state threat model | Bind repository, run, candidate, authorization, artifacts, target, state observations, and prior event. | Replays across work or after state change fail. | No | Runtime owner |
| Provider signatures | Unresolved spec decision | Use authenticated stable provider IDs, raw response hashes, and current corroboration for version 1; reserve a schema field for a future signature profile without accepting it now. | First implementation stays dependency-free while refusing unverifiable provider claims. | Yes | Provider integration owner |
| Retryable checks | Unresolved GitHub conclusion policy | Treat `queued`, `pending`, `in_progress`, `requested`, and provider-unavailable states as non-passing blockers; record the exact conclusion for the caller to retry. | No ambiguous check result authorizes merge. | No | Merge owner |
| Receipt lifetime | Unresolved time-to-live policy | Version 1 has no wall-clock-only pass window; state-sensitive evidence is current only while every bound identity and observed hash still matches. | Currency depends on reality rather than an arbitrary duration. | No | Runtime owner |
| Shared hash representation | Cross-plan lifecycle and workspace review | Encode every digest as `sha256:<64 lowercase hexadecimal characters>` and compute it with the kernel canonical serializer. | Lifecycle and workspace receipts cannot drift into incompatible hash encodings. | No | Schema owner |
| Workspace evidence | Codex-native workspace isolation contract | Register `workspace_receipt` as a versioned kernel evidence kind and evaluate provider-specific fields through gate extensions. | PR-ready, closeout, and other isolation-sensitive gates can prove workspace ownership without duplicating kernel identity rules. | No | Workspace integration owner |
| Legacy evidence | Approved migration rule | Reject with `legacy_evidence_unsupported`. | Compatibility cannot restore the defect. | No | Migration owner |
| Release decision | Approved release trust design | `command_prepare_release` consumes a current `publish_ready` receipt. | Publication derives from validated proof rather than local booleans. | No | Release owner |
| Deployment sequencing | Required post-revision loop and cross-plan review | Validate, commit all source/index/template changes, sync, install, verify version, then issue final current-state acceptance proof. | Deployment evidence always identifies an immutable source commit and cannot be invalidated by a later receipt edit. | No | Release owner |

## Task 1: Canonical Evidence Schema And Receipt Identity

**Use Cases:**

- A validator receives a version-1 envelope and derives the same hash across repeated parses and supported platforms.
- A forged, duplicate-key, unknown-version, path-traversal, symlink-escape, or hash-mismatched envelope fails with one stable error code before gate rules run.
- A later gate verifies the exact prior receipt instead of accepting an unbound success boolean, providing the first acceptance-proof foundation for cutover from legacy ledgers.

**Files:**

- Create: `scripts/lib/evidence_schema.py`
- Create: `scripts/lib/gate_receipts.py`
- Create: `scripts/lib/gate_common.py`
- Create: `tests/test_evidence_schema.py`
- Modify: `.codex-plugin/runtime-package.yml`
- Test: `tests/test_evidence_schema.py`

**Interfaces:**

- Consumes: UTF-8 JSON text or a parsed mapping, canonical repository root, registered gate/evidence/collector constants.
- Produces: `EvidenceError(code: str, message: str, rule: str | None)`, `HashRef`, `EvidenceItem`, `EvidenceEnvelope`, `RuleResult`, `GateReceipt`, `EvidenceKindRegistration`, `parse_envelope_json(text: str, repo_root: Path) -> EvidenceEnvelope`, `canonical_json(value: object) -> bytes`, `hash_ref(value: object) -> HashRef`, `register_evidence_kind(registration: EvidenceKindRegistration) -> None`, `build_receipt(envelope: EvidenceEnvelope, validator_id: str, observations: dict[str, object], rules: list[RuleResult]) -> GateReceipt`, and `verify_receipt(receipt: GateReceipt, envelope: EvidenceEnvelope, expected_gate: str) -> None`.

- [ ] **Step 1: Write failing canonicalization and rejection tests**

```python
class EvidenceSchemaTests(unittest.TestCase):
    def test_hash_is_stable_and_duplicate_keys_fail(self):
        envelope = make_envelope(self.repo, gate="pr_ready")
        first = parse_envelope_json(json.dumps(envelope), self.repo)
        second = parse_envelope_json(json.dumps(envelope, indent=2), self.repo)
        self.assertEqual(first.envelope_hash, second.envelope_hash)
        with self.assertRaisesRegex(EvidenceError, "duplicate_key"):
            parse_envelope_json('{"schema_version":1,"schema_version":1}', self.repo)

    def test_paths_must_resolve_inside_repository(self):
        envelope = make_envelope(self.repo, plan_path="../outside.md")
        with self.assertRaisesRegex(EvidenceError, "repository_mismatch"):
            parse_envelope_json(json.dumps(envelope), self.repo)
```

- [ ] **Step 2: Run the RED test and confirm the missing module is the failure**

Run: `python3 -m unittest tests.test_evidence_schema -v`

Expected: FAIL with `ModuleNotFoundError: No module named 'scripts.lib.evidence_schema'`.

- [ ] **Step 3: Implement the strict schema and canonical hash core**

```python
SUPPORTED_GATES = frozenset({"pr_ready", "premerge", "merge_decision", "closeout", "publish_ready"})

class EvidenceError(ValueError):
    def __init__(self, code: str, message: str, rule: str | None = None):
        super().__init__(f"{code}: {message}")
        self.code, self.message, self.rule = code, message, rule

def canonical_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")

HashRef = NewType("HashRef", str)

def hash_ref(value: object) -> HashRef:
    digest = hashlib.sha256(canonical_json(value)).hexdigest()
    return HashRef(f"sha256:{digest}")

def _strict_pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    output: dict[str, object] = {}
    for key, value in pairs:
        if key in output:
            raise EvidenceError("schema_invalid", f"duplicate_key:{key}")
        output[key] = value
    return output
```

Implement frozen dataclasses for the schema fields from the source spec, exact key validation, `HashRef` validation against `^sha256:[0-9a-f]{64}$`, repository-root and `git_common_dir` canonicalization, symlink-safe source paths, registered evidence/collector validation, payload-hash checks, envelope-hash verification, receipt canonicalization, per-rule results, and receipt-hash verification. Register built-in lifecycle kinds through the same evidence-kind registry used by workspace providers; reject duplicate or unregistered kind/version pairs.

- [ ] **Step 4: Run GREEN schema tests**

Run: `python3 -m unittest tests.test_evidence_schema -v`

Expected: PASS for stable round-trip, duplicate keys, unsupported values, traversal, symlink escape, payload tampering, envelope tampering, and receipt tampering.

Also assert that raw 64-character digests fail, `HashRef` values round-trip unchanged, lifecycle authorization uses `hash_ref(canonical_authorization)`, and a fixture workspace provider can register `workspace_receipt@1` without replacing the common serializer.

- [ ] **Step 5: Refactor shared rule execution without changing behavior**

Move reusable repository/run/candidate/authorization/source/target checks into:

```python
def evaluate_rules(checks: list[tuple[str, Callable[[], tuple[bool, str]]]]) -> list[RuleResult]:
    return [RuleResult(rule_id=name, ok=ok, reason=reason) for name, check in checks for ok, reason in [check()]]
```

Run: `python3 -m unittest tests.test_evidence_schema -v && python3 -m unittest tests.test_runtime_package -v`

Expected: both suites PASS and `validate_runtime_reads` reports no missing runtime file.

- [ ] **Step 6: Checkpoint commit**

```bash
git add scripts/lib/evidence_schema.py scripts/lib/gate_receipts.py scripts/lib/gate_common.py tests/test_evidence_schema.py .codex-plugin/runtime-package.yml
git commit -m "feat: add canonical execution evidence schema"
```

## Task 2: Read-Only Collectors And Envelope Construction

**Use Cases:**

- A route owner collects Git, artifact, command, review, provider, authorization, and cleanup observations without changing repository or provider state.
- A command failure or unavailable provider becomes structured evidence with exact exit status and output hashes, never a passing claim.
- Existing collection launchers cut over from self-reported `ok: true` ledgers to version-1 envelopes whose observed read-only behavior is visible in acceptance evidence.
- A Codex workspace adapter registers its provider receipt as `workspace_receipt@1`; collection preserves its provider extension while binding it to the same repository, run, candidate, authorization, and target as lifecycle evidence.

**Files:**

- Create: `scripts/lib/evidence_collectors.py`
- Create: `scripts/lib/commands/gates.py`
- Create: `tests/test_evidence_collectors.py`
- Modify: `scripts/lib/commands/__init__.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `.codex-plugin/runtime-package.yml`
- Modify: `tests/test_command_registry.py`
- Test: `tests/test_evidence_collectors.py`
- Test: `tests/test_command_registry.py`

**Interfaces:**

- Consumes: `CollectionRequest(gate, repository_root, workflow, source, target, commands, provider_inputs, prior_event_hash)` and explicit output path.
- Produces: `CollectorResult(kind: str, collector: str, observed_at: str, payload: dict[str, object])`, `collect_git_state(root: Path)`, `collect_artifact_hashes(root: Path, paths: Sequence[str])`, `collect_command_result(root: Path, argv: Sequence[str])`, `collect_review_result(review: Mapping[str, object])`, `collect_github_state(raw_json: Mapping[str, object])`, `collect_authorization_event(event: Mapping[str, object])`, `collect_cleanup_state(root: Path)`, `collect_registered_evidence(kind: str, provider_receipt: Mapping[str, object])`, and `build_evidence_envelope(request: CollectionRequest) -> dict[str, object]`; `commands.gates` exports existing collector handler names.

- [ ] **Step 1: Write failing read-only and failure-observation tests**

```python
def test_collectors_do_not_change_git_or_files(self):
    before = snapshot_repo(self.repo)
    result = collect_git_state(self.repo)
    self.assertEqual(before, snapshot_repo(self.repo))
    self.assertEqual(0, result.payload["status_exit_code"])

def test_failed_command_is_observed_not_promoted(self):
    result = collect_command_result(self.repo, ["git", "rev-parse", "missing-ref"])
    self.assertNotEqual(0, result.payload["exit_code"])
    self.assertIn("stdout_hash", result.payload)
    self.assertNotIn("ok", result.payload)
```

- [ ] **Step 2: Run RED collector tests**

Run: `python3 -m unittest tests.test_evidence_collectors -v`

Expected: FAIL because `scripts.lib.evidence_collectors` does not exist.

- [ ] **Step 3: Implement bounded collectors and envelope builder**

```python
COLLECTORS = {
    "git_state": ("git-state@1", collect_git_state),
    "artifact_hashes": ("artifact-hashes@1", collect_artifact_hashes),
    "command_result": ("command-result@1", collect_command_result),
    "review_result": ("review-result@1", collect_review_result),
    "github_state": ("github-state@1", collect_github_state),
    "authorization_event": ("authorization-event@1", collect_authorization_event),
    "cleanup_state": ("cleanup-state@1", collect_cleanup_state),
    "workspace_receipt": ("registered-evidence@1", collect_registered_evidence),
}
```

Use `subprocess.run(..., stdin=DEVNULL, timeout=<bounded seconds>, check=False)`, hash full stdout/stderr while retaining only documented structured fields, normalize provider IDs, forbid collector output paths outside the repository, and compare pre/post Git status and tracked-file hashes in tests. `collect_registered_evidence` must resolve a registered kind/version, run its extension schema validator, preserve provider-owned fields, and calculate every identity through the shared `HashRef` serializer.

- [ ] **Step 4: Route public collection handlers through the builder**

Move `command_collect_pr_ready`, `command_collect_premerge`, and `command_collect_closeout` to `scripts/lib/commands/gates.py`. Require a complete `CollectionRequestJson` or `CollectionRequestPath`; emit `evidence_missing` when neither is supplied; write an envelope only when `OutputPath` is explicit.

- [ ] **Step 5: Run GREEN collector and dispatch tests**

Run: `python3 -m unittest tests.test_evidence_collectors tests.test_command_registry tests.test_command_surface -v`

Expected: PASS; all public paths retain their existing handler names, and no-argument collectors exit nonzero with structured missing-input output.

- [ ] **Step 6: Refactor collector process execution**

Extract one `_observe_process(root, argv, timeout) -> dict[str, object]` helper, then run:

Run: `python3 -m unittest tests.test_evidence_collectors tests.test_command_registry tests.test_command_surface -v`

Expected: PASS with byte-for-byte stable payload hashes for identical fixture output.

- [ ] **Step 7: Checkpoint commit**

```bash
git add scripts/lib/evidence_collectors.py scripts/lib/commands/gates.py scripts/lib/commands/__init__.py scripts/lib/superpowers_project_cli.py .codex-plugin/runtime-package.yml tests/test_evidence_collectors.py tests/test_command_registry.py
git commit -m "feat: collect repository-bound workflow evidence"
```

## Task 3: PR-Ready And Terminal Closeout Gates

**Use Cases:**

- `validate-pr-ready.sh` without evidence fails with `evidence_missing` instead of claiming PR readiness.
- A valid candidate proves implementation verification, review disposition, source-plan conformance, cleanup, and target identity; stale or forged evidence fails at the exact rule.
- Resolve terminal closeout cuts over from `result.ok` to a current `pr_ready` receipt plus an explicit terminal decision bound to the same run and candidate.
- A route that declares isolated execution must supply a registered workspace receipt; PR-ready and closeout run its provider extension and reject ownership, workspace, repository, or cleanup mismatches.

**Files:**

- Create: `scripts/lib/gate_pr_ready.py`
- Create: `scripts/lib/gate_closeout.py`
- Create: `tests/test_gate_pr_ready.py`
- Create: `tests/test_gate_closeout.py`
- Modify: `scripts/lib/commands/gates.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`
- Modify: `.codex-plugin/runtime-package.yml`
- Test: `tests/test_gate_pr_ready.py`
- Test: `tests/test_gate_closeout.py`

**Interfaces:**

- Consumes: `validate_pr_ready(envelope: EvidenceEnvelope, repo_root: Path) -> GateReceipt`; `validate_closeout(envelope: EvidenceEnvelope, repo_root: Path, merge_decision_receipt: GateReceipt) -> GateReceipt`; handler args `EvidenceEnvelopeJson|Path` and `PriorReceiptJson|Path`.
- Produces: `pr-ready-validator@1` and `closeout-validator@1` receipts with rule IDs `repository_identity`, `event_chain`, `authorization_binding`, `source_artifacts`, `target_identity`, `implementation_verification`, `review_disposition`, `plan_conformance`, `workspace_receipt`, `cleanup_state`, `integration_proof`, `completion_state`, and `workspace_disposition`.

- [ ] **Step 1: Write failing no-evidence and adversarial gate tests**

```python
def test_public_pr_ready_launcher_fails_without_evidence(self):
    result = run_launcher("skills/resolve-issue/scripts/validate-pr-ready.sh")
    self.assertNotEqual(0, result.returncode)
    self.assertEqual("evidence_missing", json.loads(result.stdout)["error"]["code"])

def test_pr_ready_rejects_forged_success_and_stale_source(self):
    envelope = valid_pr_ready_envelope(self.repo)
    envelope["evidence"].append(forged_boolean_evidence())
    with self.assertRaisesRegex(EvidenceError, "collector_untrusted"):
        validate_pr_ready(parse(envelope), self.repo)
    self.plan.write_text("changed after collection")
    with self.assertRaisesRegex(EvidenceError, "artifact_hash_mismatch"):
        validate_pr_ready(parse(valid_pr_ready_envelope(self.repo)), self.repo)
```

Add table-driven cases for wrong repository, run, candidate, authorization, branch, commit, unsupported collector, failed verification command, unresolved blocking review, missing conformance result, dirty task artifacts, and cross-candidate prior receipt.

Add workspace-extension cases for an isolation-required envelope with no workspace receipt, an unregistered workspace provider/version, wrong workspace ID, wrong provider task/thread ID, wrong repository root, wrong candidate, stale provider observation, and cleanup attempted by a non-owner. A valid registered provider fixture must pass without copying provider-specific fields into the kernel core schema.

- [ ] **Step 2: Run RED gate tests**

Run: `python3 -m unittest tests.test_gate_pr_ready tests.test_gate_closeout -v`

Expected: FAIL because gate modules and strict adapter handlers are missing.

- [ ] **Step 3: Implement minimal PR-ready and closeout rules**

```python
GATE_REQUIREMENTS = {
    "pr_ready": frozenset({"git_state", "artifact_hashes", "command_result", "review_result", "authorization_event", "cleanup_state"}),
    "closeout": frozenset({"git_state", "artifact_hashes", "command_result", "authorization_event", "cleanup_state", "integration_state"}),
}

def validate_pr_ready(envelope: EvidenceEnvelope, repo_root: Path) -> GateReceipt:
    require_gate(envelope, "pr_ready")
    rules, observations = corroborate_pr_ready(envelope, repo_root)
    require_all_rules(rules)
    return build_receipt(envelope, "pr-ready-validator@1", observations, rules)
```

Read the active plan and spec hashes, current `git_common_dir`, branch/detached state, HEAD, status, and cleanup paths independently. Require explicit nonzero-free command observations and review rule outcomes; never infer missing entries. When `target.isolation_required` is true, extend the gate requirements with `workspace_receipt`, load its registered provider validator, and require common identity plus provider ownership/disposition rules before the gate can pass.

- [ ] **Step 4: Replace fail-open PR-ready and resolve closeout adapters**

Make `command_validate_pr_ready` and `command_validate_resolve_terminal_closeout` load strict envelopes and prior receipts, catch `EvidenceError`, emit `error.code`, `error.rule`, and nonzero status, and remove their legacy success branches.

- [ ] **Step 5: Run GREEN focused and route scenario tests**

Run: `python3 -m unittest tests.test_gate_pr_ready tests.test_gate_closeout -v && ./skills/resolve-issue/scripts/test-scenarios.sh`

Expected: PASS; the scenario output includes an `evidence_missing` negative case, a valid fixture receipt, and no bare success input.

- [ ] **Step 6: Refactor shared repository corroboration**

Move repository/source/target checks shared by the two gates into `gate_common.py`, then run:

Run: `python3 -m unittest tests.test_evidence_schema tests.test_gate_pr_ready tests.test_gate_closeout -v`

Expected: PASS with unchanged rule IDs and receipt hashes.

- [ ] **Step 7: Checkpoint commit**

```bash
git add scripts/lib/gate_pr_ready.py scripts/lib/gate_closeout.py scripts/lib/gate_common.py scripts/lib/commands/gates.py scripts/lib/superpowers_project_cli.py tests/test_gate_pr_ready.py tests/test_gate_closeout.py skills/resolve-issue/SKILL.md skills/resolve-issue/scripts/test-scenarios.sh .codex-plugin/runtime-package.yml
git commit -m "fix: fail closed at PR-ready and closeout gates"
```

## Task 4: Premerge, Merge Decision, And Receipt-Consuming Integration

**Use Cases:**

- Premerge rejects missing PR identity, pending or failed checks, unresolved blocking review, base/head mismatch, and a changed head after collection.
- Merge decision requires a current premerge receipt and authorization for the selected strategy; no routine boolean or stale receipt can authorize integration.
- Local branch integration cuts over from `{"ok": true}` to an exact `merge_decision` receipt and independently verifies main, source branch, source plan, and head before mutation.

**Files:**

- Create: `scripts/lib/gate_premerge.py`
- Create: `scripts/lib/gate_merge_decision.py`
- Create: `tests/test_gate_premerge.py`
- Create: `tests/test_gate_merge_decision.py`
- Modify: `scripts/lib/commands/gates.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `tests/test_local_merge_contract.py`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Modify: `.codex-plugin/runtime-package.yml`
- Test: `tests/test_gate_premerge.py`
- Test: `tests/test_gate_merge_decision.py`
- Test: `tests/test_local_merge_contract.py`

**Interfaces:**

- Consumes: `validate_premerge(envelope, repo_root, pr_ready_receipt) -> GateReceipt`, `validate_merge_decision(envelope, repo_root, premerge_receipt) -> GateReceipt`, and `command_apply_local_branch_closeout(..., MergeDecisionReceiptJson|Path)`.
- Produces: `premerge-validator@1` rules for PR identity/checks/review/base/head/current state; `merge-decision-validator@1` rules for prior receipt, authorization, strategy, and unchanged target; integration evidence containing consumed receipt hash and resulting commit.

- [ ] **Step 1: Write failing provider and replay tests**

```python
@parameterized.expand(["queued", "pending", "in_progress", "failure", "cancelled", "timed_out", None])
def test_premerge_rejects_nonpassing_check_conclusion(self, conclusion):
    envelope = premerge_envelope(self.repo, check_conclusion=conclusion)
    with self.assertRaisesRegex(EvidenceError, "required_rule_failed"):
        validate_premerge(parse(envelope), self.repo)

def test_local_merge_rejects_bare_success_object(self):
    with self.assertRaisesRegex(EvidenceError, "legacy_evidence_unsupported"):
        apply_local_merge(self.repo, merge_decision_receipt={"ok": True})
```

Use standard `unittest.subTest` if the repository does not already depend on `parameterized`. Add changed-PR-head, cross-repository receipt, cross-candidate receipt, authorization mismatch, unsupported strategy, changed local branch, and dirty-main cases.

- [ ] **Step 2: Run RED premerge and integration tests**

Run: `python3 -m unittest tests.test_gate_premerge tests.test_gate_merge_decision tests.test_local_merge_contract -v`

Expected: FAIL because focused gates do not exist and local merge still accepts a bare boolean result.

- [ ] **Step 3: Implement current provider and Git corroboration**

```python
PASSING_CHECK_CONCLUSIONS = frozenset({"success", "neutral", "skipped"})
RETRYABLE_BLOCKERS = frozenset({"queued", "pending", "in_progress", "requested"})

def validate_merge_decision(envelope, repo_root, premerge_receipt):
    verify_receipt(premerge_receipt, envelope, "premerge")
    rules, observations = corroborate_merge_authorization(envelope, repo_root)
    require_all_rules(rules)
    return build_receipt(envelope, "merge-decision-validator@1", observations, rules)
```

Require authenticated PR ID, repository ID, base ref/SHA, head ref/SHA, required-check names/conclusions, review disposition, authorization hash, supported strategy, and a fresh provider observation hash. Provider-unavailable emits `provider_state_unavailable`.

- [ ] **Step 4: Cut public premerge and merge-decision launchers over**

Move `command_premerge` and `command_validate_merge_decision` into `commands.gates`. Require strict input and prior receipt paths; remove no-argument success and selected-action-only approval.

- [ ] **Step 5: Require the merge-decision receipt at local mutation**

Replace `PremergeResultJson` and `MergeDecisionJson` consumption with `MergeDecisionReceiptJson|Path`. Before `git merge --ff-only`, verify receipt hash, gate, repository identity, candidate, authorization, main HEAD, source head, source plan hash, and branch. Emit `consumed_receipt_hash` in dry-run and real integration output.

- [ ] **Step 6: Run GREEN focused and route tests**

Run: `python3 -m unittest tests.test_gate_premerge tests.test_gate_merge_decision tests.test_local_merge_contract -v && ./skills/merge-changes/scripts/test-scenarios.sh`

Expected: PASS; pending and unavailable providers block, stale receipts block, valid PR/local fixtures pass, and local dry-run records the exact consumed receipt hash without remote publication.

- [ ] **Step 7: Refactor provider normalization**

Extract normalized GitHub state parsing into one function used by collection and validation, while validation still performs a fresh observation comparison.

Run: `python3 -m unittest tests.test_evidence_collectors tests.test_gate_premerge tests.test_gate_merge_decision tests.test_local_merge_contract -v`

Expected: PASS with the same provider identity and rule results.

- [ ] **Step 8: Checkpoint commit**

```bash
git add scripts/lib/gate_premerge.py scripts/lib/gate_merge_decision.py scripts/lib/commands/gates.py scripts/lib/superpowers_project_cli.py tests/test_gate_premerge.py tests/test_gate_merge_decision.py tests/test_local_merge_contract.py skills/merge-changes/SKILL.md skills/merge-changes/scripts/test-scenarios.sh .codex-plugin/runtime-package.yml
git commit -m "fix: bind merge decisions to current premerge proof"
```

## Task 5: Publish-Ready Gate And Release Receipt Consumption

**Use Cases:**

- Release preparation rejects an absent, stale, wrong-version, wrong-package, wrong-commit, or incomplete `publish_ready` receipt.
- A docs-only historical artifact cannot masquerade as runtime package proof, and a runtime change requires current validation, sync, installation, provenance, trial, cleanup, and version evidence.
- The release command cuts over from deriving readiness inside one broad handler to reporting the exact validated receipt it consumed.

**Files:**

- Create: `scripts/lib/gate_publish_ready.py`
- Create: `tests/test_gate_publish_ready.py`
- Modify: `scripts/lib/commands/gates.py`
- Modify: `scripts/lib/commands/distribution.py`
- Modify: `scripts/lib/release_evidence.py`
- Modify: `tests/test_release_evidence.py`
- Modify: `scripts/test-prepare-release.sh`
- Modify: `.codex-plugin/runtime-package.yml`
- Test: `tests/test_gate_publish_ready.py`
- Test: `tests/test_release_evidence.py`
- Test: `scripts/test-prepare-release.sh`

**Interfaces:**

- Consumes: `validate_publish_ready(envelope: EvidenceEnvelope, repo_root: Path) -> GateReceipt`; `command_prepare_release(..., PublishReadyReceiptJson|Path)`.
- Produces: `publish-ready-validator@1` receipt with clean-source, package, version, provenance, validation, sync, installation, agent-trial, cleanup, and revision-classification rule outcomes; release output includes `publish_ready_receipt_hash`.

- [ ] **Step 1: Write failing release trust tests**

```python
def test_prepare_release_requires_current_publish_ready_receipt(self):
    result = run_prepare_release(self.repo, receipt=None)
    self.assertNotEqual(0, result.returncode)
    self.assertEqual("evidence_missing", result.json["error"]["code"])

def test_publish_ready_rejects_stale_package_hash(self):
    envelope = publish_ready_envelope(self.repo)
    (self.repo / "skills" / "merge-changes" / "SKILL.md").write_text("changed")
    with self.assertRaisesRegex(EvidenceError, "artifact_hash_mismatch"):
        validate_publish_ready(parse(envelope), self.repo)
```

Add missing install proof, wrong manifest version, stale commit, dirty status, invalid provenance, failed validation, failed sync, hardcoded agent counters, and incomplete cleanup cases.

- [ ] **Step 2: Run RED release tests**

Run: `python3 -m unittest tests.test_gate_publish_ready tests.test_release_evidence -v && ./scripts/test-prepare-release.sh`

Expected: FAIL because no publish-ready gate exists and prepare-release does not consume its receipt.

- [ ] **Step 3: Implement publish-ready corroboration**

```python
PUBLISH_REQUIRED_KINDS = frozenset({
    "git_state", "artifact_hashes", "command_result", "package_provenance",
    "installation_state", "agent_trial", "cleanup_state", "authorization_event",
})

def validate_publish_ready(envelope, repo_root):
    rules, observations = corroborate_release_state(envelope, repo_root)
    require_all_rules(rules)
    return build_receipt(envelope, "publish-ready-validator@1", observations, rules)
```

Compare current HEAD, manifest version, changelog version, runtime contract hash, provenance, source/live/install identities, observed trial calls/mutations/receipts, revision classification, cleanup status, and required post-revision gates.

- [ ] **Step 4: Make release preparation consume the gate receipt**

Keep descriptive release fields, but remove independent `publish_ready` inference. Verify the receipt against current state and set:

```python
receipt["publish_ready"] = True
receipt["publish_ready_receipt_hash"] = publish_receipt.receipt_hash
```

Any missing or invalid receipt emits the kernel error and exits nonzero. `-CheckOnly` may still inspect manifest/changelog without claiming publish readiness.

- [ ] **Step 5: Run GREEN release tests**

Run: `python3 -m unittest tests.test_gate_publish_ready tests.test_release_evidence -v && ./scripts/test-prepare-release.sh`

Expected: PASS; every invalid fixture returns its expected error code, check-only never claims `publish_ready`, and the valid fixture records the consumed receipt hash.

- [ ] **Step 6: Refactor legacy release evidence handling**

Keep `validate_release_evidence` only as a parser for historical reporting or migrate its callers to envelope evidence; it must raise `legacy_evidence_unsupported` if supplied where a gate receipt is required.

Run: `rg -n 'publish_ready.*not dirty|release_evidence.*ok|"ok": True' scripts/lib/commands/distribution.py scripts/lib/release_evidence.py`

Expected: no independent publish authorization formula and no bare success acceptance remains.

- [ ] **Step 7: Checkpoint commit**

```bash
git add scripts/lib/gate_publish_ready.py scripts/lib/commands/gates.py scripts/lib/commands/distribution.py scripts/lib/release_evidence.py tests/test_gate_publish_ready.py tests/test_release_evidence.py scripts/test-prepare-release.sh .codex-plugin/runtime-package.yml
git commit -m "fix: derive release readiness from trusted receipts"
```

## Task 6: Adversarial Lifecycle, Mutation, And Installed-Plugin Proof

**Use Cases:**

- The acceptance matrix gives reviewers target-perspective evidence that every documented attack class fails at the intended gate and rule.
- Removing or inverting a required rule causes tests to fail, proving the tests inspect behavior rather than file or field presence.
- The installed plugin cuts over with the source implementation: missing evidence fails, a valid lifecycle passes, and observed tool calls, mutations, and receipt identities replace hardcoded counters.

**Files:**

- Create: `tests/test_execution_kernel_lifecycle.py`
- Create: `tests/test_execution_kernel_mutations.py`
- Create: `tests/fixtures/execution-kernel/acceptance-matrix.json`
- Modify: `scripts/run-agent-usability-trials.sh`
- Modify: `tests/test_agent_usability_receipts.py`
- Modify: `tests/test_auto_loop_trials.py`
- Modify: `tests/test_runtime_package.py`
- Modify: `scripts/validate.sh`
- Test: `tests/test_execution_kernel_lifecycle.py`
- Test: `tests/test_execution_kernel_mutations.py`
- Test: `tests/test_agent_usability_receipts.py`

**Interfaces:**

- Consumes: all gate APIs, public launchers, a test-owned temporary Git repository, test-owned provider JSON, installed plugin root reported by the supported installer, and the acceptance matrix.
- Produces: lifecycle trace entries `{gate, envelope_hash, receipt_hash, repository_id, candidate_id, head, rule_results}`, mutation results `{gate, removed_rule, expected_failure}`, and installed-trial observations `{tool_calls, external_mutations, receipt_identities}`.

- [ ] **Step 1: Write the failing end-to-end lifecycle test**

```python
def test_lifecycle_receipts_match_independent_git_state(self):
    trace = run_fixture_lifecycle(self.repo)
    self.assertEqual(["pr_ready", "premerge", "merge_decision", "closeout"], [item["gate"] for item in trace])
    actual_head = git(self.repo, "rev-parse", "HEAD").stdout.strip()
    self.assertEqual(actual_head, trace[-1]["observations"]["head"])
    for previous, current in zip(trace, trace[1:]):
        self.assertEqual(previous["receipt_hash"], current["prior_receipt_hash"])
```

- [ ] **Step 2: Write acceptance-matrix and rule-mutation tests**

The JSON matrix lists every gate, fixture mutation, expected `error.code`, and expected `error.rule`. The mutation test temporarily removes each required rule through dependency injection and asserts that at least one named test fails; no source file is rewritten during the test.

- [ ] **Step 3: Run RED lifecycle and mutation tests**

Run: `python3 -m unittest tests.test_execution_kernel_lifecycle tests.test_execution_kernel_mutations -v`

Expected: FAIL until every gate exposes dependency-injected rule sets, receipt chaining, and the complete acceptance matrix.

- [ ] **Step 4: Complete lifecycle chaining and matrix coverage**

Add only the missing rule hooks and fixture builders needed for all matrix rows. Keep production defaults immutable and require the exact prior receipt hash at each transition.

- [ ] **Step 5: Replace hardcoded trial metrics with observation**

Update the trial runner to append one event per actual launcher call, provider request, project mutation, external mutation, and emitted receipt. Derive counts from those events:

```python
metrics = {
    "tool_calls": sum(event["kind"] == "tool_call" for event in events),
    "external_mutations": sum(event["kind"] == "external_mutation" for event in events),
    "receipt_identities": [event["receipt_hash"] for event in events if event["kind"] == "receipt"],
}
```

- [ ] **Step 6: Add installed-plugin negative and positive trials**

Invoke the installed snapshot's `validate-pr-ready.sh` without input and assert `evidence_missing`; then run the valid fixture through installed public launchers and compare source/installed validator IDs, package hash, envelope hashes, receipt hashes, and observed events.

- [ ] **Step 7: Run GREEN behavioral proof**

Run: `python3 -m unittest tests.test_execution_kernel_lifecycle tests.test_execution_kernel_mutations tests.test_agent_usability_receipts tests.test_auto_loop_trials tests.test_runtime_package -v`

Expected: PASS; the matrix has zero uncovered rows, mutation survival is zero, lifecycle/Git identities agree, and no trial metric is a hardcoded constant.

- [ ] **Step 8: Refactor fixture construction**

Move common temporary-repository and envelope builders into `tests/execution_kernel_fixtures.py`, keeping tests named by behavior.

Run: `python3 -m unittest tests.test_evidence_schema tests.test_evidence_collectors tests.test_gate_pr_ready tests.test_gate_premerge tests.test_gate_merge_decision tests.test_gate_closeout tests.test_gate_publish_ready tests.test_execution_kernel_lifecycle tests.test_execution_kernel_mutations -v`

Expected: PASS with identical matrix and trace results.

- [ ] **Step 9: Checkpoint commit**

```bash
git add tests/execution_kernel_fixtures.py tests/test_execution_kernel_lifecycle.py tests/test_execution_kernel_mutations.py tests/fixtures/execution-kernel/acceptance-matrix.json scripts/run-agent-usability-trials.sh tests/test_agent_usability_receipts.py tests/test_auto_loop_trials.py tests/test_runtime_package.py scripts/validate.sh
git commit -m "test: prove execution gates fail closed end to end"
```

## Task 7: Acceptance Receipt, Full Validation, And Cutover Proof

**Use Cases:**

- A maintainer can inspect one committed milestone receipt template/index and trace durable acceptance claims to commands and fixtures without embedding a publish receipt that becomes stale when committed.
- Full validation detects any displaced-path regression, including a legacy success branch, unregistered runtime module, stale installed snapshot, or missing release gate.
- Deployment always validates and commits source before sync, install, and version verification; the final ephemeral publish-ready receipt is generated against that immutable commit and current installed state.
- Merge closeout has a precise stop condition and requires the current ephemeral receipt instead of treating the committed template or a green test count as sufficient proof.

**Files:**

- Create: `docs/superpowers/milestones/M1-execution-kernel-release-trust-receipt.md`
- Modify: `scripts/validate.sh`
- Modify: `docs/superpowers/milestones/M1-source-of-truth.md`
- Test: `scripts/validate.sh`

**Interfaces:**

- Consumes: acceptance matrix results, lifecycle trace, mutation results, runtime-package proof, the final committed source identity, post-commit sync/install/version observations, cleanup output, and Git status.
- Produces: a committed milestone receipt template/index describing durable proof fields and the ephemeral receipt path, plus `.superpowers/runs/<run-id>/release/publish-ready-envelope.json` and `publish-ready-receipt.json` containing the final source commit, package `HashRef`, validator versions, acceptance row totals, lifecycle receipt chain, installed identity, deployment observations, cleanup result, and explicit remaining risks.

- [ ] **Step 1: Write a failing full-validation assertion for displaced paths**

Add a validation check that searches active handlers for the retired patterns:

```text
return complete(True, "validate-pr-ready"
return complete(True, "premerge"
return complete(True, "closeout"
premerge.get("ok") is not True
"publish_ready": not dirty
```

Run: `./scripts/validate.sh`

Expected: FAIL until all old authorization paths are absent and all focused tests are registered.

- [ ] **Step 2: Run the pre-commit proof oracle**

Run:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/test-prepare-release.sh
./scripts/validate.sh
```

Expected: every command exits 0; the acceptance matrix reports every row covered, mutation survival is zero, and lifecycle receipt identities are present. This step does not claim a current installed-plugin or publish-ready receipt because the source commit does not exist yet.

- [ ] **Step 3: Create the durable milestone receipt template and index**

Record the proof schema, required commands, acceptance matrix path, gate validator IDs, lifecycle chain fields, installed identity fields, trial event fields, cleanup fields, unresolved provider-signature risk, and the task-owned ephemeral receipt path. Link the source spec and this plan. Do not record a source commit, package hash, installed identity, or publish receipt hash as current before the final source commit exists.

- [ ] **Step 4: Re-run source validation after every source, index, and template edit**

Run:

```bash
./scripts/validate.sh
git diff --check
```

Expected: source validation and diff checks exit 0 with every intended source/index/template change present and no generated ephemeral release artifact staged.

- [ ] **Step 5: Commit all source, index, and receipt-template changes**

Run:

```bash
git add scripts/lib tests skills .codex-plugin/runtime-package.yml scripts/validate.sh docs/superpowers/milestones/M1-execution-kernel-release-trust-receipt.md docs/superpowers/milestones/M1-source-of-truth.md
git commit -m "feat: enforce execution kernel release trust"
```

Expected: commit succeeds and `git status --short` is empty. This commit is the immutable source identity used by every subsequent sync, install, version, and publish-ready observation.

- [ ] **Step 6: Deploy the committed source in required order**

Run:

```bash
./scripts/sync-live.sh --validate
codex plugin add superpowers-project@personal --json
./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
```

Expected: sync validates the exact committed source, plugin refresh succeeds, and version freshness identifies that same source/package. Stop if any deployment observation points to a different commit or package `HashRef`.

- [ ] **Step 7: Generate the current ephemeral publish-ready evidence and receipt**

Run:

```bash
RUN_ID="execution-kernel-$(git rev-parse --short HEAD)"
mkdir -p ".superpowers/runs/$RUN_ID/release"
./scripts/prepare-release.sh -CollectOnly -OutputPath ".superpowers/runs/$RUN_ID/release/publish-ready-envelope.json"
./scripts/prepare-release.sh -EvidenceEnvelopePath ".superpowers/runs/$RUN_ID/release/publish-ready-envelope.json" -ReceiptOutputPath ".superpowers/runs/$RUN_ID/release/publish-ready-receipt.json"
```

Expected: collection observes the committed source plus completed sync/install/version state; validation emits `publish-ready-validator@1`; the receipt's source commit equals `git rev-parse HEAD`; package and installed identities are `HashRef` values; `publish_ready` is true; and both files remain ignored, task-owned runtime evidence. Do not edit or commit source after this receipt is generated. Any required source edit invalidates the receipt and restarts at Step 4.

- [ ] **Step 8: Run final current-state acceptance and cleanup**

Run:

```bash
./scripts/prepare-release.sh -PublishReadyReceiptPath ".superpowers/runs/$RUN_ID/release/publish-ready-receipt.json"
bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .
git status --short --branch
```

Expected: release preparation consumes the current receipt and exits 0; cleanup preserves or removes the task-owned ephemeral evidence according to run retention policy; Git status remains clean; and no second commit is required. Final acceptance fails if the ephemeral receipt is absent, stale, mismatched, or no longer corroborates source and installed state.

## Final Verification Sequence

1. `python3 -m unittest discover -s tests -p 'test_*.py'`
2. `./skills/resolve-issue/scripts/test-scenarios.sh`
3. `./skills/merge-changes/scripts/test-scenarios.sh`
4. `./scripts/test-prepare-release.sh`
5. `./scripts/validate.sh`
6. Commit every intended source/index/receipt-template change and verify clean Git state.
7. `./scripts/sync-live.sh --validate`
8. `codex plugin add superpowers-project@personal --json`
9. `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
10. Generate and validate the ephemeral `publish-ready-receipt.json` for the committed source and installed package.
11. Consume that receipt with `./scripts/prepare-release.sh -PublishReadyReceiptPath <ephemeral-receipt>`.
12. `bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .`
13. `git status --short --branch`

Final acceptance requires zero failed tests, zero uncovered acceptance rows, zero surviving required-rule mutations, a complete receipt chain, source/installed identity agreement, a current ephemeral `publish_ready` receipt generated after the final source commit and deployment, successful cleanup, and a clean implementation branch. A committed receipt template or a receipt generated before the final source commit cannot satisfy this gate. Merge approval and integration remain owned by `superpowers-project:merge-changes`; this plan does not preauthorize them.

## Plan Self-Review

- Spec coverage: Tasks 1 through 7 cover schema, collectors, each of the five gates, receipt consumption, runtime decomposition, legacy cutover, adversarial tests, mutation tests, installed-plugin trials, release trust, and committed outcome proof.
- Scope boundary: Auto/Looping prompts, issue-route selection, Codex worktree provisioning, and contract/distribution simplification remain outside this plan. The kernel owns only shared `HashRef` serialization, workspace evidence registration, and gate extension consumption needed to trust provider receipts.
- Placeholder scan: Every implementation step names concrete behavior, files, interfaces, commands, and expected results; no deferred implementation marker is used.
- Type consistency: Every gate consumes `EvidenceEnvelope`, returns `GateReceipt`, raises `EvidenceError`, and passes `HashRef` values encoded as `sha256:<64 lowercase hexadecimal characters>` across lifecycle and workspace boundaries.
- Cutover coverage: Use cases and Tasks 3 through 7 explicitly displace no-argument success, bare booleans, legacy receipts, and independent publish authorization.
- Completion discipline: Focused tests precede implementation, every implementation task has a checkpoint, deployment occurs only after final source validation and commit, and final claims require a newly generated current publish-ready receipt plus installed, cleanup, and clean Git evidence.
