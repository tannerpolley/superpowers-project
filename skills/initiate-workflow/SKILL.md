---
name: initiate-workflow
description: Use when a Superpowers Project request needs mode selection and routing to one owning workflow skill.
---

# Initiate Workflow

Own `project_workflow_mode` and select one route owner.

## Capability Preflight

Require `filesystem.read`, `shell`, and `native.user-input` from `docs/superpowers/capabilities.yml`. Stop before routing when one is absent.

Follow `skills/advanced-user-input/SKILL.md` for shared gates and use `docs/superpowers/workflow-contract.yml` as the route graph.

## Startup

1. Resolve the plugin root and run `scripts/get-agent-plugin-version.sh -Banner -RequireCurrent` there.
2. Inspect the repository, request, canonical artifacts, and Git state without mutation.
3. Ask `project_workflow_mode`: Manual Mode, Auto Mode, or Looping Mode.
4. Write a ledger binding the request fingerprint, repository, candidate and mutation scope, proof policy, and stop conditions. Run `scripts/validate-workflow-mode-ledger.sh -ModeLedgerPath <ledger>` and, for Auto, `scripts/validate-auto-mode-authorization.sh -AuthorizationPath <ledger>`.
5. Send Looping Mode to `$superpowers-project:loop-controller` with explicit budget and candidate sources.

Route missing context to setup-project; unresolved design to brainstorm-spec; critique to audit-project; approved design to write-plan; tracker slices to create-issues; approved non-issue plans to implement-plan; direct leaf issues to resolve-issue; delegated leaf issues to orchestrate-issues; integration to merge-changes; drift to align-project; repetition to loop-controller.

Start the owner with `scripts/workflow-run.sh -RunRoot <run> -AuthorizationPath <ledger> -Action start`, then record selection with `-Action select` before mutation. Downstream routes reuse that run and authority.

## Closeout

Stop on materially ambiguous ownership, invalid authorization, missing capability, or scope excess. Manual ambiguity returns to native input; Auto fails closed. `Stop` remains intermediate, and this router never claims verified final `Done`.
