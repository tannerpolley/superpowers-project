# Project Workflow Hardening Design

## Project Context Evidence

This design hardens the Superpowers Project extension after two real end-to-end runs:

- The `milestones-plugin` run that created issue #2, resolved it through `$project-resolve`, merged PR #3 through `$project-merge`, and used `$project-doctor` for post-merge drift repair.
- The ePC-SAFT run from session `019e772a-11be-7a92-a221-0f0e0ee13daa`, where the same workflow exposed contract friction around script parameters, manual ledgers, stale closed mirrors, skipped GitHub checks, ignored instruction files, and continuation prompts.

Current repo evidence:

- `docs/superpowers/PROJECT_CONTEXT.md` defines the extension as Superpowers plus durable project context, roadmap/milestone mapping, GitHub issues, native user-input grilling, and native `/goal` execution.
- `$project-plan` already has a native continuation gate after plan creation.
- `$project-resolve` owns native goal-backed issue implementation and PR-ready handoff.
- `$project-merge` owns merge approval, issue closure verification, branch/worktree cleanup, prune, cleanup hook, and clean repo proof.
- `$project-doctor` is report-first and can repair drift only after native approval.
- Validation already covers active skill names, retired artifact paths, issue mirror shape, scenario tests, plugin validation, and live sync.

## User Decisions

- Spec organization: one cohesive workflow-hardening spec.
- Native UI policy: keep native `request_user_input` questions as the standard, hard expectation, and requirement for material decisions and handoffs.
- Quick implementation path: add a guarded local-main path after `$project-plan` for small, low-risk changes.
- Closed issue mirror lifecycle: delete closed issue mirrors by default during `$project-merge` closeout after GitHub issue closure is verified, unless the mirror is explicitly marked as historically retained.

## Problem Statement

The concept is working: native questions make the workflow explicit, `$project-resolve` and `$project-merge` split implementation from integration cleanly, and the local/GitHub issue backbone gives agents enough structure to work autonomously.

The friction is in contract edges:

- Skill docs and script parameters can drift.
- PR-ready and merge closeout ledgers are too manual.
- Closed GitHub issues can leave stale local mirrors behind.
- GitHub check handling is not normalized consistently across polling and merge gates.
- Locally ignored paths can hide files that a structure task expects to track.
- Project Doctor can identify drift manually, but does not yet have a strong scripted audit.
- `$project-plan` always routes toward issues or vanilla Superpowers execution, even when the work is a small quick change that should be applied directly with focused verification.

## Recommended Approach

Harden the existing workflow instead of adding a new board, replacing Superpowers, or creating another project-management layer.

The design has seven parts:

1. Make native UI decision gates a project-wide hard contract.
2. Add skill-doc/script contract validation.
3. Generate ledgers from real repo and GitHub evidence.
4. Normalize GitHub check states once and reuse that logic.
5. Make closed issue mirror cleanup explicit.
6. Add ignored-path detection for tracked structure files.
7. Add a guarded quick implementation route after `$project-plan`.

## Native UI Decision Contract

Native UI questions should be mandatory whenever a project skill encounters a real choice, handoff, approval, routing decision, or assumption that affects outcome.

This should become a shared rule for all Superpowers Project skills, not only `$project-brainstorm`:

- Use `request_user_input` when callable.
- Ask one to three short questions per call.
- Put the recommended option first with `(Recommended)` in the label.
- Treat answers as executable routing, not advisory text.
- Start the selected next skill in the same turn when tools and state allow it.
- End every Superpowers Project skill with a native continuation question when `request_user_input` is callable.
- Every continuation question must include a stop/review option plus the relevant next workflow routes.
- The final response before or after a continuation gate must summarize the produced artifact or result so the user can review it in chat without opening the file.
- Use `debug_question_mode` only for explicit non-interactive smoke tests or proven stuck background-thread prompts with no answer tool.
- Never use debug mode as live user approval.

Mandatory native questions:

- brainstorming and planning decisions;
- issue granularity, AFK/HITL status, labels, and publication;
- resolve execution topology;
- quick implementation approval;
- merge approval;
- Project Doctor repair approval;
- continuation routing at the end of every project skill.

Continuation prompts should normally be shown even after an obvious terminal action. The user should be able to choose whether to continue, stop, review, revise, plan, create issues, resolve, merge, or run Doctor from the native UI. Merge approval must never be skipped.

Expected closeout gates:

- `$project-brainstorm`: summarize the saved spec, then ask whether to continue to `$project-plan`, review first, or revise the spec.
- `$project-plan`: summarize the saved plan, then ask whether to continue to `$project-issue`, Quick Apply, subagent execution, inline execution, review first, or revise the plan.
- `$project-issue`: summarize created or updated issues, then ask whether to resolve the first ready issue, resolve a selected issue, review first, or stop.
- `$project-resolve`: summarize PR-ready evidence, then ask whether to start `$project-merge`, resolve another issue, review first, or stop.
- `$project-merge`: summarize merge closeout evidence, then ask whether to run `$project-doctor`, resolve another issue, review first, or stop.
- `$project-doctor`: summarize findings and repair state, then ask whether to apply a repair plan, create a planning spec, run another audit, or stop.
- `$project-context`: summarize context changes, then ask whether to brainstorm, plan, create issues, run Doctor, review first, or stop.

## Skill Docs And Script Parameter Contract

Add a validation check that compares skill documentation against bundled script parameters.

The target failure from the ePC-SAFT run was: docs named `-IssueFile`, while the resolver script expected `-IssueMirror`. That kind of mismatch should fail in source validation before a user sees it.

Design requirements:

- Every PowerShell script exposed in a skill's `SKILL.md` must have documented parameter names that match the script's `param(...)` block.
- The check should detect removed, renamed, and undocumented required parameters.
- The check should allow optional implementation-only parameters when the script is not user-facing.
- Scenario tests should include at least one fixture that would catch `-IssueFile` vs `-IssueMirror` drift.
- `scripts/validate.ps1` should run this contract check.

This should be a loud validation failure, not a runtime warning.

## Evidence Ledger Generation

Structured ledgers are useful and should stay, but agents should not hand-author most of the JSON.

Add helper scripts that collect evidence from `gh`, local git state, validation outputs, and native goal results, then emit the exact ledger shape consumed by existing gates.

Resolver helpers should generate:

- setup ledger from issue mirror, source plan, branch policy, native goal proof, execution topology answer, proof oracle, and branch inventory;
- PR-ready ledger from pushed branch proof, PR URL, closing issue reference, acceptance coverage, verification commands, handoff proof, and native goal completion proof.

Merge helpers should generate:

- premerge evidence from `gh pr view`, `gh pr checks`, `gh issue view`, issue mirror body, changed files, and verification coverage;
- closeout ledger from PR merged state, issue closed state, default branch sync, branch deletion, worktree cleanup, prune result, cleanup hook result, clean repo proof, and resolve goal completion proof.

These helpers should be wrappers around the existing gate scripts. The gate scripts remain authoritative.

## GitHub Check State Normalization

Check status handling should be consistent everywhere.

Define one normalization policy:

- Passing required checks: `SUCCESS`, `PASS`, or completed success equivalents.
- Skipped optional checks: acceptable only when the check is explicitly optional or absent from the required-check set.
- Skipped required checks: blocked unless the repo policy explicitly treats that check as optional.
- Pending, cancelled, timed out, neutral without policy, failed, or missing required checks: blocked.

Polling scripts, premerge gates, and closeout evidence should call the same normalization helper or encode the same table in one shared script.

## Closed Issue Mirror Lifecycle

Issue mirrors are execution inputs, not permanent archives by default.

During `$project-merge` closeout:

- Verify the exact GitHub issue linked by the mirror is closed.
- Verify the PR that closed it is merged.
- Verify acceptance criteria are checked or captured in closeout proof.
- Delete the local mirror from `docs/superpowers/issues`.
- Update milestone pages or roadmap references that should retain durable project context.
- Do not delete mirrors marked with a historical-retention field.

Suggested retention field:

```markdown
**Mirror Retention:** Keep
```

If absent, closed mirror cleanup defaults to deletion.

`$project-doctor` should report:

- closed GitHub issues with live mirrors that should be deleted;
- deleted mirrors that are still listed in milestone pages as active issues;
- milestone pages that should retain a durable summary after mirror deletion.

## Local Ignore Trap Detection

Structure tasks that create tracked instruction files must check whether the target path is locally ignored.

Before creating or publishing files such as `AGENTS.md`, `docs/agents/*.md`, skill files, issue mirrors, or milestone pages:

- run an ignore check against the intended paths;
- include `.gitignore`, `.git/info/exclude`, and global excludes in the result;
- warn or block before assuming the file will be tracked;
- if the user approves tracking a locally ignored file, use an explicit force-add path during the later Git step.

This prevents silent local-only instruction files.

## Project Doctor Scripted Audit

`$project-doctor` should gain a scripted audit that emits structured findings grouped as blocking, repairable, informational, and healthy.

The audit should check:

- project context sections exist and match the current skill model;
- milestone pages match GitHub milestone titles and issue membership;
- issue mirrors match GitHub issue URL, state, milestone, labels, and body;
- closed issue mirrors obey the mirror lifecycle policy;
- specs, plans, issue mirrors, and milestone pages have expected links;
- label vocabulary matches GitHub labels;
- active skill docs use native UI language consistently;
- live plugin/user skills match source after sync validation;
- ignored-path traps exist for project-owned instruction files.

Doctor remains report-first. Repairs still require native UI approval.

## Quick Implementation Path After Project Plan

Add a fourth `$project-plan` continuation option:

- `Quick Apply`: apply the saved plan directly on local `main` for small, low-risk changes.

`Quick Apply` is for narrow changes where issue publication and PR ceremony add more overhead than value.

Guardrails:

- Must ask a native UI approval question before editing.
- Must start on `main`.
- `main` must be clean and synced with `origin/main`.
- The saved plan must have a focused proof oracle.
- The user-facing scope must be small and low risk.
- No native `/goal` is required by default.
- No GitHub issue is required by default.
- No merge approval is needed because no PR is created.
- After edits, run focused verification, `scripts/validate.ps1` when project skills or contracts changed, `scripts/sync-live.ps1 -Validate` when live skills are affected, and the cleanup hook.
- Ask before pushing `main` unless the user already requested push behavior.

Examples that fit:

- documentation alignment;
- skill wording updates;
- adding a validation scenario for a narrow contract;
- small helper-script fixes with targeted scenario coverage.

Examples that should route to `$project-issue` and `$project-resolve`:

- risky behavior changes;
- multi-module implementation;
- changes needing worker/orchestrator review;
- changes where acceptance criteria should be tracked on GitHub;
- changes that require a PR review boundary.

The quick path should not replace the GitHub issue backbone. It is an explicit escape hatch for small, well-scoped work after planning.

## Proposed Skill Changes

Update `$project-plan`:

- add `Quick Apply` to `project_plan_next_step`;
- add `Review First` and `Revise Plan` options to the continuation gate;
- require the closeout response to summarize the saved plan before the continuation question;
- document the quick-apply approval question;
- require clean synced `main` and focused verification;
- route non-small work back to `$project-issue`.

Update `$project-resolve`:

- use generated setup and PR-ready ledgers where possible;
- keep native goal proof mandatory for issue work;
- require PR-ready summary before the continuation question;
- add script-doc parameter drift coverage.

Update `$project-merge`:

- use generated premerge and closeout ledgers where possible;
- normalize GitHub checks consistently;
- delete closed issue mirrors by default after closeout;
- require merge closeout summary before the continuation question;
- update closeout proof to include mirror deletion or retention evidence.

Update `$project-doctor`:

- add scripted drift audit;
- report closed mirror lifecycle drift;
- report ignored-path traps;
- report milestone-to-GitHub issue membership drift.
- always end with a native continuation or repair question after summarizing findings.

Update `$project-brainstorm`:

- require the saved spec summary in chat after writing the file;
- ask a native continuation question with `Project Plan`, `Review First`, and `Revise Spec` options;
- route `Project Plan` directly into `$project-plan` in the same turn when tools and state allow it.

Update `$superpowers-project` router:

- route direct small post-plan work to `$project-plan` plus `Quick Apply`;
- keep issue-backed execution as default for non-trivial work;
- strengthen the project-wide native UI rule.

## Tradeoffs

One cohesive spec keeps the hardening work understandable because the failures all occurred at workflow boundaries. Splitting it now would create artificial dependencies between specs that would likely be implemented together anyway.

Deleting closed mirrors keeps `docs/superpowers/issues` clean and execution-focused. The tradeoff is that durable history must move into milestone pages, specs, plans, GitHub issues, and PRs. The `Mirror Retention` escape hatch covers rare cases.

Quick Apply reduces friction for small work but could weaken branch/PR discipline if it is too broad. The guardrails make it explicit, native-approved, local-main-only, and verification-driven.

Ledger helpers reduce manual JSON mistakes but should not hide the contract. They should print or save the generated ledger and then pass it into the existing validation scripts.

## Non-Goals

- Do not add GoalBuddy boards or `docs/goals`.
- Do not replace Superpowers planning, TDD, debugging, or verification skills.
- Do not remove `$project-issue`, `$project-resolve`, or `$project-merge`.
- Do not make Quick Apply the default for non-trivial implementation.
- Do not skip native merge approval.
- Do not keep stale closed issue mirrors by default.
- Do not make Project Doctor mutate tracker or docs without native repair approval.

## Milestone Linkage

Primary milestone:

- `M1 - Source Of Truth`: contracts, ledgers, live sync, mirror lifecycle, and drift prevention.

Secondary milestone:

- `M0 - Governance`: native UI policy, validation failures, and issue/merge lifecycle guardrails.

## Proof Oracle Candidates

Implementation planning should include proof for:

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate`
- focused scenario tests for `$project-plan`, `$project-resolve`, `$project-merge`, `$project-doctor`, and `$superpowers-project`
- a script-doc parameter drift fixture that fails on renamed parameters
- a ledger-generation fixture that creates setup, PR-ready, premerge, and closeout ledgers without hand-authored JSON
- a GitHub check normalization fixture covering success, pending, failed, skipped optional, and skipped required checks
- a closed-mirror lifecycle fixture proving closed mirrors are deleted unless retained
- an ignored-path fixture using `.git/info/exclude`
- a Quick Apply fixture proving clean synced main, native approval ledger, focused verification, cleanup hook, and optional push gating

## Open Questions For Planning

- Should Quick Apply get its own bundled script, or should it stay as `$project-plan` documented behavior plus validation tests?
- Should generated ledgers be saved under a temp path only, or copied into the final handoff evidence when useful?
- Should mirror deletion also remove GitHub issue links from milestone pages, or should milestone pages retain closed-issue summaries?
- Should check normalization live in a shared script library, or remain duplicated in resolve/merge script libraries until a broader script-common layer exists?

## Self-Review

- No placeholders remain.
- The spec keeps the existing architecture and does not introduce a new board or workflow layer.
- The native UI decision requirement is explicit and project-wide.
- The Quick Apply path is bounded and does not replace issue-backed work.
- Closed mirror deletion is explicit and has a retention escape hatch.
- Every review finding from the milestones-plugin and ePC-SAFT runs is represented.
