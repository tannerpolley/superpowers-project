# Project Implement And Integration Workflow Design

## Purpose

Add a first-class non-issue implementation path to Superpowers Project and align the surrounding workflow so planned work can proceed without forcing every change through a GitHub issue.

This spec covers skill behavior only. The public SVG flowchart is covered by `docs/superpowers/specs/2026-06-03-native-qa-svg-flowchart-design.md`.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the project as a Superpowers extension with durable context, roadmap mapping, GitHub issue linkage, native user-input grilling, and `/goal` issue execution.
- Existing repo skills are `superpowers-project`, `setup`, `brainstorm-spec`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, and `audit-project`.
- There is no repo skill named `project-implement` yet.
- `resolve-issue` is issue-bound and requires an issue mirror, linked source plan, native goal proof, branch setup, Superpowers execution, verification, push, PR creation, and PR-ready handoff.
- `orchestrate-issues` currently derives worker identity from one canonical issue and manages worker-thread issue execution.
- `merge-changes` is currently PR-bound and issue-close-aware.
- `advanced-user-input` exists as a user-level skill and defines nested bounded native choice patterns.
- Superpowers `executing-plans` requires loading a written plan, critically reviewing it, executing tasks exactly, verifying each task, stopping on blockers, and finishing through `finishing-a-development-branch`.
- GitHub issue #21 already tracks Doctor tracker hygiene and repair: <https://github.com/tannerpolley/milestones-plugin/issues/21>.

## Decisions Made

- Add `project-implement` as the non-issue execution route.
- `project-implement` starts from an approved plan, not an issue mirror.
- `project-implement` requires native `/goal` activation and completion proof.
- `project-implement` asks whether to execute inline in the current thread or in a worktree worker.
- `project-implement` mirrors Superpowers `executing-plans`: load plan, review critically, stop for blockers, execute tasks exactly, verify tasks, and finish through `finishing-a-development-branch`.
- `project-implement` uses a development branch and does not default to local-main quick edits.
- `project-implement` does not create GitHub issue mirrors and must not claim issue closure.
- Do not create a canonical `docs/superpowers/implementations` folder by default. The plan plus branch, goal, verification, native publish permission, and merge proof are sufficient.
- Push approval happens before PR-ready or merge-ready handoff.
- `merge-changes` should integrate issue-backed PRs, non-issue PRs, and local branch merges.
- Local branch merges are allowed only from clean synced `main` with validation and cleanup proof.
- Merge decline/no should route to user review. If reassessment is chosen, use nested native Q&A to choose Plan for strict test/execution revision or Brainstorm for loose idea/spec reassessment.
- `orchestrate-issues` can start from a broad request to choose ready issues. It should inspect local mirrors and GitHub state together, recommend unblocked high-priority work, and ask how many issues/worktrees to manage.
- If local and GitHub issue state disagree about readiness, blockers, closed/open state, or project status, Orchestrate should stop and route to Doctor rather than guessing.
- Doctor tracker hygiene repair itself belongs to issue #21 unless a later plan explicitly chooses to implement that issue.
- Bundle `advanced-user-input` into the plugin as a first-class skill dependency.
- Project skills should use `advanced-user-input` for nested native decision trees.

## Recommended Approach

Implement this as a skill-system expansion:

1. Bundle `advanced-user-input` under `skills/advanced-user-input`.
2. Add `skills/project-implement`.
3. Update `superpowers-project` and `write-plan` routing so Implement is a first-class path after Plan.
4. Update `merge-changes` to classify integration mode: `pr-issue`, `pr-no-issue`, or `local-branch`.
5. Update `orchestrate-issues` to support autonomous ready-issue selection and to block on local/GitHub tracker drift.
6. Add validation and scenario tests for the new skill and routing contracts.

## Project Implement Contract

`project-implement` should:

- Accept an approved plan under `docs/superpowers/plans`.
- Refuse to run without acceptance criteria and proof oracle candidates.
- Ask native topology question: inline current thread or worktree worker.
- Activate a native `/goal` from the plan objective.
- Create or verify a development branch.
- Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` as appropriate.
- Use `superpowers:test-driven-development` when feature or bug work needs code changes.
- Use `superpowers:using-git-worktrees` when worktree mode is selected.
- Use `superpowers:verification-before-completion` before completion claims.
- Use `superpowers:finishing-a-development-branch` before integration.
- Ask a native publish permission question before pushing or marking work merge-ready.
- Produce merge-ready proof from the plan, branch, native goal, verification output, native publish permission, and finishing-branch result.
- Route to `merge-changes`.

`project-implement` should not:

- Create GitHub issue mirrors.
- Claim to close a GitHub issue.
- Skip branch, verification, native goal, or finishing discipline.
- Replace `resolve-issue` for issue-backed work.

## Merge Contract Changes

`merge-changes` should classify intake as:

- `pr-issue`: PR closes a GitHub issue. Existing issue closure and mirror cleanup rules apply.
- `pr-no-issue`: PR is linked to a plan but does not close an issue. Require plan linkage, verification coverage, branch push proof, PR merge proof, cleanup proof, and no issue-closure expectation.
- `local-branch`: local branch merge with no PR. Require clean synced `main`, plan linkage, verification coverage, native merge approval, local merge proof, branch cleanup, cleanup hook proof, and clean repo proof.

Merge approval should support nested decisions through `advanced-user-input`:

- Merge now.
- Decline / user review.
- Reassess.

If Reassess is selected, ask the child branch:

- Plan: strict execution, testing, acceptance, and branch strategy revision.
- Brainstorm: loose idea/spec reassessment.

## Orchestrate Contract Changes

`orchestrate-issues` should support:

- explicit issue mode for named issue mirrors;
- autonomous selection mode when the user asks it to pick ready work.

Autonomous selection must compare local and GitHub state. It should inspect readiness, milestone, labels, blockers, dependency notes, proof oracle clarity, branch/worktree ownership, and likely parallel safety.

If local and GitHub disagree, Orchestrate routes to Doctor. It should not duplicate the full repair logic from issue #21.

## Advanced User Input Integration

Bundle `advanced-user-input` into `skills/advanced-user-input`.

Project skills should reference it for nested decision trees where native UI has too many branches for one question:

- `brainstorm-spec`: scope, naming, route, and design tradeoffs.
- `write-plan`: Issue, Implement, review, revise, or stop continuation.
- `project-implement`: topology, publish permission, and merge route.
- `resolve-issue`: publish permission and PR-ready routing.
- `orchestrate-issues`: issue-set selection, worker count, recovery, and publish approval.
- `merge-changes`: merge approval, decline/reassess routing, and post-merge continuation.

Native UI prompts should use as many questions and options as the decision requires when the active Codex Desktop runtime supports it. Larger decision trees should be decomposed into sequential branches only when the first answer changes which follow-up questions matter.

## Non-Goals

- Do not alter the README SVG in this spec.
- Do not create a canonical implementations folder.
- Do not force GitHub issues for every planned change.
- Do not let Implement skip native `/goal`.
- Do not let non-issue work pretend to close issues.
- Do not let workers merge their own PRs by default.
- Do not implement the full Doctor tracker hygiene repair workflow from issue #21 in this spec unless a later plan explicitly includes that issue.

## Milestone Linkage

- `M0 - Governance`: native Q&A decision-tree contracts, publish permission, merge approval, proof gates.
- `M1 - Source Of Truth`: skill routing, artifact ownership, bundled skill dependency.
- `M2 - Distribution`: public plugin workflow clarity once behavior and docs align.

## Proof Oracle Candidates

- `skills/advanced-user-input/SKILL.md` exists and validates.
- `skills/project-implement/SKILL.md` exists and validates.
- `scripts/validate.ps1` active skill list includes `advanced-user-input` and `project-implement`.
- `superpowers-project` routes to Implement.
- `write-plan` continuation includes Project Implement and no longer treats branch-backed non-issue work as Quick Apply.
- `project-implement` scenario tests cover missing plan, missing goal proof, inline topology, worktree topology, native publish permission, and merge-ready proof.
- `merge-changes` scenario tests cover `pr-issue`, `pr-no-issue`, and `local-branch`.
- `orchestrate-issues` scenario tests cover autonomous ready issue selection and local/GitHub drift reroute to Doctor.
- Validation rejects non-issue work that claims issue closure.
- Validation rejects merge-ready work without native publish permission proof.

## Open Questions For Planning

- Should `project-implement` worker mode reuse helpers from Resolve and Orchestrate, and if so which helper boundaries should be extracted first?
- Should the first implementation plan include only Orchestrate-side dependency handling for issue #21, or should it also add a small Doctor check that reports the drift category without repair?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: this spec excludes SVG work and focuses on skill behavior.
- Scope check: this should become one implementation plan with multiple tasks, or be split further if the plan becomes too large.
- Ambiguity check: remaining helper and Doctor-scope questions are planning questions, not hidden assumptions.

