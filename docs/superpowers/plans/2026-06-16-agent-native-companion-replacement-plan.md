# Agent-Native Companion Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Superpowers Project `companion-interface` static HTML report contract with repo-owned BuilderIO/Agent-Native visual-plan MDX artifacts.

**Architecture:** Migrate the companion route in place: tests first assert Agent-Native MDX wording and stale HTML-report wording removal, then source skills/docs are rewritten, HTML renderer files are deleted, and a local Agent-Native preview fixture proves the new review surface. Canonical Superpowers implementation plans remain under `docs/superpowers/plans`; Agent-Native review artifacts live under `plans/<slug>/plan.mdx`.

**Tech Stack:** PowerShell 7, Markdown, MDX, Agent-Native CLI, existing Superpowers Project validators.

---

## Source Spec

- `docs/superpowers/specs/2026-06-16-agent-native-visual-plan-companion-design.md`
- Review artifact: `plans/agent-native-companion-replacement/plan.mdx`
- Auto Mode authorization ledger: `.superpowers/runs/20260616-232604-agent-native-companion-spec/auto-mode-authorization.json`

## User Decisions Recorded

- Use BuilderIO/Agent-Native visual-plan MDX artifacts instead of the just-created HTML companion direction.
- Keep native Codex chat and `request_user_input` as approval and continuation authority.
- Use local-files privacy mode when hosted Plan MCP tools are not visible in the active session.
- Do not edit deployed plugin copies directly; edit source, validate, then run `scripts/sync-live.ps1 -Validate`.
- Bounded Auto Mode is authorized for this saved spec after the `project_auto_mode_authorization` gate.

## Test-Complete Definition

This plan is test complete when:

- `scripts/test-companion-interface.ps1` passes and rejects active HTML companion wording.
- `scripts/test-agent-native-companion-preview.ps1` passes and creates a local Agent-Native preview from a fixture `plans/<slug>/plan.mdx`.
- `scripts/validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-16-agent-native-companion-replacement-plan.md` passes.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` passes.
- The cleanup hook reports no matching leftover Codex processes for this repo.

No numerical engineering metrics are required. This is workflow-contract and artifact-routing work; pass/fail is defined by exact source text, file removal, local preview creation, validator results, and cleanup proof.

## Acceptance Criteria

- `skills/companion-interface/SKILL.md` describes Agent-Native visual-plan MDX artifacts, not local HTML reports.
- `skills/companion-interface/agents/openai.yaml`, README, plugin prompt, `docs/superpowers/PROJECT_CONTEXT.md`, `skills/brainstorm-spec`, and `skills/write-plan` use Agent-Native visual-plan wording.
- HTML report-only files under `skills/companion-interface/scripts` and `skills/companion-interface/templates` are removed.
- Active source guidance no longer requires `.superpowers/reports`, `manifest.json`, `events.jsonl`, or generated `index.html` for the companion route.
- A focused preview test creates a temp `plans/fixture-agent-native-companion/plan.mdx`, runs Agent-Native local preview, and confirms a preview file or URL is produced.
- `.gitignore` ignores generated `plans/**/preview.html`.
- Full validation and live sync validation pass.

## Non-Goals

- Do not repair hosted Agent-Native authentication.
- Do not create an HTML wrapper around MDX plans.
- Do not replace canonical Superpowers specs, plans, issue mirrors, or milestone pages.
- Do not make visual plans record approval, push, publish, merge, live sync, GitHub mutation, or final Done.
- Do not create GitHub issues for this migration unless a later route explicitly chooses issue decomposition.

## File Map

- Modify: `scripts/test-companion-interface.ps1`
- Create: `scripts/test-agent-native-companion-preview.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `skills/companion-interface/SKILL.md`
- Modify: `skills/companion-interface/agents/openai.yaml`
- Delete: `skills/companion-interface/scripts/append-event.ps1`
- Delete: `skills/companion-interface/scripts/new-report-session.ps1`
- Delete: `skills/companion-interface/scripts/render-report.ps1`
- Delete: `skills/companion-interface/scripts/test-scenarios.ps1`
- Delete: `skills/companion-interface/scripts/lib/companion-report.ps1`
- Delete: `skills/companion-interface/templates/report-template.html`
- Delete: `skills/companion-interface/templates/report.css`
- Delete: `skills/companion-interface/templates/report.js`
- Delete: `scripts/serve-companion-report.ps1`
- Modify: `.github/workflows/validate.yml`
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`
- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`
- Modify: `.gitignore`
- Test: `scripts/test-companion-interface.ps1`
- Test: `scripts/test-agent-native-companion-preview.ps1`
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1 -Validate`

## Task 1: Rewrite The Companion Contract Test

**Use Cases:**
- A future agent cannot leave active `companion-interface` guidance pointing to static HTML reports.
- Plugin startup prompt and README route users to Agent-Native MDX review artifacts.
- Native approval boundaries remain explicit after the rich review surface changes.
- Stale report-session vocabulary fails focused validation before full repo validation.

**Files:**
- Modify: `scripts/test-companion-interface.ps1`

- [ ] **Step 1: Extend the test helpers**

Add a negative assertion helper beside `Assert-Contains`:

```powershell
function Assert-NotContains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    Add-Check -Name $Name -Ok (-not $text.Contains($Needle)) -Reason "$Path still contains $Needle"
}
```

- [ ] **Step 2: Replace HTML-positive assertions with Agent-Native assertions**

Replace assertions for "local HTML companion report" with checks equivalent to:

```powershell
Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "Agent-Native visual-plan MDX" -Name "skill defines Agent-Native MDX surface"
Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "plans/<slug>/plan.mdx" -Name "skill defines local plan source"
Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "request_user_input" -Name "skill preserves native approval"
Assert-Contains -Path "skills\companion-interface\agents\openai.yaml" -Needle "Agent-Native" -Name "metadata names Agent-Native"
Assert-Contains -Path ".codex-plugin\plugin.json" -Needle "Agent-Native visual-plan MDX" -Name "plugin prompt names MDX companion"
Assert-Contains -Path "README.md" -Needle "Agent-Native visual-plan MDX" -Name "README names MDX companion"
Assert-Contains -Path "docs\superpowers\PROJECT_CONTEXT.md" -Needle "companion-interface" -Name "project context lists companion"
Assert-Contains -Path "skills\brainstorm-spec\SKILL.md" -Needle "Agent-Native visual-plan" -Name "brainstorm uses visual-plan wording"
Assert-Contains -Path "skills\write-plan\SKILL.md" -Needle "Agent-Native visual-plan" -Name "write-plan uses visual-plan wording"
```

- [ ] **Step 3: Add stale wording rejection**

Add negative checks against active route files:

```powershell
$activeFiles = @(
    "skills\companion-interface\SKILL.md",
    "skills\companion-interface\agents\openai.yaml",
    ".codex-plugin\plugin.json",
    "README.md",
    "skills\brainstorm-spec\SKILL.md",
    "skills\write-plan\SKILL.md"
)
foreach ($file in $activeFiles) {
    Assert-NotContains -Path $file -Needle "local HTML companion report" -Name "$file omits HTML companion report"
    Assert-NotContains -Path $file -Needle ".superpowers/reports" -Name "$file omits report sessions"
    Assert-NotContains -Path $file -Needle "manifest.json" -Name "$file omits manifest contract"
    Assert-NotContains -Path $file -Needle "events.jsonl" -Name "$file omits event log contract"
    Assert-NotContains -Path $file -Needle "generated `index.html`" -Name "$file omits generated index contract"
}
```

- [ ] **Step 4: Run the focused test and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1
```

Expected: the command exits nonzero because the source still contains HTML companion wording.

- [ ] **Step 5: Commit checkpoint after the red test if working interactively**

Do not commit in Auto Mode until the matching green implementation is present. Record the failing output in the implementation notes instead.

## Task 2: Rewrite Companion Skill, Metadata, And Route Docs

**Use Cases:**
- A user invoking `$superpowers-project:companion-interface` gets a local Agent-Native MDX review artifact.
- Hosted Plan MCP absence routes directly to local-files mode without repeated auth attempts.
- The route remains an evidence surface and cannot record approval or merge authority.
- Startup prompt and README match the new companion behavior.

**Files:**
- Modify: `skills/companion-interface/SKILL.md`
- Modify: `skills/companion-interface/agents/openai.yaml`
- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `docs/superpowers/PROJECT_CONTEXT.md`

- [ ] **Step 1: Rewrite `skills/companion-interface/SKILL.md`**

Replace the body with a contract shaped like:

```markdown
---
name: companion-interface
description: Use when a Superpowers Project workflow should create or update a repo-owned Agent-Native visual-plan MDX artifact for rich review.
---

# Companion Interface

Companion Interface is the Superpowers Project rich review channel. It creates or refreshes repo-owned BuilderIO/Agent-Native visual-plan artifacts.

Use this skill when a governed workflow produces specs, plans, issue evidence, validation receipts, screenshots, diagrams, plots, tables, or long summaries that need structured review outside chat.

## Approval Boundary

The companion must not record approval, push, publish, merge, live sync, GitHub mutation, or final Done. Native Codex chat and `request_user_input` remain the decision authority.

## Visual-Plan Source Model

Write local review artifacts under `plans/<slug>/`.

Required:
- `plans/<slug>/plan.mdx`

Optional:
- `plans/<slug>/canvas.mdx` when static visual review is useful.
- `plans/<slug>/prototype.mdx` when interaction review is useful.
- `plans/<slug>/.plan-state.json` when Agent-Native local tooling writes editor state.

Canonical Superpowers specs, implementation plans, issue mirrors, and milestone pages remain under `docs/superpowers/`.

## Tooling

Before authoring MDX, fetch the Agent-Native block catalog with an available schema-only tool or:

```powershell
npx @agent-native/core@latest plan blocks --out <temporary-catalog-path>
```

After writing or revising the folder, run:

```powershell
npx @agent-native/core@latest plan local preview --dir plans/<slug> --kind plan --open
```

Report the `plan.mdx` path and returned preview URL or exact failure.

## Hosted Plan Tools

If hosted Plan MCP tools are visible in the active session, they may be used for hosted creation or publishing when the workflow permits it. When tools are not visible, use local-files mode and do not repeat failed hosted authentication polling.
```

- [ ] **Step 2: Rewrite `agents/openai.yaml`**

Use wording equivalent to:

```yaml
name: companion-interface
description: Create or refresh Superpowers Project Agent-Native visual-plan MDX artifacts while keeping native Codex chat and request_user_input as the approval channel.
summary: |
  Use $superpowers-project:companion-interface for rich review artifacts under plans/<slug>/plan.mdx.
  The route uses BuilderIO/Agent-Native local-files mode when hosted Plan MCP tools are unavailable.
  It never records approval, push, publish, merge, live sync, GitHub mutation, or final Done.
tools:
  - shell
```

- [ ] **Step 3: Update README and plugin prompt**

Change the current skill bullet to:

```markdown
- `$superpowers-project:companion-interface`: creates and refreshes repo-owned Agent-Native visual-plan MDX artifacts for rich review while native Codex input remains the approval channel.
```

Change `.codex-plugin/plugin.json` default prompt line to:

```json
"Use $superpowers-project:companion-interface to create or refresh repo-owned Agent-Native visual-plan MDX artifacts for rich review while native Codex input remains the approval channel."
```

- [ ] **Step 4: Update project context**

Keep `companion-interface` in the Extension Skills list and add one sentence under `Artifact Model`:

```markdown
- Agent-Native review artifacts: `plans/<slug>/plan.mdx` with optional `canvas.mdx` or `prototype.mdx`; these are rich review surfaces, not replacements for canonical Superpowers specs, plans, or issue mirrors.
```

- [ ] **Step 5: Run the focused companion contract**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1
```

Expected: companion skill, metadata, README, plugin prompt, and project context checks pass. Brainstorm/write-plan checks may still fail until Task 3.

## Task 3: Update Integrated Workflow Guidance

**Use Cases:**
- `brainstorm-spec` sends large design artifacts to visual-plan MDX instead of HTML reports.
- `write-plan` sends large implementation review artifacts to visual-plan MDX instead of HTML reports.
- Existing native continuation gates remain authoritative after rich artifact review.
- Agents do not interpret visual-plan review as approval.

**Files:**
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/agents/openai.yaml`

- [ ] **Step 1: Replace brainstorm companion guidance**

Replace the current `## Companion Interface Opt-In` section in `skills/brainstorm-spec/SKILL.md` with:

```markdown
## Companion Interface Opt-In

When the user asks for the companion, or when rendered specs, design alternatives, project-context evidence, or saved spec previews would be too large for chat, use `$superpowers-project:companion-interface` to create or refresh a repo-owned Agent-Native visual-plan MDX artifact. Include project context evidence, design alternatives, user decisions, open questions, saved spec path, and recommended next route.

The companion is an evidence surface only. Native approval, user review, and continuation decisions still happen through chat or `request_user_input`.
```

- [ ] **Step 2: Replace write-plan companion guidance**

Replace the current `## Companion Interface Opt-In` section in `skills/write-plan/SKILL.md` with:

```markdown
## Companion Interface Opt-In

When the user asks for the companion, or when the saved implementation plan is too large for chat rendering, use `$superpowers-project:companion-interface` to create or refresh a repo-owned Agent-Native visual-plan MDX artifact. Include source spec linkage, task list, Task # Use Cases blocks, proof oracle, test-complete definition, plan validation receipt, and recommended next route.

The companion is an evidence surface only. Native continuation, issue creation, implementation, push, publish, merge, and final Done decisions still happen through chat or `request_user_input`.
```

- [ ] **Step 3: Update skill metadata summaries**

In `skills/brainstorm-spec/agents/openai.yaml`, replace HTML companion wording with:

```yaml
Use $superpowers-project:companion-interface on opt-in runs or when large design artifacts should be reviewed as Agent-Native visual-plan MDX under plans/<slug>/plan.mdx.
```

In `skills/write-plan/agents/openai.yaml`, replace HTML companion wording with:

```yaml
Use $superpowers-project:companion-interface on opt-in runs or when long implementation plans should be reviewed as Agent-Native visual-plan MDX under plans/<slug>/plan.mdx.
```

- [ ] **Step 4: Run the focused companion contract**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1
```

Expected: JSON output has `"ok": true`.

## Task 4: Remove HTML Renderer Assets

**Use Cases:**
- The source tree no longer carries a second report renderer that agents can accidentally use.
- Validation cannot pass because of stale HTML scenario tests.
- Cleanup no longer needs to account for generated report sessions from this companion route.
- Future implementation work has one review artifact model: Agent-Native MDX.

**Files:**
- Delete: `skills/companion-interface/scripts/append-event.ps1`
- Delete: `skills/companion-interface/scripts/new-report-session.ps1`
- Delete: `skills/companion-interface/scripts/render-report.ps1`
- Delete: `skills/companion-interface/scripts/test-scenarios.ps1`
- Delete: `skills/companion-interface/scripts/lib/companion-report.ps1`
- Delete: `skills/companion-interface/templates/report-template.html`
- Delete: `skills/companion-interface/templates/report.css`
- Delete: `skills/companion-interface/templates/report.js`

- [ ] **Step 1: Delete report-session scripts and templates**

Use `Remove-Item` or `apply_patch` deletion for the exact files listed above. Verify no empty `scripts/lib` or `templates` directories remain.

- [ ] **Step 2: Verify stale file removal**

Run:

```powershell
rg -n "new-report-session|append-event|render-report|manifest.json|events.jsonl|report-template|\\.superpowers/reports" skills/companion-interface README.md .codex-plugin/plugin.json skills/brainstorm-spec skills/write-plan
```

Expected: no matches in active guidance. Matches in historical specs or plans are acceptable only when the search is explicitly scoped to historical docs.

- [ ] **Step 3: Run parser validation for the skill**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\companion-interface\scripts\test-scenarios.ps1
```

Expected: this command should no longer be run because the script is deleted. Full validation should skip absent skill scenario scripts.

- [ ] **Step 4: Commit checkpoint after green focused tests if working interactively**

Commit message:

```powershell
git add skills\companion-interface scripts\test-companion-interface.ps1 README.md .codex-plugin\plugin.json docs\superpowers\PROJECT_CONTEXT.md skills\brainstorm-spec skills\write-plan
git commit -m "Replace HTML companion contract with Agent-Native MDX"
```

In bounded Auto Mode, continue to Task 5 before committing if validation wiring still needs source edits.

## Task 5: Add Local Agent-Native Preview Validation

**Use Cases:**
- The new companion path proves a local MDX plan can be previewed without hosted Plan MCP tools.
- Validation avoids dirtying the real repo with generated preview files.
- Agent-Native CLI failure is reported as a direct validation failure.
- Generated `preview.html` files are ignored in repo-owned visual-plan folders.
- CI no longer installs Pandoc solely for the retired HTML Markdown renderer.

**Files:**
- Create: `scripts/test-agent-native-companion-preview.ps1`
- Modify: `scripts/validate.ps1`
- Modify: `.gitignore`
- Modify: `.github/workflows/validate.yml`

- [ ] **Step 1: Create the preview test script**

Create `scripts/test-agent-native-companion-preview.ps1`:

```powershell
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

try {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("agent-native-companion-" + [guid]::NewGuid().ToString("N"))
    $planDir = Join-Path $tempRoot "plans\fixture-agent-native-companion"
    New-Item -ItemType Directory -Path $planDir -Force | Out-Null
    $planPath = Join-Path $planDir "plan.mdx"
    Set-Content -LiteralPath $planPath -Encoding utf8NoBOM -Value @'
# Fixture Agent-Native Companion Plan

<Callout id="fixture-decision" tone="decision">

This fixture proves local Agent-Native visual-plan preview works from repo-owned MDX shape.

</Callout>

## Verification

- Native approval remains outside the visual plan.
- The source file is `plans/<slug>/plan.mdx`.
'@

    $raw = & npx -y @agent-native/core@latest plan local preview --dir $planDir --kind plan 2>&1
    $text = ($raw | Out-String).Trim()
    Add-Check -Name "preview command exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $text
    $json = $text | ConvertFrom-Json
    Add-Check -Name "preview reports ok" -Ok ($json.ok -eq $true) -Reason $text
    Add-Check -Name "preview output exists" -Ok (Test-Path -LiteralPath $json.out -PathType Leaf) -Reason "preview output missing"
    Add-Check -Name "preview includes plan source" -Ok (@($json.files) -contains "plan.mdx") -Reason "plan.mdx was not reported"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "agent-native-companion-preview"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "agent-native-companion-preview"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
```

- [ ] **Step 2: Wire the preview test into full validation**

In `scripts/validate.ps1`, add an `Invoke-Step` after the companion interface contract:

```powershell
$results.Add((Invoke-Step "Agent-Native companion preview" {
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-agent-native-companion-preview.ps1") | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Agent-Native companion preview failed" }
}))
```

- [ ] **Step 3: Keep generated plan previews ignored**

Ensure `.gitignore` contains:

```gitignore
plans/**/preview.html
```

- [ ] **Step 4: Remove retired CI dependency**

Remove these lines from `.github/workflows/validate.yml`:

```yaml
choco install pandoc -y --no-progress
pandoc --version
```

- [ ] **Step 5: Run focused validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-agent-native-companion-preview.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1
```

Expected: both commands emit JSON with `"ok": true`.

## Task 6: Validate, Sync, And Prepare Merge-Ready Proof

**Use Cases:**
- The saved implementation plan itself passes the Task # Use Cases gate.
- Full source validation proves the plugin source is internally consistent.
- Live sync validation proves deployed copies can receive the replacement.
- Cleanup proof shows the Agent-Native preview test and validation suite left no repo-owned processes behind.

**Files:**
- Modify: no additional source files expected unless validation reports an exact broken contract.

- [ ] **Step 1: Validate this implementation plan**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-16-agent-native-companion-replacement-plan.md
```

Expected: JSON output has `"ok": true` and `task_count` is `6`.

- [ ] **Step 2: Run full validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: final JSON output has `"ok": true`; checks include `Companion interface contract` and `Agent-Native companion preview`.

- [ ] **Step 3: Run live sync validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

Expected: command exits `0`, deploys source skills to the live plugin root, and refreshes matching local plugin cache candidates.

- [ ] **Step 4: Run cleanup proof**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: output reports no matching leftover Codex processes under this repo.

- [ ] **Step 5: Commit the completed migration**

Run:

```powershell
git add .gitignore .codex-plugin\plugin.json README.md docs\superpowers\PROJECT_CONTEXT.md scripts skills docs\superpowers\specs\2026-06-16-agent-native-visual-plan-companion-design.md docs\superpowers\plans\2026-06-16-agent-native-companion-replacement-plan.md plans\agent-native-companion-replacement\plan.mdx
git commit -m "Replace companion interface with Agent-Native MDX"
```

Expected: commit succeeds after validation and cleanup proof.

## Risk And Dependency Notes

- Agent-Native CLI availability is now part of the preview proof. If `npx @agent-native/core@latest plan local preview` fails, stop and report the command output.
- The `plans/<slug>/` root is for Agent-Native review artifacts. Do not move canonical Superpowers implementation plans out of `docs/superpowers/plans/`.
- Deleting the HTML scripts is intentional because the route is changing to a single MDX review artifact model.
- Feature/workflow implementation should use `superpowers:test-driven-development`.
- Before claiming completion, use `superpowers:verification-before-completion`.

## Plan Self-Review

- Spec coverage: the tasks cover test rewrite, skill/doc rewrite, HTML asset deletion, local MDX preview proof, validation, sync, and cleanup.
- Placeholder scan: no placeholders remain.
- Type and name consistency: route name remains `companion-interface`; review artifact root is `plans/<slug>/plan.mdx`; canonical implementation plan root remains `docs/superpowers/plans/`.
- Task # Use Cases: every numbered task includes a concrete `**Use Cases:**` block.
