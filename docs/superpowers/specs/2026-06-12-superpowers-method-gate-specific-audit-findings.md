# Superpowers Method Gate Specific Audit Findings

## Scope

Audit the Superpowers Project adapter skills that claim to use upstream Superpowers methods, then turn the broad method-gate findings into specific repair specs that are ready for `$superpowers-project:write-plan`.

The audit focuses on whether project adapter skills merely name upstream Superpowers skills or enforce the upstream gate strongly enough that a brand-new agent cannot skip the method checklist.

## Review Question

Which Superpowers Project skills still use upstream Superpowers skills too softly, and what exact source changes and proof oracles should harden each gate?

## Companion Skills Used

- `$superpowers-project:audit-project`

No implementation or mutation companion skill was used. This is a findings-first contract audit that produces a source spec for later planning.

## Checked Artifacts

- `skills/implement-plan/SKILL.md`
- `skills/implement-plan/agents/openai.yaml`
- `skills/implement-plan/scripts/lib/contract.ps1`
- `skills/implement-plan/scripts/test-scenarios.ps1`
- `skills/resolve-issue/SKILL.md`
- `skills/resolve-issue/agents/openai.yaml`
- `skills/resolve-issue/scripts/test-scenarios.ps1`
- `skills/orchestrate-issues/SKILL.md`
- `skills/orchestrate-issues/agents/openai.yaml`
- `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1`
- `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1`
- `skills/write-plan/SKILL.md`
- `skills/write-plan/agents/openai.yaml`
- `skills/write-plan/scripts/test-scenarios.ps1`
- `skills/initiate-workflow/SKILL.md`
- Upstream method contracts by canonical skill name: `superpowers:using-git-worktrees`, `superpowers:executing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `superpowers:finishing-a-development-branch`, and `superpowers:subagent-driven-development`

## Findings

### P1: `implement-plan` does not require the upstream worktree isolation and clean baseline gate

**Observed evidence:**

- `skills/implement-plan/SKILL.md:46` through `skills/implement-plan/SKILL.md:62` requires only a development branch and topology choice before implementation.
- `skills/implement-plan/SKILL.md:64` through `skills/implement-plan/SKILL.md:74` requires `superpowers:executing-plans`, TDD, debugging, verification, and optional subagent discipline, but omits `superpowers:using-git-worktrees`.
- `skills/implement-plan/scripts/lib/contract.ps1:27` through `skills/implement-plan/scripts/lib/contract.ps1:32` validates native goal, branch, topology, and passed verification, but has no field for worktree isolation proof or clean baseline proof.
- A source search for `using-git-worktrees` under `skills/implement-plan` returns no active contract requirement.

**Impact:**

Non-issue implementation can begin in a normal checkout on a development branch without the upstream worktree detection, native worktree preference, submodule guard, ignored-directory safety, dependency setup, or clean baseline test proof. That weakens the same isolation method that issue-backed execution already treats as mandatory.

**Repair requirement:**

Add an `Isolation And Baseline Gate` to `$superpowers-project:implement-plan` before code edits, branch mutation beyond setup, or worker handoff:

- Require `superpowers:using-git-worktrees` before implementation work begins.
- Detect whether the current workspace is already isolated by comparing `git rev-parse --git-dir` and `git rev-parse --git-common-dir`, including the upstream submodule guard.
- Prefer Codex/native worktree tooling when available; use Git worktree fallback only when no native tool is available and the user or repo policy allows it.
- If staying in the current checkout is allowed, record the explicit reason and branch proof.
- Run project setup and clean baseline verification before task execution starts.
- If baseline tests fail, stop and route to Revisit or debugging; do not silently proceed.
- Carry isolation and baseline proof into the implement-plan structured handoff ledger.

**Acceptance criteria:**

- `skills/implement-plan/SKILL.md` explicitly names `superpowers:using-git-worktrees` as mandatory.
- `skills/implement-plan/agents/openai.yaml` repeats the isolation and baseline gate for startup-loaded agents.
- `skills/implement-plan/scripts/lib/contract.ps1` rejects handoff ledgers missing isolation proof or baseline proof.
- `skills/implement-plan/scripts/test-scenarios.ps1` fails if the worktree/baseline gate text or contract checks are removed.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Add a fixture where an implement-plan ledger has branch, topology, and passed verification but no isolation or baseline fields. The contract helper must reject it.

### P1: `orchestrate-issues` does not enforce the upstream subagent two-stage review loop

**Observed evidence:**

- `skills/orchestrate-issues/SKILL.md:77` through `skills/orchestrate-issues/SKILL.md:87` says the route adapts `superpowers:subagent-driven-development`, but only requires a companion skill set in the worker handoff.
- `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1:85` through `skills/orchestrate-issues/scripts/prepare-worker-handoff.ps1:89` emits skill names, but no review policy fields.
- `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1:59` validates required skill names, but not fresh subagent per task, spec compliance review, code quality review, re-review loops, final review, or blocked-status handling.
- Source search under `skills/orchestrate-issues` finds no active references to `two-stage`, `spec compliance`, `code quality`, or `final code reviewer`.

**Impact:**

A worker handoff can satisfy the current validator by listing companion skills while skipping the upstream quality gates that make subagent-driven development safe: fresh context per task, spec compliance review before quality review, re-review until approved, and final whole-implementation review.

**Repair requirement:**

Add a `Subagent Review Gate` to `$superpowers-project:orchestrate-issues` and its worker handoff ledger:

- Require fresh worker/subagent context per issue task or an explicit reason the issue is a single indivisible task.
- Require the worker to extract full task text and context before implementation.
- Require implementer status handling: `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, and `BLOCKED`.
- Require spec compliance review before code quality review.
- Require code quality review only after spec compliance passes.
- Require reviewer-found issues to return to the implementer and be re-reviewed until approved.
- Require final whole-implementation review before PR-ready handoff.
- Block PR-ready intake if worker evidence omits review receipts.

**Acceptance criteria:**

- `skills/orchestrate-issues/SKILL.md` explicitly requires the two-stage review loop from `superpowers:subagent-driven-development`.
- `skills/orchestrate-issues/agents/openai.yaml` repeats the two-stage review requirement.
- `prepare-worker-handoff.ps1` emits structured review policy fields.
- `validate-worker-handoff.ps1` rejects handoffs missing spec-review, code-quality-review, re-review, or final-review requirements.
- Scenario tests fail if the review gate is weakened to skill-name presence only.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Add one fixture that lists all companion skills but omits review policy. Validation must fail.

### P2: Execution adapters require TDD by name but do not require red/green proof

**Observed evidence:**

- `skills/implement-plan/SKILL.md:69` requires `superpowers:test-driven-development` for feature and bug work unless the approved plan records an opt-out.
- `skills/resolve-issue/SKILL.md:186` requires `superpowers:test-driven-development` for feature or bug code unless the source plan records an opt-out.
- `skills/orchestrate-issues/SKILL.md:82` requires `superpowers:test-driven-development` in the worker handoff.
- `skills/implement-plan/scripts/lib/contract.ps1:32` requires only `verification.passed`, not TDD red/green proof.
- `skills/orchestrate-issues/scripts/validate-worker-handoff.ps1:59` requires the skill name but not test-first receipts.

**Impact:**

An implementation can report verification passed while never proving the upstream TDD core rule: no production code without a failing test first. The project contract currently checks the method label more strongly than the method evidence.

**Repair requirement:**

Add a `TDD Red/Green Proof Gate` to `$superpowers-project:implement-plan`, `$superpowers-project:resolve-issue`, and `$superpowers-project:orchestrate-issues` worker handoffs:

- Feature, bug, refactor, and behavior-change tasks require a failing test before production code.
- Proof must record the RED command, expected failing assertion or failure reason, GREEN command, passing result, and final relevant test command.
- If a plan records an explicit TDD opt-out, the execution ledger must name the opt-out source and scope.
- A generic `verification.passed: true` field is not enough for TDD-covered work.
- If implementation code exists before RED proof, the route must stop and route to Revisit unless the plan explicitly marks the task as non-code or opt-out.

**Acceptance criteria:**

- Implement-plan and resolve-issue completion evidence require per-task TDD receipts for TDD-covered tasks.
- Orchestrate worker handoffs require workers to return TDD receipts in PR-ready evidence.
- Contract helpers reject feature/bug ledgers with verification proof but no red/green proof.
- Scenario tests cover accepted explicit opt-out, rejected missing RED proof, and rejected pass-only proof.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P2: Execution adapters require debugging discipline by name but not the upstream phase gates

**Observed evidence:**

- `skills/implement-plan/SKILL.md:70` requires `superpowers:systematic-debugging` or `diagnose` for bugs, regressions, CI failures, performance work, or unclear failure modes.
- `skills/resolve-issue/SKILL.md:187` has the same requirement for issue-backed execution.
- `skills/write-plan/SKILL.md:131` says bug, regression, CI, or performance plans require debugging discipline before proposing a fix.
- Source search under the implementation adapters finds no active gate for `Phase 1`, `root cause`, `hypothesis`, or the upstream "3 failed fixes" stop condition.

**Impact:**

Agents can satisfy the current contract by saying debugging discipline is required, then still jump straight to a fix without root-cause evidence. The project adapter does not force the upstream order: reproduce, gather evidence, identify pattern, state a hypothesis, test it minimally, then implement one root-cause fix.

**Repair requirement:**

Add a `Debugging Phase Proof Gate` for bug, regression, CI, performance, or unclear failure work:

- Before proposing or implementing fixes, record Phase 1 root-cause evidence: error text, reproduction, recent-change check, component-boundary evidence when relevant, and data-flow trace when relevant.
- Record Phase 2 pattern analysis: similar working examples or reference comparison.
- Record Phase 3 hypothesis: one root-cause hypothesis and the smallest test of that hypothesis.
- Phase 4 implementation must include a failing reproduction test before the fix when feasible.
- If three fix attempts fail, stop and route to architecture review or user decision before a fourth fix.
- Execution ledgers must distinguish root-cause proof from final verification proof.

**Acceptance criteria:**

- `implement-plan`, `resolve-issue`, and `write-plan` all name the debugging phase proof required for bug-shaped work.
- Bug-shaped execution evidence cannot pass with only "diagnose used" or final tests passed.
- Scenario tests reject missing root-cause proof and reject a fourth fix attempt without an architecture/user-decision route.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\implement-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P2: `write-plan` is still softer than upstream `superpowers:writing-plans` on exact plan content

**Observed evidence:**

- `skills/write-plan/SKILL.md:129` through `skills/write-plan/SKILL.md:131` names TDD, debugging, and verification discipline for plans.
- `skills/write-plan/SKILL.md:133` through `skills/write-plan/SKILL.md:155` defines the local task shape and says generic labels must be replaced before saving.
- `skills/write-plan/SKILL.md:257` through `skills/write-plan/SKILL.md:268` defines self-review checks.
- Source search under `skills/write-plan/scripts` finds no validator for upstream no-placeholder failures such as `TBD`, `TODO`, `Similar to Task N`, missing code blocks for code steps, missing expected output, or type-signature inconsistency.

**Impact:**

The local `Task # Use Cases` validator is strict, but a plan can still look ready while containing vague implementation steps that upstream `superpowers:writing-plans` treats as plan failures. That weakens downstream execution because `implement-plan`, `resolve-issue`, and workers consume saved plans as authority.

**Repair requirement:**

Add a `Plan Exactness Gate` to `$superpowers-project:write-plan`:

- Block placeholders: `TBD`, `TODO`, `fill in`, `implement later`, `similar to`, and generic "add appropriate" wording in ready plans.
- Require exact files, exact commands, and expected results for each task step.
- Require code blocks or precise patch descriptions for steps that change code.
- Require tests to include the actual test behavior or command, not "write tests for the above."
- Require a type/name consistency self-review that checks function names, file names, question IDs, route IDs, and field names across tasks.
- Add or extend a validator so this is checked mechanically before artifact review.

**Acceptance criteria:**

- `skills/write-plan/SKILL.md` includes the upstream no-placeholder failure list as a blocking gate.
- `skills/write-plan/agents/openai.yaml` summarizes the exactness gate for startup-loaded agents.
- A new or existing validator rejects ready plans with placeholders, generic code instructions, missing expected output, or "similar to" shortcuts.
- `scripts/validate.ps1` includes the exactness validator.

**Proof oracle candidates:**

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\write-plan\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath <fixture-plan>
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Healthy Checks

- `$superpowers-project:brainstorm-spec` now explicitly requires the upstream `superpowers:brainstorming` ordered checklist, Design 1 / Design 2 alternatives, design-section approvals, written spec self-review, and user review before planning or Auto Mode.
- `$superpowers-project:merge-changes` already has strong premerge, native merge approval, closeout, cleanup, clean-state, terminal-decision, and final Done gates.
- `$superpowers-project:create-issues` already has concrete issue mirror metadata, approval, validation, hydration, and execution-boundary requirements for tracker artifacts.
- `$superpowers-project:align-project` and `$superpowers-project:setup-project` are report/setup routes, not direct upstream execution adapters, and their current concerns are not the same method-gate weakness audited here.

## Recommended Repair Route

Create one `$superpowers-project:write-plan` from this spec with five tasks:

1. Harden `$superpowers-project:implement-plan` with worktree isolation and clean baseline proof.
2. Harden `$superpowers-project:orchestrate-issues` with subagent two-stage review proof.
3. Harden execution routes with TDD red/green proof ledgers.
4. Harden bug-shaped routes with systematic-debugging phase proof.
5. Harden `$superpowers-project:write-plan` with plan exactness validation.

The first two tasks should be prioritized because they affect whether implementation starts in the correct workspace and whether delegated work gets real review. The TDD/debugging/plan-exactness gates can follow as one plan or become separate issue-backed slices.

## Open Questions

- Should `$superpowers-project:implement-plan` always require a linked worktree, or is explicit current-checkout execution allowed when native worktree tooling is unavailable and the user approves it?
- Should TDD red/green proof be stored directly in implementation/PR-ready ledgers, or in a separate generated evidence artifact referenced by the ledgers?
- Should the plan exactness validator be strict for all saved plans, or only for plans marked ready for implementation?
