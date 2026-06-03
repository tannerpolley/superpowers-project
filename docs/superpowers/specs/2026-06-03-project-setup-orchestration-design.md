# Project Setup And Orchestration Design

## Context Evidence Used

This spec captures new workflow direction from the June 3, 2026 orchestration session. It builds on:

- `docs/superpowers/PROJECT_CONTEXT.md`, which currently names the large-context skill as `project-context` and keeps GitHub Projects dashboard behavior optional.
- `docs/superpowers/specs/2026-06-02-resolve-issue-orchestrator-workflow-design.md`, which added runtime inline-versus-worker choice inside `project-resolve`.
- `docs/superpowers/specs/2026-06-02-project-workflow-hardening-design.md`, which made native UI gates, generated evidence, closed mirror cleanup, Project Doctor drift checks, and Quick Apply first-class.
- The current live worker-thread run, where worktree creation works best when the orchestrator starts from `main`, omits unsupported model overrides, gives the worker an explicit topology decision, and records thread id, worktree path, branch, issue URL, and PR URL.

The current skill set is:

- `project-context`
- `project-brainstorm`
- `project-plan`
- `project-issue`
- `project-resolve`
- `project-merge`
- `project-doctor`
- `superpowers-project`

## User Decisions

- Rename `project-context` to `project-setup`.
- Solidify orchestrator-created worktree threads so the visible app thread name, branch name, worktree handoff, issue slug, and PR-ready evidence all use the same issue identity.
- Add a new skill named `project-orchestrate` for worker-thread orchestration.
- Narrow `project-resolve` to the current-thread issue-resolution path.
- Add GitHub Project board creation and synchronization to `project-setup` so milestones and issues can be tracked in a board-style view.

## Problem

The plugin currently has the right ingredients, but ownership is becoming blurred:

- `project-context` sounds like passive documentation even though the skill actually creates and maintains project infrastructure.
- `project-resolve` now contains both inline issue execution and orchestrated worker-thread execution, which makes the skill harder to reason about and test.
- Orchestrator-created worker threads are functional, but their visible thread titles, branch names, and issue identities can drift because the identity contract is only implied in prompts.
- GitHub Projects are mentioned as dashboard evidence only, but the user now wants the setup layer to create and maintain a board-like tracker for milestones and issues.
- External GitHub issues can be created by other agents before a local mirror or source plan exists, so orchestration needs a clear intake rule before execution starts.

## Recommended Approach

Split project infrastructure setup, worker orchestration, and inline issue resolution into distinct skills:

- `project-setup`: create and maintain durable project infrastructure.
- `project-orchestrate`: create and manage worker-thread issue execution.
- `project-resolve`: resolve one ready issue in the current thread.

This keeps names aligned with responsibility. It also removes the hidden fork inside `project-resolve`: if the user wants a worker thread, use `project-orchestrate`; if the user wants the current thread to implement the issue directly, use `project-resolve`.

## Skill Ownership

### project-setup

`project-setup` replaces `project-context`.

It should own:

- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/milestones/`
- required `docs/superpowers/specs`, `plans`, and `issues` roots
- GitHub tracker configuration docs under `docs/agents/`
- GitHub milestone verification
- GitHub Project board creation and configuration
- live source-to-deployed setup checks when relevant

The rename should be direct. Long-term duplicate aliases should be avoided. If a short migration note is needed, it should point agents to `project-setup` and the old deployed `project-context` copy should be removed during live sync.

### project-orchestrate

`project-orchestrate` is the worker-thread route for issue implementation.

It should own:

- validating one ready issue mirror and linked source plan before worker creation;
- creating or reusing the native `/goal` for the issue;
- deriving a stable issue identity from issue number plus slug;
- creating the Codex worktree thread from `main`;
- sending the worker a complete handoff with topology already decided;
- monitoring worker progress;
- collecting PR-ready handoff evidence;
- routing the finished PR to `project-merge`.

`project-orchestrate` should not implement code itself except for tiny recovery edits explicitly approved by the user. Its main job is management, delegation, evidence collection, and review handoff.

### project-resolve

`project-resolve` becomes the current-thread route for one ready issue.

It should own:

- validating the issue mirror and source plan;
- activating native `/goal`;
- creating or verifying the issue branch in the current thread/worktree;
- applying TDD, Superpowers execution, verification, and branch finishing;
- pushing the branch and opening a PR;
- handing PR-ready evidence to `project-merge`.

It should not ask the inline-versus-worker topology question. That choice moves up to the router or the user's selected skill:

- worker route: `project-orchestrate`
- current-thread route: `project-resolve`

## Orchestrated Worktree Identity Contract

Every orchestrated worker run should use one canonical issue identity:

```text
issue-<number>-<slug>
```

Example:

```text
issue-10-project-doctor-audit-gate
```

Derived names should be consistent:

- App thread title: `Resolve #10: Project Doctor audit gate`
- Branch: `codex/issue-10-project-doctor-audit-gate`
- Worker handoff label: `issue-10-project-doctor-audit-gate`
- Temp evidence folder: `project-orchestrate-issue-10-project-doctor-audit-gate`
- PR title: imperative title that still names or closes issue `#10`

Existing issue mirrors can keep older branch names during migration, but new mirrors should prefer the issue-numbered branch format. The branch name should be written into the mirror before execution so the worker, setup ledger, PR, and cleanup scripts all agree.

## Worker Thread Creation Protocol

The orchestrator should create worker threads with these rules:

1. Start worktrees from `main` or the synced default branch, not from a feature branch that may not exist yet.
2. Do not pass a model override unless the app confirms that model is supported for the account.
3. Include the required branch name in the initial prompt.
4. Immediately send a topology follow-up that states the worker should use the current delegated worktree and should not wait on the native topology question.
5. Record the pending worktree id, final thread id, worktree path, branch, issue URL, issue mirror, source plan, goal objective, and proof oracle.
6. Require the worker to push the branch and open a PR that closes the exact issue.
7. Keep merge ownership in the main orchestrator through `project-merge`.

The setup ledger should include a structured worker identity block:

```json
{
  "worker_identity": {
    "issue_number": 10,
    "issue_slug": "project-doctor-audit-gate",
    "canonical_id": "issue-10-project-doctor-audit-gate",
    "thread_title": "Resolve #10: Project Doctor audit gate",
    "branch": "codex/issue-10-project-doctor-audit-gate",
    "worktree_path": "C:/Users/Tanner/.codex/worktrees/<id>/milestones-plugin"
  }
}
```

Plain prompt text should not be the only source of this identity.

## GitHub Project Board Setup

`project-setup` should be able to create or verify a GitHub Project board for the repo.

The board should track:

- GitHub milestones
- GitHub issues
- issue state
- labels
- assignee when available
- linked PR when available
- local mirror path when available
- source spec and source plan when available

Recommended default views:

- Roadmap by milestone
- Board by status
- Ready issues
- In progress worker threads
- PR-ready waiting for merge
- Closed issues by milestone

Remote tracker mutation must use native approval when `request_user_input` is callable. `project-setup` should summarize what it will create or change before creating a GitHub Project, adding fields, or bulk-linking issues.

`docs/superpowers/PROJECT_CONTEXT.md` should record the GitHub Project URL or id after setup. `docs/agents/project-roadmap.json` should record enough config for Doctor to audit drift.

## External GitHub Issue Hydration

External agents may create GitHub issues that follow the project issue template but do not create local mirrors or source plans.

Those issues should be treated as intake, not as ready execution inputs.

Protocol:

1. Read the GitHub issue body.
2. Create a local mirror under `docs/superpowers/issues/<number>-<slug>.md`.
3. Preserve the GitHub issue URL, milestone, labels, branch policy, acceptance criteria, proof oracle, and goal command.
4. If `Source Spec` or `Source Plan` is `TBD`, create a defensible spec or plan from the issue body and repo context before execution.
5. Update the mirror and, when appropriate, the GitHub issue body to link the new artifact.
6. Only then route to `project-resolve` or `project-orchestrate`.

This rule prevents workers from bypassing the local source-of-truth contract.

## Router Behavior

`superpowers-project` should route as follows:

- setup, adoption, tracker board creation, project map repair: `project-setup`
- idea/spec/PRD shaping: `project-brainstorm`
- implementation plan creation: `project-plan`
- issue and mirror creation: `project-issue`
- current-thread implementation of one ready issue: `project-resolve`
- worker-thread implementation of one ready issue: `project-orchestrate`
- PR review/merge/cleanup: `project-merge`
- drift audit and repair approval: `project-doctor`

When a user says "resolve this issue" without specifying inline or worker, the router can ask a native UI question that chooses:

- `Project Orchestrate`: use a worker worktree thread.
- `Project Resolve`: resolve in this current thread.
- `Review First`: stop after showing the issue context.

## Tradeoffs

Splitting `project-orchestrate` out of `project-resolve` adds one skill, but it removes a larger conceptual fork from the resolver. The orchestrator skill can focus on native thread mechanics, worktree identity, progress monitoring, and PR handoff, while the resolver can be simpler and more testable.

Renaming `project-context` to `project-setup` creates a migration step, but the new name is more accurate. The skill does not merely document context; it establishes the repo's project system and tracker backbone.

Adding GitHub Project board setup makes the extension more opinionated. The board should be created only after native approval and should remain an integration surface for GitHub issues, not a replacement for specs, plans, issue mirrors, or milestone pages.

## Non-Goals

- Do not keep a permanent `project-context` compatibility wrapper.
- Do not make worker orchestration the only way to resolve issues.
- Do not let worker threads merge their own PRs by default.
- Do not make GitHub Projects the canonical source of specs, plans, or issue mirrors.
- Do not create duplicate nested milestone-owned copies of specs, plans, or issues.
- Do not bypass local mirror and source plan requirements for external GitHub issues.
- Do not introduce GoalBuddy boards into the default workflow.

## Milestone Linkage

Primary milestone:

- `M1 - Source Of Truth`: skill naming, canonical artifact ownership, GitHub Project board linkage, external issue hydration, and branch/thread identity.

Secondary milestone:

- `M0 - Governance`: orchestration contracts, worker lifecycle rules, native approval for remote tracker mutation, and validation gates.

## Proof Oracle Candidates For Later Planning

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-setup\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-orchestrate\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\superpowers-project\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-superpowers-project-repo-contract.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- A fixture proving `project-context` has been replaced by `project-setup` in source, manifest validation, README, router metadata, and live sync output.
- A fixture proving `project-orchestrate` derives thread title, branch, worker identity, and evidence folder from one canonical issue identity.
- A fixture proving externally created GitHub issue bodies with `Source Plan: TBD` are hydrated into local mirrors plus source plans before execution.
- A fixture proving `project-setup` records GitHub Project board config and Doctor can audit that config.

## Open Questions For Planning

- Should the new branch format be required immediately for all new issues, or introduced as a migration for newly published mirrors only?
- Should `project-setup` create the GitHub Project board by default for GitHub-linked repos, or only when the user explicitly selects a board setup option?
- Should `project-orchestrate` create the native goal in the orchestrator thread only, or allow worker-owned goals for fully delegated runs later?

## Self-Review

- No unresolved placeholders remain; `TBD` appears only as the quoted external GitHub issue field value that triggers hydration.
- The spec keeps artifacts under `docs/superpowers`.
- The new names map directly to clear responsibilities.
- Worker-thread naming, branch naming, and evidence naming share one canonical issue identity.
- GitHub Project board setup is added without making the board the canonical artifact source.
- External issue hydration is included because issue #15 exposed that workflow gap during this session.
