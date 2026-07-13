# Codex-Native Workspace Isolation Implementation Plan

> Execute test-first. Reuse the issue #113 evidence kernel and issue #114 lifecycle; do not add a parallel workspace subsystem.

**Goal:** Prefer visible Codex-managed worktrees when available, preserve safe vanilla local-worktree fallback, and enforce provider-aware publication and logical disposition with the existing `workspace_receipt`.

**Architecture:** One small pure policy module selects a provider from lifecycle requirement and observed capabilities. The existing execution kernel owns receipt hashing, envelope binding, freshness, and gate receipts. Owner skills execute native Codex actions or invoke vanilla fallback and record the resulting cooperative provider observation.

## Constraints

- Keep vanilla `superpowers:using-git-worktrees` unchanged.
- A shared subagent is delegation, never isolation.
- Native selection suppresses local worktree creation.
- Local fallback is forbidden after a native task is created.
- Detached native HEAD is valid for implementation, not publication.
- Never claim host cryptographic attestation; Codex exposes no signed task receipt.
- Workspace receipts grant no physical-removal path; local cleanup remains under independently proven vanilla worktree provenance.
- Use the existing `workspace_receipt`, `EvidenceEnvelope`, `workspace_rule`, and receipt chain.
- Do not add `workspace_reality`, a second serializer, workspace-specific gate receipts, generated trial corpora, or app metadata access.

## Outcome Proof

**Intent:** Make project implementation use the correct isolated workspace provider without confusing same-checkout delegation for isolation.

**Current Behavior:** Skills request worktrees in prose, worker routing can imply subagents are isolated, and the existing generic receipt does not yet enforce provider/head-mode semantics.

**Expected Outcome:** Provider selection is deterministic; workspace receipts are schema- and branch-aware; publication and logical disposition follow provider ownership; owner skills share the same concise rules.

**Target Output:** One provider-policy module and launcher, strengthened existing workspace rule, focused tests, and small owner-skill updates.

**Owner:** Superpowers Project workspace policy and the existing execution kernel.

**Interface:** `resolve_workspace_isolation(request, capabilities) -> decision`; existing registered `workspace_receipt` evidence; existing PR-ready/premerge/closeout gates.

**Cutover:** Owner routes use provider selection before editing and record version-1 workspace receipts through the existing evidence path.

**Replaced Path:** Unconditional vanilla worktree invocation, subagent-as-worktree language, detached publication, and ambiguous cleanup ownership.

**Evidence:** Focused unit and gate tests plus owner-skill scenarios and full repository validation.

**Acceptance Proof:** `python3 -m unittest tests.test_workspace_isolation tests.test_gate_pr_ready tests.test_gate_premerge tests.test_gate_closeout -v`, four owner scenario scripts, `./scripts/test-worker-packets.sh`, and `./scripts/validate.sh`.

**Stop Criteria:** Stop on unavailable required isolation, mismatched lifecycle/repository/head binding, native-task ambiguity, detached publication, or cleanup ownership ambiguity.

**Avoid:** Avoid app metadata access, duplicate worktrees, caller-authorized proof, new receipt stacks, generated evidence fixtures, and broad cleanup.

**Risk:** Native task observations are cooperative rather than host-signed; document that boundary and rely on deterministic kernel binding/freshness rather than overstating trust.

## Implementation Boundaries

**Files To Create:** `scripts/lib/workspace_isolation.py`, `scripts/workspace-isolation.sh`, and `tests/test_workspace_isolation.py`.

**Files To Modify:** Existing workspace rule/gates, command registration, runtime package manifest, the four owner skills and focused scenarios, worker handoff example/validation only where needed, this plan/spec/mirror, and validation wiring only if a new focused launcher requires it.

**Files To Avoid:** Plugin caches, deployed copies, vanilla Superpowers, Codex app metadata, unrelated lifecycle/release code, generated trial receipts, and historical evidence.

**Source Of Truth:** Provider choice lives in `workspace_isolation.py`; evidence trust and receipt chaining remain in the issue #113 kernel.

**Read Path:** Lifecycle isolation requirement, observed native/local capabilities, optional matching current-workspace identity, and current Git state.

**Write Path:** Source/tests/docs plus ephemeral workflow evidence through existing collectors.

**Integration Points:** `workspace_rule`, PR-ready/premerge/closeout gates, owner skills, worker handoff validation, command catalog, and runtime package manifest.

**Migration Or Cutover:** New executions require version-1 provider semantics; historical receipts remain historical and do not gain publication authority.

**Replaced Path Handling:** Descriptive worktree prose may remain for readability but cannot substitute for a valid current receipt.

**Acceptance Proof Gate:** No merge until focused tests, scenarios, full validation, independent review, CI, and the repository deployment loop pass.

## Task 1: Provider Policy And Receipt Semantics

**Use Cases:**

- Native capability prefers a matching/adopted Codex worktree; otherwise it requests fork/create.
- Terminal-only capability invokes vanilla fallback, while required isolation fails without a provider and shared subagents fail.
- Acceptance evidence covers provider choice and the cutover retires unconditional local-worktree creation.

1. Add failing table-driven tests for provider selection, matching adoption, shared-subagent rejection, and post-native fallback rejection.
2. Run the focused tests and confirm the missing-module/behavior RED failure.
3. Implement the smallest pure `resolve_workspace_isolation` policy.
4. Add failing tests for version-1 receipt fields, supported providers/owners, branch/head-mode consistency, and stale/mismatched bindings.
5. Extend the existing workspace rule; do not register a new evidence kind.
6. Run focused provider and gate tests GREEN.

## Task 2: Public Policy Adapter And Owner Routes

**Use Cases:**

- Shell returns an untrusted action request, never a native-operation claim.
- Owner skills adopt native worktrees or invoke vanilla fallback exactly once; detached native work can implement but cannot push.
- Scenario proof covers provider-owned logical disposition and displaces subagent-as-isolation language.

1. Add failing command registration/surface tests for a mutation-free `scripts/workspace-isolation.sh` policy launcher.
2. Register a thin handler that rejects caller observation/receipt/head/path fields and emits only the provider action decision.
3. Add failing scenario assertions to `implement-plan`, `resolve-issue`, `orchestrate-issues`, and `merge-changes` for the shared policy rules.
4. Update the four skills and startup metadata concisely; do not add a second workflow layer.
5. Bind worker handoff validation to the existing workspace receipt/hash only if current packet validation lacks that reference.
6. Run command, owner scenario, and worker packet tests GREEN.

## Task 3: Verification And Release

**Use Cases:**

- Native and local policy paths are deterministic, negative cases fail, and vanilla source is unchanged.
- Acceptance evidence contains no generated runtime receipts and proves the old ambiguous provider path is retired.
- Deployment derives from a committed source state.

1. Run the plan validators and focused proof oracle.
2. Run `./scripts/validate.sh` and `git diff --check`.
3. Obtain independent architecture and code review; repair only evidenced findings.
4. Commit the intended source changes.
5. Run `./scripts/sync-live.sh --validate`, marketplace refresh, version banner, cleanup, and clean-status checks.
6. Push, open a PR closing #115, wait for CI, and merge only on green evidence.

## Proof Oracle

```bash
python3 -m unittest tests.test_workspace_isolation tests.test_gate_pr_ready tests.test_gate_premerge tests.test_gate_closeout tests.test_command_registry tests.test_command_surface -v
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/orchestrate-issues/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/test-worker-packets.sh
./scripts/validate-plan-outcome-proof.sh -PlanPath docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md
./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md
./scripts/validate-decision-ledger.sh -Path docs/superpowers/plans/2026-07-10-codex-native-workspace-isolation-plan.md -Kind plan
./scripts/validate.sh
```

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Evidence model | Landed #113 kernel | Extend `workspace_receipt`; add no parallel evidence kind. | Smaller implementation and one trust path. | No | Runtime owner |
| Native trust | Codex capability boundary | Treat native details as cooperative provider observations. | No false host-attestation claim. | No | Workspace owner |
| Native preference | Approved spec | Adopt matching native workspace, then fork/create. | Avoid duplicate worktrees. | No | Workflow owner |
| Local fallback | Cross-host requirement | Invoke vanilla unchanged only when native is unavailable and not started. | Terminal hosts remain safe. | No | Skill owner |
| Detached HEAD | Codex behavior | Allow work; require a fresh branch receipt to publish. | Native tasks remain usable without weakening publication. | No | Git owner |
| Cleanup | Provider ownership | Receipts authorize logical disposition only; vanilla finishing retains independent local-worktree provenance. | Prevent destructive cleanup. | No | Cleanup owner |
| Deployment order | Repository policy | Commit, validate/sync/install/version/cleanup, then publish. | Auditable release state. | No | Release owner |

## Plan Self-Review

- Three tasks cover policy, route integration, and release without duplicating the execution kernel.
- Every production behavior starts with a focused RED test.
- The plan adds one small production module and one standard launcher only.
- Native limitations are stated honestly.
- Generated trial runs and app metadata are outside scope.
