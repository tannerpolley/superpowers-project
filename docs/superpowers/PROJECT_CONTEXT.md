# Superpowers Project Context

## Durable Intent

Superpowers Project extends Superpowers with durable project context, roadmap and milestone mapping, GitHub issue and milestone linkage, native user-input grilling, and native `/goal` issue execution.

## Artifact Model

- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

Specs, plans, issue mirrors, and milestone pages are working artifacts. Remove them after their work is merged or closed unless active runtime code, validation, or an explicit retention marker requires them. GitHub and Git history retain completed-work history.

## Source-Of-Truth Roles

- `docs/superpowers/workflow-contract.yml` is the route contract for native question IDs, gate types, exact option labels, and material approval boundaries.
- `docs/superpowers/backlog/ACTIVE.md` is the active Looping Mode candidate source.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface for expected workflow shape.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence for worker orchestration.
- Runtime-included milestone receipts are current validation inputs, not general history archives.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs. `.chatgpt/**` is handoff input; `.superpowers/**` is generated runtime evidence.
- The upstream brainstorming visual companion is temporary presentation state. Its browser events are advisory and do not replace native approval.

## Roadmap And Milestones

The project roadmap uses three GitHub-backed categories:

- `M0 - Governance`: validation, guardrails, and workflow contracts that keep the plugin dependable.
- `M1 - Source Of Truth`: source/live skill alignment, artifact layout, and drift prevention.
- `M2 - Distribution`: installation, CI, release policy, and deployment proof.

GitHub milestones are the durable tracker-side grouping. Local milestone pages exist only while they actively coordinate work or supply runtime validation evidence.

## GitHub Tracker Config

- Repository: `tannerpolley/superpowers-project`
- Issue tracker: GitHub Issues, with local mirrors only while an issue is executable
- GitHub milestone policy: local pages are optional working views under `docs/superpowers/milestones/`
- GitHub Projects policy: optional dashboard evidence created or verified by `$superpowers-project:setup-project` only after native approval
- Label vocabulary: `docs/agents/triage-labels.md`
- Tracker config: `docs/agents/issue-tracker.md` and `docs/agents/project-roadmap.json`
- Hierarchy policy: GitHub Milestones carry milestone identity, parent/sub-issue links carry optional grouped-work hierarchy, and issue titles stay clean.
- Hierarchy labels: `type:issue-set`, `type:sub-milestone`, and `type:plan-wrapper` identify rollup issues when hierarchy is enabled.

## Execution Model

Issue implementation uses native `/goal` or goal tools plus Superpowers execution skills. `$superpowers-project:resolve-issue` is the direct current-thread route for one ready issue. `$superpowers-project:orchestrate-issues` is the worker-thread route when the current thread should manage a dedicated worktree worker. PR integration, linked issue close verification, branch/worktree cleanup, pruning, and final clean repo proof are owned by `$superpowers-project:merge-changes`. GoalBuddy boards are outside the default execution model.

## Extension Skills

- `initiate-workflow`
- `setup-project`
- `brainstorm-spec`
- `write-plan`
- `loop-controller`
- `implement-plan`
- `create-issues`
- `resolve-issue`
- `orchestrate-issues`
- `merge-changes`
- `audit-project`
- `align-project`
