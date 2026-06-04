# Public Repo Release Readiness

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/32
**GitHub Milestone:** M2 - Distribution
**Issue Type:** task
**Source Spec:** docs/superpowers/specs/2026-06-03-public-release-readiness-design.md
**Source Plan:** docs/superpowers/plans/2026-06-03-public-release-readiness-plan.md
**Classification:** AFK
**Labels:** type:task, status:ready
**Goal Command:** /goal Make Superpowers Project docs and install instructions public-ready without renaming or publishing the remote repository.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** Source plan packets
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## Approval Decision

Native approval selected `Docs/Install Ready`: make the repo documentation, install instructions, and manifest surface public-ready. Do not rename the GitHub repository or change repository visibility in this issue.

## What To Build

Prepare the repo for public sharing, including public-facing docs and install instructions. Keep remote rename and public visibility changes behind explicit native approval.

## Acceptance Criteria

- [ ] README presents Superpowers Project as a public Codex/Superpowers extension.
- [ ] Install instructions are clear for another user cloning the repo.
- [ ] Manifest metadata includes repository, homepage, license, and keywords.
- [ ] Issue templates and active docs use Superpowers Project naming and `docs/superpowers/issues` paths.
- [ ] Validation and live sync pass before any public release claim.
- [ ] The docs/install readiness decision records that remote repo rename and visibility mutation are out of scope for this pass.

## Blocked by

- None.

## Non-goals

- Do not rename the local workspace folder.
- Do not rewrite historical closed issue or PR links.
- Do not tag a release unless a separate release policy issue approves it.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`
