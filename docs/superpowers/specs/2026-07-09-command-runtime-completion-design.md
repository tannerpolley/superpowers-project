# Command Runtime Completion Design

## Purpose

Complete the Linux command runtime so every shipped launcher performs its named behavior, every public launcher is exercised through the same dispatch path that users call, and Auto or Looping work records production workflow state rather than test-only state.

## Project Context Evidence

- The plugin is a project-lifecycle Adapter over Superpowers methods, with canonical project artifacts under `docs/superpowers`.
- The current Bash launchers route through `scripts/lib/run-script.sh` into `scripts/lib/superpowers_project_cli.py`.
- The literal registry prevents path drift, but 49 entries target `command_unimplemented`; 46 of those entries are public dispatch wrappers.
- The CLI contains 23 substantive command Implementations that are not registered.
- `workflow_state.py` and `workflow_policy.py` pass focused tests but production route launchers do not use their Interface.

## Design Alternatives

### Design 1: Complete and deepen the existing runtime

Keep Bash as the stable public Adapter, replace placeholder registry mappings with substantive handlers, split the monolithic Python Implementation into focused Modules, and add one production Workflow Runtime Interface over policy plus event replay.

Tradeoff: this touches the central dispatch path, so the test surface must exercise every launcher before cutover. It preserves the current installation and skill namespace while improving Depth and Locality.

### Design 2: Repair registry mappings only

Map existing handlers and leave the monolithic CLI, test-only workflow ledger, and shallow validation structure unchanged.

Tradeoff: this removes the loudest failures with less code movement, but it leaves workflow safety and maintainability gaps that the audit identified.

### Design 3: Replace the runtime

Create a new command runtime and migrate every launcher at once.

Tradeoff: the resulting Interface could be smaller, but the cutover would discard working provenance, installation, and validation behavior and would expand risk without adding user value.

## Selected Design

Design 1. It preserves the proven launcher and marketplace Interfaces, deepens the Python Modules behind them, and makes the event ledger part of real execution.

## Architecture

The Bash launcher remains a narrow Adapter. A typed command catalog becomes the dispatch Seam and names the handler, command kind, mutation class, and smoke-fixture strategy for every public launcher. Focused command Modules own validation, project workflow, issue/merge, and distribution Implementations. A Workflow Runtime Module owns authorization, event append, deterministic replay, scoped completion, and all second-candidate gates.

The external Interface remains compatible: existing launcher paths and PowerShell-style flags continue to work. The internal cutover deletes the generic placeholder handler and removes handler definitions from the monolithic CLI after their focused Module owns them.

## Modules

### Command Catalog Module

- Owns the complete launcher-to-handler map.
- Rejects duplicate paths, missing launchers, missing handlers, placeholder handlers, and unknown command kinds.
- Supplies dispatch-probe metadata so every Bash Adapter can be executed safely in a contract test.

### Command Modules

- `commands/validation.py` owns source and artifact validators.
- `commands/workflow.py` owns workflow mode, authorization, run-state, and candidate operations.
- `commands/project.py` owns project setup, backlog, worker handoff, issue, and merge evidence operations.
- `commands/distribution.py` owns version, provenance, sync, installation, and release checks.
- `superpowers_project_cli.py` retains argument parsing, Context creation, JSON receipt formatting, and dispatch only.

### Workflow Runtime Module

- Starts one run under `.superpowers/runs/<run-id>`.
- Validates the selected governance profile and immutable authorization.
- Appends hash-chained events for selection, mutation, acceptance, verification, budget recheck, continuation, block, and completion.
- Produces `run.json` only by replaying `events.jsonl`.
- Enforces one-route Auto scope and one-candidate-per-iteration Looping scope.

### Command Surface Test Module

- Executes every public launcher with a dispatch probe.
- Executes at least one behavioral fixture for every distinct handler.
- Runs accepted and rejected fixtures for mutation and proof gates.
- Fails when a launcher routes to a generic failure, an unrelated phase, or a handler without behavior evidence.

## Data Flow

1. A skill invokes a stable Bash launcher with an explicit project root.
2. `run-script.sh` locates the immutable plugin root and invokes the Python dispatcher.
3. The command catalog resolves the exact plugin-relative launcher path.
4. The dispatcher constructs separate plugin and project Context values.
5. The focused command Module validates inputs and performs the named operation.
6. Workflow operations call the Workflow Runtime Module before and after mutation.
7. The command emits one structured JSON receipt with exact evidence or a nonzero loud failure.

## Error Handling

- Unknown launcher paths fail before handler invocation.
- Missing handler definitions fail catalog validation.
- Placeholder mappings are forbidden by the catalog test.
- Project paths outside the consumer repository fail before reads or writes.
- Missing authorization, invalid provenance, unsupported transitions, and incomplete proof fail before mutation.
- A failed handler emits its own named phase; the dispatcher does not convert failure into success.

## Testing

- Registry unit tests cover path discovery, unique entries, handler existence, command kinds, and placeholder rejection.
- Launcher contract tests execute all public Bash Adapters through a non-mutating dispatch probe.
- Handler behavior tests cover every distinct Implementation with accepted and rejected fixtures.
- Workflow runtime tests use the public Interface and verify deterministic replay, tamper detection, scoped completion, and second-candidate blocking.
- The full `./scripts/validate.sh` suite remains the final source gate.

## Non-Goals

- Renaming the public `superpowers-project:*` skill namespace.
- Replacing Bash launchers with another user-facing command form.
- Creating GitHub issues or pull requests for this local implementation route.
- Adding compatibility wrappers for removed placeholder behavior.

## Proof Oracle Candidates

- No registry entry targets a generic failing handler or another placeholder.
- Every public launcher passes its dispatch probe.
- Every distinct handler has behavioral evidence.
- Direct invocation of `scripts/validate-workflow-contract.sh` exits zero on the repository.
- Auto and Looping production operations create replayable hash-chained event ledgers.
- `./scripts/validate.sh` exits zero.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Runtime direction | User-authorized Auto Mode plus audit evidence | Deepen the existing Bash-to-Python runtime | Preserves installed Interfaces while completing behavior | No | Plugin maintainer |
| Public command behavior | Direct launcher reproduction | Every shipped launcher performs its named behavior or is deleted | Removes misleading public paths and generic failure mappings | No | Runtime owner |
| Runtime organization | Architecture audit | Split focused command Modules behind one command catalog Interface | Improves Locality without changing launcher paths | No | Runtime owner |
| Workflow evidence | Existing workflow_state and workflow_policy tests | Integrate both Modules into production route operations | Makes autonomy proof executable rather than test-only | No | Workflow owner |
| Test scope | User request to address all revisions | Execute every public Adapter and behavior-test every distinct handler | Prevents the top-level-suite versus direct-launcher mismatch | No | Validation owner |
| Compatibility | Repository hard rules | Delete obsolete paths instead of adding compatibility wrappers | Keeps the cutover explicit and avoids dead indirection | No | Plugin maintainer |
