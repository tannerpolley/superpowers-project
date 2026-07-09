# Decision Ledger Examples

These examples show the minimum practical shape for spec and plan Decision Ledgers. Copy the pattern, not the sample facts. Every material decision needs a source, concrete answer, downstream impact, `Deferred?` value, and risk owner.

## Spec-Style Decision Ledger Example

<!-- decision-ledger-example: spec -->
```markdown
# Example Workflow Hardening Spec

## Intent

Harden one workflow contract without widening the current milestone.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
| --- | --- | --- | --- | --- | --- |
| User priority | user answer | Prioritize the Looping Mode safety gate before narrative polish. | The spec scopes the first implementation plan around one-candidate iteration proof. | No | brainstorm-spec maintainer |
| Canonical source | repo evidence | Use `docs/superpowers/workflow-contract.yml` as the native gate source of truth. | Later plans and validators read one repo-owned contract instead of restating route trees. | No | workflow-contract maintainer |
| Acceptance proof | repo evidence | Require validator output and a clean `scripts/validate.sh` run before handoff. | The spec cannot be accepted on prose review alone. | No | validation maintainer |
| Tracker automation | deferred decision | Defer GitHub Project field automation until tracker hygiene has a dedicated owner route. | If tracker drift appears, `align-project` owns the follow-up before merge closeout. | Yes | align-project maintainer |

## Acceptance Criteria

- [ ] The Looping Mode safety gate has validator-backed proof.
```

## Plan-Style Decision Ledger Example

<!-- decision-ledger-example: plan -->
```markdown
# Example Workflow Hardening Plan

## Outcome Proof

**Intent:** Implement the approved workflow hardening slice with validator-backed evidence.
**Target Output:** A merged source change with tests and a clean validation receipt.

## Decision Ledger

| Decision | Source | Answer | Impact | Deferred? | Risk owner |
| --- | --- | --- | --- | --- | --- |
| Source decision carried forward | source spec Decision Ledger | Keep `docs/superpowers/workflow-contract.yml` as the native gate source of truth. | The plan modifies the contract and validator together instead of adding parallel docs. | No | write-plan maintainer |
| Implementation scope | planning grill | Implement validator fixtures and contract repair only; do not create a new workflow skill. | The issue remains small enough for one branch and one focused proof oracle. | No | resolve-issue maintainer |
| Proof command | planning grill | Add a focused validator test and include it in `scripts/validate.sh`. | Merge readiness depends on both the targeted proof and the full validation suite. | No | validation maintainer |
| Live deployment timing | deferred decision | Defer live sync until source validation passes on the implementation branch. | If sync drift appears, the branch cannot be pushed until `sync-live.sh --validate` passes. | Yes | merge-changes maintainer |

## Task 1: Validator Fixture

**Use Cases:**
- A contract option differs from the skill option and validation fails.
- The repaired contract and skill pass targeted validation.
```
