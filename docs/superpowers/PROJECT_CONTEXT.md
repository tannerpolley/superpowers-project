# Superpowers Project Context

## Durable Intent

Superpowers Project extends Superpowers with durable project context, roadmap and milestone mapping, GitHub issue and milestone linkage, native user-input grilling, and native `/goal` issue execution.

## Artifact Model

- Specs: `docs/superpowers/specs/`
- Plans: `docs/superpowers/plans/`
- Issue mirrors: `docs/superpowers/issues/`
- Milestone pages: `docs/superpowers/milestones/`

## Roadmap And Milestones

The project roadmap has three active GitHub-backed milestones:

- `M0 - Governance`: validation, guardrails, and workflow contracts that keep the plugin dependable.
- `M1 - Source Of Truth`: source/live sync, wrapper alignment, artifact layout, and drift prevention.
- `M2 - Distribution`: installation, CI, release policy, and deployment proof.

Milestone pages under `docs/superpowers/milestones/` are the durable project map. GitHub milestones are the tracker-side grouping. Specs, plans, and issue mirrors should link back to one of these roadmap buckets when the work is milestone-owned.

## GitHub Tracker Config

- Repository: `tannerpolley/milestones-plugin`
- Issue tracker: GitHub Issues plus local mirrors under `docs/superpowers/issues/`
- GitHub milestone policy: mirrors the roadmap pages under `docs/superpowers/milestones/`
- GitHub Projects policy: dashboard evidence only unless a future repo config makes it mandatory
- Label vocabulary: `docs/agents/triage-labels.md`
- Tracker config: `docs/agents/issue-tracker.md` and `docs/agents/project-roadmap.json`

## Execution Model

Issue execution uses native `/goal` or goal tools plus Superpowers execution skills. GoalBuddy boards are outside the default execution model.

## Extension Skills

- `superpowers-project`
- `project-context`
- `project-brainstorm`
- `project-writing-plan`
- `plan-to-issue`
- `resolve-issue-with-goal`
- `project-doctor`

## Current Open Questions

- Decide whether smoke-test issue mirrors should remain pre-publication fixtures or be published as real GitHub issues.
- Decide whether GitHub Projects should stay dashboard-only or become a required project-management surface.
