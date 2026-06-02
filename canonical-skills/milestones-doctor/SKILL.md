---
name: milestones-doctor
description: "Audit and optionally repair an existing GitHub milestone workflow: docs/milestones/PROJECT_CONTEXT.md, milestone ideas/issues folders, local issue files, GitHub milestone drift, labels, issue forms, Projects metadata, and obsolete docs folders."
---

# Milestones Doctor

Use this when a repo already has, or claims to have, the Milestones workflow and the user wants to audit, clean up, migrate, repair, or verify it. This skill is report-first. It must not delete, move, rename, commit, push, close, merge, or mutate GitHub until the user explicitly approves a repair plan.

Use `$setup-project-milestones` for first-time setup. Use this skill for existing projects, partial setups, drift, stale docs, or cleanup.

## Hard Failures

Stop with `Blocked by skill contract: <reason>` when any of these are true:

- The target repo is not explicit as `target_repo` and `target_repo_root`.
- The repo lacks a GitHub origin remote or authenticated `gh` access and the user asked for GitHub drift checks.
- `$setup-matt-pocock-skills` markers or `docs/agents/issue-tracker.md` are missing or do not prove GitHub Issues for the active remote, unless the user explicitly asked for a local-docs-only audit.
- A repair plan would change product code, implementation tests, runtime docs unrelated to milestones, branches, GoalBuddy boards, PRs, or merges.
- The agent performs cleanup before producing an audit report and receiving explicit approval.
- The agent deletes user-written idea briefs, issue files, project context text, or milestone READMEs instead of marking them for review.
- The agent auto-updates GitHub milestones or `docs/milestones/PROJECT_CONTEXT.md` to resolve drift without user approval.
- Repair mode starts from anything other than the synced default branch.

## Audit Scope

Inspect and report:

- `docs/milestones/PROJECT_CONTEXT.md` existence and whether it names the milestone taxonomy.
- `docs/milestones/README.md`.
- Every `docs/milestones/<milestone-folder>/README.md`.
- Every `docs/milestones/<milestone-folder>/ideas/README.md`.
- Every `docs/milestones/<milestone-folder>/issues/README.md`.
- Local issue files under `docs/milestones/<milestone-folder>/issues/*.md`.
- Milestone-specific idea files under `docs/milestones/<milestone-folder>/ideas/*.md`.
- Legacy or obsolete folders: `docs/ideas/`, `docs/issues/`, `docs/plans/`, `docs/milestones/*/plans/`, issue-level files under `docs/roadmaps/`, and old full-roadmap files that duplicate `docs/milestones/PROJECT_CONTEXT.md`.
- `docs/agents/project-roadmap.md` and `docs/agents/project-roadmap.json`.
- `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml`, and `task.yml`.
- Labels `type:bug`, `type:feature`, `type:task`, `status:triage`, `status:ready`, and `status:blocked`.
- GitHub milestones and whether their titles/descriptions align with `docs/milestones/PROJECT_CONTEXT.md`.
- Projects only as dashboard evidence unless repo config says Projects are required.

## State Machine

1. `repo_gate`: verify target repo, target root, GitHub remote, default branch, tracker setup, and whether the run is local-docs-only or GitHub-aware.
2. `audit`: run bundled `scripts\audit-milestones.ps1 -RepoRoot <target_repo_root>` and, when GitHub checks are needed, inspect GitHub labels, milestones, issue forms, and Projects with `gh`.
3. `report`: produce an audit report with findings grouped as `blocking`, `repairable`, `review_needed`, and `healthy`.
4. `repair_plan`: if fixes are needed, ask the user which repair set to apply. Batch choices with `request_user_input` when available.
5. `apply`: only after explicit approval, stay on the synced default branch and edit setup-owned docs/forms or GitHub tracker metadata.
6. `sync`: commit and push repair docs on the default branch when local files changed.
7. `finish`: report the audit result, approved repairs, pushed commit if any, GitHub changes if any, and remaining review-needed items.

## Repair Policy

Allowed repairs after approval:

- Create missing `docs/milestones/PROJECT_CONTEXT.md` only if the user approves the proposed context.
- Create missing `README.md` placeholders for `docs/milestones/`, milestone root folders, milestone `ideas/`, and milestone `issues/`.
- Move or retire legacy `docs/ideas/` content only when every idea has an approved destination under `docs/milestones/<milestone-folder>/ideas/`.
- Move or rename old issue files only when the source and destination are explicitly listed in the approved repair plan.
- Mark obsolete folders for deletion only when they contain no user-authored content, or when each file has an approved destination.
- Create or update `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml`, and `task.yml`.
- Create or update GitHub labels and milestones when the approved repair plan names the exact titles/descriptions.
- Update `docs/agents/project-roadmap.md` and `docs/agents/project-roadmap.json` to match the approved Milestones contract.

Forbidden repairs:

- Product-code changes.
- Implementation branches.
- GoalBuddy boards.
- PR creation, merge, or issue closure.
- Deleting unreviewed idea briefs, local issue files, or milestone context.
- Changing milestone meaning to match GitHub or changing GitHub to match docs without user-approved direction.

## Audit Report Shape

```json milestones_doctor_report
{
  "target_repo": "<owner/repo>",
  "target_repo_root": "<absolute local checkout path>",
  "mode": "audit-only|repair-approved",
  "local_contract": {
    "project_context": "present|missing|duplicate-with-roadmap|review-needed",
    "milestone_root": "present|missing",
    "milestone_folders": [
      {
        "folder": "<folder>",
        "readme": "present|missing",
        "ideas_dir": "present|missing",
        "issues_dir": "present|missing"
      }
    ],
    "obsolete_paths": ["docs/ideas", "docs/issues", "docs/plans", "docs/milestones/<folder>/plans"]
  },
  "github_contract": {
    "checked": true,
    "labels": "healthy|missing|drift",
    "milestones": "healthy|missing|drift",
    "issue_forms": "healthy|missing|drift",
    "projects": "dashboard-only|required|not-checked"
  },
  "findings": {
    "blocking": [],
    "repairable": [],
    "review_needed": [],
    "healthy": []
  },
  "proposed_repairs": []
}
```

Do not show raw JSON unless the user asks for it. Summarize the audit in human-readable form and keep the JSON as internal evidence or a file only when useful.

## Validation

Before reporting this skill package complete after edits:

- run `scripts\test-scenarios.ps1`;
- parse all bundled PowerShell scripts;
- validate skill frontmatter and plugin wrapper;
- validate the Milestones plugin;
- run the repo-scoped cleanup hook from the active repo root.
