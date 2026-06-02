# Milestones Plugin

Milestones is a local Codex plugin and skill family for GitHub-backed project management:

- set up milestone-backed repos;
- audit and repair milestone workflow drift;
- explore ideas through native question UI;
- convert scoped ideas into GitHub issues;
- write milestone-local issue implementation plans;
- resolve issues through GoalBuddy, verification, PR merge, closeout, and cleanup.

This repository is the canonical source. The live Codex install is a deployment target.

## Skills

- `$using-milestones`: routes Milestones workflow requests to the correct skill and Superpowers method.
- `$setup-project-milestones`: sets up `docs/milestones`, issue types/forms/labels, and project metadata.
- `$milestones-doctor`: audits and repairs existing milestone workflows.
- `$explore-ideas`: performs deep repo exploration and writes milestone-local idea briefs.
- `$convert-idea-to-issue`: turns an idea brief or broad intent into one issue or an approved issue set.
- `$milestone-writing-issue-plan`: writes implementation plans into milestone-local issue files.
- `$resolve-issue-with-goal`: resolves one issue through GoalBuddy, tests, PR, merge, issue closure, and cleanup.

## Canonical Layout

```text
.codex-plugin/plugin.json
canonical-skills/<skill-name>/
skills/<skill-name>/
scripts/install.ps1
scripts/sync-live.ps1
scripts/validate.ps1
docs/milestones/PROJECT_CONTEXT.md
```

`canonical-skills/` contains the canonical user-level skill implementations.

`skills/` contains plugin namespace wrappers that point to the deployed user-level skills. This keeps the plugin menu organized without duplicating live behavior and satisfies the plugin validator's required skill-root name.

Milestone-backed idea briefs belong under:

```text
docs/milestones/<milestone-folder>/ideas/
```

Milestone-backed local issue files belong under:

```text
docs/milestones/<milestone-folder>/issues/
```

`docs/ideas`, `docs/issues`, `docs/plans`, and `docs/milestones/<milestone-folder>/plans` are not part of this repo's workflow.

## Validate

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## CI And Releases

GitHub Actions runs the same validation command used locally:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Release gates and tag rules are documented in `docs/milestones/M2-distribution/RELEASE_POLICY.md`.

## Sync To Live Codex Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

The sync script deploys this repo's plugin manifest and plugin wrappers to:

- `C:\Users\Tanner\plugins\milestones`

It deploys canonical user-level skills from `canonical-skills/` to:

- `C:\Users\Tanner\.agents\skills`

## Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```
