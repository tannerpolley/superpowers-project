---
name: resolve-issue-with-goal
description: Use when one ready or externally sourced GitHub issue must be localized if needed, then resolved through GoalBuddy execution, tests, PR, merge, issue closure, and cleanup.
---

# Resolve Issue With Goal

This skill owns execution only. It starts from one ready GitHub issue, or from one externally sourced GitHub issue that must first be localized into the target repo, and ends with a merged PR, closed issue, synced default branch, deleted goal branch, deleted local GoalBuddy board, and cleanup proof.

If the issue is externally sourced, do not send the user back to `$convert-idea-to-issue` by default. Localize it in this skill before goal setup: create the target repo's durable local issue file, update the issue to the normal execution-ready marker, commit and push that issue-file sync on the default branch, then continue to preflight and branch creation.

If the issue is neither execution-ready nor externally sourced, block and tell the user to run `$convert-idea-to-issue` first.

Branch policy is chosen at execution setup time, not during issue planning. If the ready issue marker does not include `branch_policy`, `prepare-execution.ps1 -Mode Inspect` defaults to `create` unless the user or environment explicitly supplies `RIWG_BRANCH_POLICY` / `-BranchPolicy`.

## Hard Failures

Stop immediately when any of these are true:

- No single GitHub issue is named.
- The named issue URL's repository does not match the explicit target `-RepoRoot` remote.
- Any PR URL, verification ledger PR URL, or completion ledger PR URL does not belong to the same GitHub repo as the linked issue and `-RepoRoot` remote.
- The issue is closed, ambiguous, missing acceptance criteria, or not one execution scope.
- The issue is not externally sourced and is missing non-goals, proof oracle, a linked durable local issue file, or the normal readiness marker.
- An externally sourced issue is localized without creating a durable target-repo local issue file, updating the issue with the generated readiness marker, committing and pushing the issue-file sync on the target repo default branch, or acknowledging the external source in the local issue file.
- The issue and local issue file disagree on scope, non-goals, proof oracle, milestone, or acceptance criteria.
- GitHub milestones exist and the issue has no milestone, the wrong milestone, no existing full roadmap, or roadmap/milestone drift.
- Matt Pocock setup markers or `docs/agents/issue-tracker.md` do not prove GitHub Issues for the active remote.
- Any bundled gate script returns `ok: false`.
- The fast setup path is used without either the hidden `$resolve-issue-with-goal` readiness marker or the hidden `$convert-idea-to-issue` external-source marker.
- An externally sourced issue creates an implementation branch, GoalBuddy board, native goal, PR, or code edit before the local issue file is committed and pushed on the target repo default branch.
- `ApplySetup` runs before successful `preflight.ps1` proof exists.
- Unrelated dirty changes exist.
- A goal branch is created from anything other than the synced remote default branch when `branch_policy` is `create`.
- Code edits, non-preflight tests, PR operations, or implementation claims occur before setup, GoalBuddy validation, native goal activation, and `validate-setup.ps1` pass.
- New `docs/goals/<slug>/` or generated `.goalbuddy-board/` files are staged or committed.
- GoalBuddy Scout or Judge edits files, a Worker edits outside `allowed_files`, or any subagent updates git, GitHub, ledgers, roadmap gates, issue criteria, merge state, or cleanup state.
- A PR lacks a GitHub closing keyword for the exact linked issue.
- PR changed files are not covered by the verification ledger or explicit generated-file exemptions.
- Required checks are missing, pending, failed, cancelled, unknown, or absent while `required_checks_policy` is `require-existing`.
- GitHub reports mergeability as missing, null, unknown, or not `MERGEABLE`.
- The PR is draft, has requested changes, has unresolved non-outdated actionable review threads, or review-thread proof is incomplete.
- The linked issue is already closed before merge.
- Issue acceptance criteria or plan gates are not physically checked/updated before merge.
- The PR is not squash-merged, the exact issue is not closed, the default branch is not synced, the goal-owned branch remains, unrelated branches were deleted, the local board remains, or the cleanup hook result is missing.

## Blocked Response

When blocked by this skill, respond only:

```text
Blocked by skill contract: <reason>
```

Use this exact shape for non-external readiness failures too:

```text
Blocked by skill contract: run $convert-idea-to-issue first: <reason>
```

Do not use that response for externally sourced issues that include the external-source marker. Those must enter the localization phase instead.

## Script Resolution Contract

All `scripts\...` paths in this skill refer to bundled scripts in this skill package:

```text
C:\Users\Tanner\.agents\skills\resolve-issue-with-goal\scripts\
```

Run bundled scripts from the target repository root with `-RepoRoot <target-repo-root>`, or from any working directory with an explicit absolute `-RepoRoot`.

The current workspace may be unrelated to the issue's repository. The issue URL repo and -RepoRoot origin must match. Full issue URLs are authoritative; scripts must reject `https://github.com/owner-a/repo-a/issues/N` when `-RepoRoot` resolves to `owner-b/repo-b`.

Target repositories must not be required to contain `scripts\repo-gate.ps1`, `scripts\prepare-execution.ps1`, `scripts\preflight.ps1`, `scripts\validate-setup.ps1`, `scripts\premerge.ps1`, `scripts\closeout.ps1`, or any other script from this skill. Missing repo-local copies are not a blocker. If a bundled skill script itself is missing, block with:

```text
Blocked by skill contract: bundled resolve-issue-with-goal script missing: <script-name>
```

## State Machine

Follow this order exactly:

1. `repo_gate`: run the bundled `scripts\repo-gate.ps1 -RepoRoot <target-repo-root>`.
2. `issue_readiness_or_localization`: run the bundled `scripts\prepare-execution.ps1 -Mode Inspect -RepoRoot <target-repo-root>` to parse either the normal readiness marker or the external-source marker. For external-source issues, this creates the local durable issue file and emits the generated readiness marker plus issue-update evidence. For local markers missing milestone roadmap fields, this infers the roadmap/section from the target repo and emits marker-repair evidence.
3. `issue_marker_sync`: when `Inspect` reports `external_issue_localization` or `readiness_marker_repair`, stay on the target repo synced default branch, update the GitHub issue body/comment with the generated readiness marker and synced local issue-file path, commit and push only issue-file changes when a local issue file was created, and confirm the default branch is clean and equals `origin/<default>`.
4. `preflight`: run the bundled `scripts\preflight.ps1` with the generated handoff and explicit `-RepoRoot <target-repo-root>`. No implementation branch or GoalBuddy setup before it passes.
5. `setup`: run the bundled `scripts\prepare-execution.ps1 -Mode ApplySetup -RepoRoot <target-repo-root>` with successful preflight proof to create/confirm the branch, `.gitignore`, stale tracked goal cleanup, local-only GoalBuddy board, native-goal objective text, and setup-ledger draft.
6. `native_goal`: call `get_goal`, then `create_goal`, then `get_goal`; capture structured proof.
7. `setup_ledger`: run the bundled `scripts\prepare-execution.ps1 -Mode FinalizeSetup -RepoRoot <target-repo-root>` with native goal proof.
8. `setup_gate`: run the bundled `scripts\validate-setup.ps1 -RepoRoot <target-repo-root>`. No implementation before it passes.
9. `implementation`: execute GoalBuddy PM/Scout/Judge/Worker tasks and maintain verification receipts.
10. `premerge`: run the bundled `scripts\premerge.ps1 -RepoRoot <target-repo-root>`. No merge before it passes.
11. `merge`: squash-merge the approved PR.
12. `closeout`: sync default branch, delete only the goal-owned branch, delete local board files, run cleanup hook, then run the bundled `scripts\closeout.ps1 -RepoRoot <target-repo-root>`.

## External Issue Localization

Externally sourced issues are valid inputs when they include the hidden `$convert-idea-to-issue` external-source marker or an execution readiness marker with `issue_source_policy: external-github-only`.

Localization is not implementation. It may only:

- create or reuse one durable local issue file in the target repo, normally `docs/milestones/<milestone-folder>/issues/<slug>.md` when milestones are enabled or `docs/issues/<slug>.md` when milestones are disabled;
- update the GitHub issue with the generated `$resolve-issue-with-goal` readiness marker, synced local issue-file path, and external-source acknowledgement;
- commit and push the plan-file sync on the target repo default branch.

Localization must not create the implementation branch, edit product code, run implementation tests, create GoalBuddy board files, start a native goal, open a PR, or merge. After localization, preflight must run from a clean synced default branch exactly as normal.

If localization cannot infer a narrow `candidate_allowed_files` list from the issue body, it may use a broad initial candidate list only to let Scout/Judge narrow the first Worker slice. The Worker still may not edit outside the final task's `allowed_files`.

## Mandatory Handoff

Build this handoff from the ready issue and linked local issue file. Keep it out of tracked files; pass it to scripts with `-HandoffJson` or a temp file outside the repo.

```json resolve_issue_with_goal_handoff
{
  "slug": "<kebab-case-slug>",
  "target_repo": "<owner/repo parsed from issue_url and matching -RepoRoot origin>",
  "issue_url": "https://github.com/<owner>/<repo>/issues/<n>",
  "outcome": "<what must be true when the issue is closed>",
  "branch_policy": "create|reuse-current",
  "branch": "codex/<slug>",
  "full_roadmap": "<path or none>",
  "milestone_policy": "hard|none",
  "milestone_title": "<existing GitHub milestone title or none>",
  "full_roadmap_milestone_section": "<full roadmap section heading or none>",
  "project_policy": "dashboard-only",
  "plan_file": "docs/milestones/<milestone-folder>/issues/<slug>.md, docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md, or docs/issues/<slug>.md",
  "goal_board": "docs/goals/<slug>",
  "proof_oracle": ["<commands/checks/review state/artifacts>"],
  "non_goals": ["<explicit non-goals>"],
  "candidate_allowed_files": ["<repo-relative paths or globs for the first Worker slice>"],
  "merge_policy": "ready PR, closing keyword for exact issue, checks passing, MERGEABLE, no requested changes, no unresolved non-outdated actionable review threads, squash merge",
  "required_checks_policy": "require-existing|allow-none-with-local-proof",
  "allowed_existing_dirty_paths": [],
  "issue_readiness": {
    "source": "gh issue view plus linked local issue file, or external issue localization",
    "state": "OPEN",
    "single_execution_scope": true,
    "acceptance_criteria_present": true,
    "linked_plan_file_exists": true,
    "issue_plan_alignment": true
  }
}
```

New handoffs must use `plan_file`.

## Mandatory Evidence Ledgers

Maintain the setup ledger before implementation:

```json
{
  "issue_url": "https://github.com/<owner>/<repo>/issues/<n>",
  "branch": "codex/<slug>",
  "slice_roadmap_path": "docs/milestones/<milestone-folder>/issues/<slug>.md, docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md, or docs/issues/<slug>.md",
  "goal_board_path": "docs/goals/<slug>",
  "goal_activation_proof": {
    "source": "get_goal",
    "active": true,
    "objective": "<active objective>",
    "objective_refs": {
      "issue_url": "https://github.com/<owner>/<repo>/issues/<n>",
      "branch": "codex/<slug>",
      "plan_file": "docs/issues/<slug>.md",
      "goal_board": "docs/goals/<slug>",
      "proof_oracle": true,
      "closeout_required": true
    }
  },
  "proof_oracle": ["<commands/checks/review state/artifacts>"],
  "branch_inventory_before": {
    "local": ["<branches from preflight>"],
    "remote": ["<origin branches from preflight>"]
  }
}
```

Maintain the verification ledger before PR creation and premerge:

```json
{
  "pr_url": "https://github.com/<owner>/<repo>/pull/<n>",
  "proof_commands": [
    {
      "command": "<exact command>",
      "exit_code": 0,
      "output_receipt": "<concise proof output>",
      "source_label": "<local proof label>"
    }
  ],
  "changed_files_covered": ["<repo-relative paths>"],
  "verification_exemptions": ["<repo-relative generated files, only when justified>"],
  "issue_criteria_synced": true,
  "slice_roadmap_gates_synced": true
}
```

Maintain the completion ledger before any success-style final response:

```json
{
  "pr_url": "https://github.com/<owner>/<repo>/pull/<n>",
  "issue_url": "https://github.com/<owner>/<repo>/issues/<n>",
  "merge_confirmation": {
    "source": "gh pr view",
    "state": "MERGED",
    "merged_at": "<timestamp>"
  },
  "linked_issue_closed_confirmation": {
    "source": "gh issue view",
    "state": "CLOSED"
  },
  "branch_cleanup_confirmation": {
    "deleted_local": true,
    "deleted_remote": true,
    "only_goal_owned_removed": true,
    "local_delete_target": "codex/<slug>",
    "remote_delete_target": "codex/<slug>",
    "remote_deleted_branches": ["codex/<slug>"]
  },
  "goal_board_deletion_confirmation": {
    "path": "docs/goals/<slug>",
    "deleted": true
  },
  "cleanup_hook_result": {
    "command": "codex-cleanup",
    "exit_code": 0,
    "output": "<cleanup output>"
  }
}
```

Plain strings do not count as native goal, verification, or completion proof.

## Mandatory Native Goal Activation

If native goal tools are available, their use is mandatory:

- Call `get_goal` before native goal setup. If an unrelated active goal exists, block.
- Call `create_goal` after branch, issue, local issue file, GoalBuddy board, proof oracle, and branch inventory exist.
- Call `get_goal` again and record structured proof with `objective_refs`.
- Do not treat a plain-text claim that `/goal` was started as compliant execution.

If native goal tools cannot be called, print the exact `/goal` command and stop. Do not continue implementation in the same turn.

## Scripted Gates

Run scripts from this skill folder:

```powershell
$skillRoot = "C:\Users\Tanner\.agents\skills\resolve-issue-with-goal"
```

Required gates:

- Bundled `scripts\repo-gate.ps1`: validates GitHub remote, `gh` auth, Matt Pocock setup, issue tracker match, repo identity, and reports milestones/projects.
- Bundled `scripts\prepare-execution.ps1`: deterministic fast path with `Inspect`, `ApplySetup`, and `FinalizeSetup` modes. It reads hidden issue markers, localizes externally sourced issues into a durable local issue file before goal setup, emits handoff JSON, creates the local GoalBuddy board from bundled templates after preflight proof, prints the exact native goal objective, and finalizes the setup ledger only after structured native goal proof is supplied.
- `Inspect` may repair a local milestone-backed readiness marker that is missing or has an invalid `full_roadmap` or `full_roadmap_milestone_section` only when the target repo can infer those values from an existing full roadmap/milestone context. This includes markers that incorrectly point `full_roadmap_milestone_section` at the selected milestone heading instead of the containing milestone taxonomy section. The agent must update the GitHub issue marker with the emitted repaired marker before proceeding.
- Bundled `scripts\preflight.ps1`: validates handoff JSON, branch policy, branch inventory, synced default-branch start, dirty-worktree rules, stale tracked goal docs, selected milestone existence, and full-roadmap milestone taxonomy alignment.
- Bundled `scripts\validate-setup.ps1`: validates setup ledger, linked issue milestone assignment, GoalBuddy `state.yaml`, GoalBuddy delegation contract, `.gitignore`, local-only board policy, stale tracked goal deletion, and staged board failures.
- Bundled `scripts\premerge.ps1`: validates exact PR/issue linkage, exact closing keyword, required checks, mergeability, requested changes, review threads, open issue checkboxes, issue milestone, full-roadmap milestone drift, plan gates, clean git state, PR changed-file coverage, and verification ledger.
- Bundled `scripts\closeout.ps1`: validates PR merged, linked issue closed, final issue milestone, full-roadmap milestone drift, default branch synced, only goal-owned local branch removed, goal-owned remote branch gone, local board deleted, no residue, and structured cleanup proof.

Every script emits JSON with `ok`, `phase`, `reason`, and `evidence`. If `ok` is false, block with the script `reason`.

Test-only switches may be used only when `RIWG_TEST_MODE=1`.

Fast CLI environment variables:

- `RIWG_ISSUE`: issue number or URL for `prepare-execution.ps1 -Mode Inspect`.
- `RIWG_BRANCH_POLICY`: optional `create` or `reuse-current` override.
- `RIWG_SLUG`: optional slug override, still validated against the local issue-file path.
- `RIWG_OUTPUT_DIR`: optional output directory for generated handoff/ledger files; it must be outside the repo.

## GoalBuddy Execution Rules

GoalBuddy is the execution controller, not a decorative board.

- The main agent is the PM/controller.
- Only the PM/controller may update ledgers, issue acceptance criteria, plan gates, GoalBuddy `state.yaml`, git state, GitHub issues/PRs, merge state, or cleanup state.
- Scout and Judge tasks are read-only and return receipts.
- Worker tasks may edit only assigned `allowed_files` and must include `allowed_files`, `verify`, and `stop_if`.
- At most one write-capable Worker may be active unless the user explicitly requested parallel work and `state.yaml` proves disjoint write scopes.
- Subagents may not run branch, commit, push, PR, issue, merge, or cleanup commands.
- When spawning GoalBuddy subagents is available, render the active task prompt and use the required `goal_scout`, `goal_worker`, or `goal_judge` agent type.

## Superpowers And GitHub Specialist Routing

Use Superpowers for engineering discipline inside this GitHub/GoalBuddy lifecycle. Milestones owns the issue/branch/PR/merge/cleanup contract; Superpowers owns the development method.

- Start execution by checking `superpowers:using-superpowers` when it is available.
- Use `superpowers:executing-plans` only when the issue already has a written local issue-file implementation plan.
- Use `superpowers:test-driven-development` for feature or bug implementation unless the issue proof oracle explicitly records a different verification method and the PM/controller records why TDD is not applicable.
- Use `diagnose` and `superpowers:systematic-debugging` before fixes for bugs, regressions, failing tests, CI failures, performance work, or unclear failure modes.
- Use `superpowers:subagent-driven-development` only after GoalBuddy setup passes and only through GoalBuddy Worker scopes with explicit `allowed_files`, `verify`, and `stop_if`.
- Use `github:gh-fix-ci` when PR checks fail.
- Use `github:gh-address-comments` and `superpowers:receiving-code-review` when requested changes or actionable review threads exist.
- Use `superpowers:requesting-code-review` before merge when the change is non-trivial or the issue/PR policy asks for review.
- Use `superpowers:verification-before-completion` before any PR-ready, merge-ready, or complete claim.

These supporting skills do not replace the bundled gate scripts. If a supporting skill conflicts with a gate script, the gate script wins and the run blocks.

## Closeout Rules

Before success:

- preserve GoalBuddy receipts in the issue and PR;
- delete the local `docs/goals/<slug>/` board and generated `.goalbuddy-board/`;
- verify the exact linked issue is closed;
- sync local default branch to `origin/<default>`;
- delete only `codex/<slug>` locally and remotely;
- run the repo-scoped cleanup hook;
- fill the completion ledger;
- run `scripts\closeout.ps1`.

Do not send a success-style final response until closeout passes.

## Validation

Before reporting this skill package complete after edits:

- run `scripts\test-scenarios.ps1`;
- validate with explicit Python 3.12;
- verify no obsolete predecessor-skill references or old monolithic routing claims remain;
- verify `agents\openai.yaml` names `$resolve-issue-with-goal`;
- run the repo-scoped cleanup hook from the active repo root.
