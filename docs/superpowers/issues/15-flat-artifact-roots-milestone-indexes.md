# Keep specs loose and attach milestones at plan/issue stage

**GitHub Issue:** https://github.com/tannerpolley/milestones-plugin/issues/15
**GitHub Milestone:** M1 - Source Of Truth
**Issue Type:** feature
**Source Spec:** Optional; this issue defines source-of-truth behavior
**Source Plan:** docs/superpowers/plans/2026-06-03-flat-artifact-roots-milestone-indexes-plan.md
**Classification:** AFK
**Labels:** status:ready, type:feature
**Goal Command:** /goal Implement this issue by updating the Milestones plugin so canonical specs, plans, and issues stay in flat docs/superpowers roots; milestone identity is carried by metadata, filenames where applicable, and generated milestone index views; nested canonical milestone artifact folders are flagged as drift. Complete when acceptance criteria are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is recorded.
**Branch:** codex/flat-artifact-roots-milestone-indexes
**Execution Mode:** Orchestrated worker
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only

## External Hydration Notes

- Hydrated from external GitHub issue #15, which had no local mirror on `main`.
- The GitHub issue body listed source plan as optional until project-plan creates one; this mirror links the derived source plan required for `$project-resolve`.
- Delegated worker topology selected this current worktree and branch `codex/flat-artifact-roots-milestone-indexes`.

## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat

## What To Build

Codify the Milestones plugin artifact lifecycle:

- Specs are loose idea, design, PRD, or brainstorming records. They may mention related milestones, packages, categories, or future issue candidates, but they should not be required to name a milestone, GitHub issue, source plan, implementation branch, proof oracle, or issue-ready execution metadata.
- Plans are the organized execution design for a selected spec or approved idea. A plan should assign milestone ownership when the work is implementation-facing, describe steps, boundaries, proof, and issue-splitting logic, and may link back to one or more loose specs.
- Issues are the official implementation records. They should be derived from a plan, have tracker metadata, milestone ownership, acceptance criteria, proof oracle, branch/worktree guidance, and execution readiness fields.
- Canonical `docs/superpowers/specs`, `docs/superpowers/plans`, and `docs/superpowers/issues` directories should remain flat. Milestone dashboards/indexes should link to those canonical files instead of owning nested copies such as `docs/superpowers/milestones/m0/issues/...`.

## Acceptance Criteria

- [ ] Project Context, Project Doctor, Project Brainstorm, Project Plan, Project Issue, and Project Resolve documentation agree that canonical specs, plans, and issues directories are flat.
- [ ] Project Context, Project Doctor, Project Brainstorm, Project Plan, Project Issue, and Project Resolve docs describe the lifecycle as `spec -> plan -> issue`, with different metadata requirements at each stage.
- [ ] Spec templates and validators no longer require milestone, GitHub issue, source plan, implementation branch, proof oracle, or issue-ready execution metadata.
- [ ] Spec filenames require creation date and slug, but milestone identity is optional and only used when naturally helpful.
- [ ] Plan templates and validators support linking to one or more specs or a raw approved idea, and require milestone/package ownership only when the plan is implementation-facing.
- [ ] Issue templates and validators require source plan linkage, GitHub issue metadata, milestone ownership, acceptance criteria, proof oracle, AFK/HITL classification, and branch/worktree execution fields.
- [ ] Generated or repaired artifact filenames include date plus milestone identity where applicable, and issue mirrors include issue number.
- [ ] Project Doctor can repair over-coupled specs by downgrading implementation-only metadata to optional notes or moving it into matching plans/issues.
- [ ] Milestone README/dashboard generation indexes plans and issues by milestone, and may list related specs as loose upstream context without treating them as milestone-owned work.
- [ ] Milestone README/dashboard generation links to the flat canonical artifacts instead of owning nested copies.
- [ ] Doctor/validation scripts detect nested canonical artifact folders under milestone directories, unless explicitly marked as generated index/view output.
- [ ] Migration guidance explains why milestone subfolders are not canonical and how milestone/category views should be represented through frontmatter plus indexes.
- [ ] Existing test scenarios cover brainstorming a loose spec, planning it into milestone-aware work, issuing implementation slices from the plan, resolving issue mirrors, and repairing docs without creating nested canonical subfolders.

## Non-goals

- Do not require every spec to map to a milestone or GitHub issue.
- Do not move canonical issue mirrors under `docs/superpowers/milestones/<milestone>/issues`.
- Do not introduce duplicate milestone-owned copies of specs, plans, or issues.
- Do not remove milestone README/index views.
- Do not redesign GitHub labels, milestones, or issue dependency semantics beyond this lifecycle/source-of-truth rule.

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-context\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-issue\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
