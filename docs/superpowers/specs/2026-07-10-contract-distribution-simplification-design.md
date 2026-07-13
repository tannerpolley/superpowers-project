# Contract And Distribution Simplification Design

## Status

Approved for the lean issue #116 implementation.

## Context

The original design proposed a schema migration, generated route slices, dependency discovery, more command modules, a revision classifier, and an artifact-lifecycle subsystem. Current `main` already has the useful parts: a version-2 workflow graph, deterministic generated workflow views, focused command handlers, runtime-read validation, and canonical artifact roots.

Two distribution problems remain:

- `sync-live` copies `advanced-user-input` into the global user-skill directory even though the same skill is already shipped inside the plugin;
- the runtime package includes every spec and plan, adding about 1.1 MB of design history to the installed plugin.

Adding five new interfaces to solve those two problems would make the project larger and harder to maintain.

## Goals

1. Make normal sync/install mutate only the plugin live root and marketplace metadata.
2. Keep `advanced-user-input` plugin-scoped and leave any existing global copy untouched.
3. Ship only runtime contracts and the two source artifacts directly read by the release path.
4. Preserve stable skill names, launchers, workflow behavior, and release validation.

## Non-Goals

- Rewriting the version-2 workflow contract or generating per-skill route files.
- Adding a second dependency manifest or inspecting app-managed plugin caches.
- Building a revision classifier or artifact-lifecycle database.
- Refactoring handlers that already satisfy command-locality tests.
- Deleting a pre-existing global `advanced-user-input` directory.
- Changing Auto, Loop, execution-kernel, or workspace-isolation semantics.

## Selected Design

### Plugin-scoped sync

`skills/advanced-user-input` remains a normal `superpowers-project:` plugin skill. `sync-live` copies the runtime package to the plugin live root and updates the personal marketplace entry, but it does not create, replace, or delete anything under the supplied user-skill root.

Existing global helper copies are legacy/user-owned state. This change stops managing them; it does not remove them.

### Minimal runtime package

The runtime manifest keeps:

- plugin metadata, assets, scripts, and skills;
- workflow, lifecycle, governance, capability, project-context, generated-index, backlog, and example contracts read at runtime;
- the issue #113 release-trust spec and plan currently used as default publish-ready source artifacts.

The broad `docs/superpowers/specs/**` and `docs/superpowers/plans/**` patterns are removed. Other specs and plans remain canonical repository history but no longer affect the installed package hash.

### External Superpowers boundary

The plugin continues to name vanilla Superpowers skills through existing canonical method pairings. Codex exposes no supported plugin-dependency field in this repository's validated manifest schema, so this issue does not invent one or inspect cache directories. Runtime capability preflight remains responsible for reporting a missing required method when a route is invoked.

### Existing contract machinery

`docs/superpowers/workflow-contract.yml` remains the version-2 authority. Existing graph validation and generated `OUTCOME_WORKFLOW.md` / `WORKFLOW_ROUTE_INDEX.md` checks already prevent drift. No parallel route-slice generator is added.

## Interfaces

No new public interface is introduced.

- `scripts/sync-live.sh --validate` keeps its stable command line and stops user-skill writes.
- `.codex-plugin/runtime-package.yml` remains the single shipped-membership declaration.
- `runtime_manifest()` and `validate_runtime_reads()` continue to prove package contents.

## Error Handling

- Sync fails if source and live runtime manifests differ.
- Runtime validation fails if a required read is excluded.
- Tests fail if sync changes a sentinel global skill or recreates the helper.
- Package tests fail if a non-runtime spec/plan enters the manifest or changes its hash.

## Testing

- Extend the isolated sync test with legacy-helper and unrelated-skill sentinels.
- Assert `deployed_user_skills` is empty.
- Assert only the two release-trust source artifacts remain from specs/plans.
- Prove editing an excluded #116 design does not change the package hash.
- Run full validation, live sync validation, marketplace refresh, version proof, cleanup, and CI.

## Risks

- A user may have relied on the accidental global helper. The file is preserved; only future management stops.
- A future runtime read may require another document. `validate_runtime_reads()` fails closed until the manifest is updated explicitly.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Workflow schema | Current version-2 graph | Keep it. | Avoids a no-op migration and generated slice tree. | No | Contract owner |
| Helper namespace | Duplicate global deployment | Plugin-scoped only; preserve legacy files. | Sync no longer mutates global skill policy. | No | Distribution owner |
| Runtime history | Package inventory | Exclude broad specs/plans; retain only direct release reads. | Removes roughly 1.1 MB from installs. | No | Package owner |
| Vanilla dependency | Supported manifest schema | Keep canonical method pairings and runtime preflight. | Avoids unsupported metadata and cache probing. | No | Runtime owner |
| Revision policy | Existing strict repository loop | Keep it for installable changes. | Avoids a classifier larger than the problem. | No | Maintainer |

## Acceptance Criteria

- Normal sync leaves the complete user-skill tree byte-identical.
- `advanced-user-input` remains available inside the plugin.
- Runtime reads validate with broad spec/plan patterns removed.
- Non-runtime spec/plan edits do not change the package hash.
- Stable launchers and workflow behavior continue to pass full validation.
