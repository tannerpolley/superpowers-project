# Plugin Operational Maturity Design

## Purpose

Turn the six follow-up improvements from the plugin contract hardening closeout into an official Superpowers Project spec. The goal is to move the plugin from locally validated and manually operated toward repeatable CI, release traceability, stale-thread detection, easier merge closeout, end-to-end smoke coverage, and a generated contract summary that a new agent can read quickly.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the durable artifact roots: specs under `docs/superpowers/specs/`, plans under `docs/superpowers/plans/`, issues under `docs/superpowers/issues/`, and milestone index pages under `docs/superpowers/milestones/`.
- The roadmap splits this work across `M0 - Governance`, `M1 - Source Of Truth`, and `M2 - Distribution`.
- `docs/superpowers/specs/2026-06-10-plugin-contract-softness-audit-findings.md` identified soft or stale plugin contracts around terminal options, live sync, issue metadata, debug mode, and metadata readability.
- `docs/superpowers/plans/2026-06-10-plugin-contract-hardening-plan.md` implemented the first hardening pass and left the plugin with stronger local validators, a clean live sync proof, and a merged `main`.
- `scripts/validate.ps1` now runs broad source, metadata, script, manifest, and scenario checks, including `scripts/test-skill-metadata-readability.ps1`.
- `scripts/sync-live.ps1 -Validate` now proves the local live plugin install matches the source repo.
- `skills/merge-changes/scripts/premerge.ps1`, `closeout.ps1`, `validate-merge-decision.ps1`, and `validate-terminal-closeout.ps1` already define merge-closeout proof contracts, but ordinary local-branch use still requires hand-assembled ledgers and several manual script calls.
- `skills/advanced-user-input/SKILL.md` and workflow skills now define native continuation, `Stop`, `Done`, `Revisit`, stale-thread recovery, and debug-mode policy, but there is no generated summary page that condenses those contracts for a new agent.

## User Decisions

- Add all six improvements to an official spec.
- Expand each improvement beyond the short follow-up bullets.
- Keep this as a brainstorm/spec artifact, not an implementation plan or issue set yet.
- Use the canonical Superpowers Project artifact root under `docs/superpowers/specs/`.

## Recommended Approach

Treat the six improvements as one operational maturity program, not six unrelated cleanup tasks. Each improvement should make the plugin easier for a fresh agent to trust without relying on memory, cache paths, or manual reconstruction of recent decisions.

The six improvements are:

1. CI for the plugin validation suite.
2. Release and version bump discipline.
3. Stale-skill or stale-thread detector.
4. Local-branch merge and closeout helper.
5. End-to-end fixture smoke tests.
6. Rendered contract summary page.

The work should be planned as staged implementation slices so each slice can land with its own proof oracle. The highest-risk surfaces are CI portability and merge-closeout automation, because they touch environment assumptions and mutation-adjacent workflows.

## Improvement 1: CI For The Plugin Validation Suite

### Problem

The repo can be validated locally, but the current safety story depends on a human or agent remembering to run the right PowerShell commands. That is not enough for a source-of-truth plugin. A future change can weaken a contract, break metadata parsing, or introduce stale namespace wording without being caught before it reaches `main`.

### Desired Behavior

GitHub Actions should run a deterministic plugin validation workflow on pull requests and pushes to `main`. The CI workflow should prove that source contracts, metadata readability, PowerShell parsing, manifest validation, namespace checks, native continuation gates, and scenario tests still pass.

### Proposed Shape

Add or expand `.github/workflows/validate.yml` so it runs on:

- pull requests targeting `main`;
- pushes to `main`;
- manual `workflow_dispatch`;
- optionally a scheduled full smoke run if fixture cost grows.

Use a Windows runner first because the repo scripts are PowerShell-first and many local paths are Windows-oriented. A later Linux runner can be added only after the scripts are explicitly made cross-platform.

CI should have at least two tiers:

- Source-only tier: fast checks that do not require a live local plugin install or user-level skill directory.
- Full fixture tier: scenario tests that build temporary repos and validate the workflow contracts without mutating real GitHub state.

The default CI command should be explicit. Candidate:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

If full validation requires a local install path that GitHub Actions cannot provide, the implementation plan should add CI-safe parameters or fixtures rather than weakening validation.

### Acceptance Criteria

- CI fails on broken skill metadata, oversized metadata lines, stale namespace references, missing continuation contracts, and PowerShell parse failures.
- CI output names the failing script and failing contract clearly.
- CI does not require secrets for source-only validation.
- CI does not mutate live user plugin directories.
- CI does not treat skipped live sync as passed unless the skip is explicit and source-owned.

### Risks And Tradeoffs

Full local parity may not be possible in GitHub Actions if live install paths assume a user profile with deployed plugin copies. The right tradeoff is source-only CI plus local-only live sync validation, not fake defaults. CI should loudly separate "source validation passed" from "live install validation was not exercised in CI."

## Improvement 2: Release And Version Bump Discipline

### Problem

The plugin can be synced live, but there is no formal release step that records which source commit is deployed and why the version changed. A user or agent can see a live plugin version such as `0.2.0+codex...` without a clear link to the source commit, validation proof, or release notes.

### Desired Behavior

Every intentional live-install or distribution-ready update should have a release receipt. The receipt should connect:

- `.codex-plugin/plugin.json` version;
- source commit SHA;
- validation command results;
- live sync result;
- changed skill names;
- migration notes;
- compatibility notes for existing threads.

### Proposed Shape

Add a release preparation script, for example:

```text
scripts/prepare-release.ps1
```

The script should not publish by itself. It should prepare a release receipt and optionally bump version metadata after an explicit approved route. It should support:

- patch, minor, and major version intent;
- metadata-only release receipts when the manifest version should not change;
- changelog entry generation;
- validation proof capture;
- live sync proof capture;
- source commit stamping.

The plugin manifest can keep semantic versioning plus local build metadata, but the repo should define exactly what changes require a patch, minor, or major bump.

### Acceptance Criteria

- A release receipt can answer: "what source commit is this local live plugin based on?"
- Version changes are never silent side effects of sync.
- Release notes mention contract-impacting changes, new validators, and stale-thread implications.
- `sync-live.ps1 -Validate` can compare release receipt source commit against the source checkout when available.

### Risks And Tradeoffs

Over-formal release steps can slow local iteration. The design should keep a lightweight "development sync" path while making distribution or handoff releases traceable. The release script should prepare evidence first and apply version changes only after approval.

## Improvement 3: Stale-Skill Or Stale-Thread Detector

### Problem

The repo source and live install can be correct while a loaded thread still behaves as if it has older skill text. The plugin now has stale-thread recovery instructions, but there is no dedicated detector that helps an agent prove which contract marker is missing or which expected route was skipped.

### Desired Behavior

When behavior conflicts with source contracts, an agent should be able to run a detector that reports:

- source skill contract marker;
- live deployed skill contract marker;
- metadata contract marker;
- expected native question ids and option sets;
- missing or stale markers in the checked surfaces;
- recommended recovery action.

The detector should not rely on plugin cache paths as durable source of truth. Cache paths may be mentioned only as optional observed evidence when the user is explicitly debugging cache state.

### Proposed Shape

Add a source-owned detector script, for example:

```text
scripts/detect-stale-skill-contract.ps1
```

Inputs:

- `-SkillName <name>`;
- optional `-ExpectedQuestionId <id>`;
- optional `-ObservedMissingText <text>`;
- optional `-LivePluginRoot <path>`;
- optional `-UserSkillsRoot <path>`.

Outputs:

- JSON with `ok`, `phase`, `skill`, `source_contract_marker`, `live_contract_marker`, `missing_markers`, `stale_indicators`, and `recommended_recovery`;
- human-readable summary suitable for artifact review.

Each workflow skill should expose a small contract marker block, such as:

```text
Contract markers:
- native-continuation-v2
- final-health-done-v1
- debug-ledger-v1
- canonical-namespace-superpowers-project-v1
```

Markers should be stable enough for detectors and tests, but not so broad that every text edit requires marker churn.

### Acceptance Criteria

- Detector reports source and live install drift without editing either surface.
- Detector can prove that current source includes required question ids such as `project_brainstorm_start_route` or `project_merge_final_health_gate`.
- Detector can produce a clear stale-thread recovery message: warn, name the missed gate, re-ask the native gate, and continue from the corrected route.
- Detector never treats a stale loaded thread as approval.

### Risks And Tradeoffs

Markers add maintenance overhead. Too many markers become noise; too few markers fail to distinguish meaningful contract shifts. The implementation plan should start with markers for terminal states, native gate topology, namespace, debug mode, live sync, and Auto Mode.

## Improvement 4: Local-Branch Merge And Closeout Helper

### Problem

`merge-changes` has strong proof scripts, but a normal local-branch closeout currently requires an agent to manually assemble setup JSON, validation JSON, merge decision JSON, closeout JSON, and terminal continuation JSON. That is error-prone and makes clean closeout feel harder than it needs to be.

### Desired Behavior

The repo should provide one guided local-branch helper that prepares and validates closeout evidence while preserving the native approval gates. The helper must not bypass user approval for merge, branch deletion, or terminal `Done`.

### Proposed Shape

Add a helper script or small script family, for example:

```text
skills/merge-changes/scripts/prepare-local-branch-closeout.ps1
skills/merge-changes/scripts/apply-local-branch-closeout.ps1
```

The prepare script should:

- verify current branch and target branch;
- verify source plan linkage;
- verify `main` is synced with `origin/main`;
- run or consume validation proof;
- run premerge proof;
- write a premerge evidence file;
- print the exact native merge approval prompt inputs.

The apply script should run only after native approval is recorded. It should:

- validate the merge decision ledger;
- switch to `main`;
- merge the local branch;
- push `main`;
- delete only the approved owned branch locally and remotely;
- prune;
- run cleanup hook;
- validate closeout proof;
- prepare terminal health-gate evidence.

The terminal `Done` decision should remain outside the helper or be passed in as a recorded native decision after it is selected.

### Acceptance Criteria

- A local branch can move from clean premerge proof to clean closeout proof with one prepare command, one native merge approval, and one apply command.
- The helper refuses to delete any branch other than the owned implementation branch named in the setup ledger.
- The helper refuses to merge if validation proof is missing or stale.
- The helper emits JSON paths for every generated ledger.
- The helper works for non-issue local branches and does not invent PR or issue evidence.

### Risks And Tradeoffs

A too-powerful helper could hide important approval boundaries. Splitting prepare and apply keeps the native merge gate visible. The helper should make evidence collection easier, not make decisions.

## Improvement 5: End-To-End Fixture Smoke Tests

### Problem

Individual scenario tests prove parts of the plugin, but there is no single fixture that exercises the full intended lifecycle from spec through plan, implementation, verification, merge closeout, live sync proof, and final terminal gate behavior. Without an end-to-end fixture, cross-skill integration regressions can survive even when every local unit test passes.

### Desired Behavior

An end-to-end smoke test should simulate the full workflow with disposable local fixtures and no real GitHub mutation by default. It should prove that one coherent route can move through:

1. brainstorm spec;
2. write plan;
3. implement plan;
4. validate branch;
5. push/hold decision fixture;
6. merge-changes local-branch mode;
7. cleanup and closeout;
8. terminal `Done` gate validation.

### Proposed Shape

Add a script such as:

```text
scripts/test-e2e-project-workflow.ps1
```

Default mode should run entirely in a temp repo. It can copy the plugin source, create a toy source artifact, create a minimal plan, make a deterministic file edit, run validators, and exercise merge closeout scripts with fixture native-decision ledgers.

Optional modes:

- `-LocalOnly`: no network, no GitHub CLI, no live install mutation.
- `-GitHubFixture`: use static JSON fixtures for PR and issue evidence.
- `-LiveSyncFixture`: compare source to a temp live plugin copy instead of the real user install.
- `-RealGitHubSmoke`: only after explicit approval and configured test repo.

### Acceptance Criteria

- Default smoke test is safe to run in CI.
- Default smoke test creates and removes only temp directories.
- The smoke test proves no intermediate `Stop` or final `Done` shortcut is accepted before proof.
- The smoke test proves local-branch merge closeout can reach validated terminal `Done`.
- Failures name the workflow phase and the missing contract.

### Risks And Tradeoffs

True end-to-end coverage can become slow and brittle. The fixture should start narrow: one happy path plus two negative assertions around terminal gates. Broader GitHub-aware smoke tests should stay opt-in until fixture maintenance is proven cheap.

## Improvement 6: Rendered Contract Summary Page

### Problem

The plugin contracts are now strong, but they are spread across skill files, metadata, scripts, tests, and milestone docs. A new agent can still miss an important rule unless it reads a lot of source. That increases the chance of stale assumptions around gates, terminal states, live sync, or debug mode.

### Desired Behavior

The repo should expose a generated, rendered summary page that names the current workflow contracts in one place. It should be short enough for a fresh agent to read before choosing a route, and generated enough that it does not drift from the source skill files.

### Proposed Shape

Add a generated Markdown artifact such as:

```text
docs/superpowers/CONTRACT_SUMMARY.md
```

Add a generator such as:

```text
scripts/generate-contract-summary.ps1
```

The summary should include:

- canonical namespace: `$superpowers-project:*`;
- skill list and one-line route purpose;
- native continuation gate ids;
- final health gate ids;
- allowed terminal labels by gate type;
- `Done` eligibility requirements;
- push, merge, publish, and approval gate boundaries;
- debug-mode ledger requirements;
- live sync source and deployed-copy policy;
- source artifact roots;
- validation command inventory;
- current contract markers.

Validation should fail when the generated summary is stale relative to source. Candidate:

```text
scripts/test-contract-summary.ps1
```

### Acceptance Criteria

- Summary is regenerated from source contracts, not hand-maintained.
- Summary names every workflow skill and its closeout question id.
- Summary distinguishes intermediate `Stop` from verified final `Done`.
- Summary includes live sync and debug-mode restrictions.
- Validator fails if the generated page is missing a current skill, question id, or contract marker.

### Risks And Tradeoffs

Generated docs can become noisy if they dump too much source text. The generator should extract structured markers and small snippets, not copy entire skill files. If a detail cannot be extracted cleanly, the implementation plan should add explicit marker blocks to the skills first.

## Cross-Cutting Design Requirements

- Do not rely on plugin cache paths as durable contracts.
- Do not weaken the existing live sync validator.
- Do not weaken native user approval gates.
- Do not add fallback defaults for missing proof.
- Every new script must emit structured JSON with `ok`, `phase`, `reason`, and evidence where practical.
- Every generated artifact must have a validator that can fail when it drifts.
- CI-safe tests must avoid mutating real GitHub, real live plugin installs, or user-level skill directories unless explicitly opted into by a local command.

## Suggested Delivery Order

1. Add contract markers and generated contract summary.
2. Add stale-skill detector using those markers.
3. Add CI-safe validation workflow.
4. Add release receipt and version discipline.
5. Add local-branch merge closeout helper.
6. Add end-to-end fixture smoke test.

This order makes later work easier because CI and smoke tests can rely on the summary and marker surfaces, and release receipts can include summary and detector proof.

## Milestone Linkage

- `M0 - Governance`: CI validation, merge/closeout helper, end-to-end smoke tests, and terminal gate proof.
- `M1 - Source Of Truth`: stale-skill detector, generated contract summary, source/live marker comparison, and drift prevention.
- `M2 - Distribution`: release/version bump discipline and distribution-ready proof receipts.

## Proof Oracle Candidates

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-readability.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\detect-stale-skill-contract.ps1 -SkillName brainstorm-spec -ExpectedQuestionId project_brainstorm_start_route`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-release.ps1 -CheckOnly`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-e2e-project-workflow.ps1 -LocalOnly`
- GitHub Actions run for `Validate Superpowers Project plugin` succeeds on pull request and `main`.

## Open Questions For Planning

- Should CI run the full scenario suite on every PR, or should PRs run source-only validation and `main` run full scenarios?
- Should release receipts be committed under `docs/superpowers/releases/`, `docs/superpowers/ledgers/`, or another canonical root?
- Should contract markers live in frontmatter, a dedicated `## Contract Markers` section, or generated metadata?
- Should the stale detector inspect only source and live deployed copies by default, or should it also accept user-provided observed text from a stale thread?
- Should the local-branch closeout helper push `main` by default after merge, or should that be a second apply-stage approval?
- Should the rendered contract summary be fully generated or generated with a hand-written introduction?

## Non-Goals

- Do not create GitHub issues from this spec.
- Do not implement scripts, CI, release helpers, or generated docs in this brainstorm step.
- Do not change plugin cache files.
- Do not publish releases.
- Do not weaken current local validation or live sync proof.
- Do not bypass native approval for push, merge, publication, or final `Done`.

## Spec Self-Review

- Placeholder scan: no placeholder text remains.
- Scope check: the spec intentionally groups six related operational maturity improvements; implementation should still be split into smaller plans or issues.
- Contradiction check: the spec preserves the hardened terminal gate model and does not make helper scripts responsible for user decisions.
- Ambiguity check: open questions are planning choices, not missing direction for the six requested improvements.
