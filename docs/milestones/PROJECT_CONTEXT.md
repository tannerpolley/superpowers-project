# Milestones Plugin Project Context

This repo is the canonical source for the Milestones Codex plugin and user-level skill family.

## Durable Intent

The plugin should make GitHub-backed project management fast and reliable for coding agents:

- explore broad repo ideas with native question UI;
- keep ideas and issues organized under milestone folders;
- create well-scoped GitHub issues with local issue files;
- write execution-ready issue plans;
- resolve issues through GoalBuddy, tests, PRs, merge, issue closure, and cleanup;
- compose with Superpowers for brainstorming, TDD, debugging, subagents, review, and verification.

## Artifact Model

Idea briefs belong under:

```text
docs/milestones/<milestone-folder>/ideas/
```

Local issue files belong under:

```text
docs/milestones/<milestone-folder>/issues/
```

The repo must not create new `docs/ideas`, `docs/issues`, `docs/plans`, or milestone `plans` folders.

## Required Milestones

### M0 - Governance

Repository source-of-truth rules, GitHub tracker setup, labels, issue templates, milestone docs, validation policy, and cleanup gates.

### M1 - Source Of Truth

Canonical skill content, plugin manifest, repo docs, and drift prevention between source repo, live plugin install, and user-level skill installs.

### M2 - Distribution

Install/sync scripts, validation automation, release hygiene, changelog/versioning, and GitHub repository publishing.

## Project Policy

- GitHub Issues are the tracker.
- GitHub milestones mirror this file.
- GitHub Projects are dashboard-only unless future repo config explicitly requires them.
- The live plugin and user-level skill folders are deployment targets, not source.
