# Superpowers Project Plugin

Superpowers Project is a local Codex plugin and skill family that extends Superpowers with GitHub-backed project management:

- durable project context under `docs/superpowers`;
- roadmap and milestone pages;
- native question UI for grilling assumptions;
- GitHub issue mirrors and milestone linkage;
- native `/goal` issue resolution with Superpowers execution skills.

This repository is the canonical source. The live Codex install is a deployment target.

## Public Identity

The public project identity is `codex-superpowers-project`. The plugin runtime identity remains `superpowers-project` so the router skill stays stable.

This checkout may still be hosted under the older `milestones-plugin` repository name until the GitHub repo is renamed. New public documentation, installation paths, and plugin metadata should use Superpowers Project naming.

## Current Skills

- `$superpowers-project`: routes extension workflows.
- `$project-setup`: creates and maintains project setup, context, milestone pages, tracker config, and approved GitHub Project board evidence.
- `$project-brainstorm`: runs Superpowers brainstorming with native grilling.
- `$project-plan`: writes Superpowers implementation plans with project context.
- `$project-issue`: creates GitHub issue mirrors and GitHub issues from approved plans/specs.
- `$project-resolve`: resolves one issue directly in the current thread with native `/goal` and Superpowers execution.
- `$project-orchestrate`: creates and manages worker-thread issue resolution with aligned thread title, branch name, worktree identity, and PR-ready handoff evidence.
- `$project-merge`: reviews and merges PR-ready issue work, verifies linked issue closure, cleans owned branches and worktrees, prunes, and records clean repo proof.
- `$project-doctor`: audits project, GitHub, migration, and live-sync drift.

## Native Q&A Workflow

The main workflow is a chain of small native Codex questions. Each skill summarizes what it produced, asks one clear "what next?" question, and then starts the selected next skill automatically.

```mermaid
flowchart TD
    Start([Start<br/>$superpowers-project])
    Router["Router skill<br/>choose the right Project workflow"]

    SetupQ{"Need setup<br/>or audit first?"}
    Setup["$project-setup<br/>Initialize or refresh<br/>project context, roadmap,<br/>GitHub tracker"]
    Doctor["$project-doctor<br/>Audit drift, mirrors,<br/>repo hygiene, validation"]

    SetupNext{"Continue<br/>from setup?"}
    DoctorNext{"Continue<br/>from audit?"}

    Brainstorm["$project-brainstorm<br/>Grill assumptions,<br/>ask native Q&A,<br/>write spec"]
    BrainstormNext{"Continue<br/>from brainstorm?"}

    Plan["$project-plan<br/>Turn approved spec<br/>into implementation plan"]
    PlanNext{"Continue<br/>from plan?"}

    QuickApplyQ{"Small safe change<br/>on local main?"}
    QuickApply["Quick Apply<br/>implement narrow plan,<br/>verify, cleanup"]

    Issue["$project-issue<br/>Create GitHub issue<br/>and local issue mirror"]
    IssueNext{"Continue<br/>from issues?"}

    RouteQ{"Where should<br/>the issue be resolved?"}
    Resolve["$project-resolve<br/>Current thread implements,<br/>tests, commits, opens PR"]
    Orchestrate["$project-orchestrate<br/>Spawn worktree worker,<br/>orchestrate, review PR"]

    PRNext{"PR ready.<br/>What next?"}
    Merge["$project-merge<br/>Review PR, verify checks,<br/>merge, prune branch/worktree"]
    MergeQ{"Merge PR now?"}
    MergeNext{"Continue<br/>after merge?"}

    Review["Review first<br/>user inspects artifact"]
    Stop([Stop])

    Start --> Router --> SetupQ

    SetupQ -- "Setup" --> Setup --> SetupNext
    SetupQ -- "Doctor" --> Doctor --> DoctorNext
    SetupQ -- "No" --> Brainstorm

    SetupNext -- "Brainstorm" --> Brainstorm
    SetupNext -- "Plan" --> Plan
    SetupNext -- "Issue" --> Issue
    SetupNext -- "Doctor" --> Doctor
    SetupNext -- "Review" --> Review
    SetupNext -- "Stop" --> Stop

    DoctorNext -- "Apply repair" --> QuickApply
    DoctorNext -- "Create spec" --> Brainstorm
    DoctorNext -- "Run again" --> Doctor
    DoctorNext -- "Review" --> Review
    DoctorNext -- "Stop" --> Stop

    Brainstorm --> BrainstormNext
    BrainstormNext -- "Plan" --> Plan
    BrainstormNext -- "Revise spec" --> Brainstorm
    BrainstormNext -- "Review" --> Review
    BrainstormNext -- "Stop" --> Stop

    Plan --> PlanNext
    PlanNext -- "Issue flow" --> Issue
    PlanNext -- "Quick apply" --> QuickApplyQ
    PlanNext -- "Revise plan" --> Plan
    PlanNext -- "Review" --> Review
    PlanNext -- "Stop" --> Stop

    QuickApplyQ -- "Yes" --> QuickApply --> Stop
    QuickApplyQ -- "No, use issues" --> Issue
    QuickApplyQ -- "Stop" --> Stop

    Issue --> IssueNext
    IssueNext -- "Resolve first ready" --> RouteQ
    IssueNext -- "Resolve selected" --> RouteQ
    IssueNext -- "Review" --> Review
    IssueNext -- "Stop" --> Stop

    RouteQ -- "This thread" --> Resolve
    RouteQ -- "Worker worktree" --> Orchestrate
    RouteQ -- "Review first" --> Review

    Resolve --> PRNext
    Orchestrate --> PRNext
    PRNext -- "Merge" --> Merge
    PRNext -- "Resolve another" --> Issue
    PRNext -- "Review" --> Review
    PRNext -- "Stop" --> Stop

    Merge --> MergeQ
    MergeQ -- "Yes" --> MergeNext
    MergeQ -- "No" --> Review

    MergeNext -- "Doctor" --> Doctor
    MergeNext -- "Resolve another" --> Issue
    MergeNext -- "Review" --> Review
    MergeNext -- "Stop" --> Stop

    Review --> Router

    classDef start fill:#ef4444,color:#ffffff,stroke:#b91c1c,stroke-width:2px;
    classDef skill fill:#dbeafe,color:#111827,stroke:#2563eb,stroke-width:2px;
    classDef decision fill:#fef3c7,color:#111827,stroke:#d97706,stroke-width:2px;
    classDef quick fill:#dcfce7,color:#111827,stroke:#16a34a,stroke-width:2px;
    classDef hold fill:#f3f4f6,color:#111827,stroke:#6b7280,stroke-width:2px;

    class Start,Stop start;
    class Router,Setup,Brainstorm,Plan,Issue,Resolve,Orchestrate,Merge,Doctor skill;
    class SetupQ,SetupNext,DoctorNext,BrainstormNext,PlanNext,QuickApplyQ,IssueNext,RouteQ,PRNext,MergeQ,MergeNext decision;
    class QuickApply quick;
    class Review hold;
```

| Native question | Where it appears | Main choices |
| --- | --- | --- |
| `project_setup_next_step` | After `$project-setup` | Project Brainstorm, Project Plan, Project Issue, Project Doctor, Review First, Stop |
| `project_brainstorm_next_step` | After `$project-brainstorm` | Project Plan, Review First, Revise Spec, Stop |
| `project_plan_next_step` | After `$project-plan` | Project Issue First, Quick Apply, Review First, Revise Plan, Stop |
| `project_quick_apply_approval` | Before a small local-main change | Apply on Main, Use Issue Flow, Stop |
| `project_issue_next_step` | After `$project-issue` | Resolve First Ready, Resolve Selected, Review First, Stop |
| `project_issue_resolution_route` | Before issue implementation when route is ambiguous | Project Resolve, Project Orchestrate, Review First |
| `project_resolve_next_step` | After direct issue work is PR-ready | Project Merge, Resolve Another, Review First, Stop |
| `project_orchestrate_next_step` | After worker-thread issue work is PR-ready | Project Merge, Recover Worker, Review First, Stop |
| `project_merge_approval` | Before merge | Merge, Decline |
| `project_merge_next_step` | After merge closeout | Project Doctor, Resolve Another, Review First, Stop |
| `project_doctor_next_step` | After a Doctor audit | Apply Repair, Create Planning Spec, Run Audit Again, Review First, Stop |

## Quick Apply

Quick Apply is the small-work escape hatch after `$project-plan`: it can apply a narrow, low-risk plan directly on local clean synced `main` only after the native `project_quick_apply_approval` question selects `Apply on Main`.

Use the bundled `skills/project-plan/scripts/validate-quick-apply.ps1` gate to require approval, focused verification commands, cleanup hook evidence, and explicit push approval before any push. The issue-backed `$project-issue` and `$project-resolve` execution path remains the default for non-trivial work, risky changes, multi-issue scope, branch-backed work, and PR-bound implementation.

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

It also deploys the same skill implementations to:

- `C:\Users\Tanner\.agents\skills`

## Install

From a local clone:

```powershell
git clone https://github.com/tannerpolley/codex-superpowers-project.git
cd codex-superpowers-project
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

If you are installing from the current pre-rename repository checkout, run the same install command from that checkout root.

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

After install, start with `$superpowers-project` in Codex to route setup, brainstorming, planning, issue creation, issue resolution, orchestration, merge cleanup, or Doctor audits.
