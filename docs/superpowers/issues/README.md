# Superpowers Project Issue Mirrors

Issue mirrors are local, auditable copies of GitHub issue bodies. They link tracker work to source specs, source plans, milestones, acceptance criteria, proof oracles, and native `/goal` execution.

Use this path for new mirrors:

```text
docs/superpowers/issues/<issue-number>-<slug>.md
```

Before GitHub publication, use a slug-only file with `Pre-Publication: true`. After publication, rename the file to include the GitHub issue number and update the `GitHub Issue` field.

Issue mirrors are flat canonical artifacts. Do not create canonical mirrors under `docs/superpowers/milestones/<milestone>/issues`. Milestone pages are index views that link back to this directory.

## GitHub Intake Issues

GitHub issues created outside the local Superpowers Project workflow are intake records until a local mirror and source plan exist. A GitHub issue URL, raw issue body, or `Source Plan: TBD` field is not a ready execution mirror.

Hydrate external intake through `$superpowers-project:create-issues` with `skills/create-issues/scripts/hydrate-external-issue.ps1`. Hydration preserves the GitHub issue URL, title, milestone, labels, branch/worktree policy, acceptance criteria, proof oracle, and goal command, then creates or links a source plan under `docs/superpowers/plans`.

`$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues` must wait until the hydrated mirror passes `skills/create-issues/scripts/validate-issue-mirror.ps1`.

## Workflow Metadata

New issue mirrors should include:

```markdown
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only
```

These fields tell `$superpowers-project:resolve-issue` how to ask the runtime execution question and who owns integration. Missing or malformed workflow metadata is blocking for every issue mirror.

## Project Merge Metadata

New issue mirrors should include:

```markdown
## Project Merge

**Merge Owner:** Main thread orchestrator
**Merge Gate:** Native UI approval required
**Merge Policy:** Repo default
**Worktree Cleanup Policy:** Remove owned worktree after merge
**Orchestrator Wakeup Policy:** Worker handoff or bounded heartbeat
```

These fields tell `$superpowers-project:merge-changes` who owns final integration, when native approval is required, and what cleanup evidence must exist after merge.

## Closed Mirror Lifecycle

Issue mirrors are execution inputs, not the durable historical record. While an issue is open, its mirror stays under `docs/superpowers/issues/` so `$superpowers-project:resolve-issue`, `$superpowers-project:merge-changes`, and `$superpowers-project:audit-project` can audit source plan linkage, acceptance criteria, proof oracles, and native goal setup.

After `$superpowers-project:merge-changes` verifies that the linked GitHub issue is closed, the closed mirror is deleted by default. The closeout ledger must include structured mirror cleanup confirmation showing the mirror path, deletion evidence, and milestone `closed-summary` evidence.

Use this marker only for unusual mirrors that must remain as historical artifacts:

```markdown
**Mirror Retention:** Keep
```

Retained mirrors must include a retention reason in closeout evidence. `$superpowers-project:audit-project` reports closed mirrors without this marker as repairable drift.

Milestone pages keep durable closed issue history. When a mirror is deleted, the milestone page should remove the active mirror link and add a concise closed summary with both the GitHub issue link and the PR link that closed it.
