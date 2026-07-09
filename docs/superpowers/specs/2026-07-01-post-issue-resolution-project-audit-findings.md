# Post-Issue-Resolution Project Audit Findings

**Date:** 2026-07-01

**Scope:** Full Superpowers Project repo audit after the loop-mode hardening and GitHub sub-issue hierarchy issue resolution work.

**Audit route:** `$superpowers-project:audit-project` source workflow, with companion review lenses for strict code quality, repo architecture, and alignment health.

**Initial result:** No P0 blockers were found. The repo was clean, all GitHub issues were closed, the active backlog was empty, workflow-contract validation passed, source/live plugin checks passed, and the recent sub-issue hierarchy mirrors matched inspected GitHub hierarchy fields. The remaining holes identified by this audit were tracker-hygiene coverage, native route drift, validator coverage, closed mirror lifecycle cleanup, and maintainability pressure from large workflow/test files.

**Resolution status:** Resolved on branch `codex/resolve-audit-findings` on 2026-07-01.

## Evidence Summary

- `git status --short --branch` reported `## main...origin/main`.
- `gh issue list --state open --limit 100 --json number,title,state,url` returned `[]`.
- Recent GitHub PRs for the sub-issue and loop-mode work are merged.
- `./scripts/test-workflow-contract.sh` passed.
- `./scripts/get-agent-plugin-version.sh` reported source/live parity and a clean source tree.
- `./skills/align-project/scripts/align-project.sh -RepoRoot . -Mode GitHubAware -TrackerHygiene` reported `ok=True`, `blocking=0`, `repairable=7`, `informational=10`, `healthy=30`.
- The seven repairables from that alignment run were all `closed-mirror-lifecycle`.
- The same alignment run reported `GitHub milestone evidence was not inspected`, `GitHub label evidence was not inspected`, and `Project V2 state evidence was not inspected`.
- `gh issue list --state closed --limit 200 --json number,title,labels,milestone` found 50 closed issues with `status:*` labels still attached.
- `gh api repos/:owner/:repo/milestones` returned live milestone evidence for M0, M1, and M2.
- `gh label list --limit 100 --json name` returned the live `type:*` and `status:*` tracker vocabulary.
- `docs/superpowers/backlog/ACTIVE.md` contains no active candidate rows.

## Resolution Proof

- **P1 tracker hygiene:** `align-project` now evaluates closed/open issue `status:*` label hygiene without Project V2 fixtures while keeping Project item checks gated on Project V2 evidence. `skills/align-project/scripts/test-scenarios.sh` includes the no-Project-fixture regression and passes.
- **P1 native route prose:** Active skills, metadata, and `docs/superpowers/workflow-contract.yml` now route top-level continuation through `Yes`, `Revisit`, and `Stop`; child route options stay under their own native questions. The stale active-route scan returns no matches in `skills` or `docs/superpowers/workflow-contract.yml`.
- **P1 validator coverage:** `scripts/validate-workflow-contract.sh` now extracts `If the user selects ...` trigger prose and rejects route labels outside the declared contract. It also rejects composite metadata labels such as `Yes Do Work`. `scripts/test-workflow-contract.sh` passes with both failing fixtures.
- **P2 closed mirror lifecycle:** Closed mirrors 97-103 were deleted from `docs/superpowers/issues/`. Their durable history moved to `docs/superpowers/milestones/M1-source-of-truth.md` closed summaries with GitHub issue and PR evidence where available.
- **P2 live GitHub evidence:** GitHub-aware alignment now reads live milestones and labels through `gh` when fixture paths are absent. The live alignment proof reports only `dirty-worktree` and `live-sync` repairables while this branch is unmerged, with `closed-mirror-lifecycle`, `milestone-membership-drift`, and `label-drift` healthy.
- **P2 closed status labels:** Closed GitHub issues now have zero `status:*` labels.
- **P3 file pressure:** `skills/merge-changes/scripts/test-scenarios.sh` was reduced from 1087 lines to 945 lines by extracting reusable test fixtures to `skills/merge-changes/scripts/lib/test-fixtures.sh`. `docs/superpowers/workflow-contract.yml` remains the single canonical contract registry; this is bounded by the stricter route-prose and metadata validators rather than split during this repair.
- **Closed mirror fixture regression:** `skills/loop-controller/scripts/test-scenarios.sh` no longer depends on deleted closed mirrors 97 and 102; it now creates temporary hierarchy mirrors for selector tests.
- **Validation:** `./scripts/validate.sh` passes after the repairs.

## P1 - Tracker Hygiene Skips Closed Status Labels Without Project V2 Fixtures

Closed GitHub issues still carry routing labels, but the normal GitHub-aware alignment route misses them when Project V2 fixture evidence is absent.

Evidence:

- `gh issue list --state closed --limit 200 --json number,title,labels,milestone` found 50 closed issues with `status:*` labels.
- Recent examples include `#103 status:ready`, `#102 status:ready`, `#101 status:ready`, `#100 status:ready`, `#99 status:ready`, `#98 status:ready`, and `#97 status:triage`.
- `skills/align-project/SKILL.md` defines tracker hygiene as reporting closed issue status-label drift and removing `status:*` labels from closed issues during approved repair.
- `skills/align-project/scripts/align-project.sh:503` defines `Invoke-TrackerHygieneAudit`.
- `skills/align-project/scripts/align-project.sh:527` computes `$statusLabels`.
- `skills/align-project/scripts/align-project.sh:533` reports `closed-status-label-drift`.
- `skills/align-project/scripts/align-project.sh:754` only enters tracker hygiene when `-TrackerHygiene` is set.
- `skills/align-project/scripts/align-project.sh:755` reports Project V2 as not inspected when `$projectFixture` is null.
- `skills/align-project/scripts/align-project.sh:758` only calls `Invoke-TrackerHygieneAudit` when `$projectFixture` exists.

Impact:

Closed issues still look routable to humans and agents because `status:ready`, `status:triage`, or `status:blocked` remain attached. The audit mode reports a healthy tracker-hygiene shape even though live issue-label hygiene has drift. This weakens loop selection, closed issue review, and any dashboard view that treats `status:*` as active workflow state.

Repair requirement:

- Split issue-label hygiene from Project V2 item hygiene, or let `Invoke-TrackerHygieneAudit` run with a null Project fixture while skipping only Project-item checks.
- Always evaluate closed/open issue `status:*` label rules when GitHub issue evidence exists.
- Keep Project-item status and field checks gated on Project V2 evidence.
- Add a no-Project-fixture regression where a closed issue with `status:ready` produces `closed-status-label-drift`.
- Ensure approved tracker repair can remove `status:*` labels from closed GitHub issues without requiring Project V2 fixture data.

Proof target:

- `align-project -Mode GitHubAware -TrackerHygiene` reports `closed-status-label-drift` before repair when closed `status:*` labels exist.
- After approved repair, the closed issue status-label count is zero:

```bash
gh issue list --state closed --limit 200 --json labels --jq '[.[] | select(any(.labels[]?; .name|startswith("status:")))] | length'
```

## P1 - Native Route Prose Still Names Synthetic Options

Some skill prose and agent metadata still refer to composite or child-route labels as if they were selected directly from top-level native gates.

Evidence:

- `skills/audit-project/SKILL.md:90` declares top-level `project_audit_next_step` with `Yes`, `Revisit`, and `Stop`.
- `skills/audit-project/SKILL.md:100` then says `If the user selects Prepare Repair Work`, but that label is not a top-level option.
- `skills/audit-project/SKILL.md:147` says `If the user selects Review Or Extend Findings`, but that label is not a top-level option.
- `skills/audit-project/agents/openai.yaml:10` still says `project_audit_next_step can route to Yes Prepare Repair Work or Revisit Review Or Extend Findings`.
- `skills/audit-project/scripts/test-scenarios.sh:66` and `:67` assert those composite route phrases.
- `skills/align-project/SKILL.md:130` declares top-level `project_align_next_step` with `Yes`, `Revisit`, and `Stop`.
- `skills/align-project/SKILL.md:152` says `If the user selects Apply Or Prepare Repair`, but that label is not a top-level option.
- `skills/align-project/SKILL.md:163` says `If the user selects Prepare Repair Work`.
- `skills/align-project/SKILL.md:185` says `If the user selects Rerun / Review Alignment`, but that label is not a top-level option.
- `docs/superpowers/workflow-contract.yml:73` defines `project_align_next_step` as the top-level continuation gate.
- `docs/superpowers/workflow-contract.yml:110` defines `project_align_repair_group` as a `nested_revisit_route` with `parent_option: Revisit`, even though the skill prose says top-level `Yes` should apply or prepare repair work.

Impact:

Agents can attempt to follow labels that native UI never presents. A user selecting `Yes` can leave the workflow in an ambiguous state because the next documented branch talks about `Prepare Repair Work` or `Apply Or Prepare Repair` as if it had already been selected. This is exactly the kind of route mismatch that creates failed automation or "missing script" reports even when the underlying scripts exist.

Repair requirement:

- Rewrite route prose so top-level branches are keyed to `Yes`, `Revisit`, and `Stop` only.
- For audit-project, `Yes` should ask `project_audit_progress_route`; `Revisit` should ask `project_audit_revisit_route`.
- For align-project, decide one clean route shape:
  - either `Yes` asks a repair route such as `project_align_repair_group` as a nested Yes route, then optionally asks `project_align_prepare_route`;
  - or `Yes` directly asks `project_align_prepare_route` or `project_align_plan_issue_route` and removes the extra repair group.
- Align `docs/superpowers/workflow-contract.yml`, skill prose, agent metadata, and scenario assertions to the same route graph.
- Remove composite route phrases such as `Yes Prepare Repair Work`, `Revisit Review Or Extend Findings`, `Apply Or Prepare Repair`, and `Rerun / Review Alignment`.

Proof target:

```bash
rg -n "Yes Prepare Repair Work|Revisit Review Or Extend Findings|Apply Or Prepare Repair|Rerun / Review Alignment|If the user selects `Prepare Repair Work`|If the user selects `Review Or Extend Findings`" skills docs/superpowers/workflow-contract.yml
```

The command should return no stale route-trigger matches outside historical audit specs or plans.

## P1 - Workflow Contract Validation Does Not Catch Route-Trigger Drift

The workflow contract validator is strong on question IDs and option arrays, but it does not validate skill prose or agent metadata route triggers against the declared native graph.

Evidence:

- `scripts/validate-workflow-contract.sh` checks that skill question IDs are registered, contract gates exist, option arrays match, gate types are valid, nested routes exclude terminal options, and next routes are known.
- `scripts/validate-workflow-contract.sh` does not inspect `If the user selects ...` route-trigger prose.
- `scripts/validate-workflow-contract.sh` does not inspect `skills/*/agents/openai.yaml` route phrases.
- `scripts/test-workflow-contract.sh` includes fixtures for invalid nested terminal options, option mismatch, missing typed gate, and missing allowlist reason.
- `scripts/test-workflow-contract.sh` has no failing fixture where skill prose routes from `Yes` to a nonexistent synthetic option.
- `scripts/test-workflow-contract.sh` passed while the stale route prose and metadata in the previous finding remained present.

Impact:

The repo can claim workflow-contract validation is green while the actual agent-facing route instructions remain inconsistent. This lets native workflow drift recur after each issue-resolution cycle.

Repair requirement:

- Extend validation to extract route-trigger prose from workflow skills, especially patterns like `If the user selects \`.../``.
- Verify each trigger is either a valid top-level option for the preceding top-level gate, a valid option for the directly preceding nested gate, or explicitly allowlisted with a reason.
- Add metadata checks for `skills/*/agents/*.yaml` so embedded route summaries cannot mention composite labels that are not contract options.
- Add a failing fixture where prose names `Prepare Repair Work` as a top-level branch while the top-level gate only offers `Yes`, `Revisit`, and `Stop`.

Proof target:

- The validator fails before the route-prose repair.
- After repair, `./scripts/test-workflow-contract.sh` passes.

## P2 - Closed Hierarchy Rollout Mirrors Remain As Active Mirrors

The sub-issue hierarchy rollout mirrors remain under `docs/superpowers/issues/` even though their GitHub issues are closed and no mirror retention marker is present.

Evidence:

- `align-project -Mode GitHubAware -TrackerHygiene` reported seven `closed-mirror-lifecycle` repairables.
- The affected mirrors are:
  - `docs/superpowers/issues/97-github-sub-issues-workflow.md`
  - `docs/superpowers/issues/98-tracker-vocabulary-and-clean-title-policy.md`
  - `docs/superpowers/issues/99-create-issues-hierarchy-schema-and-validators.md`
  - `docs/superpowers/issues/100-create-issues-publication-hydration-and-routing.md`
  - `docs/superpowers/issues/101-leaf-only-execution-guards.md`
  - `docs/superpowers/issues/102-merge-rollup-align-migration-audit-and-loop-selection.md`
  - `docs/superpowers/issues/103-workflow-examples-generated-docs-and-validation-wiring.md`
- `docs/superpowers/issues/README.md:59` says closed mirrors are deleted by default after merge verifies the linked GitHub issue is closed.
- `docs/superpowers/issues/README.md:64` defines the only retention marker as `Mirror Retention: Keep`.
- `docs/superpowers/issues/README.md:67` says retained mirrors need a retention reason and audit reports closed mirrors without this marker as repairable drift.
- The affected mirrors still contain unchecked acceptance criteria, which makes them read like active execution inputs.

Impact:

The issue mirror folder is intended to hold active execution inputs. Keeping closed mirrors without retention evidence blurs the source-of-truth boundary between active mirrors and durable milestone history. It also creates unnecessary audit noise for every future alignment run.

Repair requirement:

- Delete closed mirrors 97-103 unless there is an explicit reason to retain them.
- If any mirror must remain, add `Mirror Retention: Keep` and a closeout evidence reason.
- Update the relevant milestone page closed summaries with concise GitHub issue and PR links so the durable history remains available after mirror deletion.
- Ensure the closeout ledger records mirror cleanup evidence and milestone closed-summary evidence.

Proof target:

- `align-project -Mode GitHubAware` reports no `closed-mirror-lifecycle` repairables.
- `docs/superpowers/issues/` contains no closed mirrors except retained mirrors with explicit retention evidence.

## P2 - GitHubAware Milestone And Label Checks Are Fixture-Only

Normal GitHub-aware alignment inspects issues from live GitHub, but milestone-membership and label-vocabulary checks only run from optional fixture files.

Evidence:

- `skills/align-project/scripts/align-project.sh:314` reads live GitHub issue evidence through GraphQL when no issue fixture is supplied.
- `skills/align-project/scripts/align-project.sh:659` reads milestone evidence with `Read-JsonArray -Path $MilestoneFixturePath`.
- `skills/align-project/scripts/align-project.sh:660` reads label evidence with `Read-JsonArray -Path $LabelFixturePath`.
- `skills/align-project/scripts/align-project.sh:738` emits `GitHub milestone evidence was not inspected` when no milestone fixture exists.
- `skills/align-project/scripts/align-project.sh:751` emits `GitHub label evidence was not inspected` when no label fixture exists.
- Live GitHub evidence is available:
  - M0 Governance: open 0, closed 18.
  - M1 Source Of Truth: open 0, closed 36.
  - M2 Distribution: open 0, closed 2.
  - Labels include `type:bug`, `type:feature`, `type:task`, `type:issue-set`, `type:sub-milestone`, `type:plan-wrapper`, `status:triage`, `status:ready`, and `status:blocked`.

Impact:

The plugin now relies on native GitHub milestone tracking instead of manual milestone names in issue titles, but the alignment audit cannot verify milestone membership from live GitHub without a fixture. Label vocabulary drift has the same issue. That leaves the most important tracker invariants as "not inspected" in the normal path.

Repair requirement:

- Add live GitHub readers for milestones and labels in GitHub-aware mode.
- Preserve fixture paths as test overrides.
- When live GitHub is reachable and authenticated, milestone and label evidence should be inspected rather than reported as unavailable.
- If live GitHub cannot be inspected, report a clear skipped check with the exact missing dependency.
- Compare local milestone pages to live milestone issue membership.
- Compare local `docs/agents/triage-labels.md` vocabulary to live `type:*` and `status:*` labels.

Proof target:

- `align-project -Mode GitHubAware` reports healthy or repairable `milestone-membership-drift` and `label-drift` findings from live GitHub evidence, not informational "not inspected" findings, when `gh` is authenticated.

## P3 - Workflow Contract And Scenario Files Are Becoming Too Large

Several workflow governance files are now large enough that future issue-resolution work is likely to miss cross-file drift.

Evidence:

- `docs/superpowers/workflow-contract.yml` is 1277 lines.
- `skills/merge-changes/scripts/test-scenarios.sh` is 1030 lines.
- `skills/create-issues/scripts/test-scenarios.sh` is 806 lines.
- `skills/align-project/scripts/align-project.sh` is 754 lines.
- `skills/resolve-issue/scripts/test-scenarios.sh` is 590 lines.

Impact:

This is not a current correctness bug, but it is a leverage and locality problem. The largest files mix contract data, route topology, scenario fixtures, and regression checks. That makes future route hardening work more expensive and increases the odds of tests asserting stale phrasing rather than intended behavior.

Repair requirement:

- Split scenario scripts by concern once the P1/P2 repairs are complete.
- Consider generating `docs/superpowers/workflow-contract.yml` from per-skill fragments or at least grouping route fixtures by skill in smaller files.
- Keep one top-level validator command, but move bulky fixtures into focused files.

Proof target:

- Existing validation still passes.
- The largest route/test files fall below the current 1000-line pressure point.
- Scenario failures report the route or skill area directly.

## Healthy Checks And Non-Findings

- There are no open GitHub issues.
- The active backlog table has no candidate entries.
- GitHub sub-issue hierarchy fields for the inspected mirrors are healthy in the current alignment output.
- Source/live plugin parity is healthy.
- Core workflow-contract validation passes.
- The repo's canonical documentation roots are aligned with `docs/superpowers/`; historical mentions of retired paths appear in migration specs and tests, not active write targets.

## Recommended Repair Strategy

Use a small parent issue as the repair rollup and create leaf sub-issues in this order:

1. Fix live tracker-hygiene coverage and remove closed `status:*` labels.
2. Fix native route prose, metadata, and workflow-contract route topology for audit-project and align-project.
3. Extend workflow-contract validation to prevent route-trigger drift.
4. Add live GitHub milestone and label evidence readers to align-project.
5. Clean up or explicitly retain closed mirrors 97-103 with milestone closed-summary evidence.
6. Split large workflow/test files after the correctness repairs are merged.

The first four items protect the workflow from creating more drift. The closed mirror cleanup should happen after the audit route can accurately prove the tracker state, and the file-size cleanup should wait until the behavior repairs are stable.
