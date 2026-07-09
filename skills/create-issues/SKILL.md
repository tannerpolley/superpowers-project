---
name: create-issues
description: Use when a Superpowers Project spec, plan, PRD, or approved scope needs vertical-slice GitHub issues and synced issue mirrors.
---

# Project Issue

Convert approved scope into executable vertical slices and synchronized local mirrors. GitHub mutation is separate from drafting and requires native approval.

## Capability Preflight

Require `filesystem.read`, `filesystem.write`, `shell`, `github`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before issue preparation if any required capability is absent.

## Shared Policy

Follow `skills/advanced-user-input/SKILL.md` for global native questions and artifact review. This route owns route-specific hierarchy, mirror, publication, and execution choices. Exact route labels live in `docs/superpowers/workflow-contract.yml`.

## Inputs And Slicing

Require an approved spec, plan, PRD, or explicit scope with acceptance criteria and proof oracle. Prefer independently testable vertical slices. Record dependencies; do not create implementation-layer fragments that cannot deliver a user-observable outcome.

Hierarchy modes are `flat`, `issue-set`, and `sub-milestone`. Parent and plan-wrapper mirrors are rollups with `Executable: false`; only leaf mirrors with `Sub-Issue Role: leaf` and `Executable: true` may execute. Run `skills/create-issues/scripts/validate-issue-title-policy.sh` for every clean title and `skills/create-issues/scripts/build-issue-hierarchy-plan.sh` before publication.

## Mirror Contract

Write `docs/superpowers/issues/<number>-<slug>.md`. Include issue URL/number, source artifact and plan, milestone, labels, dependencies, branch policy, execution role, acceptance criteria, proof oracle, non-goals, and `## Outcome Summary` with Intent, Target Output, Owner, Interface, Cutover, Replaced Path, Acceptance Proof, Stop Criteria, and Avoid.

Validate each mirror with `skills/create-issues/scripts/validate-issue-mirror.sh -IssueFile <mirror>`. Validate hierarchy against GitHub evidence with `skills/create-issues/scripts/validate-issue-hierarchy.sh`.

External issues are intake until hydrated with `skills/create-issues/scripts/hydrate-external-issue.sh` and both the local plan and mirror validate. `Source Plan: TBD` is never execution-ready.

## Publication And Stop Conditions

Show the dry hierarchy plan, titles, bodies, labels, milestone, parents, and mirror paths before native publication approval. Stop on missing approval, ambiguous slicing, invalid title/mirror, unresolved dependency, or GitHub mismatch. Never infer publication authority from Auto execution authority.

After publication, show URLs and validation receipts and use `project_issue_next_step`. Yes routes to direct resolution or orchestration, Revisit repairs/reviews, and `Stop` is the intermediate terminal choice. This route never claims verified final `Done`.
