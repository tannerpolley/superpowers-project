# Post-Issue-Resolution Audit Finding Repairs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the saved 2026-07-01 audit findings for tracker hygiene, native route drift, workflow-contract validation, closed mirror lifecycle, live GitHub evidence, and large-file pressure.

**Architecture:** Keep the workflow contract as the native gate source of truth, and make validators enforce the route language agents actually read. Strengthen `align-project` so GitHub-aware mode inspects live issue, milestone, and label evidence when fixtures are absent. Close the loop by cleaning stale closed mirrors and tracker labels, then verify source, live sync, and loop evidence.

**Tech Stack:** PowerShell 7, GitHub CLI, GitHub GraphQL/REST through `gh`, YAML via the existing workflow-contract loader, Markdown project artifacts.

---

## Source Evidence

- Source spec: `docs/superpowers/specs/2026-07-01-post-issue-resolution-project-audit-findings.md`
- Workflow mode ledger: `.superpowers/runs/2026-07-01-resolve-audit-findings/workflow-mode-ledger.json`
- Branch: `codex/resolve-audit-findings`
- Direct approval: user requested `resolve all the findings` and selected Looping Mode in `project_workflow_mode`.

## Outcome Proof

**Intent:** The Superpowers Project plugin resolves the post-issue audit findings without creating new stale workflow drift.
**Current Behavior:** Closed issues can keep `status:*` labels unnoticed, live milestone and label evidence is skipped without fixtures, route prose can name synthetic options, closed mirrors 97-103 remain active, and the largest governance files are hard to review.
**Expected Outcome:** GitHub-aware alignment reports real live tracker evidence, route prose and metadata match native options, validators reject route-trigger drift, closed mirrors move to milestone history, closed issues have no status routing labels, and file-size pressure is reduced or explicitly bounded by a clean splitter.
**Target Output:** Source repo changes on `codex/resolve-audit-findings`, updated plan/audit artifacts, validation receipts, cleanup proof, live-sync validation proof, and GitHub tracker proof.
**Owner:** Superpowers Project plugin source repo.
**Interface:** `$superpowers-project:initiate-workflow`, `$superpowers-project:loop-controller`, `$superpowers-project:align-project`, workflow-contract validators, GitHub issue labels, and `docs/superpowers` artifacts.
**Cutover:** Replace stale route wording and fixture-only inspection paths in source; delete closed mirrors only after M1 closed summaries are written.
**Replaced Path:** Stale synthetic route labels, fixture-only milestone/label checks in GitHub-aware mode, closed mirror files 97-103 as active execution inputs, and oversized unsplit test helper blocks.
**Evidence:** Targeted scenario tests, workflow-contract tests, alignment JSON output, GitHub label count query, full repo validation, cleanup hook, and sync-live validation.
**Acceptance Proof:** All P1/P2 findings from the source spec have passing proof commands; P3 file pressure is reduced without weakening route validation; `scripts/validate.ps1` passes.
**Stop Criteria:** Stop before merge-ready proof if any targeted validator fails, if GitHub label mutation fails, if live evidence contradicts the planned cleanup, or if full validation fails twice for the same reason.
**Avoid:** Do not edit deployed plugin copies directly, do not create compatibility wrappers for stale route labels, do not keep closed mirrors without retention evidence, and do not weaken native question contracts.
**Risk:** Medium: the work touches workflow infrastructure and live GitHub tracker state. Risk owner: current Codex thread.

## Implementation Boundaries

**Files To Create:** `docs/superpowers/plans/2026-07-01-post-issue-resolution-audit-finding-repairs-plan.md`; optional focused helper/test files only if they reduce large-file pressure cleanly.
**Files To Modify:** `skills/align-project/scripts/align-project.ps1`; `skills/align-project/scripts/test-scenarios.ps1`; `skills/align-project/SKILL.md`; `skills/audit-project/SKILL.md`; `skills/audit-project/agents/openai.yaml`; `skills/audit-project/scripts/test-scenarios.ps1`; `scripts/lib/workflow-contract.ps1`; `scripts/validate-workflow-contract.ps1`; `scripts/test-workflow-contract.ps1`; `docs/superpowers/workflow-contract.yml`; `docs/superpowers/milestones/M1-source-of-truth.md`; `docs/superpowers/specs/2026-07-01-post-issue-resolution-project-audit-findings.md`; `docs/superpowers/issues/97-github-sub-issues-workflow.md` through `docs/superpowers/issues/103-workflow-examples-generated-docs-and-validation-wiring.md`.
**Files To Avoid:** Deployed plugin copies, plugin cache source, unrelated workspace roots, unrelated historical plans/specs, and closed issue mirrors outside 97-103.
**Source Of Truth:** `docs/superpowers/specs/2026-07-01-post-issue-resolution-project-audit-findings.md` plus live GitHub issue/milestone/label evidence.
**Read Path:** Inspect source repo files, run existing validators, read live GitHub with `gh`, and parse fixtures through existing scripts.
**Write Path:** Edit source repo files with scoped patches; mutate GitHub only to remove `status:*` labels from closed issues after proof.
**Integration Points:** `align-project` JSON findings, workflow-contract validator, native skill metadata, M1 milestone page, `scripts/validate.ps1`, `scripts/sync-live.ps1 -Validate`.
**Migration Or Cutover:** New validator checks must fail stale route prose before repair and pass after repair. Closed mirror files must be deleted after M1 closed summaries exist.
**Replaced Path Handling:** Removed route phrases stay out of skills, metadata, and tests; removed mirrors are represented by M1 closed summaries; old fixture-only paths remain as test overrides.
**Acceptance Proof Gate:** Targeted tests pass before full validation; full validation and cleanup pass before final handoff; live sync validation passes before reporting plugin source complete.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Workflow mode | `project_workflow_mode` native answer | Looping Mode | Allows bounded repair of all findings from the saved audit spec. | No | current Codex thread |
| Execution route | User request plus repo policy | Use branch-backed plan implementation without creating new GitHub issues. | Avoids extra tracker churn while still keeping a plan and proof oracle. | No | current Codex thread |
| GitHub mutation | Source audit and mode ledger | Remove `status:*` labels from closed issues after align proof. | Resolves live tracker hygiene rather than only documenting it. | No | current Codex thread |
| Closed mirror handling | `docs/superpowers/issues/README.md` | Delete mirrors 97-103 and record M1 closed summaries. | Restores issue mirror folder to active execution inputs. | No | current Codex thread |
| P3 large-file handling | Source audit | Reduce file pressure only through clean extraction or contract splitting that keeps validation strict. | Prevents risky churn if a split would weaken workflow contract proof. | No | current Codex thread |

## Test Complete And Metrics

- Test complete means targeted validators pass, the full repo validator passes, cleanup passes, and sync-live validation passes.
- Tracker metric: closed issues with `status:*` labels equals `0`.
- Alignment metric: GitHub-aware alignment inspects live milestone and label evidence when `gh` is authenticated.
- Route metric: stale synthetic route phrases are absent from active skills, metadata, contract, and active scenario tests.
- Mirror metric: issues 97-103 no longer exist as active mirrors unless retained with explicit evidence; M1 closed summaries include their GitHub issue links and closing PR evidence where GitHub exposes it.
- File-pressure metric: any file still above 1000 lines is justified by validator output or reduced by a focused extraction that keeps validation passing.

## Acceptance Criteria

- `align-project -Mode GitHubAware -TrackerHygiene` reports closed status-label drift before live label cleanup and no such drift after cleanup.
- `align-project -Mode GitHubAware` reports live milestone and label evidence as healthy or repairable instead of informational skipped checks when `gh` is authenticated.
- `scripts/test-workflow-contract.ps1` fails stale route-trigger fixtures and passes the repaired repo contract.
- `rg` finds no active stale route phrases outside historical specs/plans and the audit spec evidence itself.
- `align-project -Mode GitHubAware` reports no `closed-mirror-lifecycle` repairables for mirrors 97-103 after cleanup.
- `scripts/validate.ps1` passes.
- `scripts/sync-live.ps1 -Validate` passes.

### Task 1: Workflow Route Contract Repair

**Use Cases:**
- Agent reads `audit-project` and sees `Yes` route to the repair-route menu, not a synthetic `Prepare Repair Work` top-level choice.
- Agent reads `align-project` and sees `Yes` route to exact repair or repair planning, not a synthetic `Apply Or Prepare Repair` choice.
- Validator rejects future route prose that names a label outside the declared gate options.
- Validator rejects metadata phrases that concatenate top-level and child route labels.
- Cutover retires displaced synthetic route labels from active skills, metadata, and tests while preserving the exact native options.

**Files:**
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/audit-project/scripts/test-scenarios.ps1`
- Modify: `skills/align-project/SKILL.md`
- Modify: `docs/superpowers/workflow-contract.yml`
- Modify: `scripts/lib/workflow-contract.ps1`
- Modify: `scripts/validate-workflow-contract.ps1`
- Modify: `scripts/test-workflow-contract.ps1`
- Test: `scripts/test-workflow-contract.ps1`
- Test: `skills/audit-project/scripts/test-scenarios.ps1`

- [x] **Step 1: Add failing workflow-contract fixtures**
  - Add a fixture skill containing `If the user selects \`Not A Real Option\``.
  - Add a fixture metadata file containing `Yes Do Work`.
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`.
  - Expected before implementation: the new checks fail.
- [x] **Step 2: Add route-trigger validation**
  - Extract `If the user selects \`...\`` labels from skill prose.
  - Check each extracted label against declared contract option labels for that skill.
  - Extract top-level plus nested composite labels from `agents/openai.yaml`.
  - Fail when metadata contains a composite phrase such as `Yes Do Work`.
- [x] **Step 3: Normalize audit-project routes**
  - Change `If the user selects \`Prepare Repair Work\`` to `If the user selects \`Yes\``.
  - Change `If the user selects \`Review Or Extend Findings\`` to `If the user selects \`Revisit\``.
  - Update metadata and tests to assert `Yes`, `project_audit_progress_route`, `Revisit`, and `project_audit_revisit_route`.
- [x] **Step 4: Normalize align-project routes**
  - Make `project_align_repair_group` a nested Yes route, or remove the extra group if direct repair planning is clearer.
  - Change stale prose triggers to `Yes` and `Revisit`.
  - Keep `Prepare Repair Work` only as a child option when the contract presents it.
- [x] **Step 5: Verify route contract**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1`.
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1`.
  - Run the stale phrase `rg` proof from the source spec and confirm no active hits remain.

### Task 2: Align Live GitHub Evidence And Tracker Hygiene

**Use Cases:**
- GitHub-aware alignment inspects live issue labels even when no Project V2 fixture is supplied.
- GitHub-aware alignment inspects live milestones and labels when no fixture paths are supplied and `gh` is authenticated.
- Fixture paths still provide deterministic tests.
- Closed issue status labels create repairable findings before cleanup and disappear after cleanup.

**Files:**
- Modify: `skills/align-project/scripts/align-project.ps1`
- Modify: `skills/align-project/scripts/test-scenarios.ps1`
- Test: `skills/align-project/scripts/test-scenarios.ps1`

- [x] **Step 1: Add failing no-Project tracker fixture**
  - Extend align scenario tests so a closed issue with `status:ready` and no `-ProjectFixturePath` reports `closed-status-label-drift`.
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\test-scenarios.ps1`.
  - Expected before implementation: the no-Project tracker check fails.
- [x] **Step 2: Decouple issue-label hygiene from Project V2 hygiene**
  - Let closed/open issue status-label checks run whenever GitHub issue evidence exists.
  - Keep Project item checks behind Project V2 evidence.
  - Keep repair receipts for label removals and Project repairs separate.
- [x] **Step 3: Add live milestone and label readers**
  - Use fixtures when `-MilestoneFixturePath` or `-LabelFixturePath` is supplied.
  - Otherwise call live GitHub through `gh api repos/:owner/:repo/milestones` and `gh label list --json name`.
  - Convert live milestone evidence into the same shape used by existing membership checks.
- [x] **Step 4: Verify align scenarios**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\test-scenarios.ps1`.
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene`.

### Task 3: Closed Mirror And Tracker State Cleanup

**Use Cases:**
- Closed issue mirrors 97-103 no longer appear as active execution inputs.
- M1 milestone history records the closed issues and closing PRs where GitHub exposes them.
- Closed GitHub issues no longer carry active `status:*` workflow labels.
- Alignment proves mirror lifecycle and tracker hygiene after cleanup.
- Cutover moves displaced closed mirror history from active mirror files into M1 closed-summary evidence.

**Files:**
- Modify: `docs/superpowers/milestones/M1-source-of-truth.md`
- Delete: `docs/superpowers/issues/97-github-sub-issues-workflow.md`
- Delete: `docs/superpowers/issues/98-tracker-vocabulary-and-clean-title-policy.md`
- Delete: `docs/superpowers/issues/99-create-issues-hierarchy-schema-and-validators.md`
- Delete: `docs/superpowers/issues/100-create-issues-publication-hydration-and-routing.md`
- Delete: `docs/superpowers/issues/101-leaf-only-execution-guards.md`
- Delete: `docs/superpowers/issues/102-merge-rollup-align-migration-audit-and-loop-selection.md`
- Delete: `docs/superpowers/issues/103-workflow-examples-generated-docs-and-validation-wiring.md`
- External: closed GitHub issues with `status:*` labels
- Test: `skills/align-project/scripts/align-project.ps1`

- [x] **Step 1: Add M1 closed summaries**
  - Add issue 97 closed directly on `2026-06-30T16:13:35Z`.
  - Add issues 98-103 with PRs #104, #106, #107, #108, #109, and #110.
- [x] **Step 2: Delete closed mirrors 97-103**
  - Remove only those seven mirror files.
  - Keep `docs/superpowers/issues/README.md`.
- [x] **Step 3: Remove closed issue status labels**
  - Query closed issues carrying `status:*`.
  - Run `gh issue edit <number> --remove-label <status-label>` for each closed status label.
  - Re-query and confirm the count is `0`.
- [x] **Step 4: Verify cleanup**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene`.
  - Confirm no `closed-mirror-lifecycle` or `closed-status-label-drift` repairables remain.

### Task 4: Large-File Pressure Reduction

**Use Cases:**
- Future maintainers can review workflow-contract and merge-change tests without scanning one oversized file.
- Existing validators keep one public entry point.
- Split helpers do not hide route behavior or weaken scenario coverage.

**Files:**
- Modify: `skills/merge-changes/scripts/test-scenarios.ps1`
- Create or modify: focused helper file under `skills/merge-changes/scripts/lib/`
- Modify: `docs/superpowers/workflow-contract.yml` and `scripts/lib/workflow-contract.ps1` only if a contract fragment split stays low-risk.
- Test: `skills/merge-changes/scripts/test-scenarios.ps1`
- Test: `scripts/test-workflow-contract.ps1`

- [x] **Step 1: Extract merge test fixture helpers**
  - Move reusable `New-*` fixture builders and sample repo helpers into a sourced helper file.
  - Keep scenario names and assertions in `test-scenarios.ps1`.
- [x] **Step 2: Verify merge scenarios**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1`.
- [x] **Step 3: Reassess workflow contract split**
  - If the workflow contract can be split into fragments while `Read-WorkflowContract` preserves the same combined object, implement the split.
  - If the split would create extra risk, leave the contract intact and record the reason in the audit spec as a bounded P3 follow-up rather than a correctness defect.
- [x] **Step 4: Verify file pressure**
  - Re-run the line-count command from the source spec.
  - Confirm `skills/merge-changes/scripts/test-scenarios.ps1` is below 1000 lines.

### Task 5: Final Validation And Live Sync

**Use Cases:**
- Full validation proves the repo source is coherent after all repairs.
- Live sync validation proves deployed plugin copies can be updated from source.
- Cleanup proof prevents orphaned processes from this workflow.
- The audit spec reflects final proof instead of stale findings.

**Files:**
- Modify: `docs/superpowers/specs/2026-07-01-post-issue-resolution-project-audit-findings.md`
- Runtime: `.superpowers/runs/2026-07-01-resolve-audit-findings/`
- Test: `scripts/validate.ps1`
- Test: `scripts/sync-live.ps1`

- [x] **Step 1: Update the audit spec with resolution proof**
  - Mark each finding with the implemented resolution and proof command.
- [x] **Step 2: Run targeted validators**
  - Run workflow-contract, audit-project, align-project, merge-changes, and plan validators.
- [x] **Step 3: Run full validation**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`.
- [x] **Step 4: Run live sync validation**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`.
- [x] **Step 5: Run cleanup**
  - Run `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .`.
- [x] **Step 6: Prepare merge-ready evidence**
  - Record branch, changed files, validation receipts, tracker proof, cleanup proof, and sync-live proof.
