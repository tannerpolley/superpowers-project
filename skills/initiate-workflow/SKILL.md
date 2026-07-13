---
name: initiate-workflow
description: Route Superpowers Project extension requests to project setup, brainstorming, audits, planning, issue creation, issue triage, alignment, or goal-backed resolution workflows.
---

# Initiate Workflow

This is the single entrypoint and route owner for `project_workflow_mode`. It selects one owning skill; it does not perform that skill's work.

## Capability Preflight

Require `filesystem.read`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before routing when a required capability is absent.

## Shared Policy

Read `skills/advanced-user-input/SKILL.md` for global question and artifact-review behavior. This route retains route-specific startup authorization, mode, and owner selection only. The authoritative route graph is `docs/superpowers/workflow-contract.yml` and the generated review is `docs/superpowers/WORKFLOW_ROUTE_INDEX.md`.

## Startup

1. Resolve the loaded plugin root and run `scripts/get-agent-plugin-version.sh -Banner -RequireCurrent` there.
2. Inspect the active repository, request, canonical artifacts, and Git state without mutating.
3. Ask `project_workflow_mode`: Manual Mode, Auto Mode, or Looping Mode. This is the only routine startup question.
4. Write the mode ledger, including the raw-request fingerprint, repository, candidate scope, mutation scope, proof policy, and stop conditions; validate it with `scripts/validate-workflow-mode-ledger.sh` from the plugin root.
5. For Auto Mode, validate that same ledger with `scripts/validate-auto-mode-authorization.sh`. Auto authorizes one outcome lifecycle and evidence-based direct or issue-backed routing; push, PR, and merge remain conditional on existing proof gates.
6. For Looping Mode, route through `$superpowers-project:loop-controller` with explicit budget and candidate sources.

## Owner Routing

Use setup-project for missing project context; brainstorm-spec for unresolved design; audit-project for evidence-backed critique; write-plan for approved design; create-issues for tracker slices; implement-plan for approved non-issue plans; resolve-issue for direct executable leaf issues; orchestrate-issues for delegated leaf issues; merge-changes for integration; align-project for drift; loop-controller for bounded repetition.

## Runtime Receipt

Start the selected route with `scripts/workflow-run.sh -Action start`, then record selection before the first mutation. Downstream skills reuse the same run root and authorization; they do not create replacement authority.

## Stop Conditions

Stop when the request maps to multiple materially different owners, authorization is missing/invalid, required capability is absent, or the selected route would exceed mode scope. Manual ambiguity returns to native input. Auto ambiguity fails closed. `Stop` is the intermediate terminal choice; this router never claims final `Done`.
