# Closeout Artifact Review And Plan Metrics Design

## Purpose

Tighten the Superpowers Project workflow contract so every skill closeout explicitly shows the artifacts it produced, summarizes what the results mean, and asks stronger planning questions about what counts as test complete. Push and merge questions should happen only after that evidence review. Planning workflows should force explicit success metrics, especially numerical pass criteria for scientific and engineering projects.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the durable lifecycle as `spec -> plan -> issue`, with final integration owned by `merge-changes`.
- `skills/brainstorm-spec/SKILL.md` currently requires a summary before the continuation question and says to show rendered Markdown artifacts when created or changed artifacts are Markdown and reasonably sized.
- `skills/write-plan/SKILL.md` currently requires a summary before the continuation question and says to show rendered Markdown artifacts when created or changed artifacts are Markdown and reasonably sized.
- `skills/audit-project/SKILL.md`, `skills/create-issues/SKILL.md`, `skills/implement-plan/SKILL.md`, and `skills/orchestrate-issues/SKILL.md` use the same pattern: summarize the result, name key artifacts, and show rendered Markdown artifacts when applicable.
- That current pattern is not the same as a universal artifact review gate. It does not require a complete inventory of all produced artifacts, does not require explicit treatment of machine-readable artifacts such as ledgers or validation receipts, and does not require the agent to explain what the results mean for the full goal and project context.
- `skills/write-plan/SKILL.md` requires a planning grill for scope, acceptance criteria, sequencing, proof oracle, TDD policy, branch strategy, routing, publish behavior, and live mutation.
- `skills/write-plan/SKILL.md` does not currently require a dedicated direct question that defines `test complete`, the pass metrics, acceptable tolerances, numerical thresholds, units, or scientific/engineering proof criteria before the plan is treated as ready.
- `docs/superpowers/specs/2026-06-04-post-commit-push-merge-and-stale-cache-design.md` already tightened continuation and push/merge governance, so this spec should extend that stricter closeout behavior instead of creating a parallel contract.

## User Decisions

- Every skill closeout should have an explicit artifact review gate.
- The artifact review requirement should be a hard gate at every skill closeout, not a best-effort summary or optional narration block.
- The agent should show all produced artifacts at closeout, not only a selective mention of Markdown files.
- The artifact review gate must happen before any continuation, push, publish, or merge question. The agent must not ask for a decision first and promise to summarize later.
- The agent should create a findings summary that states what it thinks the results mean, how they affect the current goal, how they affect the broader project context, and what next steps follow from that reading.
- The findings summary should explicitly cover the full project context and suggested next steps, not only the immediate route choice.
- That richer summary is most important before push and merge questions.
- Brainstorming and planning should also use the summary pattern, but with a lighter-weight version than push/merge closeout.
- `Stop` should stay available as a terminal option, but it must not be the recommended answer when a clean forward route exists and the user has not asked to stop.
- `write-plan` closeout must ask direct questions that define what counts as test complete.
- `write-plan` closeout must ask those questions directly and natively, not hide them inside a long prose summary or vague acceptance text.
- For scientific or engineering projects, `write-plan` must ask for the numerical metrics, thresholds, tolerances, or target values that define pass/fail and should record those values as plan goals.

## Problem Statement

The current skill contracts have partial closeout summaries, but not a fully explicit artifact review gate. That leaves three gaps.

First, produced artifacts can remain under-exposed. Markdown specs and plans may be rendered, but machine-readable ledgers, proof receipts, audit outputs, branch evidence, commit evidence, and other closeout artifacts are not uniformly surfaced in a predictable way.

Second, the closeout summary is too descriptive and not interpretive enough. A workflow can name what it produced without clearly stating what the agent believes those results imply for the goal, the repo, the workflow state, or the next safe action.

Third, plan creation can still produce a plan that sounds structured but does not sharply define test completion. For scientific and engineering work, that is a real defect because the plan may omit the numerical criteria that distinguish a passing result from a merely plausible one.

Because push and merge are user-facing commitment points, those gaps are most costly there. The user should see the artifacts, the agent's reading of them, and the recommended next route before being asked to authorize publication or integration.

## Recommended Approach

Add one shared closeout contract plus one planning-specific metric contract:

1. A universal artifact review gate before every skill continuation question.
2. A mandatory findings summary that interprets results in goal and project context.
3. A strict evidence-review requirement before push and merge questions.
4. A `write-plan` test-complete and metrics gate that blocks plan readiness until success criteria are explicit.
5. Scientific and engineering planning prompts that require numerical pass criteria when the project domain depends on measurable technical results.

These changes should be expressed in repo-owned skill text, metadata, validation checks, and scenario tests. Auto Mode should inherit the same gates instead of bypassing them.

## Workflow Design

### Universal Artifact Review Gate

Before any skill asks its continuation question, it must complete an explicit artifact review gate.

This is a blocking closeout rule. A skill closeout is not valid when it skips artifact surfacing and jumps straight to a continuation, push, publish, or merge question.

The gate requires:

- an inventory of every produced or materially changed artifact owned by that skill run
- exact artifact paths or identifiers
- rendered display for human-readable Markdown artifacts
- concise surfaced content for non-Markdown artifacts
- clear indication when no artifact of a given expected type was produced

Artifacts to surface can include:

- saved specs, plans, issue mirrors, milestone docs, or repair docs
- validation reports and audit outputs
- JSON, YAML, or Bash-generated ledgers
- verification receipts
- branch names, commit ids, PR URLs, merge confirmations, or sync-live outputs

This gate should be treated as mandatory closeout work, not optional flavor text.

### Closeout Ordering Rule

Closeout order should be explicit and invariant:

1. show all produced or materially changed artifacts owned by the skill run
2. explain what those artifacts say
3. explain what the agent thinks that means for the active goal and the full project context
4. recommend the next safe route
5. only then ask the continuation, push, publish, or merge question

This ordering matters most at publish and integration boundaries because the user should never be asked to authorize push or merge before seeing the underlying artifacts and the agent's interpretation of them.

### Artifact Display Policy By Type

To avoid noisy raw dumps while still honoring the user's requirement to show all produced artifacts:

- Markdown artifacts: render the artifact in chat when reasonably sized, with exact path shown.
- JSON/YAML/ledger artifacts: show exact path plus a concise structured summary of the key fields and decisions; offer raw content only when explicitly requested or when the artifact is small and human-facing.
- Command/proof artifacts: show the exact command or proof source, the pass/fail result, and the key evidence extracted from it.
- Non-file artifacts such as branch, commit, PR, merge, or cleanup state: show them as explicit closeout evidence entries.

The important contract is visibility of every produced artifact, not mandatory raw dumping of every byte.

### Findings Summary Contract

After the artifact review gate and before the continuation question, every skill closeout should include a findings summary with these elements:

- what was produced or changed
- what the results say
- what the agent thinks those results and findings mean
- what that means for the active goal
- what that means for the broader or full project context
- what next steps are now recommended

This should be expressed as an interpretation step, not just a file list.

### Strict Pre-Push And Pre-Merge Review Gate

Before asking push or merge questions, the skill must first show:

- all closeout artifacts relevant to that decision
- verification or validation results
- the agent's interpretation of whether the branch, PR, or closeout evidence is actually ready
- the recommended next step and why

Push and merge approval questions should be blocked until that review gate is satisfied. This applies to both manual routes and Auto Mode routes that need user approval at those points.

### Stop Recommendation Policy

`Stop` remains available at the top-level closeout gate, but recommendation policy should be stricter than availability. The agent should not recommend `Stop` merely because the branch is locally healthy, the immediate ask has been satisfied, or a broader forward route is already authorized and ready. When a clean forward route exists and the user has not indicated that they want to stop, the recommendation should stay on the forward or review path instead of steering toward termination.

### Lighter Brainstorming And Planning Review

Brainstorming and planning should also follow the artifact review gate, but the closeout summary can be lighter:

- show the saved artifact
- summarize the decisions made and assumptions removed
- interpret what the artifact means for the next workflow step
- recommend the next route

They do not need the same heavy verification framing as push and merge, but they still need explicit artifact visibility and a real interpretation summary.

### Plan Test-Complete Gate

`write-plan` should add a mandatory direct-question gate before the plan is considered ready for execution. The goal is to force clarity on what counts as complete, not to leave it buried in vague acceptance text.

When `request_user_input` is callable, these should be asked as native decision questions rather than left as prose assumptions.

The plan closeout should be explicit that the agent is asking the user to define the test-complete boundary for the plan, not merely to review wording. A plan is not ready just because it has tasks, phases, or generic acceptance bullets.

Required direct questions should cover:

- what exactly counts as `test complete`
- what proof demonstrates that status
- which tests, checks, or user-visible behaviors are required
- what metrics define pass versus fail
- whether any tolerances, edge cases, or error bounds matter

If the plan cannot answer those questions, the plan is not ready for `Continue Into Work`.

### Suggested Direct Questions For `write-plan`

The exact UI wording can vary, but the plan workflow should directly force answers to questions equivalent to:

- what exact condition means this work is test complete
- what proof, checks, or user-visible evidence demonstrate that condition
- what metrics make the result a pass instead of a fail
- what edge cases, tolerances, or regression checks are part of that decision
- for scientific or engineering work, what numerical goals, thresholds, tolerances, units, datasets, or validation ranges define success

Those answers should then be carried into the saved plan instead of remaining only in the chat transcript.

### Scientific And Engineering Metrics Gate

When the project is scientific, numerical, modeling, simulation, optimization, thermodynamic, data-analysis, or engineering-oriented, `write-plan` should ask explicit metric questions such as:

- what numerical metrics determine success
- what threshold, target, tolerance, uncertainty band, residual, or error bound is acceptable
- what units apply
- what dataset, benchmark, scenario set, or validation range the metric must cover
- whether there are baseline-comparison or regression-protection numbers that must be met

Those answers should be written into the plan as explicit acceptance criteria, plan goals, and proof-oracle content, not kept only in chat.

### Plan Readiness Rule

A plan must not close out as ready, and must not route into `implement-plan`, `create-issues`, `resolve-issue`, or `orchestrate-issues`, unless one of these is true:

- the test-complete and metrics questions were answered explicitly, or
- the skill recorded that they are not applicable with a clear reason

For scientific or engineering work, a vague answer such as `tests pass` is not sufficient. The plan should contain the actual quantitative success definition when one is relevant.

### Auto Mode Behavior

Auto Mode should inherit these same rules:

- it must not bypass the artifact review gate
- it must not bypass the findings summary requirement
- it must not bypass the plan test-complete / metrics gate
- if the needed criteria are missing, Auto Mode should stop outside policy and return to a native question rather than guessing

## Implementation Surface

Likely files:

- `skills/advanced-user-input/SKILL.md`
- `skills/advanced-user-input/agents/openai.yaml`
- `skills/brainstorm-spec/SKILL.md`
- `skills/brainstorm-spec/agents/openai.yaml`
- `skills/write-plan/SKILL.md`
- `skills/write-plan/agents/openai.yaml`
- `skills/create-issues/SKILL.md`
- `skills/create-issues/agents/openai.yaml`
- `skills/implement-plan/SKILL.md`
- `skills/implement-plan/agents/openai.yaml`
- `skills/resolve-issue/SKILL.md`
- `skills/resolve-issue/agents/openai.yaml`
- `skills/orchestrate-issues/SKILL.md`
- `skills/orchestrate-issues/agents/openai.yaml`
- `skills/merge-changes/SKILL.md`
- `skills/merge-changes/agents/openai.yaml`
- `scripts/test-advanced-user-input-policy.sh`
- `scripts/test-native-continuation-loop.sh`
- skill-specific scenario suites for `brainstorm-spec`, `write-plan`, `implement-plan`, `resolve-issue`, `orchestrate-issues`, and `merge-changes`

If a shared helper is useful, it should validate that required closeout artifact entries and interpretation-summary sections exist before a continuation gate is treated as valid.

## Validation Expectations

Validation should prove:

- every governed skill closeout explicitly requires artifact review before the continuation question
- governed skills require a findings summary that includes result meaning, goal impact, project-context impact, and recommended next steps
- push and merge questions are preceded by an explicit review/evidence summary requirement
- `write-plan` explicitly asks what counts as test complete
- `write-plan` explicitly asks for pass metrics and proof criteria
- scientific/engineering planning explicitly asks for numerical thresholds, tolerances, or targets when relevant
- Auto Mode contracts do not allow bypassing these gates
- repo validation and live-sync validation pass after the changes

## Proof Oracle Candidates

- `rg -n "artifact review|rendered Markdown artifacts|what the results mean|project context|recommended next steps" skills`
- `rg -n "test complete|numerical metrics|threshold|tolerance|units|pass/fail" skills/write-plan`
- scenario tests that fail when a continuation question is asked without prior artifact review language
- scenario tests that fail when push or merge approval appears without prior evidence-summary language
- scenario tests that fail when `write-plan` can close out without test-complete and metrics prompts
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`

## Tradeoffs

This design adds more closeout structure and more native questions. That is intentional. The cost is extra interaction and slightly longer closeout text. The benefit is that the user sees the actual artifacts, gets the agent's interpretation before making publish/integration decisions, and receives plans with measurable success criteria instead of vague completion language.

The main practical tradeoff is artifact verbosity. Showing all artifacts can become noisy if raw machine-readable content is dumped indiscriminately. The design avoids that by requiring visibility for every artifact while allowing concise summaries for machine artifacts and full rendering for human-facing artifacts.

## Non-Goals

- Do not require raw full-text dumps of every machine-readable ledger by default.
- Do not weaken the stricter push/merge governance already captured in the existing workflow-hardening spec.
- Do not let `write-plan` hand-wave scientific or engineering success criteria as generic `tests pass`.
- Do not make Auto Mode a loophole around these closeout and planning questions.

## Milestone Linkage

- `M0 - Governance`: closeout gates, interpretation summaries, and planning-metric hardening.
- `M1 - Source Of Truth`: source skill text, live install, and validation surfaces should agree on the new contract.

## Open Questions For Planning

- Should the universal artifact review gate use one shared structured ledger across all skills, or should each skill keep its own closeout ledger shape while following one shared policy?
- For large Markdown artifacts, should the default behavior be full rendered preview, or a rendered excerpt plus exact path with full preview on demand?
- Should the scientific/engineering metrics questions be triggered by explicit repo/project classification only, or also by plan content that implies numerical validation even in a generally non-scientific repo?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the spec consistently requires artifact visibility, interpretation, and stronger metric-based plan readiness.
- Scope check: this is one coherent governance slice across closeout and planning quality.
- Ambiguity check: remaining open questions are about implementation shape, not the core direction.
