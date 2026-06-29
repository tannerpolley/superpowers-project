# Superpowers Project Context

## Durable Intent

Superpowers Project extends Superpowers with durable project context, roadmap and milestone mapping, GitHub issue and milestone linkage, native user-input grilling, and native `/goal` issue execution.

## Artifact Model

- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`
- Agent-Native review artifacts: `plans/<slug>/plan.mdx` with optional `canvas.mdx` or `prototype.mdx`; use visual-plan artifacts for forward-looking specs and implementation plans, and visual-recap artifacts for after-action PR, branch, validation, audit, merge, and workflow proof. These are rich review and audit surfaces, not replacements for canonical Superpowers specs, plans, issue mirrors, or milestone pages.

## Source-Of-Truth Roles

- `docs/superpowers/workflow-contract.yml` is the route contract for native question IDs, gate types, exact option labels, and material approval boundaries.
- `docs/superpowers/backlog/ACTIVE.md` is the active Looping Mode candidate source. Historical plan checkboxes, milestone receipts, and closed issue mirrors are not active candidates.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface for expected workflow shape.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence for worker orchestration.
- `docs/superpowers/milestones/*receipt*.md` files are validation receipts and milestone history.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs. `.chatgpt/**` is handoff input; `.superpowers/**` is generated runtime evidence.

## Roadmap And Milestones

The project roadmap has three active GitHub-backed milestones:

- `M0 - Governance`: validation, guardrails, and workflow contracts that keep the plugin dependable.
- `M1 - Source Of Truth`: source/live skill alignment, artifact layout, and drift prevention.
- `M2 - Distribution`: installation, CI, release policy, and deployment proof.

Milestone pages under `docs/superpowers/milestones/` are the durable project map. GitHub milestones are the tracker-side grouping. Specs, plans, and issue mirrors should link back to one of these roadmap buckets when the work is milestone-owned.

## GitHub Tracker Config

- Repository: `tannerpolley/superpowers-project`
- Issue tracker: GitHub Issues plus local mirrors under `docs/superpowers/issues/`
- GitHub milestone policy: mirrors the roadmap pages under `docs/superpowers/milestones/`
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
- `companion-interface`
- `loop-controller`
- `implement-plan`
- `create-issues`
- `resolve-issue`
- `orchestrate-issues`
- `merge-changes`
- `audit-project`
- `align-project`

## Current Open Questions

- Decide whether GitHub Projects should stay dashboard-only or become a required project-management surface.

## Decisions

- The pre-publication smoke-test issue mirror was resolved locally and should not be published as a real GitHub issue unless a future workflow explicitly needs a new smoke fixture.
