# Workflow Governance And Agent Usability Design

## Purpose

Make the workflow contract executable, reduce repeated skill policy, define truthful scoped completion, and test the plugin through fresh Codex-agent runs rather than only synthetic Python workers.

## Project Context Evidence

- `docs/superpowers/workflow-contract.yml` is the route contract for native questions and material gates.
- The current validator checks basic mappings and labels but does not enforce duplicate-ID consistency, parents, owners, artifacts, reachability, or complete terminal semantics.
- Four governance profiles exist in Python, while the planned declarative profile contract and completion claims do not exist.
- Fourteen skill files contain 3,017 lines, with global continuation and proof policy repeated across route skills.
- Current Auto and Looping trials start a Python subprocess of the test module; they do not load the plugin, select a skill, or interpret Codex instructions.

## Design Alternatives

### Design 1: One typed graph plus capability-aware thin skills

Make the workflow graph the source of truth for gates, ownership, transitions, artifacts, and validators. Generate human summaries from the graph, keep route skills focused on judgment and method pairing, and add opt-in real Codex trial execution with independently validated receipts.

Tradeoff: graph migration changes several files together, but it eliminates repeated facts and creates a strong verification Seam.

### Design 2: Expand the current validators and leave skills unchanged

Add more YAML checks without generating surfaces or slimming skill bodies.

Tradeoff: lower migration work, but duplicated policy continues to drift and future agents still load excessive route text.

### Design 3: Put all workflow logic in skill prose

Remove most machine-readable contracts and trust agent interpretation.

Tradeoff: smallest runtime Implementation, but no deterministic proof, generation, or negative testing remains.

## Selected Design

Design 1. The typed graph and capability contract provide the Depth needed to reduce prose while preserving agent-facing clarity.

## Architecture

A typed Workflow Graph Module loads and validates the canonical YAML contract. Its Interface exposes route ownership, prompts, options, parent relationships, terminal states, artifacts, validators, and transitions. A generator produces the outcome summary and route reference fragments. Governance profiles and completion claims form a second machine-readable contract consumed by the Workflow Runtime Module.

Route skills become thin judgment Adapters. Each skill retains its trigger, project ownership, required inputs, outputs, stop reasons, and Superpowers method pairing. Shared native-input, artifact-review, and terminal policy stays in `advanced-user-input`; route facts stay in the graph.

## Modules

### Workflow Graph Module

- Loads quoted option labels without YAML boolean coercion.
- Enforces one owner for each question ID.
- Allows references to an owned question only when prompt, options, parent, and terminal semantics match the owner.
- Validates parent existence, route reachability, owner skill, validator paths, artifact declarations, and terminal-state legality.
- Generates `OUTCOME_WORKFLOW.md` and a concise route index.

### Governance And Completion Module

- Loads `manual.interactive`, `auto.one-route`, `loop.bounded`, and `trial.local` profiles.
- Defines `candidate-complete`, `authorized-scope-complete`, `run-closed`, and `project-complete` claims.
- Validates which claim each profile may make from recorded events.
- Records out-of-scope work as preserved report-only state.

### Capability Contract Module

- Declares native input, goals, GitHub, threads, worktrees, Agent-Native artifacts, network, and external mutation requirements.
- Lets each route declare required and optional capabilities in metadata.
- Fails startup or route selection with an exact unsupported-capability receipt.

### Skill Policy Module

- Keeps global native question geometry in `advanced-user-input`.
- Keeps route facts in the graph.
- Keeps each route skill below a validated size target unless a reference file is justified.
- Uses canonical skill names rather than runtime deployment paths.

### Agent Usability Trial Module

- Creates disposable Git repositories with explicit trial provenance.
- Runs fresh noninteractive Codex workers through the installed plugin when the real-agent trial gate is enabled.
- Gives workers only the repo, authorization, run path, and task entrypoint.
- Uses an independent oracle verifier that does not read the worker narrative.
- Validates receipts for friction, retries, extra reads, scope deviation, user-input calls, network access, and mutation scope.

## Data Flow

1. Codex discovers a route from concise metadata and the startup prompt.
2. The route checks declared capabilities before asking or mutating.
3. The skill reads shared policy plus its graph-owned route facts.
4. User or Auto authority selects a route and completion scope.
5. The Workflow Runtime Module records events and computes allowed completion claims.
6. Documentation generators render human review surfaces from the same graph.
7. Real-agent trials load the installed plugin and validate resulting repositories plus ledgers against independent oracles.

## Error Handling

- Duplicate or conflicting question definitions fail graph validation.
- Missing parents, owners, artifacts, validators, or transitions fail before generation.
- Unsupported capabilities fail before a route begins.
- Auto Mode cannot claim more than authorized-scope completion or select another candidate.
- Looping Mode cannot select another candidate without acceptance, verification, budget, and continuation evidence.
- Trial workers that prompt, use the network, mutate outside the disposable repo, or omit a receipt fail the trial.
- Generated documentation drift fails validation instead of being silently rewritten during a check.

## Testing

- Graph fixtures cover boolean labels, conflicting duplicate IDs, wrong parents, illegal terminal options, missing owners, missing artifacts, missing validators, unreachable routes, and missing transitions.
- Generator tests compare deterministic output byte-for-byte.
- Governance tests exercise every profile and completion claim.
- Skill tests enforce capability declarations, route-size limits, and shared-policy de-duplication.
- Real-agent trial receipt tests include golden and adversarial scenarios; the default suite validates fixtures, and the release gate requires a current real-agent receipt.

## Non-Goals

- Replacing native Codex input with an HTML approval surface.
- Allowing Auto Mode to drain a queue.
- Making GitHub Projects mandatory.
- Moving judgment-heavy instructions into generated code.

## Proof Oracle Candidates

- The graph validator rejects every malformed fixture listed above.
- Generated workflow summaries match the canonical graph.
- Every skill declares capabilities and passes size and duplication checks.
- Completion claims are derived from replayed events.
- A real Codex trial receipt is tied to the current package hash and passes independent oracle validation.
- `./scripts/validate.sh` exits zero.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Contract ownership | Audit evidence and existing project context | One typed graph owns route facts | Removes drift across YAML, skills, metadata, and summaries | No | Workflow owner |
| Skill shape | User request to reduce friction | Thin route skills plus shared policy and capability declarations | Reduces prompt load while retaining judgment guidance | No | Skill owner |
| Completion language | Governance audit | Derive scoped completion claims from events | Prevents route completion from being overstated as project completion | No | Workflow owner |
| Agent testing | Current synthetic-trial evidence | Add real installed-plugin Codex trials with independent oracles | Measures actual instruction following and friction | No | Validation owner |
| Trial safety | Existing trial policy | Disposable repo, fixture provenance, no external mutation, bounded network policy | Keeps agent trials reproducible and safe | No | Validation owner |
| Documentation generation | Typed graph plan | Generate summaries but retain judgment prose in skills | Increases Leverage without making generated text own agent judgment | No | Documentation owner |

