# Score 9+ And Looping Mode Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Superpowers Project workflow contract, metadata, Looping Mode, examples, and scorecard proof strict enough to support a 9+ workflow-quality audit.

**Architecture:** Use the promoted score 9+ spec as the source of truth, create issue-backed repair slices, and strengthen validators before relying on docs. The workflow contract becomes typed and option-authoritative, metadata is validated against continuation geometry, Looping Mode gains a state-machine contract, and final completion is recorded by a scorecard receipt plus live-sync and tracker proof.

**Tech Stack:** Bash validators and fixtures, YAML workflow contract, Markdown skill/spec/plan/docs, GitHub issue mirrors, Loop Controller ledgers, existing Superpowers Project validation scripts, and GitHub CLI issue/PR workflow.

---

## Source Spec

- `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`

## Test-Complete Definition

Test complete means every new or changed validator has passing and failing fixtures where practical, known contract/SKILL/YAML mismatches are repaired, Looping Mode state-machine fixtures cover the required unsafe states, the scorecard receipt validates every target at `>= 9`, `scripts/validate.sh` passes, `scripts/sync-live.sh --validate` passes, version freshness passes, GitHub-aware align/tracker hygiene passes or records only documented non-blocking findings, the cleanup hook passes, and `git status --short --branch` is clean.

Pass/fail metrics are command exit codes, validator JSON receipts, exact fixture assertions, GitHub issue and PR state, and clean repository state. Numerical tolerances are not part of this workflow-plugin hardening plan; the measurable threshold is zero failing required validators and every scorecard target at least `9`.

## Outcome Proof

**Intent:** Raise Superpowers Project workflow quality to a validator-backed 9+ standard and make Looping Mode a predictable state machine.
**Current Behavior:** The project has a workflow contract, compact metadata, centralized policy, Decision Ledger requirements, Artifact Review Card schema, active backlog, examples, worker packets, and broad validation. The contract still has option drift, some native gates are not registered authoritatively, metadata can flatten child routes into top-level continuation summaries, Looping Mode is under-specified as a state machine, and no scorecard receipt proves 9+ quality.
**Expected Outcome:** Every material native gate is registered with gate type and exact options, metadata cannot flatten route geometry, route-local skill prose is clean, Looping Mode validates one candidate per iteration with required ledgers and gates, scorecard proof records every target at `>= 9`, project docs explain source-of-truth roles, and Decision Ledger examples validate.
**Target Output:** A merged issue-backed hardening program with strict validators, updated contract and docs, issue mirrors, a scorecard receipt, passing live-sync/tracker proof, and no ready backlog candidates left unintentionally.
**Owner:** `docs/superpowers/workflow-contract.yml` owns route contract data; `skills/loop-controller` owns loop coordination rules; `skills/advanced-user-input` owns shared native-question semantics; scripts under `scripts/` own validation proof; issue mirrors own slice execution.
**Interface:** Validators read YAML, Markdown skills, metadata YAML, examples, active backlog, generated run fixtures, scorecard receipts, GitHub issue state where needed, and Git status; they emit pass/fail receipts consumed by `scripts/validate.sh` and merge closeout.
**Cutover:** Tighten validators first, repair drift in contract/SKILL/YAML/docs, then rely on the strict contract and Looping Mode state machine for future workflow routing.
**Replaced Path:** Loose question-ID indexing, prose-only Looping Mode semantics, metadata route summaries that flatten nested routes, and subjective score claims stop being sufficient proof.
**Evidence:** Typed workflow contract, exact-option validator, metadata geometry validator, loop state-machine contract and fixtures, scorecard proof receipt, updated project context docs, Decision Ledger examples, issue mirrors, validation logs, live-sync proof, align/tracker proof, cleanup proof, and merged PR evidence.
**Acceptance Proof:** The proof oracle commands in each issue slice pass, followed by final `scripts/validate.sh`, `scripts/sync-live.sh --validate`, version freshness, scorecard validation, align/tracker hygiene, cleanup hook, and clean Git state.
**Stop Criteria:** Stop before push or merge if a validator is weaker than the spec requires, if a native gate cannot be mapped to exact contract options, if Looping Mode can select a second candidate without `project_loop_next_step`, if scorecard proof is subjective, or if source/live/tracker proof is incomplete.
**Avoid:** Do not create a new user-facing workflow skill, do not weaken native gates, do not treat `.chatgpt/**` or `.superpowers/**` as canonical docs, do not keep compatibility wrappers for obsolete behavior, do not use one giant implementation issue when issue-backed slices are available.
**Risk:** The highest risk is overfitting validators to current text while still missing actual route geometry drift. The plan mitigates this by parsing real `Question id:`, `Prompt:`, and `Options:` blocks from active `SKILL.md` files.

## Implementation Boundaries

**Files To Create:** `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`, optional `docs/superpowers/loop-mode-contract.yml`, `scripts/validate-loop-state-machine.sh`, `scripts/test-loop-controller.sh`, `scripts/validate-scorecard-proof.sh`, `scripts/test-scorecard-proof.sh`, `docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md`, `docs/superpowers/examples/decision-ledger-examples.md`, and issue mirrors under `docs/superpowers/issues/`.
**Files To Modify:** `docs/superpowers/workflow-contract.yml`, `skills/*/SKILL.md`, `skills/*/agents/openai.yaml`, `skills/loop-controller/scripts/*.sh`, `scripts/validate-workflow-contract.sh`, `scripts/test-workflow-contract.sh`, `scripts/validate-skill-metadata-contract.sh`, `scripts/test-skill-metadata-contract.sh`, `scripts/validate-global-policy-deduplication.sh`, `scripts/test-artifact-review-card.sh`, `scripts/validate-workflow-examples.sh`, `scripts/validate.sh`, `docs/superpowers/PROJECT_CONTEXT.md`, `README.md`, `docs/superpowers/OUTCOME_WORKFLOW.md`, milestone pages, and `docs/superpowers/backlog/ACTIVE.md`.
**Files To Avoid:** deployed live plugin copies, plugin cache paths, `.chatgpt/**` after source promotion, committed `.superpowers/**` run ledgers, unrelated workspaces, and retired milestone-local canonical artifact roots.
**Source Of Truth:** This plan and the promoted source spec drive issue creation; after Task 1, `docs/superpowers/workflow-contract.yml` and any loop-mode contract file own the route and loop state contracts.
**Read Path:** Validators read skill Markdown, metadata YAML, workflow contract YAML, loop contract YAML, examples, issue mirrors, active backlog, milestone receipts, Git tracked state, and generated fixture run roots.
**Write Path:** Source edits happen only in this repo. Live install proof is produced by `scripts/sync-live.sh --validate` after source validation passes.
**Integration Points:** `scripts/validate.sh`, `scripts/sync-live.sh`, `scripts/get-agent-plugin-version.sh`, `skills/align-project/scripts/align-project.sh`, loop-controller ledgers, create-issues mirrors, resolve-issue PR-ready proof, and merge-changes closeout proof.
**Migration Or Cutover:** Add strict tests first, update validators and contracts until failures are meaningful, repair content drift, then wire new validators into full validation and scorecard proof.
**Replaced Path Handling:** Remove stale route summaries, machine-patched duplicate prose fragments, and any metadata text that lists child routes as top-level options beside terminal labels.
**Acceptance Proof Gate:** No issue slice is merge-ready until its focused validators and relevant full validation subset pass; the program is not final Done until every issue slice is merged and final proof oracle commands pass.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Source artifact | User request and promoted spec | Use `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`. | Keeps `.chatgpt` as handoff input and moves canonical planning into repo-owned docs. | No | `write-plan` |
| Execution model | `project_workflow_mode` answer | Looping Mode with issue-backed slices. | Loop Controller coordinates repeated candidates, while route owner skills do planning, issue creation, implementation, and merge closeout. | No | `loop-controller` |
| Issue slicing | Source spec proposed issue list | Seven slices in the proposed order. | Each workstream has independent acceptance criteria and proof, avoiding one oversized implementation issue. | No | `create-issues` |
| Validator priority | Source spec selected design | Make workflow contract and Looping Mode validators stricter before docs polish. | Prevents documentation from claiming 9+ before route geometry and loop state are actually enforced. | No | `resolve-issue` |
| Final proof level | Source spec final Done criteria | Require full validation, live sync, version freshness, scorecard, align/tracker, cleanup, and clean Git proof. | Merge closeout needs concrete receipts, not subjective audit language. | No | `merge-changes` |

## Acceptance Criteria

- [ ] Canonical spec exists under `docs/superpowers/specs/`.
- [ ] Seven issue-backed slices are created in the order listed below.
- [ ] `workflow-contract.yml` has typed gates and exact option validation against `SKILL.md`.
- [ ] Metadata geometry validation rejects flattened top-level continuation summaries.
- [ ] Prose cleanup removes machine-patched duplicate fragments without weakening route-specific artifact inventories.
- [ ] Looping Mode has a documented phase/state contract and validator fixtures for one-candidate iteration, no-ready, budget exhaustion, dirty repo, Auto Mode misuse, owner mismatch, and historical checkbox rejection.
- [ ] Scorecard receipt validates every target area at `>= 9` with command receipts and source links.
- [ ] Project context docs explain workflow contract, active backlog, examples, receipts, `.chatgpt/**`, and `.superpowers/**` roles.
- [ ] Decision Ledger examples validate for spec and plan shapes and are referenced by `brainstorm-spec` and `write-plan`.
- [ ] Final `scripts/validate.sh`, `scripts/sync-live.sh --validate`, version freshness, align/tracker hygiene, cleanup hook, and clean Git state pass.

## Non-Goals

- Add a new workflow skill.
- Bypass issue creation for the seven hardening slices.
- Treat Auto Mode as permission to drain a queue.
- Make GitHub Projects mandatory beyond existing tracker hygiene proof.
- Commit generated `.superpowers/runs/**` runtime ledgers.
- Edit deployed live copies directly.

## Issue Slices

Create seven issue mirrors from this plan:

1. P1 Authoritative Gate Types And Exact Option Validation.
2. P1 Metadata Geometry Guardrails.
3. P1 Register All Material Native Gates.
4. P1 Looping Mode State Machine.
5. P2 Scorecard Proof Receipt And Project Context Narrative.
6. P2 Skill Prose Polish And Artifact Card Clarity.
7. P2 Decision Ledger Examples.

## Task 1: Authoritative Gate Types And Exact Option Validation

**Use Cases:**
- A maintainer changes a `SKILL.md` option label and validation fails until `workflow-contract.yml` is updated.
- A contract entry lists an option that does not exist in the owning skill, and validation blocks merge.
- A nested Yes-route includes `Stop`, and gate-type validation reports the invalid terminal option.

**Files:**
- Modify: `docs/superpowers/workflow-contract.yml`
- Modify: `scripts/validate-workflow-contract.sh`
- Modify: `scripts/test-workflow-contract.sh`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-workflow-contract.sh`

- [ ] **Step 1: Add failing fixtures for exact option mismatches**
  - Add fixtures for missing gate registration, extra contract option, extra skill option, invalid nested terminal option, approval gate, permission gate, topology gate, and final health gate.
  - Run: `./scripts/test-workflow-contract.sh`
- [ ] **Step 2: Extend the contract schema**
  - Add `gate_type`, `parent_question_id`, `parent_option`, effect mappings, and allowlist reasons where needed.
  - Register material prose gates such as `project_setup_board_approval` and `project_issue_resolution_route` or rewrite them into canonical blocks first.
- [ ] **Step 3: Parse real skill route blocks**
  - Extract `Question id:`, nearest `Prompt:`, and nearest `Options:` labels from workflow `SKILL.md` files.
  - Preserve exact backtick labels when comparing.
- [ ] **Step 4: Enforce gate-type rules**
  - Enforce top-level continuation, final health, nested Yes, nested Revisit, approval, permission, topology, repair, and data-selection rules.
  - Fail unregistered native-question-like identifiers unless explicitly allowlisted with a reason.
- [ ] **Step 5: Repair known drift**
  - Align `align-project`, `setup-project`, `merge-changes`, and `implement-plan` contract entries with their actual skill option labels.
- [ ] **Step 6: Validate**
  - Run: `./scripts/test-workflow-contract.sh`
  - Run: `./scripts/validate-workflow-contract.sh -RepoRoot .`

## Task 2: Metadata Geometry Guardrails

**Use Cases:**
- A compact metadata prompt points to `SKILL.md` and the workflow contract without restating route trees.
- A metadata prompt says a `*_next_step` gate has child routes beside `Stop`, and validation fails.
- Metadata can mention child routes only in clearly nested wording.

**Files:**
- Modify: `scripts/validate-skill-metadata-contract.sh`
- Modify: `scripts/test-skill-metadata-contract.sh`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-skill-metadata-contract.sh`

- [ ] **Step 1: Add metadata geometry fixtures**
  - Add passing safe-form fixtures and failing flattened top-level continuation fixtures.
  - Include unsupported option summaries for registered gates.
- [ ] **Step 2: Implement geometry checks**
  - Detect `*_next_step` summaries that list child route labels beside terminal labels.
  - Allow no route summary, exact top-level summary, or explicitly nested child-route summary.
- [ ] **Step 3: Repair metadata prompts**
  - Remove flattened route summaries from the named metadata files.
  - Keep compact pointers to `SKILL.md` and `docs/superpowers/workflow-contract.yml`.
- [ ] **Step 4: Validate**
  - Run: `./scripts/test-skill-metadata-contract.sh`
  - Run: `./scripts/validate-skill-metadata-contract.sh -RepoRoot .`

## Task 3: Register All Material Native Gates

**Use Cases:**
- A material native gate appears in prose and is either a registered `Question id:` block or a deliberate allowlisted non-gate.
- `project_setup_board_approval` is discoverable by contract validation.
- `project_issue_resolution_route` is discoverable by contract validation or removed from active prose.

**Files:**
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `docs/superpowers/workflow-contract.yml`
- Modify: `scripts/validate-workflow-contract.sh`
- Modify: `scripts/test-workflow-contract.sh`
- Test: `scripts/test-workflow-contract.sh`

- [ ] **Step 1: Inventory native-question-like identifiers**
  - Search active workflow skills for `project_[a-z0-9_]+` and `implement_plan_[a-z0-9_]+`.
  - Classify each as registered gate, generated fixture, legacy reference, or allowlisted non-gate.
- [ ] **Step 2: Convert prose-only material gates**
  - Add canonical `Question id:`, `Prompt:`, and `Options:` blocks where live native gates exist.
  - Register the exact gate in `workflow-contract.yml`.
- [ ] **Step 3: Add allowlist enforcement**
  - Require a reason for every identifier that is intentionally not a native gate.
  - Fail if a new identifier appears without registration or allowlist.
- [ ] **Step 4: Validate**
  - Run: `./scripts/test-workflow-contract.sh`
  - Run: `./scripts/validate-workflow-contract.sh -RepoRoot .`

## Task 4: Looping Mode State Machine

**Use Cases:**
- Looping Mode selects one ready candidate, routes to the owner skill, records proof, rechecks budget, and asks `project_loop_next_step` before selecting another candidate.
- Two ready candidates do not auto-drain without a recorded continuation answer.
- No-ready, budget-exhausted, dirty-repo, Auto Mode misuse, owner mismatch, and historical-checkbox cases are explicit validator outcomes.

**Files:**
- Create: `docs/superpowers/loop-mode-contract.yml`
- Create: `skills/loop-controller/scripts/validate-loop-state-machine.sh`
- Create: `scripts/test-loop-controller.sh`
- Modify: `skills/loop-controller/SKILL.md`
- Modify: `skills/loop-controller/scripts/select-candidate.sh`
- Modify: `skills/loop-controller/scripts/validate-run-ledger.sh`
- Modify: `skills/loop-controller/scripts/validate-budget.sh`
- Modify: `skills/loop-controller/scripts/validate-verifier-ledger.sh`
- Modify: `skills/loop-controller/scripts/validate-terminal-closeout.sh`
- Modify: `skills/loop-controller/scripts/test-scenarios.sh`
- Modify: `docs/superpowers/examples/workflow-golden-paths.md`
- Modify: `scripts/validate-workflow-examples.sh`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-loop-controller.sh`

- [ ] **Step 1: Define loop phases and invariants**
  - Document the required phase order and candidate-source precedence.
  - Record required ledgers and explain which ledgers may be absent before a phase is reached.
- [ ] **Step 2: Build loop state validator**
  - Validate phase order, one-candidate-per-iteration, continuation gate before next selection, candidate source, owner route, owner result, budget checks, final Done, no-ready proof, Auto Mode separation, dirty repo handling, and historical checkbox rejection.
- [ ] **Step 3: Add end-to-end fixtures**
  - Cover one ready candidate, two ready candidates without auto-drain, no-ready, Auto Mode misuse, budget exhausted, dirty repo, owner mismatch, and historical checkbox.
- [ ] **Step 4: Wire examples and validation**
  - Update the Looping Mode golden path so it matches the strict state machine.
  - Add the new tests and validator to `scripts/validate.sh`.
- [ ] **Step 5: Validate**
  - Run: `./scripts/test-loop-controller.sh`
  - Run: `./skills/loop-controller/scripts/test-scenarios.sh`

## Task 5: Scorecard Proof Receipt And Project Context Narrative

**Use Cases:**
- A future audit can inspect one receipt and see every score area mapped to source links and commands.
- The project context explains which files are source-of-truth, examples, receipts, active backlog, or generated runtime evidence.
- Milestone pages link the hardening receipt instead of burying proof in chat.

**Files:**
- Create: `docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md`
- Create: `scripts/validate-scorecard-proof.sh`
- Create: `scripts/test-scorecard-proof.sh`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `README.md`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`
- Modify: `docs/superpowers/milestones/M0-governance.md`
- Modify: `docs/superpowers/milestones/M1-source-of-truth.md`
- Modify: `docs/superpowers/backlog/ACTIVE.md`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-scorecard-proof.sh`

- [ ] **Step 1: Add scorecard receipt validator fixtures**
  - Fail missing evidence, target below `9`, missing command receipt, and missing Looping Mode proof.
  - Pass a receipt with every score area, source links, and command pass rows.
- [ ] **Step 2: Create the receipt**
  - Include scorecard table, command receipts, source artifact links, Looping Mode E2E proof, live sync proof, and tracker/align proof.
- [ ] **Step 3: Update source-of-truth narrative**
  - Document workflow contract, active backlog, examples, packet examples, milestone receipts, `.chatgpt/**`, and `.superpowers/**` roles.
  - Ensure docs do not call `.chatgpt/**` or `.superpowers/**` canonical.
- [ ] **Step 4: Validate**
  - Run: `./scripts/test-scorecard-proof.sh`
  - Run: `./scripts/validate-scorecard-proof.sh -RepoRoot .`

## Task 6: Skill Prose Polish And Artifact Card Clarity

**Use Cases:**
- Route-specific Artifact Review Card paragraphs are concise and exact.
- Global findings-summary policy remains centralized in `advanced-user-input`.
- Machine-patched duplicate fragments are removed without weakening push, merge, publish, or continuation gates.

**Files:**
- Modify: `skills/*/SKILL.md`
- Modify: `scripts/validate-global-policy-deduplication.sh`
- Modify: `scripts/test-global-policy-deduplication.sh`
- Modify: `scripts/test-artifact-review-card.sh`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-global-policy-deduplication.sh`
- Test: `scripts/test-artifact-review-card.sh`

- [ ] **Step 1: Add prose-smell checks**
  - Search for duplicate fragments such as `Add the helper-required findings summary`, `permission question:.`, and `artifacts are shown.*Add the helper`.
  - Add failing fixtures or validator checks for these patterns.
- [ ] **Step 2: Clean route-local wording**
  - Replace duplicate summary fragments with route-specific card inventory.
  - Keep exact artifacts needed by each route.
- [ ] **Step 3: Validate**
  - Run: `rg -n "Add the helper-required findings summary|permission question:\\.|artifacts are shown.*Add the helper" skills`
  - Run: `./scripts/test-global-policy-deduplication.sh`
  - Run: `./scripts/test-artifact-review-card.sh`

## Task 7: Decision Ledger Examples

**Use Cases:**
- A spec example shows repo-derived decisions, user decisions, and deferred decisions with concrete risk owners.
- A plan example carries forward source decisions and adds a planning grill decision that changes owner, interface, cutover, or acceptance proof.
- `brainstorm-spec` and `write-plan` point agents to examples that validate.

**Files:**
- Create: `docs/superpowers/examples/decision-ledger-examples.md`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `scripts/test-decision-ledger.sh`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-decision-ledger.sh`

- [ ] **Step 1: Add example fixtures**
  - Include spec-style and plan-style Decision Ledger examples with user answer, repo evidence, planning grill, and deferred decision rows.
- [ ] **Step 2: Validate examples**
  - Extend tests so the examples are parsed and validated, or add example extraction fixtures when direct Markdown validation needs a focused artifact path.
- [ ] **Step 3: Reference examples from skills**
  - Link the examples from `brainstorm-spec` and `write-plan` near the Decision Ledger requirements.
- [ ] **Step 4: Validate**
  - Run: `./scripts/test-decision-ledger.sh`
  - Run: `./scripts/validate-decision-ledger.sh -Path ./docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md -Kind spec`
  - Run: `./scripts/validate-decision-ledger.sh -Path ./docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md -Kind plan`

## Final Program Proof

- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`
- `./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent`
- `./scripts/validate-scorecard-proof.sh -RepoRoot .`
- `./skills/align-project/scripts/align-project.sh -RepoRoot . -Mode GitHubAware -TrackerHygiene`
- `"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .`
- `git status --short --branch`
