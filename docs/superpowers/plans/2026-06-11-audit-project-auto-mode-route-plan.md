# Audit Project Auto Mode Route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `$superpowers-project:audit-project` offer bounded Auto Mode after it saves a findings spec, matching the saved-spec path already available from `$superpowers-project:brainstorm-spec`.

**Architecture:** Extend the audit continuation route, metadata, README, generated outcome workflow, and scenario tests so audit findings specs can authorize `project_auto_mode_authorization`. Reuse the existing plugin-provided Auto Mode validator and downstream ledger contract instead of creating a separate audit-specific execution engine.

**Tech Stack:** Markdown skill contracts, YAML agent metadata, PowerShell validation scripts, generated Markdown outcome workflow.

---

## Source And Scope

**Source Spec:** `docs/superpowers/specs/2026-06-11-plugin-stale-code-cleanup-audit-findings.md`

**Selected Finding:** `P2: Audit Findings Specs Cannot Originate Auto Mode`

**Non-Goals:**

- Do not implement the other stale-code cleanup findings in this plan.
- Do not create a second Auto Mode validator.
- Do not bypass the existing `project_auto_mode_authorization` ledger.
- Do not allow Auto Mode before the audit findings spec is saved and self-reviewed.

## Acceptance Criteria

- `$superpowers-project:audit-project` exposes Auto Mode after a findings spec is ready.
- The route asks `project_auto_mode_authorization` and accepts only `Bounded Auto Merge` or `Manual Planning`.
- The ledger must validate with `scripts/validate-auto-mode-authorization.ps1`.
- The saved audit findings spec is carried as `source_spec`.
- The route continues into `$superpowers-project:write-plan` after a valid ledger.
- README and generated outcome workflow show that audit-project has `project_auto_mode_authorization`.
- Focused audit scenario tests, outcome workflow tests, and plan use-case validation pass.

## Proof Oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-11-audit-project-auto-mode-route-plan.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-auto-mode-contract.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Test Complete

Testing is complete when the proof oracle passes and `scripts\sync-live.ps1 -Validate` refreshes the live plugin without drift.

## Metrics And Tolerances

No numerical engineering metrics apply. Pass/fail is contract-based: required strings, route IDs, ledger validation, generated summary freshness, and scenario tests must pass exactly.

## Task 1: Add Audit Auto Mode Contract Surface

**Use Cases:**
- User completes an audit findings spec and chooses to continue with bounded automation instead of manual repair planning.
- Agent sees an audit-created `docs/superpowers/specs/*.md` source and can ask the same `project_auto_mode_authorization` gate used by brainstorm-created specs.
- Audit Auto Mode is not allowed until the findings spec has been saved, self-reviewed, and shown through the artifact review gate.
- If the user selects Manual Planning, the route returns to `project_audit_progress_route` / `$superpowers-project:write-plan` instead of authorizing automation.

**Files:**
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `README.md`
- Modify: `scripts/generate-contract-summary.ps1`
- Modify: `docs/superpowers/OUTCOME_WORKFLOW.md`

- [ ] **Step 1: Extend audit continuation docs**
  Add an audit Auto Mode child route after the audit progress route. It must state that Auto Mode starts only after the findings spec is saved and self-reviewed.

- [ ] **Step 2: Reuse the existing authorization ledger**
  Require `project_auto_mode_authorization`, `Bounded Auto Merge`, and the plugin-provided validator command:

  ```powershell
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>
  ```

- [ ] **Step 3: Keep downstream execution unchanged**
  State that a valid audit Auto Mode ledger continues into `$superpowers-project:write-plan` with the audit findings spec as the source spec, then downstream routes consume the ledger normally.

- [ ] **Step 4: Update public route summaries**
  Update README and generated outcome workflow so new agents can see that `audit-project` supports `project_auto_mode_authorization`.

## Task 2: Add Focused Validation Coverage

**Use Cases:**
- A future edit that removes audit Auto Mode from `SKILL.md`, metadata, README, or generated summary fails validation.
- A future edit that changes the authorization validator command fails the audit scenario contract.
- A future edit that leaves `OUTCOME_WORKFLOW.md` stale relative to the generator fails `test-contract-summary`.
- The implementation plan itself fails validation if any task loses its `**Use Cases:**` block.

**Files:**
- Modify: `skills/audit-project/scripts/test-scenarios.ps1`
- Modify: `scripts/test-contract-summary.ps1`

- [ ] **Step 1: Extend audit-project scenario tests**
  Add required strings for `Auto Mode`, `project_auto_mode_authorization`, `Bounded Auto Merge`, `validate-auto-mode-authorization.ps1`, and `source spec`.

- [ ] **Step 2: Extend outcome workflow tests**
  Require `project_auto_mode_authorization` in the audit-project generated summary row.

- [ ] **Step 3: Run focused validation**
  Run plan use-case validation, audit scenario tests, outcome workflow tests, and Auto Mode contract tests before broader validation.

## Task 3: Sync And Enable The Live Plugin Surface

**Use Cases:**
- Existing local plugin cache candidates receive the updated audit Auto Mode route after sync.
- A new agent startup banner still reports source, live, and observed plugin surfaces as current after the route change.
- The current thread can ask the native `project_auto_mode_authorization` question for this audit findings spec after the route exists.
- If live sync or version freshness fails, the workflow stops before claiming Auto Mode is enabled.

**Files:**
- Modify: live deployed plugin copy through `scripts\sync-live.ps1 -Validate`
- No direct edits to plugin cache paths

- [ ] **Step 1: Run full validation**
  Run `scripts\validate.ps1`, or rely on `scripts\sync-live.ps1 -Validate` because it invokes the full validator.

- [ ] **Step 2: Sync live**
  Run:

  ```powershell
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
  ```

- [ ] **Step 3: Confirm version freshness**
  Run `scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent` with the observed plugin root when available.

- [ ] **Step 4: Ask Auto Mode authorization**
  After validation and sync pass, ask `project_auto_mode_authorization` for `docs/superpowers/specs/2026-06-11-plugin-stale-code-cleanup-audit-findings.md`.

## Self-Review

- Source spec is named.
- Acceptance criteria map to tasks.
- Every numbered task has a non-empty `**Use Cases:**` block.
- Proof oracle includes focused and full validation.
- Feature work uses `superpowers:test-driven-development` via failing scenario/summary checks before implementation.
- Completion requires version freshness and live sync proof.

