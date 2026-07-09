# Project Doctor Source Scope Audit Implementation Plan

**Source:** https://github.com/tannerpolley/milestones-plugin/issues/23

## Goal

Fix Project Doctor so product repos that do not own `skills/audit-project/SKILL.md` are not told to repair that absent source file.

## Implementation Tasks

- Scope the native UI closeout wording check to repos that actually contain the Doctor source skill file.
- Report absent Doctor source as informational/skipped in product repos instead of repairable.
- Keep live sync comparison skipped clearly when no source file exists.
- Add source-repo and product-repo fixture coverage.

## Proof Oracle

- `./skills/audit-project/scripts/test-scenarios.sh`
- `./scripts/validate.sh`

