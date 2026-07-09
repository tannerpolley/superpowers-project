# Superpowers HTML Companion Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first opt-in Superpowers Project HTML companion interface so specs, plans, issue evidence, validation receipts, plots, tables, and summaries can be rendered in the Codex in-app browser while chat remains concise.

**Architecture:** Add a source-owned `companion-interface` skill plus Bash helper scripts and static templates. The v1 companion creates repo-scoped report sessions under `.superpowers/reports`, writes structured JSON and JSONL evidence, and regenerates a self-contained HTML report from the manifest instead of running a long-lived local server.

**Tech Stack:** Bash 7, Pandoc, JSON/JSONL, static HTML/CSS/JavaScript, Markdown, existing Superpowers Project validators.

---

## Source Spec

- `docs/superpowers/specs/2026-06-12-superpowers-html-companion-interface-design.md`

## User Decisions Recorded

- Implementation surface: `Skill + Helpers`.
- Browser refresh model: `Static Regenerate`.
- Rollout: `Opt-In First`.
- Math and diagram scope: `Pandoc MathML` for v1. Local MathJax and Mermaid asset bundling are outside this implementation plan.

## Test-Complete Definition

This plan is test complete when:

- `scripts/test-companion-interface.sh` passes.
- `skills/companion-interface/scripts/test-scenarios.sh` passes.
- `scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md` passes.
- `scripts/validate.sh` passes.
- `scripts/sync-live.sh --validate` passes before reporting live install readiness.
- The cleanup hook reports no leftover repo-owned companion processes.

No scientific or engineering numerical metrics are required. This is a workflow and rendering feature; pass/fail is contract-based: generated files exist where expected, JSON schemas are valid, rendered HTML contains required sections, command results carry exact statuses, and native approval boundaries remain intact.

## Acceptance Criteria

- A new `companion-interface` skill exists under `skills/companion-interface`.
- The plugin metadata and docs expose `$superpowers-project:companion-interface`.
- A repo-scoped report session can be created under `.superpowers/reports/<yyyy-mm-dd>/<run-id>`.
- A report session contains `manifest.json`, `events.jsonl`, `index.html`, and `artifacts/`.
- Event append scripts reject report paths outside the repo-scoped report root.
- The renderer converts a fixture manifest into a self-contained HTML report with run overview, timeline, artifact browser, evidence feed, validation receipts, decision dock, and summary sections.
- Markdown artifacts render through Pandoc with YAML frontmatter separated from rendered body.
- Math in Markdown renders through Pandoc MathML.
- Plot and table fixture artifacts appear in the report.
- Validation receipt fixture artifacts show command, working directory, exit code, status, and output excerpt.
- The companion displays pending decision context without recording approval.
- `brainstorm-spec` and `write-plan` skill contracts include opt-in companion reporting guidance without weakening native continuation or artifact review gates.

## Non-Goals

- Do not replace native Codex chat.
- Do not replace `request_user_input`.
- Do not make HTML reports the approval authority.
- Do not add a long-lived local server in this plan.
- Do not add local MathJax or Mermaid asset bundling in this plan.
- Do not make generated HTML the canonical source for specs, plans, or issue mirrors.
- Do not update every governed skill in the first slice.
- Do not edit deployed live plugin copies directly.

## File Map

- Create: `skills/companion-interface/SKILL.md`
- Create: `skills/companion-interface/agents/openai.yaml`
- Create: `skills/companion-interface/scripts/lib/companion-report.sh`
- Create: `skills/companion-interface/scripts/new-report-session.sh`
- Create: `skills/companion-interface/scripts/append-event.sh`
- Create: `skills/companion-interface/scripts/render-report.sh`
- Create: `skills/companion-interface/scripts/test-scenarios.sh`
- Create: `skills/companion-interface/templates/report-template.html`
- Create: `skills/companion-interface/templates/report.css`
- Create: `skills/companion-interface/templates/report.js`
- Create: `scripts/test-companion-interface.sh`
- Modify: `scripts/validate.sh`
- Modify: `README.md`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`

## Task 1: Register Companion Skill And Contract Tests

**Use Cases:**
- User asks for a Superpowers Project companion interface and the plugin exposes a canonical `$superpowers-project:companion-interface` route.
- A future agent validates the repo and the new skill must be treated as source-owned, not as an external helper.
- The plugin startup prompt lists the companion route without replacing existing workflow routes.
- Documentation readers see that the companion is an evidence surface, not a Goal Buddy Board or approval channel.

**Files:**
- Create: `scripts/test-companion-interface.sh`
- Create: `skills/companion-interface/SKILL.md`
- Create: `skills/companion-interface/agents/openai.yaml`
- Modify: `scripts/validate.sh`
- Modify: `README.md`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `.codex-plugin/plugin.json`

- [ ] **Step 1: Write the failing companion contract test**

Create `scripts/test-companion-interface.sh` with checks equivalent to:

```bash
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    }) | Out-Null
}

function Assert-Contains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    Add-Check -Name $Name -Ok $text.Contains($Needle) -Reason "$Path missing $Needle"
}

try {
    Assert-Contains -Path "skills/companion-interface\SKILL.md" -Needle "name: companion-interface" -Name "skill frontmatter exists"
    Assert-Contains -Path "skills/companion-interface\SKILL.md" -Needle "evidence and interpretation channel" -Name "skill defines evidence channel"
    Assert-Contains -Path "skills/companion-interface\SKILL.md" -Needle "must not record approval" -Name "skill preserves native approvals"
    Assert-Contains -Path "skills/companion-interface\agents\openai.yaml" -Needle "companion-interface" -Name "metadata exists"
    Assert-Contains -Path ".codex-plugin\plugin.json" -Needle '$superpowers-project:companion-interface' -Name "plugin prompt lists companion"
    Assert-Contains -Path "README.md" -Needle '$superpowers-project:companion-interface' -Name "README lists companion"
    Assert-Contains -Path "docs/superpowers\PROJECT_CONTEXT.md" -Needle "companion-interface" -Name "project context lists companion"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "companion-interface-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "companion-interface-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
```

- [ ] **Step 2: Run the contract test and verify the expected failure**

Run:

```bash
./scripts/test-companion-interface.sh
```

Expected: command exits nonzero because `skills/companion-interface/SKILL.md` does not exist yet.

- [ ] **Step 3: Create the companion skill contract**

Create `skills/companion-interface/SKILL.md` with frontmatter and required sections:

```markdown
---
name: companion-interface
description: Use when a Superpowers Project workflow should create or update the local HTML companion report for rich artifact review.
---

# Companion Interface

Companion Interface is the Superpowers Project evidence and interpretation channel. It writes repo-scoped report sessions and renders a static HTML workbench for the Codex in-app browser.

Use this skill when the user asks to show rich artifacts, when a workflow produces large specs or plans, or when implementation evidence includes plots, tables, validation receipts, screenshots, diagrams, or long summaries.

## Approval Boundary

The companion must not record approval, push, publish, merge, live sync, GitHub mutation, or final Done. Native Codex chat and `request_user_input` remain the decision authority.

## Report Model

Use `scripts/new-report-session.sh` to create a session, `scripts/append-event.sh` to add structured evidence, and `scripts/render-report.sh` to regenerate `index.html`.

Generated reports live under `.superpowers/reports/<yyyy-mm-dd>/<run-id>`.

## Required Closeout

After updating a report, tell the user the exact `index.html` path and the artifact types added. Keep chat concise and point detailed review to the companion.
```

- [ ] **Step 4: Create skill metadata**

Create `skills/companion-interface/agents/openai.yaml`:

```yaml
name: companion-interface
description: Render Superpowers Project workflow artifacts into a local HTML companion report while keeping native Codex chat and request_user_input as the approval channel.
tools:
  - shell
```

- [ ] **Step 5: Register companion in plugin-facing docs**

Update `.codex-plugin/plugin.json` `interface.defaultPrompt` by adding:

```json
"Use $superpowers-project:companion-interface to create or refresh the local HTML companion report for rich artifact review while native Codex input remains the approval channel."
```

Update `README.md` near the workflow skill list with:

```markdown
- `$superpowers-project:companion-interface`: creates and refreshes a local HTML companion report for rich artifact review in the Codex in-app browser.
```

Update `docs/superpowers/PROJECT_CONTEXT.md` `Extension Skills` with:

```markdown
- `companion-interface`
```

- [ ] **Step 6: Wire the companion contract test into full validation**

Modify `scripts/validate.sh` after the `Advanced user input policy contract` check:

```bash
$results.Add((Invoke-Step "Companion interface contract" {
    & (Join-Path $PSScriptRoot "test-companion-interface.sh") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Companion interface contract failed" }
}))
```

- [ ] **Step 7: Run the focused test and verify it passes**

Run:

```bash
./scripts/test-companion-interface.sh
```

Expected: JSON output has `"ok": true`.

- [ ] **Step 8: Commit the companion skill shell**

Run:

```bash
git add .codex-plugin\plugin.json README.md docs/superpowers\PROJECT_CONTEXT.md scripts/test-companion-interface.sh scripts/validate.sh skills/companion-interface\SKILL.md skills/companion-interface\agents\openai.yaml
git commit -m "Add companion interface skill contract"
```

Expected: commit succeeds.

## Task 2: Add Report Session Schema And Event Scripts

**Use Cases:**
- A workflow creates a report session before adding rich evidence.
- An agent appends artifact, summary, command-result, and decision events without hand-editing JSON.
- Report generation refuses paths outside the repo report root.
- A failed command can be recorded as evidence without pretending it passed.

**Files:**
- Create: `skills/companion-interface/scripts/lib/companion-report.sh`
- Create: `skills/companion-interface/scripts/new-report-session.sh`
- Create: `skills/companion-interface/scripts/append-event.sh`
- Create: `skills/companion-interface/scripts/test-scenarios.sh`

- [ ] **Step 1: Write failing scenario tests for report sessions**

Create `skills/companion-interface/scripts/test-scenarios.sh` with scenarios that call the scripts and assert:

```bash
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../../..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

$sessionScript = Join-Path $RepoRoot "skills/companion-interface/scripts/new-report-session.sh"
$appendScript = Join-Path $RepoRoot "skills/companion-interface/scripts/append-event.sh"
$session = & $sessionScript -RepoRoot $RepoRoot -WorkflowName "brainstorm-spec" -Title "Fixture Report" | ConvertFrom-Json
Add-Check -Name "session creates manifest" -Ok (Test-Path -LiteralPath $session.manifest_path) -Reason "manifest missing"
Add-Check -Name "session creates events file" -Ok (Test-Path -LiteralPath $session.events_path) -Reason "events file missing"
Add-Check -Name "session stays under .superpowers reports" -Ok ($session.relative_report_root -like ".superpowers/reports/*") -Reason "wrong report root"

$event = & $appendScript -RepoRoot $RepoRoot -ReportRoot $session.relative_report_root -Type "summary_added" -Title "Fixture Summary" -Summary "Report evidence was added." | ConvertFrom-Json
Add-Check -Name "append event succeeds" -Ok ($event.ok -eq $true) -Reason "append failed"
Add-Check -Name "manifest event count increments" -Ok ($event.event_count -eq 2) -Reason "unexpected event count"

$failedAppend = & $appendScript -RepoRoot $RepoRoot -ReportRoot "../outside" -Type "summary_added" -Title "Bad" -Summary "Bad" 2>&1
Add-Check -Name "outside report root is rejected" -Ok ($LASTEXITCODE -ne 0 -and (($failedAppend | Out-String) -match "outside repo root|report root")) -Reason "outside root was accepted"

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "companion-interface-scenarios"; checks = $checks } | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
```

- [ ] **Step 2: Run the scenario tests and verify the expected failure**

Run:

```bash
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: command exits nonzero because session scripts do not exist yet.

- [ ] **Step 3: Create the companion report library**

Create `skills/companion-interface/scripts/lib/companion-report.sh` with these functions:

```bash
$ErrorActionPreference = "Stop"

function Resolve-CompanionRepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../../..")).Path
    }
    (Resolve-Path -LiteralPath $RepoRoot).Path
}

function ConvertTo-CompanionRelativePath {
    param([string]$RepoRoot, [string]$Path)
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "path is outside repo root: $candidate"
    }
    ([IO.Path]::GetRelativePath($root, $candidate) -replace "\\", "/")
}

function New-CompanionRunId {
    param([string]$WorkflowName)
    $safeWorkflow = ($WorkflowName.ToLowerInvariant() -replace "[^a-z0-9-]", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeWorkflow)) { throw "workflow name is required" }
    "$safeWorkflow-" + (Get-Date -Format "HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
}

function Get-CompanionReportRoot {
    param([string]$RepoRoot, [string]$RunId)
    $date = Get-Date -Format "yyyy-MM-dd"
    Join-Path $RepoRoot (Join-Path ".superpowers\reports" (Join-Path $date $RunId))
}

function Write-CompanionJson {
    param([string]$Path, [object]$Value)
    $json = $Value | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $Path -Encoding utf8NoBOM -Value $json
}
```

- [ ] **Step 4: Create the session script**

Create `skills/companion-interface/scripts/new-report-session.sh` with parameters:

```bash
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../../..")).Path,
    [Parameter(Mandatory = $true)][string]$WorkflowName,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$SourcePath = ""
)
```

The script should:

- resolve the repo root
- create a run id with `New-CompanionRunId`
- create `.superpowers/reports/<date>/<run-id>/artifacts`
- create a `run_started` event
- write `events.jsonl`
- write `manifest.json`
- return JSON with `ok`, `report_root`, `relative_report_root`, `manifest_path`, `events_path`, `index_path`, and `artifact_root`

- [ ] **Step 5: Create the append script**

Create `skills/companion-interface/scripts/append-event.sh` with parameters:

```bash
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../../..")).Path,
    [Parameter(Mandatory = $true)][string]$ReportRoot,
    [Parameter(Mandatory = $true)][ValidateSet("artifact_added", "artifact_changed", "markdown_rendered", "plot_added", "table_added", "command_result", "validation_result", "test_result", "file_inventory", "risk_added", "summary_added", "decision_needed", "decision_recorded", "cleanup_result", "run_completed")][string]$Type,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Summary = "",
    [string]$ArtifactPath = "",
    [string]$PayloadJson = "{}"
)
```

The script should:

- reject `ReportRoot` outside `.superpowers/reports`
- parse `PayloadJson` with `ConvertFrom-Json`
- append one compact JSON line to `events.jsonl`
- update `manifest.json` event count and latest summary
- return JSON with `ok`, `event_id`, `event_count`, and `manifest_path`

- [ ] **Step 6: Run scenario tests and verify they pass**

Run:

```bash
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: JSON output has `"ok": true`.

- [ ] **Step 7: Commit report session helpers**

Run:

```bash
git add skills/companion-interface/scripts
git commit -m "Add companion report session helpers"
```

Expected: commit succeeds.

## Task 3: Add Static HTML Renderer

**Use Cases:**
- User opens one local HTML file in the Codex in-app browser and sees current run evidence.
- A workflow regenerates the report after each event without starting a localhost server.
- Long evidence sections are collapsible so the report is readable.
- The report has no external network dependency for its default layout.

**Files:**
- Create: `skills/companion-interface/scripts/render-report.sh`
- Create: `skills/companion-interface/templates/report-template.html`
- Create: `skills/companion-interface/templates/report.css`
- Create: `skills/companion-interface/templates/report.js`
- Modify: `skills/companion-interface/scripts/test-scenarios.sh`

- [ ] **Step 1: Extend scenario tests for static rendering**

Add a scenario to `skills/companion-interface/scripts/test-scenarios.sh` that:

- creates a report session
- appends `summary_added`, `validation_result`, and `decision_needed` events
- runs `render-report.sh`
- asserts `index.html` exists
- asserts the HTML contains `Run Overview`, `Workflow Timeline`, `Artifact Browser`, `Evidence Feed`, `Decision Dock`, and `Interpretation Summary`
- asserts the HTML does not contain `https://` or `http://`

Run:

```bash
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: command exits nonzero because `render-report.sh` and templates do not exist yet.

- [ ] **Step 2: Create the static HTML template**

Create `skills/companion-interface/templates/report-template.html` with token markers:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{TITLE}}</title>
  <style>{{CSS}}</style>
</head>
<body>
  <header class="topbar">
    <div>
      <p class="eyebrow">Superpowers Project Companion</p>
      <h1>{{TITLE}}</h1>
    </div>
    <p class="status">{{STATUS}}</p>
  </header>
  <main>
    {{BODY}}
  </main>
  <script id="companion-manifest" type="application/json">{{MANIFEST_JSON}}</script>
  <script>{{JS}}</script>
</body>
</html>
```

- [ ] **Step 3: Create report CSS**

Create `skills/companion-interface/templates/report.css` with stable layout classes:

```css
:root {
  color-scheme: light dark;
  --bg: #f8fafc;
  --text: #111827;
  --muted: #4b5563;
  --panel: #ffffff;
  --border: #cbd5e1;
  --accent: #0f766e;
  --fail: #b91c1c;
  --pass: #047857;
  --warn: #a16207;
}
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: Arial, sans-serif;
}
.topbar {
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: center;
  padding: 16px 24px;
  border-bottom: 1px solid var(--border);
  background: var(--panel);
}
main {
  display: grid;
  grid-template-columns: minmax(220px, 280px) minmax(0, 1fr);
  gap: 20px;
  padding: 20px;
}
section, nav {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 16px;
}
details {
  border-top: 1px solid var(--border);
  padding: 10px 0;
}
pre {
  overflow: auto;
  padding: 12px;
  background: #111827;
  color: #e5e7eb;
}
```

- [ ] **Step 4: Create report JavaScript**

Create `skills/companion-interface/templates/report.js`:

```javascript
document.querySelectorAll("button[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const text = button.getAttribute("data-copy") || "";
    await navigator.clipboard.writeText(text);
    button.textContent = "Copied";
    window.setTimeout(() => { button.textContent = "Copy"; }, 1200);
  });
});
```

- [ ] **Step 5: Create the renderer script**

Create `skills/companion-interface/scripts/render-report.sh` with parameters:

```bash
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../../..")).Path,
    [Parameter(Mandatory = $true)][string]$ReportRoot
)
```

The script should:

- load `manifest.json`
- read all `events.jsonl` lines
- group events into overview, timeline, artifacts, evidence, decisions, and summary
- escape plain-text fields with `[System.Net.WebUtility]::HtmlEncode`
- inline `report.css` and `report.js`
- embed manifest JSON in the page
- write `index.html`
- return JSON with `ok`, `index_path`, `event_count`, and `section_count`

- [ ] **Step 6: Run render scenarios and verify they pass**

Run:

```bash
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: JSON output has `"ok": true`, and the generated HTML contains all required section names with no `http://` or `https://`.

- [ ] **Step 7: Commit the static renderer**

Run:

```bash
git add skills/companion-interface/scripts/render-report.sh skills/companion-interface\templates skills/companion-interface/scripts/test-scenarios.sh
git commit -m "Render companion reports as static HTML"
```

Expected: commit succeeds.

## Task 4: Add Markdown, Plot, Table, And Validation Rendering

**Use Cases:**
- User reviews a rendered spec or plan without reading raw Markdown in chat.
- User sees math from Markdown rendered through Pandoc MathML.
- User sees plots and tables beside the validation evidence that produced them.
- User sees command and validation receipts with exact exit state and output excerpt.

**Files:**
- Modify: `skills/companion-interface/scripts/lib/companion-report.sh`
- Modify: `skills/companion-interface/scripts/append-event.sh`
- Modify: `skills/companion-interface/scripts/render-report.sh`
- Modify: `skills/companion-interface/scripts/test-scenarios.sh`

- [ ] **Step 1: Extend tests with Markdown, table, plot, and validation fixtures**

In `skills/companion-interface/scripts/test-scenarios.sh`, create fixture files under the generated report `artifacts/` directory:

```bash
$fixtureMarkdown = Join-Path $session.artifact_root "fixture-spec.md"
Set-Content -LiteralPath $fixtureMarkdown -Encoding utf8NoBOM -Value @'
---
title: Fixture Spec
---

# Fixture Spec

Inline math: $x^2 + y^2 = z^2$.

| item | status |
| --- | --- |
| markdown | pass |

```bash
Write-Output "hello"
```
'@

$fixtureCsv = Join-Path $session.artifact_root "results.csv"
Set-Content -LiteralPath $fixtureCsv -Encoding utf8NoBOM -Value @'
name,status,count
unit,pass,3
integration,fail,1
'@

$fixtureSvg = Join-Path $session.artifact_root "plot.svg"
Set-Content -LiteralPath $fixtureSvg -Encoding utf8NoBOM -Value '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="80"><rect width="200" height="80" fill="#f8fafc"/><circle cx="40" cy="40" r="24" fill="#0f766e"/></svg>'
```

Append events for `markdown_rendered`, `table_added`, `plot_added`, and `validation_result`, then render the report and assert:

- frontmatter appears in a metadata block
- rendered body contains `Fixture Spec`
- rendered math output contains MathML markup
- CSV table rows appear
- SVG plot path appears
- validation command and exit code appear

- [ ] **Step 2: Run the extended tests and verify the expected failure**

Run:

```bash
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: command exits nonzero because Markdown, table, plot, and validation renderers do not exist yet.

- [ ] **Step 3: Add Markdown conversion helper**

Add `Convert-CompanionMarkdownToHtml` to `skills/companion-interface/scripts/lib/companion-report.sh`:

```bash
function Convert-CompanionMarkdownToHtml {
    param(
        [Parameter(Mandatory = $true)][string]$MarkdownPath
    )
    $pandoc = Get-Command pandoc -ErrorAction Stop
    $output = & $pandoc.Source --from gfm+yaml_metadata_block+tex_math_dollars --to html5 --mathml --highlight-style=tango $MarkdownPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "pandoc markdown render failed for $MarkdownPath`: $($output | Out-String)"
    }
    ($output | Out-String)
}
```

- [ ] **Step 4: Add table and validation render helpers**

Add helpers that:

- read CSV with `Import-Csv`
- read JSON arrays with `ConvertFrom-Json`
- render status cells with `pass`, `fail`, and `warn` classes
- render command receipts from payload fields `command`, `working_directory`, `exit_code`, `status`, and `excerpt`

Use function names:

```bash
Convert-CompanionTableToHtml
Convert-CompanionValidationToHtml
Convert-CompanionArtifactPathToHtml
```

- [ ] **Step 5: Wire artifact rendering into the static renderer**

Update `skills/companion-interface/scripts/render-report.sh` so:

- `markdown_rendered` events call `Convert-CompanionMarkdownToHtml`
- `table_added` events call `Convert-CompanionTableToHtml`
- `plot_added` events render an `<img>` for `.svg`, `.png`, `.jpg`, and `.jpeg`
- `validation_result`, `test_result`, and `command_result` events call `Convert-CompanionValidationToHtml`

- [ ] **Step 6: Run extended companion scenarios**

Run:

```bash
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: JSON output has `"ok": true`, and the generated report includes frontmatter, MathML markup, CSV rows, SVG image markup, validation command text, and exit code text.

- [ ] **Step 7: Commit rich artifact rendering**

Run:

```bash
git add skills/companion-interface/scripts
git commit -m "Render companion markdown tables plots and receipts"
```

Expected: commit succeeds.

## Task 5: Add Opt-In Integration To Brainstorm And Write Plan

**Use Cases:**
- User asks `brainstorm-spec` to use the companion and receives a report with design alternatives, decisions, and saved spec preview.
- User asks `write-plan` to use the companion and receives a report with task list, use cases, proof oracle, and validation receipts.
- Existing native continuation gates remain authoritative after companion reporting.
- Companion output reduces chat artifact dumping without hiding required evidence.

**Files:**
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `scripts/test-companion-interface.sh`

- [ ] **Step 1: Extend contract tests for opt-in integration**

Update `scripts/test-companion-interface.sh` to assert:

```bash
Assert-Contains -Path "skills/brainstorm-spec\SKILL.md" -Needle "companion-interface" -Name "brainstorm mentions companion"
Assert-Contains -Path "skills/brainstorm-spec\SKILL.md" -Needle "native approval" -Name "brainstorm preserves native approval"
Assert-Contains -Path "skills/write-plan\SKILL.md" -Needle "companion-interface" -Name "write-plan mentions companion"
Assert-Contains -Path "skills/write-plan\SKILL.md" -Needle "native continuation" -Name "write-plan preserves native continuation"
Assert-Contains -Path "skills/brainstorm-spec\agents\openai.yaml" -Needle "companion-interface" -Name "brainstorm metadata mentions companion"
Assert-Contains -Path "skills/write-plan\agents\openai.yaml" -Needle "companion-interface" -Name "write-plan metadata mentions companion"
```

- [ ] **Step 2: Run the contract test and verify the expected failure**

Run:

```bash
./scripts/test-companion-interface.sh
```

Expected: command exits nonzero because `brainstorm-spec` and `write-plan` do not yet mention companion reporting.

- [ ] **Step 3: Update brainstorm-spec opt-in guidance**

Add a `## Companion Interface Opt-In` section to `skills/brainstorm-spec/SKILL.md`:

```markdown
## Companion Interface Opt-In

When the user asks for the HTML companion, or when rendered specs/design alternatives would be too large for chat, use `$superpowers-project:companion-interface` to create or refresh a local report. Include project context evidence, design alternatives, user decisions, open questions, saved spec path, and recommended next route.

The companion is an evidence surface only. Native approval, user review, and continuation decisions still happen through chat or `request_user_input`.
```

Update `skills/brainstorm-spec/agents/openai.yaml` summary text to mention opt-in companion reporting for large design artifacts.

- [ ] **Step 4: Update write-plan opt-in guidance**

Add a `## Companion Interface Opt-In` section to `skills/write-plan/SKILL.md`:

```markdown
## Companion Interface Opt-In

When the user asks for the HTML companion, or when the saved plan is too large for chat rendering, use `$superpowers-project:companion-interface` to create or refresh a local report. Include source spec linkage, task list, Task # Use Cases blocks, proof oracle, test-complete definition, plan validation receipt, and recommended next route.

The companion is an evidence surface only. Native continuation, issue creation, implementation, push, publish, merge, and final Done decisions still happen through chat or `request_user_input`.
```

Update `skills/write-plan/agents/openai.yaml` summary text to mention opt-in companion reporting for long implementation plans.

- [ ] **Step 5: Run companion and skill scenario tests**

Run:

```bash
./scripts/test-companion-interface.sh
./skills/brainstorm-spec/scripts/test-scenarios.sh
./skills/write-plan/scripts/test-scenarios.sh
```

Expected: all three commands exit `0`.

- [ ] **Step 6: Commit opt-in integration**

Run:

```bash
git add scripts/test-companion-interface.sh skills/brainstorm-spec skills/write-plan
git commit -m "Add opt-in companion reporting to planning workflows"
```

Expected: commit succeeds.

## Task 6: Validate, Sync, And Prove Cleanup

**Use Cases:**
- The plugin source validates after the companion skill and renderer are added.
- Live sync validation proves the deployed copy can receive the companion feature.
- Generated report sessions do not leave long-running processes behind.
- The saved plan remains valid under the Task # Use Cases gate.

**Files:**
- Modify: no additional source files expected unless validation reports a specific broken contract.

- [ ] **Step 1: Validate this saved plan's task use cases**

Run:

```bash
./scripts/validate-plan-task-use-cases.sh -PlanPath docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md
```

Expected: JSON output has `"ok": true` and `task_count` is `6`.

- [ ] **Step 2: Run focused companion validation**

Run:

```bash
./scripts/test-companion-interface.sh
./skills/companion-interface/scripts/test-scenarios.sh
```

Expected: both commands exit `0` and emit JSON with `"ok": true`.

- [ ] **Step 3: Run full repo validation**

Run:

```bash
./scripts/validate.sh
```

Expected: final JSON output has `"ok": true`.

- [ ] **Step 4: Run live sync validation**

Run:

```bash
./scripts/sync-live.sh --validate
```

Expected: command exits `0` and reports source/live validation success.

- [ ] **Step 5: Run cleanup proof**

Run:

```bash
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Expected: output reports no matching leftover Codex processes for this repo.

- [ ] **Step 6: Commit validation wiring if required**

If Task 6 exposed validation-only source edits, run:

```bash
git add scripts skills README.md docs/superpowers .codex-plugin
git commit -m "Validate companion interface workflow"
```

Expected: commit succeeds only when there are validation-related source edits to record. If no source files changed during Task 6, record the validation output in the handoff instead of creating an empty commit.

## Risk And Dependency Notes

- Pandoc is required for v1 Markdown rendering. The renderer must fail loudly when `pandoc` cannot be resolved.
- Static regeneration keeps process cleanup simple, but it means "live" updates happen through explicit report regeneration and browser refresh rather than a server push channel.
- `.superpowers/reports` must be treated as generated runtime output unless a future workflow explicitly marks a report for retention.
- `companion-interface` is opt-in for the first slice so existing governed skills keep their current artifact review behavior until the companion proves stable.
- Native approval boundaries must be protected in tests because HTML reports can look like a control surface even though they are only evidence.

## Execution Notes

- Use `superpowers:test-driven-development` for each implementation task.
- Use `superpowers:verification-before-completion` before reporting the feature complete.
- Use `scripts/sync-live.sh --validate` only after source validation passes.
- Run the cleanup hook before final closeout.

## Plan Self-Review

- Spec coverage: the plan implements the recommended first slice from the source spec: skill plus helpers, static report generation, manifest/events, Markdown rendering through Pandoc, plots, tables, validation receipts, decision context, and opt-in integration with `brainstorm-spec` and `write-plan`.
- Acceptance coverage: every acceptance criterion maps to Tasks 1 through 6.
- Placeholder scan: no placeholder instructions remain.
- Type and name consistency: report terms use `manifest.json`, `events.jsonl`, `index.html`, `ReportRoot`, `WorkflowName`, `companion-interface`, and `.superpowers/reports` consistently.
- Task # Use Cases: every numbered task includes a non-empty `**Use Cases:**` block before files and steps.
