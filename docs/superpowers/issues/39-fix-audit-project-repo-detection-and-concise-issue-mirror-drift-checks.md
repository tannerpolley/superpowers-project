# Fix audit-project repo detection and concise issue mirror drift checks

**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/39
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** bug
**Source Spec:** none
**Source Plan:** docs/superpowers/plans/fix-audit-project-repo-detection-and-concise-issue-mirror-drift-checks-plan.md
**Classification:** AFK
**Labels:** type:bug, status:ready
**Goal Command:** /goal Resolve issue 39 by fixing audit-project repository detection and concise issue mirror drift checks, with scenario coverage and repo validation.
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Current thread owns PR
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** No worktree created
**Orchestrator Wakeup Policy:** Inline run

## What To Build

Repair `audit-project` GitHub-aware mode so it can inspect live GitHub evidence from the repository metadata shapes used by project docs and so concise issue mirrors are audited by stable metadata instead of exact body containment.

## Reproduction

In a repo whose `docs/agents/project-roadmap.json` contains `target_repo` but not `repository`, run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\audit-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene
```

Current behavior:

- `target_repo` in audit output is `null`.
- Live GitHub issue evidence is not inspected.
- GitHub-aware drift checks are downgraded to informational findings.
- Frontmatter-backed issue mirrors can parse `---` as the title.
- Concise issue mirrors can be flagged as body drift when title, milestone, labels, and issue URL match.
- `mirror-github-drift` is reported as repairable even though no mirror drift repair receipt/action exists.

## Acceptance Criteria

- [ ] `audit-project -Mode GitHubAware` resolves `repository` from `docs/agents/project-roadmap.json` when present.
- [ ] `audit-project -Mode GitHubAware` resolves `target_repo` from `docs/agents/project-roadmap.json` when `repository` is absent.
- [ ] `audit-project -Mode GitHubAware` resolves the repository from `git remote` when roadmap metadata is absent.
- [ ] Issue mirror title parsing reads frontmatter `title` or the first Markdown H1 after frontmatter instead of the first raw line.
- [ ] Concise issue mirrors that match title, milestone, labels, and issue URL are not flagged only because the full GitHub issue body is not copied verbatim.
- [ ] `mirror-github-drift` no longer appears as repairable unless the script records a concrete repair receipt/action for that field.

## Blocked by

- None

## Non-goals

- Do not add automatic GitHub mutation for mirror drift.
- Do not change closed issue lifecycle policy.
- Do not change Project V2 repair behavior outside mirror drift categorization.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
