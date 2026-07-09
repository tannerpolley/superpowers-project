# Post-Commit Push Merge And Stale Cache Design

## Purpose

Tighten the Superpowers Project workflow contract so branch-producing work cannot terminate after a commit, cannot offer `Done` while the repo has uncommitted changes, must ask to push before any merge route, and must re-ask missed continuation gates when a stale loaded thread appears to be following older skill text.

## Project Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines the durable lifecycle as `spec -> plan -> issue`, with issue execution routed through `resolve-issue` or `orchestrate-issues` and final integration routed through `merge-changes`.
- `skills/advanced-user-input/SKILL.md` currently says `Done` is valid only for verified final states, but it does not explicitly say a dirty worktree disqualifies a final `Done` gate.
- `skills/audit-project/SKILL.md` defines a healthy final `Done` gate when no blocking or repairable findings remain, but it likewise does not explicitly require a clean git worktree before `Done`.
- `skills/implement-plan/SKILL.md` asks `implement_plan_publish_permission` with `Local Merge Ready` or `Hold`, then routes directly to `$superpowers-project:merge-changes`. It does not ask a separate push permission after local commits exist.
- `skills/resolve-issue/SKILL.md` requires PR-ready evidence to show a pushed branch and open PR, but it does not require a separate user-facing push approval gate before push happens.
- `skills/merge-changes/SKILL.md` already has an explicit merge approval gate (`project_merge_approval`) and a strong final closeout proof contract that includes synced default branch, cleanup proof, and clean repo proof.
- The bundled Superpowers `finishing-a-development-branch` skill already treats push and merge as distinct choices: `Merge back locally` or `Push and create a Pull Request`. That means the repo-owned adapters are weaker than the upstream branch-finish contract they claim to require.
- This repo has already seen stale-session symptoms where an open thread continued using older loaded skill text after the source repo and live install had been updated.
- `skills/brainstorm-spec/SKILL.md`, `skills/brainstorm-spec/agents/openai.yaml`, and `skills/brainstorm-spec/scripts/test-scenarios.sh` all define and assert the nested Auto Mode route after brainstorming: `project_brainstorm_start_route`, `project_auto_mode_authorization`, and `Bounded Auto Merge`.
- The live installed plugin copy under `/home/tnnrpolley21/.codex/plugins/superpowers-project\skills/brainstorm-spec\` also contains the Auto Mode route.
- The exact cached bundle path that the user invoked for `brainstorm-spec` did not contain those Auto Mode strings, which is concrete evidence that at least one loaded cache surface is stale or unsynced relative to source and live install.
- The plugin-provided Auto Mode validator currently rejects an `[ordered]@{}` authorization ledger with `missing question_id` because its property probe recognizes `Hashtable` and `PSObject` but not ordered dictionaries. That means a valid ledger shape can fail validation depending on how the caller constructs it.

## User Decisions

- Post-commit routing should use a universal push gate: any workflow that has produced new commits must ask to push before it may offer merge or `Done`.
- A verified final `Done` gate is invalid whenever the repo still has uncommitted changes.
- When a thread appears stale and skips a required push or merge gate, the correct behavior is to warn that the loaded skill text may be stale and then re-ask the missed gate instead of terminating.
- This design should cover repo-owned project workflow contracts and repo-owned stale-cache diagnostics together.

## Problem Statement

The current workflow language is stricter than it was before, but it still leaves two important termination gaps.

First, the project skills say that a commit is not terminal, yet they do not define the next required user decision in a universal way. `implement-plan` can produce merge-ready branch output without an explicit push decision. `resolve-issue` can reach PR-ready proof with a pushed branch requirement but no user-facing push permission checkpoint. That makes it possible for agents to move from commit into push or into a later handoff without asking the missing question the user actually cares about.

Second, the shared continuation contract says `Done` requires a verified final state, but it does not explicitly require a clean worktree. That lets a workflow mistakenly treat "healthy artifact state" as equivalent to "workflow done" even when local documentation repairs or other edits remain uncommitted.

The stale-cache symptom makes both problems worse. If a thread was loaded before the latest contract changes, it may still skip the newer questions unless the repo-owned rules explicitly require a warning and a re-ask.

The Auto Mode absence after brainstorming is one concrete example. In current source and live install, the route exists. In at least one loaded cached bundle, it does not. That means users can encounter behavior that contradicts the repo's source-of-truth workflow even when the repo itself is already correct.

## Recommended Approach

Adopt one shared post-commit closeout rule across project skills:

- If the workflow has created new commits, the next required explicit user choice is whether to push.
- Merge routes are unavailable until the push gate has been answered and the selected route has been executed or deliberately held.
- `Done` is unavailable whenever `git status --short` is non-empty.
- A stale-thread mismatch is treated as a recoverable routing defect: warn, re-ask the missed gate, continue from the corrected route, and do not convert the skipped gate into implicit approval.

This should be expressed at three levels:

1. Shared native continuation policy:
   - final `Done` requires clean proof and clean worktree proof
   - custom or skipped routes cannot bypass push or merge approval
2. Skill-specific workflow contracts:
   - `implement-plan` must ask push permission after commit-producing work and before merge-ready or local merge routing
   - `resolve-issue` must ask push permission after verification and before pushing branch / opening PR
   - `audit-project` and any other final-health workflows must explicitly block `Done` while the repo is dirty
3. Validation surface:
   - repo-level tests must fail if a final `Done` contract omits clean-worktree language
   - scenario tests must fail if branch-producing workflows can route from commit to merge without an explicit push gate
   - stale-thread guidance must be present in repo-owned skill text or metadata where the workflow may otherwise look complete
   - brainstorm-spec coverage must prove that Auto Mode is exposed in active source and live-sync surfaces after brainstorming

## Workflow Design

### Shared Final-State Rule

Verified final `Done` means all of the following:

- the skill's own final proof passed
- no blocking or repairable workflow state remains
- the repo has no uncommitted changes
- any required push and merge decisions for the selected route have already been asked and recorded

If any of those are false, the terminal option stays `Stop`, not `Done`.

### Branch-Producing Sequence

The branch-producing lifecycle becomes:

1. implement or revise
2. verify
3. commit when appropriate
4. ask push permission
5. execute the selected push/hold route
6. only then ask merge approval or hand off to the merge-owning skill
7. after merge and cleanup proof, ask the final `Done` gate if the skill owns one

### `implement-plan`

Current gap:

- asks `Local Merge Ready` or `Hold`
- does not ask a separate push permission

Required redesign:

- after verification and cleanup proof, ask a native push gate
- recommended branch of that gate should push the branch and record structured push evidence
- only after push choice is answered should the workflow ask whether to continue into merge
- if the user chooses not to push, the branch can be held, but merge must not be offered and `Done` must remain unavailable

### `resolve-issue`

Current gap:

- PR-ready proof requires branch pushed and PR opened
- no separate push approval is required before that state is produced

Required redesign:

- after verification passes and before branch push or PR creation, ask a native push permission question
- only if push is approved should the workflow push and create the PR-ready handoff
- after PR-ready proof, the workflow should still ask the existing merge routing question
- if push is declined, the route becomes explicit hold/revisit state rather than silent termination

### `merge-changes`

`merge-changes` already owns merge approval and final clean closeout proof. The new contract should not weaken that. Instead:

- merge approval remains explicit
- final `Done` remains valid only after closeout proof passes
- add an explicit statement that `Done` is invalid if the repo has uncommitted changes at the final health gate

### `audit-project`

`audit-project` may remain a final-health skill, but only when:

- findings are healthy enough for final closeout
- no repair route remains
- the repo worktree is clean

If the audit itself created or approved local repairs that are still uncommitted, the workflow must not ask `Done`. It must route to a non-final continuation such as commit/push/merge/hold or `Stop`.

### Stale Thread Recovery

When observed behavior conflicts with repo-owned workflow contracts:

- report that the loaded thread may still be using older skill text
- identify the missed required gate, such as push approval or merge approval
- identify missing expected routes, such as the brainstorm-spec Auto Mode branch after a saved spec
- re-ask that gate natively instead of accepting the stale behavior as terminal
- continue from the selected corrected route

This is a workflow recovery rule, not a cache repair mechanism. It should not depend on editing plugin cache files or treating cache paths as durable source of truth.

## Implementation Surface

Likely files:

- `skills/advanced-user-input/SKILL.md`
- `skills/advanced-user-input/agents/openai.yaml`
- `scripts/test-advanced-user-input-policy.sh`
- `scripts/test-native-continuation-loop.sh`
- `skills/implement-plan/SKILL.md`
- `skills/implement-plan/agents/openai.yaml`
- `skills/implement-plan/scripts/test-scenarios.sh`
- `skills/resolve-issue/SKILL.md`
- `skills/resolve-issue/agents/openai.yaml`
- `skills/resolve-issue/scripts/test-scenarios.sh`
- `skills/merge-changes/SKILL.md`
- `skills/merge-changes/agents/openai.yaml`
- `skills/merge-changes/scripts/test-scenarios.sh`
- `skills/audit-project/SKILL.md`
- `skills/audit-project/agents/openai.yaml`
- `skills/audit-project/scripts/test-scenarios.sh`
- repo-level README or workflow docs only if they still describe weaker continuation semantics

If a shared helper is needed, it should live in the repo source and validate clean-worktree final gates or structured push ledgers without depending on cache paths.

## Validation Expectations

Validation should prove:

- a final `Done` contract explicitly requires clean worktree state
- `audit-project` does not allow `Done` when uncommitted changes remain
- `implement-plan` cannot route from commit-producing work directly into merge-ready continuation without an explicit push decision
- `resolve-issue` cannot claim PR-ready completion without a structured push approval gate before push
- `merge-changes` final `Done` still requires clean closeout proof and now also clean worktree proof
- repo-level continuation policy tests enforce the "no Done with uncommitted changes" rule
- stale-thread guidance exists and tells the workflow to warn and re-ask missed gates rather than terminate
- `scripts/validate.sh` passes
- `scripts/sync-live.sh --validate` passes before live install update

## Error Handling

Examples that must block `Done`:

- local docs were changed by an audit repair and are still uncommitted
- implementation produced commits but push permission was never asked
- push was declined, but the workflow tries to offer merge anyway
- merge approval was skipped because the thread followed stale loaded text
- final closeout proof passes, but `git status --short` is still non-empty

Examples that must re-ask instead of terminate:

- the user reports the agent stopped after commit
- the user reports the agent stopped after push without asking merge
- the active thread appears to be using older loaded skill text than the repo source now requires

## Tradeoffs

This design is stricter than the current repo contracts. It adds more explicit gates, especially for non-issue branch work, and it may slow down users who are comfortable with immediate push after verification. That cost is acceptable because the user has explicitly said that commit must not be a stopping point and push / merge must be separate approvals.

The stale-thread warning also adds visible friction, but it is less harmful than silently accepting a skipped gate and pretending the workflow reached a valid closeout.

The main complexity is local-branch flow. A universal push gate means the repo must decide what "push before merge" means for work that might otherwise have been merged locally. The design accepts that friction because the user chose universal strictness.

## Non-Goals

- Do not edit or rely on plugin cache files as the durable fix.
- Do not remove explicit merge approval from `merge-changes`.
- Do not weaken PR-ready, premerge, cleanup, or closeout proof.
- Do not let a stale-thread warning become a blanket excuse for skipped workflow gates.
- Do not treat a pushed branch as equivalent to merge approval.
- Do not treat a clean audit result as equivalent to workflow completion when edits are still uncommitted.

## Milestone Linkage

- `M0 - Governance`: continuation-gate strictness, final-state proof, push/merge approvals, and stale-thread recovery rules.
- `M1 - Source Of Truth`: repo skill docs, tests, and live-sync behavior must all agree on the stronger contract.

## Proof Oracle Candidates

- `rg -n "Done is valid only" skills` shows clean-worktree language at final gates.
- `rg -n "push permission|push approval|ask to push" skills/implement-plan skills/resolve-issue` shows explicit pre-merge push gates.
- `Select-String` or equivalent checks show `project_brainstorm_start_route`, `project_auto_mode_authorization`, and `Bounded Auto Merge` in the source repo and live install.
- `skills/implement-plan/scripts/test-scenarios.sh` fails if merge-ready routing can happen without push approval.
- `skills/resolve-issue/scripts/test-scenarios.sh` fails if PR-ready routing can happen without push approval.
- `skills/audit-project/scripts/test-scenarios.sh` fails if healthy `Done` can happen while the repo is dirty.
- `skills/brainstorm-spec/scripts/test-scenarios.sh` fails if the active brainstorm-spec contract stops exposing Auto Mode after brainstorming.
- `scripts/test-advanced-user-input-policy.sh` and `scripts/test-native-continuation-loop.sh` fail if the shared contract omits the clean-worktree final-state rule.
- `scripts/lib/auto-mode-contract.sh` accepts both ordered and plain authorization ledger objects when they contain the same valid fields.
- `scripts/validate.sh` passes.
- `scripts/sync-live.sh --validate` passes.

## Open Questions For Planning

- Should the universal push gate introduce a shared push-ledger helper, or should each affected skill define its own structured approval receipt?
- For `implement-plan`, should declining push automatically map to `Hold`, or should it reopen a richer revisit route with review evidence and publish-choice revision?
- Should the stale-thread re-ask guidance live only in repo-owned skill text and tests, or also in README-level user guidance for why a thread may repeat a question after a contract change?

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Consistency check: the spec consistently treats commit as non-terminal, push as a required explicit gate, merge as a separate later gate, and `Done` as forbidden on dirty worktrees.
- Scope check: this is one coherent governance hardening slice, but it likely needs one implementation plan and focused scenario coverage across several skills.
- Ambiguity check: the remaining open questions are implementation details about shared helpers and exact revisit behavior, not missing product direction.
