# Add Project Doctor Tracker Hygiene Audit And Repair Mode

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/21
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md
**Source Plan:** docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md
**Classification:** AFK
**Labels:** enhancement, type:feature, status:ready
**Goal Command:** /goal Add Project Doctor tracker hygiene audit and repair mode using docs/superpowers/issues/21-add-project-doctor-tracker-hygiene-audit-and-repair-mode.md and docs/superpowers/plans/2026-06-02-project-workflow-hardening-plan.md.
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

Extend `project-doctor` with a repo-safe tracker hygiene audit and conservative repair workflow for GitHub Issues plus GitHub Project V2 state. The default route must be audit-only and emit compact JSON findings grouped as `blocking`, `repairable`, `informational`, and `healthy`, matching the existing Doctor report shape.

## Acceptance Criteria

- [ ] `project-doctor` can audit GitHub issue label drift and Project V2 state drift from a Superpowers Project repo.
- [ ] The audit reports closed/open issue status mismatches, `status:*` label drift, missing routing labels, missing canonical Project items, mirror-to-Project field drift, and remaining Project V2 draft items without mutation by default.
- [ ] A repair mode removes `status:*` labels from closed issues and marks closed Project items `Done`.
- [ ] A repair mode can add mirrored open issues back to the canonical Project and sync valid Project fields from mirror metadata.
- [ ] Draft Project V2 issues are reported separately and are not published or deleted automatically.
- [ ] The command produces a repair receipt listing every GitHub object and field or label changed.
- [ ] Fixture tests cover closed-label cleanup, closed-not-done Project status, open-done mismatch, missing Project item from mirror, Project field sync, and draft-item reporting.
- [ ] Documentation explains the clean policy: open issues use `status:*` routing labels; closed issues use GitHub closed state plus Project `Done`.

## Blocked by

- None

## Non-goals

- Do not automatically close or reopen issues from Project state.
- Do not automatically publish or delete draft issues.
- Do not edit product code in audited repositories.
- Do not assume every repository uses the same Project field option names unless they are configured or discovered.

## Suggested Interface

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\audit-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\audit-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene -ApplyTrackerRepairs
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\audit-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene -ApplyDraftCleanup
```

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
