# Krypton Contract Adoption Design

## Purpose

Adopt the best parts of Krypton's operator discipline inside Superpowers Project without adding a parallel workflow route or artifact root.

The goal is to make every Superpowers Project implementation plan and issue mirror carry the same ownership, contract, cutover, and evidence checks that Krypton emphasizes, while keeping the plugin's existing `docs/superpowers` lifecycle, native questions, issue mirrors, ledgers, and validation scripts authoritative.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the canonical artifact model as specs, plans, issue mirrors, and milestone pages under `docs/superpowers`.
- `skills/write-plan/SKILL.md` already requires acceptance criteria, proof oracle, test-complete definition, metrics handling, Task # Use Cases, and `docs/superpowers/plans` as the plan destination.
- `skills/create-issues/SKILL.md` owns issue mirror creation from approved plans.
- `skills/implement-plan/SKILL.md` owns non-issue branch-backed execution from approved plans.
- `skills/resolve-issue/SKILL.md` owns direct issue-backed execution from ready issue mirrors and linked source plans.
- `skills/merge-changes/SKILL.md` owns premerge and closeout proof for issue-backed PRs and local branch merges.
- `docs/superpowers/specs/2026-06-19-krypton-integration-audit-findings.md` records the downloaded Krypton evidence and concludes that direct Krypton execution conflicts with Superpowers Project's canonical artifact model.

## User Decisions

- Use an embedded contract approach, not a new top-level workflow route.
- Make the Superpowers-native Krypton contract mandatory for all implementation plans.
- Ensure plans and issue mirrors both carry and use the contract rules.
- Keep Superpowers Project compatible with existing plugin routing, validation, native continuation gates, and issue-backed execution.

## Design Alternatives Considered

### Design 1: Embedded Contract In Existing Skills

Add a required Superpowers Project outcome proof to `write-plan`, copy the relevant fields into issue mirrors through `create-issues`, and require `implement-plan`, `resolve-issue`, and `merge-changes` to verify the same fields during execution and integration.

This is the selected design. It gives Superpowers Project the Krypton benefits while preserving the current plugin interface and source-of-truth model.

### Design 2: Separate Adapter Skill

Create a new `$superpowers-project:krypton-contract` skill that reviews plans and issues before the existing skills run.

This keeps the contract concept isolated, but it adds route selection burden and creates another place for agents to forget a mandatory gate. It also weakens locality because plan readiness would be split across two skill interfaces.

### Design 3: External Krypton Bridge

Install upstream `krypton-planning` and `krypton-execution` as separate personal skills, then document how operators manually combine them with Superpowers Project.

This is useful for experimentation but not as the plugin's canonical behavior. Upstream Krypton defaults to a `docs/goals` package, while Superpowers Project requires `docs/superpowers` artifacts and issue mirrors.

## Recommended Approach

Implement Design 1.

The contract should become part of the existing Superpowers Project module interfaces:

- `write-plan` writes the full contract.
- `create-issues` condenses the contract into issue mirrors.
- `implement-plan` and `resolve-issue` restate and enforce the contract before edits.
- `merge-changes` verifies that implementation evidence still satisfies the contract before integration.
- validators reject ready-state claims when required contract fields or evidence are missing.

This keeps the contract deep: one plan contract pays back across planning, issue creation, execution, review, and merge proof.

## Contract Shape

Every implementation plan must include a `## Outcome Proof` section before task decomposition.

Required fields:

- **Intent:** the product, operator, or engineering outcome served.
- **Current Behavior:** what exists now.
- **Expected Outcome:** what should be true after the work.
- **Target Output:** what the target person or operator sees, receives, runs, inspects, or trusts.
- **Owner:** the module, artifact, or process that owns the durable truth.
- **Interface:** the interface that crosses from owner to consumer, including expected shape, invariants, and trust assumptions.
- **Cutover:** delete, redirect, demote, shim with removal trigger, or explicitly keep the old path.
- **Replaced Path:** the behavior, artifact, route, doc, or source file that stops being current.
- **Evidence:** browser, API, CLI, generated artifact, persisted record, trace, GitHub state, or workflow ledger.
- **Acceptance Proof:** the exact target-perspective proof required.
- **Stop Criteria:** what must happen if a temporary path, shim, or duplicate implementation cannot be proven or retired.
- **Avoid:** changes the agent must not make because they would create wrong ownership, duplicate truth, or fake proof.
- **Risk:** what breaks or becomes misleading if the contract is violated.

Every plan must also include a `## Implementation Boundaries` section before tasks.

Required fields:

- **Files To Create**
- **Files To Modify**
- **Files To Avoid**
- **Source Of Truth**
- **Read Path**
- **Write Path**
- **Integration Points**
- **Migration Or Cutover**
- **Replaced Path Handling**
- **Acceptance Proof Gate**

Fields may say that no displaced path exists only when the plan names why no old path is being replaced. Empty generic answers are invalid.

## Plan Integration

`$superpowers-project:write-plan` should add the outcome proof after the existing required header and before `## Acceptance Criteria` or task sections.

The planning grill should ask native questions for unresolved contract fields before a plan is saved. If repo inspection can answer a field, the agent should inspect first and write the evidence instead of asking the user.

Task # Use Cases stay mandatory. Each task's use cases should tie back to at least one contract concern:

- target-perspective output
- contract interface behavior
- cutover or displaced path handling
- acceptance evidence
- failure or recovery path
- validator or ledger behavior

The plan is not ready when Task # Use Cases do not cover the contract's acceptance evidence and cutover risk.

## Issue Mirror Integration

`$superpowers-project:create-issues` should copy a compact outcome workflow into every issue mirror created from a plan.

Issue mirror fields:

- **Outcome Source:** linked source plan and section.
- **Intent**
- **Target Output**
- **Owner**
- **Interface**
- **Cutover**
- **Replaced Path**
- **Acceptance Proof**
- **Stop Criteria**
- **Avoid**

For multi-issue plans, each issue mirror must say which part of the source contract it owns. An issue can narrow the contract for its slice, but it cannot contradict or drop the source plan's truth owner, contract interface, cutover, or evidence requirement.

Issue mirror validation should reject issue-ready state when the mirror lacks the outcome workflow or when the summary conflicts with the source plan.

## Execution Integration

`$superpowers-project:implement-plan` and `$superpowers-project:resolve-issue` should restate the contract before code edits:

- goal
- plan path
- issue mirror path when applicable
- intent
- truth owner
- contract interface
- cutover decision
- displaced path
- acceptance evidence
- kill criteria
- forbidden moves

Setup ledgers should carry these fields from the source plan or issue mirror. Plain prose memory is not enough.

During task execution, the agent must stop and ask through native UI when a needed decision would change:

- truth owner
- contract interface
- cutover decision
- displaced path handling
- acceptance evidence
- kill criteria
- forbidden moves

Execution may continue only when the answer is recorded in the relevant artifact or ledger.

## Review And Merge Integration

Execution closeout should add four readiness review lanes:

1. **Plan Alignment Review:** verifies implementation still matches intent, truth owner, contract interface, cutover, displaced path, acceptance evidence, and kill criteria.
2. **Correctness Review:** verifies target behavior, security, data integrity, freshness, and trust assumptions.
3. **Maintainability Review:** verifies no duplicate current-looking path, stale artifact, unclear ownership, misleading comment, or unnecessary indirection remains.
4. **Reality Evidence Review:** verifies the target-perspective proof from the selected evidence lane.

`$superpowers-project:merge-changes` should treat failed readiness review as failed premerge proof. A passing test command or clean diff is supporting evidence, not enough by itself.

Final `Done` remains governed by the existing merge and closeout gates. The Krypton-derived contract adds required proof content; it does not replace native continuation, merge approval, cleanup, issue close verification, or clean repo proof.

## Validator Design

Add a plan contract validator, or extend the existing plan validator, to enforce:

- `## Outcome Proof` exists.
- all required outcome proof fields exist and are non-empty.
- `## Implementation Boundaries` exists.
- all required architecture slice fields exist and are non-empty.
- no field uses a generic answer when a concrete owner, interface, path, or evidence artifact is required.
- Task # Use Cases include at least one use case tied to acceptance evidence and one tied to cutover or displaced path handling when those fields are active.

Add issue mirror validation for:

- outcome workflow exists.
- contract source links to the source plan.
- issue contract fields do not contradict source plan fields.
- issue acceptance criteria and proof oracle cover the issue's contract slice.

Add execution and merge validation for:

- setup ledgers carry contract fields.
- PR-ready or merge-ready evidence names contract coverage.
- premerge proof rejects missing plan alignment review, correctness review, maintainability review, or reality evidence review.

## Error Handling

Missing contract fields block plan readiness.

Missing issue outcome workflow blocks issue-ready execution.

Contract drift during implementation blocks push, PR-ready handoff, or merge-ready output until the plan or issue mirror is revised and reviewed.

Missing target-perspective evidence blocks completion. The agent should report the exact missing evidence and keep the workflow in Revisit or repair routing instead of marking the work done.

Conflicts between source plan and issue mirror block execution until `$superpowers-project:create-issues` or `$superpowers-project:write-plan` repairs the artifact chain.

## Testing And Proof

Focused proof should include:

```bash
./skills/write-plan/scripts/test-scenarios.sh
./skills/create-issues/scripts/test-scenarios.sh
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/validate.sh
```

Required scenarios:

- wrong-layer feature: plan is rejected until truth owner, contract interface, and evidence lane are explicit.
- weak evidence: PR-ready or merge-ready proof is rejected when only tests or diffs are provided.
- cutover debt: plan or merge proof is rejected when two current-looking paths remain without ownership and kill criteria.
- issue mirror propagation: issue mirror is rejected when it drops required source plan contract fields.
- contract drift: execution closeout is rejected when implementation changes truth owner, contract interface, or cutover without recorded approval.

## Acceptance Criteria

- Every saved implementation plan has a required Superpowers Project outcome proof.
- Every saved implementation plan has an architecture slice that names source of truth, read path, write path, contract interface, cutover, displaced path handling, and evidence gate.
- Every issue mirror created from a plan carries a compact outcome workflow linked to the source plan.
- Issue execution cannot start when the issue mirror lacks or contradicts contract fields.
- Implement and resolve setup ledgers carry contract fields from the approved plan or issue mirror.
- PR-ready, merge-ready, premerge, and closeout evidence include plan alignment, correctness, maintainability, and target-perspective evidence reviews.
- Existing native continuation, approval, issue, merge, cleanup, and final `Done` gates remain authoritative.
- Full repo validation passes after implementation.

## Non-Goals

- Do not add upstream Krypton as a bundled Superpowers Project skill.
- Do not create a `docs/goals` artifact root for default Superpowers Project work.
- Do not rename existing Superpowers Project skills.
- Do not replace Task # Use Cases, native `/goal`, issue mirrors, Auto Mode ledgers, merge approval, or cleanup proof.
- Do not require a new external runtime or network call for normal validation.

## Open Questions For Planning

- Should the validator be one new `validate-plan-outcome-proof.sh` script or an extension of `validate-plan-task-use-cases.sh`?
- Should issue mirror contract validation live in the create-issues mirror validator or a shared contract helper consumed by create, resolve, and merge scripts?
- Which contract fields should become machine-readable ledger fields first if the implementation needs to land incrementally?

