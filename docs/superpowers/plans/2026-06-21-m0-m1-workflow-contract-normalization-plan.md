# Workflow Contract Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a registry-first workflow contract system that removes route drift, compresses duplicated metadata and global policy, records decisions, standardizes artifact review, and validates the full audit-derived workflow improvement program.

**Architecture:** Add a machine-readable workflow contract and validators first, then update metadata, skill policy references, authoring templates, examples, and loop-selection surfaces to consume or validate against that contract. Keep existing Superpowers Project route ownership intact: planning creates issue-backed work, issue execution happens through resolve or orchestrate routes, and merge closeout remains the final integration owner.

**Tech Stack:** PowerShell validators and fixtures, YAML route contract, Markdown skill/spec/plan docs, existing Superpowers Project scripts, GitHub issue mirrors, and the repo validation suite.

---

## Source Spec

- `docs/superpowers/specs/2026-06-21-workflow-contract-normalization-design.md`

## Planning Decisions

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Execution topology | Native `workflow_plan_execution_topology` answer | Issue-backed execution | The plan routes to `create-issues` after approval and expects one issue mirror/GitHub issue per track. | No | `create-issues` |
| Issue slicing | Native `workflow_plan_issue_slicing` answer | Ten slices | Each audit track gets independent acceptance criteria and proof. | No | `create-issues` |
| Policy compression | Native `workflow_plan_policy_compression` answer | Strict centralize | Repeated global policy moves into `advanced-user-input` with validators rejecting duplicate walls. | No | `merge-changes` |

## Test-Complete Definition

Test complete means every new or changed validator has at least one passing fixture and one failing fixture where practical, all route-contract and metadata drift checks pass, the known `write-plan` metadata drift is repaired, `scripts/validate.ps1` passes, `scripts/sync-live.ps1 -Validate` passes after plugin-surface changes, the repo cleanup hook passes, and Git reports no uncommitted tracked changes at the final Done gate.

Pass/fail metrics are command exit codes, validator JSON or console receipts, fixture assertions, and exact file diffs. Numerical tolerances are not part of this workflow-plugin repair; the measurable threshold is zero failing validators.

## Outcome Proof

**Intent:** Make Superpowers Project workflow behavior predictable by giving routes one authoritative contract and validating every duplicated or generated surface against it.
**Current Behavior:** Route policy, continuation rules, question IDs, metadata summaries, and artifact-review instructions are repeated across README, generated docs, skill bodies, metadata prompts, scripts, and examples. The `write-plan` metadata prompt currently lists `Stop` inside a nested ready-issue execution route while the skill body correctly omits terminal options there.
**Expected Outcome:** The registry owns route structure, metadata is compact, repeated global policy is centralized, decisions and artifact reviews are schema-backed, active candidates are cleaner, examples are testable, and live-sync/tracker/align drift receives targeted proof.
**Target Output:** Maintainers and agents can inspect one contract file, run validators, and trust that skill docs, metadata, examples, and generated workflow docs agree.
**Owner:** `docs/superpowers/workflow-contract.yml` owns workflow route data; `skills/advanced-user-input/SKILL.md` owns global native continuation and artifact-review policy; validators under `scripts/` own proof.
**Interface:** PowerShell validators read the YAML contract and Markdown/YAML surfaces, then produce pass/fail results used by `scripts/validate.ps1`, issue acceptance, and merge closeout.
**Cutover:** Replace duplicated route tables and global-policy walls with contract-driven summaries or short references. Remove the known metadata contradiction and any duplicated policy text made obsolete by the central helper.
**Replaced Path:** Hand-maintained route summaries in metadata prompts and repeated global continuation/artifact-review prose across workflow skills stop being the durable source of truth.
**Evidence:** Contract file, validators, updated skills, compact metadata prompts, examples, issue mirrors, validation receipts, live-sync validation, cleanup receipt, and clean Git state.
**Acceptance Proof:** `scripts/validate.ps1`, focused new validators, `scripts/sync-live.ps1 -Validate`, and the cleanup hook all pass after the issue-backed implementation slices merge.
**Stop Criteria:** If the registry cannot validate a route surface or an implementation slice cannot prove contract parity, stop the merge route and repair the owning track before continuing.
**Avoid:** Do not add alternate route behavior, compatibility wrappers, new workflow route owners, milestone-local canonical artifacts, or permissive metadata drift.
**Risk:** If the registry is incomplete or validators are shallow, the project gains another surface without eliminating drift.

## Implementation Boundaries

**Files To Create:** `docs/superpowers/workflow-contract.yml`, focused validators and tests under `scripts/`, examples under `docs/superpowers/examples/`, optional active backlog file under `docs/superpowers/backlog/`.
**Files To Modify:** workflow `skills/*/SKILL.md`, `skills/*/agents/openai.yaml`, `scripts/validate.ps1`, existing focused tests, `README.md`, `docs/superpowers/OUTCOME_WORKFLOW.md` generator and generated output, milestone pages, and issue mirrors created from this plan.
**Files To Avoid:** deployed live plugin copies, plugin cache paths, `.chatgpt/**` audit packet content, `.superpowers/**` generated runtime state as committed source, and retired artifact roots.
**Source Of Truth:** The approved spec and this plan drive issue creation; after Task 1, `docs/superpowers/workflow-contract.yml` drives route data.
**Read Path:** Validators read the contract, skill Markdown, metadata YAML, examples, generated docs, issue mirrors, and Git tracked-file state.
**Write Path:** Edits are made in this source repo only, then synced with `scripts/sync-live.ps1 -Validate`.
**Integration Points:** `scripts/validate.ps1`, `scripts/generate-outcome-workflow-summary.ps1`, `scripts/test-native-continuation-loop.ps1`, `scripts/test-skill-metadata-readability.ps1`, loop-controller candidate selection, create-issues mirror validation, orchestrate worker handoff validation, and merge closeout proof.
**Migration Or Cutover:** Introduce contract and validators, repair mismatches, then shrink duplicated metadata/policy surfaces after validators can detect drift.
**Replaced Path Handling:** Remove redundant route tables and repeated global policy text when the central contract/reference covers them; keep skill-specific question IDs, artifacts, and route maps local where the owning skill needs them.
**Acceptance Proof Gate:** Do not route to merge until all focused validators, plan validators, repo validation, live-sync validation, cleanup, and clean Git proof pass.

## Acceptance Criteria

- [ ] One source-owned workflow contract includes all active workflow skills and native question IDs.
- [ ] A validator fails when route metadata contradicts the contract or a skill route block.
- [ ] `skills/write-plan/agents/openai.yaml` no longer lists `Stop` inside `project_plan_issue_execution_route`.
- [ ] Metadata prompts are compact and no longer duplicate full native continuation, artifact-review, or route-table policy.
- [ ] `advanced-user-input` owns global continuation and artifact-review policy, and non-helper workflow skills reference it with only skill-specific additions.
- [ ] Specs and plans require a `Decision Ledger`, with validation coverage.
- [ ] Artifact Review Card schema exists and is covered by fixtures.
- [ ] Active backlog/candidate signal excludes historical plan checkboxes and generated run state.
- [ ] `.superpowers/**` generated state remains ignored and cannot become canonical tracked documentation.
- [ ] Four golden-path workflow examples validate route sequence, question IDs, artifacts, validators, and stop points.
- [ ] Worker handoff and PR-ready packet examples validate required handoff fields.
- [ ] Targeted live-sync, tracker, and align drift proof is recorded.
- [ ] `scripts/validate.ps1`, `scripts/sync-live.ps1 -Validate`, and the repo cleanup hook pass before final Done.

## Non-Goals

- Create a new workflow skill for contract normalization.
- Change the public artifact roots.
- Make GitHub Projects mandatory.
- Edit deployed live copies directly.
- Treat `.chatgpt/**` or `.superpowers/**` as canonical documentation.
- Collapse merge closeout, issue execution, or loop-controller boundaries into one shortcut.

## Issue Slices

The `create-issues` route should create ten issue mirrors, one per implementation track:

1. P1 route registry and validator.
2. P1 metadata prompt compression.
3. P1 centralized continuation and artifact-review policy.
4. P1 Decision Ledger.
5. P2 Artifact Review Card schema.
6. P2 active backlog and candidate signal.
7. P2 generated-state guardrails.
8. P2 golden-path workflow fixtures.
9. P2 worker handoff and PR-ready packets.
10. P2 live-sync, tracker, and align drift validation.

## Task 1: Add Canonical Workflow Contract

**Use Cases:**
- An agent can inspect one YAML file to discover every workflow skill, question ID, terminal rule, final gate, validator, artifact, and next route.
- A route mismatch such as `Stop` appearing inside a nested Yes-route fails before merge.
- Generated workflow docs can be rebuilt from contract-backed data instead of hand-maintained route summaries.

**Files:**
- Create: `docs/superpowers/workflow-contract.yml`
- Create: `scripts/lib/workflow-contract.ps1`
- Create: `scripts/validate-workflow-contract.ps1`
- Create: `scripts/test-workflow-contract.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-workflow-contract.ps1`

- [ ] **Step 1: Write failing contract tests**
  - Add fixtures inside `scripts/test-workflow-contract.ps1` that create a temporary contract and temporary skill/metadata surfaces.
  - Include one passing fixture where nested Yes routes contain only forward options.
  - Include one failing fixture where a nested Yes route includes `Stop`.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`
  - Expected: fails because the validator script does not exist yet.
- [ ] **Step 2: Add the contract file**
  - Create `docs/superpowers/workflow-contract.yml` with every active workflow skill from `docs/superpowers/OUTCOME_WORKFLOW.md`.
  - Include each skill's purpose, native question IDs, final gate, top-level options, nested options, required validators, output artifacts, and next transitions.
  - Add `advanced-user-input` as the central native-input helper, not as an implementation route.
- [ ] **Step 3: Implement contract loading helpers**
  - Add `scripts/lib/workflow-contract.ps1` with helpers that load YAML through PowerShell, normalize question IDs, and expose skill entries by name.
  - Use the repo's existing Python/PyYAML expectation only when PowerShell cannot parse YAML directly.
- [ ] **Step 4: Implement the validator**
  - Add `scripts/validate-workflow-contract.ps1` to compare contract entries against `skills/*/SKILL.md`, `skills/*/agents/openai.yaml`, and generated workflow summary expectations.
  - Fail on missing active workflow skills, missing question IDs, undeclared final gates, terminal options inside nested routes, and unknown next-skill transitions.
- [ ] **Step 5: Wire validation**
  - Add `scripts/test-workflow-contract.ps1` and `scripts/validate-workflow-contract.ps1` to `scripts/validate.ps1`.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`
  - Expected: passes.
- [ ] **Step 6: Commit**
  - Commit message: `feat: add workflow contract registry`

## Task 2: Compress Metadata Prompts Against The Contract

**Use Cases:**
- Metadata prompts help route skill selection without becoming a second full skill contract.
- The known `write-plan` metadata route mismatch is repaired and covered by validation.
- Maintainers get a bounded prompt-size/readability check for every `agents/openai.yaml`.

**Files:**
- Modify: `skills/*/agents/openai.yaml`
- Modify: `scripts/test-skill-metadata-readability.ps1`
- Create: `scripts/validate-skill-metadata-contract.ps1`
- Create: `scripts/test-skill-metadata-contract.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-skill-metadata-readability.ps1`
- Test: `scripts/test-skill-metadata-contract.ps1`

- [ ] **Step 1: Write failing metadata contract tests**
  - Add a fixture where `write-plan` metadata includes `Stop` in `project_plan_issue_execution_route`.
  - Add a fixture where metadata stays compact and points to `SKILL.md` plus the workflow contract.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1`
  - Expected: fails because the validator script is not present yet.
- [ ] **Step 2: Implement metadata validator**
  - Create `scripts/validate-skill-metadata-contract.ps1`.
  - Validate metadata route summaries against `docs/superpowers/workflow-contract.yml`.
  - Enforce a compact prompt budget or structured summary budget agreed in the test.
- [ ] **Step 3: Shrink metadata prompts**
  - Edit every `skills/*/agents/openai.yaml` so `default_prompt` covers selection trigger, hard boundaries, required companion skills, and a pointer to `SKILL.md` plus the workflow contract.
  - Remove duplicated full continuation loops, artifact-review walls, route tables, and terminal-state prose.
  - Repair `skills/write-plan/agents/openai.yaml` so `project_plan_issue_execution_route` lists only `Resolve Issue` and `Orchestrate Issues`.
- [ ] **Step 4: Wire validation**
  - Add the new metadata contract test and validator to `scripts/validate.ps1`.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1`
  - Expected: passes.
- [ ] **Step 5: Run readability checks**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-readability.ps1`
  - Expected: passes with the new compact metadata.
- [ ] **Step 6: Commit**
  - Commit message: `fix: validate compact skill metadata`

## Task 3: Centralize Native Continuation And Artifact Review Policy

**Use Cases:**
- Agents read global native continuation and artifact-review policy in one helper skill.
- Workflow skills keep route-specific gates without repeating the same global walls.
- Validation catches a non-helper skill that reintroduces duplicated global policy text.

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/*/SKILL.md`
- Create: `scripts/validate-global-policy-deduplication.ps1`
- Create: `scripts/test-global-policy-deduplication.ps1`
- Modify: `scripts/test-native-continuation-loop.ps1`
- Modify: `scripts/test-advanced-user-input-policy.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-global-policy-deduplication.ps1`
- Test: `scripts/test-native-continuation-loop.ps1`

- [ ] **Step 1: Write failing duplication tests**
  - Add a fixture with copied global continuation text in a non-helper skill.
  - Add a fixture with a short reference to `advanced-user-input` plus skill-specific question IDs.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-global-policy-deduplication.ps1`
  - Expected: fails until the validator exists.
- [ ] **Step 2: Expand the helper contract**
  - Move the global native continuation, artifact review, terminal gate, Custom Other, nested route, Revisit, Stop, and Done policy into `skills/advanced-user-input/SKILL.md`.
  - Keep wording strong enough for existing native continuation tests.
- [ ] **Step 3: Replace duplicated skill walls**
  - Edit workflow `SKILL.md` files to reference `advanced-user-input` for global behavior.
  - Preserve each skill's required method, route-specific question IDs, prompts, options, artifacts, validators, and hard failures.
- [ ] **Step 4: Update continuation tests**
  - Modify `scripts/test-native-continuation-loop.ps1` so it validates central policy presence in `advanced-user-input` and route-specific references in other skills.
  - Keep checks for top-level `Yes`, `Revisit`, `Stop`, final `Done`, and nested terminal restrictions.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-global-policy-deduplication.ps1`
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1`
  - Expected: both pass.
- [ ] **Step 6: Commit**
  - Commit message: `refactor: centralize native continuation policy`

## Task 4: Add Decision Ledger Requirements

**Use Cases:**
- Brainstorming and planning decisions are auditable after the conversation moves on.
- Deferred decisions have a named risk owner and downstream impact.
- Validators fail a ready spec or plan that lacks required decision columns.

**Files:**
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/write-plan/SKILL.md`
- Create: `scripts/validate-decision-ledger.ps1`
- Create: `scripts/test-decision-ledger.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-decision-ledger.ps1`

- [ ] **Step 1: Write decision-ledger tests**
  - Add passing fixtures for spec and plan Markdown with `Decision`, `Source`, `Answer`, `Impact`, `Deferred?`, and `Risk owner`.
  - Add failing fixtures with missing columns, empty answers, and deferred decisions without risk owners.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-decision-ledger.ps1`
  - Expected: fails until the validator exists.
- [ ] **Step 2: Implement the validator**
  - Create `scripts/validate-decision-ledger.ps1`.
  - Support `-Path` and `-Kind spec|plan`.
  - Fail when the ledger is missing, required columns are missing, or deferred rows lack risk owners.
- [ ] **Step 3: Update skill contracts**
  - Add Decision Ledger output requirements to `brainstorm-spec` and `write-plan`.
  - In `write-plan`, require carried-forward spec decisions plus planning grill decisions.
- [ ] **Step 4: Wire validation**
  - Add focused tests to `scripts/validate.ps1`.
  - Add plan/spec examples in existing scenario tests where useful.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-decision-ledger.ps1`
  - Expected: passes.
- [ ] **Step 6: Commit**
  - Commit message: `feat: require decision ledgers`

## Task 5: Add Artifact Review Card Schema

**Use Cases:**
- Agents show exact paths, proof, decisions, risks, and next route before closeout without dumping excessive text.
- Large artifacts have a consistent excerpt rule.
- Push, publish, merge, and continuation gates use the same proof-first card shape.

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: workflow `skills/*/SKILL.md`
- Create: `scripts/validate-artifact-review-card.ps1`
- Create: `scripts/test-artifact-review-card.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-artifact-review-card.ps1`

- [ ] **Step 1: Write card tests**
  - Add a passing card fixture with `Created/changed`, `Proof`, `Decisions`, `Risks`, and `Recommended next route`.
  - Add failing fixtures missing exact paths, proof, and risk owner.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1`
  - Expected: fails until validator exists.
- [ ] **Step 2: Define schema in helper skill**
  - Add the Artifact Review Card schema to `advanced-user-input`.
  - Define the excerpt rule for large artifacts.
- [ ] **Step 3: Reference schema from route skills**
  - Replace verbose artifact display paragraphs in workflow skills with short references plus route-specific artifact lists.
  - Keep strict display-before-question requirements.
- [ ] **Step 4: Implement validator**
  - Create `scripts/validate-artifact-review-card.ps1` to validate Markdown card fixtures.
  - Add scenario fixtures for before push, publish, merge, and continuation gates.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1`
  - Expected: passes.
- [ ] **Step 6: Commit**
  - Commit message: `feat: standardize artifact review cards`

## Task 6: Clean Active Backlog And Candidate Signal

**Use Cases:**
- Loop Controller selects active candidates from explicit sources instead of historical plan checkboxes.
- Maintainers can see current next work without scanning old implementation plans.
- Archived or implemented plans do not appear as normal candidate inventory.

**Files:**
- Create: `docs/superpowers/backlog/ACTIVE.md`
- Modify: `skills/loop-controller/scripts/select-candidate.ps1`
- Modify: `skills/loop-controller/scripts/test-scenarios.ps1`
- Create: `scripts/validate-active-backlog.ps1`
- Create: `scripts/test-active-backlog.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-active-backlog.ps1`
- Test: `skills/loop-controller/scripts/test-scenarios.ps1`

- [ ] **Step 1: Write active-backlog tests**
  - Add a fixture with archived plan checkboxes and one active backlog item.
  - Assert candidate selection returns only the active item.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-active-backlog.ps1`
  - Expected: fails until active backlog validation exists.
- [ ] **Step 2: Add active backlog source**
  - Create `docs/superpowers/backlog/ACTIVE.md` with a compact schema for active candidate links, route owner, source artifact, priority, status, and proof target.
- [ ] **Step 3: Update candidate selection**
  - Update loop-controller candidate-selection tests and selector logic to prefer explicit candidate inventories and active backlog sources.
  - Keep generated `.superpowers/runs/**` inventories valid when a live run intentionally selects from them.
- [ ] **Step 4: Implement validator**
  - Create `scripts/validate-active-backlog.ps1` to reject missing source artifacts, unsupported route owners, and historical plan checkbox-only candidates.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-active-backlog.ps1`
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1`
  - Expected: both pass.
- [ ] **Step 6: Commit**
  - Commit message: `feat: add active backlog candidate signal`

## Task 7: Guard Generated Runtime State

**Use Cases:**
- `.superpowers/**` remains local generated state unless a route intentionally reviews a run ledger.
- Validation fails if generated run ledgers become tracked canonical docs.
- Audits do not count runtime ledgers as durable project specs, plans, or issues.

**Files:**
- Modify: `.gitignore`
- Create: `scripts/validate-generated-state.ps1`
- Create: `scripts/test-generated-state.ps1`
- Modify: `scripts/validate-flat-artifact-roots.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-generated-state.ps1`

- [ ] **Step 1: Write generated-state tests**
  - Add a fixture simulating tracked `.superpowers/runs/foo.json`.
  - Add a fixture where `.superpowers/runs/foo.json` exists locally but is untracked.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-generated-state.ps1`
  - Expected: fails until validator exists.
- [ ] **Step 2: Confirm ignore rules**
  - Ensure `.gitignore` ignores `.superpowers/`.
  - Avoid committing generated ledgers from this run.
- [ ] **Step 3: Implement validator**
  - Create `scripts/validate-generated-state.ps1`.
  - Use `git ls-files .superpowers` to fail on tracked generated state.
  - Scan docs for references that present `.superpowers/**` as canonical documentation.
- [ ] **Step 4: Wire validation**
  - Add the generated-state validator to `scripts/validate.ps1`.
  - Update flat artifact root validation if needed.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-generated-state.ps1`
  - Expected: passes.
- [ ] **Step 6: Commit**
  - Commit message: `test: guard generated workflow state`

## Task 8: Add Golden-Path Workflow Fixtures

**Use Cases:**
- Fresh agents can follow common workflow paths with exact question IDs, artifacts, validators, and stop points.
- Auto Mode examples stop after one route.
- Looping Mode examples re-check budget before another candidate.

**Files:**
- Create: `docs/superpowers/examples/workflow-golden-paths.md`
- Create: `scripts/validate-workflow-examples.ps1`
- Create: `scripts/test-workflow-examples.ps1`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md` generator if examples need generated links
- Modify: `scripts/validate.ps1`
- Test: `scripts/test-workflow-examples.ps1`

- [ ] **Step 1: Write example validator tests**
  - Add fixture examples for four routes: idea to local merge, spec to issues to merge, audit to Auto Mode single route, and Looping Mode candidate selection with budget recheck.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1`
  - Expected: fails until validator exists.
- [ ] **Step 2: Write golden-path examples**
  - Create `docs/superpowers/examples/workflow-golden-paths.md`.
  - Include question IDs, route owner, artifacts, validators, stop point, and proof receipt for each example.
- [ ] **Step 3: Implement example validator**
  - Create `scripts/validate-workflow-examples.ps1`.
  - Compare example question IDs and route names against `docs/superpowers/workflow-contract.yml`.
- [ ] **Step 4: Wire validation**
  - Add example tests and validator to `scripts/validate.ps1`.
  - Update generated workflow summary links if the generator owns those references.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1`
  - Expected: passes.
- [ ] **Step 6: Commit**
  - Commit message: `docs: add workflow golden paths`

## Task 9: Add Worker Handoff And PR-Ready Packets

**Use Cases:**
- Orchestrated worker threads receive complete issue context and proof requirements.
- Worker return packets are predictable enough for current-thread review and merge handoff.
- PR-ready packets include branch, validation, issue mirror, source plan, proof oracle, and merge route.

**Files:**
- Create: `docs/superpowers/examples/worker-handoff-packets.md`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Create: `scripts/test-worker-packets.ps1`
- Modify: `scripts/validate.ps1`
- Test: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Test: `scripts/test-worker-packets.ps1`

- [ ] **Step 1: Write packet tests**
  - Add passing worker handoff and PR-ready packet fixtures.
  - Add failing fixtures missing source plan, issue mirror, branch, validation command, or merge handoff.
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1`
  - Expected: fails until packet validation is extended.
- [ ] **Step 2: Document packet examples**
  - Create `docs/superpowers/examples/worker-handoff-packets.md` with sample handoff and return packets.
  - Include exact fields and proof commands.
- [ ] **Step 3: Update orchestrate skill**
  - Reference packet examples from `skills/orchestrate-issues/SKILL.md`.
  - Preserve worker no-merge rule and current-thread review responsibility.
- [ ] **Step 4: Extend handoff validator**
  - Update `validate-worker-handoff.ps1` to validate the fields used by the examples.
  - Add packet tests to scenario coverage.
- [ ] **Step 5: Run focused tests**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1`
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1`
  - Expected: both pass.
- [ ] **Step 6: Commit**
  - Commit message: `docs: add worker handoff packets`

## Task 10: Run Live-Sync, Tracker, And Align Drift Proof

**Use Cases:**
- Source and live plugin copies match after skill and script changes.
- Tracker labels, milestones, issue mirrors, and align checks remain current.
- Merge closeout has concrete proof instead of prose confidence.

**Files:**
- Modify: `docs/superpowers/milestones/M0-governance.md`
- Modify: `docs/superpowers/milestones/M1-source-of-truth.md`
- Modify: issue mirrors created from this plan
- Create: validation receipt artifact chosen by `merge-changes` or `align-project`
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1 -Validate`

- [ ] **Step 1: Run full validation**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
  - Expected: passes.
- [ ] **Step 2: Run live sync validation**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
  - Expected: passes.
- [ ] **Step 3: Run version check**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent`
  - Expected: reports source/live current.
- [ ] **Step 4: Record align/tracker proof**
  - Use `align-project` evidence or existing tracker validation commands to verify labels, milestones, issue mirrors, and source/live drift.
  - Record exact commands and results in the issue mirror or merge closeout packet selected by the route owner.
- [ ] **Step 5: Run cleanup**
  - Run: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
  - Expected: no repo-owned process cleanup required, or cleanup reports only owned state.
- [ ] **Step 6: Commit**
  - Commit message: `chore: record workflow normalization proof`

## Final Verification

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-outcome-proof.ps1 -PlanPath .\docs\superpowers\plans\2026-06-21-m0-m1-workflow-contract-normalization-plan.md`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath .\docs\superpowers\plans\2026-06-21-m0-m1-workflow-contract-normalization-plan.md`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`

## Recommended Next Route

Continue to `$superpowers-project:create-issues` and create ten issue mirrors from this plan. Use the issue-backed route because the work is broad, risky, and tracker-worthy.
