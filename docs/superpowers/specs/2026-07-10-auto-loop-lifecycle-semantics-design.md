# Lean Auto And Loop Lifecycle Semantics

## Status

Approved for implementation. This revision replaces the earlier controller-heavy design.

## Problem

The startup mode and downstream workflow skills disagree about the unit of autonomy. Auto is described as one route, so later skills can ask again during specification, planning, issue routing, publication, push, or merge. Looping adds another user continuation question even when its startup budget still permits another candidate.

## Product Contract

| Mode | User questions | Work unit | Normal stop |
|---|---|---|---|
| Manual | Ask at material gates | One user-directed outcome | Verified closeout or explicit stop |
| Auto | One startup mode selection | One requested outcome from raw request through verified closeout | Completion or a safety blocker |
| Looping | One startup mode and budget selection | Sequential Auto-like outcomes | Budget, no-ready candidate, failed health, blocker, expiry, or interruption |

Selecting Auto or Looping at `project_workflow_mode` is the authorization decision. There is no second Auto question. Generated specs and plans are outputs of the same outcome, not new permission boundaries.

## Lean Design

Reuse the existing `WorkflowRuntime`, immutable authorization hash, append-only event ledger, and #113 proof receipts. Do not add another lifecycle controller, authorization subsystem, artifact-binding framework, command package, or receipt format.

Make three focused changes:

1. Validate Auto directly from the startup mode ledger. It may begin from a raw request, is bound to one repository and one candidate outcome, permits evidence-based direct-versus-issue routing, and permits push/PR/merge only after existing proof gates pass.
2. Add one small mode-aware gate decision helper to `workflow_policy.py`. Manual returns `ask`; Auto and Looping select the owner-provided safe recommendation; every mode blocks when no authorized option exists. `WorkflowRuntime` records resolved gate decisions in its existing ledger.
3. Make Loop continuation a recorded budget-and-health decision. It remains one candidate at a time, but does not ask between candidates unless the startup policy explicitly requests a checkpoint.

Owner skills share these rules through `advanced-user-input`; they do not each implement their own Auto policy.

## Safety Boundary

This is a cooperative local-agent policy, not host attestation. Public hashes detect accidental or later ledger changes; they do not prove that Codex displayed a native prompt. Safety continues to come from repository scope, explicit startup selection, bounded candidate scope, stop conditions, and #113 fail-closed integration proof.

Auto and Looping must block on changed authorization, repository mismatch, missing safe recommendation, failed proof, dirty unsafe state, scope expansion, or user interruption. Neither mode authorizes unrelated repositories, destructive Git, purchases, secrets, broad backlog draining, or bypassing external-write policy.

## Acceptance Criteria

- A raw request can select Auto without an existing spec.
- `project_workflow_mode` is the only routine Auto authorization question.
- Auto carries one outcome across skill boundaries and records zero routine downstream questions.
- Manual still asks at material gates.
- Direct versus issue-backed work is an evidence-based gate decision.
- Auto can consume merge authority only after existing clean premerge proof.
- Looping selects one candidate at a time and continues without a routine question while budget and health remain valid.
- Focused tests cover ask, decide, block, raw-request Auto, outcome completion, Loop continuation, and tampered authority.
- No generated usability-trial corpus is committed for this change.

## Non-Goals

- Cryptographic host or native-prompt attestation.
- A typed phase machine for every skill transition.
- New lifecycle, authorization, issue-route, or Loop runtime modules.
- Reworking the #113 evidence kernel.
- Workspace isolation, distribution changes, broad documentation rewrites, or unrelated refactoring.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
|---|---|---|---|---|---|
| Lifecycle unit | User request | One requested outcome, not one skill route | Removes repeated Auto questions | No | Workflow maintainer |
| Runtime shape | Existing #113 runtime | Extend existing policy and ledger | Avoids duplicate frameworks | No | Runtime maintainer |
| Gate behavior | Product contract | Manual asks; Auto and Looping record safe recommendations | One shared rule | No | Workflow maintainer |
| Loop continuation | User request | Budget and health decide by default | Removes routine between-candidate prompts | No | Loop maintainer |
| Trust model | Platform capability | Cooperative local agent; no host attestation claim | Keeps claims honest | No | Governance maintainer |

