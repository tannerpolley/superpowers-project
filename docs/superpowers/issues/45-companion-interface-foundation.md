# Add Companion Interface Skill And Minimal Report Session

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/45
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-12-superpowers-html-companion-interface-design.md
**Source Plan:** docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md
**Classification:** AFK
**Labels:** type:feature, status:ready
**Goal Command:** /goal Implement docs/superpowers/issues/45-companion-interface-foundation.md using docs/superpowers/plans/2026-06-12-superpowers-html-companion-interface-plan.md Tasks 1 through 3, then stop with validation evidence.
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

Add the first vertical slice of the Superpowers Project HTML companion: a source-owned `companion-interface` skill, plugin/docs registration, report session helpers, event append support, and a static HTML renderer that can create a minimal browser report from a fixture manifest.

## Acceptance Criteria

- [ ] `skills/companion-interface/SKILL.md` exists with a valid skill contract for the evidence and interpretation channel.
- [ ] `skills/companion-interface/agents/openai.yaml` exists and describes the companion without changing native approval authority.
- [ ] `.codex-plugin/plugin.json`, `README.md`, and `docs/superpowers/PROJECT_CONTEXT.md` expose `$superpowers-project:companion-interface`.
- [ ] `scripts/test-companion-interface.ps1` is wired into `scripts/validate.ps1`.
- [ ] `new-report-session.ps1` creates `.superpowers/reports/<date>/<run-id>/manifest.json`, `events.jsonl`, `index.html`, and `artifacts/`.
- [ ] `append-event.ps1` records structured events and rejects report roots outside `.superpowers/reports`.
- [ ] `render-report.ps1` creates a self-contained `index.html` with Run Overview, Workflow Timeline, Artifact Browser, Evidence Feed, Decision Dock, and Interpretation Summary sections.
- [ ] The static report contains no `http://` or `https://` dependencies.
- [ ] Focused companion tests and full repo validation pass.

## Blocked by

- None

## Non-goals

- Do not add rich Markdown, table, plot, or validation receipt rendering in this slice.
- Do not add a long-lived local server.
- Do not make the HTML report an approval authority.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-companion-interface.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\companion-interface\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
