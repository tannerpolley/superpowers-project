# Project Merge Skill Design

## Summary

Add a new `$project:merge-changes` skill that owns the integration half of issue execution after `$project:resolve-issue` produces a PR-ready handoff.

`$project:resolve-issue` should keep the issue-specific implementation lifecycle: issue mirror intake, source plan validation, native goal setup, branch/worktree setup, implementation, verification, commit, push, PR creation, and PR-ready evidence. `$project:merge-changes` should own everything after that: orchestrator review, CI and review feedback, merge, linked issue closure verification, cleanup, pruning, and final clean repo proof.

## Context Evidence

- `docs/superpowers/PROJECT_CONTEXT.md` defines Superpowers Project as the durable project context, roadmap, GitHub issue linkage, native user-input grilling, and native `/goal` issue execution layer.
- `skills/resolve-issue/SKILL.md` currently owns the full lifecycle from issue mirror through merge, issue close, goal completion, branch cleanup, and cleanup hook proof.
- `skills/resolve-issue/scripts/premerge.ps1` already models merge-readiness checks: PR closes the linked issue, required checks pass, issue acceptance state is covered, changed files have verification receipts, and proof commands exist.
- `skills/resolve-issue/scripts/closeout.ps1` already models final integration closeout: PR merged, linked issue closed, branch cleanup structured, cleanup hook passed, and goal completion proof present.
- `skills/resolve-issue/scripts/test-scenarios.ps1` currently tests happy closeout inside the resolver. That test belongs under `$project:merge-changes` after the split.
- `codex-dynamic-workflows` supports explicit orchestration, work packets, goal mode for sustained execution, bounded subagent/thread delegation, integration, and verification. `$project:resolve-issue` should borrow the parts that strengthen issue execution, but it should not run the whole dynamic-workflow lifecycle by default because `$project:resolve-issue` already owns native goals, GitHub issue linkage, branch/worktree setup, PR handoff, and script gates.
- Codex app thread tools can create and message background threads, and automation tools can create heartbeat wakeups. The spec should use these to avoid long-running busy waits.

## User Decisions

These decisions were made through native UI during brainstorming:

- Handoff boundary: `$project:resolve-issue` hands off when a branch is pushed and a PR is opened with PR-ready evidence.
- Merge owner: `$project:merge-changes` is normally run by the main orchestrator thread, not by the worker that implemented the change.
- Goal completion: `$project:resolve-issue` completes its native goal at PR-ready evidence, not after merge.
- Waiting model: use worker handoff plus heartbeat or worker signal. Do not keep the main orchestrator idly waiting for a long-running worker.
- Spec scope: include the `$project:merge-changes` skill split and automation/heartbeat behavior for worker readiness.
- Resolve topology: `$project:resolve-issue` must always ask whether to resolve in the current thread or open a new worktree agent.
- Worker orchestration: when worker mode is selected, `$project:resolve-issue` must create a lightweight dynamic work packet map adapted from `codex-dynamic-workflows`. It should invoke the full `codex-dynamic-workflows` skill only when the issue actually meets its own decision rule: broad work, independent tracks, elevated risk, reusable workflow value, separate verification needs, or explicit user request.

## Problem

`$project:resolve-issue` has become too broad. It owns implementation, PR finishing, review, merge, issue closeout, native goal completion, branch cleanup, and final clean repo proof.

That creates two problems:

1. The worker/orchestrator split is blurred. A worker can implement an issue, but the main thread should own review and integration.
2. Native goal semantics are overloaded. The worker's goal should be concrete and finishable: implement the issue, prove the checkboxes, push the branch, and open a PR. The issue is not fully integrated until `$project:merge-changes` finishes.

## Goals

- Add `$project:merge-changes` as the integration and cleanup skill for one PR created from a Superpowers Project issue workflow.
- Make `$project:resolve-issue` end at PR-ready handoff evidence.
- Keep native `/goal` required for `$project:resolve-issue` issue implementation.
- Mark the `$project:resolve-issue` goal complete only when PR-ready evidence exists:
  - issue acceptance checkboxes are covered by implementation evidence;
  - verification commands have passed;
  - branch is pushed;
  - PR is opened and references/closes the linked issue;
  - worker notifies or hands off to the orchestrator.
- Make `$project:merge-changes` run from the main orchestrator thread by default.
- Move `premerge.ps1` and `closeout.ps1` responsibilities from `$project:resolve-issue` into `$project:merge-changes`.
- Add automation guidance so the orchestrator does not busy-wait for a worker thread.
- Add native continuation gates across Superpowers Project handoffs so the agent asks how to continue and then immediately starts the selected next skill instead of only telling the user what to prompt next.

## Non-Goals

- Do not make `$project:merge-changes` implement product/code changes directly except for review-requested fixes explicitly delegated back to a worker or handled as a small follow-up.
- Do not let workers merge their own PR by default.
- Do not require GoalBuddy boards.
- Do not start a native `/goal` at `$project:brainstorm-spec` or `$project:write-plan` by default.
- Do not make the main orchestrator poll indefinitely.
- Do not require GitHub Projects as an execution surface.

## Proposed Workflow

### Native Continuation Gate

Major Superpowers Project handoffs should end with a native continuation question when `request_user_input` is callable. The answer is executable routing, not advisory text.

After the current skill completes its required artifact and validation, it should ask one concise next-step question and then continue in the same turn with the selected route when tool and context state allow it.

Default handoff gates:

- `$project:brainstorm-spec` after saving a spec: ask whether to continue to `$project:write-plan`, `$project:create-issues` for a direct issue, or stop.
- `$project:write-plan` after saving a plan: ask whether to continue to `$project:create-issues`, execute with `superpowers:subagent-driven-development`, or execute inline with `superpowers:executing-plans`.
- `$project:create-issues` after creating issue mirrors or GitHub issues: ask whether to resolve the first ready issue, resolve a selected issue, or stop after issue creation.
- `$project:resolve-issue` after PR-ready handoff: ask whether to start `$project:merge-changes`, resolve another ready issue, or stop at PR-ready.
- `$project:merge-changes` after clean closeout: ask whether to resolve the next ready issue, run `$project:audit-project`, or stop.

The selected route must be honored immediately. Do not end with "run `$project:create-issues` next" when the user selected that option. Start `$project:create-issues` and carry over the source artifact path, decisions, and proof summary.

If the selected next skill requires its own material decision, that next skill may ask its own native UI question. If a required tool is unavailable or the route would perform an external write that still needs approval, stop with a clear pending state and exact resume target.

### Phase 1: `$project:resolve-issue`

`$project:resolve-issue` remains issue-specific and goal-backed.

It should:

1. Read the issue mirror under `docs/superpowers/issues`.
2. Validate the linked source plan under `docs/superpowers/plans`.
3. Always ask the execution topology question: resolve in the current thread or open a new worktree agent.
4. Activate the native `/goal` for implementation.
5. Set up the branch/worktree or worker thread.
6. Execute with Superpowers methods:
   - `superpowers:using-git-worktrees`
   - `superpowers:test-driven-development`
   - `superpowers:executing-plans` or `superpowers:subagent-driven-development`
   - `superpowers:verification-before-completion`
   - `superpowers:finishing-a-development-branch`
   - a lightweight Dynamic Work Packet Map when a worker thread/worktree agent is selected
   - `codex-dynamic-workflows` only when full orchestration is justified by scope, risk, independent packets, reusable workflow value, separate verification needs, or explicit user request
7. Commit and push the branch.
8. Open a PR that closes the exact linked GitHub issue.
9. Create a PR-ready handoff ledger.
10. Complete the native goal with structured proof that the implementation goal is finished.
11. Notify or wake the main orchestrator.

`$project:resolve-issue` must not claim the issue is fully integrated. Its final state is `PR-ready handoff created`.

### Resolve Topology Question

`$project:resolve-issue` must ask this question in every normal run after issue/source-plan validation and before branch or worktree setup:

```text
How should this issue be resolved?
```

Options:

- `Open worktree agent`: create a new Codex worktree thread/agent to implement the issue while the current thread remains orchestrator.
- `Current thread`: resolve the issue in the current thread using worktree isolation.

Recommend `Open worktree agent` for non-trivial AFK issues, multiple plan tasks, independent packets, risky shared-code changes, or work expected to end in a PR. Recommend `Current thread` only for small, low-risk, single-thread implementation work.

Do not skip this question because the answer seems obvious. The point is to force an explicit orchestration decision before implementation begins. In explicit smoke tests, `debug_question_mode` may record the recommended option instead of opening the native UI.

### Dynamic Workflow Compatibility Requirement

When `Open worktree agent` is selected, `$project:resolve-issue` must use a small Project Resolve-native packet contract before launching or instructing the worker. This keeps worker orchestration concrete without duplicating the full `codex-dynamic-workflows` skill.

The Dynamic Work Packet Map should define:

- goal and success criteria;
- current repo, issue mirror, source plan, branch, and proof oracle;
- orchestrator ownership;
- worker packet objective;
- worker do/do-not boundaries;
- PR-ready handoff requirements;
- verification commands;
- merge owner and `$project:merge-changes` handoff;
- wakeup or heartbeat policy.

This map belongs in the `$project:resolve-issue` setup ledger or worker handoff. Do not create `.workflow/<slug>` directories, `state.json`, `orchestration.md`, reusable recipes, or dynamic-workflow helper-script output for ordinary issue resolution.

The worker packet must be self-contained and must tell the worker:

- use `superpowers:using-git-worktrees`;
- use `superpowers:test-driven-development` unless the source plan records an explicit opt-out;
- use `superpowers:executing-plans` or `superpowers:subagent-driven-development`;
- use `superpowers:verification-before-completion`;
- use `superpowers:finishing-a-development-branch`;
- open a PR that closes the exact linked issue;
- complete the `$project:resolve-issue` native goal only after PR-ready evidence exists;
- wake or notify the main orchestrator as the final action.

Use the full `codex-dynamic-workflows` skill only when at least two of these are true:

- the source plan has independent research, coding, QA, docs, or review tracks;
- a separate verification pass would materially reduce risk;
- the issue is broad enough that an explicit success contract would prevent drift;
- the change is risky because it touches destructive, external, production, secret, deployment, billing, account, or repo-wide behavior;
- the workflow is likely to become a reusable recipe;
- the user explicitly asks for dynamic workflows, swarm, subagents, parallel agents, or Claude Code-style orchestration.

Even when the full skill is used, `$project:resolve-issue` remains the lifecycle owner. It owns the issue mirror, source plan, native goal proof, topology question, setup ledger, worktree/branch setup, PR-ready evidence, and worker handoff. `codex-dynamic-workflows` supplies packet discipline, risk gates, and integration notes only.

Do not import these `codex-dynamic-workflows` behaviors into the default `$project:resolve-issue` path:

- creating `.workflow/<slug>` folders for every issue;
- running `new_workflow.py`, `collect_results.py`, or `verify_workflow.py` as required gates;
- activating a second goal mode separate from `$project:resolve-issue`'s native goal;
- saving reusable recipes by default;
- simulating subagents when the user selected current-thread execution;
- asking a second approval question for non-risky steps already covered by the issue mirror, topology question, and GitHub PR flow;
- treating dynamic workflow integration as the final closeout owner.

### Phase 2: Worker Handoff And Wakeup

When `$project:resolve-issue` runs in a worker worktree/thread, the final worker step must send the orchestrator a handoff message when thread tools are callable.

The handoff should include:

- worker thread id or title;
- dynamic workflow artifact path or summary;
- repo path and worktree path;
- branch name;
- PR URL;
- issue URL;
- issue mirror path;
- source plan path;
- verification ledger;
- native goal completion proof;
- changed files;
- remaining risks;
- requested reviewer action.

If thread messaging tools are unavailable, the worker final response must give the user the handoff text and tell them to resume the main orchestrator with it.

The main orchestrator should not wait in a tight loop. If the worker is still running, the orchestrator should:

- record the worker thread id, branch, and expected PR-ready evidence;
- optionally create a heartbeat automation to wake the orchestrator later;
- stop with a clear pending state until a worker/user signal or heartbeat resumes it.

Heartbeat automation should be used for "check back later" behavior. It should inspect the worker thread or PR state, not rerun implementation.

### Phase 3: `$project:merge-changes`

`$project:merge-changes` starts from a PR URL or worker handoff.

It should:

1. Verify it is running from the main orchestrator context or explicitly approved equivalent.
2. Read the PR, issue mirror, source plan, setup ledger, and verification ledger.
3. Run `superpowers:verification-before-completion` before merge-ready claims.
4. Run `premerge.ps1` checks:
   - PR closes the exact linked issue;
   - required checks pass or policy allows local proof;
   - changed files are covered by verification receipts or explicit exemptions;
   - issue acceptance checkboxes are checked or represented in closeout proof;
   - proof commands exist.
5. Review the PR diff and worker evidence.
6. Handle CI failures with `github:gh-fix-ci` or equivalent.
7. Handle review comments with `github:gh-address-comments` or equivalent.
8. Merge the PR after evidence is clean.
9. Verify the exact linked issue is closed.
10. Sync default branch.
11. Delete only the owned implementation branch locally and remotely.
12. Remove the owned worktree if one exists.
13. Run `git fetch --prune`.
14. Run the repo cleanup hook.
15. Verify clean repo state.
16. Write final closeout proof.

`$project:merge-changes` is the only phase allowed to claim the issue is fully integrated.

## Goal Model

Use native `/goal` as the issue implementation contract, not as the entire brainstorming-to-merge umbrella by default.

### Required Goal

`$project:resolve-issue` must activate a native goal when executing a ready issue.

The goal objective should be framed as implementation-to-PR-ready, for example:

```text
Implement <GitHub issue URL> from <issue mirror> using <source plan>. Complete when acceptance checkboxes are covered, verification passes, branch is pushed, PR is opened, and PR-ready handoff is sent to the orchestrator.
```

The `$project:resolve-issue` goal is complete when PR-ready evidence exists. It does not wait for merge.

### Optional Merge Goal

`$project:merge-changes` does not require a native goal by default. It can use a native goal only when the user explicitly asks for a goal-backed integration run.

The final issue state is still not complete until `$project:merge-changes` merges the PR, verifies issue closure, cleans up, prunes, and proves a clean repo.

## Skill Boundary Changes

### Add `$project:merge-changes`

Create:

```text
skills/merge-changes/SKILL.md
skills/merge-changes/agents/openai.yaml
skills/merge-changes/scripts/test-scenarios.ps1
skills/merge-changes/scripts/premerge.ps1
skills/merge-changes/scripts/closeout.ps1
skills/merge-changes/scripts/lib/contract.ps1
```

The new skill should include:

- PR intake contract;
- worker handoff intake contract;
- native question debug mode;
- main orchestrator ownership;
- bounded waiting and heartbeat automation rules;
- premerge checks;
- closeout checks;
- branch/worktree cleanup policy;
- `git fetch --prune` policy;
- final clean repo proof.

### Narrow `$project:resolve-issue`

Update `$project:resolve-issue` so it:

- no longer says it merges PRs or closes issues;
- no longer owns `premerge.ps1` or `closeout.ps1`;
- always asks whether to resolve in the current thread or open a worktree agent;
- creates a Project Resolve-native Dynamic Work Packet Map when a worktree agent is selected;
- invokes the full `codex-dynamic-workflows` skill only when the issue meets the full orchestration decision rule or the user explicitly requests it;
- emits a PR-ready handoff ledger;
- marks the native goal complete at PR-ready evidence;
- routes final integration to `$project:merge-changes`;
- blocks if asked to merge directly unless the user explicitly bypasses the split.

### Update Router And Metadata

Update:

- `skills/initiate-workflow/SKILL.md`
- `skills/initiate-workflow/agents/openai.yaml`
- `docs/superpowers/PROJECT_CONTEXT.md`
- `README.md`
- validation active skill lists

The route should read:

```text
resolve-issue: ready issue -> implementation -> pushed branch -> PR-ready handoff
merge-changes: PR/handoff -> review -> merge -> issue close -> cleanup -> clean repo proof
```

### Update `$project:create-issues`

Issue mirrors should include fields that support the split:

- `Resolution Owner`: worker or current thread
- `Merge Owner`: main orchestrator
- `Merge Policy`: squash, merge commit, rebase, or repo default
- `Worktree Cleanup Policy`
- `Orchestrator Wakeup Policy`

Existing fields can remain, but `Integration Policy` should point to `$project:merge-changes` as the owner of integration.

## Automation Contract

When a worker thread is not ready, `$project:merge-changes` should not run active long waits.

If automation tools are callable and the user wants the orchestrator to check back, `$project:merge-changes` may create a heartbeat automation attached to the orchestrator thread.

The heartbeat prompt should be self-contained:

```text
Check whether worker thread <id/title> or PR <url> has reached PR-ready state for <issue URL>. If PR-ready evidence exists, continue $project:merge-changes. If not ready, report current state and either schedule the next bounded check or ask the user.
```

Heartbeat checks should be bounded and evidence-based. They must not rerun implementation or silently merge.

If automation tools are absent, the skill should stop with a clear pending handoff and ask the user to resume when the worker reports PR-ready.

## Proof And Validation

Implementation should add or update tests that prove:

- validation active skill list includes `merge-changes`;
- `$project:resolve-issue` always asks the inline-vs-worktree-agent topology question before branch/worktree setup;
- worker-mode `$project:resolve-issue` requires a Dynamic Work Packet Map in the setup ledger or worker handoff;
- full `codex-dynamic-workflows` artifacts are optional and appear only when the issue meets the full orchestration decision rule or the user explicitly requested them;
- `$project:resolve-issue` scenario tests end at PR-ready handoff;
- `$project:merge-changes` scenario tests own previous `premerge` and `closeout` cases;
- `$project:write-plan` asks a native continuation question after saving a plan and starts `$project:create-issues` when selected;
- `$project:create-issues`, `$project:resolve-issue`, and `$project:merge-changes` document the same executable continuation-gate pattern for their handoffs;
- closeout rejects unstructured goal or cleanup proof;
- closeout rejects deletion of non-goal branches;
- router text includes `merge-changes`;
- sync deploys the new skill to plugin and user skill roots;
- full `scripts/validate.ps1` passes;
- `scripts/sync-live.ps1 -Validate` passes.

Proof oracle candidates:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

## Tradeoffs

### Benefits

- Smaller, clearer skill responsibilities.
- Worker threads can finish their own implementation goals without owning merge authority.
- Main orchestrator has a dedicated integration workflow.
- Long worker runs no longer force the main thread to busy-wait.
- Existing `premerge` and `closeout` scripts already map cleanly to the new skill.

### Costs

- Adds another skill to the router and validation surface.
- Requires handoff ledgers to be precise.
- Requires careful docs updates so agents do not think `$project:resolve-issue` fully closes the issue.
- Heartbeat automation behavior must be bounded so it does not become silent background merge automation.

## Open Questions

- Should `$project:merge-changes` always ask before merge, or may it merge automatically when PR evidence and repo policy are clean?
- Should `$project:merge-changes` support both real GitHub PRs and local-only PR fixtures for repos without GitHub remotes?
- Should issue mirrors get a new `Project Merge` section, or should the existing workflow metadata fields be extended in place?

## Recommended Next Step

Run `$project:write-plan` on this spec to create the implementation plan. The plan should start with failing tests for the new skill route and the narrowed `$project:resolve-issue` completion state before moving scripts.


