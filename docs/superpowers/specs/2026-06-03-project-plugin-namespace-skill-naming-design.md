# Project Plugin Namespace And Skill Naming Design

## Purpose

Migrate Superpowers Project from a mostly user-skill surface such as `$project:brainstorm-spec` and `$project:initiate-workflow` to a true plugin namespace surface under `$project`.

The target experience is that typing `$project` exposes the whole Superpowers Project skill family as plugin-scoped skills, the same way the Superpowers plugin exposes `superpowers:*` skills.

## Project Context Evidence

- `.codex-plugin/plugin.json` currently uses `name: workflow`, so the natural plugin namespace is `superpowers-project`, not `project`.
- `scripts/sync-live.ps1` currently deploys the source skills both to `C:\Users\Tanner\plugins\superpowers-project` and to `C:\Users\Tanner\.agents\skills`.
- The global user-skill deployment creates unscoped prompt entries such as `$project:brainstorm-spec`, which undermines a clean plugin namespace.
- The repo's current source skills are `superpowers-project`, `setup`, `brainstorm-spec`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, and `audit-project`.
- `docs/superpowers/PROJECT_CONTEXT.md` defines this repo as the durable source for Superpowers Project workflow skills, project context, roadmap mapping, GitHub issue linkage, native user-input grilling, and goal-backed execution.
- Existing specs already cover behavior expansion for direct plan implementation. This spec only selects the public skill name `implement-plan`; it does not redefine that skill's execution contract.

## User Decisions

- Use `project` as the plugin runtime namespace.
- Keep `Superpowers Project` as the public display brand.
- Move the live plugin deployment path to `C:\Users\Tanner\plugins\project`.
- Stop copying canonical plugin skills into `C:\Users\Tanner\.agents\skills`.
- Remove old global user-skill copies after migration.
- Do not keep compatibility wrappers, forwarding skills, alias stubs, or fake defaults for old names.
- Use action-oriented skill names that read clearly under the `project:` namespace.

## Recommended Skill Surface

The canonical prompt surface should be:

- `project:initiate-workflow`: top-level router and continuation chooser, replacing `superpowers-project`.
- `project:setup-project`: project setup, tracker configuration, roadmap, and milestone context.
- `project:audit-project`: drift, tracker, sync, migration, and repair audit, replacing `audit-project`.
- `project:brainstorm-spec`: repo-backed brainstorming, native grilling, and loose spec creation.
- `project:write-plan`: approved spec or issue mirror to implementation plan.
- `project:create-issues`: approved scope to vertical GitHub issue mirrors and GitHub issues.
- `project:implement-plan`: direct plan implementation path that does not require issue creation.
- `project:resolve-issue`: direct current-thread resolution of one ready issue.
- `project:orchestrate-issues`: worker-thread orchestration for ready issue work.
- `project:merge-changes`: PR or branch integration, verification, cleanup, and closeout.

The source skill directories and `SKILL.md` frontmatter names should match these names without a redundant `project-` prefix.

## Migration Contract

The implementation should make `project` the only canonical plugin namespace.

`.codex-plugin/plugin.json` should change the plugin runtime `name` to `project` while keeping the human-facing display name as `Superpowers Project`. Documentation can continue to describe the package as Superpowers Project.

`scripts/sync-live.ps1` should deploy the plugin to `C:\Users\Tanner\plugins\project`. It should stop copying active skills into `C:\Users\Tanner\.agents\skills`. It should remove previously deployed, repo-owned global user-skill directories for the retired names.

The migration should remove the old live plugin root `C:\Users\Tanner\plugins\superpowers-project` only after verifying it is owned by this plugin. It should also keep any retired `milestones` cleanup behavior that is still needed by current install drift checks.

Docs, tests, scenario scripts, validation scripts, and default prompts should use the new `project:*` names. References to old names should remain only where they describe migration history or retired-name cleanup.

## Tradeoffs

The short `project` namespace is more generic than `superpowers-project`, but it matches the desired prompt autocomplete behavior and keeps the actual skill names short enough to read.

Keeping the display brand as `Superpowers Project` preserves the package identity and relationship to Superpowers while allowing a compact runtime namespace.

Removing global user-skill copies creates a cleaner prompt surface, but it means any old `$project-*` habits must be updated immediately. This is acceptable because compatibility wrappers would create the exact stale indirection this repo's rules reject.

Renaming `audit-project` to `audit-project` makes the skill clearer in autocomplete. The name is less terse than `doctor`, but it better describes read-only drift and tracker checks.

`implement-plan` is preferred over `execute-plan` because it avoids confusion with `superpowers:executing-plans` while still signaling that the skill is the project-level direct implementation path.

## Non-Goals

- Do not implement the migration in this spec.
- Do not rewrite the full behavior contract for `implement-plan`.
- Do not create compatibility wrappers for old skill names.
- Do not keep duplicate active skill copies in the global user-skill folder.
- Do not rename the public package away from Superpowers Project.
- Do not create new canonical artifact roots outside `docs/superpowers`.

## Milestone Linkage

- `M1 - Source Of Truth`: plugin namespace, source skill names, live deployment path, stale deployment cleanup, docs and validation alignment.
- `M2 - Distribution`: public prompt surface, installation clarity, and reduced user-facing skill-name noise.

## Proof Oracle Candidates

- `.codex-plugin/plugin.json` has `name: project` and display name `Superpowers Project`.
- `skills/initiate-workflow/SKILL.md` exists and has `name: workflow`.
- `skills/brainstorm-spec/SKILL.md` exists and has `name: brainstorm-spec`.
- `skills/write-plan/SKILL.md` exists and has `name: write-plan`.
- `skills/create-issues/SKILL.md` exists and has `name: create-issues`.
- `skills/implement-plan/SKILL.md` exists and has `name: implement-plan`.
- `skills/resolve-issue/SKILL.md` exists and has `name: resolve-issue`.
- `skills/orchestrate-issues/SKILL.md` exists and has `name: orchestrate-issues`.
- `skills/merge-changes/SKILL.md` exists and has `name: merge-changes`.
- `skills/audit-project/SKILL.md` exists and has `name: audit-project`.
- `scripts/sync-live.ps1 -Validate` deploys to `C:\Users\Tanner\plugins\project`.
- `scripts/sync-live.ps1 -Validate` no longer deploys active skills to `C:\Users\Tanner\.agents\skills`.
- Old repo-owned user-skill directories such as `brainstorm-spec`, `write-plan`, `create-issues`, `resolve-issue`, `orchestrate-issues`, `merge-changes`, `audit-project`, and `superpowers-project` are removed during sync.
- Validation rejects missing source skill directories for the new canonical names.
- `README.md` and skill continuation prompts use `project:*` names.
- `rg -n "\$project-|brainstorm-spec|write-plan|create-issues|resolve-issue|orchestrate-issues|merge-changes|audit-project|superpowers-project" .` returns only intentional migration-history references.

## Open Questions For Planning

- Should `project:initiate-workflow` keep a separate display phrase such as "Superpowers Project Workflow" inside docs and prompts, or should prompts use only the compact skill name?
- Should the implementation plan migrate every skill directory in one change, or split runtime namespace and skill-name migration into separate validation steps to reduce blast radius?
- Should the live sync script remove the old `C:\Users\Tanner\plugins\superpowers-project` directory in the same pass or report it first for a follow-up Doctor repair?

## Spec Self-Review

- Placeholder scan: no placeholder text remains.
- Consistency check: the spec treats `project` as runtime namespace and `Superpowers Project` as display brand throughout.
- Scope check: the artifact is a migration contract, not an implementation plan.
- Ambiguity check: old-name compatibility policy is explicit: remove old names without wrappers.


