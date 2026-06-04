# Auto Mode And Stop Done Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Auto Mode route after spec creation and make continuation terminal labels phase-sensitive so `Stop` means mid-loop exit and `Done` means verified workflow completion.

**Architecture:** Implement this as contract-first skill work: add a shared Auto Mode authorization validator, update native continuation policy in shared docs and validators, then propagate the new route and terminal-label semantics through active skill docs, metadata, scenario scripts, README, and workflow assets. Keep execution on existing project routes (`write-plan`, `implement-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, and `merge-changes`) instead of adding a new execution engine.

**Tech Stack:** Codex skill Markdown/YAML, PowerShell 7 scenario scripts and validators, JSON authorization ledgers, README/SVG/Mermaid docs assets, Git/GitHub workflow evidence, and existing `scripts/validate.ps1` plus `scripts/sync-live.ps1 -Validate`.

---

## Intake

**Source Specs:**

- `docs/superpowers/specs/2026-06-04-auto-mode-after-spec-design.md`
- `docs/superpowers/specs/2026-06-04-stop-done-terminal-labels-design.md`

**Planning Grill Decisions:**

- Store Auto Mode authorization as a shared generated evidence file validated by a shared helper.
- First Auto Mode implementation supports worker execution only through the existing issue-backed `orchestrate-issues` path.
- Final `Done` appears through an explicit healthy-style gate after clean merge closeout, matching Doctor semantics.
- Validation scans active contracts only: README, skill docs, metadata, scripts, and assets. Historical specs and plans are excluded.
- Update README, SVG, Mermaid, and asset validation in the first implementation.

**Milestone Linkage:**

- `M0 - Governance`: Auto Mode authorization, native continuation semantics, terminal-state proof, and scenario gates.
- `M1 - Source Of Truth`: skill docs, metadata, README, assets, and validation must agree on active workflow contracts.

## Acceptance Criteria

- `brainstorm-spec` offers Auto Mode only after a saved spec and only inside the nested progress branch.
- Auto Mode asks one native authorization question and records a structured ledger.
- The shared Auto Mode validator accepts a complete bounded auto-merge ledger and rejects missing source spec, authority, route policy, decision policy, merge permission, mutation scope, proof requirements, or stop conditions.
- `write-plan` can consume a valid Auto Mode ledger as recorded planning authorization only when material decisions are covered.
- Auto Mode route policy chooses direct `implement-plan` for narrow non-issue work and issue-backed `create-issues -> resolve-issue/orchestrate-issues -> merge-changes` for tracked, risky, broad, milestone-owned, worker-suitable, or multi-slice work.
- Direct Auto Mode worker execution is out of first-pass scope; worker execution is available only through issue-backed `orchestrate-issues`.
- `merge-changes` accepts Auto Mode merge permission only after clean premerge proof.
- Intermediate continuation gates use `Yes`, `Revisit`, and `Stop`.
- `Done` appears only after verified final closeout: clean merge closeout followed by a healthy-style gate, or healthy audit with no remaining repair route.
- Active contract validation excludes historical specs and plans from old-label scans.
- README, Mermaid, SVG, and asset validation match the new Auto Mode and phase-sensitive Stop/Done semantics.
- `scripts/validate.ps1`, `scripts/sync-live.ps1 -Validate`, and the user-level cleanup hook pass before implementation closeout.

## Non-Goals

- Do not use `debug_question_mode` for normal Auto Mode execution.
- Do not add direct worker execution to `implement-plan` for Auto Mode in this first pass.
- Do not edit directly on `main`.
- Do not weaken validation, cleanup, PR-ready, premerge, or closeout proof.
- Do not let non-issue work claim GitHub issue closure.
- Do not scan historical specs or plans as active Stop/Done contracts.
- Do not add a separate project-management state store only for terminal labels.

## File Map

- Create: `scripts/lib/auto-mode-contract.ps1`
- Create: `scripts/test-auto-mode-contract.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `scripts/test-native-continuation-loop.ps1`
- Modify: `scripts/test-advanced-user-input-policy.ps1`
- Modify: `scripts/test-native-qa-svg.ps1`
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`
- Modify: `skills/setup-project/SKILL.md`
- Modify: `skills/setup-project/agents/openai.yaml`
- Modify: `skills/setup-project/scripts/test-scenarios.ps1`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/scripts/test-scenarios.ps1`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/audit-project/scripts/test-scenarios.ps1`
- Modify: `README.md`
- Modify: `docs/assets/native-qa-main-flow-mermaid.md`
- Modify: `docs/assets/native-qa-main-flow.svg`
- Modify: `docs/assets/native-qa-main-flow-preview.html` only if preview text describes the old label contract.

## Proof Oracle

Run these commands before claiming implementation complete:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-auto-mode-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
git status --short --branch
```

Expected final state:

- Every command exits `0`.
- `git status --short --branch` shows the implementation branch with no unstaged or untracked changes after final commit.
- Active skill docs and metadata use phase-sensitive terminal labels.
- Historical specs and plans may still mention old labels as history.

### Task 1: Add Shared Auto Mode Authorization Contract

**Files:**

- Create: `scripts/lib/auto-mode-contract.ps1`
- Create: `scripts/test-auto-mode-contract.ps1`
- Modify: `scripts/validate.ps1`

- [ ] **Step 1: Write the failing Auto Mode contract test**

Create `scripts/test-auto-mode-contract.ps1` with this structure:

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$helper = Join-Path $repoRoot "scripts\lib\auto-mode-contract.ps1"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try { & $Body; Add-Result -Name $Name -Ok $true -Reason "passed" }
    catch { Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message }
}

Invoke-Scenario "helper exists" {
    if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw "missing helper: $helper" }
}

. $helper

function New-HappyAuthorization {
    @{
        question_id = "project_auto_mode_authorization"
        source = "request_user_input"
        selected_authority = "bounded-auto-merge"
        source_spec = "docs/superpowers/specs/2026-06-04-auto-mode-after-spec-design.md"
        route_policy = @{
            selected_mode = "agent-chooses"
            direct_route = "implement-plan"
            issue_route = "create-issues"
            worker_route = "issue-backed-orchestrate-only"
        }
        decision_policy = @{
            selected_mode = "recorded-defaults"
            stop_outside_policy = $true
        }
        merge_permission = @{
            selected_mode = "preauthorized-after-clean-premerge"
            require_clean_premerge = $true
        }
        mutation_scope = @("current-repo", "development-branch", "github-issues", "github-pr", "merge")
        required_proof = @("plan-proof-oracle", "verification-receipts", "cleanup-hook", "premerge-proof", "closeout-proof")
        stop_conditions = @("missing-proof", "dirty-unsafe-state", "failed-validation", "github-auth-failure", "pending-required-check", "decision-outside-policy")
    }
}

Invoke-Scenario "happy authorization passes" {
    $result = Test-AutoModeAuthorization -Authorization (New-HappyAuthorization) -RepoRoot $repoRoot
    if (-not $result.ok) { throw $result.reason }
}

foreach ($field in @("question_id", "source_spec", "route_policy", "decision_policy", "merge_permission", "mutation_scope", "required_proof", "stop_conditions")) {
    Invoke-Scenario "missing $field blocks" {
        $auth = New-HappyAuthorization
        $auth.Remove($field)
        $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
        if ($result.ok) { throw "missing $field should fail" }
    }
}

Invoke-Scenario "direct worker mode blocks" {
    $auth = New-HappyAuthorization
    $auth.route_policy.worker_route = "direct-implement-worker"
    $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
    if ($result.ok) { throw "direct Auto Mode workers are out of first-pass scope" }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-auto-mode-contract.ps1
```

Expected: exits `1` with a result named `helper exists` failing because `scripts\lib\auto-mode-contract.ps1` does not exist.

- [ ] **Step 3: Add the shared helper**

Create `scripts/lib/auto-mode-contract.ps1` with:

```powershell
function Test-AutoModeAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Authorization,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $requiredFields = @(
        "question_id",
        "source",
        "selected_authority",
        "source_spec",
        "route_policy",
        "decision_policy",
        "merge_permission",
        "mutation_scope",
        "required_proof",
        "stop_conditions"
    )

    foreach ($field in $requiredFields) {
        if (-not ($Authorization.PSObject.Properties.Name -contains $field) -and -not ($Authorization.ContainsKey($field))) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "missing $field" }
        }
    }

    if ([string]$Authorization.question_id -ne "project_auto_mode_authorization") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "question_id must be project_auto_mode_authorization" }
    }
    if ([string]$Authorization.source -ne "request_user_input") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "source must be request_user_input" }
    }
    if ([string]$Authorization.selected_authority -ne "bounded-auto-merge") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "selected_authority must be bounded-auto-merge" }
    }

    $specPath = Join-Path $RepoRoot ([string]$Authorization.source_spec)
    $specRoot = Join-Path $RepoRoot "docs\superpowers\specs"
    $resolvedSpecRoot = [IO.Path]::GetFullPath($specRoot)
    $resolvedSpecPath = [IO.Path]::GetFullPath($specPath)
    if (-not $resolvedSpecPath.StartsWith($resolvedSpecRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "source_spec must be under docs/superpowers/specs" }
    }
    if (-not (Test-Path -LiteralPath $resolvedSpecPath -PathType Leaf)) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "source_spec does not exist" }
    }

    if ([string]$Authorization.route_policy.selected_mode -ne "agent-chooses") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "route_policy.selected_mode must be agent-chooses" }
    }
    if ([string]$Authorization.route_policy.worker_route -ne "issue-backed-orchestrate-only") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "worker_route must be issue-backed-orchestrate-only" }
    }
    if ([string]$Authorization.decision_policy.selected_mode -ne "recorded-defaults" -or $Authorization.decision_policy.stop_outside_policy -ne $true) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "decision_policy must use recorded-defaults and stop_outside_policy true" }
    }
    if ([string]$Authorization.merge_permission.selected_mode -ne "preauthorized-after-clean-premerge" -or $Authorization.merge_permission.require_clean_premerge -ne $true) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "merge_permission must require clean premerge" }
    }

    foreach ($needed in @("current-repo", "development-branch")) {
        if (@($Authorization.mutation_scope) -notcontains $needed) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "mutation_scope missing $needed" }
        }
    }
    foreach ($needed in @("plan-proof-oracle", "verification-receipts", "cleanup-hook", "premerge-proof", "closeout-proof")) {
        if (@($Authorization.required_proof) -notcontains $needed) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "required_proof missing $needed" }
        }
    }
    foreach ($needed in @("missing-proof", "dirty-unsafe-state", "failed-validation", "decision-outside-policy")) {
        if (@($Authorization.stop_conditions) -notcontains $needed) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "stop_conditions missing $needed" }
        }
    }

    [pscustomobject]@{ ok = $true; phase = "auto-mode-authorization"; reason = "passed" }
}
```

- [ ] **Step 4: Run the contract test to verify it passes**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-auto-mode-contract.ps1
```

Expected: exits `0`; output includes `happy authorization passes` and `direct worker mode blocks` with `ok: true`.

- [ ] **Step 5: Wire the contract test into validation**

In `scripts/validate.ps1`, add this step after `Advanced user input policy contract`:

```powershell
$results.Add((Invoke-Step "Auto Mode authorization contract" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-auto-mode-contract.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Auto Mode authorization contract failed" }
}))
```

- [ ] **Step 6: Commit Task 1**

Run:

```powershell
git add scripts/lib/auto-mode-contract.ps1 scripts/test-auto-mode-contract.ps1 scripts/validate.ps1
git commit -m "Add auto mode authorization contract"
```

### Task 2: Update Shared Native Continuation Semantics

**Files:**

- Modify: `scripts/test-advanced-user-input-policy.ps1`
- Modify: `scripts/test-native-continuation-loop.ps1`
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`

- [ ] **Step 1: Add failing shared policy assertions**

In `scripts/test-advanced-user-input-policy.ps1`, replace checks that require `No / Stop / Done` as a universal terminal label with checks for:

```powershell
foreach ($needle in @(
    "Use Stop for mid-loop exits",
    "Use Done only for verified final states",
    "Intermediate closeout gates use Yes, Revisit, and Stop",
    "Final clean closeout gates may use Yes, Revisit, and Done",
    "custom answers that claim completion before proof exists are treated as Stop"
)) {
    Add-Check $checks "advanced-user-input contains $needle" ($text.Contains($needle)) "$skillPath must contain policy: $needle"
}
foreach ($forbidden in @(
    "Right is shown to the user as No / Stop / Done",
    "Only No / Stop / Done can end a continuation loop",
    "Ask exactly three top-level options: Yes, Revisit, and No / Stop / Done"
)) {
    Add-Check $checks "advanced-user-input omits $forbidden" (-not $text.Contains($forbidden)) "$skillPath must not contain old terminal label policy: $forbidden"
}
```

- [ ] **Step 2: Add failing active-contract scan**

In `scripts/test-native-continuation-loop.ps1`, define active intermediate and final skills:

```powershell
$intermediateSkills = @(
    "initiate-workflow",
    "setup-project",
    "brainstorm-spec",
    "write-plan",
    "implement-plan",
    "create-issues",
    "resolve-issue",
    "orchestrate-issues"
)
$finalCapableSkills = @("merge-changes", "audit-project")
```

Then replace old universal checks with:

```powershell
foreach ($skillName in $intermediateSkills) {
    $text = Get-Content -LiteralPath (Join-Path $skillRoot "$skillName\SKILL.md") -Raw
    $agentText = Get-Content -LiteralPath (Join-Path $skillRoot "$skillName\agents\openai.yaml") -Raw
    Add-Check $checks "$skillName uses Stop for intermediate terminal route" ($text.Contains("Stop") -and $agentText.Contains("Stop")) "$skillName must expose Stop on intermediate gates"
    Add-Check $checks "$skillName omits Stop Done combined label" (-not $text.Contains("Stop / Done") -and -not $agentText.Contains("Stop / Done")) "$skillName must not use combined Stop / Done"
}
foreach ($skillName in $finalCapableSkills) {
    $text = Get-Content -LiteralPath (Join-Path $skillRoot "$skillName\SKILL.md") -Raw
    Add-Check $checks "$skillName defines final Done gate" ($text.Contains("Done") -and $text.Contains("verified final")) "$skillName must define verified final Done semantics"
}
```

- [ ] **Step 3: Run shared tests to verify failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
```

Expected: both exit `1`; failures name missing phase-sensitive policy and old `Stop / Done` text still present.

- [ ] **Step 4: Update `advanced-user-input` skill text and metadata**

In `skills/advanced-user-input/SKILL.md`, replace the `## Continuation Gates` section with a phase-sensitive version:

```markdown
## Continuation Gates

For workflow closeout, preserve the user's direction model:

- Down is shown to the user as Yes and means progress or default move-on.
- Left is shown to the user as Revisit and means revise, review, repair, rerun, recover, or gather more evidence.
- Right is terminal and is phase-sensitive.

Use Stop for mid-loop exits. Use Done only for verified final states.

Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop. A saved spec, saved plan, created issue set, PR-ready branch, or PR-ready worker handoff is not final completion.

Final clean closeout gates may use exactly three top-level options: Yes, Revisit, and Done. Done is valid only after a skill proves a final state, such as clean merge closeout proof or an explicit healthy audit gate with no remaining repair route.

Revisit is non-terminal. Yes must start the selected progress route or ask the blocking child question. Review First is not a terminal answer. Custom answers that mean a mid-loop exit are treated as Stop. Custom answers that claim completion before final proof exists are treated as Stop and the agent reports the remaining lifecycle state.

Do not end a loop until the user chooses Stop, reaches a verified final Done gate, or provides a Custom answer that maps to one of those states. Executable routes run, then ask the next native continuation or permission question instead of closing the turn.
```

Mirror the same policy in `skills/advanced-user-input/agents/openai.yaml`.

- [ ] **Step 5: Run shared tests to verify they pass**

Run the two commands from Step 3.

Expected: both exit `0`.

- [ ] **Step 6: Commit Task 2**

Run:

```powershell
git add scripts/test-advanced-user-input-policy.ps1 scripts/test-native-continuation-loop.ps1 skills/advanced-user-input/SKILL.md skills/advanced-user-input/agents/openai.yaml
git commit -m "Refine native terminal label policy"
```

### Task 3: Add Auto Mode Route After Spec Creation

**Files:**

- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/brainstorm-spec/scripts/test-scenarios.ps1`
- Modify: `skills/initiate-workflow/SKILL.md`
- Modify: `skills/initiate-workflow/agents/openai.yaml`
- Modify: `skills/initiate-workflow/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing brainstorm scenario assertions**

In `skills/brainstorm-spec/scripts/test-scenarios.ps1`, add an Auto Mode scenario:

```powershell
Invoke-Scenario "auto mode route after spec creation is present" {
    $text = Get-Content -LiteralPath $skillFile -Raw
    foreach ($needle in @(
        "project_brainstorm_start_route",
        "Manual Planning",
        "Auto Mode",
        "project_auto_mode_authorization",
        "bounded-auto-merge",
        "recorded defaults",
        "issue-backed-orchestrate-only",
        "scripts/lib/auto-mode-contract.ps1",
        "Auto Mode starts only after the spec is saved and self-reviewed"
    )) {
        Assert-Contains $text $needle "missing Auto Mode brainstorm route: $needle"
    }
    Assert-NotContains $text "Stop / Done" "brainstorm-spec must use Stop for intermediate closeouts"
}
```

Update the metadata scenario to require the same route strings in `agents/openai.yaml`.

- [ ] **Step 2: Add failing router scenario assertions**

In `skills/initiate-workflow/scripts/test-scenarios.ps1`, add required strings:

```powershell
foreach ($needle in @(
    "Auto Mode",
    "project_auto_mode_authorization",
    "bounded-auto-merge",
    "scripts/lib/auto-mode-contract.ps1",
    "route project_auto_mode_authorization only after brainstorm-spec saves a spec"
)) {
    Assert-Contains -Text $skill -Needle $needle -Reason "missing Auto Mode router contract: $needle"
}
Assert-NotContains -Text $skill -Needle "Stop / Done" -Reason "router must use phase-sensitive terminal labels"
```

- [ ] **Step 3: Run scenarios to verify failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\initiate-workflow\scripts\test-scenarios.ps1
```

Expected: both exit `1` with missing Auto Mode route strings.

- [ ] **Step 4: Update `brainstorm-spec` route contract**

In `skills/brainstorm-spec/SKILL.md`, change the post-spec continuation tree:

```markdown
If the user selects `Continue From Spec`, ask:

Question id: `project_brainstorm_start_route`

Prompt: `How should this saved spec continue?`

Options:

- Down: `Manual Planning`: choose one-plan or multi-spec planning.
- Left: `Auto Mode`: ask `project_auto_mode_authorization`, validate the ledger with `scripts/lib/auto-mode-contract.ps1`, then continue into `$project:write-plan`.
- Right: `Stop`: stop with the saved spec as the current artifact.
```

Then move the existing one-plan and multi-spec question under `Manual Planning`. Replace intermediate `Stop / Done` labels with `Stop`.

- [ ] **Step 5: Add Auto Mode authorization question contract**

Add this section to `skills/brainstorm-spec/SKILL.md`:

```markdown
## Auto Mode Authorization

Auto Mode starts only after the spec is saved and self-reviewed.

Question id: `project_auto_mode_authorization`

Prompt: `Authorize Auto Mode for this saved spec?`

Options:

- Down: `Bounded Auto Merge`: authorize bounded auto-merge with recorded defaults, agent route choice, and merge only after clean premerge proof.
- Left: `Auto To PR`: authorize unattended planning and implementation through PR-ready proof, but require live merge approval.
- Right: `Stop`: do not start Auto Mode.

For the first implementation, only `Bounded Auto Merge` produces a valid Auto Mode ledger. The ledger must use `worker_route: issue-backed-orchestrate-only`. Direct `implement-plan` worker mode is outside first-pass scope.
```

Mirror the route and authorization wording in `skills/brainstorm-spec/agents/openai.yaml`.

- [ ] **Step 6: Update `initiate-workflow` route contract**

In `skills/initiate-workflow/SKILL.md` and `agents/openai.yaml`, add Auto Mode as a supported `brainstorm-spec` child route and state that the router must not offer `project_auto_mode_authorization` until a source spec exists under `docs/superpowers/specs`.

- [ ] **Step 7: Run scenarios to verify they pass**

Run the two scenario commands from Step 3.

Expected: both exit `0`.

- [ ] **Step 8: Commit Task 3**

Run:

```powershell
git add skills/brainstorm-spec skills/initiate-workflow
git commit -m "Add auto mode route after spec creation"
```

### Task 4: Propagate Phase-Sensitive Stop And Done Labels

**Files:**

- Modify: all active project `SKILL.md` files and `agents/openai.yaml` files listed in the File Map.
- Modify: all active project skill `scripts/test-scenarios.ps1` files listed in the File Map.

- [ ] **Step 1: Update intermediate skill scenario tests first**

For each intermediate skill scenario script (`setup-project`, `brainstorm-spec`, `write-plan`, `implement-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `initiate-workflow`), replace assertions requiring `Stop / Done` with assertions requiring `Stop` and rejecting `Stop / Done`.

Use this pattern:

```powershell
Assert-Contains $text "Stop" "missing intermediate Stop label"
Assert-NotContains $text "Stop / Done" "intermediate skill must not use combined Stop / Done label"
```

For metadata tests, apply the same assertions to `$metadata`.

- [ ] **Step 2: Update final-capable skill scenario tests**

In `skills/merge-changes/scripts/test-scenarios.ps1`, add checks for:

```powershell
foreach ($needle in @(
    "verified final Done gate",
    "project_merge_final_health_gate",
    "Done is valid only after closeout proof passes",
    "Stop remains the terminal option when premerge or closeout proof is incomplete"
)) {
    Assert-Contains $text $needle "missing merge Done gate contract: $needle"
}
```

In `skills/audit-project/scripts/test-scenarios.ps1`, add checks for:

```powershell
foreach ($needle in @(
    "verified final Done gate",
    "Healthy -> Done",
    "Done is valid only when no blocking or repairable findings remain",
    "Stop remains the terminal option when findings remain"
)) {
    Assert-Contains $text $needle "missing audit Done gate contract: $needle"
}
```

- [ ] **Step 3: Run all scenario scripts to verify failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\setup-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\create-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\initiate-workflow\scripts\test-scenarios.ps1
```

Expected: at least the intermediate skills fail because active docs still contain combined terminal labels.

- [ ] **Step 4: Replace shared loop wording in active skills**

In each active project skill and metadata file, replace the generic text:

```text
Only No / Stop / Done can break the loop before that final Done gate.
```

with:

```text
Only Stop can break an intermediate loop. Done is valid only at a verified final Done gate.
```

Replace:

```text
No / Stop / Done
```

with `Stop` for intermediate routes and with `Done` only in verified final gate sections.

- [ ] **Step 5: Add final healthy gate to `merge-changes`**

In `skills/merge-changes/SKILL.md`, after closeout proof, define:

```markdown
If closeout proof passes, ask:

Question id: `project_merge_final_health_gate`

Prompt: `Closeout proof is clean. Mark this workflow done?`

Options:

- Down: `Done`: end the workflow as complete.
- Left: `Revisit`: review closeout evidence, then return to `project_merge_next_step`.
- Right: `Stop`: stop with clean closeout proof recorded.
```

State that `project_merge_next_step` uses `Stop` until this healthy gate is reached. Mirror the wording in metadata.

- [ ] **Step 6: Update `audit-project` final healthy wording**

In `skills/audit-project/SKILL.md` and metadata, keep the existing healthy completion idea but align labels:

```text
If audit findings are blocking or repairable, the terminal option is Stop. Done appears only after a healthy audit result proves no blocking or repairable findings remain.
```

- [ ] **Step 7: Run scenarios and shared continuation validator**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
```

Expected: all exit `0`.

- [ ] **Step 8: Commit Task 4**

Run:

```powershell
git add skills scripts/test-native-continuation-loop.ps1
git commit -m "Apply phase-sensitive terminal labels"
```

### Task 5: Teach Planning And Execution Skills To Consume Auto Mode Authorization

**Files:**

- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `skills/write-plan/scripts/test-scenarios.ps1`
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/test-scenarios.ps1`
- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/test-scenarios.ps1`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/test-scenarios.ps1`
- Modify: `skills/orchestrate-issues/SKILL.md`
- Modify: `skills/orchestrate-issues/agents/openai.yaml`
- Modify: `skills/orchestrate-issues/scripts/test-scenarios.ps1`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add failing Auto Mode assertions to downstream scenarios**

Add these shared required strings to affected scenario scripts:

```powershell
foreach ($needle in @(
    "Auto Mode authorization ledger",
    "scripts/lib/auto-mode-contract.ps1",
    "bounded-auto-merge",
    "recorded defaults",
    "stop outside policy"
)) {
    Assert-Contains $text $needle "missing Auto Mode downstream contract: $needle"
}
```

Use skill-specific additions:

- `write-plan`: `"Auto Mode authorization can satisfy the planning grill only when material decisions are covered"`.
- `implement-plan`: `"direct Auto Mode execution is inline only in the first implementation"`.
- `create-issues`: `"record the Auto Mode route reason in issue creation output"`.
- `resolve-issue`: `"Auto Mode can skip live topology prompt only when the ledger covers inline execution"`.
- `orchestrate-issues`: `"Auto Mode worker execution is issue-backed only"`.
- `merge-changes`: `"Auto Mode merge permission is accepted only after clean premerge proof"`.

- [ ] **Step 2: Run downstream scenarios to verify failure**

Run the downstream scenario commands listed in the Proof Oracle.

Expected: affected scripts fail with missing Auto Mode downstream contract strings.

- [ ] **Step 3: Update `write-plan` contract**

Add:

```markdown
## Auto Mode Planning Authorization

When a valid Auto Mode authorization ledger is present, validate it with `scripts/lib/auto-mode-contract.ps1` before using it.

Auto Mode authorization can satisfy the planning grill only when material decisions are covered by the source spec or the ledger's recorded defaults. If the plan needs a decision outside the ledger, stop outside policy and report the exact missing decision.

The plan must record:

- source spec path
- authorization ledger path
- route choice and reason
- decision defaults used
- proof oracle
- stop conditions inherited by downstream skills
```

Mirror in metadata.

- [ ] **Step 4: Update implementation and issue route contracts**

Add to `implement-plan`:

```markdown
For Auto Mode, direct execution is inline only in the first implementation. If the authorization ledger requests direct worker execution, stop because worker Auto Mode is issue-backed only.
```

Add to `create-issues`:

```markdown
When issue-backed Auto Mode is selected, record the Auto Mode route reason in each issue set summary and preserve AFK/HITL classification, milestone, labels, proof oracle, and Goal Command.
```

Add to `resolve-issue`:

```markdown
Auto Mode may skip the live topology prompt only when the authorization ledger covers inline execution and the issue mirror remains AFK-ready. Otherwise stop before implementation.
```

Add to `orchestrate-issues`:

```markdown
Auto Mode worker execution is issue-backed only. Validate the authorization ledger before worker creation and record the ledger path in the worker handoff.
```

Add to `merge-changes`:

```markdown
Auto Mode merge permission is accepted only after clean premerge proof. A valid Auto Mode authorization ledger is not merge proof by itself.
```

Mirror these policies in each metadata file.

- [ ] **Step 5: Run downstream scenarios**

Run all downstream scenario commands from Step 2.

Expected: all exit `0`.

- [ ] **Step 6: Commit Task 5**

Run:

```powershell
git add skills/write-plan skills/implement-plan skills/create-issues skills/resolve-issue skills/orchestrate-issues skills/merge-changes
git commit -m "Document auto mode downstream authorization"
```

### Task 6: Update README And Workflow Assets

**Files:**

- Modify: `README.md`
- Modify: `docs/assets/native-qa-main-flow-mermaid.md`
- Modify: `docs/assets/native-qa-main-flow.svg`
- Modify: `docs/assets/native-qa-main-flow-preview.html` only if needed.
- Modify: `scripts/test-native-qa-svg.ps1`

- [ ] **Step 1: Add failing asset/readme assertions**

In `scripts/test-native-qa-svg.ps1`, update README/Mermaid checks:

```powershell
foreach ($needle in @(
    "Auto Mode",
    "project_auto_mode_authorization",
    "Intermediate gates use Stop",
    "Done means verified final closeout"
)) {
    Add-Check $checks "README contains $needle" ($readme.Contains($needle)) "README must describe: $needle"
    Add-Check $checks "Mermaid companion contains $needle" ($mermaidText.Contains($needle)) "Mermaid must describe: $needle"
}
foreach ($forbidden in @(
    "top-level closeout options are always `Yes`, `Revisit`, and `No / Stop / Done`",
    "Only `No / Stop / Done`"
)) {
    Add-Check $checks "README omits $forbidden" (-not $readme.Contains($forbidden)) "README must not describe old terminal contract: $forbidden"
}
```

Add SVG checks:

```powershell
foreach ($needle in @("Auto Mode", "Stop means pause", "Done means complete")) {
    Add-Check $checks "SVG contains label $needle" ($svgText.Contains($needle)) "SVG must show workflow label: $needle"
}
Add-Check $checks "SVG omits Stop Done combined label" (-not $svgText.Contains("Stop / Done")) "SVG must not show combined Stop / Done"
```

- [ ] **Step 2: Run asset test to verify failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
```

Expected: exits `1` with missing Auto Mode and phase-sensitive label assertions.

- [ ] **Step 3: Update README text**

In `README.md`, replace the Native Q&A section with wording that says:

```markdown
Each skill summarizes what it produced, asks `Continue?`, and then starts the selected next skill automatically. Intermediate gates use `Yes`, `Revisit`, and `Stop`. `Done` is reserved for verified final closeout, such as a clean merge closeout or a healthy Doctor result with no remaining repair route.

After a saved spec, the `Yes` branch can choose manual planning or Auto Mode. Auto Mode asks `project_auto_mode_authorization`, records bounded auto-merge authority, and then continues through planning, implementation, verification, and merge using existing project skills while stopping if evidence is incomplete.
```

Update the native question table so intermediate rows show `Yes, Revisit, Stop`; final rows describe `Done` only for verified closeout gates.

- [ ] **Step 4: Update Mermaid companion**

In `docs/assets/native-qa-main-flow-mermaid.md`, add an Auto Mode branch under Brainstorm Spec and replace old terminal explanation with:

```mermaid
%% Intermediate gates use Stop. Done appears only after verified final closeout.
```

Keep the visual companion high level; do not add every nested route as a separate graph node.

- [ ] **Step 5: Update SVG asset**

Edit `docs/assets/native-qa-main-flow.svg` so visible labels include:

- `Auto Mode`
- `Stop means pause`
- `Done means complete`
- no `Stop / Done`

Keep the existing centered skill rail and right-side stop node geometry intact.

- [ ] **Step 6: Run asset validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
```

Expected: exits `0`.

- [ ] **Step 7: Commit Task 6**

Run:

```powershell
git add README.md docs/assets/native-qa-main-flow-mermaid.md docs/assets/native-qa-main-flow.svg docs/assets/native-qa-main-flow-preview.html scripts/test-native-qa-svg.ps1
git commit -m "Update native workflow docs for auto mode"
```

### Task 7: Full Validation, Live Sync Dry Run, And Closeout

**Files:**

- Modify only files needed to fix validation failures from earlier tasks.

- [ ] **Step 1: Run focused proof oracle commands**

Run every command in the Proof Oracle except `sync-live.ps1 -Validate` first.

Expected: each command exits `0`; if any command fails, fix the failing active contract rather than loosening the assertion.

- [ ] **Step 2: Run full repo validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: exits `0`.

- [ ] **Step 3: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: exits `0` and reports the repo's plugin source can sync to `C:\Users\Tanner\plugins\superpowers-project`.

- [ ] **Step 4: Run cleanup hook**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: exits `0` and reports no matching leftover Codex processes for this repo.

- [ ] **Step 5: Verify git state**

Run:

```powershell
git status --short --branch
```

Expected: branch is `codex/add-automode-option`; no unstaged or untracked files remain after final commit.

- [ ] **Step 6: Commit final validation fixes if any**

If validation required final edits, commit them:

```powershell
git add <exact files changed by validation fixes>
git commit -m "Validate auto mode workflow contracts"
```

Expected: commit succeeds or there are no remaining validation edits to commit.

## Plan Self-Review

- Spec coverage: the plan covers Auto Mode after spec creation, bounded authorization, route choice, issue-backed worker scope, Stop versus Done semantics, README/assets, validation, live sync validation, and cleanup.
- Placeholder scan: no placeholder tokens remain in the plan.
- Type consistency: question IDs, file paths, script names, helper names, and policy labels are consistent across tasks.
- Scope check: this is one coordinated workflow-contract implementation. Splitting it would risk drift between Auto Mode routing and Stop/Done terminal labels because they share continuation-gate code paths and docs.
