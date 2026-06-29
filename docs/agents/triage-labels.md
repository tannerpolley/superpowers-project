# Triage Labels

This repo uses GitHub labels as the tracker vocabulary for Superpowers Project issue mirrors.

## Type Labels

- `type:bug`: broken behavior or regression.
- `type:feature`: new user-visible or agent-visible capability.
- `type:task`: maintenance, docs, setup, process, or validation work.
- `type:issue-set`: parent issue that groups one approved multi-issue plan.
- `type:sub-milestone`: parent issue that acts as a pseudo sub-milestone inside a real GitHub Milestone.
- `type:plan-wrapper`: non-executable wrapper issue that groups leaf issues for one plan under a pseudo sub-milestone.

Hierarchy labels identify rollup records. They do not replace GitHub Milestones, and they do not make parent or wrapper issues executable.

## Status Labels

- `status:triage`: scope or acceptance criteria still need review.
- `status:ready`: ready for an agent to execute from the issue mirror and source plan.
- `status:blocked`: blocked on a decision, dependency, access, or external state.

## Legacy GitHub Defaults

The repository may still contain GitHub default labels such as `bug`, `enhancement`, `documentation`, and `question`. Superpowers Project issue mirrors should prefer the `type:*` and `status:*` labels above.
