# Autonomous Workflow And Codex Worktree Audit Findings

## Audit Status

This is a diagnosis and repair specification. It does not implement any finding.

The audit covers the repository as a whole, with emphasis on:

- the intended role of Superpowers Project as a Codex extension to vanilla Superpowers;
- Manual, Auto, and Looping mode semantics;
- the idea/problem/feature-to-verified-closeout lifecycle;
- native Codex task and worktree integration;
- skill routing, approval, evidence, and cleanup contracts;
- behavioral test coverage, release evidence, packaging, and maintainability.

## Successor Specifications

The audit is the umbrella diagnosis. Implementation planning should use these four non-overlapping design contracts:

1. `docs/superpowers/specs/2026-07-10-execution-kernel-release-trust-design.md` owns fail-closed evidence, lifecycle gates, behavioral proof, and publication trust.
2. `docs/superpowers/specs/2026-07-10-auto-loop-lifecycle-semantics-design.md` owns startup authority, lifecycle state, mode-aware gate resolution, issue routing, merge semantics, and finite Looping behavior.
3. `docs/superpowers/specs/2026-07-10-codex-native-workspace-isolation-design.md` owns native Codex task worktrees, vanilla fallback, detached-head handling, handoff, receipts, and cleanup ownership.
4. `docs/superpowers/specs/2026-07-10-contract-distribution-simplification-design.md` owns graph normalization, generated route slices, runtime modularization, external dependency checks, namespace isolation, revision classification, and artifact lifecycle.

Implementation order begins with the execution kernel, then lifecycle semantics, workspace isolation, and contract/distribution simplification. A plan may overlap preparatory tests, but no later specification may weaken an earlier trust boundary.

## Executive Assessment

Superpowers Project has a sound product idea and several strong low-level mechanisms, but its control plane is not yet trustworthy enough for unattended execution.

The project is best understood as a project-lifecycle layer above vanilla Superpowers:

1. vanilla Superpowers supplies implementation methods such as brainstorming, planning, TDD, debugging, verification, and branch finishing;
2. Superpowers Project supplies durable context, specs, plans, issue mirrors, GitHub linkage, goals, workflow modes, orchestration, and closeout evidence;
3. Codex supplies native questions, goals, tasks, subagents, project worktrees, and handoff operations.

The repository is strongest at artifact organization, packaging, provenance, hash-chained event replay, and documented workflow intent. It is weakest where those three layers meet. Mode authority is not consumed consistently by downstream skills, Codex task worktrees are conflated with same-checkout subagents, and several public safety validators succeed without evidence.

The user's Auto Mode expectation is coherent and should become the canonical contract:

> One upfront Auto selection authorizes one requested outcome lifecycle: understand the idea/problem/feature, create and self-review the spec, create the plan, decide whether a real issue is warranted, execute the selected route, verify it, integrate it, and stop at verified closeout without asking another question unless the work leaves the authorized envelope or becomes unsafe.

In that definition, an Auto **lifecycle** contains multiple owner-skill steps. It is not one skill invocation. Looping Mode repeats candidate lifecycles; it is not Auto with more intra-route prompts.

## Project Goal And Observable Contract

Repository evidence establishes the intended goal:

- `README.md` and `docs/superpowers/PROJECT_CONTEXT.md` define a durable project layer around Superpowers.
- `docs/superpowers/specs/2026-06-02-superpowers-project-extension-design.md` explicitly preserves vanilla Superpowers rather than replacing it.
- `docs/superpowers/workflow-contract.yml` is intended to own question and route facts.
- `docs/superpowers/governance-profiles.yml` distinguishes Manual, Auto, Looping, and trial governance.
- `scripts/lib/workflow_runtime.py` and `scripts/lib/workflow_state.py` provide append-only workflow evidence and tamper detection.
- `orchestrate-issues`, `resolve-issue`, `implement-plan`, and `merge-changes` are intended to connect planning to branch/worktree execution and verified integration.

The externally observable contract should therefore be:

| Mode | User interaction | Unit of work | Completion |
|---|---|---|---|
| Manual | Ask at material decisions and route closeouts | One user-directed lifecycle | Verified closeout or explicit Stop |
| Auto | One mode/authority selection, then no routine questions | One requested outcome lifecycle across multiple skills | Verified integration/closeout or fail-closed blocker |
| Looping | One startup mode selection and budget policy; no intra-candidate route questions | Repeated Auto-like candidate lifecycles | Budget/no-ready/final-health stop, with any configured between-candidate checkpoint |

## Reproduced Evidence

The following commands were run from the repository root.

### Full baseline validation

`./scripts/validate.sh` exited zero. It ran 60 unit tests plus the repository's shell validation surface and reported `Plugin validation passed`.

This is healthy baseline evidence, but it does not disprove the findings below because the current suite does not exercise several advertised behaviors.

### Production mode provenance rejection

Calling `validate_governance` with production-shaped startup provenance produced:

```text
auto: REJECTED: noninteractive governance cannot silently depend on request_user_input
looping: REJECTED: noninteractive governance cannot silently depend on request_user_input
```

This reproduces the conflict between a one-time native mode selection and the runtime's interpretation of noninteractive execution.

### Fail-open lifecycle gates

The following public launchers were invoked with no evidence arguments and all exited zero:

```text
./skills/resolve-issue/scripts/validate-pr-ready.sh
  -> {"ok": true, "phase": "validate-pr-ready"}

./skills/merge-changes/scripts/premerge.sh
  -> {"ok": true, "phase": "premerge"}

./skills/merge-changes/scripts/closeout.sh
  -> {"ok": true, "phase": "closeout"}

./skills/merge-changes/scripts/validate-merge-decision.sh
  -> {"ok": true, "phase": "validate-merge-decision"}
```

### Codex worktree behavior

The current Codex app exposes separate operations for:

- listing projects;
- creating a project task in `environment.type = worktree`;
- forking a task into a worktree;
- handing another task between Local and Worktree.

Current-session collaboration subagents share the same checkout and are not equivalent to these native task worktrees.

The official [Codex worktree documentation](https://developers.openai.com/codex/app/worktrees) also establishes that managed worktrees are app-owned, normally start in detached HEAD, live under `$CODEX_HOME/worktrees` by default, and use Create Branch or Handoff for later Git movement.

## Prioritized Findings

### P0 — Lifecycle approval and evidence validators fail open

**Locations**

- `scripts/lib/superpowers_project_cli.py:1432-1480`
- `scripts/lib/superpowers_project_cli.py:2304-2316`
- public launchers under `skills/resolve-issue/scripts/` and `skills/merge-changes/scripts/`

**Evidence**

The no-argument PR-ready, premerge, closeout, and merge-decision commands all returned success. Supplied ledgers are also checked too shallowly in several paths.

**Impact**

The plugin promises that Auto merge is safe because proof gates remain mandatory. That promise is false if the gates accept missing evidence. An agent can produce a green receipt without proving readiness, approval, integration, or cleanup.

**Recommended correction**

Make every mutation-adjacent validator fail closed. Require a schema-valid, provenance-bound ledger whose repository, run, candidate, branch/task, source plan, authorization hash, and evidence hashes match the active workflow. Separate collectors from validators; collectors may create evidence, validators may only inspect it.

**Verification oracle**

- Every validator fails when its required path/JSON is absent.
- Missing, stale, cross-repository, wrong-candidate, wrong-branch, tampered, incomplete, and self-contradictory fixtures fail.
- A valid end-to-end ledger passes only after the underlying commands and repository state independently match it.

### P0 — Real Auto and Looping startup provenance is rejected by the runtime

**Locations**

- `skills/initiate-workflow/SKILL.md:20-25`
- `scripts/lib/superpowers_project_cli.py:408-417`
- `scripts/lib/workflow_policy.py:41-51`
- `scripts/lib/workflow_runtime.py:72-87`
- `docs/superpowers/governance-profiles.yml:8-17`

**Evidence**

Initiation requires a native `request_user_input` selection. The Auto authorization validator permits production authority only when its source is `request_user_input`. The governance runtime then rejects `request_user_input` provenance for Auto and Looping because those profiles are noninteractive.

**Impact**

A legitimate user-selected Auto or Looping run cannot start through the production runtime contract that is supposed to govern it. Trial fixtures pass because they use separate `trial-fixture` provenance.

**Recommended correction**

Split authorization provenance from post-authorization interaction behavior:

- `authorized_by: request_user_input` proves the one-time startup selection;
- `interaction_policy: no-routine-prompts` governs downstream execution;
- append-only events record any later question attempt and cause Auto policy failure unless the run is already blocked outside its envelope.

**Verification oracle**

A production-shaped startup ledger starts Auto and Looping, while missing/forged user authorization fails. After startup, an instrumented Auto lifecycle records zero native input calls.

### P0 — Fresh-request Auto authorization requires an artifact that does not exist yet

**Locations**

- `skills/initiate-workflow/SKILL.md:22-25`
- `scripts/lib/superpowers_project_cli.py:393-420`
- `docs/superpowers/workflow-contract.yml:577-645`
- the now-superseded June 4 Auto-after-spec design, retained in Git history

**Evidence**

Initiation asks for mode and Auto authority before the owning route runs, but the Auto authorization validator requires an existing `source_spec` under `docs/superpowers/specs/`. A raw idea cannot satisfy both requirements. Historical design then reintroduced Auto after spec creation, which explains the observed second Auto prompt and current semantic drift.

**Impact**

The desired entry flow is impossible. An agent must either create invalid authority, defer authority until after the spec and ask again, silently change modes, or skip the runtime contract.

**Recommended correction**

Make `project_workflow_mode = Auto Mode` the sole user authorization decision. Bind the immutable root authorization to the request/candidate fingerprint, repository, allowed mutation envelope, and stop policy. Attach generated spec and plan paths later through hash-chained `artifact_bound` events rather than mutating or replacing the authorization ledger.

**Verification oracle**

A clean raw-idea fixture follows exactly one mode prompt, then spec, plan, route decision, implementation, verification, and closeout. No second Auto or bounded-merge question appears.

### P1 — Auto is not mode-aware downstream and cannot be question-free

**Locations**

- `skills/advanced-user-input/SKILL.md`
- `skills/brainstorm-spec/SKILL.md:14-30`
- `skills/write-plan/SKILL.md:36-38`
- `skills/implement-plan/SKILL.md:24-33`
- `skills/create-issues/SKILL.md:32-36`
- `skills/resolve-issue/SKILL.md:28-37`
- `skills/merge-changes/SKILL.md:30-39`
- corresponding gates in `docs/superpowers/workflow-contract.yml`

**Evidence**

Shared policy mandates continuation questions at every route closeout. Brainstorming requires interactive questions and approval. Implementation asks topology. Issue creation requires publication approval and explicitly refuses to infer it from Auto. Resolve asks push/PR permission. Merge asks approval unless separately preauthorized.

**Impact**

Selecting Auto does not actually produce autonomous execution. It produces Manual Mode with an extra ledger and several contradictory opportunities to stop after only a spec or plan.

**Recommended correction**

Add a mode-aware gate resolver. In Manual, it renders native questions. In Auto, it consumes the upfront authority, chooses from recorded defaults, writes a decision event with evidence and rationale, and does not render the question. The same owner-skill code should call one interface rather than embedding separate prompting behavior.

The Auto selection must explicitly authorize the current-repository mutation envelope needed for the requested outcome, including:

- specs, plans, local issue mirrors, and source edits;
- development branches;
- visible Codex worktree task creation when isolation is needed;
- a real GitHub issue when the decision rubric requires one;
- push, PR creation, and merge after required checks and fail-closed premerge proof;
- no unrelated repositories, destructive Git operations, broad queue draining, or mutation outside the requested outcome.

**Verification oracle**

Instrument `request_user_input`. After the startup mode selection, both local-plan and issue-backed Auto fixtures must record zero calls. Every auto-resolved choice must have a typed decision event and the remote scope must remain confined to the active repository.

### P1 — “One route” conflates a lifecycle with one skill step

**Locations**

- `README.md:87-90`
- `skills/initiate-workflow/SKILL.md:8,24,29`
- `docs/superpowers/examples/workflow-golden-paths.md:54-68`
- the June 4 Auto-after-spec design preserved in Git history
- `scripts/lib/workflow_runtime.py:102-137`

**Evidence**

Some sources say Auto stops at the closeout of one owner route, such as `write-plan`. Other sources describe continuous spec-to-plan-to-execution-to-merge behavior. The runtime records an opaque candidate and does not record owner-step transitions.

**Impact**

Agents can reasonably stop after a spec or plan and still believe Auto completed successfully. Others can overrun scope because “route” has no stable meaning.

**Recommended correction**

Adopt these terms consistently:

- **candidate**: the user's requested idea, problem, feature, or selected backlog item;
- **lifecycle**: all owner-skill steps required to deliver that candidate to verified closeout;
- **owner step**: one skill-owned phase such as brainstorm, plan, implement, or merge;
- **iteration**: one candidate lifecycle inside Looping Mode.

Auto authorizes one candidate lifecycle. Looping authorizes repeated candidate lifecycles under a budget.

**Verification oracle**

Expected event traces contain typed owner-step transitions such as `brainstorm -> plan -> implement -> merge` or `brainstorm -> plan -> create-issues -> resolve/orchestrate -> merge`. A second unrelated candidate is rejected in Auto.

### P1 — Auto cannot decide between issue-backed and direct execution

**Locations**

- `scripts/lib/superpowers_project_cli.py:421-436`
- `skills/create-issues/SKILL.md`
- `skills/resolve-issue/SKILL.md`
- `skills/orchestrate-issues/SKILL.md`

**Evidence**

The authorization validator hard-codes `route_policy.issue_route` to `direct-inline-resolve-issue` even though the historical Auto design says the agent chooses direct implementation or issue-backed execution. Mutation scope requires only the current repository and development branch, while issue publication and push/PR authority remain separate.

**Impact**

The stated route policy cannot represent the user's desired decision. It also prevents Auto from choosing native worker orchestration and can strand issue-backed work at the first publication gate.

**Recommended correction**

Replace a preselected issue route with a deterministic decision rubric evaluated after planning:

- use direct `implement-plan` for one coherent, locally verifiable outcome with no tracker need;
- use a real issue for milestone-owned, externally visible, risky, dependent, multi-slice, resumable, or worker-delegated work;
- record the chosen route, evidence, and rejected alternative in the Decision Ledger and runtime events.

**Verification oracle**

Fixtures at each decision boundary produce stable route choices. Both direct and issue-backed Auto lifecycles complete without prompting, and ambiguous/out-of-policy cases fail closed with exact evidence.

### P1 — Subagents are incorrectly modeled as isolated Codex worktree workers

**Locations**

- `docs/superpowers/capabilities.yml`
- `skills/orchestrate-issues/SKILL.md:10-29`
- `skills/implement-plan/SKILL.md:10-29`
- `scripts/lib/superpowers_project_cli.py:1316-1401`
- `docs/superpowers/examples/worker-handoff-packets.md`

**Evidence**

The capability contract treats `subagents` as isolated workers. Current-session subagents share the checkout. Native isolation is supplied by separate Codex project-task worktree operations. The handoff packet only says the worker creates an isolated worktree and contains no native task/worktree identity or ownership proof.

**Impact**

An orchestrator can spawn a same-checkout subagent, label it isolated, and then allow vanilla worktree fallback to create `.worktrees/`. This bypasses Codex app ownership, task visibility, Handoff, and cleanup semantics.

**Recommended correction**

Add explicit capabilities for `codex.tasks` and `codex.managed-worktrees`. Introduce a Superpowers Project `workspace-isolation` adapter used before vanilla `superpowers:using-git-worktrees`:

1. detect an existing linked or Codex-managed worktree;
2. when the root task is Local and isolated work is needed, list projects and create a project task with `environment.type = worktree` using the immutable handoff packet;
3. allow vanilla worktree handling to run inside the worker, where its existing-isolation check should skip creation;
4. use a worktree fork only when completed-history inheritance is the intended handoff;
5. use manual Git worktrees only when native capability is absent and policy explicitly allows the fallback.

This adapts vanilla behavior without editing or shadowing the vanilla skill.

**Verification oracle**

A live disposable trial records the native task/client ID, final task ID, project ID, worktree path, Git dir/common dir, provider, owner, starting ref, detached state, and handoff strategy. It proves `git_dir != git_common_dir` and proves no repository `.worktrees` path was created while native capability was available.

### P1 — Native detached worktrees conflict with the branch and cleanup contract

**Locations**

- `scripts/lib/superpowers_project_cli.py:1268-1279,1338-1401`
- `skills/merge-changes/SKILL.md:30-39`
- `docs/superpowers/examples/worker-handoff-packets.md`
- official Codex worktree documentation

**Evidence**

Codex-managed worktrees normally begin detached. Worker identity requires a named `codex/issue-*` branch immediately, but the packet has no detached-state or branch-transition receipt. Merge closeout says to remove owned worktrees without distinguishing app-owned and plugin-owned paths.

**Impact**

Valid native workers can fail an incorrect branch assumption, while cleanup can fight the app or remove state it does not own.

**Recommended correction**

Split planned branch identity from observed environment state. A native creation receipt may be detached. PR readiness must later prove Create Branch or Handoff/named-branch transition. Cleanup must dispatch by ownership:

- Codex app-owned: hand off, preserve, archive, or let the app dispose it;
- plugin manual worktree: remove only after ownership and integration proof;
- external linked worktree: never remove without separate authority.

**Verification oracle**

Negative fixtures reject an app-owned path marked for manual removal, a detached worker claiming PR readiness, and a same-checkout worker claiming isolation. Positive fixtures cover native detached creation, branch transition, Handoff, manual fallback, and existing linked worktrees.

### P1 — Scenario and fresh-agent tests overstate behavioral coverage

**Locations**

- `scripts/lib/superpowers_project_cli.py:2328-2342`
- all `skills/*/scripts/test-scenarios.sh`
- `scripts/run-agent-usability-trials.py:44-95`
- `tests/workflow-trials/scenarios/auto/prompt.md`
- `tests/test_auto_loop_trials.py`

**Evidence**

Route scenario launchers check only the skill name and executable bits. The fresh Auto trial receives prebuilt authorization, edits one `result.txt`, and never exercises startup, spec creation, planning, issue choice, native worktrees, publication, or merge. The runner hard-codes `user_input_calls` and `external_mutations` to zero in the receipt.

**Impact**

Full validation is green while the primary advertised workflows are contradictory or fail open. Release evidence gives false confidence about usability and safety.

**Recommended correction**

Replace launcher-presence checks with route-specific positive and adversarial behavior fixtures. Add installed-plugin, fresh-context trials that begin from real user prompts and record actual tool calls and native input calls.

**Verification oracle**

- Raw idea + Auto runs the complete lifecycle with one startup prompt.
- Auto direct and issue-backed branches both pass.
- Missing evidence, route drift, worktree fallback while native tools exist, detached PR-ready claims, and extra questions fail.
- Loop blocks or continues only according to its real continuation policy and evidence.

### P1 — The workflow graph is not fully authoritative

**Locations**

- `docs/superpowers/workflow-contract.yml`
- `scripts/lib/workflow_graph.py`
- generated `docs/superpowers/WORKFLOW_ROUTE_INDEX.md`

**Evidence**

Gate facts are repeated in `question_ids`, `nested_routes`, and `gates`. In-memory mutations that removed initiation question IDs, corrupted a nested mode option, or removed the Auto validator produced no graph findings.

**Impact**

The repository can claim one typed source while still allowing divergent prompt, route, and validator views. Agents then read internally inconsistent authority.

**Recommended correction**

Normalize each gate once, including owner, type, parent, options, transition effects, required capabilities, authority effects, artifacts, and validators. Generate indexes, route slices, and metadata from that representation.

**Verification oracle**

Mutation fixtures fail for every removed or inconsistent gate/validator/transition. Generated route slices are byte-stable and are the only contract context loaded by an owner skill.

### P1 — Installation leaks plugin policy into the global skill namespace

**Locations**

- `scripts/sync-live.sh` dispatch path
- live-sync implementation in `scripts/lib/superpowers_project_cli.py`
- `README.md:226-240`

**Evidence**

Sync deploys the plugin's `advanced-user-input` skill both inside the plugin and into the user-global `~/.agents/skills/advanced-user-input` path, replacing the target.

**Impact**

Installing or updating one plugin can change unrelated agent behavior and expose duplicate global/plugin-prefixed skill identities. This weakens isolation and makes debugging loaded policy harder.

**Recommended correction**

Keep the helper namespaced and self-contained by default. If a global helper remains a supported optional product, install it through a separate collision-aware transaction with manifest ownership and rollback rather than ordinary plugin sync.

**Verification oracle**

A clean plugin install leaves unrelated user skills byte-identical and exposes one unambiguous helper identity to plugin routes.

### P2 — The base Superpowers dependency is undeclared and unverified

**Locations**

- `.codex-plugin/plugin.json`
- route skill `Required Superpowers Pairings` sections
- isolated marketplace lifecycle tests

**Evidence**

Most execution routes require vanilla Superpowers skills, but the manifest and install preflight do not declare or verify the dependency. The isolated marketplace lifecycle installs only Superpowers Project.

**Impact**

The plugin can appear installed and healthy while core routes cannot load their required methods.

**Recommended correction**

Declare the dependency if the plugin format supports it. Regardless, add startup capability resolution that proves every required pairing is available before mode selection and reports exact missing skills.

**Verification oracle**

A clean Codex home either resolves all mandatory Superpowers pairings or fails before presenting Auto/Loop options.

### P2 — Looping Mode has incomplete raw-request and continuation semantics

**Locations**

- `docs/superpowers/loop-mode-contract.yml`
- `skills/loop-controller/SKILL.md`
- `docs/superpowers/backlog/ACTIVE.md`
- Loop validator handlers in `scripts/lib/superpowers_project_cli.py`

**Evidence**

Candidate precedence begins with the active backlog and omits the explicit startup request, while the current backlog is empty. Startup budget/default collection is not fully specified. Low-level continuation events do not prove the graph-owned question/answer that allegedly authorized them, and several Loop validators do not enforce all documented terminal conditions.

**Impact**

Looping cannot reliably begin from a new idea and its recorded continuation can be weaker than the prose contract.

**Recommended correction**

Treat the explicit request as the first candidate when present and route unresolved requests through brainstorming. Preserve one candidate per iteration and fail-closed budget/verifier proof. For the first repair, retain the explicit between-candidate `project_loop_next_step` checkpoint while removing all redundant intra-candidate questions; a later approved design may replace that checkpoint with unattended queue draining under an upfront budget.

**Verification oracle**

An empty-backlog raw idea enters brainstorming as iteration one. No request plus empty backlog produces no-ready proof. A second candidate requires a structured continuation record whose question, answer, budget, verifier, and candidate all match.

### P2 — The runtime command module is too broad and shallow in critical places

**Locations**

- `scripts/lib/superpowers_project_cli.py` (2,385 lines, 122 functions, 86 command handlers)
- `scripts/lib/commands/`
- `tests/test_command_locality.py`

**Evidence**

One module mixes validators, test handlers, installation, sync, workflow modes, Loop state, issue hydration, GitHub checks, worker packets, PR readiness, merge, and closeout. Existing locality tests cover only a small subset.

**Impact**

The module is a shallow interface with poor locality: unrelated changes share one implementation, tests can dispatch to generic handlers, and fail-open stubs are easy to hide among many commands.

**Recommended correction**

Deepen modules by domain: authorization/runtime, planning validation, issue/tracker, workspace isolation, PR/merge evidence, distribution, and test-only fixtures. The top-level CLI should dispatch only.

**Verification oracle**

No production command handler remains in the top-level dispatcher. Each module has focused positive/negative tests through its public interface, and a size/locality guard prevents the monolith from regrowing.

### P2 — Prompt complexity was relocated rather than eliminated

**Locations**

- thin route `SKILL.md` files
- `skills/advanced-user-input/SKILL.md` (276 lines)
- `docs/superpowers/workflow-contract.yml` (approximately 1,282 lines)
- `skills/*/agents/openai.yaml`

**Evidence**

Skill slimming reduced route files but requires agents to read a large global policy and full cross-project route graph. Agent metadata repeats additional instructions and can diverge from both.

**Impact**

The prompt surface remains cognitively expensive and harder for agents to apply locally. Thin adapters do not create depth when their interface requires understanding the entire implementation graph.

**Recommended correction**

Generate small owner-specific contract slices from the normalized graph. Keep shared policy modular by need: authorization, artifact display, continuation, and terminal health. Generate agent metadata from the same route source.

**Verification oracle**

Each route can execute from its skill, one shared mode interface, and one generated owner slice without reading unrelated routes. Drift tests compare generated metadata and contract slices byte-for-byte.

### P3 — Historical design status is ambiguous and amplifies semantic drift

**Locations**

- the June 4 Auto-after-spec design preserved in Git history
- the June 15 Auto and Loop controller design preserved in Git history
- later workflow-mode and governance specs

**Evidence**

Historical specs preserve mutually incompatible Auto definitions without a prominent supersession marker. The repository correctly treats history as non-runtime package input, but maintainers and agents still use it as research evidence.

**Impact**

The post-spec Auto behavior that concerned the user is understandable from repository history even though current route ownership moved to initiation. Research and repair planning take longer and can resurrect retired semantics.

**Recommended correction**

Add a lightweight status header or supersession index for historical specs. Do not rewrite history; point each superseded design to the current authority and explain which decision changed.

**Verification oracle**

Every historical spec that conflicts with an active contract is discoverably marked `superseded` with a link to its replacement, while active specs remain unambiguous.

## Healthy Checks

The audit found meaningful strengths worth preserving:

- canonical project artifacts have clear roots under `docs/superpowers/`;
- the source repository and deployment target roles are explicitly documented;
- runtime package hashing and path containment guard against stale or cross-root evidence;
- hash-chained workflow event replay detects tampering;
- Auto rejects selection of a second opaque candidate at the low level;
- Loop rejects a second candidate until its current low-level gates are recorded;
- graph validation checks unique IDs, reachability, and terminal geometry;
- generated workflow indexes are deterministic;
- source and installed plugin version `0.3.0` were current at audit time;
- the full existing validation suite passed;
- vanilla `superpowers:using-git-worktrees` already prefers native tools and detects existing linked isolation, so the extension can adapt it instead of forking it;
- the official Codex app provides the native worktree/task and Handoff primitives needed for the repair.

## False-Positive Risks And Skipped Checks

- A caller may currently perform additional checks before invoking a permissive validator. That does not make a public validator safe; the finding is specifically that the validator interface itself fails open.
- `select-candidate` may be called only after a separately validated inventory in intended workflows. The finding is missing enforced linkage, not proof that every caller selects arbitrary work.
- Live native modal behavior, real GitHub publication, push, PR, and merge were not mutated during this read-oriented audit.
- The audit did not create a real Codex worktree task because that would create an external user-visible task. Current-session tool contracts and official documentation were sufficient to identify the missing adapter and receipt shape.
- The current full suite passing is reported as healthy implementation evidence, not as behavioral proof of Auto or Loop lifecycle correctness.

## Alternatives

### Alternative A — Patch prompts and validators in place

Remove the second Auto question, relax `source_spec`, add native-worktree wording, and make the four validators require arguments.

**Benefits:** smallest initial diff.

**Costs:** leaves lifecycle semantics distributed across skills, retains duplicate gate facts, and is likely to regress when another route adds a question or approval.

### Alternative B — Mode-aware lifecycle controller plus workspace-isolation adapter

Keep existing owner skills, but place a typed lifecycle controller above them and a shared workspace-isolation adapter before vanilla worktree handling. Normalize gates, make evidence validators fail closed, and test complete mode traces.

**Benefits:** preserves the extension model, gives Auto and Loop stable semantics, keeps vanilla untouched, and creates deep interfaces with high leverage and locality.

**Costs:** requires coordinated contract, runtime, skill, packet, and behavioral-test changes.

### Alternative C — Separate autonomous execution engine

Build a new Auto/Loop engine that owns spec, planning, issue selection, execution, and merge independently of the existing skill graph.

**Benefits:** clean control flow and fewer legacy constraints.

**Costs:** duplicates Superpowers Project owner skills, risks competing with vanilla Superpowers, and creates a second artifact/execution model—the original architectural mistake this plugin was designed to avoid.

## Selected Design

Select Alternative B.

### Lifecycle Controller Module

The controller interface accepts:

- candidate/request fingerprint;
- active repository and project identity;
- selected mode;
- authorization envelope;
- current lifecycle phase;
- bound artifacts and proof receipts;
- budgets and stop conditions.

It returns one of:

- the next owner step with typed inputs;
- an auto-resolved gate decision plus rationale;
- a fail-closed blocker with the exact missing evidence;
- verified lifecycle completion.

### Gate Resolver Module

The same gate definition is evaluated differently by mode:

- Manual renders native input.
- Auto resolves covered decisions from policy and records them without rendering input.
- Looping uses Auto behavior inside one candidate and applies its separate between-candidate continuation policy.

No owner skill decides independently whether a question is skippable.

### Append-Only Authority And Artifact Binding

The initial authorization remains immutable and binds to the raw request. Later specs, plans, issue mirrors, branches, tasks, and PRs are attached through hash-chained events. This preserves tamper evidence without requiring a spec before initiation.

### Workspace Isolation Module

The `workspace-isolation` module provides a small interface:

```text
ensure_isolated(candidate, topology, starting_state, authority)
  -> workspace_receipt | blocker
```

The receipt records provider, ownership, project/task IDs, path, Git state, planned branch, branch transition, and finish strategy. Codex-managed worktrees remain app-owned. Vanilla `using-git-worktrees` is invoked after the adapter and should detect the existing worktree.

### Evidence Gate Modules

PR-ready, premerge, merge-decision, and closeout become separate deep modules. Each has a narrow schema, validates repository reality, and refuses missing evidence. The interface is the test surface.

### Issue Decision Module

The plan outcome proof feeds one deterministic issue decision. The module chooses direct execution or a real issue-backed route and records why. Issue count, hierarchy, topology, publication, push, and merge choices are resolved from the same Auto authority instead of triggering new questions.

## Data Flow

```text
raw request
  -> initiate-workflow: one mode/authority decision
  -> immutable authorization + candidate fingerprint
  -> lifecycle controller
  -> brainstorm/spec owner step
  -> artifact_bound(spec)
  -> planning owner step
  -> artifact_bound(plan)
  -> issue decision
       -> direct implement-plan
       -> create-issues -> resolve-issue or orchestrate-issues
  -> workspace-isolation adapter
  -> vanilla Superpowers execution methods
  -> fail-closed PR-ready/premerge/merge/closeout gates
  -> verified candidate lifecycle completion
  -> stop (Auto) or Looping continuation policy
```

## Error Handling

Auto stops without asking when:

- the requested outcome cannot be inferred from the original request and repository evidence;
- a choice would exceed the startup mutation envelope;
- a required capability or vanilla Superpowers dependency is absent;
- repository state is dirty in a way that overlaps the candidate;
- validation, tests, checks, provenance, or evidence fail;
- a native task/worktree cannot be created and fallback is not authorized;
- GitHub authentication/network state blocks a route that the issue rubric requires;
- merge conflicts or destructive recovery would require new authority.

The blocker report must name the current lifecycle phase, completed artifacts, verified evidence, missing fact, and safest resume route. It must not reopen routine choices already covered by Auto.

## Testing Strategy

### Phase 0 — Safety gate repair

- Negative-first tests for missing PR-ready, premerge, merge-decision, and closeout evidence.
- Provenance and repository-reality fixtures.
- Full validation must include these fixtures directly.

### Phase 1 — Auto lifecycle semantics

- Fresh raw idea, problem, and feature prompts.
- Exactly one startup mode input.
- Direct and issue-backed lifecycle traces.
- No downstream question calls.
- Issue rubric boundary fixtures.
- Remote mutation confinement and fail-closed stop tests.

### Phase 2 — Codex-native isolation

- Existing linked worktree.
- Native managed worktree task created from Local.
- Detached initial receipt and named-branch/Handoff transition.
- Manual fallback only when native capability is absent.
- App-owned cleanup cannot call manual removal/prune.

### Phase 3 — Looping semantics

- Raw request as first iteration with empty backlog.
- Ready-backlog iteration.
- Structured between-candidate continuation.
- Budget, verifier, no-ready, and terminal-health proof.
- No intra-candidate questions.

### Phase 4 — Installed-plugin trials

- Clean Codex home with base Superpowers dependency resolution.
- Real installed-plugin discovery and startup.
- Actual tool/input call capture rather than hard-coded metrics.
- Separate worker and verifier sessions with repository and event evidence.

### Phase 5 — Architecture and distribution

- Split the CLI monolith into domain modules.
- Generate owner contract slices and agent metadata.
- Remove ordinary sync mutation of the global user skill namespace.
- Add supersession metadata for conflicting historical specs.

## Recommended Repair Order

1. Make lifecycle and approval validators fail closed.
2. Reconcile production startup provenance and replace the second Auto authorization with one startup authority.
3. Define candidate lifecycle and owner-step events; make downstream gates mode-aware.
4. Implement the issue decision rubric and complete Auto mutation envelope.
5. Add the Codex-native workspace-isolation adapter and ownership-aware cleanup.
6. Replace scenario stubs with true behavioral fixtures and fresh installed-plugin lifecycle trials.
7. Strengthen and normalize the workflow graph.
8. Split the CLI by domain and reduce prompt/package coupling.
9. Isolate global helper deployment and mark superseded historical designs.

## Outcome Proof

**Intent:** Make Superpowers Project a trustworthy, low-friction Codex lifecycle extension in which Auto completes one requested outcome without repeated questions and native Codex worktrees are used when available.

**Current Behavior:** Auto authority is contradictory and cannot begin from a raw idea, downstream skills remain interactive, issue/worktree choices are constrained incorrectly, native task isolation is unenforced, and critical lifecycle validators can pass without evidence.

**Expected Outcome:** One startup mode decision drives a typed candidate lifecycle across spec, plan, issue decision, execution, verification, integration, and closeout; Auto asks no routine follow-up questions; Looping repeats verified lifecycles under its continuation policy; Codex-managed worktrees remain app-owned; every safety gate fails closed.

**Target Output:** Normalized mode/lifecycle contract, gate resolver, append-only artifact binding, issue decision rubric, native workspace-isolation adapter, provenance-bound evidence validators, real behavioral scenarios, and installed-plugin usability trials.

**Owner:** Superpowers Project workflow owner.

**Interface:** `initiate-workflow` mode authority, lifecycle controller owner-step transitions, workspace isolation receipts, and PR-ready/premerge/merge/closeout evidence schemas.

**Cutover:** Repair fail-open gates first, then cut Auto to the single startup authority, then add native isolation and behavior trials before removing old prompt paths.

**Replaced Path:** Second bounded Auto authorization, post-spec Auto re-entry, per-route Auto questions, opaque one-route semantics, same-checkout workers labeled isolated, generic branch/worktree strings, and no-evidence gate success.

**Evidence:** Reproduced production provenance rejection, reproduced no-evidence validator successes, current contract/source comparison, current Codex tool contracts, official Codex worktree behavior, targeted scenario/test runs, and full validation baseline.

**Acceptance Proof:** A clean installed-plugin raw-idea Auto trial uses exactly one native mode selection, chooses direct or issue-backed execution, uses a Codex-managed worktree task when isolation is required, reaches verified closeout, records actual tool/input metrics, and passes fail-closed evidence gates. Adversarial fixtures fail at every missing or forged authority/evidence seam.

**Stop Criteria:** Stop the repair if mode authority cannot be made explicit before external mutation, a native-worktree operation cannot be proven/owned, a gate cannot validate repository reality, or a change would require modifying vanilla Superpowers.

**Avoid:** Editing vanilla Superpowers, silently broadening Auto beyond the current repository/outcome, direct-to-main shortcuts, manual removal of app-owned worktrees, self-verified narrative receipts, duplicate workflow authorities, and compatibility shims that retain contradictory Auto behavior.

**Risk:** A coordinated control-plane migration can strand in-progress workflow ledgers or stale loaded sessions. Mitigate with versioned schemas, explicit unsupported-old-ledger diagnostics, generated contract checks, and fresh-session cutover instructions.

## Unresolved Decisions

1. After the first repair, decide whether Looping Mode should retain one explicit between-candidate continuation gate or offer a separately authorized unattended queue-draining policy. The first repair should retain the gate and remove only intra-candidate questions.
2. Decide whether the global `advanced-user-input` installation is retired outright or split into a separately installed, manifest-owned optional package. Ordinary plugin sync should no longer replace it.
3. Decide the migration policy for existing generated Auto/Loop ledgers. Silent compatibility is not recommended; an explicit versioned rejection and restart route is safer.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Canonical Auto meaning | User request plus reproduced lifecycle contradictions | One requested candidate lifecycle from idea/problem/feature through verified closeout, with no routine questions after startup | Replaces one-skill/one-route ambiguity | No | Workflow owner |
| Auto authority point | User request | `project_workflow_mode = Auto Mode` is the sole user authorization decision | Removes post-spec Auto and second bounded-merge prompts | No | Governance owner |
| Remote mutation envelope | User's real-issue and end-to-end Auto requirement | Auto selection explicitly preauthorizes current-repository issue/branch/PR/merge actions needed by the chosen route after fail-closed proof | Allows issue-backed Auto without later approval prompts | No | Governance owner |
| Vanilla Superpowers | Original extension design and user constraint | Preserve vanilla; add a project adapter before vanilla worktree handling | Avoids a fork and keeps upstream improvements | No | Skill owner |
| Worktree mechanism | Current Codex tools and official documentation | Codex-managed project task worktrees first; manual Git fallback only when native capability is absent and policy permits | Prevents `.worktrees` fallback in the app path | No | Workspace owner |
| Worktree cleanup | Official Codex ownership semantics | App-owned worktrees use Handoff/preservation/archive/app cleanup; plugin removes only plugin-owned manual worktrees | Prevents fighting the harness | No | Merge owner |
| Issue decision | User request and historical Auto design | Agent decides direct versus real issue-backed execution after planning using a deterministic rubric | Removes hard-coded inline route | No | Planning owner |
| Safety priority | Reproduced no-evidence successes | Fail-open lifecycle gates are repaired before autonomy expansion | Restores the foundation for safe Auto merge | No | Validation owner |
| Looping interaction | Audit scope and user emphasis on Auto | Remove intra-candidate prompts; retain one structured between-candidate gate initially | Reduces friction without silently authorizing queue draining | Yes | Loop owner |
| Test standard | Existing green suite versus reproduced defects | Require behavior and actual tool/input evidence, not launcher presence or hard-coded metrics | Makes release proof meaningful | No | Validation owner |
| Architecture approach | Alternatives analysis | Mode-aware lifecycle controller plus workspace-isolation adapter | Creates deep modules with leverage and locality | No | Architecture owner |

## Spec Self-Review

- Placeholder scan: no placeholders or incomplete requirements remain.
- Internal consistency: Auto is one candidate lifecycle across multiple owner steps; Looping repeats lifecycles; Manual remains interactive.
- Scope check: the findings require a staged implementation plan with safety gates first; they should not be implemented as one undifferentiated refactor.
- Ambiguity check: the three intentionally deferred policy choices are isolated under Unresolved Decisions and do not block Phase 0 through Phase 4 repairs.
