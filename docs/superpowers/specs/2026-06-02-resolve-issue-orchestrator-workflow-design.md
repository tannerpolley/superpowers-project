# Resolve Issue Orchestrator Workflow Design

## Context Evidence Used

This spec extends `docs/superpowers/specs/2026-06-02-superpowers-project-extension-design.md` after the first Superpowers Project implementation passed validation. The existing resolver already requires one issue mirror under `docs/superpowers/issues`, a linked source plan under `docs/superpowers/plans`, structured native goal proof, no GoalBuddy board files, PR evidence, issue closeout, goal completion, branch cleanup, and cleanup hook proof.

The new decision comes from the June 2, 2026 native UI grilling answers:

- Execution topology: conditional, with a runtime question.
- Merge owner: main thread owns review, merge, issue close, and goal completion.
- Script gate mode: safety only.
- Worktree policy: native Codex worktree thread first.
- TDD policy: required.
- Finish branch policy: PR default.

The resolver should now support two execution shapes:

- solve the issue in the current thread;
- open a new Codex worktree thread to resolve the issue while the current thread acts as orchestrator, manager, reviewer, merger, and closeout owner.

## Problem

`resolve-issue` currently treats issue execution as a single-thread lifecycle. That is enough for small issues, but it misses the stronger Superpowers pattern for complex work: isolate work in a worktree, let a worker implement the issue, and keep the main thread free to coordinate, review, and finish the GitHub lifecycle.

The resolver also needs to loosen Bash scripts into safety gates instead of style enforcers. Scripts should block unsafe or invalid lifecycle states, but they should not make the workflow brittle by hard-coding every agent choice.

## Goals

- Ask a native UI question during every normal issue-resolution run: solve inline or open a worker worktree thread.
- Use `debug_question_mode` only for explicit non-interactive smoke tests, with a Native Question Debug Ledger.
- Keep native `/goal` as the lifecycle guard for the issue.
- Prefer native Codex worktree/thread tools for orchestrated worker execution.
- Keep the main thread responsible for orchestration, review, merge, issue close, goal completion, default-branch sync, branch cleanup, and final cleanup proof.
- Require TDD for feature and bug work unless the issue mirror records an explicit user-approved opt-out.
- Route bug failures through `superpowers:systematic-debugging` or diagnose discipline.
- Route independent work packets through `codex-dynamic-workflows`, `superpowers:dispatching-parallel-agents`, or `superpowers:subagent-driven-development` when the source plan supports it.
- Use `superpowers:verification-before-completion` before PR-ready, merge-ready, and completion claims.
- Use `superpowers:finishing-a-development-branch` with PR as the default finish path.
- Keep Bash scripts focused on safety invariants and proof validation.

## Non-Goals

- Do not add GoalBuddy boards or `docs/goals` to default issue resolution.
- Do not create a separate GoalBuddy-style board for orchestration.
- Do not make every issue use a worker thread.
- Do not force every issue into parallel agents.
- Do not let the worker merge its own PR or close the native goal.
- Do not turn advisory workflow preferences into hard script blockers.

## Approaches Considered

### Recommended: Runtime Choice With Main-Thread Orchestration

The resolver inspects the issue mirror and source plan, then asks the user whether to solve the issue in the current thread or open a worker worktree thread. The recommended option is dynamic:

- recommend worker thread for non-trivial AFK issues, multiple plan tasks, independent packets, risky shared-code changes, or work expected to end in a PR;
- recommend inline execution for small, single-step, low-risk issues.

This keeps the workflow frictionless while preserving explicit user choice. It also matches the approved decision that the main thread should manage review and integration.

### Inline Only

The resolver could keep all execution in the current thread. This is simpler, but it underuses Codex threads, worktrees, and the reviewer/orchestrator split. It also makes longer issue runs harder to supervise.

### Worker Always

The resolver could always spawn a worker worktree thread. This is clean for large AFK work, but it adds overhead for small issues and creates unnecessary coordination when the main thread can finish safely.

## Design

### Native Execution Topology Question

After repo, issue mirror, and source plan validation, and before implementation branch setup, `resolve-issue` asks:

```text
How should this issue be resolved?
```

Options:

```text
Open worker thread
Current thread
```

The recommended label is chosen from issue complexity. For non-trivial AFK issues, `Open worker thread (Recommended)` is first. For small issues, `Current thread (Recommended)` is first.

The answer is recorded in the setup ledger as structured evidence:

```json
{
  "execution_decision": {
    "question_id": "resolve_execution_topology",
    "source": "request_user_input",
    "selected_mode": "orchestrated-worker",
    "options": ["orchestrated-worker", "inline"],
    "recommended_mode": "orchestrated-worker"
  }
}
```

For non-interactive smoke tests, the same shape is recorded with `"source": "debug_question_mode"` plus the Native Question Debug Ledger fields already used by the project skills.

### Inline Execution

Inline mode keeps the current thread as both worker and lifecycle owner.

The resolver must:

1. Use `superpowers:using-git-worktrees` before implementation work.
2. Activate or verify the native goal.
3. Create or verify the issue branch.
4. Use `superpowers:test-driven-development` for feature or bug code.
5. Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to execute the linked plan.
6. Use `superpowers:verification-before-completion`.
7. Use `superpowers:finishing-a-development-branch`, with PR as the normal finish path.
8. Review, merge, close the issue, complete the native goal, sync the default branch, delete the issue branch, and run cleanup.

### Orchestrated Worker Execution

Orchestrated worker mode keeps the current thread as manager and reviewer. The worker thread owns implementation.

The main thread must:

1. Keep the native goal active in the main thread.
2. Create a worker handoff containing the issue mirror, source plan, goal objective, branch name, proof oracle, TDD policy, verification commands, and PR closeout expectations.
3. Open a new Codex worktree thread when native thread tools are callable.
4. Instruct the worker to use `superpowers:using-git-worktrees`, `superpowers:test-driven-development`, `superpowers:executing-plans` or `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`.
5. Require the worker to push its branch and open a PR that closes the exact GitHub issue.
6. Review the PR from the main thread.
7. Handle review feedback, CI, merge, issue closure, goal completion, default-branch sync, branch cleanup, and cleanup proof from the main thread.

If native thread tools are absent, the resolver should stop after producing the complete worker handoff and ask the user to open the worker thread manually. It should not silently downgrade the run into inline execution.

### Dynamic Workflows And Parallel Agents

If the linked source plan contains independent tasks, the resolver should create a small orchestration map before implementation:

```markdown
## Work Packets

- Packet A: <scope>, files, proof command
- Packet B: <scope>, files, proof command

## Integration Owner

Main thread orchestrator reviews and integrates worker output through PR.
```

The resolver may use:

- `codex-dynamic-workflows` to design the orchestration map;
- `superpowers:dispatching-parallel-agents` when packets can run independently;
- `superpowers:subagent-driven-development` for task-by-task worker execution.

Parallelism is optional. TDD and verification are not optional for feature or bug code.

### Issue Mirror Workflow Fields

`create-issues` should include workflow metadata in new issue mirrors:

```markdown
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only
```

These fields guide the resolver and make GitHub issue mirrors readable. Missing fields should be advisory during migration. Malformed values should be reported clearly because they create ambiguous execution instructions.

### Script Gate Policy

Bash scripts remain valuable, but their job is proof and safety.

Scripts should block:

- issue mirror outside `docs/superpowers/issues`;
- missing linked source plan under `docs/superpowers/plans`;
- missing GitHub issue for execution;
- missing acceptance criteria, proof oracle, or AFK/HITL classification;
- missing or fake native goal proof;
- GoalBuddy board fields or `docs/goals` in the default resolver path;
- unsafe branch cleanup targets;
- PR evidence that does not close the exact linked issue;
- closeout without merged PR, closed issue, completed native goal, branch cleanup proof, and cleanup hook proof.

Scripts should report advisory checks for:

- missing workflow metadata during migration;
- choice between inline and worker mode;
- number of agents;
- exact packet boundaries;
- whether a PR is draft or ready before final review.

## Success Criteria

- `resolve-issue` asks the inline-versus-worker question in normal runs when `request_user_input` is callable.
- The setup ledger records the execution decision source, selected mode, recommendation, and options.
- Orchestrated mode keeps main-thread ownership of review, merge, issue close, goal complete, and cleanup.
- Worker handoff includes all context needed to resolve the issue without reading this conversation.
- Issue mirrors include the new workflow fields.
- Existing dummy repo validation proves both inline and orchestrated setup ledger shapes.
- No default workflow creates GoalBuddy board files.
- Full repo validation and sync-live validation pass after implementation.

## Open Decisions Resolved

- `resolve-issue` must ask whether to solve inline or open a worker worktree thread.
- Main thread is the orchestrator, manager, reviewer, merge owner, issue close owner, and goal completion owner.
- Native Codex worktree/thread support is preferred for worker execution.
- TDD is required for feature and bug implementation.
- PR is the default development branch finish path.
- Bash scripts should enforce safety and proof, not every workflow style choice.

