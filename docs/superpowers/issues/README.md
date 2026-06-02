# Superpowers Project Issue Mirrors

Issue mirrors are local, auditable copies of GitHub issue bodies. They link tracker work to source specs, source plans, milestones, acceptance criteria, proof oracles, and native `/goal` execution.

Use this path for new mirrors:

```text
docs/superpowers/issues/<issue-number>-<slug>.md
```

Before GitHub publication, use a slug-only file with `Pre-Publication: true`. After publication, rename the file to include the GitHub issue number and update the `GitHub Issue` field.

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

These fields tell `$resolve-issue-with-goal` how to ask the runtime execution question and who owns integration. Missing fields are migration drift; malformed values should be fixed before GitHub publication.
