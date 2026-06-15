# Issue 44 Resolve Terminal Closeout Plan

**Source Issue:** https://github.com/tannerpolley/superpowers-project/issues/44
**Goal:** Make issue #44 executable and close it by adding regression proof that `resolve-issue` cannot terminate at PR-ready without a validated continuation ledger.

## Context

The resolver already has a terminal-closeout validator and continuation-decision helpers. The remaining gap for #44 is issue-specific proof: there is no local mirror, no source plan, and no regression that directly asserts PR-ready proof without any continuation ledger is blocked.

## Task 1: Add Missing Terminal-Closeout Regression

**Use Cases:**
- A resolver implementation reaches PR-ready validation, but the agent attempts final closeout without passing `ContinuationDecisionJson` or `ContinuationDecisionPath`.
- The validator must fail loudly with a reason that identifies the missing continuation decision instead of allowing a success-style result.
- Existing explicit Stop behavior must keep passing so users can intentionally pause at PR-ready.
- Existing Merge behavior must stay non-terminal so agents are forced into the selected `merge-changes` route.

**Steps:**

- [ ] Add a scenario to `skills/resolve-issue/scripts/test-scenarios.ps1` named `resolve terminal closeout blocks missing continuation ledger`.
- [ ] Build a valid PR-ready result using the existing fixture pattern.
- [ ] Call `validate-terminal-closeout.ps1` with the valid PR-ready result and no continuation decision input.
- [ ] Assert the result is not OK and the reason mentions `continuation decision`.
- [ ] Run `skills/resolve-issue/scripts/test-scenarios.ps1`.

## Task 2: Validate The Issue Mirror And Plan Gates

**Use Cases:**
- A future resolver can start issue #44 only after the mirror is under `docs/superpowers/issues`, points to this source plan, and carries strict workflow metadata.
- The linked source plan must satisfy the strict Task # Use Cases contract before branch setup or code edits.
- The proof oracle must be executable from a clean checkout and must not rely on stale cache paths.

**Steps:**

- [ ] Run `skills/create-issues/scripts/validate-issue-mirror.ps1` with `-MilestoneRequired` for the #44 issue mirror.
- [ ] Run `scripts/validate-plan-task-use-cases.ps1` for this plan.
- [ ] Update the issue mirror only if validation finds missing metadata or proof gaps.

## Task 3: Run Repo And Live-Sync Validation

**Use Cases:**
- Resolver scenario coverage must pass in isolation.
- The full plugin source validation must pass after the regression test and issue artifacts are added.
- Live plugin sync validation must prove the updated resolver tests and artifacts do not break package distribution.
- Cleanup proof must show no leftover repo-owned processes.

**Steps:**

- [ ] Run `skills/resolve-issue/scripts/test-scenarios.ps1`.
- [ ] Run `scripts/validate.ps1`.
- [ ] Run `scripts/sync-live.ps1 -Validate`.
- [ ] Run the repo cleanup hook.

## Task 4: Publish PR-Ready Work For Issue 44

**Use Cases:**
- The branch is pushed only after the native push permission gate is approved.
- The PR body must include `Closes #44`.
- PR-ready handoff must record acceptance coverage, verification commands, branch push proof, and native goal completion proof.
- `resolve-issue` must not claim final completion unless the user explicitly selects Stop and the terminal validator passes, or the selected continuation route starts `merge-changes`.

**Steps:**

- [ ] Review changed artifacts and validation evidence before push permission.
- [ ] Ask `project_resolve_push_permission`.
- [ ] If approved, push the branch and open a PR that closes issue #44.
- [ ] Validate PR-ready evidence with `skills/resolve-issue/scripts/validate-pr-ready.ps1`.
- [ ] Ask `project_resolve_next_step` and continue the selected route.
