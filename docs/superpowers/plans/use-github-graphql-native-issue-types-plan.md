# Teach project setup and audit to use GitHub GraphQL for native issue types Implementation Plan

**Source:** https://github.com/tannerpolley/superpowers-project/issues/40

## Intake Summary

This plan was created during external GitHub issue hydration so the local issue mirror has an auditable source plan before execution routing.

## Issue Body

# Teach project setup and audit to use GitHub GraphQL for native issue types

## Problem

The project workflow currently relies on high-level `gh issue create` / `gh issue edit` behavior when preparing or auditing tracker state. On current GitHub CLI versions, those commands expose labels, milestones, projects, title/body, and assignees, but they do not expose native GitHub issue type assignment.

This makes project setup/audit capable of seeing or recommending `type:*` compatibility labels while missing the native GitHub issue type field when the target repository has issue types enabled.

## Evidence

Observed with `gh version 2.92.0`:

- `gh issue create --help` has no `--type` or issue-type flag.
- `gh issue edit --help` has no `--type` or issue-type flag.
- GraphQL repository introspection can read native issue types:
  - `repository.issueTypes(first: 20) { nodes { id name isEnabled } }`
- GraphQL supports native type assignment:
  - `CreateIssueInput.issueTypeId`
  - `UpdateIssueInput.issueTypeId`

Example update shape:

```graphql
mutation($issueId: ID!, $typeId: ID!) {
  updateIssue(input: { id: $issueId, issueTypeId: $typeId }) {
    issue { number title issueType { name } }
  }
}
```

## Requested Change

Update the Superpowers Project plugin workflows, especially project setup and project audit, so they treat native GitHub issue types as a first-class tracker field when the target repo supports them.

## Acceptance Criteria

- [ ] `project:setup-project` detects whether the target repository exposes native issue types through GraphQL.
- [ ] `project:audit-project` reports whether open issues have the expected native issue type in addition to compatibility `type:*` labels.
- [ ] Issue creation/update helpers use GraphQL `issueTypeId` when `gh issue create/edit` does not expose a native type flag.
- [ ] The workflow keeps compatibility labels such as `type:task`, `type:bug`, and `type:feature` when the target project still uses them.
- [ ] If a repo has no native issue types configured, the skills say that clearly and continue with label-only behavior.
- [ ] Documentation or skill text warns agents not to conclude that native issue types are unavailable just because high-level `gh issue` commands lack a `--type` flag.

## Non-goals

- Do not remove compatibility `type:*` labels.
- Do not require native issue types for repositories that have not enabled them.
- Do not depend on plugin cache paths or local ephemeral install paths.

## Suggested Proof

- Run a fixture or smoke test against a repo with native issue types enabled and prove GraphQL can set `Task`, `Bug`, and `Feature`.
- Run a fixture or smoke test against a repo without native issue types and prove the workflow falls back to label-only behavior with an explicit note.

## Verification

Run the proof oracle recorded in the hydrated issue mirror.
