# Brainstorm Design Checklist Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `$superpowers-project:brainstorm-spec` treat the upstream `superpowers:brainstorming` checklist, including Design 1 / Design 2 alternatives and section-by-section approval checks, as a mandatory gate instead of a soft reference.

**Architecture:** Harden the brainstorm-spec source skill and agent metadata, then lock the behavior with focused scenario tests. Reuse the upstream `superpowers:brainstorming` workflow as the authority; the project adapter adds repo context and native user input but cannot weaken or skip the upstream design checklist.

**Tech Stack:** Markdown skill contracts, YAML agent metadata, PowerShell scenario validation, live plugin sync scripts.

---

## Source And Scope

**Source Request:** User requested that `$superpowers-project:brainstorm-spec` make the Design 1 / Design 2 checklist and checks required by `superpowers:brainstorming` mandatory.

**Non-Goals:**

- Do not edit plugin cache files directly.
- Do not change the upstream `superpowers:brainstorming` skill.
- Do not add implementation, issue creation, branch, PR, or merge routes to brainstorm-spec.
- Do not allow Auto Mode authorization to bypass the upstream brainstorming checklist.

## Acceptance Criteria

- `brainstorm-spec` explicitly states that the upstream brainstorming checklist is mandatory, ordered, and blocking.
- The skill requires at least Design 1 and Design 2 alternatives, with tradeoffs and a recommendation, before a design can be selected.
- The skill requires design-section presentation and user approval after each section, including architecture, components, data flow, error handling, and testing.
- The skill forbids implementation, issue creation, planning, branch work, PR work, merge work, and Auto Mode authorization before the checklist, written spec, self-review, and user review are complete.
- Agent metadata repeats the mandatory checklist gate so startup-loaded agents see the requirement.
- Focused scenario tests fail if the mandatory checklist or Design 1 / Design 2 language is removed.

## Proof Oracle

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-plan-task-use-cases.ps1 -PlanPath docs/superpowers/plans/2026-06-12-brainstorm-design-checklist-gate-plan.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\brainstorm-spec\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-readability.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
```

## Test Complete

Testing is complete when the proof oracle passes, live sync updates the deployed plugin copy, the version freshness banner reports current plugin surfaces, and the repo cleanup hook runs.

## Metrics And Tolerances

No numerical engineering metrics apply. Pass/fail is contract-based: required strings, checklist ordering, metadata visibility, live sync, and version freshness must pass exactly.

## Task 1: Add Mandatory Checklist Coverage

**Use Cases:**
- A new agent reads only `brainstorm-spec` and still understands that upstream `superpowers:brainstorming` checklist tasks are mandatory and ordered.
- A future edit that removes Design 1 / Design 2 alternatives fails focused validation.
- A future edit that allows planning or Auto Mode before user-reviewed written specs fails focused validation.
- A future edit that treats design-section approval as advisory fails focused validation.

**Files:**
- Modify: `skills/brainstorm-spec/scripts/test-scenarios.ps1`

- [x] **Step 1: Add mandatory checklist scenario**
  Require strings for the upstream checklist gate, ordered checklist completion, Design 1, Design 2, 2-3 approaches, section approval, written design doc, self-review, user review, and transition only to planning.

- [x] **Step 2: Add metadata checklist scenario**
  Require matching metadata strings so startup-loaded agents see the same gate.

- [x] **Step 3: Prove RED**
  Run the brainstorm-spec scenario test before contract edits and confirm it fails for missing mandatory checklist text.

## Task 2: Harden Brainstorm-Spec Contract

**Use Cases:**
- A repo-backed brainstorm cannot skip directly to a recommendation without presenting at least Design 1 and Design 2.
- A design with unresolved architecture, component, data-flow, error-handling, or testing sections cannot be treated as approved.
- A saved spec cannot be used to start write-plan, create-issues, implementation, or Auto Mode until self-review and user review are complete.
- If an agent cannot satisfy the checklist, it must stop at the blocking question instead of inferring approval.

**Files:**
- Modify: `skills/brainstorm-spec/SKILL.md`
- Modify: `skills/brainstorm-spec/agents/openai.yaml`

- [x] **Step 1: Add a blocking upstream checklist gate**
  State that the upstream `superpowers:brainstorming` checklist is mandatory, ordered, and cannot be weakened by project adapter behavior.

- [x] **Step 2: Require Design 1 / Design 2 alternatives**
  Require at least two real design alternatives named Design 1 and Design 2, with tradeoffs and recommendation, before selecting a design.

- [x] **Step 3: Require section approvals and user review**
  Require design-section approval after each section, written design doc saving, self-review, and user review before any transition to planning or automation.

## Task 3: Validate, Sync, And Report Freshness

**Use Cases:**
- The source repo passes focused and full validation after the contract change.
- The live deployed plugin copy receives the updated brainstorm contract through sync.
- Version freshness proof catches stale live or observed plugin surfaces before completion is claimed.
- Cleanup proof runs before reporting the repository work complete.

**Files:**
- Modify: live deployed plugin copy through `scripts\sync-live.ps1 -Validate`
- No direct edits to plugin cache paths

- [x] **Step 1: Run focused validation**
  Run the plan use-case validator, brainstorm-spec scenario tests, and skill metadata readability tests.

- [x] **Step 2: Sync live with validation**
  Run `scripts\sync-live.ps1 -Validate`.

- [x] **Step 3: Confirm version freshness and cleanup**
  Run the agent plugin version banner with `-RequireCurrent` when an observed root is available, then run the repo cleanup hook.

## Self-Review

- Source request is named.
- Acceptance criteria map to tasks.
- Every numbered task has a non-empty `**Use Cases:**` block.
- Proof oracle includes focused validation and live sync.
- Contract edits are source-only and avoid plugin cache paths.
