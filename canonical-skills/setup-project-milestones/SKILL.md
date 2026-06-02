---
name: setup-project-milestones
description: Use when a GitHub-backed repo needs strict docs/milestones setup with project context, milestone idea folders, milestone issue folders, labels, issue types, issue forms, and Projects dashboard metadata.
---

# Setup Project Milestones

This skill prepares a GitHub repo for the issue-planning and issue-execution workflow. It sets up durable repo/project-management structure; it does not implement product code, create execution branches, run GoalBuddy, open PRs, or merge work.

Use this after or alongside `$setup-matt-pocock-skills`. That skill establishes tracker/domain-doc conventions; this skill establishes the milestone context file, milestone folders, milestone-local idea and issue files, issue type, issue form, label, and Projects dashboard contract consumed by `$explore-ideas`, `$convert-idea-to-issue`, and `$resolve-issue-with-goal`.

If the repo already has a milestone workflow and the user asks to audit, clean up, repair, migrate, or verify it, stop setup routing and use `$milestones-doctor` instead. This skill may upgrade an existing setup only when the user explicitly asks for setup migration and approves the setup plan.

The canonical local doc model is:

- `docs/milestones/`: the milestone system root.
- `docs/milestones/PROJECT_CONTEXT.md`: the canonical full roadmap/context file for milestone meaning.
- `docs/milestones/<milestone-folder>/README.md`: the milestone's durable summary, GitHub milestone mirror, and local navigation.
- `docs/milestones/<milestone-folder>/ideas/`: the only canonical location for new idea briefs and research notes.
- `docs/milestones/<milestone-folder>/issues/`: synced local issue files. These are the detailed plans for GitHub issues.
- `docs/issues/`: legacy or non-milestone fallback only for repos not yet migrated; do not create it in this strict setup.
- `docs/ideas/`: legacy only. Do not create it in this strict setup.
- `docs/roadmaps/`: optional historical architecture roadmaps only. Do not create `docs/roadmaps/FULL_ROADMAP.md` from this skill and do not put issue-level plans there.

Do not create `docs/plans/` or `docs/milestones/<milestone>/plans/`. In this workflow, issue files are the execution plans.

## Hard Failures

Stop with `Blocked by skill contract: <reason>` when any of these are true:

- The target repo is not explicit as `target_repo` and `target_repo_root`.
- The repo lacks a GitHub origin remote or authenticated `gh` access.
- `$setup-matt-pocock-skills` markers or `docs/agents/issue-tracker.md` are missing or do not prove GitHub Issues for the active remote.
- Apply mode starts from anything other than the synced default branch, normally `main`.
- Apply mode creates an implementation branch, GoalBuddy board, PR, or product-code change.
- The setup plan omits issue categories `bug`, `feature`, and `task`.
- The setup plan omits `docs/milestones/PROJECT_CONTEXT.md`.
- The setup plan omits `docs/milestones/` or any selected milestone's `ideas/` or `issues/` folder.
- The setup plan creates `docs/ideas/` or treats global `docs/ideas/` as the primary idea location.
- The setup plan creates or references `docs/plans/` or `docs/milestones/<milestone>/plans/`.
- The setup plan disables milestones or uses `docs/issues/` as the primary issue-file location.
- The setup plan treats GitHub Projects as a hard gate without repo-local config saying Projects are required.
- The setup claims a milestone context file exists when `docs/milestones/PROJECT_CONTEXT.md` was not found or approved.
- The setup chooses milestones without showing agent-proposed milestones and asking the user to select, rename, add, remove, or reorder them with `request_user_input` when available.
- The setup finishes before local setup docs/forms are committed and pushed.
- The user asked for audit, cleanup, repair, migration, or verification of an existing setup. Use `$milestones-doctor` unless the user explicitly requested setup migration.

## GitHub Issues Model

Use GitHub Issues deliberately:

- Milestones are durable roadmap buckets that mirror `docs/milestones/PROJECT_CONTEXT.md`.
- Labels are always available and must include `type:bug`, `type:feature`, and `type:task`.
- GitHub issue types are organization-level when available. Record and use `bug`, `feature`, and `task` if the org supports them; otherwise labels and issue forms are the fallback.
- Issue forms/templates make ready issues consistent. Provide bug, feature, and task forms that require outcome, acceptance criteria, non-goals, proof oracle, and plan file.
- Projects are dashboard evidence by default. They may expose table, board, or roadmap views, but are not a blocker unless `docs/agents/project-roadmap.json` says they are required.
- Sub-issues and dependencies are for decomposed work only; do not use them as a substitute for a scoped executable issue.

Primary GitHub docs to align with: Issues overview, milestones, Projects, issue templates/forms, issue types, sub-issues/dependencies, and PR issue linkage.

## State Machine

1. `repo_gate`: inspect the target repo with GitHub remote, `gh auth`, default branch, Matt Pocock setup, `docs/agents/issue-tracker.md`, existing milestones, labels, issue forms, Projects, legacy `docs/ideas`, `docs/milestones`, and `docs/milestones/PROJECT_CONTEXT.md`.
2. `milestone_context`: read `docs/milestones/PROJECT_CONTEXT.md` when it exists. If it does not exist, ask for approval to create it as the full roadmap/context file before milestone setup. The agent may propose initial context sections from repo/docs inspection, but must not silently invent durable milestone taxonomy.
3. `milestone_proposal`: propose milestones from the milestone context file, existing GitHub milestones, package/domain structure, active roadmaps, and repo docs.
4. `milestone_question_gate`: ask the user which milestones they want with `request_user_input` when available. Include the agent-proposed milestone set first, plus options to use existing GitHub milestones, edit the set, add milestones, remove milestones, rename milestones, or reorder milestones.
5. `plan`: ask for any remaining setup choices. Batch independent questions with `request_user_input` when available.
6. `handoff`: produce a fenced JSON block named `setup_project_milestones_plan`.
7. `validate`: run bundled `scripts\validate-setup-plan.ps1` against the handoff.
8. `apply`: after explicit approval, stay on the synced default branch and update only setup-owned files plus GitHub tracker metadata.
9. `sync`: commit and push setup docs/forms on the default branch.
10. `finish`: report the pushed commit, `docs/milestones/PROJECT_CONTEXT.md`, `docs/agents/project-roadmap.md`, `docs/agents/project-roadmap.json`, `docs/milestones/`, configured issue forms, labels, milestones, and Projects evidence. If legacy `docs/ideas/` exists, report it as legacy cleanup/audit work for `$milestones-doctor`.

## Mandatory Setup Plan

```json setup_project_milestones_plan
{
  "target_repo": "<owner/repo>",
  "target_repo_root": "<absolute local checkout path>",
  "source_docs": [
    "https://docs.github.com/en/issues",
    "https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/about-milestones",
    "https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects",
    "https://docs.github.com/articles/about-issue-and-pull-request-templates",
    "https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-the-issue-type-field"
  ],
  "full_roadmap": "docs/milestones/PROJECT_CONTEXT.md",
  "full_roadmap_policy": "read-existing|create-approved",
  "milestone_policy": "mirror-full-roadmap",
  "milestone_question_log": [
    {
      "tool": "request_user_input",
      "question": "<milestone selection question>",
      "agent_recommendation": ["<agent-proposed milestone title>"],
      "answer": "<user milestone decision>"
    }
  ],
  "milestones": [
    {
      "title": "<GitHub milestone title>",
      "folder": "<repo-safe milestone folder>",
      "description": "<roadmap-backed milestone meaning>",
      "source": "existing-github|full-roadmap|agent-proposed-user-approved",
      "github_milestone": "create|update|exists",
      "local_readme": "docs/milestones/<folder>/README.md",
      "local_ideas_dir": "docs/milestones/<folder>/ideas",
      "local_issues_dir": "docs/milestones/<folder>/issues"
    }
  ],
  "project_policy": "dashboard-only|repo-config-required",
  "issue_types": ["bug", "feature", "task"],
  "labels": ["type:bug", "type:feature", "type:task", "status:triage", "status:ready", "status:blocked"],
  "issue_forms": ["bug", "feature", "task"],
  "local_files": [
    "docs/milestones/PROJECT_CONTEXT.md",
    "docs/milestones/README.md",
    "docs/milestones/<folder>/README.md",
    "docs/milestones/<folder>/ideas/README.md",
    "docs/milestones/<folder>/issues/README.md",
    "docs/agents/project-roadmap.md",
    "docs/agents/project-roadmap.json",
    ".github/ISSUE_TEMPLATE/bug.yml",
    ".github/ISSUE_TEMPLATE/feature.yml",
    ".github/ISSUE_TEMPLATE/task.yml"
  ],
  "apply_policy": "default-branch-commit-push",
  "projects_required_by_repo_config": false
}
```

Do not include `branch`, `branch_policy`, `goal_board`, `pr_url`, implementation files, or merge state.

## Apply Rules

Apply mode may update:

- `docs/milestones/PROJECT_CONTEXT.md`
- `docs/milestones/README.md`
- `docs/milestones/<milestone-folder>/README.md`
- `docs/milestones/<milestone-folder>/ideas/README.md`
- `docs/milestones/<milestone-folder>/issues/README.md`
- `docs/agents/project-roadmap.md`
- `docs/agents/project-roadmap.json`
- `.github/ISSUE_TEMPLATE/*.yml`
- GitHub labels, milestones, issue forms/templates, and Projects dashboard metadata when permissions allow

Apply mode must not update product code. It must not create a feature branch. It must commit and push the setup changes on the default branch.

## Milestone Context Contract

This skill is for milestone-backed repos. It must read or create `docs/milestones/PROJECT_CONTEXT.md` first, then mirror its milestone taxonomy. If that file does not exist, ask for explicit approval to create it. Do not invent a milestone taxonomy silently.

The agent must propose a milestone set from `docs/milestones/PROJECT_CONTEXT.md` and repo evidence, then ask the user what milestones they want. The final milestone list must come from the user answer or be explicitly confirmed by the user. Each selected milestone gets a folder under `docs/milestones/<milestone-folder>/` with both an `ideas/` subfolder for exploration and an `issues/` subfolder for local issue files.

`docs/agents/project-roadmap.json` is the machine-readable setup contract for later skills. It must record that milestones are hard, whether Projects are dashboard-only, the canonical issue categories, labels, forms, milestone context source, milestone folders, idea file path template, and issue file path template.

## Handoff To Other Skills

After setup:

- `$explore-ideas` writes exploratory briefs under `docs/milestones/<milestone-folder>/ideas/`. For cross-cutting ideas, the user must choose an owning milestone or an approved cross-cutting milestone folder.
- `$convert-idea-to-issue` uses `docs/agents/project-roadmap.json` to create synced local-main issues or externally sourced issues. For local-main-sync, the linked `plan_file` field points to a local issue file under `docs/milestones/<milestone-folder>/issues/`.
- `$resolve-issue-with-goal` uses the issue marker and linked local issue file to execute ready issues.
- `$triage` and `$to-issues` use the issue categories and labels when decomposing or refining work.

## Validation

Before reporting this skill package complete after edits:

- run `scripts\test-scenarios.ps1`;
- parse all bundled PowerShell scripts;
- validate skill frontmatter and `agents\openai.yaml`;
- run the repo-scoped cleanup hook from the active repo root.
