# Render Companion Markdown, Tables, Plots, And Receipts

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/46
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-12-superpowers-html-companion-interface-design.md
**Source Plan:** docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/46-companion-rich-artifact-rendering.md using docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md Task 4 after the companion foundation issue is complete.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Extend the companion renderer so report sessions can show rendered Markdown through Pandoc, math through Pandoc MathML, CSV/JSON tables, SVG/PNG/JPG plot artifacts, and command or validation receipts with exact status evidence.

## Acceptance Criteria

- [ ] `Convert-CompanionMarkdownToHtml` renders Markdown through Pandoc with YAML frontmatter separated from the rendered body.
- [ ] Markdown math renders as MathML in generated report HTML.
- [ ] CSV and JSON table artifacts render as readable HTML tables.
- [ ] SVG, PNG, JPG, and JPEG plot artifacts render through image sections with captions or source context.
- [ ] `command_result`, `validation_result`, and `test_result` events show command, working directory, exit code, status, and output excerpt.
- [ ] Fixture tests create Markdown, CSV, SVG, and validation receipt artifacts and prove they appear in `index.html`.
- [ ] Missing or failing Pandoc rendering fails loudly with the source path and command evidence.
- [ ] Focused companion tests and full repo validation pass.

## Blocked by

- https://github.com/tannerpolley/superpowers-project/issues/45

## Non-goals

- Do not add local MathJax or Mermaid asset bundling in this slice.
- Do not add a local server or polling renderer.
- Do not integrate companion reporting into other workflow skills in this slice.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\companion-interface\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
