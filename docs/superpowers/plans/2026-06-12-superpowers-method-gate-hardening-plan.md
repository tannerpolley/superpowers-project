# Superpowers Method Gate Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden Superpowers Project adapter skills so they enforce upstream Superpowers workflow gates with structured proof instead of only naming companion skills.

**Architecture:** Update each adapter contract at the source skill, startup metadata, and executable PowerShell validation layer. Add focused scenario fixtures for each missing method gate, then include any new aggregate validators in `scripts/validate.ps1` so a weakened contract fails locally before live sync.

**Tech Stack:** Markdown skill contracts, YAML agent metadata, PowerShell contract validators, JSON ledgers, repo validation scripts.

---

## Source And Scope

**Source Spec:** `docs/superpowers/specs/2026-06-12-superpowers-method-gate-specific-audit-findings.md`

**Auto Mode Authorization Ledger:** `C:\Users\Tanner\AppData\Local\Temp\superpowers-project\auto-mode\2026-06-12-superpowers-method-gate-specific-authorization.json`

**Recorded Planning Defaults:**

- Scope: source repo only; do not edit plugin cache paths or deployed copies directly.
- Sequencing: implement the two P1 gates first, then the P2 evidence gates.
- Worker route: issue-backed orchestration is the forward route after planning, but this plan itself only prepares executable work.
- TDD policy: required for all behavior-changing validator and script work in this plan.
- Debugging policy: required only when a task encounters a failing validator, scenario test, CI failure, unclear failure, or regression.
- Branch strategy: continue on the active development branch unless later execution chooses an issue-backed worktree.
- Live mutation: after implementation, run `scripts\sync-live.ps1 -Validate`; do not manually edit live or cache plugin files.

## Non-Goals

- Do not change upstream `superpowers:*` skills.
- Do not weaken native continuation, Stop, Done, Revisit, or Auto Mode contracts.
- Do not add broad compatibility flags that allow agents to bypass evidence gates.
- Do not create plugin-cache links or treat cache paths as durable source.
- Do not publish GitHub issues or merge branches from this planning task.

## Acceptance Criteria

- `implement-plan` requires `superpowers:using-git-worktrees` plus structured isolation and clean baseline proof before implementation evidence can pass.
- `orchestrate-issues` requires the upstream subagent two-stage review loop in worker handoffs and rejects handoffs that list skills without review policy proof.
- Execution adapters require TDD red/green receipts for feature, bug, refactor, and behavior-change work unless a source plan explicitly records an opt-out.
- Bug-shaped execution routes require systematic-debugging phase proof before fix claims can pass.
- `write-plan` blocks ready implementation plans with placeholders, missing expected outputs, generic code instructions, or shortcut wording.
- Focused scenario tests cover the new rejection cases and are wired into the existing full validation path.
- Live plugin sync validation is part of implementation completion, but plugin cache files are not edited directly.

## Proof Oracle

Run these commands from the repo root after implementation:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-12-superpowers-method-gate-hardening-plan.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-method-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-exactness.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected results:

- Every command exits `0`.
- JSON-producing validators return `ok: true`.
- `scripts\sync-live.ps1 -Validate` reports the source and live install are in sync.
- The cleanup hook reports no matching leftover Codex processes for this repo, or only terminates processes clearly owned by this task when run later with `-Kill`.

## Test Complete

Testing is complete when all focused scenario tests, the aggregate method contract test, the plan exactness test, the full repo validator, live sync validation, and the repo cleanup hook pass from the repo root. For this repo, no scientific numerical metrics apply; pass/fail is contract-based and exact.

## Metrics And Tolerances

- Required contract text must be present in both `SKILL.md` and `agents/openai.yaml` for each changed skill.
- Required ledger fields must be structured objects or arrays, not prose strings.
- Missing evidence fixtures must fail with a reason naming the missing gate.
- Positive fixtures must pass without disabling the gate.
- The plan exactness validator must reject placeholder and shortcut wording in ready plans.
- No tolerance band applies; validator and scenario-test output must be clean pass/fail.

## File Map

- `skills/implement-plan/SKILL.md`: add the isolation, baseline, TDD, and debugging proof gates to the non-issue implementation contract.
- `skills/implement-plan/agents/openai.yaml`: repeat startup-visible method proof requirements.
- `skills/implement-plan/scripts/lib/contract.ps1`: validate structured implementation evidence.
- `skills/implement-plan/scripts/test-scenarios.ps1`: add positive and negative evidence fixtures.
- `skills/resolve-issue/SKILL.md`: add issue-backed TDD and debugging proof requirements.
- `skills/resolve-issue/agents/openai.yaml`: repeat startup-visible issue-backed proof requirements.
- `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1`: collect method proof into PR-ready ledgers.
- `skills/resolve-issue/scripts/validate-pr-ready.ps1`: reject PR-ready ledgers missing method proof.
- `skills/resolve-issue/scripts/test-scenarios.ps1`: add PR-ready method-proof fixtures.
- `skills/orchestrate-issues/SKILL.md`: add two-stage review, TDD, and debugging worker evidence requirements.
- `skills/orchestrate-issues/agents/openai.yaml`: repeat startup-visible orchestration proof requirements.
- `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`: emit structured worker review and evidence policy.
- `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`: reject weak worker handoffs.
- `skills/orchestrate-issues/scripts/test-scenarios.ps1`: add worker handoff negative fixtures.
- `skills/write-plan/SKILL.md`: add the plan exactness gate.
- `skills/write-plan/agents/openai.yaml`: repeat startup-visible plan exactness requirements.
- `skills/write-plan/scripts/test-scenarios.ps1`: require exactness gate text and validator wiring.
- `scripts/validate-plan-exactness.ps1`: create mechanical validator for ready-plan exactness.
- `scripts/test-plan-exactness.ps1`: create validator fixtures.
- `scripts/test-superpowers-method-contract.ps1`: extend aggregate method contract needles for the new gates.
- `scripts/validate.ps1`: add `test-plan-exactness.ps1` to the full validation path.

## Task 1: Implement-Plan Isolation And Baseline Gate

**Use Cases:**
- A new agent starting non-issue plan implementation cannot begin code edits without reading and applying `superpowers:using-git-worktrees`.
- A handoff ledger with branch, topology, and final verification but no worktree isolation proof fails.
- A handoff ledger with isolation proof but no clean baseline setup and verification proof fails.
- A current-checkout run can only pass when it records an explicit current-checkout reason and clean baseline proof.
- A future edit that removes the worktree or baseline requirement fails focused implement-plan scenario tests.

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/lib/contract.ps1`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `scripts/test-superpowers-method-contract.ps1`

- [ ] **Step 1: Add RED fixtures for missing isolation and baseline proof**
  In `skills/implement-plan/scripts/test-scenarios.ps1`, extend `New-HappyLedger` with this proof shape so positive fixtures represent the new contract:

```powershell
isolation = [pscustomobject]@{
    skill = "superpowers:using-git-worktrees"
    selected_mode = "native-worktree"
    git_dir = ".git/worktrees/codex-implement-approved-plan"
    git_common_dir = ".git"
    isolated = $true
    current_checkout_reason = ""
}
baseline = [pscustomobject]@{
    setup_completed = $true
    clean = $true
    commands = @("pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/plan.md")
    git_status = ""
}
```

  Add a scenario named `contract rejects missing isolation and baseline proof`. First remove `$ledger.isolation` and assert the failure reason matches `isolation`; then restore isolation, remove `$ledger.baseline`, and assert the failure reason matches `baseline`.

- [ ] **Step 2: Validate the RED state**
  Run this command before contract changes:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
```

  Expected result before implementation: exit code `1`, with `contract rejects missing isolation and baseline proof` failing because `Test-ImplementPlanLedger` still accepts ledgers without those fields.

- [ ] **Step 3: Add contract helper checks**
  In `skills/implement-plan/scripts/lib/contract.ps1`, add these helper functions above `Test-ImplementPlanLedger`:

```powershell
function Assert-StructuredField {
    param([object]$Object, [string]$Name)
    if (-not (Test-Property $Object $Name) -or $Object.$Name -is [string]) { throw "$Name proof must be structured" }
    $Object.$Name
}

function Assert-IsolationProof {
    param($Proof)
    if ([string]$Proof.skill -ne "superpowers:using-git-worktrees") { throw "isolation proof must name superpowers:using-git-worktrees" }
    if ([string]$Proof.selected_mode -notin @("native-worktree", "git-worktree", "current-checkout-approved")) { throw "isolation selected_mode is invalid" }
    if (-not (Test-Property $Proof "isolated")) { throw "isolation proof must record isolated" }
    if ([string]$Proof.selected_mode -eq "current-checkout-approved" -and [string]::IsNullOrWhiteSpace([string]$Proof.current_checkout_reason)) { throw "current checkout execution requires a reason" }
    foreach ($field in @("git_dir", "git_common_dir")) {
        if (-not (Test-Property $Proof $field) -or [string]::IsNullOrWhiteSpace([string]$Proof.$field)) { throw "isolation proof missing $field" }
    }
}

function Assert-BaselineProof {
    param($Proof)
    if ($Proof.setup_completed -ne $true) { throw "baseline proof requires setup_completed" }
    if ($Proof.clean -ne $true) { throw "baseline proof requires clean" }
    $commands = @($Proof.commands | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($commands.Count -eq 0) { throw "baseline proof requires commands" }
    if (-not (Test-Property $Proof "git_status")) { throw "baseline proof requires git_status" }
}
```

  Then call:

```powershell
$isolation = Assert-StructuredField -Object $Ledger -Name "isolation"
Assert-IsolationProof -Proof $isolation
$baseline = Assert-StructuredField -Object $Ledger -Name "baseline"
Assert-BaselineProof -Proof $baseline
```

  Place these calls after the topology validation and before final verification validation.

- [ ] **Step 4: Harden implement-plan text and metadata**
  In `skills/implement-plan/SKILL.md`, update `## Superpowers Method Contract` so it explicitly requires `superpowers:using-git-worktrees` before implementation, and add an `## Isolation And Baseline Gate` section with these blocking rules:

```markdown
Before code edits, worker handoff, or implementation claims, require structured isolation proof and clean baseline proof. Isolation proof must name `superpowers:using-git-worktrees`, record the selected mode (`native-worktree`, `git-worktree`, or `current-checkout-approved`), record `git rev-parse --git-dir` and `git rev-parse --git-common-dir` evidence, and record a current-checkout reason when current-checkout execution is approved. Baseline proof must record setup completion, clean baseline commands, clean result, and git status before task execution. If baseline verification fails, stop and route to Revisit or systematic debugging before implementation.
```

  Add the same required phrases to `skills/implement-plan/agents/openai.yaml`: `superpowers:using-git-worktrees`, `Isolation And Baseline Gate`, `native-worktree`, `git-worktree`, `current-checkout-approved`, `setup completion`, `clean baseline commands`, and `stop and route to Revisit or systematic debugging`.

- [ ] **Step 5: Extend the aggregate method contract**
  In `scripts/test-superpowers-method-contract.ps1`, extend the `implement-plan companion method contract` needles to require the new isolation and baseline phrases in both skill and metadata. Use normalized text matching in the existing `Test-Contract` call.

- [ ] **Step 6: Validate the GREEN state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-method-contract.ps1
```

  Expected result after implementation: both commands exit `0`; the missing-isolation and missing-baseline fixtures fail inside the test harness as expected, and the happy ledger passes.

- [ ] **Step 7: Commit this slice**
  Commit after the focused tests pass:

```powershell
git add skills/implement-plan/SKILL.md skills/implement-plan/agents/openai.yaml skills/implement-plan/scripts/lib/contract.ps1 skills/implement-plan/scripts/test-scenarios.ps1 scripts/test-superpowers-method-contract.ps1
git commit -m "Harden implement-plan isolation gate"
```

## Task 2: Orchestrate-Issues Subagent Review Gate

**Use Cases:**
- A worker handoff cannot pass only by listing companion skill names.
- A handoff requires fresh worker context per issue task or an explicit single-task reason.
- Spec compliance review is required before code quality review.
- Reviewer-found issues must return to the implementer and be re-reviewed until approved.
- PR-ready worker intake is blocked unless final whole-implementation review receipts are required by the handoff.

**Files:**
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `scripts/test-superpowers-method-contract.ps1`

- [ ] **Step 1: Add RED worker handoff review-policy fixture**
  In `skills/orchestrate-issues/scripts/test-scenarios.ps1`, after the existing `prepare and validate worker handoff` scenario prepares a valid handoff, add a separate scenario named `worker handoff rejects missing subagent review policy`. Prepare a handoff, remove `$handoff.review_policy`, pass it to `validate-worker-handoff.ps1` through `-HandoffJson`, and assert the validator exits non-zero with a reason matching `review_policy`.

- [ ] **Step 2: Validate the RED state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
```

  Expected result before implementation: exit code `1`, because the current validator accepts handoffs without `review_policy`.

- [ ] **Step 3: Emit structured review policy in worker handoffs**
  In `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`, add this sibling object after `topology_handoff` and before `required_skills`:

```powershell
review_policy = [ordered]@{
    base_skill = "superpowers:subagent-driven-development"
    fresh_context_per_issue = $true
    single_indivisible_task_reason = ""
    worker_must_extract_full_task_text = $true
    implementer_statuses = @("DONE", "DONE_WITH_CONCERNS", "NEEDS_CONTEXT", "BLOCKED")
    required_review_sequence = @("spec-compliance-review", "code-quality-review", "final-implementation-review")
    code_quality_after_spec_compliance = $true
    reviewer_found_issues_return_to_implementer = $true
    re_review_until_approved = $true
    block_pr_ready_without_review_receipts = $true
}
```

- [ ] **Step 4: Validate review policy fields**
  In `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`, add `review_policy` to the required top-level fields. Then assert:

```powershell
$reviewPolicy = $handoff.review_policy
if ($reviewPolicy -is [string]) { throw "review_policy must be structured" }
if ([string]$reviewPolicy.base_skill -ne "superpowers:subagent-driven-development") { throw "review_policy base_skill must be superpowers:subagent-driven-development" }
if ($reviewPolicy.fresh_context_per_issue -ne $true -and [string]::IsNullOrWhiteSpace([string]$reviewPolicy.single_indivisible_task_reason)) { throw "fresh worker context or single task reason is required" }
if ($reviewPolicy.worker_must_extract_full_task_text -ne $true) { throw "worker must extract full task text" }
$statuses = @($reviewPolicy.implementer_statuses | ForEach-Object { [string]$_ })
foreach ($status in @("DONE", "DONE_WITH_CONCERNS", "NEEDS_CONTEXT", "BLOCKED")) {
    if ($statuses -notcontains $status) { throw "review_policy missing implementer status: $status" }
}
$sequence = @($reviewPolicy.required_review_sequence | ForEach-Object { [string]$_ })
foreach ($stage in @("spec-compliance-review", "code-quality-review", "final-implementation-review")) {
    if ($sequence -notcontains $stage) { throw "review_policy missing review stage: $stage" }
}
if ($sequence.IndexOf("spec-compliance-review") -gt $sequence.IndexOf("code-quality-review")) { throw "spec compliance review must precede code quality review" }
foreach ($field in @("code_quality_after_spec_compliance", "reviewer_found_issues_return_to_implementer", "re_review_until_approved", "block_pr_ready_without_review_receipts")) {
    if ($reviewPolicy.$field -ne $true) { throw "review_policy requires $field" }
}
```

- [ ] **Step 5: Harden orchestrate text and metadata**
  In `skills/orchestrate-issues/SKILL.md`, add a `## Subagent Review Gate` section requiring `superpowers:subagent-driven-development` two-stage review, fresh context per issue task, implementer statuses, spec compliance review before code quality review, re-review until approved, and final whole-implementation review. Add matching startup-visible summary text to `skills/orchestrate-issues/agents/openai.yaml`.

- [ ] **Step 6: Extend the aggregate method contract**
  In `scripts/test-superpowers-method-contract.ps1`, extend `orchestrate-issues companion method contract` needles with `Subagent Review Gate`, `spec compliance review before code quality review`, `re-review until approved`, `final whole-implementation review`, and `block PR-ready intake`.

- [ ] **Step 7: Validate the GREEN state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-method-contract.ps1
```

  Expected result after implementation: both commands exit `0`; missing `review_policy` is rejected, and the generated happy handoff passes.

- [ ] **Step 8: Commit this slice**
  Commit after the focused tests pass:

```powershell
git add skills/orchestrate-issues/SKILL.md skills/orchestrate-issues/agents/openai.yaml skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1 skills/orchestrate-issues/scripts/validate-worker-handoff.ps1 skills/orchestrate-issues/scripts/test-scenarios.ps1 scripts/test-superpowers-method-contract.ps1
git commit -m "Require orchestrated subagent review proof"
```

## Task 3: TDD Red/Green Proof Gate

**Use Cases:**
- A feature or bug implementation cannot satisfy the contract with only final verification passed.
- A PR-ready ledger for issue-backed work records RED command, expected failure, GREEN command, passing result, and final relevant test command.
- A non-issue implementation ledger records equivalent per-task TDD receipts.
- A plan-level opt-out can pass only when the ledger names the opt-out source and scope.
- Worker handoffs tell delegated agents exactly what TDD evidence they must return.

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/lib/contract.ps1`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1`
- Modify: `skills/resolve-issue/scripts/validate-pr-ready.ps1`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `scripts/test-superpowers-method-contract.ps1`

- [ ] **Step 1: Add RED fixtures for missing TDD proof**
  Add `tdd` to the happy implementation and PR-ready fixtures:

```powershell
tdd = [pscustomobject]@{
    required = $true
    opt_out = $false
    opt_out_source = ""
    receipts = @(
        [pscustomobject]@{
            task = "Task 1"
            red_command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1"
            red_expected = "FAIL before production contract accepts missing gate"
            green_command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1"
            green_result = "PASS"
            final_command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1"
        }
    )
}
```

  In `skills/implement-plan/scripts/test-scenarios.ps1`, add `contract rejects verification-only TDD proof`: remove `$ledger.tdd` from a happy ledger and assert failure matches `TDD`. Add a second fixture with `tdd = @{ required = $true; opt_out = $false; receipts = @() }` and assert failure matches `RED`.

  In `skills/resolve-issue/scripts/test-scenarios.ps1`, add `PR-ready handoff rejects missing TDD proof`: build the existing happy PR-ready ledger without `tdd` and assert `validate-pr-ready.ps1` fails with a reason matching `TDD`.

- [ ] **Step 2: Validate the RED state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
```

  Expected result before implementation: both commands exit `1` because the current contracts accept verification-only evidence.

- [ ] **Step 3: Add implement-plan TDD validation**
  In `skills/implement-plan/scripts/lib/contract.ps1`, add:

```powershell
function Assert-TddProof {
    param($Proof)
    if ($Proof -is [string]) { throw "TDD proof must be structured" }
    if ($Proof.required -ne $true) { throw "TDD proof must record required true for implementation work" }
    if ($Proof.opt_out -eq $true) {
        if ([string]::IsNullOrWhiteSpace([string]$Proof.opt_out_source)) { throw "TDD opt-out source is required" }
        return
    }
    $receipts = @($Proof.receipts)
    if ($receipts.Count -eq 0) { throw "TDD RED/GREEN receipts are required" }
    foreach ($receipt in $receipts) {
        foreach ($field in @("task", "red_command", "red_expected", "green_command", "green_result", "final_command")) {
            if (-not (Test-Property $receipt $field) -or [string]::IsNullOrWhiteSpace([string]$receipt.$field)) { throw "TDD receipt missing $field" }
        }
    }
}
```

  Call it from `Test-ImplementPlanLedger` after baseline validation:

```powershell
$tdd = Assert-StructuredField -Object $Ledger -Name "tdd"
Assert-TddProof -Proof $tdd
```

- [ ] **Step 4: Add resolve-issue TDD collection and validation**
  In `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1`, add parameters:

```powershell
[string]$TddProofJson,
[string]$TddProofPath,
```

  Read the proof and include it in the emitted ledger:

```powershell
$tddProof = Read-JsonInput -Json $TddProofJson -Path $TddProofPath -Name "TDD proof"
...
tdd = $tddProof
```

  In `skills/resolve-issue/scripts/validate-pr-ready.ps1`, add a local `Assert-TddProof` function with the same required fields and call it after the structured field checks:

```powershell
if (-not (Test-Property -Object $ready -Name "tdd") -or $ready.tdd -is [string]) { throw "PR-ready ledger TDD proof must be structured" }
Assert-TddProof -Proof $ready.tdd
```

- [ ] **Step 5: Add worker handoff TDD evidence policy**
  In `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`, add an `evidence_policy` object if Task 4 has not already added it. It must include:

```powershell
evidence_policy = [ordered]@{
    tdd_red_green_required = $true
    tdd_required_fields = @("task", "red_command", "red_expected", "green_command", "green_result", "final_command")
}
```

  In `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`, require `evidence_policy.tdd_red_green_required -eq $true` and every `tdd_required_fields` value listed above.

- [ ] **Step 6: Harden skill text and metadata**
  In `implement-plan`, `resolve-issue`, and `orchestrate-issues` skill text and metadata, add a `TDD Red/Green Proof Gate` that says final verification alone is insufficient. Require RED command, expected failing assertion or failure reason, GREEN command, passing result, final relevant test command, and explicit opt-out source when the approved plan opts out.

- [ ] **Step 7: Extend aggregate method contract**
  In `scripts/test-superpowers-method-contract.ps1`, add needles for `TDD Red/Green Proof Gate`, `RED command`, `expected failing assertion`, `GREEN command`, `final relevant test command`, and `final verification alone is insufficient` to the implement, resolve, and orchestrate contract checks.

- [ ] **Step 8: Validate the GREEN state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-method-contract.ps1
```

  Expected result after implementation: all commands exit `0`; verification-only fixtures fail inside the test harness, and opt-out fixtures pass only with source and scope recorded.

- [ ] **Step 9: Commit this slice**
  Commit after the focused tests pass:

```powershell
git add skills/implement-plan skills/resolve-issue skills/orchestrate-issues scripts/test-superpowers-method-contract.ps1
git commit -m "Require TDD red green proof"
```

## Task 4: Debugging Phase Proof Gate

**Use Cases:**
- A bug, regression, CI failure, performance issue, or unclear failure cannot pass by saying a debugging skill was used.
- Execution evidence separates root-cause proof from final verification proof.
- A worker handoff tells delegated agents to return phase-based debugging receipts for bug-shaped work.
- A fourth fix attempt is blocked unless the route records architecture review or user-decision escalation.
- A failing reproduction test is required before the fix when the failure shape makes that feasible.

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/lib/contract.ps1`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1`
- Modify: `skills/resolve-issue/scripts/validate-pr-ready.ps1`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Modify: `scripts/test-superpowers-method-contract.ps1`

- [ ] **Step 1: Add RED fixtures for missing debugging phase proof**
  Add a bug-shaped ledger fixture to implement-plan and resolve-issue tests:

```powershell
work_shape = "bug"
debugging = [pscustomobject]@{
    required = $true
    phase1_root_cause = [pscustomobject]@{
        error_text = "fixture failure"
        reproduction = "pwsh.exe -NoProfile -Command 'throw ""fixture failure""'"
        recent_change_check = "inspected current diff"
        component_boundary = "contract validator"
        data_flow_trace = "ledger -> validator -> failure reason"
    }
    phase2_pattern_analysis = [pscustomobject]@{
        comparison = "existing structured ledger validators"
    }
    phase3_hypothesis = [pscustomobject]@{
        hypothesis = "missing structured proof lets invalid ledgers pass"
        smallest_test = "negative scenario removes debugging proof"
    }
    phase4_fix = [pscustomobject]@{
        reproduction_test = "negative scenario fails before fix"
        fix_summary = "validator rejects missing phase proof"
    }
    fix_attempts = 1
    escalation = ""
}
```

  Add scenarios that remove `debugging` from a bug-shaped ledger and assert the validator failure matches `debugging`. Add a fixture with `fix_attempts = 4` and empty `escalation`, and assert failure matches `fourth fix` or `escalation`.

- [ ] **Step 2: Validate the RED state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
```

  Expected result before implementation: both commands exit `1`, because bug-shaped ledgers can currently pass without debugging phase proof.

- [ ] **Step 3: Add debugging validators**
  In `skills/implement-plan/scripts/lib/contract.ps1` and `skills/resolve-issue/scripts/validate-pr-ready.ps1`, add an `Assert-DebuggingProof` function:

```powershell
function Assert-DebuggingProof {
    param($WorkShape, $Proof)
    $bugShapes = @("bug", "regression", "ci-failure", "performance", "unclear-failure")
    if ($bugShapes -notcontains [string]$WorkShape) { return }
    if ($Proof -is [string] -or $null -eq $Proof) { throw "debugging phase proof must be structured for bug-shaped work" }
    foreach ($phase in @("phase1_root_cause", "phase2_pattern_analysis", "phase3_hypothesis", "phase4_fix")) {
        if (-not (Test-Property $Proof $phase) -or $Proof.$phase -is [string]) { throw "debugging proof missing $phase" }
    }
    foreach ($field in @("error_text", "reproduction", "recent_change_check")) {
        if (-not (Test-Property $Proof.phase1_root_cause $field) -or [string]::IsNullOrWhiteSpace([string]$Proof.phase1_root_cause.$field)) { throw "debugging phase1_root_cause missing $field" }
    }
    foreach ($field in @("hypothesis", "smallest_test")) {
        if (-not (Test-Property $Proof.phase3_hypothesis $field) -or [string]::IsNullOrWhiteSpace([string]$Proof.phase3_hypothesis.$field)) { throw "debugging phase3_hypothesis missing $field" }
    }
    if ([int]$Proof.fix_attempts -ge 4 -and [string]::IsNullOrWhiteSpace([string]$Proof.escalation)) { throw "fourth fix attempt requires architecture review or user-decision escalation" }
}
```

  In implement-plan, call:

```powershell
$workShape = if (Test-Property $Ledger "work_shape") { [string]$Ledger.work_shape } else { "feature" }
Assert-DebuggingProof -WorkShape $workShape -Proof $Ledger.debugging
```

  In resolve-issue PR-ready validation, call the same function with `$ready.work_shape` and `$ready.debugging`.

- [ ] **Step 4: Collect debugging proof for issue-backed PR-ready ledgers**
  In `skills/resolve-issue/scripts/collect-pr-ready-ledger.ps1`, add parameters:

```powershell
[string]$WorkShape = "feature",
[string]$DebuggingProofJson,
[string]$DebuggingProofPath,
```

  Read the proof only when `$WorkShape` is one of the bug-shaped values, then include `work_shape` and `debugging` in the emitted ledger.

- [ ] **Step 5: Add worker handoff debugging evidence policy**
  Extend the `evidence_policy` object in `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1` with:

```powershell
debugging_phase_proof_required_for = @("bug", "regression", "ci-failure", "performance", "unclear-failure")
debugging_required_phases = @("phase1_root_cause", "phase2_pattern_analysis", "phase3_hypothesis", "phase4_fix")
max_fix_attempts_before_escalation = 3
```

  In `validate-worker-handoff.ps1`, require these values and reject missing or altered policy fields.

- [ ] **Step 6: Harden skill text and metadata**
  In implement-plan, resolve-issue, orchestrate-issues, and write-plan skill text and metadata, add a `Debugging Phase Proof Gate` that requires Phase 1 root-cause evidence, Phase 2 pattern analysis, Phase 3 hypothesis, Phase 4 implementation with reproduction test when feasible, and escalation after three failed fix attempts.

- [ ] **Step 7: Extend write-plan scenario coverage**
  In `skills/write-plan/scripts/test-scenarios.ps1`, add required text needles for `Debugging Phase Proof Gate`, `Phase 1 root-cause evidence`, `Phase 2 pattern analysis`, `Phase 3 hypothesis`, `Phase 4`, and `three failed fix attempts`.

- [ ] **Step 8: Extend aggregate method contract**
  In `scripts/test-superpowers-method-contract.ps1`, add the same debugging phase needles to implement-plan, resolve-issue, orchestrate-issues, and write-plan contract checks.

- [ ] **Step 9: Validate the GREEN state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-method-contract.ps1
```

  Expected result after implementation: all commands exit `0`; bug-shaped ledgers without debugging proof fail inside the harness, and non-bug work shapes are not forced through debugging phase proof.

- [ ] **Step 10: Commit this slice**
  Commit after the focused tests pass:

```powershell
git add skills/implement-plan skills/resolve-issue skills/orchestrate-issues skills/write-plan scripts/test-superpowers-method-contract.ps1
git commit -m "Require debugging phase proof"
```

## Task 5: Write-Plan Exactness Gate

**Use Cases:**
- A ready implementation plan with reserved placeholder or shortcut wording fails before execution routes can consume it.
- A task step that changes code must include a code block or precise patch description.
- A validation step must include the exact command and expected result.
- A task cannot use a generic test-writing shortcut without naming the behavior and command.
- Startup-loaded agents see the exactness gate even when they only read metadata.

**Files:**
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Create: `scripts/validate-plan-exactness.ps1`
- Create: `scripts/test-plan-exactness.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `scripts/test-superpowers-method-contract.ps1`

- [ ] **Step 1: Add the plan exactness validator**
  Create `scripts/validate-plan-exactness.ps1` with parameters:

```powershell
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$PlanPath
)
```

  The validator must resolve `PlanPath` under the repo, require `docs/superpowers/plans/`, read the plan, strip fenced code blocks before prose-pattern matching, and reject these case-insensitive patterns in the remaining prose:

```powershell
$forbiddenPatterns = @(
    '\bTBD\b',
    '\bTODO\b',
    'fill in',
    'implement later',
    'similar to',
    'add appropriate',
    'write tests for the above'
)
```

  It must also parse numbered `Task N` sections and reject any checkbox line containing `Run`, `Validate`, `Test`, or `Verify` unless the current line or following two lines contain `Expected:`. Return JSON:

```powershell
[pscustomobject]@{
    ok = $true
    phase = "plan-exactness"
    plan_path = $relativePlan
    task_count = $tasks.Count
    reason = "plan exactness checks passed"
}
```

  On failure, return `ok: false`, `phase: "plan-exactness"`, `plan_path`, and a `reason` naming the first matched issue, then exit `1`.

- [ ] **Step 2: Add validator scenario tests**
  Create `scripts/test-plan-exactness.ps1` with a temp fixture repo. Include these fixture files:

```text
docs/superpowers/plans/valid-exact-plan.md
docs/superpowers/plans/placeholder-plan.md
docs/superpowers/plans/missing-expected-output-plan.md
docs/superpowers/plans/shortcut-plan.md
```

  Assertions:

- `valid-exact-plan.md` passes.
- `placeholder-plan.md` containing the first placeholder token from the validator pattern list fails.
- `missing-expected-output-plan.md` containing `- [ ] **Step 2: Run validation**` with no nearby `Expected:` fails.
- `shortcut-plan.md` containing the shortcut phrase from the validator pattern list fails.

- [ ] **Step 3: Wire exactness into full validation**
  In `scripts/validate.ps1`, after the existing `Plan task use cases` step, add:

```powershell
$results.Add((Invoke-Step "Plan exactness" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-plan-exactness.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Plan exactness failed" }
}))
```

- [ ] **Step 4: Harden write-plan text and metadata**
  In `skills/write-plan/SKILL.md`, add `## Plan Exactness Gate` before `## Native Question Debug Mode`. It must say ready plans are blocked by placeholder words, shortcut references, generic code instructions, missing expected output, missing exact files, missing exact commands, and missing type/name consistency review. It must require:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-exactness.ps1 -PlanPath <saved-plan-path>
```

  before artifact review or any route into `create-issues`, `implement-plan`, `resolve-issue`, or `orchestrate-issues`.

  Add matching startup-visible text to `skills/write-plan/agents/openai.yaml` for the exactness gate and the reserved phrase list:

```yaml
Plan Exactness Gate
validate-plan-exactness.ps1
TBD
TODO
fill in
implement later
similar to
add appropriate
write tests for the above
Expected:
type/name consistency review
```

- [ ] **Step 5: Extend write-plan scenario coverage**
  In `skills/write-plan/scripts/test-scenarios.ps1`, add a scenario named `plan exactness gate is mandatory`. It must assert the skill and metadata contain `Plan Exactness Gate`, `validate-plan-exactness.ps1`, and every forbidden phrase listed in Step 4.

- [ ] **Step 6: Extend aggregate method contract**
  In `scripts/test-superpowers-method-contract.ps1`, add a `write-plan exactness contract` check requiring the same exactness gate phrases in the skill and metadata.

- [ ] **Step 7: Validate the GREEN state**
  Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-plan-exactness.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-exactness.ps1 -PlanPath docs/superpowers/plans/2026-06-12-superpowers-method-gate-hardening-plan.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-method-contract.ps1
```

  Expected result after implementation: all commands exit `0`; placeholder, shortcut, and missing-expected-output fixtures fail inside `test-plan-exactness.ps1`, and this saved plan passes exactness validation.

- [ ] **Step 8: Commit this slice**
  Commit after the focused tests pass:

```powershell
git add skills/write-plan scripts/validate-plan-exactness.ps1 scripts/test-plan-exactness.ps1 scripts/validate.ps1 scripts/test-superpowers-method-contract.ps1 docs/superpowers/plans/2026-06-12-superpowers-method-gate-hardening-plan.md
git commit -m "Enforce write-plan exactness"
```

## Final Validation And Live Sync

After Tasks 1 through 5 are complete, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-12-superpowers-method-gate-hardening-plan.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected result: every command exits `0`; the full validator returns `ok: true`; live sync validation reports current source and deployed surfaces; cleanup reports no matching leftover processes for this repo.

## Risk And Dependency Notes

- Task 1 should land before Tasks 3 and 4 because it establishes the local implementation ledger structure.
- Task 2 should land before expanding worker evidence policy because worker handoffs need the review-policy shape first.
- Tasks 3 and 4 both touch implementation evidence ledgers; keep commits separate so TDD proof and debugging proof failures are easy to isolate.
- Task 5 should run last because its validator will check this plan and future plans more strictly.
- `scripts\sync-live.ps1 -Validate` must happen after source validation, not before.

## Self-Review

- Source spec is named and under `docs/superpowers/specs`.
- Auto Mode authorization ledger is named and remains outside the repo.
- Every acceptance criterion maps to at least one task.
- Every numbered task has concrete `**Use Cases:**` before files and steps.
- Every task names exact files and exact validation commands.
- TDD is required for behavior-changing script and validator work.
- Debugging discipline is required for bug-shaped failures and failed validator investigations.
- Completion requires `superpowers:verification-before-completion`, full repo validation, live sync validation, and cleanup proof.
