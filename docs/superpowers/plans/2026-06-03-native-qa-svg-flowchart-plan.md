# Native Q&A SVG Flowchart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the README-visible native Q&A workflow diagram with a deterministic SVG flowchart that has fixed layout, local side branches, and light/dark mode readability.

**Architecture:** Keep the public diagram as a source-controlled SVG asset under `docs/assets` and embed it from `README.md`. Add a repo validation script that enforces the diagram contract structurally so future edits do not regress the centered skill column, right-side Stop nodes, left-side alternate-action boxes, or dark-mode arrow styling.

**Tech Stack:** Markdown, SVG, PowerShell validation scripts, Playwright CLI for optional visual screenshot checks, existing `scripts/validate.ps1`.

---

## Intake

**Source Spec:** `docs/superpowers/specs/2026-06-03-native-qa-svg-flowchart-design.md`

**Milestone Linkage:**
- `M0 - Governance`: validation contract for public workflow docs.
- `M2 - Distribution`: public README clarity and dark-mode-safe visual documentation.

**Acceptance Criteria:**
- README embeds `docs/assets/native-qa-main-flow.svg`.
- README no longer contains the archived full Mermaid router/setup/Doctor flowchart.
- SVG exists under `docs/assets`.
- SVG owns light/dark mode background, arrow, label, and arrowhead styling.
- All primary blue skill boxes share one x coordinate and width.
- All Stop nodes are right of the primary skill column.
- All gray alternate-action boxes are left of the primary skill column.
- Visual smoke screenshots render in light and dark mode.
- `scripts/validate.ps1` passes.

**Non-Goals:**
- No `project-implement` skill changes.
- No runtime native Q&A behavior changes.
- No `project-merge`, `project-resolve`, `project-orchestrate`, or `advanced-user-input` changes.

**Proof Oracle:**
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- Optional visual checks:
  - `npx playwright screenshot --viewport-size="1400,1960" --color-scheme=light file:///C:/Users/Tanner/Documents/Workspaces/Projects/milestones-plugin/docs/assets/native-qa-main-flow.svg "$env:TEMP\native-qa-main-flow-light.png"`
  - `npx playwright screenshot --viewport-size="1400,1960" --color-scheme=dark file:///C:/Users/Tanner/Documents/Workspaces/Projects/milestones-plugin/docs/assets/native-qa-main-flow.svg "$env:TEMP\native-qa-main-flow-dark.png"`

## File Map

- Modify: `README.md`
  - Keep the public SVG embed.
  - Delete the archived full Mermaid diagram section.
- Create/Modify: `docs/assets/native-qa-main-flow.svg`
  - Source-controlled fixed-layout flowchart.
  - Theme-aware CSS variables for background, arrows, labels, and arrowheads.
- Create: `scripts/test-native-qa-svg.ps1`
  - Structural SVG/README contract test.
- Modify: `scripts/validate.ps1`
  - Invoke `scripts/test-native-qa-svg.ps1` as part of the normal validation suite.

### Task 1: Add SVG Contract Test

**Files:**
- Create: `scripts/test-native-qa-svg.ps1`
- Modify: none
- Test: `scripts/test-native-qa-svg.ps1`

- [ ] **Step 1: Create the failing contract test**

Create `scripts/test-native-qa-svg.ps1` with this content:

```powershell
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [string]$Reason = "passed"
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

$checks = [System.Collections.Generic.List[object]]::new()
$readmePath = Join-Path $RepoRoot "README.md"
$svgRelativePath = "docs/assets/native-qa-main-flow.svg"
$svgPath = Join-Path $RepoRoot $svgRelativePath

$readme = Get-Content -LiteralPath $readmePath -Raw
Add-Check $checks "README references SVG" ($readme.Contains("![Native Q&A main workflow flowchart]($svgRelativePath)")) "README must embed $svgRelativePath"
Add-Check $checks "README archived Mermaid removed" (-not $readme.Contains("Archived full setup, Doctor, and router flow")) "README must not keep the archived full Mermaid flowchart"
Add-Check $checks "SVG exists" (Test-Path -LiteralPath $svgPath -PathType Leaf) "missing SVG: $svgPath"

if (Test-Path -LiteralPath $svgPath -PathType Leaf) {
    [xml]$svg = Get-Content -LiteralPath $svgPath -Raw
    $svgText = Get-Content -LiteralPath $svgPath -Raw

    foreach ($needle in @("--bg", "--line", "--label", "@media (prefers-color-scheme: dark)", ".canvas", ".arrow-head")) {
        Add-Check $checks "SVG contains $needle" ($svgText.Contains($needle)) "SVG must contain theme contract token: $needle"
    }

    $rects = @($svg.svg.rect)
    $skillRects = @($rects | Where-Object { $_.class -eq "skill" })
    $sideRects = @($rects | Where-Object { $_.class -eq "side" })
    $stopRects = @($rects | Where-Object { $_.class -eq "stop" })

    $skillXValues = @($skillRects | ForEach-Object { [int]$_.x } | Sort-Object -Unique)
    $skillWidthValues = @($skillRects | ForEach-Object { [int]$_.width } | Sort-Object -Unique)
    Add-Check $checks "skill boxes share x" ($skillXValues.Count -eq 1 -and $skillXValues[0] -eq 520) "skill boxes must all use x=520"
    Add-Check $checks "skill boxes share width" ($skillWidthValues.Count -eq 1 -and $skillWidthValues[0] -eq 360) "skill boxes must all use width=360"
    Add-Check $checks "side boxes left of skills" (@($sideRects | Where-Object { [int]$_.x -ge 520 }).Count -eq 0) "side boxes must be left of the main skill column"
    Add-Check $checks "stop nodes right of skills" (@($stopRects | Where-Object { [int]$_.x -le 880 }).Count -eq 0) "stop nodes must be right of the main skill column"
}

$failed = @($checks | Where-Object { -not $_.ok })
$result = [pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "native-qa-svg-contract"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) {
    exit 1
}
```

- [ ] **Step 2: Run the contract test and verify it fails before the implementation is complete**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
```

Expected before Task 2 or Task 3 is complete: failure on the missing SVG, archived Mermaid section, or missing validation tokens.

- [ ] **Step 3: Commit checkpoint**

After the test is created and observed failing for the expected reason:

```powershell
git add scripts/test-native-qa-svg.ps1
git commit -m "test: add native qa svg contract"
```

### Task 2: Finalize README SVG Flowchart

**Files:**
- Modify: `README.md`
- Create/Modify: `docs/assets/native-qa-main-flow.svg`
- Test: `scripts/test-native-qa-svg.ps1`

- [ ] **Step 1: Remove the archived Mermaid block from README**

In `README.md`, keep:

```markdown
![Native Q&A main workflow flowchart](docs/assets/native-qa-main-flow.svg)
```

Delete the entire collapsed block that starts with:

```markdown
<details>
<summary>Archived full setup, Doctor, and router flow</summary>
```

and ends with:

```markdown
</details>
```

- [ ] **Step 2: Finalize the SVG asset**

Ensure `docs/assets/native-qa-main-flow.svg` contains:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1960" viewBox="0 0 1400 1960" role="img" aria-labelledby="title desc">
```

Ensure the SVG style block contains these theme tokens:

```css
:root {
  --bg: #ffffff;
  --line: #111827;
  --label: #111827;
  --title: #111827;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0b1020;
    --line: #f8fafc;
    --label: #f8fafc;
    --title: #f8fafc;
  }
}
.canvas { fill: var(--bg); }
.arrow { fill: none; stroke: var(--line); stroke-width: 2.5; marker-end: url(#arrow); }
.arrow-head { fill: var(--line); }
```

Ensure the primary skill rectangles use the same coordinate contract:

```xml
<rect x="520" ... width="360" ... class="skill" />
```

Ensure side-action rectangles use `class="side"` and `x` less than `520`.

Ensure Stop rectangles use `class="stop"` and `x` greater than `880`.

- [ ] **Step 3: Run the contract test**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
```

Expected: JSON output with `"ok": true`.

- [ ] **Step 4: Commit checkpoint**

```powershell
git add README.md docs/assets/native-qa-main-flow.svg
git commit -m "docs: add native qa svg flowchart"
```

### Task 3: Wire SVG Contract Into Repo Validation

**Files:**
- Modify: `scripts/validate.ps1`
- Test: `scripts/validate.ps1`

- [ ] **Step 1: Add the validation step**

In `scripts/validate.ps1`, after the `Superpowers project path contract` step and before the PowerShell parser check, add:

```powershell
$results.Add((Invoke-Step "Native Q&A SVG contract" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-native-qa-svg.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Native Q&A SVG contract failed" }
}))
```

- [ ] **Step 2: Run the focused validator**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
```

Expected: JSON output with `"ok": true`.

- [ ] **Step 3: Run the full validator**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: final JSON output with `"ok": true`.

- [ ] **Step 4: Commit checkpoint**

```powershell
git add scripts/validate.ps1 scripts/test-native-qa-svg.ps1
git commit -m "test: validate native qa svg flowchart"
```

### Task 4: Visual Smoke Check Light And Dark Mode

**Files:**
- Modify: none unless screenshots reveal a visual defect in `docs/assets/native-qa-main-flow.svg`
- Test: temporary screenshots under `$env:TEMP`

- [ ] **Step 1: Render light mode screenshot**

Run:

```powershell
$svgPath = (Resolve-Path .\docs\assets\native-qa-main-flow.svg).Path
$url = 'file:///' + ($svgPath -replace '\\','/')
npx playwright screenshot --viewport-size="1400,1960" --color-scheme=light $url "$env:TEMP\native-qa-main-flow-light.png"
```

Expected: screenshot file exists at `$env:TEMP\native-qa-main-flow-light.png`.

- [ ] **Step 2: Render dark mode screenshot**

Run:

```powershell
$svgPath = (Resolve-Path .\docs\assets\native-qa-main-flow.svg).Path
$url = 'file:///' + ($svgPath -replace '\\','/')
npx playwright screenshot --viewport-size="1400,1960" --color-scheme=dark $url "$env:TEMP\native-qa-main-flow-dark.png"
```

Expected: screenshot file exists at `$env:TEMP\native-qa-main-flow-dark.png`.

- [ ] **Step 3: Inspect screenshots**

Open both screenshots. Verify:

- blue skill boxes are aligned in one vertical column;
- gray alternate-action boxes are on the left;
- Stop nodes are on the right;
- decision labels are readable;
- arrows are visible in dark mode;
- no nodes overlap;
- no connector crosses through node text.

- [ ] **Step 4: Fix any visual defect and rerun checks**

If a visual defect is found, edit `docs/assets/native-qa-main-flow.svg`, then rerun:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-qa-svg.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: both commands pass.

### Task 5: Final Verification And Cleanup

**Files:**
- Modify: none unless verification finds an issue
- Test: full repo validation and cleanup hook

- [ ] **Step 1: Run full validation**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: final JSON output with `"ok": true`.

- [ ] **Step 2: Run cleanup hook**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: no matching leftover Codex processes under the repo.

- [ ] **Step 3: Check git status**

```powershell
git status --short --branch
```

Expected: only intentional changes remain, or the working tree is clean after commits.

- [ ] **Step 4: Final commit if needed**

If any intentional files remain uncommitted:

```powershell
git add README.md docs/assets/native-qa-main-flow.svg scripts/test-native-qa-svg.ps1 scripts/validate.ps1
git commit -m "docs: finalize native qa svg flowchart"
```

## Plan Self-Review

- Spec coverage: every SVG spec acceptance criterion maps to a task.
- Placeholder scan: no placeholder task remains.
- File paths: every task names exact files.
- TDD policy: Task 1 creates the failing contract before the implementation is finalized.
- Verification: focused SVG contract, full repo validation, Playwright screenshots, and cleanup hook are specified.
- Scope separation: no Project Implement, Merge, Orchestrate, or runtime native Q&A behavior changes are included.
