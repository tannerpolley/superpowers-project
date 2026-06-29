# GitHub Sub-Issues Workflow Design

## Summary

Superpowers Project should support GitHub sub-issues as an optional hierarchy feature for grouped multi-issue work. Simple projects and single-issue plans remain flat. When an approved plan naturally produces related vertical slices, `$superpowers-project:create-issues` should recommend a clean-title parent issue and publish the executable slices as sub-issues. When work is large enough to act like a pseudo sub-milestone, the parent issue represents that pseudo sub-milestone inside the real GitHub Milestone.

Issue titles must stay clean. GitHub Milestone, parent/sub-issue relationships, labels, issue types, and Project fields carry tracking structure. Titles must not encode manual milestone names, milestone numbers, pseudo sub-milestone numbers, or hierarchy ordinals.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines GitHub Issues plus local mirrors under `docs/superpowers/issues` as the tracker model.
- `skills/create-issues/SKILL.md` owns issue decomposition, GitHub publication, local mirrors, AFK/HITL classification, labels, milestones, and downstream routing.
- `skills/resolve-issue/SKILL.md` and `skills/orchestrate-issues/SKILL.md` execute one ready issue mirror at a time and should remain leaf-issue executors.
- `skills/merge-changes/SKILL.md` owns integration, issue close verification, cleanup, and final proof.
- `skills/align-project/SKILL.md` already owns tracker drift and should own selective hierarchy migration and repair.
- Current recent GitHub issues for this repo have real GitHub milestones but no parent/sub-issue relationships.
- Local `gh` is `2.94.0` and supports `gh issue create --parent`, `gh issue edit --add-sub-issue`, `--remove-sub-issue`, `--parent`, `--remove-parent`, and JSON fields `parent`, `subIssues`, and `subIssuesSummary`.
- GitHub documentation describes sub-issues for breaking larger work into tasks, REST endpoints for parent/sub-issue operations, and Project fields for parent issue and sub-issue progress:
  - https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues
  - https://docs.github.com/en/rest/issues/sub-issues
  - https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-parent-issue-and-sub-issue-progress-fields

## Goals

- Add native GitHub sub-issue support without making hierarchy mandatory for every project.
- Use parent issues as pseudo sub-milestones when grouped work is large enough to need a rollup object inside a real GitHub Milestone.
- Support clean-title issue publication. Tracking metadata belongs in GitHub fields and local mirrors, not in titles.
- Preserve the existing `spec -> plan -> issue` lifecycle and flat canonical artifact roots.
- Keep parent and plan-wrapper issues non-executable.
- Keep `$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues` leaf-only.
- Add validation so hierarchy drift, title drift, and accidental parent execution fail loudly.

## Non-Goals

- Do not replace GitHub Milestones with parent issues.
- Do not require every repo or every plan to use pseudo sub-milestones.
- Do not bulk-rewrite historical issue titles or hierarchy without native approval.
- Do not make GitHub Projects the source of truth for issue hierarchy.
- Do not let parent or wrapper issues run through direct or worker issue execution.
- Do not use title prefixes such as `M1`, `M1.2`, `[M0]`, or milestone names for new issue publication.

## Core Model

The workflow supports three hierarchy modes.

### Flat

Use flat mode for single-issue plans, unrelated maintenance, or projects that do not benefit from hierarchy.

Shape:

```text
GitHub Milestone
  -> Executable issue
```

### Issue Set

Use issue-set mode when one approved plan creates multiple related vertical slices. The parent issue represents the grouped plan. Its sub-issues are executable leaves.

Shape:

```text
GitHub Milestone
  -> Parent issue: grouped plan
      -> Executable leaf issue
      -> Executable leaf issue
```

### Pseudo Sub-Milestone

Use pseudo sub-milestone mode when a body of work acts like a sub-milestone inside a real GitHub Milestone. The parent issue is the pseudo sub-milestone. If it contains multiple approved plans, each plan can have a wrapper issue beneath the parent before executable leaves.

Shape:

```text
GitHub Milestone
  -> Parent issue: pseudo sub-milestone
      -> Plan wrapper issue
          -> Executable leaf issue
          -> Executable leaf issue
      -> Plan wrapper issue
          -> Executable leaf issue
```

The parent issue and wrapper issue are rollup artifacts. They are not agent-executable implementation records.

## Title Policy

New issue titles must be clean work titles.

Allowed examples:

- `Looping Mode State Machine`
- `Decision Ledger Examples`
- `Artifact Review Card Schema`
- `Native Continuation Policy`

Rejected examples for new issue publication:

- `M1: Looping Mode State Machine`
- `M1.2 Looping Mode State Machine`
- `[M0] Artifact Review Card Schema`
- `Source Of Truth: Decision Ledger Examples`
- `1. Decision Ledger Examples`

The real GitHub Milestone field carries milestone identity. Parent/sub-issue relationships carry grouping. Labels, issue type, and Project fields carry filtering and display state.

Historical issues that already violate the policy should be reported by `align-project` as selective migration or cleanup candidates. They should not be renamed automatically.

## Use Cases

### 1. Project Stays Flat

A project or plan has one issue, or the issue set is not meaningfully grouped. `create-issues` publishes normal executable issues with no parent. Existing validation and execution routes continue unchanged.

### 2. Grouped Multi-Issue Plan

An approved plan creates several related vertical slices. `create-issues` recommends issue-set mode. The user approves one clean-title parent issue and multiple executable leaf sub-issues. The parent tracks progress, while leaves carry AFK/HITL classification, goal commands, proof oracles, and merge metadata.

### 3. Pseudo Sub-Milestone Inside A Real Milestone

A large body of work belongs under a real GitHub Milestone but should be grouped more tightly than the milestone itself. The parent issue becomes the pseudo sub-milestone. The parent has a clean descriptive title, the real GitHub Milestone field, and a hierarchy label or issue type such as `type:sub-milestone`.

### 4. Multiple Plans Under One Pseudo Sub-Milestone

A pseudo sub-milestone includes multiple approved plans. Each plan receives a clean-title wrapper issue under the parent. Executable leaf sub-issues attach to the relevant wrapper. This preserves plan-level rollup without title prefixes.

### 5. Leaf Issue Direct Execution

A leaf issue mirror is ready and AFK. `$superpowers-project:resolve-issue` validates that it is executable, runs the linked source plan, opens a PR, and routes to `$superpowers-project:merge-changes`. Parent hierarchy metadata does not change the execution contract.

### 6. Leaf Issue Worker Execution

A leaf issue is worker-suitable. `$superpowers-project:orchestrate-issues` validates that the issue is executable, derives worker identity from the leaf issue, and creates the worker handoff. Parent and wrapper issues never become worker handoffs.

### 7. Parent Rollup Closeout

After leaf issues merge, `$superpowers-project:merge-changes` records child closure evidence. A wrapper or pseudo sub-milestone parent may close only after rollup proof shows all required child issues are closed or intentionally skipped, and the native merge or closeout gate approves the rollup action.

### 8. External GitHub Issue Hydration

When hydrating an existing GitHub issue URL, `create-issues` reads `parent`, `subIssues`, and `subIssuesSummary` with `gh issue view --json`. It creates or repairs local hierarchy fields before any execution route begins. Raw GitHub issue text remains intake until mirror and source plan validation pass.

### 9. Selective Migration

`align-project` audits existing flat issues and proposes attaching them under clean-title parent issues when that improves tracker structure. The migration is selective and approval-backed. It must show proposed parent, children, labels/types, milestones, and title changes before any GitHub mutation.

### 10. Looping Mode Candidate Selection

`loop-controller` and active backlog selection should select executable leaf issues. Parent and wrapper issues can appear as rollup candidates only for align, closeout, or tracker repair routes, not implementation routes.

### 11. Project Dashboard Progress

GitHub Projects can group or filter by parent issue and show sub-issue progress. The extension can use this for dashboard evidence, but local mirrors and route validators remain authoritative for execution readiness.

### 12. Dependency Plus Hierarchy

Sub-issue hierarchy is grouping, not dependency. Existing blocked-by or blocking relationships remain dependency signals. `create-issues` may combine them when a child must wait for another child, but hierarchy alone must not imply execution order.

## Workflow Changes By Skill

### setup-project

- Add tracker setup for hierarchy labels and issue types.
- Verify `type:sub-milestone`, `type:issue-set`, and `type:plan-wrapper` labels or equivalent native issue types when hierarchy is enabled.
- Keep existing `type:bug`, `type:feature`, `type:task`, and status labels for executable leaves.
- Record GitHub CLI/API hierarchy capability proof.

### create-issues

- Classify the issue output as `flat`, `issue-set`, or `sub-milestone`.
- Recommend issue-set mode by default for grouped multi-issue plans.
- Ask native approval for hierarchy mode, parent title, wrapper use, child issue list, labels/types, milestones, and publication order.
- Publish parent or wrapper issues before leaf sub-issues.
- Use `gh issue create --parent` for new child issues and `gh issue edit --add-sub-issue` when attaching existing issues.
- Write local mirrors for parent, wrapper, and leaf issues.
- Validate clean-title policy before any GitHub mutation.

### Issue Mirrors

Add hierarchy fields:

```markdown
**Hierarchy Mode:** flat | issue-set | sub-milestone
**Sub-Issue Role:** parent | plan-wrapper | leaf
**Executable:** true | false
**Parent Issue:** <url or None>
**Parent Mirror:** <path or None>
**Child Issues:** <issue URLs or None>
**Rollup Policy:** all-required-children-closed | explicit-skip-evidence-allowed | none
**Title Policy:** Clean GitHub title
```

Leaf mirrors retain existing required execution metadata: source plan, AFK/HITL classification, goal command, execution mode, worktree policy, outcome summary, acceptance criteria, proof oracle, and project merge metadata.

### resolve-issue

- Block parent and plan-wrapper mirrors.
- Require `Executable: true` and `Sub-Issue Role: leaf` when hierarchy fields are present.
- Preserve current one-issue execution behavior for leaf mirrors.

### orchestrate-issues

- Block parent and plan-wrapper mirrors.
- Derive worker identity only from executable leaf issue mirrors.
- Preserve current worker handoff behavior for leaf mirrors.

### merge-changes

- After a leaf merge, collect parent/wrapper rollup state.
- Record rollup evidence in the merge closeout artifact.
- Close parent or wrapper issues only through explicit rollup proof and native approval.

### align-project

- Audit tracker vocabulary for hierarchy labels or issue types.
- Detect local/GitHub parent-child drift.
- Detect historical titles that encode milestone metadata.
- Propose selective hierarchy migration, title cleanup, and mirror repair without automatic GitHub mutation.

## Validation Rules

- New issue titles must not include milestone names, milestone numbers, pseudo sub-milestone ordinals, or hierarchy ordering.
- Parent and wrapper mirrors must have `Executable: false`.
- Leaf mirrors must have `Executable: true`.
- Executable routes must reject non-leaf mirrors.
- Hierarchy publication must stop when approved hierarchy metadata cannot be represented in GitHub.
- Local mirror parent/child fields must match GitHub `parent`, `subIssues`, and `subIssuesSummary` after publication.
- Parent or wrapper closeout must prove all required children are closed or intentionally skipped.

## Testing Requirements

- `create-issues` flat single issue fixture still passes.
- Grouped multi-issue plan fixture recommends issue-set mode.
- Pseudo sub-milestone fixture creates parent, plan-wrapper, and leaf payloads in dependency order.
- Clean-title validator rejects milestone metadata in new issue titles.
- Publication blocks when hierarchy was approved but GitHub hierarchy capability proof is missing.
- Leaf issue mirrors pass current execution validation plus hierarchy fields.
- Parent and wrapper mirrors pass non-executable mirror validation.
- Parent and wrapper mirrors fail when passed to `resolve-issue`.
- Parent and wrapper mirrors fail when passed to `orchestrate-issues`.
- Leaf mirrors under a parent still execute through current direct and worker routes.
- `merge-changes` records child closure rollup without auto-closing a parent.
- `align-project` detects missing hierarchy labels/types and proposes repair.
- End-to-end fixture covers `spec -> plan -> parent/wrapper/leaves -> resolve leaf -> merge leaf -> roll up parent progress`.
- Opt-out fixture proves a project can stay flat.

## Rollout

1. Add hierarchy labels/types and clean-title policy to tracker setup and project context.
2. Add mirror schema fields and validators.
3. Extend `create-issues` to propose and publish hierarchy.
4. Add execution-route guards for non-leaf mirrors.
5. Add merge rollup evidence and closeout validation.
6. Add align-project audit and selective migration support.
7. Update workflow examples and README.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| GitHub sub-issues should be integrated into the workflow. | User request | Use GitHub sub-issues for grouped multi-issue workflows and pseudo sub-milestones. | Adds hierarchy support to issue creation, validation, alignment, and merge rollup. | No | create-issues |
| Hierarchy should not be mandatory. | User clarification | Projects and plans that do not need parent issues can stay flat. | Requires a hierarchy mode field and opt-out fixture. | No | create-issues |
| Parent issue semantics. | User clarification | Large parent issues act as pseudo sub-milestones inside real GitHub Milestones. | Parent issues become rollup artifacts, not executable work. | No | create-issues |
| Default trigger for hierarchy. | Native decision | Recommend parent issue creation for grouped multi-issue plans. | Multi-issue planning can use a single parent issue with leaf sub-issues by default. | No | create-issues |
| Depth policy. | Native decision | Support parent, optional plan-wrapper, and executable leaf levels. | Enables both single-plan issue sets and multi-plan pseudo sub-milestones. | No | create-issues |
| Title policy. | User clarification and native decision | Use clean titles only; do not encode milestone names, numbers, or ordinals in titles. | Adds title validation before GitHub publication and migration audit for historical titles. | No | create-issues |
| Tracker metadata location. | GitHub docs and repo context | GitHub Milestone, parent/sub-issue links, labels/types, and Project fields carry hierarchy metadata. | Prevents duplicate metadata in titles and keeps GitHub as tracker truth for hierarchy. | No | setup-project |
| Execution route boundary. | Repo context | Only leaf issue mirrors can run through resolve-issue or orchestrate-issues. | Parent and wrapper issues are blocked from implementation routes. | No | resolve-issue |
| Migration policy. | Native decision | Support selective migration rather than bulk mutation. | Existing flat issues can be reorganized after review without risky automatic tracker rewrites. | No | align-project |
| Parent closeout rule. | Design review | Parent/wrapper closure requires rollup proof and native approval. | Prevents one leaf merge from prematurely closing a pseudo sub-milestone. | No | merge-changes |
| Native issue type availability. | Repo evidence | Verify issue types or labels during setup; fail loudly when hierarchy identity cannot be represented. | Keeps hierarchy identity explicit without fake defaults. | No | setup-project |

## Recommended Next Route

After user review, route this spec to `$superpowers-project:write-plan`. The implementation should be split into issue-backed slices because it affects setup, issue creation, validation, execution guards, merge closeout, alignment, docs, and workflow examples.
