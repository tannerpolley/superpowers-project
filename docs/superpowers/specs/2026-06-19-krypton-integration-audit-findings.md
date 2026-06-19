# Krypton Integration Audit Findings

## Scope

Investigate `jturntdev/krypton` and assess how its planning and execution discipline could be used with the Superpowers Project plugin without weakening the plugin's source-of-truth, native continuation, issue, and proof contracts.

## Review Question

Should Superpowers Project consume Krypton directly, adapt Krypton's contract fields into existing project skills, or keep Krypton only as an operator reference?

## Companion Skills Used

- `$superpowers-project:audit-project`
- `improve-codebase-architecture`

No implementation route was used. This is a findings-first audit for later planning.

## Checked Artifacts

- Downloaded upstream repository: `https://github.com/jturntdev/krypton`
- Downloaded commit: `5ead1cdbdc43b42af45ee404c0729ed60d658886`
- Local ignored inspection copy: `.codex-local/external/krypton`
- `.codex-local/external/krypton/README.md`
- `.codex-local/external/krypton/skills/krypton-planning/SKILL.md`
- `.codex-local/external/krypton/skills/krypton-execution/SKILL.md`
- `.codex-local/external/krypton/docs/required-roles.md`
- `.codex-local/external/krypton/skills/krypton-planning/plan-reviewer-prompt.md`
- `.codex-local/external/krypton/skills/krypton-execution/post-plan-reviewer-prompt.md`
- `.codex-local/external/krypton/skills/krypton-execution/reviewer-prompt.md`
- `.codex-local/external/krypton/skills/krypton-execution/maintainer-prompt.md`
- `.codex-local/external/krypton/examples/wrong-layer-feature.md`
- `.codex-local/external/krypton/examples/cutover-plan.md`
- `.codex-local/external/krypton/examples/acceptance-evidence.md`
- `README.md`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `docs/superpowers/CONTRACT_SUMMARY.md`
- `skills/write-plan/SKILL.md`
- `skills/implement-plan/SKILL.md`
- `skills/resolve-issue/SKILL.md`
- `skills/merge-changes/SKILL.md`

## Validation Evidence

```powershell
bash ./scripts/validate.sh
```

Result from `.codex-local/external/krypton`: `validation passed`.

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Result: no matching leftover Codex processes under the Superpowers Project repo.

## Findings

### P1: Direct Krypton execution conflicts with Superpowers Project's canonical artifact model

**Observed evidence:**

- Krypton defaults to `docs/goals/<goal-slug>/PLAN.md` and `docs/goals/<goal-slug>/GOAL.md` as its goal package in `.codex-local/external/krypton/README.md:50` through `.codex-local/external/krypton/README.md:58`.
- Krypton Planning repeats the same default destination in `.codex-local/external/krypton/skills/krypton-planning/SKILL.md:69` through `.codex-local/external/krypton/skills/krypton-planning/SKILL.md:73`.
- Superpowers Project's artifact model is `docs/superpowers/specs`, `docs/superpowers/plans`, `docs/superpowers/issues`, and `docs/superpowers/milestones` in `docs/superpowers/PROJECT_CONTEXT.md:7` through `docs/superpowers/PROJECT_CONTEXT.md:12`.
- `$superpowers-project:write-plan` requires plans under `docs/superpowers/plans` in `skills/write-plan/SKILL.md:84` through `skills/write-plan/SKILL.md:92`.
- `$superpowers-project:resolve-issue` explicitly says GoalBuddy boards and `docs/goals` are outside the default execution model in `skills/resolve-issue/SKILL.md:14` and rejects setup ledgers containing `docs/goals` in `skills/resolve-issue/SKILL.md:56`.

**Impact:**

Installing and invoking `krypton-planning` as-is would create a parallel planning root outside the plugin lifecycle. That would bypass the `spec -> plan -> issue` model, issue mirror validation, native continuation gates, and existing plan validators.

**Repair requirement:**

Do not make Krypton a direct execution route inside Superpowers Project. If Krypton concepts are adopted, adapt them into `$superpowers-project:write-plan`, `$superpowers-project:implement-plan`, `$superpowers-project:resolve-issue`, and `$superpowers-project:merge-changes` while preserving `docs/superpowers` as the only canonical artifact root.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-flat-artifact-roots.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Add a fixture asserting that a plan with a Krypton-shaped `docs/goals` source is rejected unless the user explicitly opted into separate GoalBuddy work outside the default route.

### P2: Krypton's outcome contract would strengthen `write-plan`, but it is not yet first-class in Superpowers Project plans

**Observed evidence:**

- Krypton Planning requires outcome, current behavior, expected outcome, target output, truth owner, contract boundary, cutover, displaced path, acceptance evidence, evidence lane, and kill criteria in `.codex-local/external/krypton/skills/krypton-planning/SKILL.md:24` through `.codex-local/external/krypton/skills/krypton-planning/SKILL.md:43`.
- Krypton also requires an architecture slice naming source of truth, read path, write path, contract boundary, integration points, migration/cutover, displaced path, and evidence gate in `.codex-local/external/krypton/skills/krypton-planning/SKILL.md:45` through `.codex-local/external/krypton/skills/krypton-planning/SKILL.md:62`.
- `$superpowers-project:write-plan` requires acceptance criteria, proof oracle, Task # Use Cases, and test-complete evidence in `skills/write-plan/SKILL.md:55` through `skills/write-plan/SKILL.md:76` and `skills/write-plan/SKILL.md:121` through `skills/write-plan/SKILL.md:126`.
- The current plan header in `skills/write-plan/SKILL.md:96` through `skills/write-plan/SKILL.md:107` does not require truth owner, cutover, displaced path, contract owner, evidence lane, or kill criteria.

**Impact:**

The plugin already has strong proof and native decision gates, but a plan can still be structurally valid while missing the ownership and cutover answers Krypton is designed to force. That leaves room for plausible work that passes local tests while living on the wrong layer or leaving duplicate current-looking paths.

**Repair requirement:**

Add a Superpowers Project outcome contract section to `$superpowers-project:write-plan` before task decomposition. The section should preserve existing header shape and add required fields for:

- intent and target-perspective output
- current behavior and displaced path
- truth owner and contract interface
- cutover decision
- evidence lane and acceptance evidence
- kill criteria for temporary or duplicate paths

Then add a validator or extend the plan validator so high-risk implementation plans cannot be marked ready without those fields.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <saved-plan-path>
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Add pressure fixtures based on Krypton's wrong-layer, weak-evidence, and cutover-debt scenarios.

### P2: Krypton's review roles map cleanly to existing gates, but should be integrated as gate evidence rather than new top-level workflow routes

**Observed evidence:**

- Krypton defines `explorer`, `plan-reviewer`, `reviewer`, `maintainer`, and `verifier` roles in `.codex-local/external/krypton/docs/required-roles.md:5` through `.codex-local/external/krypton/docs/required-roles.md:34`.
- Krypton Execution requires the main agent to restate goal, plan path, intent, truth owner, contract boundary, cutover, displaced path, acceptance evidence, kill criteria, and forbidden moves before work in `.codex-local/external/krypton/skills/krypton-execution/SKILL.md:24` through `.codex-local/external/krypton/skills/krypton-execution/SKILL.md:40`.
- Krypton Execution's final gates require post-plan review, correctness review, maintainability review, and blocker summary in `.codex-local/external/krypton/skills/krypton-execution/SKILL.md:89` through `.codex-local/external/krypton/skills/krypton-execution/SKILL.md:96`.
- `$superpowers-project:implement-plan` already requires native goal activation, proof oracle use, verification receipts, cleanup evidence, push permission, branch push proof, and merge-ready proof in `skills/implement-plan/SKILL.md:20` through `skills/implement-plan/SKILL.md:38` and `skills/implement-plan/SKILL.md:95` through `skills/implement-plan/SKILL.md:107`.
- `$superpowers-project:resolve-issue` already requires issue acceptance coverage, verification proof, branch push proof, handoff proof, native goal completion proof, and PR close evidence in `skills/resolve-issue/SKILL.md:54` through `skills/resolve-issue/SKILL.md:59`.
- `$superpowers-project:merge-changes` already validates premerge and closeout ledgers in `skills/merge-changes/SKILL.md:214` through `skills/merge-changes/SKILL.md:228`.

**Impact:**

Krypton does not need to become a separate workflow route. The useful part is the review evidence shape: pre-plan alignment, post-plan drift, correctness, maintainability, and target-perspective verification. Treating those roles as separate routes would duplicate the existing Project Plan, Resolve, Implement, and Merge lifecycle.

**Repair requirement:**

Thread Krypton-style role evidence into existing ledgers and artifact review gates:

- `write-plan`: optional or required PRE plan-review evidence for high-risk plans.
- `implement-plan` and `resolve-issue`: setup ledger fields carrying the outcome contract from the approved plan.
- `implement-plan` and `resolve-issue`: final evidence fields for post-plan alignment, correctness review, maintainability review, and target-perspective proof.
- `merge-changes`: premerge proof should reject work when the contract drift, duplicate-path, or weak-evidence review fails.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P3: Krypton's pressure scenarios are strong regression fixtures for this plugin

**Observed evidence:**

- Krypton's wrong-layer scenario expects the agent to stop before implementation and require source-of-truth, read/write path, contract, displaced behavior, and real data-path evidence in `.codex-local/external/krypton/tests/pressure-scenarios/wrong-layer.md:1` through `.codex-local/external/krypton/tests/pressure-scenarios/wrong-layer.md:18`.
- Krypton's weak-evidence scenario treats tests as supporting evidence rather than completion proof in `.codex-local/external/krypton/tests/pressure-scenarios/evidence.md:1` through `.codex-local/external/krypton/tests/pressure-scenarios/evidence.md:14`.
- Krypton's cutover-debt scenario rejects two current-looking implementations without ownership and kill criteria in `.codex-local/external/krypton/tests/pressure-scenarios/cutover-debt.md:1` through `.codex-local/external/krypton/tests/pressure-scenarios/cutover-debt.md:15`.

**Impact:**

These scenarios match this repo's failure modes: stale paths, weak proof, duplicated workflow roots, and claims that outrun evidence. They would make the existing validators more behaviorally representative without adding a new runtime dependency.

**Repair requirement:**

Add local Superpowers Project scenario tests that encode those failures against the plugin's own skill text and validators. Keep the fixtures under this repo's test scripts rather than depending on the ignored downloaded copy.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Healthy Checks

- Krypton validated successfully from the repo-local ignored download.
- Krypton's evidence philosophy is aligned with Superpowers Project: tests and diffs support proof, but they are not the final user-visible or operator-visible proof.
- Superpowers Project already has stronger native continuation, approval, issue, merge, and closeout gates than Krypton provides by itself.
- The best integration path is additive: absorb Krypton's contract vocabulary and pressure tests into existing project skills, not a new top-level route.

## Recommended Repair Route

Use `$superpowers-project:write-plan` to create one implementation plan from this findings spec. The plan should target `M0 - Governance` and `M1 - Source Of Truth` because the work strengthens gate contracts and prevents parallel artifact roots.

Recommended plan tasks:

1. Extend the Project Plan contract with a Superpowers Project outcome contract section.
2. Add or extend plan validation for truth owner, contract interface, cutover, displaced path, evidence lane, and kill criteria.
3. Carry outcome contract fields through implement/resolve setup and final evidence ledgers.
4. Add post-plan, correctness, maintainability, and target-perspective review fields to execution closeout proof.
5. Add Krypton-inspired pressure scenario fixtures to repo-owned tests.
6. Update README and contract summary after validation.

## Non-Findings

- Do not vendor Krypton into `skills/` as a project plugin skill without a separate design decision. That would expand the public Superpowers Project surface and create route ambiguity.
- Do not install Krypton globally as part of this repo's validated sync. This repo's live sync should continue to deploy only the Superpowers Project plugin and the shared `advanced-user-input` helper.
- Do not copy Krypton's `docs/goals` lifecycle into the default issue-resolution path.

## Open Questions

- Should the outcome contract be mandatory for every plan or only for high-risk plans? The stronger default is every implementation plan, with lightweight "not applicable" explanations only for fields that truly do not apply.
- Should reviewer evidence be prose in the artifact review gate, structured ledger fields, or both? The stronger default is both: readable summary plus validator-consumable fields for execution and merge gates.
- Should the local ignored Krypton download remain for manual comparison, or should it be removed after the repo-owned pressure fixtures are added?
