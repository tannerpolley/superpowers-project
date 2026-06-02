---
name: explore-ideas
description: Use in Default mode when a repo idea, feature area, workflow, architecture concern, code-health concern, roadmap area, or broad question needs meticulous codebase scope auditing and native request_user_input grilling without Plan mode or an Implement Plan step.
---

# Explore Ideas

This skill owns exploration, codebase auditing, workflow mapping, and interrogation only. It helps the user think deeply before issue planning by inspecting the repo thoroughly and asking many native UI questions with `request_user_input` in Default mode.

It is deliberately self-contained. Do not depend on a nested `grill-with-docs` invocation to do the core work. Instead, apply the docs-grilling behavior directly: inspect the repo's context docs, ADRs, roadmap and milestone language, code, tests, workflows, issues, and project-management signals; challenge fuzzy terminology; surface code/docs contradictions; and turn the result into a durable idea brief.

It must not create GitHub issues, create branches, start GoalBuddy, open PRs, merge, or implement code. It must not produce a Plan-mode implementation plan.

## Mode Contract

Run this skill in Default mode.

- If the thread is in Plan mode, stop and ask the user to switch to Default mode before continuing. This skill intentionally avoids the Plan-mode `Implement Plan` affordance.
- Native question UI is mandatory. If `request_user_input` is available in Default mode, use it for the grilling loop.
- Ask up to the active UI/tool limit of independent questions per `request_user_input` call. Prefer batching independent questions so the user can answer many decisions quickly.
- Ask sequentially only when one answer changes which follow-up questions are valid.
- Continue asking until the material decision inventory is exhausted or the user explicitly pauses.
- Do not end after only one or two broad questions unless the topic is genuinely tiny and the decision inventory is empty.

When `request_user_input` is not available, stop with the blocked response. Do not fake native UI usage with plain-text questions.

## Hard Failures

Stop immediately when any of these are true:

- The skill is invoked in Plan mode.
- The agent tries to create a GitHub issue, implementation branch, PR, GoalBuddy board, native goal, or merge.
- The agent edits implementation code, tests, workflows, package config, or runtime behavior.
- The agent writes a tracked brief or repo doc without explicit user approval.
- The agent skips repo/docs exploration for a repo topic that can be inspected locally.
- The agent emits a final issue plan or says the issue is ready without first asking the material questions.
- The agent uses only narrative questions when `request_user_input` is available.
- `request_user_input` is unavailable, because this skill requires native question UI.
- The agent omits the inlined docs-grilling pass for repo work.
- The agent fails to audit code health, current features, workflows, docs, and their connections when those repo surfaces are relevant to the topic.
- The agent writes a new idea brief under legacy `docs/ideas/` instead of `docs/milestones/<milestone-folder>/ideas/`.
- The agent writes a repo idea brief before the owning milestone or approved cross-cutting milestone folder is selected.
- The agent dumps the full machine JSON handoff into the final chat response when a file artifact exists or the user did not explicitly ask to see it.

Use this blocked response:

```text
Blocked by explore-ideas contract: <reason>
```

## Inlined Docs Grilling And Skill Routing

This skill must perform its own docs-aware grilling pass for repo work. Treat `grill-with-docs` as source behavior to inline, not as a dependency to outsource the session.

- Read `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md`, and `docs/adr/*.md` when present.
- Use context docs for glossary, domain language, architecture decisions, and terminology consistency. They are not task trackers.
- Challenge terms that conflict with the glossary or local architecture language.
- Sharpen vague words into candidate canonical terms and ask the user to confirm them with `request_user_input` when the answer is not discoverable.
- Stress-test ideas with concrete scenarios and edge cases.
- Cross-check user claims against code, tests, workflows, docs, issues, milestones, and roadmap files. Surface contradictions instead of smoothing them over.
- Recommend CONTEXT or ADR updates only in the idea brief unless the user explicitly asks this skill to update those docs.
- Offer ADRs sparingly: only for decisions that are hard to reverse, surprising without context, and the result of a real tradeoff.

Use the smallest supporting skill set and record it in the brief:

- Record the inlined docs-grilling pass as `inlined-docs-grilling`, not as proof that a nested skill was invoked.
- Use `grill-me` only for abstract/non-repo strategy.
- Use `diagnose` for bugs, regressions, failing tests, CI failures, performance problems, or unclear failure modes.
- Use `improve-codebase-architecture` for architecture, refactor, package layout, module-boundary, or testability concerns.
- Adopt `superpowers:brainstorming` patterns for vague feature, behavior, UX, or product design topics: explore project context first, detect oversized scope, propose 2-3 approaches with tradeoffs, recommend one, and self-review the resulting brief for placeholders, contradictions, ambiguity, and scope creep.
- Do not use `to-issues` here unless the user explicitly asks for a decomposition sketch. Even then, do not publish issues.

## Exploration Workflow

1. Resolve the target repo and topic. If the repo is unclear and cannot be inferred safely, ask with `request_user_input`.
2. Inspect repo facts before questioning when possible:
   - `AGENTS.md` / `CLAUDE.md`;
   - `docs/agents/*.md`;
   - `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md`;
   - `docs/adr/*.md`;
   - `docs/roadmaps/*`, `FULL_ROADMAP.md`, `docs/milestones/**`;
   - related issues, labels, milestones, Projects evidence when GitHub is configured;
   - relevant code/tests/workflows for the topic.
3. Use mapping and navigation tools when they add real signal:
   - use `rg`, file reads, tests, workflow files, and GitHub CLI/app evidence for ordinary repo inspection;
   - use Carto when a structural code map, neighbors, or change-plan blast radius is relevant and the tool is available;
   - use Graphify when a broader knowledge graph across docs/code/research artifacts would materially improve the audit;
   - use JetBrains or debugger tooling only when semantic navigation or runtime evidence is actually needed.
4. Audit current code health and connections where relevant: current features, workflows, dependency boundaries, duplicated paths, stale docs, inefficient handoffs, missing tests, broken issue/roadmap alignment, issue/milestone/project drift, and places where code and docs disagree.
5. Build a material decision inventory. Include idea scope, issue count, owning milestone, candidate idea-brief location, artifact policy, commit/push policy, acceptance criteria, proof oracle, non-goals, risks, dependencies, sequencing, and unknowns.
6. Ask native UI questions with `request_user_input` in batches. Each question must be tied to a decision inventory item and include a recommended option first when choices are useful.
7. After each answer batch, update the decision inventory and ask the next batch. Do not collapse unanswered decisions into assumptions unless the user says to.
8. Propose 2-3 approaches when the topic admits multiple valid designs, policies, or workflow shapes. Include tradeoffs and one recommended path.
9. Finish with a scope audit idea brief, not an implementation plan.

## Idea Brief Output

For serious repo exploration, the preferred durable artifact is a tracked idea brief:

- `docs/milestones/<milestone-folder>/ideas/<YYYY-MM-DD>-<slug>.md`.

`docs/ideas/` is legacy only. Do not create new idea briefs there. For cross-cutting ideas, ask the user to choose the owning milestone or approve a cross-cutting milestone folder such as `docs/milestones/cross-cutting/ideas/`.

Ask the artifact and publication question through `request_user_input` unless the user already gave explicit instructions. The recommended default for repo work is:

- write a tracked idea brief;
- place it under the selected milestone's `ideas/` folder;
- commit and push that brief on the synced default branch;
- use one commit per exploration session;
- do not create implementation branches, issues, PRs, GoalBuddy boards, native goals, or runtime/code changes.

If the target is not a git-backed repo, the default branch is not synced, GitHub push is not appropriate, or the user chooses not to write a repo artifact, keep the brief in chat or an approved scratch path and state that no tracked handoff file exists.

The human-facing final response should be short. Report the brief path, commit/push status when applicable, key decisions, open questions, and recommended next skill. Do not paste the full machine-readable JSON in chat unless the user explicitly asks to see it or no file artifact can be written and the user requests a handoff in the conversation.

The saved brief must include human-readable sections and a hidden or fenced machine handoff block for downstream skills. Use one of these forms:

```md
<!-- explore_ideas_brief
{ "...": "..." }
-->
```

or:

````md
```json explore_ideas_brief
{ "...": "..." }
```
````

The machine handoff must include:

```json explore_ideas_brief
{
  "slug": "<kebab-case-topic>",
  "target_repo": "<owner/repo or local:none>",
  "topic": "<topic explored>",
  "owning_milestone": "<milestone folder or chat:none>",
  "mode": "default-mode-native-questioning",
  "skills_used": [
    {
      "skill": "inlined-docs-grilling",
      "why": "<why this pass was required>",
      "evidence": "<docs or repo facts it shaped>"
    }
  ],
  "docs_read": ["<repo-relative docs>"],
  "tool_receipts": [
    {
      "tool_or_command": "<rg|gh|Carto|Graphify|JetBrains|test command>",
      "why": "<why used or why skipped>",
      "evidence": "<concise receipt>"
    }
  ],
  "repo_evidence": ["<facts discovered from code/docs/issues/workflows>"],
  "code_health_audit": ["<current health, coupling, stale docs, workflow, or feature gaps>"],
  "workflow_connections": ["<how code, docs, issues, milestones, tests, and workflows connect or drift>"],
  "decision_inventory": [
    {
      "decision": "<decision to settle>",
      "status": "answered|open|discoverable",
      "answer": "<answer or empty>",
      "evidence": "<user answer or repo/doc source>"
    }
  ],
  "question_log": [
    {
      "id": "<stable id>",
      "tool": "request_user_input",
      "question": "<question asked>",
      "answer": "<user answer>",
      "decision": "<decision_inventory item>"
    }
  ],
  "candidate_issue_slices": [
    {
      "title": "<possible issue title>",
      "milestone": "<candidate milestone or none>",
      "why": "<why this slice exists>"
    }
  ],
  "recommended_next_skill": "convert-idea-to-issue|resolve-issue-with-goal|none",
  "idea_artifact": {
    "path": "docs/milestones/<milestone-folder>/ideas/<YYYY-MM-DD>-<slug>.md or chat:none",
    "commit": "<hash or none>",
    "pushed": true
  },
  "open_questions": ["<remaining question>"]
}
```

If the user later wants GitHub issues, pass the saved brief path and machine handoff into `$convert-idea-to-issue`. That skill should convert the idea into one issue or an approved issue set without redoing broad exploration unless the brief is stale or incomplete.

## Validation

Before reporting this skill package complete after edits:

- run `scripts\test-scenarios.ps1`;
- validate `SKILL.md` and `agents\openai.yaml` mention Default mode, `request_user_input`, no Plan mode, no Implement Plan, inlined docs-grilling, no issue/branch/PR/GoalBuddy execution, tracked milestone-local idea output policy, and no full JSON dump in the final chat;
- run the repo-scoped cleanup hook from the active repo root.
