---
name: create-issues
description: Use when approved scope needs executable GitHub issue slices and synchronized local mirrors.
---

# Project Issue

Convert approved scope into testable vertical slices. GitHub publication requires separate native approval.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `github`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before drafting when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates and `docs/superpowers/workflow-contract.yml` for labels.

## Contract

Require approved scope with acceptance criteria and a proof oracle. Use independently testable vertical slices and record dependencies. Hierarchy modes are `flat`, `issue-set`, and `sub-milestone`; only leaf mirrors with `Sub-Issue Role: leaf` and `Executable: true` may execute. Run `validate-issue-title-policy.sh -Title <title>` and `build-issue-hierarchy-plan.sh -SourcePlanPath <plan> -HierarchyMode <mode> -LeafTitles <titles>` under `skills/create-issues/scripts/`; non-flat modes also require `-ParentTitle`.

Write `docs/superpowers/issues/<number>-<slug>.md` with issue identity, source artifact and plan, milestone, labels, dependencies, branch policy, execution role, acceptance criteria, proof oracle, non-goals, and Outcome Summary fields: Intent, Target Output, Owner, Interface, Cutover, Replaced Path, Acceptance Proof, Stop Criteria, and Avoid.

Run `skills/create-issues/scripts/validate-issue-mirror.sh -IssueFile <mirror>` and `skills/create-issues/scripts/validate-issue-hierarchy.sh -IssueMirrorPath <mirror> -GitHubIssueFixturePath <fixture>`. External issues remain intake until `skills/create-issues/scripts/hydrate-external-issue.sh -IssueJsonPath <issue>` produces a valid plan and mirror. `Source Plan: TBD` blocks execution.

## Closeout

Show the dry hierarchy, issue content, metadata, and mirror paths before publication approval. Stop on missing approval, ambiguous slicing, invalid artifacts, unresolved dependencies, or GitHub mismatch. After publication, show URLs and receipts through `project_issue_next_step`; Yes resolves or orchestrates, Revisit repairs, and `Stop` exits. This route has no verified final `Done`.
