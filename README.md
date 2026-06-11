# Superpowers Project Plugin

Superpowers Project is a local Codex plugin and skill family that extends Superpowers with GitHub-backed project management:

- durable project context under `docs/superpowers`;
- roadmap and milestone pages;
- native question UI for grilling assumptions;
- GitHub issue mirrors and milestone linkage;
- native `/goal` issue resolution with Superpowers execution skills.

This repository is the canonical source. The live Codex install is a deployment target.

## Public Identity

The canonical plugin identity is `superpowers-project`, the GitHub repository is `tannerpolley/superpowers-project`, and the canonical user-facing prompt surface is `$superpowers-project:*`.

## Current Skills

- `$superpowers-project:initiate-workflow`: routes extension workflows.
- `$superpowers-project:setup-project`: creates and maintains project setup, context, milestone pages, tracker config, and approved GitHub Project board evidence.
- `$superpowers-project:brainstorm-spec`: runs Superpowers brainstorming with native grilling.
- `$superpowers-project:write-plan`: writes Superpowers implementation plans with project context.
- `$superpowers-project:implement-plan`: implements an approved plan on a development branch without creating GitHub issue mirrors.
- `$superpowers-project:create-issues`: creates GitHub issue mirrors and GitHub issues from approved plans/specs.
- `$superpowers-project:resolve-issue`: resolves one issue directly in the current thread with native `/goal` and Superpowers execution.
- `$superpowers-project:orchestrate-issues`: creates and manages worker-thread issue resolution with aligned thread title, branch name, worktree identity, and PR-ready handoff evidence.
- `$superpowers-project:merge-changes`: reviews and merges issue-backed PR work or approved local branch work, cleans owned branches and worktrees, prunes, and records clean repo proof.
- `$superpowers-project:audit-project`: reviews code or workflow behavior and writes P-coded repair findings specs.
- `$superpowers-project:align-project`: aligns project, GitHub, migration, tracker, and live-sync drift.

## Native Q&A Workflow

The main workflow is a chain of small native Codex questions. Each skill summarizes what it produced, asks `Continue?`, and then starts the selected next skill automatically. The top-level closeout options are always `Yes`, `Revisit`, and `Stop`. When `Yes` has multiple possible next skills, the agent asks a nested route question after `Yes` is selected. Nested Yes menus list only forward routes, nested Revisit menus list only review, revision, repair, recovery, rerun, or evidence routes, and terminal options are not repeated inside those nested route menus.

![Native Q&A main workflow flowchart](docs/assets/native-qa-main-flow.svg)

GitHub can also render the simplified Mermaid companion: [Native Q&A main flow Mermaid](docs/assets/native-qa-main-flow-mermaid.md).

`Stop` pauses a continuation loop before verified completion. `Done` is reserved for a verified final clean state, such as an explicit merge final gate or explicitly asked healthy audit gate with passing proof. `Yes` choices enter the next workflow depth and either start the next skill or ask the next route question. Revisit choices such as `Review First`, revise, repair, or gather evidence must show the relevant artifacts or evidence, ask follow-up questions, and return to the originating continuation gate.

The recommended option should be `Yes` when a safe forward route exists and `Revisit` when evidence or repair is needed. `Stop` may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion.

Before any closeout, push, publish, or merge question, the agent must show the artifacts first. It must show what was created or revised, not merely say something changed. This includes the chosen brainstorm design/spec, full plan task and step list, created issue bodies or mirrors, full changed-artifact inventory for implementation routes, exact test values/results, cleanup evidence, branch or PR proof, and machine-readable ledgers when present. After artifacts are shown, the agent must add its own findings summary: what was done, what was fixed, what remains unsatisfactory or risky, its feedback/opinion, active-goal impact, broader project impact, and the recommended next route.

| Native question | Where it appears | Top-level choices | Nested examples |
| --- | --- | --- | --- |
| `project_setup_next_step` | After Setup Project | Yes, Revisit, Stop | Brainstorm Spec, Write Plan, Create Issues, Run Align |
| `project_brainstorm_next_step` | After Brainstorm Spec | Yes, Revisit, Stop | Manual Planning, Auto Mode, Revise Spec |
| `project_plan_next_step` | After Write Plan | Yes, Revisit, Stop | Create Issues, Implement Plan, Resolve Issue, Orchestrate Issues |
| `project_implement_next_step` | After Implement Plan | Yes, Revisit, Stop | Merge Changes, Review Evidence, Revise Branch |
| `project_issue_next_step` | After Create Issues | Yes, Revisit, Stop | Resolve Issues, Orchestrate Issues, Repair Issue Mirrors |
| `project_issue_resolution_route` | Before issue implementation when route is ambiguous | Resolve, Orchestrate, Review First | Direct current-thread work or worker-thread worktree |
| `project_resolve_next_step` | After direct issue work is PR-ready | Yes, Revisit, Stop | Merge, Resolve Another, Address CI / Checks |
| `project_orchestrate_next_step` | After worker-thread issue work is PR-ready | Yes, Revisit, Stop | Merge, Recover Worker |
| `project_merge_approval` | Before merge | Merge, Decline | Premerge evidence review |
| `project_merge_next_step` | After merge closeout | Yes, Revisit, Stop; `project_merge_final_health_gate` uses Done, Revisit, Stop | Align, Resolve Another, Re-run Cleanup |
| `project_audit_next_step` | After a findings audit | Yes, Revisit, Stop | Write Plan, Create Issues, Review Findings |
| `project_align_next_step` | After an alignment check | Yes, Revisit, Stop | Apply Repair, Create Planning Spec, Run Align Again |
| `project_align_final_health_gate` | After verified healthy alignment proof | Done, Revisit, Stop | Terminal Done only after clean audit proof |

## Implement Plan

`$superpowers-project:implement-plan` is the direct execution path after `$superpowers-project:write-plan` when an approved plan without a GitHub issue should be implemented without GitHub issue mirrors.

Implement Plan uses a development branch, native `/goal` where applicable, Superpowers execution discipline, focused verification, and `$superpowers-project:merge-changes` in local-branch mode for final integration. It does not create issue mirrors, does not open pull requests, and must not claim GitHub issue closure. Use the issue-backed `$superpowers-project:create-issues` route first for non-trivial work that should have GitHub issue and milestone backbone.

## Canonical Layout

```text
.codex-plugin/plugin.json
skills/<skill-name>/
scripts/install.ps1
scripts/sync-live.ps1
scripts/validate.ps1
docs/superpowers/PROJECT_CONTEXT.md
docs/superpowers/specs/
docs/superpowers/plans/
docs/superpowers/issues/
docs/superpowers/milestones/
```

`skills/` contains the full skill implementations and is the only skill source root.

The retired Milestones artifact model is migration history only. New Superpowers Project artifacts should not be written under the old Milestones issue or idea folders, root-level issue folders, root-level plan folders, or milestone-local plan folders.

## Validate

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Agent Version Tracking

At Superpowers Project startup, agents should print a concise version banner before selecting a workflow route:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent
```

Use the JSON version tracker when an agent needs machine-readable proof of the exact Superpowers Project plugin copy it is using:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -RequireCurrent
```

The checker reports the manifest version, source commit, and runtime `contract_hash` for source, live install, local cache candidates, and an optional observed plugin or skill root. If an agent has an observed skill root from its loaded context, pass it explicitly:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -ObservedSkillRoot <loaded-skill-root> -RequireCurrent
```

If source and live are current but the observed surface differs, run validated live sync. Live sync refreshes the live user install and matching local plugin cache roots that already exist, so existing threads can see updated files when they re-read plugin skill bodies. It cannot rewrite prompt text already loaded into an agent context; if the observed surface still differs after sync, start a fresh agent session.

## CI And Releases

GitHub Actions runs the same validation command used locally:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Release gates and tag rules are documented in `docs/superpowers/RELEASE_POLICY.md`. The first release after this migration is `v0.2.0`.

## Sync To Live Codex Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

The sync script deploys this repo's plugin manifest and full skill implementations to:

- `C:\Users\Tanner\plugins\superpowers-project`

It also deploys only the shared helper skill to:

- `C:\Users\Tanner\.agents\skills\advanced-user-input`

By default, the same command also refreshes matching existing local plugin cache candidates for this plugin. Use `-SkipCacheRefresh` only when intentionally validating the live install without updating already-materialized cache copies.

## Install

From a local clone:

```powershell
git clone https://github.com/tannerpolley/superpowers-project.git
cd superpowers-project
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

After install, start with `$superpowers-project:initiate-workflow` in Codex to route setup, brainstorming, code/workflow audits, planning, issue creation, issue resolution, orchestration, merge cleanup, or alignment checks.
