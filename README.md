# Superpowers Project Plugin

Superpowers Project is a local Codex plugin and skill family that extends Superpowers with GitHub-backed project management:

- durable project context under `docs/superpowers`;
- roadmap and milestone pages;
- native question UI for grilling assumptions;
- GitHub issue mirrors and milestone linkage;
- native `/goal` issue resolution with Superpowers execution skills.

This repository is the canonical source. The live Codex install is a deployment target.

## Public Identity

The canonical plugin identity is `superpowers-project`, the GitHub repository is `tannerpolley/superpowers-project`, and the canonical user-facing prompt surface is `$superpowers-project:*`.

## Current Skills

- `$superpowers-project:initiate-workflow`: routes extension workflows.
- `$superpowers-project:setup-project`: creates and maintains project setup, context, milestone pages, tracker config, and approved GitHub Project board evidence.
- `$superpowers-project:brainstorm-spec`: runs Superpowers brainstorming with native grilling.
- `$superpowers-project:write-plan`: writes Superpowers implementation plans with project context.
- `$superpowers-project:loop-controller`: coordinates repeated workflow runs with local run ledgers, budgets, candidate selection, verifier proof, metrics, and policy continuation.
- `$superpowers-project:implement-plan`: implements an approved plan on a development branch without creating GitHub issue mirrors.
- `$superpowers-project:create-issues`: creates GitHub issue mirrors and GitHub issues from approved plans/specs.
- `$superpowers-project:resolve-issue`: resolves one issue directly in the current thread with native `/goal` and Superpowers execution.
- `$superpowers-project:orchestrate-issues`: creates and manages worker-thread issue resolution with aligned thread title, branch name, worktree identity, and PR-ready handoff evidence.
- `$superpowers-project:merge-changes`: reviews and merges issue-backed PR work or approved local branch work, cleans owned branches and worktrees, prunes, and records clean repo proof.
- `$superpowers-project:audit-project`: reviews code or workflow behavior and writes P-coded repair findings specs.
- `$superpowers-project:align-project`: aligns project, GitHub, migration, tracker, and live-sync drift.

## Upstream Visual Companion

`$superpowers-project:brainstorm-spec` pairs with `superpowers:brainstorming` and inherits its just-in-time visual companion for questions that genuinely benefit from a visual comparison. Browser events are advisory; native Codex input remains the approval channel. Generated `.superpowers/brainstorm/` state is ignored, and its local server should be stopped after use.

Set `SUPERPOWERS_DISABLE_TELEMETRY=true` before starting a visual session to disable the upstream Prime Radiant version check. Planning, merge review, and workflow recaps stay in Markdown and native Codex rather than adding a second companion route.

## Source-Of-Truth Roles

- `docs/superpowers/workflow-contract.yml` is the route contract for material native gates, gate types, exact option labels, and approval or permission effects.
- `docs/superpowers/backlog/ACTIVE.md` is the active Looping Mode candidate source.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface, not the route authority.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence for orchestrated worker handoffs.
- Specs, plans, issue mirrors, and milestone pages are working artifacts and are removed after completion unless the runtime or an explicit retention marker still requires them.
- GitHub and Git history are the durable record of completed work.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs. `.chatgpt/**` is handoff input; `.superpowers/**` is generated runtime evidence.

## GitHub Milestones And Sub-Issues

GitHub Milestones remain the milestone tracker. Parent issues and optional plan-wrapper issues group work inside a milestone; they do not replace milestones or encode milestone identity in titles.

- New issue titles stay clean. Milestone names, milestone numbers, hierarchy ordinals, and pseudo sub-milestone numbers belong in GitHub fields and local mirror metadata.
- Supported hierarchy modes are `flat`, `issue-set`, and `sub-milestone`.
- Parent and plan-wrapper mirrors are rollup records with `Executable: false`.
- Only `Sub-Issue Role: leaf` with `Executable: true` can enter `$superpowers-project:resolve-issue` or `$superpowers-project:orchestrate-issues`.
- Leaf merge closeout records `hierarchy_rollup` parent progress from GitHub `subIssuesSummary`; parent or wrapper closeout still needs native approval plus child proof.
- `$superpowers-project:align-project` reports parent/sub-issue drift and clean-title migration candidates before any GitHub mutation.
- `$superpowers-project:loop-controller` skips parent and plan-wrapper implementation candidates and reserves them for rollup, alignment, or tracker repair.

## Native Q&A Workflow

Manual workflow is a chain of small native Codex questions. Auto and Looping use the same graph but resolve routine gates through the shared lifecycle mode policy. In Manual, each skill summarizes what it produced and asks `Continue?`; top-level closeout options are `Yes`, `Revisit`, and `Stop`.

At startup, `$superpowers-project:initiate-workflow` asks `project_workflow_mode` once with `Manual Mode`, `Auto Mode`, and `Looping Mode`. Manual Mode asks at material gates. Auto Mode authorizes one outcome lifecycle across owner skills. Looping Mode runs those outcomes one candidate at a time and continues only while its startup budget, verifier, and health policy pass.

![Native Q&A main workflow flowchart](docs/assets/native-qa-main-flow.svg)

GitHub can also render the simplified Mermaid companion: [Native Q&A main flow Mermaid](docs/assets/native-qa-main-flow-mermaid.md).

`Stop` pauses a continuation loop before verified completion. `Done` is reserved for a verified final clean state, such as an explicit merge final gate or explicitly asked healthy audit gate with passing proof. `Yes` choices enter the next workflow depth and either start the next skill or ask the next route question. Revisit choices such as `Review First`, revise, repair, or gather evidence must show the relevant artifacts or evidence, ask follow-up questions, and return to the originating continuation gate.

The recommended option should be `Yes` when a safe forward route exists and `Revisit` when evidence or repair is needed. `Stop` may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion.

Before any closeout, push, publish, or merge question, the agent must show the artifacts first. It must show what was created or revised, not merely say something changed. This includes the chosen brainstorm design/spec, full plan task and step list, created issue bodies or mirrors, full changed-artifact inventory for implementation routes, exact test values/results, cleanup evidence, branch or PR proof, and machine-readable ledgers when present. After artifacts are shown, the agent must add its own findings summary: what was done, what was fixed, what remains unsatisfactory or risky, its feedback/opinion, active-goal impact, broader project impact, and the recommended next route.

| Native question | Where it appears | Top-level choices | Nested examples |
| --- | --- | --- | --- |
| `project_workflow_mode` | Before Initiate Workflow task routing | Manual Mode, Auto Mode, Looping Mode | Looping Mode enters Loop Controller; Manual and Auto enter the existing route flow |
| `project_setup_next_step` | After Setup Project | Yes, Revisit, Stop | Brainstorm Spec, Write Plan, Create Issues, Run Align |
| `project_brainstorm_next_step` | After Brainstorm Spec | Yes, Revisit, Stop | Manual Planning, Write Plan, Revise Spec |
| `project_plan_next_step` | After Write Plan | Yes, Revisit, Stop | Create Issues, Implement Plan, Resolve Issue, Orchestrate Issues |
| `project_implement_next_step` | After Implement Plan | Yes, Revisit, Stop | Merge Changes, Review Evidence, Revise Branch |
| `project_issue_next_step` | After Create Issues | Yes, Revisit, Stop | Resolve Issues, Orchestrate Issues, Repair Issue Mirrors |
| `project_issue_resolution_route` | Before issue implementation when route is ambiguous | Resolve, Orchestrate, Review First | Direct current-thread work or worker-thread worktree |
| `project_resolve_next_step` | After direct issue work is PR-ready | Yes, Revisit, Stop | Merge, Resolve Another, Address CI / Checks |
| `project_orchestrate_next_step` | After worker-thread issue work is PR-ready | Yes, Revisit, Stop | Merge, Recover Worker |
| `project_merge_approval` | Before merge | Merge, Decline | Premerge evidence review |
| `project_merge_next_step` | After merge closeout | Yes, Revisit, Stop; `project_merge_final_health_gate` uses Done, Revisit, Stop | Align, Resolve Another, Re-run Cleanup |
| `project_audit_next_step` | After a findings audit | Yes, Revisit, Stop | Write Plan, Auto Mode, Create Issues, Review Findings |
| `project_align_next_step` | After an alignment check | Yes, Revisit, Stop | Apply Repair, Create Planning Spec, Run Align Again |
| `project_align_final_health_gate` | After verified healthy alignment proof | Done, Revisit, Stop | Terminal Done only after clean audit proof |

Auto Mode ledgers are validated by the plugin-provided validator from the loaded Superpowers Project plugin root:

```bash
<Superpowers Project plugin root>/scripts/validate-auto-mode-authorization.sh -RepoRoot <active repo> -AuthorizationPath <ledger>
```

Workflow mode ledgers are validated by the plugin-provided validator from the loaded Superpowers Project plugin root before mode-driven routing:

```bash
<Superpowers Project plugin root>/scripts/validate-workflow-mode-ledger.sh -RepoRoot <active repo> -ModeLedgerPath <ledger>
```

## Task # Use Cases

Implementation plans must include `Task # Use Cases`: every numbered `Task N` needs a non-empty `**Use Cases:**` block before files and steps. This is a strict requirement before a plan is ready, before `$superpowers-project:implement-plan` starts code work, and before `$superpowers-project:resolve-issue` executes a linked source plan.

```bash
./scripts/validate-plan-task-use-cases.sh -PlanPath <plan>
```

## Outcome Proofs

Implementation plans must also include an `Outcome Proof` and `Implementation Boundaries`. The proof names the target outcome, owner, interface, cutover, replaced path, evidence, acceptance proof, stop criteria, avoid list, and risk. Issue mirrors carry that proof forward as an `Outcome Summary`.

```bash
./scripts/validate-plan-outcome-proof.sh -PlanPath <plan>
```

`$superpowers-project:implement-plan` and `$superpowers-project:resolve-issue` carry the approved proof as structured `outcome_proof` ledger evidence. `$superpowers-project:merge-changes` requires structured `readiness_review` proof with `plan_alignment`, `correctness`, `maintainability`, and `reality_evidence` all true before merge approval.

## Implement Plan

`$superpowers-project:implement-plan` is the direct execution path after `$superpowers-project:write-plan` when an approved plan without a GitHub issue should be implemented without GitHub issue mirrors.

Implement Plan uses a development branch, native `/goal` where applicable, Superpowers execution discipline, focused verification, and `$superpowers-project:merge-changes` in local-branch mode for final integration. It does not create issue mirrors, does not open pull requests, and must not claim GitHub issue closure. Use the issue-backed `$superpowers-project:create-issues` route first for non-trivial work that should have GitHub issue and milestone backbone.

## Canonical Layout

```text
.codex-plugin/plugin.json
skills/<skill-name>/
scripts/install.sh
scripts/sync-live.sh
scripts/validate.sh
docs/superpowers/PROJECT_CONTEXT.md
docs/superpowers/specs/
docs/superpowers/plans/
docs/superpowers/issues/
docs/superpowers/milestones/
```

`skills/` contains the full skill implementations and is the only skill source root.

The retired Milestones artifact model is migration history only. New Superpowers Project artifacts should not be written under the old Milestones issue or idea folders, root-level issue folders, root-level plan folders, or milestone-local plan folders.

## Validate

```bash
./scripts/validate.sh
```

## Agent Version Tracking

At Superpowers Project startup, agents should print a concise version banner before selecting a workflow route:

```bash
<Superpowers Project plugin root>/scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
```

Use the JSON version tracker when an agent needs machine-readable proof of the exact Superpowers Project plugin copy it is using:

```bash
<Superpowers Project plugin root>/scripts/get-agent-plugin-version.sh -RequireCurrent
```

The checker reports the manifest version, source commit, and runtime `contract_hash` for source, live install, and an optional observed plugin or skill root. If an agent has an observed skill root from its loaded context, pass it explicitly:

```bash
<Superpowers Project plugin root>/scripts/get-agent-plugin-version.sh -ObservedSkillRoot <loaded-skill-root> -RequireCurrent
```

If source and live are current but the observed surface differs, install or update through the supported Codex marketplace/plugin CLI, then start a fresh agent session. Sync does not mutate Codex cache directories or already-loaded prompt text.

## CI And Releases

GitHub Actions runs the same validation command used locally:

```bash
./scripts/validate.sh
```

Release gates and tag rules are documented in `docs/superpowers/RELEASE_POLICY.md`. The current capability release is `v0.3.0`; local tag creation and remote publication are separate authority boundaries.

The installable surface is declared in `.codex-plugin/runtime-package.yml`; historical specs and plans remain source history but do not churn the installed package hash. Package manifests normalize modes to Git's executable/non-executable semantics, so ambient checkout write permissions do not create false drift. Validate inclusion and runtime reads with `./scripts/validate-runtime-package.py`.

Use `./scripts/get-agent-plugin-version.sh -RevisionStatus` for a read-only report of the next required revision-loop gate. Receipt paths can be supplied for validation, installation, and cleanup evidence; the command never commits, syncs, installs, tags, pushes, or publishes.

### Fresh-Agent Usability Proof

Release usability is proved with five fresh Auto workers and three fresh Looping workers. Every worker uses a disposable repository, is checked by a separate Codex verifier, records a hash-chained event ledger, and must report zero user-input calls and zero mutations outside its fixture. Run the trials only when fresh Codex execution is authorized:

```bash
./scripts/run-agent-usability-trials.sh --execute --parallelism 4 --output-dir .superpowers/runs/agent-trials/current
./scripts/validate-agent-usability-receipt.sh -RepoRoot . -ReceiptDir .superpowers/runs/agent-trials/current
```

`./scripts/validate.sh` checks the ignored runtime receipt set when that directory exists. Receipts are release evidence, not source: any installable runtime change invalidates the package hash and requires fresh trials before release. Documentation history excluded by `.codex-plugin/runtime-package.yml` does not.

## Sync To Live Codex Install

```bash
./scripts/sync-live.sh --validate
```

The sync script deploys this repo's plugin manifest and full skill implementations to:

- `/home/tnnrpolley21/.codex/plugins/superpowers-project`

`advanced-user-input` is included in that plugin namespace. Sync does not create, replace, or delete global user skills. Any pre-existing standalone helper is left untouched. The command updates only the explicit live install and marketplace source metadata. Installed package discovery and updates are owned by the supported Codex marketplace/plugin CLI.

## Revision And Refresh Loop

Use this loop after changing `.codex-plugin/`, `skills/`, `assets/`, `scripts/`, or `docs/superpowers/`. Validation or live sync alone does not finish an installable-surface revision.

```bash
./scripts/validate.sh
git status --short
# Stage only the reviewed revision files, then create a focused commit.
./scripts/sync-live.sh --validate
codex plugin add superpowers-project@personal --json
./scripts/get-agent-plugin-version.sh -Banner -RequireCurrent
bash "$HOME/.codex/hooks/codex-cleanup.sh" --repo-root .
git status --short --branch
```

Commit the reviewed source changes before running live sync. If commit authorization is absent, stop and request it instead of deploying a dirty source state. Push only when the user authorizes it.

`codex plugin add` may be rerun after later revisions to refresh the installed marketplace snapshot. After refresh, start a fresh Codex session so Codex loads the updated prompt and skill text. For a named release, also update `.codex-plugin/plugin.json` and `CHANGELOG.md` according to the release policy.

Changes outside the listed installable paths still require proportionate validation and cleanup. They do not require live sync or plugin refresh unless they alter runtime behavior.

## Install

From a local clone:

```bash
git clone https://github.com/tannerpolley/superpowers-project.git
cd superpowers-project
./scripts/install.sh
```

After install, start with `$superpowers-project:initiate-workflow` in Codex to route setup, brainstorming, code/workflow audits, planning, issue creation, issue resolution, orchestration, merge cleanup, or alignment checks.
