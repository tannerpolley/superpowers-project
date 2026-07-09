# Workflow Mode Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-choice Manual, Auto, and Looping mode gate to `$superpowers-project:initiate-workflow` with validator-backed mode ledgers, Loop Controller handoff, and updated workflow diagrams.

**Architecture:** Add mode selection at initiation, store it in a root-validated workflow mode ledger, and keep the existing skill-to-skill closeout flow underneath. Auto Mode remains one-route only; Looping Mode hands broad repeated maintenance to Loop Controller with budgets, proof, metrics, and per-candidate continuation.

**Tech Stack:** Bash validators and tests, Markdown skill contracts, YAML skill metadata, generated outcome workflow, Mermaid and SVG workflow docs.

---

## Intake

**Source Spec:** `docs/superpowers/specs/2026-06-16-workflow-mode-entry-design.md`

**Milestone:** `M0 - Governance`

**Approved Design:** Design 1, Entry Mode Gate plus Mode Ledger.

**Planning Decisions:**

- Validator location: root script `scripts/validate-workflow-mode-ledger.sh`.
- Scope: one implementation plan covering router, validator, Looping handoff, docs, diagrams, and tests.
- Test complete: focused new tests plus existing Auto/Loop tests, SVG/contract tests, full `scripts/validate.sh`, and `scripts/sync-live.sh --validate`.

## Acceptance Criteria

- `$superpowers-project:initiate-workflow` starts by asking `project_workflow_mode`.
- The three entry options are `Manual Mode`, `Auto Mode`, and `Looping Mode`.
- A workflow mode ledger records the selected mode, autonomy scope, mutation scope, candidate scope, route policy, proof policy, budget policy, and stop conditions.
- Root validator accepts valid Manual, Auto, and Looping ledgers.
- Root validator rejects Auto Mode queue continuation authority.
- Root validator rejects Looping Mode without budget, candidate scope, proof policy, or stop conditions.
- Auto Mode remains one-route only and cannot continue to another candidate after closeout.
- Looping Mode routes through Loop Controller and may select broad maintenance candidates one at a time after merge proof and budget re-checks.
- README, plugin metadata, outcome workflow, Mermaid, and SVG surfaces expose the mode gate.
- Existing skill-to-skill flow remains intact after the mode gate is added.

## Non-Goals

- Do not replace the existing skill-to-skill flowchart.
- Do not make Auto Mode select multiple candidates.
- Do not let Looping Mode bypass `merge-changes`, final proof, clean repo checks, or budget checks.
- Do not create direct-to-main implementation routes.
- Do not store generated run state in committed docs by default.

## Test-Complete Definition

This plan is test-complete when all focused tests pass, the full repo validator passes, live sync validation passes, and the cleanup hook reports no owned leftover processes.

Metrics are workflow-validation metrics, not scientific or numerical performance metrics. Pass/fail is defined by script exit codes, generated contract freshness, and explicit fixture acceptance/rejection. No numerical tolerances are required.

Proof oracle:

```bash
./scripts/test-initiate-workflow-mode-gate.sh
./scripts/test-workflow-mode-ledger.sh
./scripts/test-auto-mode-contract.sh
./scripts/test-loop-controller.sh
./skills/loop-controller/scripts/test-scenarios.sh
./scripts/test-native-qa-svg.sh
./scripts/test-contract-summary.sh
./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-06-16-m0-workflow-mode-entry-plan.md
./scripts/validate.sh
./scripts/sync-live.sh --validate
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

## Task 1: Add Failing Mode-Gate Contract Tests

**Use Cases:**
- A new agent can discover the Manual, Auto, and Looping modes from the router before choosing a task route.
- A stale router that exposes Loop Controller only as a hidden skill route fails the contract.
- README, metadata, and outcome workflow drift are caught before the plugin ships.

**Files:**
- Create: `scripts/test-initiate-workflow-mode-gate.sh`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-initiate-workflow-mode-gate.sh`

- [ ] **Step 1: Create the failing mode-gate test.**

Create `scripts/test-initiate-workflow-mode-gate.sh` with checks that initially fail until the router and docs are updated:

```bash
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Read-RepoText {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $RepoRoot $RelativePath) -Raw
}

try {
    $skill = Read-RepoText "skills/initiate-workflow/SKILL.md"
    $metadata = Read-RepoText "skills/initiate-workflow/agents/openai.yaml"
    $readme = Read-RepoText "README.md"
    $summary = Read-RepoText "docs/superpowers/OUTCOME_WORKFLOW.md"
    $mermaid = Read-RepoText "docs/assets/native-qa-main-flow-mermaid.md"

    foreach ($textCase in @(
        @{ name = "skill"; text = $skill },
        @{ name = "metadata"; text = $metadata },
        @{ name = "README"; text = $readme },
        @{ name = "summary"; text = $summary },
        @{ name = "Mermaid"; text = $mermaid }
    )) {
        foreach ($needle in @("project_workflow_mode", "Manual Mode", "Auto Mode", "Looping Mode")) {
            Add-Check "$($textCase.name) contains $needle" $textCase.text.Contains($needle) "$($textCase.name) missing $needle"
        }
    }

    Add-Check "router names mode ledger" $skill.Contains("workflow mode ledger") "router must require a workflow mode ledger"
    Add-Check "router names root validator" $skill.Contains("scripts/validate-workflow-mode-ledger.sh") "router must name the root mode-ledger validator"
    Add-Check "auto mode is one-route only" $skill.Contains("one-route autonomy") "Auto Mode must be one-route only"
    Add-Check "looping mode delegates to loop controller" $skill.Contains('$superpowers-project:loop-controller') "Looping Mode must delegate to Loop Controller"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "initiate-workflow-mode-gate"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check "fatal" $false $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "initiate-workflow-mode-gate"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 2: Run the test and verify the expected failure.**

Run:

```bash
./scripts/test-initiate-workflow-mode-gate.sh
```

Expected: nonzero exit because `project_workflow_mode` is not yet present in the router, metadata, README, summary, or Mermaid companion.

- [ ] **Step 3: Add the test to validation.**

Modify `scripts/validate.sh` after the Auto Mode and Loop Controller checks:

```bash
$results.Add((Invoke-Step "Workflow mode entry contract" {
    & (Join-Path $PSScriptRoot "test-initiate-workflow-mode-gate.sh") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Workflow mode entry contract failed" }
}))
```

- [ ] **Step 4: Commit the failing contract test.**

Run:

```bash
git add scripts/test-initiate-workflow-mode-gate.sh scripts/validate.sh
git commit -m "Add workflow mode gate contract test"
```

## Task 2: Add Workflow Mode Ledger Validator

**Use Cases:**
- Manual Mode records that future material decisions still require native questions.
- Auto Mode cannot quietly become queue execution.
- Looping Mode cannot start without budget, candidate, proof, and stop policy.
- Existing agents can validate mode state without relying on conversation memory.

**Files:**
- Create: `scripts/validate-workflow-mode-ledger.sh`
- Create: `scripts/test-workflow-mode-ledger.sh`
- Modify: `scripts/validate.sh`
- Test: `scripts/test-workflow-mode-ledger.sh`

- [ ] **Step 1: Create validator tests first.**

Create `scripts/test-workflow-mode-ledger.sh` with valid Manual, Auto, and Looping fixtures plus invalid fixtures:

```bash
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("workflow-mode-ledger-" + [guid]::NewGuid().ToString("N"))

function Add-Check { param([string]$Name, [bool]$Ok, [string]$Reason) $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null }
function Write-Ledger { param([string]$Name, [hashtable]$Ledger) $path = Join-Path $tempRoot $Name; $Ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM; $path }
function Invoke-Validator { param([string]$Path) $raw = & (Join-Path $RepoRoot "scripts/validate-workflow-mode-ledger.sh") -RepoRoot $RepoRoot -ModeLedgerPath $Path 2>&1; [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = ($raw | Out-String).Trim(); json = (($raw | Out-String).Trim() | ConvertFrom-Json) } }

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $base = @{
        question_id = "project_workflow_mode"
        source = "request_user_input"
        repo_root = $RepoRoot
        plugin_manifest_version = "0.2.0+fixture"
        plugin_contract_hash = "fixture"
        started_at = "2026-06-16T00:00:00Z"
        mutation_scope = @("current-repo", "development-branch")
        route_policy = @{ use_existing_flowchart = $true }
        proof_policy = @{ require_final_proof = $true; require_clean_repo_for_done = $true }
        stop_conditions = @("missing-proof", "failed-validation", "decision-outside-policy")
        downstream_ledger_paths = @()
    }

    $manual = $base.Clone(); $manual.selected_mode = "manual"; $manual.autonomy_scope = "ask-every-material-decision"; $manual.candidate_scope = @()
    $auto = $base.Clone(); $auto.selected_mode = "auto"; $auto.autonomy_scope = "one-route"; $auto.candidate_scope = @("selected-route"); $auto.route_policy.one_route_only = $true; $auto.route_policy.continue_to_next_candidate = $false
    $looping = $base.Clone(); $looping.selected_mode = "looping"; $looping.autonomy_scope = "bounded-loop"; $looping.candidate_scope = @("ready-issues", "approved-plans", "saved-specs", "audit-findings", "alignment-drift", "stale-version"); $looping.budget_policy = @{ max_candidates = 3; max_attempts_per_phase = 2; max_github_mutations = 6 }

    foreach ($fixture in @(
        @{ name = "manual passes"; path = Write-Ledger "manual.json" $manual; ok = $true },
        @{ name = "auto passes"; path = Write-Ledger "auto.json" $auto; ok = $true },
        @{ name = "looping passes"; path = Write-Ledger "looping.json" $looping; ok = $true }
    )) {
        $result = Invoke-Validator $fixture.path
        Add-Check $fixture.name ($result.exit_code -eq 0 -and $result.json.ok -eq $true) $result.raw
    }

    $badAuto = $auto.Clone(); $badAuto.route_policy.continue_to_next_candidate = $true
    $badAutoResult = Invoke-Validator (Write-Ledger "bad-auto.json" $badAuto)
    Add-Check "auto queue authority fails" ($badAutoResult.exit_code -ne 0 -and [string]$badAutoResult.json.reason -match "one-route") "Auto Mode queue authority should fail"

    $badLooping = $looping.Clone(); $badLooping.Remove("budget_policy")
    $badLoopingResult = Invoke-Validator (Write-Ledger "bad-looping.json" $badLooping)
    Add-Check "looping without budget fails" ($badLoopingResult.exit_code -ne 0 -and [string]$badLoopingResult.json.reason -match "budget_policy") "Looping Mode without budget must fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "workflow-mode-ledger"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check "fatal" $false $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "workflow-mode-ledger"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
```

- [ ] **Step 2: Run the tests and verify the expected failure.**

Run:

```bash
./scripts/test-workflow-mode-ledger.sh
```

Expected: nonzero exit because `scripts/validate-workflow-mode-ledger.sh` does not exist.

- [ ] **Step 3: Implement the validator.**

Create `scripts/validate-workflow-mode-ledger.sh`:

```bash
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$ModeLedgerPath
)

$ErrorActionPreference = "Stop"

function Test-Property {
    param([object]$Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $path = if ([IO.Path]::IsPathRooted($ModeLedgerPath)) { $ModeLedgerPath } else { Join-Path $root $ModeLedgerPath }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "mode ledger not found: $ModeLedgerPath" }
    $ledger = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

    $required = @("question_id", "source", "selected_mode", "repo_root", "plugin_manifest_version", "plugin_contract_hash", "started_at", "autonomy_scope", "mutation_scope", "candidate_scope", "route_policy", "proof_policy", "stop_conditions", "downstream_ledger_paths")
    $missing = @($required | Where-Object { -not (Test-Property $ledger $_) -or [string]::IsNullOrWhiteSpace([string]$ledger.$_) })
    if ($missing.Count -gt 0) { throw "missing required field(s): $($missing -join ', ')" }
    if ([string]$ledger.question_id -ne "project_workflow_mode") { throw "question_id must be project_workflow_mode" }

    $mode = ([string]$ledger.selected_mode).ToLowerInvariant()
    if ($mode -notin @("manual", "auto", "looping")) { throw "unsupported selected_mode: $($ledger.selected_mode)" }

    if ($mode -eq "manual") {
        if ([string]$ledger.autonomy_scope -ne "ask-every-material-decision") { throw "manual mode must use ask-every-material-decision autonomy_scope" }
    }

    if ($mode -eq "auto") {
        if ([string]$ledger.autonomy_scope -ne "one-route") { throw "auto mode must be one-route autonomy" }
        if (-not (Test-Property $ledger.route_policy "one_route_only") -or $ledger.route_policy.one_route_only -ne $true) { throw "auto mode requires route_policy.one_route_only true" }
        if ((Test-Property $ledger.route_policy "continue_to_next_candidate") -and $ledger.route_policy.continue_to_next_candidate -eq $true) { throw "auto mode must remain one-route and cannot continue to next candidate" }
    }

    if ($mode -eq "looping") {
        if ([string]$ledger.autonomy_scope -ne "bounded-loop") { throw "looping mode must use bounded-loop autonomy_scope" }
        foreach ($field in @("budget_policy", "candidate_scope", "proof_policy", "stop_conditions")) {
            if (-not (Test-Property $ledger $field)) { throw "looping mode requires $field" }
        }
        if (@($ledger.candidate_scope).Count -eq 0) { throw "looping mode requires non-empty candidate_scope" }
        if (@($ledger.stop_conditions).Count -eq 0) { throw "looping mode requires non-empty stop_conditions" }
    }

    [pscustomobject]@{ ok = $true; phase = "workflow-mode-ledger"; selected_mode = $mode; path = [IO.Path]::GetFullPath($path) } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{ ok = $false; phase = "workflow-mode-ledger"; reason = $_.Exception.Message } | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 4: Wire the validator tests into full validation.**

Modify `scripts/validate.sh` after the Workflow mode entry contract:

```bash
$results.Add((Invoke-Step "Workflow mode ledger validator" {
    & (Join-Path $PSScriptRoot "test-workflow-mode-ledger.sh") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Workflow mode ledger validator failed" }
}))
```

- [ ] **Step 5: Verify and commit.**

Run:

```bash
./scripts/test-workflow-mode-ledger.sh
git add scripts/validate-workflow-mode-ledger.sh scripts/test-workflow-mode-ledger.sh scripts/validate.sh
git commit -m "Validate workflow mode ledgers"
```

Expected: test exits `0`, then commit succeeds.

## Task 3: Add Mode Gate To Initiate Workflow

**Use Cases:**
- A user starting Superpowers Project can choose the agent's freedom level before task routing.
- Manual Mode preserves current question-driven behavior.
- Auto Mode cannot be mistaken for Looping Mode.
- Looping Mode is discoverable through the official router rather than only through metadata.

**Files:**
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.sh`
- Test: `skills/initiate-workflow/scripts/test-scenarios.sh`
- Test: `scripts/test-initiate-workflow-mode-gate.sh`

- [ ] **Step 1: Add scenario expectations before changing the skill text.**

Modify `skills/initiate-workflow/scripts/test-scenarios.sh` so the router contract list includes:

```bash
"project_workflow_mode",
"Manual Mode",
"Auto Mode",
"Looping Mode",
"workflow mode ledger",
"scripts/validate-workflow-mode-ledger.sh",
"one-route autonomy",
"bounded repeated maintenance autonomy",
"$superpowers-project:loop-controller"
```

- [ ] **Step 2: Run initiate-workflow scenarios and verify they fail.**

Run:

```bash
./skills/initiate-workflow/scripts/test-scenarios.sh
```

Expected: nonzero exit with missing router contract text.

- [ ] **Step 3: Update `skills/initiate-workflow/SKILL.md`.**

Add a `## Workflow Mode Gate` section before `## Routing`:

```markdown
## Workflow Mode Gate

Before task routing, ask native question `project_workflow_mode`.

Prompt: `How should I run this Superpowers Project workflow?`

Options:

- `Manual Mode`: ask at each material route, mutation, and closeout decision.
- `Auto Mode`: one-route autonomy using recorded defaults and validator-backed proof; it must stop at route closeout and must not continue to another candidate.
- `Looping Mode`: bounded repeated maintenance autonomy; create or validate a workflow mode ledger, then route to `$superpowers-project:loop-controller`.

Record a workflow mode ledger under `.superpowers/runs/<run-id>/workflow-mode-ledger.json` and validate it with `scripts/validate-workflow-mode-ledger.sh -RepoRoot <active repo> -ModeLedgerPath <ledger>`.
```

Also update `## Routing` so Looping Mode routes to `$superpowers-project:loop-controller` and Auto Mode remains one-route only.

- [ ] **Step 4: Update metadata.**

Modify `skills/initiate-workflow/agents/openai.yaml` so the default prompt mentions:

```yaml
Before task routing, ask project_workflow_mode with Manual Mode, Auto Mode, and Looping Mode. Manual Mode asks at each material decision. Auto Mode is one-route autonomy and must not continue to another candidate. Looping Mode validates a workflow mode ledger and routes to $superpowers-project:loop-controller for bounded repeated maintenance.
```

- [ ] **Step 5: Verify and commit.**

Run:

```bash
./skills/initiate-workflow/scripts/test-scenarios.sh
./scripts/test-initiate-workflow-mode-gate.sh
git add skills/initiate-workflow/SKILL.md skills/initiate-workflow/agents/openai.yaml skills/initiate-workflow/scripts/test-scenarios.sh
git commit -m "Add initiate workflow mode gate"
```

Expected: both focused tests exit `0`, then commit succeeds.

## Task 4: Connect Looping Mode To Loop Controller Behavior

**Use Cases:**
- Looping Mode can select broad maintenance work after a clean merge.
- Looping Mode stops before another candidate when budget or proof is unsafe.
- Auto Mode stays one-route even when Loop Controller exists.
- Agents can inspect skipped candidates and understand why the loop continued or stopped.

**Files:**
- Modify: `skills/loop-controller/SKILL.md`
- Modify: `skills/loop-controller/agents/openai.yaml`
- Modify: `skills/loop-controller/scripts/test-scenarios.sh`
- Modify: `skills/loop-controller/scripts/select-candidate.sh`
- Test: `skills/loop-controller/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing Looping Mode scenario coverage.**

Modify `skills/loop-controller/scripts/test-scenarios.sh` to add fixtures that prove:

```bash
@{
    candidates = @(
        @{ id = "ready-issue-62"; source = "ready-issue"; route = "resolve-issue"; ready = $true; risk = "low"; source_path = "docs/superpowers/issues/62-example.md"; reason = "ready issue mirror" },
        @{ id = "stale-version"; source = "stale-version"; route = "align-project"; ready = $true; risk = "low"; source_path = "scripts/get-agent-plugin-version.sh"; reason = "version drift repair" },
        @{ id = "broad-audit"; source = "audit"; route = "audit-project"; ready = $true; risk = "medium"; source_path = "docs/superpowers/specs/2026-06-16-workflow-mode-entry-design.md"; reason = "broad maintenance audit" }
    )
}
```

Expected selector behavior:

- chooses the safest ready candidate;
- records skipped candidates;
- accepts broad maintenance sources only in Looping Mode fixtures.

- [ ] **Step 2: Run Loop Controller scenarios and verify the expected failure.**

Run:

```bash
./skills/loop-controller/scripts/test-scenarios.sh
```

Expected: nonzero exit until candidate source handling and skill text are updated.

- [ ] **Step 3: Update Loop Controller contract text.**

Modify `skills/loop-controller/SKILL.md` to add:

```markdown
## Looping Mode Input

When invoked from `project_workflow_mode`, require a validated workflow mode ledger with `selected_mode: looping`. Looping Mode may select broad maintenance candidates one at a time, including ready issues, approved plans, saved specs, audit findings, alignment drift, stale version checks, and live sync drift. After a candidate is merged or closed out, re-check budget before selecting the next candidate.

Auto Mode remains one-route only and must not use Loop Controller to continue to another candidate.
```

Update `skills/loop-controller/agents/openai.yaml` with the same boundary.

- [ ] **Step 4: Update candidate selection source handling.**

Modify `skills/loop-controller/scripts/select-candidate.sh` only as needed so fixture candidates with sources `ready-issue`, `stale-version`, `audit`, `align`, `plan`, and `spec` are accepted when `ready = true`, source paths exist or are explicitly fixture-safe, and risk sorting still prefers lower-risk candidates.

- [ ] **Step 5: Verify and commit.**

Run:

```bash
./skills/loop-controller/scripts/test-scenarios.sh
./scripts/test-loop-controller.sh
git add skills/loop-controller/SKILL.md skills/loop-controller/agents/openai.yaml skills/loop-controller/scripts/test-scenarios.sh skills/loop-controller/scripts/select-candidate.sh
git commit -m "Connect looping mode to loop controller"
```

Expected: both focused Loop Controller tests exit `0`, then commit succeeds.

## Task 5: Update User-Facing Workflow Docs And Diagrams

**Use Cases:**
- A human reading the README sees the three maintenance levels before the skill chain.
- The Mermaid companion shows the mode gate without destroying the current skill-to-skill flow.
- SVG tests catch visual drift such as missing mode labels or a broken existing flow.
- Contract summary reflects the new native question id after regeneration.

**Files:**
- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `docs/assets/native-qa-main-flow-mermaid.md`
- Modify: `docs/assets/native-qa-main-flow.svg`
- Modify: `scripts/test-native-qa-svg.sh`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`
- Test: `scripts/test-native-qa-svg.sh`
- Test: `scripts/test-contract-summary.sh`

- [ ] **Step 1: Update README and plugin prompt text.**

Modify `README.md` near `## Native Q&A Workflow` to explain:

```markdown
`$superpowers-project:initiate-workflow` starts with `project_workflow_mode`: Manual Mode, Auto Mode, or Looping Mode. Manual Mode asks at each material decision. Auto Mode runs one route with recorded defaults. Looping Mode uses Loop Controller to select and complete one maintenance candidate at a time, then re-checks budget before continuing.
```

Modify `.codex-plugin/plugin.json` default prompt to mention the same mode gate before listing individual workflow routes.

- [ ] **Step 2: Update Mermaid flow.**

Modify `docs/assets/native-qa-main-flow-mermaid.md` so the top flow becomes:

```mermaid
start --> rule --> initiate --> d_mode
d_mode -->|Manual Mode| d_initiate
d_mode -->|Auto Mode| d_initiate
d_mode -->|Looping Mode| loop_controller
loop_controller --> d_loop
d_loop -->|Next Candidate| d_initiate
d_loop -->|Stop| stop_loop
```

Keep the existing skill-to-skill nodes and edges after `d_initiate`.

- [ ] **Step 3: Update SVG and SVG contract test.**

Modify `docs/assets/native-qa-main-flow.svg` to add the mode decision before the current router depth. Update `scripts/test-native-qa-svg.sh` to assert the SVG contains:

```bash
"project_workflow_mode",
"Manual Mode",
"Auto Mode",
"Looping Mode",
"Workflow Mode",
"Loop Controller"
```

Also assert existing labels still exist:

```bash
"Initiate Workflow",
"Setup Project",
"Brainstorm Spec",
"Write Plan",
"Create Issues",
"Implement Plan",
"Resolve Issue",
"Orchestrate Issues",
"Merge Changes",
"Audit Project",
"Align Project"
```

- [ ] **Step 4: Regenerate the outcome workflow.**

Run:

```bash
./scripts/generate-contract-summary.sh
```

Expected: `docs/superpowers/OUTCOME_WORKFLOW.md` includes `project_workflow_mode` in the `initiate-workflow` row.

- [ ] **Step 5: Verify docs and commit.**

Run:

```bash
./scripts/test-native-qa-svg.sh
./scripts/test-contract-summary.sh
./scripts/test-initiate-workflow-mode-gate.sh
git add README.md .codex-plugin/plugin.json docs/assets/native-qa-main-flow-mermaid.md docs/assets/native-qa-main-flow.svg scripts/test-native-qa-svg.sh docs/superpowers/OUTCOME_WORKFLOW.md
git commit -m "Document workflow mode entry"
```

Expected: all three tests exit `0`, then commit succeeds.

## Task 6: Validate Full Workflow And Live Sync Readiness

**Use Cases:**
- A future agent can execute the plan without missing the strict `Task # Use Cases` gate.
- Full repo validation proves no stale route, diagram, metadata, or skill contract was broken.
- Live sync validation proves the updated plugin can be deployed to the local user install.
- Cleanup proof confirms no owned background process remains.

**Files:**
- Modify: `docs/superpowers/plans/2026-06-16-m0-workflow-mode-entry-plan.md` only if validation reveals a plan issue.
- Test: `scripts/validate-plan-task-use-cases.sh`
- Test: `scripts/validate.sh`
- Test: `scripts/sync-live.sh`

- [ ] **Step 1: Validate the plan use-case gate.**

Run:

```bash
./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-06-16-m0-workflow-mode-entry-plan.md
```

Expected: exit `0`.

- [ ] **Step 2: Run focused proof commands.**

Run:

```bash
./scripts/test-initiate-workflow-mode-gate.sh
./scripts/test-workflow-mode-ledger.sh
./scripts/test-auto-mode-contract.sh
./scripts/test-loop-controller.sh
./skills/loop-controller/scripts/test-scenarios.sh
./scripts/test-native-qa-svg.sh
./scripts/test-contract-summary.sh
```

Expected: every command exits `0`.

- [ ] **Step 3: Run full validation.**

Run:

```bash
./scripts/validate.sh
```

Expected: exit `0`.

- [ ] **Step 4: Run live sync validation.**

Run:

```bash
./scripts/sync-live.sh --validate
```

Expected: exit `0`.

- [ ] **Step 5: Run cleanup proof.**

Run:

```bash
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Expected: no matching leftover Codex processes under the repo.

- [ ] **Step 6: Commit final validation repairs if any were required.**

If validation required edits, run:

```bash
git add <changed-files>
git commit -m "Validate workflow mode entry"
```

Expected: commit succeeds or no changes remain.

## Self-Review

- Spec coverage: every acceptance criterion in `docs/superpowers/specs/2026-06-16-workflow-mode-entry-design.md` maps to at least one task.
- Placeholder scan: no placeholder markers remain.
- Type consistency: mode names are `Manual Mode`, `Auto Mode`, and `Looping Mode`; ledger values are `manual`, `auto`, and `looping`; native question id is `project_workflow_mode`.
- Task use cases: every numbered task includes a non-empty `**Use Cases:**` block before files and steps.
- TDD policy: all implementation tasks begin with failing contract or scenario tests before skill/script changes.
- Debug policy: this is feature/workflow work, not a bug diagnosis plan.
- Verification policy: completion requires focused tests, full validation, live sync validation, and cleanup proof.

