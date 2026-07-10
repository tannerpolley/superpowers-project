# Codex-Native Workspace Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add provider-aware workspace isolation that prefers Codex-managed project worktrees, preserves safe local Git worktree fallback, and proves workspace identity and ownership before implementation, publication, or cleanup.

**Architecture:** A pure Python policy module turns untrusted caller requests into provider action requests, while execution-kernel read-only collectors independently inspect repository, coordinator, Git, Codex project/task/workspace, and duplicate-worktree reality before constructing registered workspace evidence. The existing kernel `HashRef`, canonical serializer, `EvidenceEnvelope`, `gate_premerge`, and `gate_closeout` interfaces own trust, hashing, acceptance, and receipt chaining; the agent invokes native Codex mutations but cannot self-attest their result.

**Tech Stack:** Python 3 standard library, JSON, Bash launcher shims, Markdown skill contracts, YAML agent metadata, `unittest`, existing Superpowers Project command registry and scenario harness.

## Global Constraints

- Prefer `codex_managed_worktree` when Codex native project task operations are available and isolation is `preferred` or `required`.
- Keep the installed vanilla `superpowers:using-git-worktrees` skill byte-for-byte unchanged.
- Treat `shared_subagent` as delegation without filesystem isolation.
- Accept detached HEAD for Codex-managed execution, but require a branch-bound transition receipt before push or pull-request creation.
- Never manually delete a Codex-app-owned or user-owned workspace.
- Permit fallback from native Codex to local Git worktree only before a native task has been created.
- Treat every caller-supplied JSON object as untrusted request input; it cannot establish workspace reality or pass an evidence gate.
- Collect canonical coordinator/workspace paths, Git common directory, actual HEAD/branch, Codex project/task/workspace identity, and duplicate-worktree state through registered execution-kernel read-only collectors.
- Reuse the execution kernel's `HashRef` and canonical serializer; do not define workspace-specific hashing or a parallel validation/receipt stack.
- Execute this plan only after the execution-kernel and Auto/Loop lifecycle plans are merged to main; rebase onto that main before the first RED test.
- Persist full paths and provider task identifiers only in ephemeral run evidence; committed examples use redacted fixture values.
- Use TDD for every behavior change: observe the focused RED failure, implement the minimum GREEN change, and refactor only while focused and full tests remain green.
- Use `superpowers:systematic-debugging` when a test fails for an unexplained reason and `superpowers:verification-before-completion` before any completion, commit, push, or merge-readiness claim.

---

## Source Evidence

**Source Spec:** `docs/superpowers/specs/2026-07-10-codex-native-workspace-isolation-design.md`

**Umbrella Audit:** `docs/superpowers/specs/2026-07-10-autonomous-workflow-and-codex-worktree-audit-findings.md`

**Current implementation evidence:**

- `skills/orchestrate-issues/SKILL.md` says to create an isolated worker worktree but does not distinguish a Codex task from a same-checkout collaboration subagent.
- `scripts/lib/superpowers_project_cli.py::command_prepare_worker_handoff` emits only the prose field `branch_worktree_policy` and a list naming `superpowers:using-git-worktrees`.
- `scripts/lib/superpowers_project_cli.py::command_validate_worker_handoff` validates the branch name and required skill names but does not validate filesystem separation, provider identity, ownership, or repository and candidate bindings.
- `skills/implement-plan/SKILL.md` and `skills/resolve-issue/SKILL.md` direct agents to create a worktree without a shared provider receipt.
- `skills/merge-changes/SKILL.md` allows cleanup after integration but has no provider-owned cleanup decision.
- The public launcher architecture routes Bash shims through `scripts/lib/run-script.sh`, `scripts/lib/command_catalog.py`, and `scripts/lib/superpowers_project_cli.py`.

**Resolved planning decisions:**

- The adapter defaults to `fork_task` when a current Codex project task can carry the approved context into a worktree; it uses `create_task` when no suitable source task exists or a clean conversation boundary is required.
- Full provider identifiers and absolute paths stay in ignored or temporary workflow-run evidence. Committed examples replace them with stable fixture tokens.
- Completion records logical disposition for app-owned tasks. Automatic archival is outside this plan because it changes user-visible task state and is not required to prove safe cleanup.
- The execution kernel is the only evidence authority. Workspace code registers evidence kinds, collector versions, and premerge/closeout rules through kernel-owned interfaces instead of exposing a second validator.

## Strict Dependencies And Execution Order

1. Merge `docs/superpowers/plans/2026-07-10-execution-kernel-release-trust-plan.md` to main, including `HashRef`, canonical serialization, registered collectors, `EvidenceEnvelope`, `gate_premerge`, and `gate_closeout`.
2. Merge `docs/superpowers/plans/2026-07-10-auto-loop-lifecycle-semantics-plan.md` to main so workspace evidence can bind the canonical workflow run, candidate, and authorization lifecycle.
3. Rebase the workspace-isolation implementation branch onto that updated main and rerun both dependency suites before editing workspace code.
4. Implement this plan by extending the merged kernel and lifecycle interfaces. If their landed names or schemas differ, revise this plan and its issue before implementation rather than adding compatibility aliases or a parallel stack.
5. Commit all source changes before any `sync-live`, marketplace install/refresh, version verification, or other deployment action.

The dependency is hard, not advisory. Workspace implementation must not proceed against speculative kernel or lifecycle interfaces.

## Test Complete And Metrics

Testing is complete when the provider unit tests, public-command tests, owner-skill scenario tests, worker packet validator, installed-app trial verifier, non-Codex trial fixture, full repository validator, live sync validation, version check, and cleanup audit all pass from the repository root.

Metrics and exact tolerances:

- All provider selection table cases return the exact expected provider or structured blocker; no fallback default is accepted.
- A shared subagent passes zero `required` isolation cases.
- A native receipt with detached HEAD passes execution validation and fails publication validation until a branch transition is recorded.
- Cleanup validation permits physical removal only when `ownership=plugin` and `cleanup_owner=plugin` for the exact recorded workspace ID.
- Native provider scenarios create zero repository-local `.worktrees` directories.
- Vanilla Superpowers source checksums before and after installed-app verification are identical.
- All focused commands and `./scripts/validate.sh` exit `0`; JSON validators report `ok: true`.

## Outcome Proof

**Intent:** Make Codex desktop isolation use visible, app-managed project worktree tasks while retaining safe terminal-only behavior and preventing labels or shared subagents from masquerading as isolated workspaces.

**Current Behavior:** Owner skills describe worktree creation in prose, worker packets name the vanilla worktree skill, and validators accept branch metadata without provider-bound filesystem evidence.

**Expected Outcome:** Every isolation decision produces a validated provider action or structured blocker, every adopted or created workspace produces a repository/run/candidate-bound receipt, and downstream publication and cleanup actions enforce the receipt's branch and ownership state.

**Target Output:** Provider policy code, a registered execution-kernel workspace reality collector and evidence schema extension, premerge/closeout workspace rules, unit and scenario coverage, updated owner skills and metadata, updated worker packet examples, and installed-app/non-Codex proof fixtures.

**Owner:** Workspace isolation adapter owned by the Superpowers Project runtime, with native operations executed by the active Codex agent and local worktree mechanics delegated to `superpowers:using-git-worktrees`.

**Interface:** `resolve_workspace_isolation(request, capabilities) -> IsolationDecision`; `collect_workspace_reality(request, repo_root) -> CollectorResult`; kernel `HashRef` and canonical serialization; workspace evidence embedded in `EvidenceEnvelope`; and workspace rules registered with `validate_premerge(...) -> GateReceipt` and `validate_closeout(...) -> GateReceipt`.

**Cutover:** Implementation, issue-resolution, orchestration, publication, and cleanup routes switch from prose `branch_worktree_policy` evidence to registered `workspace_reality@1` kernel evidence and chained premerge/closeout receipts in one source revision.

**Replaced Path:** Branch labels, worker names, `required_skills` membership, and a prose worktree policy no longer establish isolation; the prose fields may remain for human readability but cannot satisfy a validator.

**Evidence:** Unit tests cover selection and kernel-owned evidence registration; read-only reality-collector tests independently corroborate coordinator/workspace paths, Git and Codex identities, and duplicates; gate tests cover detached HEAD, fallback, publication, and cleanup; scenario tests cover all owner routes; trial receipts prove both providers; checksum evidence proves vanilla files remain unchanged.

**Acceptance Proof:** `python3 -m unittest tests.test_workspace_isolation tests.test_command_registry tests.test_command_surface`, all four owner-skill scenario scripts, `./scripts/test-worker-packets.sh`, `./scripts/test-workspace-isolation-trials.sh`, and `./scripts/validate.sh` pass with the exact negative cases rejecting invalid evidence.

**Stop Criteria:** Stop implementation if current Codex operations cannot expose a stable project/task/workspace identity, if repository identity cannot be compared across coordinator and worker, if native task creation succeeds without observable state needed for a receipt, or if a provider-owned cleanup action cannot be distinguished from app/user ownership.

**Avoid:** Do not edit vanilla Superpowers, infer isolation from narrative, create both native and local worktrees for one candidate, manipulate Codex app metadata with Git commands, persist private machine paths in committed evidence, or perform broad worktree pruning.

**Risk:** Codex native operations can differ across app versions; the mitigation is capability-driven action requests, fail-closed receipt validation, redacted fixtures, and an installed-app acceptance trial owned by the workspace maintainer.

## Implementation Boundaries

**Files To Create:** `scripts/lib/workspace_isolation.py`, `scripts/workspace-isolation.sh`, `scripts/test-workspace-isolation-trials.sh`, `tests/test_workspace_isolation.py`, `tests/fixtures/workspace_isolation/native-detached.json`, `tests/fixtures/workspace_isolation/local-branch.json`, and `docs/superpowers/examples/workspace-isolation-receipts.md`.

**Files To Modify:** `scripts/lib/evidence_schema.py`, `scripts/lib/evidence_collectors.py`, `scripts/lib/gate_premerge.py`, `scripts/lib/gate_closeout.py`, `scripts/lib/commands/gates.py`, `scripts/lib/command_catalog.py`, `scripts/lib/superpowers_project_cli.py`, `.codex-plugin/runtime-package.yml`, `scripts/validate.sh`, owner skill contracts and startup metadata under `skills/implement-plan`, `skills/resolve-issue`, `skills/orchestrate-issues`, and `skills/merge-changes`, their focused scenario tests, worker handoff preparation/validation behavior, and `docs/superpowers/examples/worker-handoff-packets.md`.

**Files To Avoid:** All installed plugin cache paths, deployed copies under `$HOME/.codex/plugins`, all vanilla `superpowers:*` skill files, Codex app worktree metadata, unrelated workflow graph and release-kernel files, and historical receipts.

**Source Of Truth:** `scripts/lib/workspace_isolation.py` owns provider-selection policy and workspace-specific domain checks; the execution kernel owns `HashRef`, canonical serialization, registered evidence schema/collectors, `EvidenceEnvelope`, gate rules, and `GateReceipt`; skill prose does not redefine either source.

**Read Path:** Untrusted capability/action request JSON, canonical lifecycle identifiers, and read-only kernel collection of canonical coordinator/workspace paths, `git rev-parse --git-common-dir`, actual HEAD/branch, Codex project/task/workspace identity, provider operation results, and duplicate Git/Codex worktrees.

**Write Path:** Kernel envelope and receipt paths selected by the workflow runtime, committed redacted fixtures/examples, and source-controlled skill/runtime/test files only; callers cannot write passing observations directly.

**Integration Points:** Execution-kernel `HashRef`, serializer, evidence registry, collectors, `gate_premerge`, `gate_closeout`, and receipt chaining; lifecycle run/candidate/authorization identity; Codex project task operations through the active agent; vanilla local fallback; owner workflow skills; worker packets; merge cleanup; command dispatch; validation; live sync; and marketplace refresh.

**Migration Or Cutover:** Existing local worktrees can be adopted only after producing a valid `local_git_worktree` receipt; historical shared-subagent packets remain records but fail new execution and merge gates.

**Replaced Path Handling:** Remove reliance on caller JSON, `branch_worktree_policy`, and required-skill names as proof; retain prose fields only as descriptive compatibility text for one release; require registered kernel workspace evidence at premerge/closeout; and do not ship workspace-specific validator receipts.

**Acceptance Proof Gate:** No implementation issue is merge-ready until focused tests, all owner scenario tests, installed-app/non-Codex trial verification, full validation, required post-revision deployment loop, and clean-main proof succeed.

## File Map And Interface Map

- `scripts/lib/workspace_isolation.py`: immutable provider enums and dataclasses, untrusted-request policy, workspace evidence interpretation, transition rules, and cleanup ownership decisions without its own serializer or receipt validator.
- `scripts/workspace-isolation.sh`: public launcher for provider action-request resolution only; its result never constitutes evidence.
- `scripts/lib/evidence_schema.py`: register workspace evidence kinds and reuse kernel `HashRef` for coordinator, workspace, provider-response, and artifact identities.
- `scripts/lib/evidence_collectors.py`: independently collect canonical coordinator/workspace paths, Git common directory, actual HEAD/branch, Codex project/task/workspace identities, and duplicate-worktree observations.
- `scripts/lib/gate_premerge.py` and `scripts/lib/gate_closeout.py`: consume registered workspace evidence through the existing kernel gate and `GateReceipt` interfaces.
- `scripts/lib/commands/gates.py`: expose workspace collection through the kernel-owned collection adapter rather than a workspace-specific validation command.
- `scripts/lib/command_catalog.py`: register only the provider action-request launcher; kernel collection/gate launchers remain the evidence surface.
- `scripts/lib/superpowers_project_cli.py`: parse untrusted policy requests and delegate evidence operations to the kernel adapters.
- `tests/test_workspace_isolation.py`: unit contract for native preference, local fallback, kernel evidence registration, independent reality collection, coordinator binding, detached HEAD, branch transitions, and cleanup ownership.
- `skills/implement-plan/*` and `skills/resolve-issue/*`: require an isolation decision and validated receipt before implementation.
- `skills/orchestrate-issues/*`: send a provider action request before worker creation and bind the returned receipt into the immutable handoff packet.
- `skills/merge-changes/*`: require transition proof before publication and provider-authorized cleanup after integration.
- `docs/superpowers/examples/workspace-isolation-receipts.md`: redacted, validator-backed native, local, and negative receipt examples.
- `scripts/test-workspace-isolation-trials.sh`: verify recorded installed-app and terminal-only traces, no native `.worktrees` creation, and unchanged vanilla checksums.

## Tasks

### Task 1: Provider Policy And Kernel Evidence Registration

**Use Cases:**

- A required isolation request with native Codex capability selects a Codex-managed task action, but its caller JSON and decision output remain untrusted request data.
- A terminal-only request selects local Git worktree fallback without imposing `.worktrees` as its directory.
- A shared subagent cannot satisfy required isolation and produces a structured blocker.
- A matching current Codex worktree is adopted without creating a duplicate workspace.
- Registered kernel evidence bound to another repository, run, candidate, coordinator, workspace, or current head fails acceptance evidence validation.
- Workspace evidence reuses kernel `HashRef` and canonical serialization, so semantically identical observations hash exactly like every other kernel artifact.
- Migration from label-based proof is explicit: branch names and agent labels cannot substitute for the new receipt.

**Files:**

- Create: `scripts/lib/workspace_isolation.py`
- Modify: `scripts/lib/evidence_schema.py`
- Modify: `.codex-plugin/runtime-package.yml`
- Create: `tests/test_workspace_isolation.py`
- Modify: `tests/test_evidence_schema.py`

**Interfaces:**

- Consumes: untrusted JSON-compatible `IsolationRequest` and `CapabilitySnapshot`, plus merged execution-kernel `HashRef`, canonical serializer, evidence-kind registry, `EvidenceEnvelope`, and lifecycle identity.
- Produces: `resolve_workspace_isolation(request, capabilities) -> IsolationDecision`, `WorkspaceEvidencePayload`, registered `workspace_reality@1` evidence, and kernel-owned `HashRef` values; no workspace-specific receipt or serializer.

- [ ] **Step 1: Write RED provider selection tests**

Create `tests/test_workspace_isolation.py` with table-driven tests that define the wished-for API before production code exists:

```python
import copy
import unittest

from scripts.lib.workspace_isolation import WorkspaceIsolationError, resolve_workspace_isolation


class WorkspaceIsolationTests(unittest.TestCase):
    def test_native_provider_is_preferred_for_required_isolation(self):
        result = resolve_workspace_isolation(
            {"requirement": "required", "repository_identity": "repo:superpowers", "workflow_run_id": "run-1", "candidate_id": "candidate-1"},
            {"codex_project_tasks": True, "local_git_worktrees": True, "source_task_id": "task-local"},
        )
        self.assertEqual("codex_managed_worktree", result["provider"])
        self.assertEqual("fork_task", result["operation"])

    def test_terminal_host_uses_local_provider_without_prescribing_directory(self):
        result = resolve_workspace_isolation(
            {"requirement": "required", "repository_identity": "repo:superpowers", "workflow_run_id": "run-1", "candidate_id": "candidate-1"},
            {"codex_project_tasks": False, "local_git_worktrees": True},
        )
        self.assertEqual({"provider": "local_git_worktree", "operation": "invoke_vanilla_worktree_skill"}, {key: result[key] for key in ("provider", "operation")})
        self.assertNotIn("workspace_path", result)

    def test_shared_subagent_is_not_isolation(self):
        with self.assertRaisesRegex(WorkspaceIsolationError, "shared_subagent.*not an isolation provider"):
            resolve_workspace_isolation(
                {"requirement": "required", "repository_identity": "repo:superpowers", "workflow_run_id": "run-1", "candidate_id": "candidate-1"},
                {"codex_project_tasks": False, "local_git_worktrees": False, "delegation_provider": "shared_subagent"},
            )
```

- [ ] **Step 2: Run the provider tests and record the RED failure**

Run:

```bash
python3 -m unittest tests.test_workspace_isolation.WorkspaceIsolationTests.test_native_provider_is_preferred_for_required_isolation tests.test_workspace_isolation.WorkspaceIsolationTests.test_terminal_host_uses_local_provider_without_prescribing_directory tests.test_workspace_isolation.WorkspaceIsolationTests.test_shared_subagent_is_not_isolation
```

Expected: exit `1` with `ModuleNotFoundError: No module named 'scripts.lib.workspace_isolation'`. Fix only test syntax/import errors if the failure differs; do not add production behavior until the tests fail for the missing module.

- [ ] **Step 3: Implement the minimal provider selection policy**

Create `scripts/lib/workspace_isolation.py` with frozen provider constants, required-field checks, and this selection core:

```python
from __future__ import annotations

import hashlib
import json
from typing import Any, Mapping


class WorkspaceIsolationError(ValueError):
    pass


PROVIDERS = {"current_checkout", "local_git_worktree", "codex_managed_worktree", "shared_subagent"}
REQUIREMENTS = {"none", "preferred", "required"}


def _required(data: Mapping[str, Any], *fields: str) -> None:
    missing = [field for field in fields if data.get(field) in (None, "")]
    if missing:
        raise WorkspaceIsolationError("missing required field(s): " + ", ".join(missing))


def resolve_workspace_isolation(request: Mapping[str, Any], capabilities: Mapping[str, Any]) -> dict[str, Any]:
    _required(request, "requirement", "repository_identity", "workflow_run_id", "candidate_id")
    requirement = str(request["requirement"])
    if requirement not in REQUIREMENTS:
        raise WorkspaceIsolationError(f"unsupported isolation requirement: {requirement}")
    if capabilities.get("delegation_provider") == "shared_subagent" and requirement == "required" and not capabilities.get("codex_project_tasks") and not capabilities.get("local_git_worktrees"):
        raise WorkspaceIsolationError("shared_subagent is delegation, not an isolation provider")
    if capabilities.get("codex_project_tasks") and requirement in {"preferred", "required"}:
        operation = "fork_task" if capabilities.get("source_task_id") else "create_task"
        return {"ok": True, "provider": "codex_managed_worktree", "operation": operation, "reason": "native Codex isolation is available"}
    if capabilities.get("local_git_worktrees") and requirement in {"preferred", "required"}:
        return {"ok": True, "provider": "local_git_worktree", "operation": "invoke_vanilla_worktree_skill", "reason": "native provider unavailable"}
    if requirement != "required":
        return {"ok": True, "provider": "current_checkout", "operation": "adopt", "reason": "request permits current checkout"}
    raise WorkspaceIsolationError("required isolation has no provable provider")
```

- [ ] **Step 4: Run provider selection tests GREEN**

Run the three-test command from Step 2.

Expected: exit `0`, `Ran 3 tests`, `OK`.

- [ ] **Step 5: Write RED kernel evidence registration and HashRef tests**

Extend the test module and `tests/test_evidence_schema.py` with a detached native payload. Assert `workspace_reality` is a registered evidence kind, every identity/hash field is a kernel `HashRef`, caller-supplied `receipt_hash` and observed path fields are rejected as unknown request keys, and `sha256_canonical` produces the evidence hash:

```python
def native_observation(self):
    return {
        "schema_version": 1,
        "provider": "codex_managed_worktree",
        "ownership": "codex_app",
        "repository_identity": "repo:superpowers",
        "workflow_run_id": "run-1",
        "candidate_id": "candidate-1",
        "task_id": "task-worktree",
        "workspace_id": "workspace-1",
        "workspace_path": "/tmp/codex-worktree",
        "coordinator_path": "/tmp/coordinator",
        "git_common_dir": "/tmp/repo/.git",
        "initial_head": "a" * 40,
        "current_head": "a" * 40,
        "head_mode": "detached",
        "branch": None,
        "created_at": "2026-07-10T12:00:00Z",
        "created_by_operation": "fork_task",
        "cleanup_owner": "codex_app",
    }

def test_workspace_evidence_uses_kernel_hashrefs_and_serializer(self):
    item = make_workspace_evidence_item(self.native_observation())
    self.assertIsInstance(item.payload["workspace_path"], HashRef)
    self.assertIsInstance(item.payload["coordinator_path"], HashRef)
    self.assertEqual(item.payload_hash, sha256_canonical(item.payload))

def test_untrusted_request_cannot_self_attest_reality(self):
    request = {"requirement": "required", "workspace_path": "/claimed", "receipt_hash": "claimed"}
    with self.assertRaisesRegex(EvidenceError, "schema_invalid"):
        parse_isolation_request(request)
```

- [ ] **Step 6: Run receipt tests RED**

Run:

```bash
python3 -m unittest tests.test_workspace_isolation.WorkspaceIsolationTests.test_workspace_evidence_uses_kernel_hashrefs_and_serializer tests.test_workspace_isolation.WorkspaceIsolationTests.test_untrusted_request_cannot_self_attest_reality
```

Expected: exit `1` because workspace evidence is not registered with the merged kernel schema and the policy parser does not yet reject self-attested reality fields.

- [ ] **Step 7: Register workspace evidence and reuse kernel identity primitives**

Extend the kernel evidence registry with `workspace_reality@1` and define `WorkspaceEvidencePayload` using imported `HashRef`. Call the kernel serializer and `sha256_canonical`; do not add `canonical_receipt_hash`, `build_workspace_receipt`, or `validate_workspace_receipt`. Bind both coordinator and workspace identities:

```python
@dataclass(frozen=True)
class WorkspaceEvidencePayload:
    provider: str
    ownership: str
    repository: HashRef
    workflow_run: HashRef
    candidate: HashRef
    coordinator_identity: HashRef
    coordinator_path: HashRef
    workspace_identity: HashRef
    workspace_path: HashRef
    git_common_dir: HashRef
    head: HashRef
    branch: str | None
    codex_project: HashRef | None
    codex_task: HashRef | None
    codex_workspace: HashRef | None
    duplicate_worktrees: tuple[HashRef, ...]

REGISTERED_EVIDENCE_KINDS["workspace_reality"] = WorkspaceEvidencePayload
```

- [ ] **Step 8: Run all kernel tests and refactor while green**

Run:

```bash
python3 -m unittest tests.test_workspace_isolation -v
```

Expected: all provider and receipt cases pass. Refactor duplicate test fixtures and field checks only after this GREEN result, then rerun the same command and retain exit `0`.

- [ ] **Step 9: Commit the kernel checkpoint**

```bash
git add scripts/lib/workspace_isolation.py scripts/lib/evidence_schema.py tests/test_workspace_isolation.py tests/test_evidence_schema.py .codex-plugin/runtime-package.yml
git commit -m "Register workspace isolation evidence"
```

### Task 2: Read-Only Workspace Reality Collection

**Use Cases:**

- The kernel collector independently canonicalizes both coordinator and workspace paths and proves that required isolation uses different working trees with the same expected Git common directory.
- The collector reads actual HEAD and branch from the selected workspace rather than accepting caller claims.
- The collector resolves Codex project/task/workspace identity through a registered read-only provider observation and hashes the raw provider response.
- The collector enumerates Git and Codex worktrees to detect duplicate candidate workspaces, including an unexpected `.worktrees` checkout during native isolation.
- Pre/post snapshots prove collection does not mutate repository, provider, or app state.
- Missing, inaccessible, ambiguous, or contradictory reality becomes non-passing kernel evidence rather than a caller-selected fallback.

**Files:**

- Modify: `scripts/lib/evidence_collectors.py`
- Modify: `scripts/lib/commands/gates.py`
- Modify: `scripts/lib/workspace_isolation.py`
- Modify: `tests/test_workspace_isolation.py`
- Modify: `tests/test_evidence_collectors.py`

**Interfaces:**

- Consumes: kernel `CollectionRequest`, canonical repository root, coordinator path, selected workspace locator, lifecycle identity, and read-only Codex provider inspector.
- Produces: registered `CollectorResult(kind="workspace_reality", collector="workspace-reality@1", payload=WorkspaceEvidencePayload)` through the existing kernel envelope builder.

- [ ] **Step 1: Write RED independent reality-collector tests**

Add tests that pass false caller claims and assert the collector returns independently observed values:

```python
def test_workspace_collector_ignores_claimed_head_and_paths(self):
    request = workspace_collection_request(
        claimed_workspace_path="/forged",
        claimed_head="0" * 40,
    )
    result = collect_workspace_reality(self.repo, request, provider=self.provider)
    self.assertEqual(hash_ref(self.actual_workspace.resolve()), result.payload.workspace_path)
    self.assertEqual(hash_ref(git_head(self.actual_workspace)), result.payload.head)
    self.assertEqual(hash_ref(self.coordinator.resolve()), result.payload.coordinator_path)

def test_collector_detects_duplicate_candidate_worktree_without_mutation(self):
    before = snapshot_repo_and_provider(self.repo, self.provider)
    result = collect_workspace_reality(self.repo, workspace_collection_request(), provider=self.provider)
    self.assertEqual(1, len(result.payload.duplicate_worktrees))
    self.assertEqual(before, snapshot_repo_and_provider(self.repo, self.provider))
```

- [ ] **Step 2: Verify transition tests fail RED**

Run:

```bash
python3 -m unittest tests.test_workspace_isolation.WorkspaceIsolationTests.test_detached_native_receipt_blocks_publication_until_branch_transition tests.test_workspace_isolation.WorkspaceIsolationTests.test_cleanup_follows_exact_provider_ownership
```

Expected: exit `1` because `collect_workspace_reality` and `workspace-reality@1` are not registered in the merged kernel collector registry.

- [ ] **Step 3: Implement the bounded read-only collector**

Add `collect_workspace_reality` to the kernel collector registry. It must run bounded read-only Git commands in both checkouts, canonicalize paths, compare Git common directories, inspect actual HEAD/branch, query provider identity without mutation, hash raw provider output, and enumerate duplicates. Caller values select what to inspect but never populate observed payload fields:

```python
COLLECTORS["workspace_reality"] = ("workspace-reality@1", collect_workspace_reality)

def collect_workspace_reality(root: Path, request: WorkspaceCollectionRequest, provider: WorkspaceProviderInspector) -> CollectorResult:
    coordinator = canonical_existing_path(request.coordinator_locator)
    workspace = provider.resolve_workspace(request.workspace_locator)
    git = inspect_git_reality(coordinator, workspace.path)
    provider_state = provider.inspect_project_task_workspace(workspace)
    duplicates = inspect_duplicate_worktrees(root, provider_state)
    payload = WorkspaceEvidencePayload.from_observations(
        coordinator=coordinator,
        workspace=workspace,
        git=git,
        provider_state=provider_state,
        duplicates=duplicates,
    )
    return CollectorResult("workspace_reality", "workspace-reality@1", utc_now(), payload)
```

- [ ] **Step 4: Run collector tests GREEN and the complete kernel collector suite**

Run:

```bash
python3 -m unittest tests.test_workspace_isolation tests.test_evidence_collectors tests.test_evidence_schema -v
```

Expected: all tests pass, including forged request claims ignored, coordinator/workspace identity binding, actual Git state, provider identity, duplicate detection, read-only snapshots, and unsupported provider observations rejected.

- [ ] **Step 5: Commit transition checkpoint**

```bash
git add scripts/lib/workspace_isolation.py scripts/lib/evidence_collectors.py scripts/lib/commands/gates.py tests/test_workspace_isolation.py tests/test_evidence_collectors.py .codex-plugin/runtime-package.yml
git commit -m "Collect workspace reality evidence"
```

### Task 3: Kernel Premerge And Closeout Workspace Rules

**Use Cases:**

- An agent can resolve provider choice before mutation, but only a kernel-collected `EvidenceEnvelope` can pass premerge or closeout.
- `gate_premerge` requires current workspace reality, branch-bound publication state, matching coordinator/workspace/lifecycle identities, and zero duplicate workspaces.
- `gate_closeout` requires current post-integration reality and derives cleanup disposition from independently observed ownership.
- A detached native workspace can pass implementation evidence but premerge blocks publication until the next collection observes a supported branch or Handoff result.
- Kernel `GateReceipt` chaining binds workspace rules to the same repository, workflow run, candidate, authorization, and prior receipt.
- Migration extends registered kernel interfaces and does not add public workspace receipt/transition validators.

**Files:**

- Create: `scripts/workspace-isolation.sh`
- Modify: `scripts/lib/gate_premerge.py`
- Modify: `scripts/lib/gate_closeout.py`
- Modify: `scripts/lib/commands/gates.py`
- Modify: `scripts/lib/command_catalog.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `tests/test_gate_premerge.py`
- Modify: `tests/test_gate_closeout.py`
- Modify: `tests/test_command_registry.py`
- Modify: `tests/test_command_surface.py`

**Interfaces:**

- Consumes: untrusted `-RequestJson|-RequestPath` and `-CapabilitiesJson|-CapabilitiesPath` for policy only; kernel `EvidenceEnvelopeJson|Path` and prior `GateReceipt` for premerge/closeout.
- Produces: `workspace-isolation-decision` request output plus kernel-owned `premerge-validator@1` and `closeout-validator@1` receipts containing registered workspace rule results.

- [ ] **Step 1: Add RED kernel workspace-rule and policy-command tests**

In `tests/test_command_registry.py`, register only the untrusted policy request command:

```python
def test_workspace_isolation_request_has_exact_handler(self):
    self.assertEqual("command_workspace_isolation", _COMMANDS["scripts/workspace-isolation.sh"])
```

In `tests/test_command_surface.py`, assert the policy command works from an arbitrary CWD, labels output `untrusted_request: true`, and performs no mutation. In `tests/test_gate_premerge.py` and `tests/test_gate_closeout.py`, add RED cases for missing workspace evidence, forged caller observations, coordinator mismatch, duplicate workspace, detached publication, wrong cleanup ownership, and cross-candidate prior receipt.

- [ ] **Step 2: Run command tests RED**

Run:

```bash
python3 -m unittest tests.test_gate_premerge tests.test_gate_closeout tests.test_command_registry tests.test_command_surface -v
```

Expected: exit `1` because the kernel gates do not require registered workspace reality and the policy launcher does not exist.

- [ ] **Step 3: Add the single policy-request launcher shim**

Create `scripts/workspace-isolation.sh` with the repository-standard body, changing no behavior in Bash:

```bash
#!/usr/bin/env bash
set -euo pipefail

search_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
while [[ "$search_dir" != "/" ]]; do
  if [[ -x "$search_dir/scripts/lib/run-script.sh" ]]; then
    exec "$search_dir/scripts/lib/run-script.sh" "${BASH_SOURCE[0]}" "$@"
  fi
  search_dir="$(dirname "$search_dir")"
done

echo "Could not locate scripts/lib/run-script.sh" >&2
exit 127
```

Make the launcher executable as a mechanical file-mode change after creating it. Do not create `validate-workspace-receipt.sh` or `validate-workspace-transition.sh`; validation belongs to the kernel gate launchers.

- [ ] **Step 4: Register exact handlers and mutation classes**

Add only this entry to `_COMMANDS` in `scripts/lib/command_catalog.py`:

```python
'scripts/workspace-isolation.sh': 'command_workspace_isolation',
```

Classify `command_workspace_isolation` as mutation-free. It returns an action request and cannot write evidence or assert observed state.

- [ ] **Step 5: Implement thin CLI handlers**

In `scripts/lib/superpowers_project_cli.py`, add only the policy handler. It rejects observation, receipt, path-reality, head, branch, and hash keys; those are collected by `commands.gates`:

```python
def command_workspace_isolation(ctx: Context, args: dict[str, Any]) -> int:
    root = project_root_for(ctx, args)
    request, _ = read_json_arg(root, args, "RequestJson", "RequestPath")
    capabilities, _ = read_json_arg(root, args, "CapabilitiesJson", "CapabilitiesPath")
    decision = resolve_workspace_isolation(parse_isolation_request(request), capabilities)
    return emit({"ok": True, "phase": "workspace-isolation-decision", "untrusted_request": True, "decision": decision})
```

Extend kernel `GATE_REQUIREMENTS` and registered rule sets rather than creating new handlers:

```python
PREMERGE_REQUIREMENTS.add("workspace_reality")
CLOSEOUT_REQUIREMENTS.add("workspace_reality")
PREMERGE_RULES.extend((workspace_identity_rule, workspace_publication_rule, duplicate_workspace_rule))
CLOSEOUT_RULES.extend((workspace_identity_rule, workspace_disposition_rule, cleanup_ownership_rule))
```

- [ ] **Step 6: Run registry, surface, and unit tests GREEN**

Run:

```bash
python3 -m unittest tests.test_workspace_isolation tests.test_evidence_schema tests.test_evidence_collectors tests.test_gate_premerge tests.test_gate_closeout tests.test_command_registry tests.test_command_surface -v
```

Expected: all tests pass; the policy subprocess works from `/tmp` but cannot carry reality evidence, premerge/closeout return kernel `GateReceipt` objects, and every forged/missing/stale workspace case fails with a stable kernel error rule.

- [ ] **Step 7: Commit public command checkpoint**

```bash
git add scripts/workspace-isolation.sh scripts/lib/gate_premerge.py scripts/lib/gate_closeout.py scripts/lib/commands/gates.py scripts/lib/command_catalog.py scripts/lib/superpowers_project_cli.py tests/test_gate_premerge.py tests/test_gate_closeout.py tests/test_command_registry.py tests/test_command_surface.py .codex-plugin/runtime-package.yml
git commit -m "Enforce workspace evidence at kernel gates"
```

### Task 4: Implementation And Issue-Resolution Preflight

**Use Cases:**

- Inline plan implementation resolves `none`, `preferred`, or `required` isolation before editing and triggers kernel reality collection after adoption.
- Issue resolution requests required isolation and prefers a native Codex project worktree when native operations are callable.
- The agent executes the returned `fork_task` or `create_task` action, then a read-only kernel collector independently inspects the result instead of accepting agent-supplied observed JSON.
- A native action failure blocks before local fallback once a task ID exists, preventing duplicate orphaned workspaces.
- A detached native worktree can implement and verify while kernel premerge remains blocked until a new collection observes a branch transition.
- The old direct call to vanilla worktree creation is displaced by provider selection; terminal hosts still invoke vanilla unchanged.

**Files:**

- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/test-scenarios.sh`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`
- Modify: `skills/resolve-issue/scripts/prepare-execution.sh`
- Modify: `skills/resolve-issue/scripts/validate-setup.sh`

**Interfaces:**

- Consumes: canonical lifecycle context, explicit isolation requirement, untrusted capability request, adapter decision, and kernel `CollectionRequest` after native/local mutation.
- Produces: untrusted `isolation_decision` plus registered `workspace_reality` evidence in the kernel envelope; premerge/closeout consume kernel receipts rather than workspace-specific validation output.

- [ ] **Step 1: Add RED text and scenario assertions**

Extend both owner scenario scripts so they fail unless skill and startup metadata require these exact concepts:

```text
scripts/workspace-isolation.sh
Codex project task
workspace_reality
execution-kernel read-only collector
coordinator identity
shared_subagent is delegation, not isolation
do not invoke superpowers:using-git-worktrees when provider is codex_managed_worktree
fallback is forbidden after native task creation
gate_premerge workspace rules
```

For `resolve-issue`, add a setup fixture whose kernel collector observes `shared_subagent`/same checkout and assert setup exits nonzero with the workspace-isolation rule. Add detached native reality that passes setup/implementation collection, then assert `gate_premerge` rejects publication until a second independent collection observes a branch.

- [ ] **Step 2: Run focused owner tests RED**

Run:

```bash
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: at least the new adapter-contract and missing-receipt scenarios fail because current skills and setup validators do not know the receipt contract.

- [ ] **Step 3: Update implementation skill and metadata**

Add a `## Workspace Isolation Adapter` section to `skills/implement-plan/SKILL.md` and its startup-visible summary to `agents/openai.yaml`:

```markdown
Before code edits, resolve the isolation request with `scripts/workspace-isolation.sh`, treating its output as untrusted policy direction. After native or local workspace mutation, invoke the registered execution-kernel read-only workspace collector. The collector independently inspects coordinator/workspace paths, Git common directory, actual HEAD/branch, Codex project/task/workspace identity, and duplicates and binds them to the lifecycle envelope. Do not invoke `superpowers:using-git-worktrees` for a native decision. A shared subagent is delegation, not isolation. Fallback is forbidden after native task creation. Detached native HEAD is valid for implementation; kernel `gate_premerge` must observe a branch before publication.
```

Change Execution step 3 to reference this adapter rather than unconditionally creating a branch/worktree.

- [ ] **Step 4: Update issue-resolution setup collection and validation**

Extend `prepare-execution` output with a kernel `CollectionRequest` locator, never a caller-supplied receipt. In setup, require a registered `workspace_reality@1` collector result bound to the issue-derived repository/run/candidate and coordinator identity. Detached native reality may pass implementation setup; branch state is independently recollected for premerge.

Update `skills/resolve-issue/SKILL.md` and metadata with the same agent/native boundary and add an explicit transition check before push permission:

```markdown
The shell adapter returns an untrusted action request; the active agent invokes native Codex task operations, then the execution kernel independently collects their reality. Never describe a same-checkout collaboration subagent as the workspace provider. Before `project_resolve_push_permission`, require a current kernel premerge receipt whose workspace publication rule passes.
```

- [ ] **Step 5: Run implementation and resolution scenarios GREEN**

Run:

```bash
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
python3 -m unittest tests.test_workspace_isolation -v
```

Expected: all commands exit `0`; missing receipts and shared-subagent claims are rejected inside the harness, detached native setup passes, and push without a branch transition fails as expected.

- [ ] **Step 6: Commit owner preflight checkpoint**

```bash
git add skills/implement-plan skills/resolve-issue
git commit -m "Require kernel workspace evidence before execution"
```

### Task 5: Orchestrated Worker Handoff Contract

**Use Cases:**

- The orchestrator requests one native project worktree task per executable issue when Codex task operations are available.
- A collaboration subagent may implement delegated work only after the orchestrator binds it to separately observed workspace evidence; the subagent identity itself proves nothing.
- Worker packets carry repository, run, candidate, source artifact `HashRef` values, authorization `HashRef`, and a kernel workspace-evidence reference without repeating large prompt prose.
- A packet from another repository, issue candidate, workspace, or head fails worker acceptance evidence.
- Native isolation prevents duplicate `.worktrees` creation and suppresses vanilla creation steps.
- The prose-only `branch_worktree_policy` path is retired as proof while remaining descriptive during migration.

**Files:**

- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/prepare-worker-handoff.sh`
- Modify: `skills/orchestrate-issues/scripts/validate-worker-handoff.sh`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.sh`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `docs/superpowers/examples/worker-handoff-packets.md`

**Interfaces:**

- Consumes: executable issue mirror, lifecycle identity, kernel `HashRef` values for source spec/plan/authorization, registered workspace-evidence item reference, required validation commands, and expected return schema.
- Produces: worker handoff with `workspace_evidence_ref`, `artifact_bindings`, and `expected_return_evidence`; handoff validation verifies kernel references and leaves reality acceptance to kernel collection/gates.

- [ ] **Step 1: Write RED worker packet scenarios**

In `skills/orchestrate-issues/scripts/test-scenarios.sh`, build a happy handoff with a kernel `workspace_evidence_ref`, then add negative scenarios that remove the reference, substitute an unknown evidence kind/collector, change `candidate_id`, corrupt its kernel `HashRef`, or bind another coordinator. Each scenario must invoke the handoff validator and fail on the mismatched reference; same-checkout and reality failures belong to the collector/gate tests.

Update `docs/superpowers/examples/worker-handoff-packets.md` fixture expectation in `scripts/test-worker-packets.sh` to require a redacted kernel `workspace_evidence_ref` and `HashRef` artifact bindings.

- [ ] **Step 2: Run worker tests RED**

Run:

```bash
./skills/orchestrate-issues/scripts/test-scenarios.sh
./scripts/test-worker-packets.sh
```

Expected: the new missing/malformed receipt scenarios fail because the current handoff validator accepts packets without provider evidence, and the examples validator reports missing fields.

- [ ] **Step 3: Extend handoff preparation arguments and packet shape**

Change `command_prepare_worker_handoff` to require `WorkspaceEvidenceRef`, `WorkflowRunRef`, `CandidateRef`, `SourceSpecRef`, `SourcePlanRef`, and `AuthorizationRef`, all parsed through the kernel `HashRef` type. Construct:

```python
"workspace_evidence_ref": workspace_evidence_ref,
"artifact_bindings": {
    "workflow_run": workflow_run_ref,
    "candidate": candidate_ref,
    "source_spec": source_spec_ref,
    "source_plan": source_plan_ref,
    "authorization": authorization_ref,
},
"expected_return_evidence": {
    "workspace_evidence_ref": workspace_evidence_ref,
    "required_validation_commands": proof,
    "merge_owner": "merge-changes",
},
```

Keep `branch_worktree_policy` as descriptive text set from the provider, but remove it from all proof decisions.

- [ ] **Step 4: Make worker validation consume the kernel**

Change `command_validate_worker_handoff` to require the three structured objects, parse all references with kernel `HashRef`, and verify exact lifecycle/artifact reference equality. It must not claim that reference validation proves workspace reality; the receiving worker triggers fresh kernel collection before editing.

Return:

```python
{"ok": True, "phase": "validate-worker-handoff", "reason": "worker handoff references passed", "evidence": {"workspace_evidence_ref": str(workspace_evidence_ref), "candidate_ref": str(candidate_ref), "recollection_required": True}}
```

- [ ] **Step 5: Update orchestration instructions and redacted examples**

Make the procedure sequence explicit: resolve provider, execute native operation when requested, run kernel reality collection, bind the resulting evidence `HashRef`, then create the collaboration worker. The receiver recollects reality before editing. State that subagents are never proof and native selection suppresses vanilla creation. Examples contain redacted kernel references, never real paths or task IDs.

- [ ] **Step 6: Run worker handoff GREEN tests**

Run:

```bash
./skills/orchestrate-issues/scripts/test-scenarios.sh
./scripts/test-worker-packets.sh
python3 -m unittest tests.test_workspace_isolation -v
```

Expected: all commands exit `0`; happy local and detached-native packets pass, all malformed/shared/mismatched packets are rejected inside the harness, and examples contain no real absolute workspace path.

- [ ] **Step 7: Commit worker contract checkpoint**

```bash
git add skills/orchestrate-issues scripts/lib/superpowers_project_cli.py docs/superpowers/examples/worker-handoff-packets.md
git commit -m "Bind worker handoffs to workspace evidence"
```

### Task 6: Merge Transition, Provider Cleanup, And End-To-End Trials

**Use Cases:**

- PR-backed merge intake rejects detached native evidence without a branch-bound provider transition.
- Local-branch merge intake accepts a named local provider receipt and exact integration evidence.
- App-owned native workspaces receive logical disposition only; user-owned workspaces remain reported; plugin-owned local worktrees remove only their recorded path.
- An installed Codex app trace proves a visible project worktree task, detached start, supported branch/handoff transition, no duplicate `.worktrees`, and unchanged vanilla source.
- A terminal-only trace proves vanilla fallback, a valid local receipt, and plugin-owned exact cleanup.
- Cutover acceptance evidence proves no owner route still treats `branch_worktree_policy` or a shared subagent as isolation proof.

**Files:**

- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/collect-premerge-ledger.sh`
- Modify: `skills/merge-changes/scripts/premerge.sh`
- Modify: `skills/merge-changes/scripts/closeout.sh`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Create: `docs/superpowers/examples/workspace-isolation-receipts.md`
- Create: `tests/fixtures/workspace_isolation/native-detached.json`
- Create: `tests/fixtures/workspace_isolation/local-branch.json`
- Create: `scripts/test-workspace-isolation-trials.sh`
- Modify: `scripts/lib/command_catalog.py`
- Modify: `scripts/lib/superpowers_project_cli.py`
- Modify: `scripts/validate.sh`

**Interfaces:**

- Consumes: premerge ledger with workspace receipt and transition, integration proof with exact workspace ID, recorded native/local trial traces, vanilla checksum manifest, and repository filesystem observation.
- Produces: validated `workspace_transition`, provider cleanup action, closeout evidence, redacted trial examples, and aggregate validator receipt.

- [ ] **Step 1: Add RED merge and trial scenarios**

Extend merge scenarios with:

1. detached native PR intake without transition, expected rejection containing `branch-bound transition`;
2. detached native PR intake with matching `create_branch` transition, expected pass;
3. native cleanup, expected `physical_removal_allowed=false`;
4. plugin local cleanup with wrong workspace ID, expected rejection;
5. user cleanup, expected report-only action.

Create `scripts/test-workspace-isolation-trials.sh` as the standard launcher and register `command_test_workspace_isolation_trials`. Its handler must initially fail because fixture examples are absent, proving the new aggregate gate detects missing evidence.

- [ ] **Step 2: Run merge/trial tests RED**

Run:

```bash
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/test-workspace-isolation-trials.sh
```

Expected: exit `1` for the new merge transition scenarios or missing trial fixtures. Confirm the failures name workspace transition/fixture evidence, not unrelated parser errors.

- [ ] **Step 3: Collect and validate merge workspace evidence**

Add registered `workspace_reality@1` to the kernel premerge collection request. In kernel premerge validation:

- validate repository/run/candidate/coordinator and current-head kernel bindings;
- require independently observed named-branch state for PR intake and permit detached state only outside publication gates;
- reject shared/same-checkout reality, duplicate worktrees, or evidence `HashRef` mismatch;
- include provider, workspace ID, transition branch, and cleanup owner in review evidence.

Update the merge skill and metadata to forbid Git edits to app-owned metadata and broad `git worktree prune` as candidate cleanup.

- [ ] **Step 4: Enforce receipt-owned closeout cleanup**

Extend kernel `gate_closeout` with workspace disposition and cleanup-ownership rules after integration proof. Execute physical removal only when the passing closeout receipt authorizes the independently collected exact plugin-owned path; use logical disposition for app ownership and report-only disposition for user ownership. Never derive a deletion path from caller JSON, scans, or task names.

- [ ] **Step 5: Add redacted provider examples and fixtures**

Create native and local fixtures through the kernel serializer and `HashRef` constructors so hashes are valid. Document:

- native detached receipt and its matching branch transition;
- local named-branch receipt and exact cleanup authorization;
- shared-subagent rejection;
- mismatched candidate rejection;
- committed redaction rule for task IDs and paths.

The fixture JSON uses stable values such as `/redacted/codex-worktree`, `/redacted/local-worktree`, `task-fixture-1`, and forty-character test SHAs.

- [ ] **Step 6: Implement the trial evidence validator**

Add `command_test_workspace_isolation_trials` that loads both fixtures through the kernel parser, runs premerge/closeout workspace rules, checks zero native duplicates and local vanilla invocation, verifies the vanilla checksum manifest, and confirms shared-subagent rejection. Wire it into `scripts/validate.sh` after execution-kernel tests.

- [ ] **Step 7: Run focused GREEN verification**

Run:

```bash
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/test-workspace-isolation-trials.sh
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/orchestrate-issues/scripts/test-scenarios.sh
./scripts/test-worker-packets.sh
python3 -m unittest tests.test_workspace_isolation tests.test_command_registry tests.test_command_surface -v
```

Expected: every command exits `0`; the harness reports the intended negative cases rejected, native cleanup remains logical, and local cleanup is exact-path-only.

- [ ] **Step 8: Run installed-app acceptance trial before final release proof**

From a fresh Codex desktop task on this project, request required isolation and execute the adapter's native action. Record ephemeral evidence with project/task/workspace identifiers, detached HEAD, repository identity, candidate binding, branch or Handoff transition, and logical disposition. Verify no repo-local `.worktrees` directory appears and compare checksums of the installed vanilla `superpowers:using-git-worktrees` source before/after. Redact identifiers before copying any evidence into committed examples.

Expected: visible project worktree task exists, receipt validation passes, initial `head_mode=detached`, supported transition passes publication validation, `repo_local_worktrees_created=0`, and vanilla checksums match exactly. Stop if the runtime cannot expose enough observable state; do not fabricate the receipt.

- [ ] **Step 9: Run terminal-only acceptance trial**

With `codex_project_tasks=false` and `local_git_worktrees=true`, resolve required isolation, invoke `superpowers:using-git-worktrees`, independently collect local workspace reality, validate branch mode through the kernel, and verify closeout authorization points only to that collected path.

Expected: provider is `local_git_worktree`, operation is `invoke_vanilla_worktree_skill`, kernel evidence validates, and the closeout receipt authorizes only the exact collected workspace identity/path.

- [ ] **Step 10: Run full verification and outcome-proof review**

Run:

```bash
./scripts/validate-plan-outcome-proof.sh -PlanPath docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md
./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md
./scripts/validate-decision-ledger.sh -Path docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md -Kind plan
./scripts/validate.sh
git diff --check
bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .
```

Expected: every command exits `0`, all JSON validators report `ok: true`, the complete repository suite has zero failures, `git diff --check` is silent, and cleanup reports no task-owned residue.

Review every source-spec acceptance criterion against the task evidence. Confirm the target output is visible to owner skills, the old proof path is displaced, and installed/non-Codex evidence proves both providers.

- [ ] **Step 11: Commit the merge/trial checkpoint**

```bash
git add skills/merge-changes docs/superpowers/examples/workspace-isolation-receipts.md tests/fixtures/workspace_isolation scripts/test-workspace-isolation-trials.sh scripts/lib/command_catalog.py scripts/lib/superpowers_project_cli.py scripts/validate.sh
git commit -m "Complete provider-aware workspace lifecycle"
```

- [ ] **Step 12: Complete the required post-revision deployment loop**

Only after all intended source changes are committed, run in order. Stop before sync/install/deploy if `git status --short` contains uncommitted source changes:

```bash
./scripts/validate.sh
./scripts/sync-live.sh --validate
codex plugin add superpowers-project@personal --json
./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .
git status --short --branch
```

Expected: validation and sync exit `0`; plugin add reports the current personal snapshot; the banner/version check confirms current source and installed versions; cleanup passes; and Git status shows the expected clean main/feature integration state. Tell the user to start a fresh Codex session so the revised skill text loads.

## Verification Matrix

| Requirement | Primary proof | Negative proof |
|---|---|---|
| Prefer native project worktree | Native selection unit test and installed-app trace | Native unavailable selects local only |
| Shared subagent is not isolation | Reality collector and worker reference rejection | No shared-subagent observation can pass kernel gates |
| Preserve vanilla skill | Before/after checksum manifest | Any checksum drift fails trial validator |
| Native suppresses `.worktrees` | Installed-app filesystem trace | `repo_local_worktrees_created > 0` fails |
| Detached HEAD accepted for work | Transition unit and resolve setup scenarios | Push/PR without transition fails |
| Branch-bound publication | Matching transition scenario | Wrong workspace/hash/branch fails |
| Provider-owned cleanup | Merge and kernel ownership tests | App/user delete and mismatched local ID fail |
| Local fallback remains safe | Terminal-only trace | No local capability plus required isolation fails |
| Context remains bound | Worker packet artifact bindings | Repository/run/candidate mismatch fails |
| Owner routes use one contract | Four skill scenario suites | Prose-only policy packet fails |

## Rollback And Failure Boundaries

- If provider selection fails before mutation, return the structured blocker and leave the current checkout unchanged.
- If native task creation/fork succeeds but observation or receipt validation fails, record the task ID as unresolved app-owned state, do not create a local fallback, and route to Revisit.
- If local worktree creation fails, follow vanilla safety recovery and do not emit a receipt.
- If a receipt becomes stale after head movement, collect a new provider observation and produce a new receipt bound to the same run/candidate; never edit the old hash in place.
- If publication transition fails, retain the isolated workspace and route through supported Codex Create Branch/Handoff or local branch repair.
- If cleanup authorization fails, leave the workspace intact and report ownership ambiguity. Safety takes precedence over tidy state.
- Rollback may revert this plugin's adapter commits, but must not modify vanilla skill files, Codex app metadata, or user-owned worktrees.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Isolation adapter source of truth | Approved spec and cross-plan review | Use domain policy plus the execution kernel evidence/gate stack. | All owner routes share registered collectors, `HashRef`, envelopes, and receipts. | No | Runtime owner |
| Native operation boundary | Codex task APIs are agent/app operations, not shell APIs | Shell returns action requests; after mutation, kernel collectors independently inspect reality. | Agent claims cannot become passing evidence. | No | Workspace owner |
| Native provider preference | User requirement | Prefer matching/adopted or newly forked/created Codex project worktree tasks. | Codex work is visible and app-managed. | No | Orchestration owner |
| Create versus fork | Spec unresolved decision resolved during planning | Prefer fork when a suitable project task provides approved context; create otherwise. | Context is retained without requiring every native task to share conversation history. | No | Orchestration owner |
| Shared subagents | Runtime observation and approved spec | Treat as delegation only, never filesystem isolation. | Worker names and summaries cannot satisfy isolation gates. | No | Validation owner |
| Vanilla compatibility | User constraint | Invoke upstream `superpowers:using-git-worktrees` unchanged only for local fallback. | CLI hosts retain established worktree safety behavior. | No | Skill owner |
| Detached HEAD | Codex native behavior | Permit detached execution and require provider transition before publication. | Native work starts without unsafe ad hoc branch manipulation. | No | Git owner |
| Evidence persistence | Privacy risk in approved spec | Keep full observations ephemeral, reuse kernel `HashRef`, and commit redacted fixtures only. | Proof remains auditable without leaking machine-specific data. | No | Evidence owner |
| Native fallback | Approved error handling | Allow local fallback only before native task creation. | One candidate cannot orphan duplicate native and local workspaces. | No | Workspace owner |
| Cleanup ownership | Approved spec | App/user ownership never authorizes plugin filesystem deletion; plugin local ownership authorizes exact recorded path only. | Broad prune and metadata deletion are blocked. | No | Cleanup owner |
| App task archival | User-visible external-state boundary | Record logical disposition but do not auto-archive in this implementation. | Physical lifecycle stays app-owned; explicit archival product policy remains a later product decision. | Yes | Product owner |
| Cutover | Audit evidence | Require registered workspace evidence in execution and merge gates in one revision. | Prose and skill-name evidence becomes descriptive only. | No | Migration owner |
| Completion proof | Approved outcome proof | Require native trace, local trace, negative shared-subagent trace, no-`.worktrees` trace, and vanilla checksum equality. | Both provider paths and the displaced path are observable. | No | Verification owner |
| Trust boundary | Cross-plan review | Treat caller JSON as request input and accept only read-only kernel observations. | Workspace reality is independently corroborated. | No | Validation owner |
| Implementation order | Cross-plan review | Merge kernel and lifecycle first, then rebase this work. | Code targets landed identities and gates instead of speculative duplicates. | No | Integration owner |
| Deployment order | Repository post-revision policy | Commit before sync, install, or deploy. | Deployed state derives from an auditable source commit. | No | Release owner |

## Plan Self-Review

- Spec coverage: Tasks 1 and 2 implement provider policy plus registered schema and independent reality collection; Tasks 3 through 6 extend kernel gates, integrate owner routes, and prove both providers.
- Scope: The plan does not redesign Auto/Loop authority, release evidence gates, workflow graph normalization, or vanilla Superpowers.
- Interface consistency: All later tasks consume registered `workspace_reality@1`, kernel `HashRef`, `EvidenceEnvelope`, `GateReceipt`, provider names, and repository/run/candidate/coordinator bindings.
- TDD order: Every production behavior has a focused failing test or scenario before its implementation step, followed by focused GREEN and broader regression verification.
- Displaced path: Branch/agent labels, prose policy, and required-skill membership remain human-readable but no longer pass isolation validation.
- Placeholder scan: The plan contains no deferred implementation marker; the one deferred product decision has an explicit current behavior, owner, and safe boundary.
- Outcome proof: Both runtime perspectives, native Codex and terminal-only local Git, have concrete target-visible trial evidence and stop conditions.
