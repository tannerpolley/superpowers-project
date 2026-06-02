# Sync CI Release Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden live sync, add CI validation, and define the first release policy for the Milestones plugin repo.

**Architecture:** Extract sync tree operations into a small repo-owned PowerShell helper so stale cleanup and drift checks can be tested without touching live user paths. Keep `scripts/sync-live.ps1` responsible for the actual source-to-live deployment. Add one GitHub Actions workflow that runs the same validation command used locally, then document release criteria in the distribution milestone.

**Tech Stack:** PowerShell 7, GitHub Actions, Markdown docs, existing plugin validation scripts.

---

## Issue Metadata

**GitHub Issue:** Create from this local issue file before execution and rename the file after GitHub assigns the issue number.
**Issue Type:** `type:task`
**Milestone:** `M2 - Distribution` (`docs/milestones/M2-distribution`)
**Source Spec:** `docs/superpowers/specs/2026-06-02-bootstrap-workflow-design.md`

**Acceptance Criteria:**

- `scripts/sync-live.ps1` removes stale deployed Milestones-owned skill directories and refuses paths outside approved deployment roots.
- Sync tests prove stale cleanup removes only owned skill directories and preserves unrelated directories.
- `scripts/sync-live.ps1 -Validate` verifies post-sync source/live drift.
- `.github/workflows/validate.yml` runs `scripts/validate.ps1` on pull requests and pushes to `main`.
- `docs/milestones/M2-distribution/RELEASE_POLICY.md` defines the first tag policy and release gates.

**Non-Goals:**

- Do not publish a tag in this issue.
- Do not change validation behavior beyond invoking existing validation commands and sync tests.
- Do not change skill content in this issue.

**Proof Oracle:** `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sync-live.ps1`, `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests`, and `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` all exit zero after the M0 and M1 prerequisite issues are merged.

---

## File Map

- Create: `scripts/lib/sync-tree.ps1`  
  Owns reusable tree copy, stale cleanup, and hash comparison functions.
- Create: `scripts/test-sync-live.ps1`  
  Tests sync helper behavior with temporary directories.
- Modify: `scripts/sync-live.ps1`  
  Uses the helper functions and runs post-sync drift checks.
- Modify: `scripts/validate.ps1`  
  Runs the sync helper test.
- Create: `.github/workflows/validate.yml`  
  Runs repo validation in GitHub Actions.
- Create: `docs/milestones/M2-distribution/RELEASE_POLICY.md`  
  Defines version and tag gates.
- Modify: `README.md`  
  Links to the release policy and CI command.

## Task 1: Extract Testable Sync Tree Helpers

**Files:**

- Create: `scripts/lib/sync-tree.ps1`
- Create: `scripts/test-sync-live.ps1`
- Test: `scripts/test-sync-live.ps1`

- [ ] **Step 1: Create the sync helper library**

Create `scripts/lib/sync-tree.ps1` with:

```powershell
$ErrorActionPreference = "Stop"

function Get-SkillDirectoryNames {
    param([Parameter(Mandatory = $true)][string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $Root -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)
}

function Assert-ChildDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child
    )
    $resolvedParent = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $resolvedChild = [IO.Path]::GetFullPath($Child)
    if (-not $resolvedChild.StartsWith($resolvedParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to operate outside approved root: $resolvedChild"
    }
}

function Copy-SkillDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot
    )
    New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    foreach ($sourceSkill in (Get-ChildItem -LiteralPath $SourceRoot -Directory | Sort-Object Name)) {
        $target = Join-Path $TargetRoot $sourceSkill.Name
        Assert-ChildDirectory -Parent $TargetRoot -Child $target
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $sourceSkill.FullName -Destination $target -Recurse
    }
}

function Remove-StaleOwnedSkillDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string[]]$ActiveSkillNames,
        [Parameter(Mandatory = $true)][string[]]$RetiredSkillNames
    )
    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) { return @() }
    $ownedNames = @($ActiveSkillNames + $RetiredSkillNames | Sort-Object -Unique)
    $removed = [System.Collections.Generic.List[string]]::new()
    foreach ($targetSkill in (Get-ChildItem -LiteralPath $TargetRoot -Directory | Sort-Object Name)) {
        if ($ownedNames -contains $targetSkill.Name -and $ActiveSkillNames -notcontains $targetSkill.Name) {
            Assert-ChildDirectory -Parent $TargetRoot -Child $targetSkill.FullName
            Remove-Item -LiteralPath $targetSkill.FullName -Recurse -Force
            $removed.Add($targetSkill.Name)
        }
    }
    @($removed)
}

function Get-TreeHashes {
    param([Parameter(Mandatory = $true)][string]$Root)
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $hashes = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($resolvedRoot, $file.FullName).Replace("\", "/")
        $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    $hashes
}

function Compare-TreeHashes {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot
    )
    $source = Get-TreeHashes -Root $SourceRoot
    $target = Get-TreeHashes -Root $TargetRoot
    $keys = @($source.Keys + $target.Keys | Sort-Object -Unique)
    foreach ($key in $keys) {
        if (-not $source.ContainsKey($key)) {
            [pscustomobject]@{ path = $key; drift = "missing-in-source" }
        } elseif (-not $target.ContainsKey($key)) {
            [pscustomobject]@{ path = $key; drift = "missing-in-target" }
        } elseif ($source[$key] -ne $target[$key]) {
            [pscustomobject]@{ path = $key; drift = "content-diff" }
        }
    }
}

function Assert-NoTreeDrift {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $drift = @(Compare-TreeHashes -SourceRoot $SourceRoot -TargetRoot $TargetRoot)
    if ($drift.Count -gt 0) {
        throw "$Label drift detected: $($drift | ConvertTo-Json -Compress)"
    }
}
```

- [ ] **Step 2: Create the sync helper test**

Create `scripts/test-sync-live.ps1` with:

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\sync-tree.ps1")

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("milestones-sync-tests-" + [guid]::NewGuid().ToString("N"))
try {
    $source = Join-Path $tempRoot "source"
    $target = Join-Path $tempRoot "target"
    New-Item -ItemType Directory -Path (Join-Path $source "active-skill") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $target "retired-skill") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $target "unrelated-skill") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source "active-skill\SKILL.md") -Value "# Active`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $target "retired-skill\SKILL.md") -Value "# Retired`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $target "unrelated-skill\SKILL.md") -Value "# Unrelated`n" -Encoding UTF8

    Copy-SkillDirectories -SourceRoot $source -TargetRoot $target
    $removed = @(Remove-StaleOwnedSkillDirectories -TargetRoot $target -ActiveSkillNames @("active-skill") -RetiredSkillNames @("retired-skill"))

    if ($removed -ne "retired-skill") { throw "expected retired-skill cleanup, got: $($removed -join ', ')" }
    if (-not (Test-Path -LiteralPath (Join-Path $target "active-skill\SKILL.md") -PathType Leaf)) { throw "active skill was not deployed" }
    if (Test-Path -LiteralPath (Join-Path $target "retired-skill")) { throw "retired owned skill remains" }
    if (-not (Test-Path -LiteralPath (Join-Path $target "unrelated-skill\SKILL.md") -PathType Leaf)) { throw "unrelated skill was removed" }

    Assert-NoTreeDrift -SourceRoot (Join-Path $source "active-skill") -TargetRoot (Join-Path $target "active-skill") -Label "active skill"
    [pscustomobject]@{ ok = $true; removed = $removed } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{ ok = $false; reason = $_.Exception.Message } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
```

- [ ] **Step 3: Run the helper test**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sync-live.ps1
```

Expected: exits zero and emits JSON with `"ok": true` and `"retired-skill"`.

- [ ] **Step 4: Commit the helper test slice**

Run:

```powershell
git add scripts/lib/sync-tree.ps1 scripts/test-sync-live.ps1
git commit -m "test: add sync tree helper coverage"
```

## Task 2: Wire Sync Helpers Into Live Deployment

**Files:**

- Modify: `scripts/sync-live.ps1`
- Modify: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1`, `scripts/validate.ps1`

- [ ] **Step 1: Dot-source the sync helper**

In `scripts/sync-live.ps1`, after `$ErrorActionPreference = "Stop"`, add:

```powershell
. (Join-Path $PSScriptRoot "lib\sync-tree.ps1")
```

- [ ] **Step 2: Add owned skill metadata**

After the source root variables in `scripts/sync-live.ps1`, add:

```powershell
$activeSkillNames = @(Get-SkillDirectoryNames -Root $sourceSkillsRoot)
$activePluginSkillNames = @(Get-SkillDirectoryNames -Root $sourcePluginSkillsRoot)
$retiredSkillNames = @()
$retiredPluginSkillNames = @()
```

- [ ] **Step 3: Replace manual copy loops with helper calls**

Replace the plugin wrapper loop and user skill loop with:

```powershell
Copy-SkillDirectories -SourceRoot $sourcePluginSkillsRoot -TargetRoot $livePluginSkillsRoot
$removedPluginSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $livePluginSkillsRoot -ActiveSkillNames $activePluginSkillNames -RetiredSkillNames $retiredPluginSkillNames)

Copy-SkillDirectories -SourceRoot $sourceSkillsRoot -TargetRoot $userSkillsRootResolved
$removedUserSkills = @(Remove-StaleOwnedSkillDirectories -TargetRoot $userSkillsRootResolved -ActiveSkillNames $activeSkillNames -RetiredSkillNames $retiredSkillNames)

foreach ($skillName in $activePluginSkillNames) {
    Assert-NoTreeDrift -SourceRoot (Join-Path $sourcePluginSkillsRoot $skillName) -TargetRoot (Join-Path $livePluginSkillsRoot $skillName) -Label "plugin wrapper $skillName"
}
foreach ($skillName in $activeSkillNames) {
    Assert-NoTreeDrift -SourceRoot (Join-Path $sourceSkillsRoot $skillName) -TargetRoot (Join-Path $userSkillsRootResolved $skillName) -Label "user skill $skillName"
}
```

Update the final JSON object to include:

```powershell
removed_plugin_skills = $removedPluginSkills
removed_user_skills = $removedUserSkills
```

- [ ] **Step 4: Run sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: exits zero after prerequisite validation issues are merged. The JSON includes `removed_plugin_skills` and `removed_user_skills` arrays.

- [ ] **Step 5: Add sync tests to repo validation**

In `scripts/validate.ps1`, after the PowerShell parser check, add:

```powershell
    $results.Add((Invoke-Step "sync-live helper tests" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-sync-live.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "sync-live helper tests failed" }
    }))
```

- [ ] **Step 6: Run validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero and includes `"sync-live helper tests"`.

- [ ] **Step 7: Commit the sync wiring slice**

Run:

```powershell
git add scripts/sync-live.ps1 scripts/validate.ps1
git commit -m "feat: harden live sync validation"
```

## Task 3: Add Minimal CI

**Files:**

- Create: `.github/workflows/validate.yml`
- Test: GitHub Actions workflow syntax by local file inspection and next push.

- [ ] **Step 1: Create the workflow**

Create `.github/workflows/validate.yml` with:

```yaml
name: Validate

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  validate:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Validate Milestones plugin
        shell: pwsh
        run: pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

- [ ] **Step 2: Validate the workflow file is present**

Run:

```powershell
Test-Path -LiteralPath .\.github\workflows\validate.yml
```

Expected: prints `True`.

- [ ] **Step 3: Commit the CI workflow**

Run:

```powershell
git add .github/workflows/validate.yml
git commit -m "ci: validate milestones plugin"
```

## Task 4: Document Release Policy

**Files:**

- Create: `docs/milestones/M2-distribution/RELEASE_POLICY.md`
- Modify: `docs/milestones/M2-distribution/README.md`
- Modify: `README.md`
- Test: Markdown inspection and structural validation.

- [ ] **Step 1: Create release policy doc**

Create `docs/milestones/M2-distribution/RELEASE_POLICY.md` with:

```markdown
# Release Policy

Milestones plugin releases are tags on the canonical source repository.

## Gates

Before creating a release tag:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` exits zero.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` exits zero.
- `CHANGELOG.md` contains the version entry.
- The live plugin and user-level skill copies match source after sync.

## Versioning

- Use `v0.1.0` for the first green canonical baseline if no repair commit changes behavior before tagging.
- Use `v0.1.1` if validation, sync, CI, or release-policy repair commits land before the first tag.
- Use patch releases for validation, sync, docs, and workflow fixes.
- Use minor releases for new skill behavior or new plugin capabilities.

## Tag Command

Run tags from `main` only after the gates pass:

```powershell
git tag v0.1.1
git push origin v0.1.1
```
```

- [ ] **Step 2: Link the release policy from the distribution README**

Append this section to `docs/milestones/M2-distribution/README.md`:

```markdown
## Release Policy

Release gates and tag rules live in `docs/milestones/M2-distribution/RELEASE_POLICY.md`.
```

- [ ] **Step 3: Link CI and release policy from the root README**

In `README.md`, after the Validate section, add:

```markdown
## CI And Releases

GitHub Actions runs the same validation command used locally:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Release gates and tag rules are documented in `docs/milestones/M2-distribution/RELEASE_POLICY.md`.
```

- [ ] **Step 4: Run structural validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero.

- [ ] **Step 5: Commit release policy docs**

Run:

```powershell
git add README.md docs/milestones/M2-distribution/README.md docs/milestones/M2-distribution/RELEASE_POLICY.md
git commit -m "docs: add release policy"
```

## Closeout

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-sync-live.ps1
```

Expected: exits zero.

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero.

- [ ] Run after M0 and M1 prerequisite issues are merged:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: exits zero.

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: exits zero and reports no matching leftover repo processes.
