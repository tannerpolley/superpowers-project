# Krypton Contract Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed Krypton-style ownership, contract, cutover, and evidence gates into Superpowers Project plans, issue mirrors, execution ledgers, and merge proof.

**Architecture:** Add a shared Bash outcome-proof helper and validator wrapper, then thread its contract shape through existing project skills instead of creating a new workflow route. Planning writes the full contract, issue mirrors carry a compact summary, execution ledgers carry structured contract proof, and merge gates reject missing readiness reviews.

**Tech Stack:** Markdown skill contracts, YAML agent metadata, Bash validators and scenario tests, existing Superpowers Project validation and sync scripts.

---

## Source Material

- Source spec: `docs/superpowers/specs/2026-06-19-krypton-outcome-proof-adoption-design.md`
- Audit findings: `docs/superpowers/specs/2026-06-19-krypton-integration-audit-findings.md`
- Auto Mode authorization ledger: `.superpowers/runs/2026-06-19-krypton-outcome-proof-adoption/auto-mode-authorization.json`
- Downloaded Krypton inspection copy: `.codex-local/external/krypton`

## Auto Mode Defaults

- Route policy: agent chooses the implementation route from the approved plan.
- Implementation route: direct inline branch-backed implementation is allowed first; issue-backed execution can be prepared by this plan but should not create external GitHub issues unless all local proofs pass.
- Mutation scope: current repo and development branch.
- Merge permission: preauthorized only after clean premerge proof.
- Stop conditions: missing proof, unsafe dirty state, failed validation, or a decision outside this plan.

## Test Complete And Metrics

This is workflow-contract work, not scientific or numerical modeling. Numerical tolerances are not applicable.

Test complete means:

- focused scenario tests pass for plan, issue, implement, resolve, and merge contracts;
- full `scripts/validate.sh` passes;
- `scripts/sync-live.sh --validate` passes before any live install update;
- cleanup hook reports no repo-owned leftover processes.

## Acceptance Criteria

- Every implementation plan must include a required `## Outcome Proof`.
- Every implementation plan must include a required `## Implementation Boundaries`.
- Plan validation rejects missing or generic contract fields.
- Issue mirrors created from plans must carry compact contract summaries.
- Issue mirror validation rejects missing or contradictory contract summaries.
- Implement-plan and resolve-issue setup ledgers carry structured contract fields.
- PR-ready, merge-ready, and premerge proof reject missing readiness review evidence.
- Krypton-inspired wrong-layer, weak-evidence, cutover-debt, issue propagation, and contract-drift scenarios are covered by repo-owned tests.
- Full repo validation and live sync validation pass.

## Proof Oracle

```bash
./scripts/test-plan-outcome-proof.sh
./skills/write-plan/scripts/test-scenarios.sh
./skills/create-issues/scripts/test-scenarios.sh
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/validate.sh
./scripts/sync-live.sh --validate
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

## Risk And Dependency Notes

- The shared helper should be added before skill text changes so all later validators can call the same field and section checks.
- Plan and issue validators should fail before execution validators are tightened; otherwise existing generated fixtures become noisy.
- Execution and merge ledger fields should use one structured `outcome_proof` object so future routes can reuse the same contract shape.
- No upstream Krypton files should be vendored into `skills/`; the ignored local copy is reference material only.

### Task 1: Add Shared Outcome Proof Validator

**Use Cases:**
- A saved plan without `## Outcome Proof` is rejected before issue creation or implementation starts.
- A plan with missing truth owner, contract interface, cutover, displaced path handling, or target-perspective evidence is rejected with a clear validator reason.
- A wrong-layer feature fixture fails until source of truth, read path, write path, and evidence lane are explicit.
- A cutover-debt fixture fails when two current-looking paths remain without kill criteria.

**Files:**
- Create: `scripts/lib/outcome-proof.sh`
- Create: `scripts/validate-plan-outcome-proof.sh`
- Create: `scripts/test-plan-outcome-proof.sh`
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Write the failing plan-contract scenario test**

Create `scripts/test-plan-outcome-proof.sh` with fixture plans under a temp repo. Include one valid plan and at least three invalid plans:

```bash
$validPlan = @'
# Valid Contract Plan

## Outcome Proof

**Intent:** Make contract adoption enforceable.
**Current Behavior:** Plans require use cases but do not require contract ownership.
**Expected Outcome:** Plans carry ownership, cutover, and evidence gates.
**Target Output:** Maintainer sees a validator pass only when contract fields are present.
**Owner:** `scripts/lib/outcome-proof.sh`
**Interface:** Markdown fields consumed by validator scripts.
**Cutover:** Extend the existing plan readiness path.
**Replaced Path:** Plan readiness based only on Task # Use Cases.
**Evidence:** CLI validator output.
**Acceptance Proof:** `validate-plan-outcome-proof.sh` returns `ok: true`.
**Stop Criteria:** Reject plans that omit required ownership or proof fields.
**Avoid:** Do not create a separate `docs/goals` route.
**Risk:** Agents can ship plausible work with weak ownership proof.

## Implementation Boundaries

**Files To Create:** `scripts/lib/outcome-proof.sh`
**Files To Modify:** `scripts/validate.sh`
**Files To Avoid:** `skills/krypton-*`
**Source Of Truth:** plan outcome proof section
**Read Path:** plan markdown -> validator helper
**Write Path:** `$superpowers-project:write-plan` writes the section
**Integration Points:** plan validation and issue validation
**Migration Or Cutover:** old plan readiness is extended, not replaced
**Replaced Path Handling:** Task-only readiness no longer stands alone
**Acceptance Proof Gate:** focused validator test passes

### Work Item 1: Add Validator

**Use Cases:**
- Contract fixture passes with full ownership and evidence fields.

**Files:**
- Create: `scripts/lib/outcome-proof.sh`

- [ ] **Step 1: Add helper**
'@
```

Run:

```bash
./scripts/test-plan-outcome-proof.sh
```

Expected before implementation: fails because `scripts/validate-plan-outcome-proof.sh` does not exist.

- [ ] **Step 2: Implement the shared helper**

Create `scripts/lib/outcome-proof.sh` with functions that parse Markdown sections and required fields:

```bash
$script:OutcomeProofFields = @(
    "Intent",
    "Current Behavior",
    "Expected Outcome",
    "Target Output",
    "Owner",
    "Interface",
    "Cutover",
    "Replaced Path",
    "Evidence",
    "Acceptance Proof",
    "Stop Criteria",
    "Avoid",
    "Risk"
)

$script:ArchitectureSliceFields = @(
    "Files To Create",
    "Files To Modify",
    "Files To Avoid",
    "Source Of Truth",
    "Read Path",
    "Write Path",
    "Integration Points",
    "Migration Or Cutover",
    "Replaced Path Handling",
    "Acceptance Proof Gate"
)
```

The helper should expose `Test-PlanOutcomeProof` and `Test-IssueOutcomeProofSummary`, each returning an object with `ok`, `reason`, and `fields`.

- [ ] **Step 3: Implement the plan validator wrapper**

Create `scripts/validate-plan-outcome-proof.sh` with parameters:

```bash
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$PlanPath
)
```

The wrapper must resolve repo-relative paths safely, require `docs/superpowers/plans`, call `Test-PlanOutcomeProof`, print JSON, and exit nonzero when `ok` is false.

- [ ] **Step 4: Wire the focused test into full validation**

Modify `scripts/validate.sh` after the existing `Plan task use cases` step:

```bash
$results.Add((Invoke-Step "Plan outcome proof" {
    & (Join-Path $PSScriptRoot "test-plan-outcome-proof.sh") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Plan outcome proof failed" }
}))
```

- [ ] **Step 5: Run focused proof**

Run:

```bash
./scripts/test-plan-outcome-proof.sh
```

Expected after implementation: JSON output has `"ok": true` and includes valid, missing-section, missing-field, weak-evidence, and cutover-debt checks.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/outcome-proof.sh scripts/validate-plan-outcome-proof.sh scripts/test-plan-outcome-proof.sh scripts/validate.sh
git commit -m "Add outcome proof plan validator"
```

### Task 2: Require Outcome Proof In Project Plan

**Use Cases:**
- A future `$superpowers-project:write-plan` run must write the contract before tasks.
- Agents see the same contract requirement from `SKILL.md` and startup metadata.
- The planning grill asks for missing ownership, cutover, and evidence fields instead of inventing them.
- Existing Task # Use Cases remain mandatory and now map to contract concerns.

**Files:**
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing scenario checks**

Modify `skills/write-plan/scripts/test-scenarios.sh` so the `superpowers writing contract is present`, `planning grill gate is mandatory`, and metadata scenarios require these strings:

```bash
"## Outcome Proof",
"## Implementation Boundaries",
"validate-plan-outcome-proof.sh",
"Owner",
"Interface",
"Cutover",
"Replaced Path",
"Evidence",
"Stop Criteria",
"Avoid"
```

Run:

```bash
./skills/write-plan/scripts/test-scenarios.sh
```

Expected before skill edits: fails on missing contract strings.

- [ ] **Step 2: Update `write-plan` skill contract**

Add a section before `## Task # Use Cases Gate` in `skills/write-plan/SKILL.md` named `## Outcome Proof Gate`. Require every implementation plan to include `## Outcome Proof` and `## Implementation Boundaries`, list the exact fields from the source spec, and require:

```bash
./scripts/validate-plan-outcome-proof.sh -PlanPath <saved-plan-path>
```

The skill text must say that task use cases cover acceptance evidence and cutover or displaced path handling.

- [ ] **Step 3: Update startup metadata**

Update `skills/write-plan/agents/openai.yaml` to include the same outcome-proof gate, validator command, required fields, and relationship to Task # Use Cases.

- [ ] **Step 4: Run focused proof**

Run:

```bash
./skills/write-plan/scripts/test-scenarios.sh
```

Expected: all write-plan scenario checks pass.

- [ ] **Step 5: Commit**

```bash
git add skills/write-plan/SKILL.md skills/write-plan/agents/openai.yaml skills/write-plan/scripts/test-scenarios.sh
git commit -m "Require outcome proofs in project plans"
```

### Task 3: Carry Contract Summaries Into Issue Mirrors

**Use Cases:**
- Creating issues from a plan preserves the plan's truth owner, contract interface, cutover, displaced path, acceptance evidence, kill criteria, and forbidden moves.
- Issue mirror validation rejects ready issue mirrors that drop the outcome workflow.
- External issue hydration produces or preserves contract-compatible issue mirrors before execution routing.
- Multi-issue mirrors can narrow contract ownership without contradicting the source plan.

**Files:**
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/validate-issue-mirror.sh`
- Modify: `skills/create-issues/scripts/hydrate-external-issue.sh`
- Modify: `skills/create-issues/scripts/test-scenarios.sh`
- Modify: `scripts/lib/outcome-proof.sh`

- [ ] **Step 1: Add failing issue-mirror scenario checks**

Extend `skills/create-issues/scripts/test-scenarios.sh` with one valid issue mirror that includes:

```markdown
## Outcome Summary

**Outcome Source:** docs/superpowers/plans/valid-plan.md#outcome-proof
**Intent:** Enforce contract continuity.
**Target Output:** Maintainer sees issue execution blocked without contract proof.
**Owner:** `scripts/lib/outcome-proof.sh`
**Interface:** Markdown issue summary fields consumed by validators.
**Cutover:** Extend issue readiness validation.
**Replaced Path:** Issue readiness without outcome workflow.
**Acceptance Proof:** issue validator returns `ok: true`.
**Stop Criteria:** Reject issue mirrors missing contract proof.
**Avoid:** Do not use `docs/goals` as the issue source.
```

Add one invalid issue mirror missing `## Outcome Summary`. Expected before validator edits: invalid mirror currently passes, so the new check fails.

- [ ] **Step 2: Extend shared helper for issue summaries**

In `scripts/lib/outcome-proof.sh`, implement `Test-IssueOutcomeProofSummary` with fields:

```bash
$script:IssueOutcomeProofFields = @(
    "Outcome Source",
    "Intent",
    "Target Output",
    "Owner",
    "Interface",
    "Cutover",
    "Replaced Path",
    "Acceptance Proof",
    "Stop Criteria",
    "Avoid"
)
```

Reject summaries with empty generic values and reject `docs/goals` in the contract source.

- [ ] **Step 3: Wire issue mirror validation**

Modify `skills/create-issues/scripts/validate-issue-mirror.sh` to import `scripts/lib/outcome-proof.sh` from the repo root and call `Test-IssueOutcomeProofSummary` after source artifact validation.

Add returned check entries named:

```bash
Add-Check -Name "outcome summary" -Ok $contractResult.ok -Reason $contractResult.reason
```

When the contract result fails, complete with that reason.

- [ ] **Step 4: Update hydration output**

Modify `skills/create-issues/scripts/hydrate-external-issue.sh` so generated mirrors include `## Outcome Summary`. For externally hydrated issues with sparse source data, derive the summary from the external issue body and the generated source plan. Use concrete values such as the source plan path, issue intent, expected target output, validator-owned truth, and proof oracle.

- [ ] **Step 5: Update skill text and metadata**

Update `skills/create-issues/SKILL.md` and `skills/create-issues/agents/openai.yaml` to require outcome proof summaries in every issue mirror and to state that issue execution is blocked when the summary is missing or contradicts the source plan.

- [ ] **Step 6: Run focused proof**

Run:

```bash
./skills/create-issues/scripts/test-scenarios.sh
```

Expected: valid issue mirrors pass; missing outcome workflow fails; hydration tests pass with outcome workflow present.

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/outcome-proof.sh skills/create-issues/SKILL.md skills/create-issues/agents/openai.yaml skills/create-issues/scripts/validate-issue-mirror.sh skills/create-issues/scripts/hydrate-external-issue.sh skills/create-issues/scripts/test-scenarios.sh
git commit -m "Carry outcome proofs into issue mirrors"
```

### Task 4: Carry Contract Fields Through Execution Ledgers

**Use Cases:**
- Non-issue implementation cannot produce merge-ready evidence without carrying the approved plan's outcome proof.
- Issue-backed resolution cannot finalize setup when the issue mirror lacks contract fields.
- PR-ready evidence cannot pass when acceptance coverage is present but readiness review evidence is missing.
- Contract drift during execution is represented as a structured blocker, not a prose-only note.

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/lib/contract.sh`
- Modify: `skills/implement-plan/scripts/test-scenarios.sh`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/prepare-execution.sh`
- Modify: `skills/resolve-issue/scripts/validate-setup.sh`
- Modify: `skills/resolve-issue/scripts/collect-pr-ready-ledger.sh`
- Modify: `skills/resolve-issue/scripts/validate-pr-ready.sh`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing implement-plan ledger tests**

Modify `skills/implement-plan/scripts/test-scenarios.sh` so `New-HappyLedger` includes:

```bash
outcome_proof = [pscustomobject]@{
    intent = "Adopt outcome proofs"
    owner = "scripts/lib/outcome-proof.sh"
    interface = "structured outcome_proof ledger object"
    cutover = "extend existing execution proof"
    replaced_path = "merge-ready proof without readiness review"
    acceptance_proof = "readiness review evidence is structured"
    stop_criteria = "block merge-ready when readiness review is missing"
    avoid = @("docs/goals route", "string-only contract proof")
}
readiness_review = [pscustomobject]@{
    plan_alignment = $true
    correctness = $true
    maintainability = $true
    reality_evidence = $true
}
```

Add a negative fixture where `outcome_proof` is removed. Expected before implementation: the missing field is not rejected, so the new negative check fails.

- [ ] **Step 2: Tighten implement-plan contract helper**

Modify `skills/implement-plan/scripts/lib/contract.sh` so `Test-ImplementPlanLedger` requires structured `outcome_proof` and structured `readiness_review`. Reject string values and require review booleans for `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence`.

- [ ] **Step 3: Update resolve setup and PR-ready tests**

Modify `skills/resolve-issue/scripts/test-scenarios.sh` happy setup and PR-ready fixtures to include `outcome_proof` and `readiness_review`. Add negative fixtures for missing setup contract and missing PR-ready readiness review.

- [ ] **Step 4: Carry issue contract from mirror to handoff and setup**

Modify `skills/resolve-issue/scripts/prepare-execution.sh`:

- `Read-IssueMirrorContract` extracts `## Outcome Summary`.
- the inspect handoff includes structured `outcome_proof`.
- `FinalizeSetup` writes that object to the setup ledger.

- [ ] **Step 5: Validate resolve setup and PR-ready ledgers**

Modify `skills/resolve-issue/scripts/validate-setup.sh` to require `outcome_proof`.

Modify `skills/resolve-issue/scripts/collect-pr-ready-ledger.sh` to accept a `-ReadinessReviewJson` input and write `readiness_review` into the PR-ready ledger.

Modify `skills/resolve-issue/scripts/validate-pr-ready.sh` to require `readiness_review` with the four review lanes.

- [ ] **Step 6: Update skill text and metadata**

Update implement and resolve `SKILL.md` plus `agents/openai.yaml` files so startup-loaded agents must restate the outcome proof before edits and must collect readiness review evidence before push, PR-ready, or merge-ready claims.

- [ ] **Step 7: Run focused proof**

Run:

```bash
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: both scripts return passing JSON and reject fixtures missing contract fields or review lanes.

- [ ] **Step 8: Commit**

```bash
git add skills/implement-plan/SKILL.md skills/implement-plan/agents/openai.yaml skills/implement-plan/scripts/lib/contract.sh skills/implement-plan/scripts/test-scenarios.sh skills/resolve-issue/SKILL.md skills/resolve-issue/agents/openai.yaml skills/resolve-issue/scripts/prepare-execution.sh skills/resolve-issue/scripts/validate-setup.sh skills/resolve-issue/scripts/collect-pr-ready-ledger.sh skills/resolve-issue/scripts/validate-pr-ready.sh skills/resolve-issue/scripts/test-scenarios.sh
git commit -m "Carry outcome proofs through execution proof"
```

### Task 5: Enforce Readiness Review In Merge Proof

**Use Cases:**
- Premerge proof fails when a PR-ready or local-branch verification ledger lacks plan alignment review.
- Premerge proof fails when correctness, maintainability, or reality evidence review is missing.
- A passing test command alone cannot satisfy merge readiness.
- Merge closeout remains governed by existing approval and cleanup gates after contract proof passes.

**Files:**
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/lib/contract.sh`
- Modify: `skills/merge-changes/scripts/collect-premerge-ledger.sh`
- Modify: `skills/merge-changes/scripts/premerge.sh`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing merge scenario tests**

Modify `skills/merge-changes/scripts/test-scenarios.sh` so happy premerge fixtures include:

```bash
readiness_review = [pscustomobject]@{
    plan_alignment = $true
    correctness = $true
    maintainability = $true
    reality_evidence = $true
    evidence = @("target-perspective proof inspected")
}
```

Add a negative premerge fixture where `verification.proof_commands` exists but `readiness_review` is missing. Expected before implementation: the fixture passes; after implementation it must fail.

- [ ] **Step 2: Add merge readiness review assertion**

In `skills/merge-changes/scripts/lib/contract.sh`, add `Assert-ReadinessReviewProof` that rejects missing or string values and requires `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` to be `$true`.

- [ ] **Step 3: Wire premerge validation**

Modify `skills/merge-changes/scripts/premerge.sh` to call `Assert-ReadinessReviewProof -Proof $verification.readiness_review` for both `local-branch` and `pr-issue` modes before `Complete-Contract`.

- [ ] **Step 4: Update premerge collector**

Modify `skills/merge-changes/scripts/collect-premerge-ledger.sh` to accept `-ReadinessReviewJson` and include the parsed object as `readiness_review` in the generated verification ledger.

- [ ] **Step 5: Update skill text and metadata**

Update merge `SKILL.md` and `agents/openai.yaml` so premerge proof lists the four readiness review lanes and says missing readiness review blocks merge approval.

- [ ] **Step 6: Run focused proof**

Run:

```bash
./skills/merge-changes/scripts/test-scenarios.sh
```

Expected: merge scenario tests pass and reject verification ledgers without readiness review proof.

- [ ] **Step 7: Commit**

```bash
git add skills/merge-changes/SKILL.md skills/merge-changes/agents/openai.yaml skills/merge-changes/scripts/lib/contract.sh skills/merge-changes/scripts/collect-premerge-ledger.sh skills/merge-changes/scripts/premerge.sh skills/merge-changes/scripts/test-scenarios.sh
git commit -m "Require readiness review in merge proof"
```

### Task 6: Update Public Contract Surfaces

**Use Cases:**
- New agents can discover the outcome proof from README and generated summary before opening individual skill files.
- Contract summary validation catches stale public documentation.
- Live sync validation deploys the new contract surfaces consistently.

**Files:**
- Modify: `README.md`
- Modify: `scripts/generate-contract-summary.sh`
- Modify: `scripts/test-contract-summary.sh`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`

- [ ] **Step 1: Add failing outcome workflow checks**

Modify `scripts/test-contract-summary.sh` to require `Outcome Proof`, `Implementation Boundaries`, `validate-plan-outcome-proof.sh`, and `readiness review` in the generated summary.

Run:

```bash
./scripts/test-contract-summary.sh
```

Expected before summary updates: fails on missing outcome-proof summary text.

- [ ] **Step 2: Update README**

Add a short section after `Task # Use Cases` in `README.md` explaining that every implementation plan must include an Outcome Proof and Implementation Boundaries, and that issue mirrors and execution ledgers carry compact contract proof through merge.

- [ ] **Step 3: Update generated summary source and regenerate**

Modify `scripts/generate-contract-summary.sh` to include the same outcome workflow. Then run:

```bash
./scripts/generate-contract-summary.sh
```

Expected: `docs/superpowers/OUTCOME_WORKFLOW.md` is updated from the generator.

- [ ] **Step 4: Run focused proof**

Run:

```bash
./scripts/test-contract-summary.sh
```

Expected: outcome workflow checks pass.

- [ ] **Step 5: Commit**

```bash
git add README.md scripts/generate-contract-summary.sh scripts/test-contract-summary.sh docs/superpowers/OUTCOME_WORKFLOW.md
git commit -m "Document outcome proof workflow"
```

### Task 7: Validate, Sync, And Close Out

**Use Cases:**
- Focused validators prove each changed gate rejects missing contract proof.
- Full repo validation proves the plugin contract remains coherent.
- Live sync validation proves the source repo can deploy the new contract.
- Cleanup proof shows no repo-owned background processes remain.

**Files:**
- Modify: no source changes expected unless validation identifies a specific broken contract.

- [ ] **Step 1: Validate this plan's Task # Use Cases**

Run:

```bash
./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-06-19-krypton-outcome-proof-adoption-plan.md
```

Expected: JSON output has `"ok": true` and `task_count` is `7`.

- [ ] **Step 2: Run focused proof commands**

Run:

```bash
./scripts/test-plan-outcome-proof.sh
./skills/write-plan/scripts/test-scenarios.sh
./skills/create-issues/scripts/test-scenarios.sh
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/test-contract-summary.sh
```

Expected: every command exits `0`.

- [ ] **Step 3: Run full validation**

Run:

```bash
./scripts/validate.sh
```

Expected: final JSON has `"ok": true`.

- [ ] **Step 4: Run live sync validation**

Run:

```bash
./scripts/sync-live.sh --validate
```

Expected: command exits `0` and reports successful validation.

- [ ] **Step 5: Run cleanup proof**

Run:

```bash
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Expected: no matching leftover Codex processes under the repo.

- [ ] **Step 6: Commit final proof or generated updates**

If validation generated tracked updates, commit them:

```bash
git add README.md docs/superpowers/OUTCOME_WORKFLOW.md scripts skills docs/superpowers/specs docs/superpowers/plans
git commit -m "Adopt Krypton-style outcome proofs"
```

If no generated tracked updates remain, record the final validation and cleanup results in the merge-ready handoff instead of creating an empty commit.

## Plan Self-Review

- Spec coverage: every acceptance criterion in `docs/superpowers/specs/2026-06-19-krypton-outcome-proof-adoption-design.md` maps to at least one task.
- Task use cases: every numbered task includes a non-empty `**Use Cases:**` block before files and steps.
- TDD policy: all implementation tasks begin with failing scenario or contract tests before skill/script changes.
- Debug policy: no bug diagnosis lane is required because this is forward contract work, not a known runtime defect.
- Verification policy: completion requires focused tests, full validation, live sync validation, and cleanup proof.

