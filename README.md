# Project Truss

Project Truss is a lean GitHub-native coordination layer for coding agents. It keeps ordinary coding direct and adds durable structure only when an outcome needs publication, multiple deliverables, delegation, a milestone, or continuity beyond one safe context.

It combines three strengths without duplicating them:

- upstream Superpowers owns implementation mechanics such as brainstorming, planning, debugging, worktrees, review, and verification;
- Project Truss owns adaptive GitHub structure, ownership, re-entry, and truthful closeout;
- seven compact method cards preserve high-value reasoning patterns independently informed by [mattpocock/skills](https://github.com/mattpocock/skills) without a runtime dependency.

## Direct and governed work

Ordinary requests stay in normal Codex. They create no Project Truss artifact and ask no workflow question.

Invoke `$project-truss:start` when Project Truss is explicit or a hard continuity trigger exists. The same entry point starts new work and reconstructs current work from GitHub, Git, CI, and active worktrees.

Governed work asks at most one initial control question, and only when a material decision or authority boundary cannot be inferred.

## Adaptive GitHub shape

Project Truss creates only the structure the outcome needs:

- one mergeable unit: leaf issue plus pull request;
- several units: parent issue, leaf sub-issues, and necessary dependencies;
- coordinated release or deadline: milestone plus parent and leaves.

Ready, Claimed, In review, Blocked, and Done are derived from current provider evidence. GitHub Projects, lifecycle labels, wrapper issues, local task stores, and dashboards are not required.

## Skills

- `start` — classify direct or governed work and own one outcome;
- `shape` — create the smallest native GitHub structure;
- `deliver` — select and claim one Ready leaf, read feedback, isolate work, and route upstream execution;
- `close` — verify, merge, roll up, and retire outcome-owned artifacts;
- `advanced-user-input` — resolve material decisions and authority boundaries.

The public front door is only `$project-truss:start`.

## Source and validation

The runtime contract is in `docs/project-truss/contract.yml`; method cards and operator guidance live beside it. Validate source with:

```bash
./scripts/validate.sh
```

Installable revisions follow:

```bash
./scripts/sync-live.sh --validate
codex plugin add project-truss@personal --json
./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
```

Never edit deployed or cached plugin files directly. Start a fresh Codex session after an installable revision so current skill text and prompts load.

## Status

Project Truss 1.0.0 is a clean product cutover. Its repository and plugin identities are `tannerpolley/project-truss` and `project-truss`; no predecessor compatibility namespace is supported.

License: MIT.
