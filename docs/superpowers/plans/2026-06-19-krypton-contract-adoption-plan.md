# Krypton Contract Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed Krypton-style ownership, contract, cutover, and evidence gates into Superpowers Project plans, issue mirrors, execution ledgers, and merge proof.

**Architecture:** Add a shared PowerShell outcome-contract helper and validator wrapper, then thread its contract shape through existing project skills instead of creating a new workflow route. Planning writes the full contract, issue mirrors carry a compact summary, execution ledgers carry structured contract proof, and merge gates reject missing contract reviews.

**Tech Stack:** Markdown skill contracts, YAML agent metadata, PowerShell validators and scenario tests, existing Superpowers Project validation and sync scripts.

---

## Source Material

- Source spec: `docs/superpowers/specs/2026-06-19-krypton-contract-adoption-design.md`
- Audit findings: `docs/superpowers/specs/2026-06-19-krypton-integration-audit-findings.md`
- Auto Mode authorization ledger: `.superpowers/runs/2026-06-19-krypton-contract-adoption/auto-mode-authorization.json`
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
- full `scripts/validate.ps1` passes;
- `scripts/sync-live.ps1 -Validate` passes before any live install update;
- cleanup hook reports no repo-owned leftover processes.

## Acceptance Criteria

- Every implementation plan must include a required `## Outcome Contract`.
- Every implementation plan must include a required `## Architecture Slice`.
- Plan validation rejects missing or generic contract fields.
- Issue mirrors created from plans must carry compact contract summaries.
- Issue mirror validation rejects missing or contradictory contract summaries.
- Implement-plan and resolve-issue setup ledgers carry structured contract fields.
- PR-ready, merge-ready, and premerge proof reject missing contract review evidence.
- Krypton-inspired wrong-layer, weak-evidence, cutover-debt, issue propagation, and contract-drift scenarios are covered by repo-owned tests.
- Full repo validation and live sync validation pass.

## Proof Oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-outcome-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

## Risk And Dependency Notes

- The shared helper should be added before skill text changes so all later validators can call the same field and section checks.
- Plan and issue validators should fail before execution validators are tightened; otherwise existing generated fixtures become noisy.
- Execution and merge ledger fields should use one structured `outcome_contract` object so future routes can reuse the same contract shape.
- No upstream Krypton files should be vendored into `skills/`; the ignored local copy is reference material only.

### Task 1: Add Shared Outcome Contract Validator

**Use Cases:**
- A saved plan without `## Outcome Contract` is rejected before issue creation or implementation starts.
- A plan with missing truth owner, contract interface, cutover, displaced path handling, or target-perspective evidence is rejected with a clear validator reason.
- A wrong-layer feature fixture fails until source of truth, read path, write path, and evidence lane are explicit.
- A cutover-debt fixture fails when two current-looking paths remain without kill criteria.

**Files:**
- Create: `scripts/lib/outcome-contract.ps1`
- Create: `scripts/validate-plan-outcome-contract.ps1`
- Create: `scripts/test-plan-outcome-contract.ps1`
- Modify: `scripts/validate.ps1`

- [ ] **Step 1: Write the failing plan-contract scenario test**

Create `scripts/test-plan-outcome-contract.ps1` with fixture plans under a temp repo. Include one valid plan and at least three invalid plans:

```powershell
$validPlan = @'
# Valid Contract Plan

## Outcome Contract

**Intent:** Make contract adoption enforceable.
**Current Behavior:** Plans require use cases but do not require contract ownership.
**Expected Outcome:** Plans carry ownership, cutover, and evidence gates.
**Target-Perspective Output:** Maintainer sees a validator pass only when contract fields are present.
**Truth Owner:** `scripts/lib/outcome-contract.ps1`
**Contract Interface:** Markdown fields consumed by validator scripts.
**Cutover Decision:** Extend the existing plan readiness path.
**Displaced Path:** Plan readiness based only on Task # Use Cases.
**Evidence Lane:** CLI validator output.
**Acceptance Evidence:** `validate-plan-outcome-contract.ps1` returns `ok: true`.
**Kill Criteria:** Reject plans that omit required ownership or proof fields.
**Forbidden Moves:** Do not create a separate `docs/goals` route.
**Risk If Wrong:** Agents can ship plausible work with weak ownership proof.

## Architecture Slice

**Files To Create:** `scripts/lib/outcome-contract.ps1`
**Files To Modify:** `scripts/validate.ps1`
**Files To Avoid:** `skills/krypton-*`
**Source Of Truth:** plan outcome contract section
**Read Path:** plan markdown -> validator helper
**Write Path:** `$superpowers-project:write-plan` writes the section
**Integration Points:** plan validation and issue validation
**Migration Or Cutover:** old plan readiness is extended, not replaced
**Displaced Path Handling:** Task-only readiness no longer stands alone
**Acceptance Evidence Gate:** focused validator test passes

### Work Item 1: Add Validator

**Use Cases:**
- Contract fixture passes with full ownership and evidence fields.

**Files:**
- Create: `scripts/lib/outcome-contract.ps1`

- [ ] **Step 1: Add helper**
'@
```

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-outcome-contract.ps1
```

Expected before implementation: fails because `scripts/validate-plan-outcome-contract.ps1` does not exist.

- [ ] **Step 2: Implement the shared helper**

Create `scripts/lib/outcome-contract.ps1` with functions that parse Markdown sections and required fields:

```powershell
$script:OutcomeContractFields = @(
    "Intent",
    "Current Behavior",
    "Expected Outcome",
    "Target-Perspective Output",
    "Truth Owner",
    "Contract Interface",
    "Cutover Decision",
    "Displaced Path",
    "Evidence Lane",
    "Acceptance Evidence",
    "Kill Criteria",
    "Forbidden Moves",
    "Risk If Wrong"
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
    "Displaced Path Handling",
    "Acceptance Evidence Gate"
)
```

The helper should expose `Test-PlanOutcomeContract` and `Test-IssueOutcomeContractSummary`, each returning an object with `ok`, `reason`, and `fields`.

- [ ] **Step 3: Implement the plan validator wrapper**

Create `scripts/validate-plan-outcome-contract.ps1` with parameters:

```powershell
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$PlanPath
)
```

The wrapper must resolve repo-relative paths safely, require `docs/superpowers/plans`, call `Test-PlanOutcomeContract`, print JSON, and exit nonzero when `ok` is false.

- [ ] **Step 4: Wire the focused test into full validation**

Modify `scripts/validate.ps1` after the existing `Plan task use cases` step:

```powershell
$results.Add((Invoke-Step "Plan outcome contract" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-plan-outcome-contract.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Plan outcome contract failed" }
}))
```

- [ ] **Step 5: Run focused proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-outcome-contract.ps1
```

Expected after implementation: JSON output has `"ok": true` and includes valid, missing-section, missing-field, weak-evidence, and cutover-debt checks.

- [ ] **Step 6: Commit**

```powershell
git add scripts/lib/outcome-contract.ps1 scripts/validate-plan-outcome-contract.ps1 scripts/test-plan-outcome-contract.ps1 scripts/validate.ps1
git commit -m "Add outcome contract plan validator"
```

### Task 2: Require Outcome Contract In Project Plan

**Use Cases:**
- A future `$superpowers-project:write-plan` run must write the contract before tasks.
- Agents see the same contract requirement from `SKILL.md` and startup metadata.
- The planning grill asks for missing ownership, cutover, and evidence fields instead of inventing them.
- Existing Task # Use Cases remain mandatory and now map to contract concerns.

**Files:**
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing scenario checks**

Modify `skills/write-plan/scripts/test-scenarios.ps1` so the `superpowers writing contract is present`, `planning grill gate is mandatory`, and metadata scenarios require these strings:

```powershell
"## Outcome Contract",
"## Architecture Slice",
"validate-plan-outcome-contract.ps1",
"Truth Owner",
"Contract Interface",
"Cutover Decision",
"Displaced Path",
"Evidence Lane",
"Kill Criteria",
"Forbidden Moves"
```

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
```

Expected before skill edits: fails on missing contract strings.

- [ ] **Step 2: Update `write-plan` skill contract**

Add a section before `## Task # Use Cases Gate` in `skills/write-plan/SKILL.md` named `## Outcome Contract Gate`. Require every implementation plan to include `## Outcome Contract` and `## Architecture Slice`, list the exact fields from the source spec, and require:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-outcome-contract.ps1 -PlanPath <saved-plan-path>
```

The skill text must say that task use cases cover acceptance evidence and cutover or displaced path handling.

- [ ] **Step 3: Update startup metadata**

Update `skills/write-plan/agents/openai.yaml` to include the same outcome-contract gate, validator command, required fields, and relationship to Task # Use Cases.

- [ ] **Step 4: Run focused proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
```

Expected: all write-plan scenario checks pass.

- [ ] **Step 5: Commit**

```powershell
git add skills/write-plan/SKILL.md skills/write-plan/agents/openai.yaml skills/write-plan/scripts/test-scenarios.ps1
git commit -m "Require outcome contracts in project plans"
```

### Task 3: Carry Contract Summaries Into Issue Mirrors

**Use Cases:**
- Creating issues from a plan preserves the plan's truth owner, contract interface, cutover, displaced path, acceptance evidence, kill criteria, and forbidden moves.
- Issue mirror validation rejects ready issue mirrors that drop the contract summary.
- External issue hydration produces or preserves contract-compatible issue mirrors before execution routing.
- Multi-issue mirrors can narrow contract ownership without contradicting the source plan.

**Files:**
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/validate-issue-mirror.ps1`
- Modify: `skills/create-issues/scripts/hydrate-external-issue.ps1`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `scripts/lib/outcome-contract.ps1`

- [ ] **Step 1: Add failing issue-mirror scenario checks**

Extend `skills/create-issues/scripts/test-scenarios.ps1` with one valid issue mirror that includes:

```markdown
## Outcome Contract Summary

**Outcome Contract Source:** docs/superpowers/plans/valid-plan.md#outcome-contract
**Intent:** Enforce contract continuity.
**Target-Perspective Output:** Maintainer sees issue execution blocked without contract proof.
**Truth Owner:** `scripts/lib/outcome-contract.ps1`
**Contract Interface:** Markdown issue summary fields consumed by validators.
**Cutover Decision:** Extend issue readiness validation.
**Displaced Path:** Issue readiness without contract summary.
**Acceptance Evidence:** issue validator returns `ok: true`.
**Kill Criteria:** Reject issue mirrors missing contract proof.
**Forbidden Moves:** Do not use `docs/goals` as the issue source.
```

Add one invalid issue mirror missing `## Outcome Contract Summary`. Expected before validator edits: invalid mirror currently passes, so the new check fails.

- [ ] **Step 2: Extend shared helper for issue summaries**

In `scripts/lib/outcome-contract.ps1`, implement `Test-IssueOutcomeContractSummary` with fields:

```powershell
$script:IssueOutcomeContractFields = @(
    "Outcome Contract Source",
    "Intent",
    "Target-Perspective Output",
    "Truth Owner",
    "Contract Interface",
    "Cutover Decision",
    "Displaced Path",
    "Acceptance Evidence",
    "Kill Criteria",
    "Forbidden Moves"
)
```

Reject summaries with empty generic values and reject `docs/goals` in the contract source.

- [ ] **Step 3: Wire issue mirror validation**

Modify `skills/create-issues/scripts/validate-issue-mirror.ps1` to import `scripts/lib/outcome-contract.ps1` from the repo root and call `Test-IssueOutcomeContractSummary` after source artifact validation.

Add returned check entries named:

```powershell
Add-Check -Name "outcome contract summary" -Ok $contractResult.ok -Reason $contractResult.reason
```

When the contract result fails, complete with that reason.

- [ ] **Step 4: Update hydration output**

Modify `skills/create-issues/scripts/hydrate-external-issue.ps1` so generated mirrors include `## Outcome Contract Summary`. For externally hydrated issues with sparse source data, derive the summary from the external issue body and the generated source plan. Use concrete values such as the source plan path, issue intent, expected target output, validator-owned truth, and proof oracle.

- [ ] **Step 5: Update skill text and metadata**

Update `skills/create-issues/SKILL.md` and `skills/create-issues/agents/openai.yaml` to require outcome contract summaries in every issue mirror and to state that issue execution is blocked when the summary is missing or contradicts the source plan.

- [ ] **Step 6: Run focused proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
```

Expected: valid issue mirrors pass; missing contract summary fails; hydration tests pass with contract summary present.

- [ ] **Step 7: Commit**

```powershell
git add scripts/lib/outcome-contract.ps1 skills/create-issues/SKILL.md skills/create-issues/agents/openai.yaml skills/create-issues/scripts/validate-issue-mirror.ps1 skills/create-issues/scripts/hydrate-external-issue.ps1 skills/create-issues/scripts/test-scenarios.ps1
git commit -m "Carry outcome contracts into issue mirrors"
```

### Task 4: Carry Contract Fields Through Execution Ledgers

**Use Cases:**
- Non-issue implementation cannot produce merge-ready evidence without carrying the approved plan's outcome contract.
- Issue-backed resolution cannot finalize setup when the issue mirror lacks contract fields.
- PR-ready evidence cannot pass when acceptance coverage is present but contract review evidence is missing.
- Contract drift during execution is represented as a structured blocker, not a prose-only note.

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/lib/contract.ps1`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/prepare-execution.ps1`
- Modify: `skills/resolve-issue/scripts/validate-setup.ps1`
- Modify: `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1`
- Modify: `skills/resolve-issue/scripts/validate-pr-ready.ps1`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing implement-plan ledger tests**

Modify `skills/implement-plan/scripts/test-scenarios.ps1` so `New-HappyLedger` includes:

```powershell
outcome_contract = [pscustomobject]@{
    intent = "Adopt outcome contracts"
    truth_owner = "scripts/lib/outcome-contract.ps1"
    contract_interface = "structured outcome_contract ledger object"
    cutover_decision = "extend existing execution proof"
    displaced_path = "merge-ready proof without contract review"
    acceptance_evidence = "contract review evidence is structured"
    kill_criteria = "block merge-ready when contract review is missing"
    forbidden_moves = @("docs/goals route", "string-only contract proof")
}
contract_review = [pscustomobject]@{
    plan_alignment = $true
    correctness = $true
    maintainability = $true
    reality_evidence = $true
}
```

Add a negative fixture where `outcome_contract` is removed. Expected before implementation: the missing field is not rejected, so the new negative check fails.

- [ ] **Step 2: Tighten implement-plan contract helper**

Modify `skills/implement-plan/scripts/lib/contract.ps1` so `Test-ImplementPlanLedger` requires structured `outcome_contract` and structured `contract_review`. Reject string values and require review booleans for `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence`.

- [ ] **Step 3: Update resolve setup and PR-ready tests**

Modify `skills/resolve-issue/scripts/test-scenarios.ps1` happy setup and PR-ready fixtures to include `outcome_contract` and `contract_review`. Add negative fixtures for missing setup contract and missing PR-ready contract review.

- [ ] **Step 4: Carry issue contract from mirror to handoff and setup**

Modify `skills/resolve-issue/scripts/prepare-execution.ps1`:

- `Read-IssueMirrorContract` extracts `## Outcome Contract Summary`.
- the inspect handoff includes structured `outcome_contract`.
- `FinalizeSetup` writes that object to the setup ledger.

- [ ] **Step 5: Validate resolve setup and PR-ready ledgers**

Modify `skills/resolve-issue/scripts/validate-setup.ps1` to require `outcome_contract`.

Modify `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1` to accept a `-ContractReviewJson` input and write `contract_review` into the PR-ready ledger.

Modify `skills/resolve-issue/scripts/validate-pr-ready.ps1` to require `contract_review` with the four review lanes.

- [ ] **Step 6: Update skill text and metadata**

Update implement and resolve `SKILL.md` plus `agents/openai.yaml` files so startup-loaded agents must restate the outcome contract before edits and must collect contract review evidence before push, PR-ready, or merge-ready claims.

- [ ] **Step 7: Run focused proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
```

Expected: both scripts return passing JSON and reject fixtures missing contract fields or review lanes.

- [ ] **Step 8: Commit**

```powershell
git add skills/implement-plan/SKILL.md skills/implement-plan/agents/openai.yaml skills/implement-plan/scripts/lib/contract.ps1 skills/implement-plan/scripts/test-scenarios.ps1 skills/resolve-issue/SKILL.md skills/resolve-issue/agents/openai.yaml skills/resolve-issue/scripts/prepare-execution.ps1 skills/resolve-issue/scripts/validate-setup.ps1 skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1 skills/resolve-issue/scripts/validate-pr-ready.ps1 skills/resolve-issue/scripts/test-scenarios.ps1
git commit -m "Carry outcome contracts through execution proof"
```

### Task 5: Enforce Contract Review In Merge Proof

**Use Cases:**
- Premerge proof fails when a PR-ready or local-branch verification ledger lacks plan alignment review.
- Premerge proof fails when correctness, maintainability, or reality evidence review is missing.
- A passing test command alone cannot satisfy merge readiness.
- Merge closeout remains governed by existing approval and cleanup gates after contract proof passes.

**Files:**
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/lib/contract.ps1`
- Modify: `skills/merge-changes/scripts/collect-premerge-ledger.ps1`
- Modify: `skills/merge-changes/scripts/premerge.ps1`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing merge scenario tests**

Modify `skills/merge-changes/scripts/test-scenarios.ps1` so happy premerge fixtures include:

```powershell
contract_review = [pscustomobject]@{
    plan_alignment = $true
    correctness = $true
    maintainability = $true
    reality_evidence = $true
    evidence = @("target-perspective proof inspected")
}
```

Add a negative premerge fixture where `verification.proof_commands` exists but `contract_review` is missing. Expected before implementation: the fixture passes; after implementation it must fail.

- [ ] **Step 2: Add merge contract review assertion**

In `skills/merge-changes/scripts/lib/contract.ps1`, add `Assert-ContractReviewProof` that rejects missing or string values and requires `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` to be `$true`.

- [ ] **Step 3: Wire premerge validation**

Modify `skills/merge-changes/scripts/premerge.ps1` to call `Assert-ContractReviewProof -Proof $verification.contract_review` for both `local-branch` and `pr-issue` modes before `Complete-Contract`.

- [ ] **Step 4: Update premerge collector**

Modify `skills/merge-changes/scripts/collect-premerge-ledger.ps1` to accept `-ContractReviewJson` and include the parsed object as `contract_review` in the generated verification ledger.

- [ ] **Step 5: Update skill text and metadata**

Update merge `SKILL.md` and `agents/openai.yaml` so premerge proof lists the four contract review lanes and says missing contract review blocks merge approval.

- [ ] **Step 6: Run focused proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
```

Expected: merge scenario tests pass and reject verification ledgers without contract review proof.

- [ ] **Step 7: Commit**

```powershell
git add skills/merge-changes/SKILL.md skills/merge-changes/agents/openai.yaml skills/merge-changes/scripts/lib/contract.ps1 skills/merge-changes/scripts/collect-premerge-ledger.ps1 skills/merge-changes/scripts/premerge.ps1 skills/merge-changes/scripts/test-scenarios.ps1
git commit -m "Require contract review in merge proof"
```

### Task 6: Update Public Contract Surfaces

**Use Cases:**
- New agents can discover the outcome contract from README and generated summary before opening individual skill files.
- Contract summary validation catches stale public documentation.
- Live sync validation deploys the new contract surfaces consistently.

**Files:**
- Modify: `README.md`
- Modify: `scripts/generate-contract-summary.ps1`
- Modify: `scripts/test-contract-summary.ps1`
- Modify: `docs/superpowers/CONTRACT_SUMMARY.md`

- [ ] **Step 1: Add failing contract summary checks**

Modify `scripts/test-contract-summary.ps1` to require `Outcome Contract`, `Architecture Slice`, `validate-plan-outcome-contract.ps1`, and `contract review` in the generated summary.

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
```

Expected before summary updates: fails on missing outcome-contract summary text.

- [ ] **Step 2: Update README**

Add a short section after `Task # Use Cases` in `README.md` explaining that every implementation plan must include an Outcome Contract and Architecture Slice, and that issue mirrors and execution ledgers carry compact contract proof through merge.

- [ ] **Step 3: Update generated summary source and regenerate**

Modify `scripts/generate-contract-summary.ps1` to include the same contract summary. Then run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-contract-summary.ps1
```

Expected: `docs/superpowers/CONTRACT_SUMMARY.md` is updated from the generator.

- [ ] **Step 4: Run focused proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
```

Expected: contract summary checks pass.

- [ ] **Step 5: Commit**

```powershell
git add README.md scripts/generate-contract-summary.ps1 scripts/test-contract-summary.ps1 docs/superpowers/CONTRACT_SUMMARY.md
git commit -m "Document outcome contract workflow"
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

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-19-krypton-contract-adoption-plan.md
```

Expected: JSON output has `"ok": true` and `task_count` is `7`.

- [ ] **Step 2: Run focused proof commands**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-outcome-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
```

Expected: every command exits `0`.

- [ ] **Step 3: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: final JSON has `"ok": true`.

- [ ] **Step 4: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: command exits `0` and reports successful validation.

- [ ] **Step 5: Run cleanup proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no matching leftover Codex processes under the repo.

- [ ] **Step 6: Commit final proof or generated updates**

If validation generated tracked updates, commit them:

```powershell
git add README.md docs/superpowers/CONTRACT_SUMMARY.md scripts skills docs/superpowers/specs docs/superpowers/plans
git commit -m "Adopt Krypton-style outcome contracts"
```

If no generated tracked updates remain, record the final validation and cleanup results in the merge-ready handoff instead of creating an empty commit.

## Plan Self-Review

- Spec coverage: every acceptance criterion in `docs/superpowers/specs/2026-06-19-krypton-contract-adoption-design.md` maps to at least one task.
- Task use cases: every numbered task includes a non-empty `**Use Cases:**` block before files and steps.
- TDD policy: all implementation tasks begin with failing scenario or contract tests before skill/script changes.
- Debug policy: no bug diagnosis lane is required because this is forward contract work, not a known runtime defect.
- Verification policy: completion requires focused tests, full validation, live sync validation, and cleanup proof.
