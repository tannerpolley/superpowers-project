# Source Wrapper And Drift Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make wrapper validation use repo source as authority and add a source wrapper contract check that covers every plugin wrapper.

**Architecture:** Keep wrappers as thin plugin namespace entries that point to deployed user-level skill implementations. Update scenario tests to inspect `skills/<skill>/SKILL.md` in the repo, then add a top-level source wrapper contract check in `scripts/validate.ps1` so all wrappers share the same enforced wording and skill set. This issue removes live deployment paths from source-level tests without changing runtime skill behavior.

**Tech Stack:** PowerShell 7, Markdown skill files, existing validator scripts, Git.

---

## Issue Metadata

**GitHub Issue:** Create from this local issue file before execution and rename the file after GitHub assigns the issue number.
**Issue Type:** `type:task`
**Milestone:** `M1 - Source Of Truth` (`docs/milestones/M1-source-of-truth`)
**Source Spec:** `docs/superpowers/specs/2026-06-02-bootstrap-workflow-design.md`

**Acceptance Criteria:**

- `using-milestones` scenario tests inspect the repo source wrapper under `skills/using-milestones/SKILL.md`.
- `milestone-writing-issue-plan` scenario tests inspect the repo source wrapper under `skills/milestone-writing-issue-plan/SKILL.md`.
- The expected wrapper wording matches the current wrapper contract: namespace wrapper, deployed user-level path, `Follow that skill exactly`, and no separate behavior.
- `scripts/validate.ps1` checks every canonical skill has a matching source wrapper with the same contract.
- Full `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` reaches later suites instead of failing on wrapper wording.

**Non-Goals:**

- Do not change the deployed user-level skill implementations.
- Do not edit live deployment copies directly.
- Do not change `sync-live.ps1` in this issue.

**Proof Oracle:** `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` no longer fails with `missing canonical follow rule` or `missing canonical read instruction`.

---

## File Map

- Modify: `canonical-skills/using-milestones/scripts/test-scenarios.ps1`  
  Reads the source wrapper instead of the deployed live wrapper and asserts the actual wrapper contract.
- Modify: `canonical-skills/milestone-writing-issue-plan/scripts/test-scenarios.ps1`  
  Uses the same source wrapper assertion pattern.
- Modify: `scripts/validate.ps1`  
  Adds a source wrapper contract check for all canonical skills.

## Task 1: Update Using Milestones Wrapper Scenario

**Files:**

- Modify: `canonical-skills/using-milestones/scripts/test-scenarios.ps1`
- Test: `canonical-skills/using-milestones/scripts/test-scenarios.ps1`

- [ ] **Step 1: Change the wrapper path to repo source**

Replace line 9:

```powershell
$pluginWrapper = "C:\Users\Tanner\plugins\milestones\skills\using-milestones\SKILL.md"
```

with:

```powershell
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot "..\..")).Path
$pluginWrapper = Join-Path $repoRoot "skills\using-milestones\SKILL.md"
```

- [ ] **Step 2: Update the wrapper contract assertions**

Replace the scenario body named `"plugin wrapper points to canonical skill"` with:

```powershell
    Invoke-Scenario "plugin wrapper points to deployed user skill" {
        $text = Get-Content -LiteralPath $pluginWrapper -Raw
        Assert-True ($text -match '(?m)^---\s*\r?\nname: using-milestones') "missing wrapper frontmatter"
        Assert-True ($text.Contains('C:\Users\Tanner\.agents\skills\using-milestones\SKILL.md')) "missing deployed user skill path"
        Assert-True ($text -match 'namespace wrapper') "missing namespace wrapper wording"
        Assert-True ($text.Contains('Read the deployed user-level `SKILL.md` above.')) "missing deployed read instruction"
        Assert-True ($text.Contains('Follow that skill exactly.')) "missing follow instruction"
        Assert-True ($text -match 'do not invent separate behavior') "missing no separate behavior warning"
    }
```

- [ ] **Step 3: Run the targeted scenario**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\using-milestones\scripts\test-scenarios.ps1
```

Expected: exits zero.

- [ ] **Step 4: Commit the using wrapper scenario change**

Run:

```powershell
git add canonical-skills/using-milestones/scripts/test-scenarios.ps1
git commit -m "test: validate using milestones source wrapper"
```

## Task 2: Update Milestone Writing Wrapper Scenario

**Files:**

- Modify: `canonical-skills/milestone-writing-issue-plan/scripts/test-scenarios.ps1`
- Test: `canonical-skills/milestone-writing-issue-plan/scripts/test-scenarios.ps1`

- [ ] **Step 1: Change the wrapper path to repo source**

Replace line 9:

```powershell
$pluginWrapperFile = Join-Path $env:USERPROFILE "plugins\milestones\skills\milestone-writing-issue-plan\SKILL.md"
```

with:

```powershell
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot "..\..")).Path
$pluginWrapperFile = Join-Path $repoRoot "skills\milestone-writing-issue-plan\SKILL.md"
```

- [ ] **Step 2: Update the wrapper assertions**

Replace the scenario body named `"plugin wrapper points to canonical skill"` with:

```powershell
    Invoke-Scenario "plugin wrapper points to deployed user skill" {
        $text = Get-Content -LiteralPath $pluginWrapperFile -Raw
        Assert-Match $text "(?s)^---\s*name:\s*milestone-writing-issue-plan\s*description:" "missing wrapper frontmatter"
        Assert-Contains $text "namespace wrapper" "missing wrapper declaration"
        Assert-Contains $text "C:\Users\Tanner\.agents\skills\milestone-writing-issue-plan\SKILL.md" "missing deployed user skill path"
        Assert-Contains $text 'Read the deployed user-level `SKILL.md` above.' "missing deployed read instruction"
        Assert-Contains $text "Follow that skill exactly." "missing follow instruction"
        Assert-Contains $text "Treat this plugin wrapper as organization only" "missing no separate behavior rule"
    }
```

- [ ] **Step 3: Run the targeted scenario**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\milestone-writing-issue-plan\scripts\test-scenarios.ps1
```

Expected: exits zero.

- [ ] **Step 4: Commit the milestone-writing scenario change**

Run:

```powershell
git add canonical-skills/milestone-writing-issue-plan/scripts/test-scenarios.ps1
git commit -m "test: validate milestone plan source wrapper"
```

## Task 3: Add A Source Wrapper Contract Check To Validate

**Files:**

- Modify: `scripts/validate.ps1`
- Test: `scripts/validate.ps1`

- [ ] **Step 1: Add the contract check functions**

In `scripts/validate.ps1`, after `Invoke-Step`, add:

```powershell
function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Reason
    )
    if (-not $Text.Contains($Needle)) {
        throw "$Reason in $Path"
    }
}

function Test-PluginWrapperContracts {
    $canonicalNames = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)
    $wrapperNames = @(Get-ChildItem -LiteralPath $pluginSkillRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)

    $missingWrappers = @($canonicalNames | Where-Object { $wrapperNames -notcontains $_ })
    $extraWrappers = @($wrapperNames | Where-Object { $canonicalNames -notcontains $_ })
    if ($missingWrappers.Count -gt 0) { throw "missing plugin wrapper(s): $($missingWrappers -join ', ')" }
    if ($extraWrappers.Count -gt 0) { throw "plugin wrapper(s) without canonical skill: $($extraWrappers -join ', ')" }

    foreach ($name in $canonicalNames) {
        $wrapperPath = Join-Path $pluginSkillRoot "$name\SKILL.md"
        if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
            throw "missing wrapper SKILL.md: $wrapperPath"
        }
        $text = Get-Content -LiteralPath $wrapperPath -Raw
        Assert-TextContains -Text $text -Needle "name: $name" -Path $wrapperPath -Reason "missing wrapper name"
        Assert-TextContains -Text $text -Needle "namespace wrapper" -Path $wrapperPath -Reason "missing namespace wrapper contract"
        Assert-TextContains -Text $text -Needle "C:\Users\Tanner\.agents\skills\$name\SKILL.md" -Path $wrapperPath -Reason "missing deployed user skill path"
        Assert-TextContains -Text $text -Needle 'Read the deployed user-level `SKILL.md` above.' -Path $wrapperPath -Reason "missing deployed read instruction"
        Assert-TextContains -Text $text -Needle "Follow that skill exactly." -Path $wrapperPath -Reason "missing follow instruction"
        Assert-TextContains -Text $text -Needle "do not invent separate behavior" -Path $wrapperPath -Reason "missing no separate behavior rule"
    }
}
```

- [ ] **Step 2: Invoke the contract check**

After the existing directory existence checks in `scripts/validate.ps1`, add:

```powershell
    $results.Add((Invoke-Step "Plugin wrapper source contract" {
        Test-PluginWrapperContracts
    }))
```

- [ ] **Step 3: Run structural validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero and includes `"Plugin wrapper source contract"`.

- [ ] **Step 4: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: the previous wrapper failures are gone. If the M0 timeout work has not landed, the command may stop later on that independent issue.

- [ ] **Step 5: Commit the top-level wrapper validation**

Run:

```powershell
git add scripts/validate.ps1
git commit -m "test: enforce plugin wrapper source contracts"
```

## Closeout

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero.

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: exits zero and reports no matching leftover repo processes.
