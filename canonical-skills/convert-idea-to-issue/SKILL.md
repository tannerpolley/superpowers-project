---
name: convert-idea-to-issue
description: Use when vague or broad GitHub-backed repo intent must be grilled against docs and turned into one scoped GitHub issue or an approved issue set with durable local issue files.
---

# Convert Idea To Issue

This skill owns issue design only. It turns messy intent into one ready GitHub issue or an explicitly approved issue set, with durable local issue files for local repo work. It does not create branches, GoalBuddy boards, code edits, PRs, merges, or cleanup runs.

For broad topics that need deep codebase scope auditing and many native UI questions without Plan mode, use `$explore-ideas` first. Prefer consuming the saved `docs/milestones/<milestone-folder>/ideas/<YYYY-MM-DD>-<slug>.md` idea brief and its hidden `explore_ideas_brief` handoff instead of asking the user to paste raw JSON. This skill should import that brief as evidence, then run its native `request_user_input` question gate in Default mode or Plan mode before publishing issue(s).

`docs/ideas/` is legacy only. For `local-main-sync`, do not use a top-level `docs/ideas/*.md` brief as the canonical source; first move or rewrite the brief under the owning milestone's `ideas/` folder through `$milestones-doctor` or an approved docs-only cleanup.

When converting an idea brief, the first-class job is canonical issue selection: decide exactly which part of the explored idea becomes the GitHub issue, which parts are excluded or deferred, and whether the selected slice is one issue or an approved issue set. Do not turn the whole idea brief into an issue by default.

Branch policy belongs to `$resolve-issue-with-goal`, not issue planning. `$convert-idea-to-issue` must not create a branch, select a branch, switch branches, push branches, or include `branch_policy` in the planning handoff or issue marker. The implementation branch is created only after an execution agent starts resolving the ready issue.

Issue creation has two source policies:

- `local-main-sync`: the agent is creating issue(s) for the repo it is allowed to edit. Stay on the synced default branch, normally `main`; create or update the durable local issue file(s) there; create/update the GitHub issue(s); make each issue explicitly say it is synced with its repo file; commit and push only the local issue-file/docs changes on the default branch. The issue publication is not finished until the commit and push are confirmed.
- `external-github-only`: the agent is creating issue(s) for another repo from an external context. Do not touch the target repo checkout, do not create or edit target repo files, do not commit, and do not include the execution readiness marker. Each issue must say `Externally sourced issue`, name the source context, and say a target-repo `$resolve-issue-with-goal` run must localize the issue into a repo-local issue file before GoalBuddy execution starts.

Issue count is a first-class planning decision. The skill must ask whether the work should become one issue or multiple issues, and when multiple issues are approved it must also ask whether those issues stay in one milestone or span multiple milestones. Do not default to one issue or one milestone.

`Implement Plan` under this skill means `publish-issue-and-plan-only`. It never means resolving the issue, changing product code, changing workflow behavior, creating an implementation branch, opening a PR, merging, creating a GoalBuddy board, or starting a native goal. If the user asks to implement code/workflows/tests while invoking this skill, block with:

```text
Blocked by skill contract: $convert-idea-to-issue can only publish the issue and plan. Use $resolve-issue-with-goal to resolve the created issue.
```

## Hard Failures

Stop immediately with the blocked response when any of these are true:

- Fresh repo intake or idea canonicalization proceeds without native `request_user_input` questions when the tool is available.
- The bundled `scripts\repo-gate.ps1 -RepoRoot <target-repo-root>` has not passed for repo work.
- Matt Pocock setup markers or `docs/agents/issue-tracker.md` do not prove GitHub Issues for the target repo remote.
- The target GitHub repo and local checkout are not explicit before repo-gate, issue creation, or local issue-file publication.
- The workflow uses the current working directory as the implicit GitHub issue target.
- `local-main-sync` issue creation is not performed from the target repo default branch, normally `main`.
- `local-main-sync` finishes before the local issue file is committed and pushed to the target repo default branch.
- `external-github-only` touches the target repo checkout, writes a target repo file, commits, pushes, or claims the issue is execution-ready.
- Repo work proceeds without `grill-with-docs`.
- Abstract non-repo strategy uses repo gates or GitHub issue creation.
- Architecture, refactor, package layout, module boundary, or testability planning omits `improve-codebase-architecture`.
- Bug, regression, failing test, CI failure, performance, or unclear failure-mode planning omits `diagnose`.
- Vague feature or design work omits `superpowers:brainstorming`.
- Large scope or cross-milestone scope is decomposed with `to-issues` before explicit user approval.
- The handoff omits the issue-count decision, uses multiple issues without `issue_count_policy: approved-issue-set`, or defaults to a single issue without a `request_user_input` answer.
- The handoff omits `canonical_issue_scope`, or that scope is not tied to a `request_user_input` answer.
- An approved issue set omits per-issue milestone assignment, per-issue local issue files, per-issue acceptance criteria, or a milestone/cross-milestone question.
- Any milestone-backed local issue or issue-set item has `milestone_policy: hard` without a non-`none` `full_roadmap` and `full_roadmap_milestone_section` in the handoff and hidden execution marker.
- The workflow attempts branch creation, GoalBuddy setup, code edits, PR operations, merge, or branch cleanup.
- `Implement Plan` is interpreted as resolving the issue instead of publishing the issue and plan only.
- The pre-publish mutation self-check includes any file, GitHub object, or command outside the mutation allowlist.
- The planning handoff, issue body, hidden marker, or local issue file contains `branch_policy`, `branch`, or instructions to create an implementation branch.
- GitHub milestones exist but no existing full roadmap and matching milestone section are identified.
- GitHub milestone title or description drifts from the selected full roadmap milestone taxonomy.
- The handoff is missing structured `skills_used` evidence.
- The handoff is missing structured `doc_grill_evidence`, `decision_log`, `question_log`, or `unresolved_decisions`.
- A final plan, proposed plan, issue body, or handoff is emitted while `unresolved_decisions` is non-empty.
- A material decision is resolved by agent default instead of either a `request_user_input` answer or a specific `no_question_needed_reason` proving the decision was discoverable from repo/docs.
- An interrupted or abandoned `request_user_input` turn is resumed by silently using the abandoned default instead of re-asking or recording the answered question.
- Any created/updated local-main-sync issue is missing its own hidden `$resolve-issue-with-goal` readiness marker.

## Blocked Response

When blocked by this skill, respond only:

```text
Blocked by skill contract: <reason>
```

## Script Resolution Contract

All `scripts\...` paths in this skill refer to bundled scripts in this skill package:

```text
C:\Users\Tanner\.agents\skills\convert-idea-to-issue\scripts\
```

Run bundled scripts from the target repository root with `-RepoRoot <target-repo-root>`, or from any working directory with an explicit absolute `-RepoRoot`.

The current workspace may be unrelated to the target repo. Always treat the explicit target repo as authoritative:

- `target_repo`: GitHub `owner/repo` slug where the issue will be created or updated.
- `target_repo_root`: local checkout used for docs, roadmap, local issue-file edits, and repo-gate.

When the user asks from repo A to create an issue for repo B, use repo B as `target_repo` and pass repo B's local checkout as `-RepoRoot`. Do not require or create skill scripts inside repo B.

Target repositories must not be required to contain `scripts\repo-gate.ps1`, `scripts\validate-handoff.ps1`, or any other script from this skill. Missing repo-local copies are not a blocker. If the bundled skill script itself is missing, block with:

```text
Blocked by skill contract: bundled convert-idea-to-issue script missing: <script-name>
```

## Mode Contract

Fresh intake may run in Default mode or Plan mode. Default mode is preferred when converting a saved `$explore-ideas` brief because it avoids the Plan-mode `Implement Plan` affordance while still using the native question UI.

Use `request_user_input` to ask as many material questions per call as the active UI/tool allows. Prefer batching independent questions together so the issue can converge quickly. Ask one question at a time only when the answer changes which follow-up questions are valid.

If `request_user_input` is unavailable during fresh intake, block instead of substituting plain-text questions. If a valid handoff already exists, validate it with the bundled validator before publishing.

In Default mode, after all material decisions are locked, ask a final native approval question before any mutation:

- `Publish issue and local file` means create/update the GitHub issue(s) and allowed durable local issue file(s) only.
- `Revise scope first` means continue native questioning.
- `Stop` means do not mutate anything.

In Plan mode, `Implement Plan` still means `publish-issue-and-plan-only`. A valid approved Plan-mode handoff may arrive after the user clicks `Implement Plan`, when the thread is back in Default mode. In that case, continue only with issue and local issue-file creation/update. Do not ask the user to re-enable Plan mode.

Before any mutation after approval, state the exact files and GitHub objects that will change. If that list includes anything outside the allowlist below, stop before changing anything.

Allowed mutations:

- repo-qualified GitHub issue create/update, labels, milestones, and dashboard/project evidence;
- create/update the durable local issue file(s) named by `plan_file` and `issue_set[].plan_file` for `local-main-sync`;
- optionally update one issue mirror file only when repo-local config explicitly declares that mirror;
- default-branch `git add`, `git commit`, and `git push` only for the local issue file(s) and optional declared mirror.

Forbidden mutations:

- `git switch`, `git checkout`, branch creation, or branch push;
- edits to implementation code, tests, workflows, package config, build scripts, or runtime docs unrelated to the single local issue file;
- implementation commits or pushes;
- PR creation, PR updates, or merge;
- GoalBuddy board creation or native goal activation;
- implementation test runs beyond validating the issue/plan handoff.

## Required Skill Routing

Use the smallest skill set that matches the planning problem, but record every required or conditional skill in `skills_used`.

- `grill-with-docs` is mandatory for repo work. It reads `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md`, and `docs/adr/*.md` for terminology, domain language, and architecture-decision alignment. It is not a roadmap or task tracker.
- `grill-me` is allowed only for abstract or non-repo strategy.
- `superpowers:brainstorming` is mandatory for vague feature, behavior, or design work.
- `improve-codebase-architecture` is mandatory for architecture, refactor, package-layout, module-boundary, or testability planning.
- `diagnose` is mandatory for bugs, regressions, failing tests, CI failures, performance problems, or unclear failure modes.
- `to-issues` is only used after the user explicitly approves decomposition into multiple issues. Approved issue sets may span multiple milestones when the user chooses that in Plan Mode.

## Decision And Question Gate

Before any final plan, proposed plan, handoff, or issue publication:

1. Build a decision inventory from repo inspection, tracker docs, `grill-with-docs`, roadmap/milestone state, and the user's request.
2. If an `$explore-ideas` brief is present, inventory its candidate issue slices and ask which exact slice or slices should become canonical GitHub issue scope.
3. Classify every decision as either `locked` by a `request_user_input` answer or `discoverable` from repo/docs.
4. Ask every non-discoverable material question with `request_user_input`. Batch independent questions in the same call up to the active UI/tool limit.
5. Always ask a native question for canonical issue scope unless the user already answered it in the same thread or the source issue/update URL makes the scope mechanically fixed.
6. Record every answer in `question_log` with `tool: request_user_input`.
7. Record every decision in `decision_log`. A decision may omit `question_id` only when it has a concrete `no_question_needed_reason`.
8. Keep `unresolved_decisions` non-empty until all material decisions are closed.

Material decisions include canonical issue scope from the idea brief, selected slice vs deferred slices, single issue vs multiple issues, selected milestone or cross-milestone assignment, policy choices, required vs advisory checks, trigger model for expensive lanes, acceptance criteria, proof oracle, non-goals, labels, project/dashboard treatment, and execution candidate files.

`canonical_issue_scope` must answer:

- source idea brief or source prompt;
- selected slice or selected issue set;
- included scope;
- excluded or deferred scope;
- why this is the canonical issue boundary;
- the `request_user_input` question that locked the decision.

The canonical issue question should be concrete, for example: "Which part of this idea brief should become the GitHub issue now?" Use the recommended option first.

`grill-with-docs` must produce `doc_grill_evidence`, not just a `skills_used` entry:

- `docs_read`: docs actually inspected, normally `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md`, and `docs/adr/*.md` when present.
- `constraints_found`: terminology, architecture decisions, tracker rules, roadmap or milestone constraints that shaped the issue.
- `contradictions_found`: mismatches or empty array if none were found.
- `questions_derived`: material questions that came from those docs.

## State Machine

1. `repo_gate`: for `local-main-sync`, run the bundled `scripts\repo-gate.ps1 -RepoRoot <target-repo-root> -ExpectedRemoteSlug <target_repo>` before the first native question. For `external-github-only`, inspect only through repo-qualified GitHub commands such as `gh repo view --repo <target_repo>` and do not require a target checkout.
2. `doc_grill`: use `grill-with-docs` and conditional skills to inspect docs and produce `doc_grill_evidence`.
3. `decision_inventory`: list material decisions and initialize `unresolved_decisions`. If a saved `$explore-ideas` brief or `explore_ideas_brief` handoff is provided, import its repo evidence, code-health audit, workflow connections, tool receipts, question log, candidate issue slices, and open questions into this inventory instead of redoing broad exploration.
4. `canonical_scope`: use `request_user_input` in Default mode or Plan mode to decide exactly which idea slice becomes the issue now and which slices are excluded or deferred.
5. `question_gate`: use `request_user_input` for every non-discoverable material decision, then update `decision_log`, `question_log`, and `unresolved_decisions`.
6. `scope`: ask whether this is one issue or an issue set. If issue set, ask whether it stays in one milestone or spans multiple milestones, then use `to-issues` only after explicit approval.
7. `handoff`: the issue-publication handoff must include `convert_idea_to_issue_handoff`.
8. `approval`: in Default mode, ask the final publish approval with `request_user_input`. In Plan mode, the user's `Implement Plan` approval is enough only for publish-issue-and-plan-only.
9. `publish_issue_file`: for `local-main-sync`, create or update the durable local issue file(s) on the synced default branch. For `external-github-only`, skip local issue-file writes and set each `plan_file` value to `external:none`.
10. `publish_issue`: after approval, create or update one GitHub issue for `single-issue` or each issue in `issue_set` for `approved-issue-set`. Use `--repo <target_repo>`.
11. `sync`: for `local-main-sync`, commit and push the local issue-file/docs change on the default branch and update the issue body or comment with the synced local issue-file path and commit. For `external-github-only`, add the external source marker and do not write or push repo files.
12. `finish`: report the issue URL(s). For `local-main-sync`, also report the local issue file path(s) and pushed commit. Tell execution agents to use `$resolve-issue-with-goal` issue-by-issue after the issues are ready or localized.

## Mandatory Handoff

The final issue-publication handoff must include this fenced JSON block:

```json convert_idea_to_issue_handoff
{
  "slug": "<kebab-case-slug>",
  "target_repo": "<owner/repo>",
  "target_repo_root": "<absolute local checkout path for local-main-sync, or external:none>",
  "source_repo": "<owner/repo creating the issue, or external:none>",
  "issue_source_policy": "local-main-sync|external-github-only",
  "title": "<GitHub issue title>",
  "outcome": "<what must be true when this issue is resolved>",
  "issue_policy": "create|update:<issue-url>",
  "milestone_policy": "hard|none",
  "milestone_title": "<existing GitHub milestone title or none>",
  "full_roadmap": "<path or none>",
  "full_roadmap_milestone_section": "<full roadmap section heading or none>",
  "project_policy": "dashboard-only",
  "plan_file": "docs/milestones/<milestone-folder>/issues/<slug>.md, docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md, docs/issues/<slug>.md, or external:none",
  "required_checks_policy": "require-existing|allow-none-with-local-proof",
  "labels": ["<label>"],
  "acceptance_criteria": ["<checked yes/no criterion>"],
  "non_goals": ["<explicit non-goal>"],
  "proof_oracle": ["<commands/checks/review state/artifacts>"],
  "candidate_allowed_files": ["<repo-relative paths or globs for local-main-sync; empty for external-github-only>"],
  "canonical_issue_scope": {
    "source": "docs/milestones/<milestone-folder>/ideas/<YYYY-MM-DD>-<slug>.md or user prompt",
    "selected_slice": "<exact idea slice or issue set selected for publication>",
    "included_scope": ["<what belongs in this issue>"],
    "excluded_scope": ["<what is deferred or intentionally not part of this issue>"],
    "canonical_reason": "<why this boundary is the right issue boundary>",
    "question_id": "<matching question_log id that selected the canonical scope>"
  },
  "issue_count_policy": "single-issue|approved-issue-set",
  "decomposition_policy": "single-issue|approved-decompose",
  "issue_set": [
    {
      "slug": "<per-issue slug>",
      "title": "<per-issue title>",
      "outcome": "<per-issue outcome>",
      "issue_policy": "create|update:<issue-url>",
      "milestone_policy": "hard|none",
      "milestone_title": "<per-issue milestone title or none>",
      "full_roadmap": "<path or none>",
      "full_roadmap_milestone_section": "<section heading or none>",
      "plan_file": "docs/milestones/<milestone-folder>/issues/<slug>.md, docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md, docs/issues/<slug>.md, or external:none",
      "required_checks_policy": "require-existing|allow-none-with-local-proof",
      "labels": ["<label>"],
      "acceptance_criteria": ["<checked yes/no criterion>"],
      "non_goals": ["<explicit non-goal>"],
      "proof_oracle": ["<commands/checks/review state/artifacts>"],
      "candidate_allowed_files": ["<repo-relative paths or globs for local-main-sync; empty for external-github-only>"]
    }
  ],
  "execution_boundary": {
    "skill_scope": "issue-and-plan-publication-only",
    "approval_meaning": "publish-issue-and-plan-only",
    "implementation_skill": "resolve-issue-with-goal",
    "allowed_after_approval": [
      "repo-qualified GitHub issue create/update",
      "durable local issue file writes",
      "default-branch commit/push for local issue docs only"
    ],
    "forbidden_after_approval": [
      "implementation branch creation",
      "implementation edits",
      "implementation commits",
      "implementation pushes",
      "PR creation",
      "merge",
      "GoalBuddy board",
      "native goal activation"
    ]
  },
  "doc_grill_evidence": {
    "docs_read": ["CONTEXT.md", "docs/adr/<id>.md"],
    "constraints_found": ["<doc-backed constraint that shaped the issue>"],
    "contradictions_found": ["<doc mismatch, or empty array if none>"],
    "questions_derived": ["<material question derived from docs>"]
  },
  "decision_log": [
    {
      "decision": "<material decision>",
      "status": "locked|discoverable",
      "source": "user|repo inspection|docs",
      "question_id": "<matching question_log id when status is locked by user answer>",
      "no_question_needed_reason": "<only when discoverable from repo/docs>"
    }
  ],
  "question_log": [
    {
      "id": "<stable-question-id>",
      "decision": "<material decision>",
      "tool": "request_user_input",
      "question": "<question asked>",
      "answer": "<user answer>",
      "source": "user"
    }
  ],
  "unresolved_decisions": [],
  "skills_used": [
    {
      "skill": "grill-with-docs",
      "why": "<why it was required>",
      "evidence": "<docs or decisions it shaped>"
    }
  ]
}
```

Do not include execution-owned fields such as `branch_policy`, `branch`, `goal_board`, `goal_activation_proof`, `verification_ledger`, `completion_ledger`, `pr_url`, or merge state.

For `single-issue`, omit `issue_set`; the top-level issue fields describe the one issue to publish.

For `approved-issue-set`, `issue_set` is mandatory and must contain at least two issues. Each item owns its own title, acceptance criteria, milestone, local issue file, hidden marker, labels, proof oracle, non-goals, and candidate files. A single approved issue set may span milestones, but only after the user explicitly approves that in `question_log`.

## Hidden Execution Marker

Every `local-main-sync` issue must include its own hidden HTML marker so `$resolve-issue-with-goal` can prepare the goal quickly without re-inferring readiness from prose. For `approved-issue-set`, render one marker per created issue using that issue's `issue_set[]` values:

```html
<!-- resolve-issue-with-goal
{
  "slug": "<kebab-case-slug>",
  "target_repo": "<owner/repo>",
  "issue_source_policy": "local-main-sync",
  "plan_file": "docs/milestones/<milestone-folder>/issues/<slug>.md, docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md, or docs/issues/<slug>.md",
  "milestone_policy": "hard|none",
  "milestone_title": "<existing GitHub milestone title or none>",
  "full_roadmap": "<path or none>",
  "full_roadmap_milestone_section": "<full roadmap section heading or none>",
  "proof_oracle": ["<commands/checks/review state/artifacts>"],
  "non_goals": ["<explicit non-goals>"],
  "candidate_allowed_files": ["<repo-relative paths or globs for the first Worker slice>"],
  "required_checks_policy": "require-existing|allow-none-with-local-proof"
}
-->
```

The marker must match the visible issue body and durable local issue file. Do not add `branch_policy`, `branch`, `goal_board`, native goal proof, PR state, or merge state to the marker.

Every `external-github-only` issue must instead include this marker and must not include the `$resolve-issue-with-goal` readiness marker:

```html
<!-- convert-idea-to-issue-external-source
{
  "target_repo": "<owner/repo>",
  "source_repo": "<owner/repo or external:none>",
  "issue_source_policy": "external-github-only",
  "local_plan_file": "external:none",
  "execution_ready": false
}
-->
```

The visible external issue body must include the phrase `Externally sourced issue`, explain the source context, and state that `$resolve-issue-with-goal` in the target repo will first create the synced local issue file before GoalBuddy execution can start.

## Issue Requirements

Every created or updated issue must contain:

- concise title;
- publication to the explicit `target_repo` using GitHub's repo-qualified issue operations, such as `gh issue create --repo <target_repo>` or `gh issue edit --repo <target_repo>`;
- problem statement and intended outcome;
- acceptance criteria as checkboxes;
- non-goals;
- proof oracle;
- hidden `$resolve-issue-with-goal` readiness marker;
- linked durable local issue file;
- milestone assignment when milestones exist;
- labels from the repo's triage vocabulary;
- project/dashboard evidence only when available and useful.

Use a GitHub closing-compatible issue body and labels, but do not create a PR. GitHub Projects remain dashboards unless repo-local config explicitly makes them mandatory.

For `local-main-sync`, every issue must also say:

- `Synced local issue file: <plan_file>`;
- `Synced commit: <commit-sha>`;
- the local issue file is committed and pushed on the target repo default branch.

For `external-github-only`, every issue must instead say:

- `Externally sourced issue`;
- `No local issue file was written by the source agent`;
- `Execution readiness requires target-repo localization by $resolve-issue-with-goal before GoalBuddy starts`.

## Roadmap, Milestone, And Issue-File Rules

Full roadmaps are never auto-created. If GitHub milestones exist, select an existing full roadmap and matching milestone section(s) before issue creation. The `full_roadmap_milestone_section` value must name the roadmap section that contains the milestone headings, such as `Required milestones`; it must not name the selected milestone heading itself, such as `M3 - EOS`. The selected full roadmap is the durable meaning source; GitHub milestone title and description must mirror it after whitespace normalization.

For `local-main-sync`, each `plan_file` field points to the detailed local issue file for its GitHub issue. This field name is retained for `$resolve-issue-with-goal` compatibility, but the file itself must live under `docs/milestones/<milestone-folder>/issues/` when milestones are enabled, or under `docs/issues/` when milestones are disabled. Do not create `docs/plans/`, `docs/milestones/<milestone-folder>/plans/`, or issue-level files under `docs/roadmaps/`.

Each local issue file must live under `target_repo_root`, be committed and pushed on the default branch, and agree with its GitHub issue on scope, acceptance criteria, non-goals, proof oracle, selected milestone, and labels. If the GitHub issue number is known before writing the file, prefer `docs/milestones/<milestone-folder>/issues/<issue-number>-<slug>.md`; otherwise use `docs/milestones/<milestone-folder>/issues/<slug>.md` and update or rename it only when doing so is part of the approved publication mutation list.

For `approved-issue-set`, the set may span multiple milestones. The plan must show why each issue belongs to its selected milestone, and the issue body must mirror that milestone assignment. Do not collapse a cross-milestone effort into one issue unless the user explicitly chooses one issue after being asked.

When `milestone_policy` is `hard`, the handoff, issue body, local issue file, and hidden execution marker must all carry the selected `full_roadmap` and `full_roadmap_milestone_section`. Publishing a milestone-backed issue with `full_roadmap: none` is forbidden because `$resolve-issue-with-goal` cannot validate roadmap/milestone sync from that marker.

For `external-github-only`, do not create or claim a target repo local issue file. The external issue is a request for the target repo to perform local issue-file sync.

## Handoff To Execution

For `local-main-sync`, when publishing is complete, stop after reporting issue URL(s), local issue file path(s), and pushed commit. The final response must include:

```text
Use $resolve-issue-with-goal to resolve <issue-url> one issue at a time.
```

For `external-github-only`, do not hand off directly to execution. The final response must say:

```text
This is an externally sourced issue. A target-repo $resolve-issue-with-goal run must first localize it into a synced local issue file before GoalBuddy execution starts.
```

Do not run the execution skill from this skill.

## Validation

Before reporting this skill package complete after edits:

- run `scripts\test-scenarios.ps1`;
- validate with the explicit Python 3.12 skill validator;
- verify no branch, GoalBuddy, PR, merge, or closeout scripts are bundled in this skill;
- run the repo-scoped cleanup hook from the active repo root.
