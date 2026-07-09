# Superpowers Project Outcome Workflow

> Generated from `docs/superpowers/workflow-contract.yml` by `scripts/generate-outcome-workflow-summary.sh`. Do not edit by hand.

## Contract

- Plugin: `superpowers-project`
- Prompt namespace: `$superpowers-project:*`
- Workflow entrypoint: `$superpowers-project:initiate-workflow`
- Global continuation policy owner: `$superpowers-project:advanced-user-input`
- Runtime evidence: immutable authorization plus replayed `.superpowers/runs/<run-id>/events.jsonl`

## Routes

| Route | Purpose | Artifacts | Validators | Next routes |
|---|---|---|---|---|
| `align-project` | Structure alignment, migration review, tracker alignment, live sync verification, and repair planning. | `docs/superpowers/milestones`<br>`docs/superpowers/issues`<br>`docs/superpowers/plans` | `scripts/validate.sh`<br>`scripts/sync-live.sh --validate` | `write-plan`<br>`create-issues`<br>`merge-changes` |
| `audit-project` | Evidence-backed code, workflow, test, skill, or repo behavior audit findings before repair planning. | `docs/superpowers/specs`<br>`docs/superpowers/plans` | `scripts/validate.sh` | `write-plan`<br>`create-issues` |
| `brainstorm-spec` | Repo-backed ideas, specs, PRDs, architecture concepts, and broad feature requests. | `docs/superpowers/specs` | `scripts/validate.sh` | `companion-interface`<br>`write-plan` |
| `companion-interface` | Optional Agent-Native visual-plan or visual-recap review surface. | `docs/superpowers/plans` | `scripts/test-companion-interface.sh`<br>`scripts/test-agent-native-companion-preview.sh` | `brainstorm-spec`<br>`write-plan`<br>`merge-changes` |
| `create-issues` | Vertical-slice GitHub issues and synced local issue mirrors. | `docs/superpowers/issues` | `skills/create-issues/scripts/validate-issue-mirror.sh` | `resolve-issue`<br>`orchestrate-issues` |
| `implement-plan` | Approved non-issue implementation plan execution with branch-backed proof. | `docs/superpowers/plans` | `skills/implement-plan/scripts/test-scenarios.sh` | `merge-changes` |
| `initiate-workflow` | Route setup, brainstorming, audits, planning, issue creation, issue resolution, orchestration, merge cleanup, and alignment checks. | `.superpowers/runs` | `scripts/validate-workflow-mode-ledger.sh`<br>`scripts/validate-auto-mode-authorization.sh` | `setup-project`<br>`brainstorm-spec`<br>`audit-project`<br>`write-plan`<br>`create-issues`<br>`resolve-issue`<br>`orchestrate-issues`<br>`merge-changes`<br>`align-project`<br>`loop-controller` |
| `loop-controller` | Repeated workflow coordination across candidates with run ledgers, budgets, verifier proof, metrics, and continuation gates. | `.superpowers/runs` | `skills/loop-controller/scripts/validate-run-ledger.sh`<br>`skills/loop-controller/scripts/validate-budget.sh`<br>`skills/loop-controller/scripts/validate-terminal-closeout.sh` | `brainstorm-spec`<br>`write-plan`<br>`create-issues`<br>`resolve-issue`<br>`orchestrate-issues`<br>`merge-changes`<br>`audit-project`<br>`align-project` |
| `merge-changes` | Review, approve, merge, clean up, close linked issues, and record final proof for PR-ready or local branch work. | `docs/superpowers/issues`<br>`docs/superpowers/plans` | `skills/merge-changes/scripts/validate-terminal-closeout.sh`<br>`skills/merge-changes/scripts/validate-merge-decision.sh` | `write-plan`<br>`create-issues`<br>`resolve-issue`<br>`orchestrate-issues`<br>`align-project` |
| `orchestrate-issues` | Delegate a ready issue to a Codex worktree worker while the current thread reviews and integrates. | `docs/superpowers/issues`<br>`docs/superpowers/examples/worker-handoff-packets.md` | `skills/orchestrate-issues/scripts/validate-worker-handoff.sh`<br>`skills/orchestrate-issues/scripts/test-scenarios.sh`<br>`scripts/validate-worker-packets.sh`<br>`scripts/test-worker-packets.sh` | `merge-changes`<br>`resolve-issue` |
| `resolve-issue` | Direct current-thread implementation for one ready GitHub issue mirror. | `docs/superpowers/issues`<br>`docs/superpowers/plans` | `skills/resolve-issue/scripts/validate-setup.sh`<br>`skills/resolve-issue/scripts/validate-pr-ready.sh`<br>`skills/resolve-issue/scripts/validate-terminal-closeout.sh` | `merge-changes`<br>`resolve-issue`<br>`orchestrate-issues` |
| `setup-project` | Create or maintain setup, milestone map, tracker config, project board configuration, and roadmap artifacts. | `docs/superpowers/PROJECT_CONTEXT.md`<br>`docs/superpowers/milestones` | `scripts/validate.sh` | `brainstorm-spec`<br>`align-project` |
| `write-plan` | Turn approved specs or issue mirrors into detailed implementation plans. | `docs/superpowers/plans` | `scripts/validate-plan-outcome-proof.sh`<br>`scripts/validate-plan-task-use-cases.sh` | `create-issues`<br>`implement-plan`<br>`resolve-issue`<br>`orchestrate-issues` |

## Completion Scope

- `candidate`: the selected candidate has acceptance and verifier proof.
- `route`: the one authorized Auto route has closed with acceptance and verifier proof.
- `iteration`: the Looping candidate has acceptance, verifier, and budget evidence.
- `project`: reserved for explicit final health proof; route completion never implies project completion.

## Required Local Gates

- `./scripts/validate-workflow-graph.py`
- `./scripts/generate-outcome-workflow-summary.sh -Check`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate` after committed installable changes
