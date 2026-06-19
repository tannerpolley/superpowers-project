# Closeout And Startup Decision Tree

This document maps the repo-owned Superpowers Project skill closeout/startup routes.
It covers the selected scope only: repo skills, closeout/startup transitions, and adjacent permission gates that directly affect whether a transition may proceed.

Source roots:

- `skills/*/SKILL.md`
- `skills/*/agents/openai.yaml` where it summarizes closeout/startup behavior
- `skills/advanced-user-input/SKILL.md` for shared native-question semantics

## Global Semantics

Every project workflow closeout follows the same visible route model:

- `Yes` is the progress route.
- `Revisit` is the revisit route.
- `Stop` is terminal at intermediate top-level closeout gates and `Done` is terminal only at verified final gates.
- Use `Stop` for intermediate exits.
- Use `Done` only after verified final proof and a clean worktree.
- `Review First` is non-terminal: show evidence, ask follow-up questions, then return to the originating gate.
- Custom Other never terminates directly. If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels.
- Nested Yes-route menus must not include `Stop` or `Done` when they are pure forward-route menus.
- Nested Revisit-route menus must not include `Stop` or `Done` when they are pure revisit-route menus.

Current source wording is aligned around visible route labels: top-level closeouts use Yes, Revisit, and Stop; final clean gates may use Done, Revisit, and Stop; nested route menus list only real child routes. The trees below preserve exact source question ids, prompts, labels, and route effects.

Legend:

- `ASK`: ask another native question.
- `START`: start the named skill or workflow.
- `LOOP`: return to the originating top-level closeout gate.
- `STOP`: terminal stop/pause leaf.
- `DONE`: verified terminal completion leaf.
- `HOLD`: terminal hold state before a transition can proceed.
- `APPLY`: perform the selected approved repair/action, then return to the next native gate.

## Source Line Reference Index

`SKILL.md` is the source of exact question ids, prompts, option labels, route effects, and terminal leaves. `agents/openai.yaml` repeats most route summaries in one folded `default_prompt` on line 5 of each skill's YAML file; it is useful as a outcome workflow, but it is less precise than the `SKILL.md` blocks for exact prompts and child questions.

Shared closeout semantics:

- `skills/advanced-user-input/SKILL.md:12` and `skills/advanced-user-input/SKILL.md:128`: native question shape, top-level `Continue?`, `Yes` / `Revisit` / `Stop`, Custom answer, and terminal `Done` rules.
- `skills/advanced-user-input/agents/openai.yaml:5`: YAML summary of the same shared closeout contract.
- Per-skill closeout-contract paragraphs: `skills/initiate-workflow/SKILL.md:65`, `skills/setup-project/SKILL.md:115`, `skills/brainstorm-spec/SKILL.md:83`, `skills/audit-project/SKILL.md:91`, `skills/write-plan/SKILL.md:137`, `skills/implement-plan/SKILL.md:100`, `skills/create-issues/SKILL.md:206`, `skills/resolve-issue/SKILL.md:198`, `skills/orchestrate-issues/SKILL.md:94`, `skills/merge-changes/SKILL.md:111`, and `skills/align-project/SKILL.md:120`.

Route-specific source ranges:

- Router startup and ambiguous issue route: `skills/initiate-workflow/SKILL.md:16`, `skills/initiate-workflow/SKILL.md:31`, `skills/initiate-workflow/SKILL.md:35`, `skills/initiate-workflow/SKILL.md:47`, `skills/initiate-workflow/SKILL.md:61`; YAML summary at `skills/initiate-workflow/agents/openai.yaml:5`.
- Setup project: `skills/setup-project/SKILL.md:121`, `skills/setup-project/SKILL.md:133`, `skills/setup-project/SKILL.md:145`, `skills/setup-project/SKILL.md:156`; YAML summary at `skills/setup-project/agents/openai.yaml:5`.
- Brainstorm spec: `skills/brainstorm-spec/SKILL.md:89`, `skills/brainstorm-spec/SKILL.md:101`, `skills/brainstorm-spec/SKILL.md:112`, `skills/brainstorm-spec/SKILL.md:123`, `skills/brainstorm-spec/SKILL.md:154`, `skills/brainstorm-spec/SKILL.md:165`, `skills/brainstorm-spec/SKILL.md:176`; YAML summary at `skills/brainstorm-spec/agents/openai.yaml:5`.
- Write plan: `skills/write-plan/SKILL.md:143`, `skills/write-plan/SKILL.md:155`, `skills/write-plan/SKILL.md:167`, `skills/write-plan/SKILL.md:178`, `skills/write-plan/SKILL.md:191`, `skills/write-plan/SKILL.md:202`, `skills/write-plan/SKILL.md:213`; YAML summary at `skills/write-plan/agents/openai.yaml:5`.
- Implement plan: `skills/implement-plan/SKILL.md:42`, `skills/implement-plan/SKILL.md:74`, `skills/implement-plan/SKILL.md:106`, `skills/implement-plan/SKILL.md:118`; YAML summary at `skills/implement-plan/agents/openai.yaml:5`.
- Create issues: `skills/create-issues/SKILL.md:212`, `skills/create-issues/SKILL.md:224`, `skills/create-issues/SKILL.md:235`, `skills/create-issues/SKILL.md:246`, `skills/create-issues/SKILL.md:257`, `skills/create-issues/SKILL.md:268`; YAML summary at `skills/create-issues/agents/openai.yaml:5`.
- Resolve issue: `skills/resolve-issue/SKILL.md:187`, `skills/resolve-issue/SKILL.md:204`, `skills/resolve-issue/SKILL.md:216`, `skills/resolve-issue/SKILL.md:227`, `skills/resolve-issue/SKILL.md:238`, `skills/resolve-issue/SKILL.md:249`; YAML summary at `skills/resolve-issue/agents/openai.yaml:5`.
- Orchestrate issues: `skills/orchestrate-issues/SKILL.md:100`, `skills/orchestrate-issues/SKILL.md:112`, `skills/orchestrate-issues/SKILL.md:123`, `skills/orchestrate-issues/SKILL.md:134`, `skills/orchestrate-issues/SKILL.md:145`; YAML summary at `skills/orchestrate-issues/agents/openai.yaml:5`.
- Merge changes: `skills/merge-changes/SKILL.md:80`, `skills/merge-changes/SKILL.md:117`, `skills/merge-changes/SKILL.md:129`, `skills/merge-changes/SKILL.md:141`, `skills/merge-changes/SKILL.md:152`, `skills/merge-changes/SKILL.md:163`, `skills/merge-changes/SKILL.md:174`, `skills/merge-changes/SKILL.md:185`, `skills/merge-changes/SKILL.md:196`; YAML summary at `skills/merge-changes/agents/openai.yaml:5`.
- Audit project: `skills/audit-project/SKILL.md:99`, `skills/audit-project/SKILL.md:111`, `skills/audit-project/SKILL.md:121`; YAML summary at `skills/audit-project/agents/openai.yaml:5`.
- Align project: `skills/align-project/SKILL.md:128`, `skills/align-project/SKILL.md:140`, `skills/align-project/SKILL.md:151`, `skills/align-project/SKILL.md:162`, `skills/align-project/SKILL.md:173`, `skills/align-project/SKILL.md:184`; YAML summary at `skills/align-project/agents/openai.yaml:5`.

## Router Startup

`$superpowers-project:initiate-workflow` is the project router. It does not own a full closeout tree with explicit question blocks, but it owns startup routing and the ambiguous issue route.

- Startup route mapping:
  - Project setup, roadmap context, tracker board setup, or large-scope project map
    - START `$superpowers-project:setup-project`.
  - Brainstorming, specs, PRDs, product design, architecture design, or unresolved early project decisions for new work
    - START `$superpowers-project:brainstorm-spec`.
      - Companion method: `superpowers:brainstorming`.
  - Codebase audit, workflow review, diagnosis findings, maintainability findings, architecture findings, or existing behavior that should become a repair spec
    - START `$superpowers-project:audit-project`.
      - Companion methods: `diagnose`, `thermo-nuclear-code-quality-review`, `improve-codebase-architecture`, or framework doctors such as `react-doctor` when applicable.
  - Implementation planning from a spec, issue mirror, or approved direct request
    - START `$superpowers-project:write-plan`.
      - Companion method: `superpowers:writing-plans`.
  - Branch-backed implementation of an approved plan without a GitHub issue
    - START `$superpowers-project:implement-plan`.
      - Companion methods: `superpowers:executing-plans`, plus TDD/debug/verification companions when applicable.
  - Issue decomposition, GitHub issue creation, issue mirror creation, or milestone assignment
    - START `$superpowers-project:create-issues`.
      - Output must keep downstream resolve/orchestrate method compatibility.
  - External GitHub issue hydration, `Source Plan: TBD`, or a GitHub issue that exists before a local mirror and source plan
    - START `$superpowers-project:create-issues`.
  - One ready issue execution in the current thread with native `/goal` proof
    - START `$superpowers-project:resolve-issue`.
      - Companion methods: `superpowers:using-git-worktrees`, `superpowers:executing-plans`, TDD/debug/verification companions when applicable, and `superpowers:finishing-a-development-branch`.
  - Worker-thread implementation of one ready issue
    - START `$superpowers-project:orchestrate-issues`.
      - Companion method: `superpowers:subagent-driven-development`.
      - Worker handoffs require worktree, execution, TDD, verification, and branch-finish companions.
  - PR URL, worker handoff, merge approval, issue close verification, branch/worktree cleanup, or clean repo proof
    - START `$superpowers-project:merge-changes`.
      - Companion method: `superpowers:finishing-a-development-branch`, with upstream verification proof already satisfied.
  - Structure alignment, migration, label review, milestone review, tracker alignment, issue mirror alignment, or live sync review
    - START `$superpowers-project:align-project`.

- `project_issue_resolution_route`
  - Prompt: not specified in current `initiate-workflow` or `resolve-issue` skill text.
  - Guard:
    - If the issue has no local mirror or source plan
      - START `$superpowers-project:create-issues` hydration first.
  - Options:
    - `Project Resolve`
      - START `$superpowers-project:resolve-issue`.
    - `Project Orchestrate`
      - START `$superpowers-project:orchestrate-issues`.
    - `Review First`
      - Show evidence/artifacts.
      - Ask follow-up.
      - Return to route selection.

- `project_auto_mode_authorization`
  - Startup point: `$superpowers-project:initiate-workflow` after `project_workflow_mode` selects Auto Mode and the route has a source artifact.
  - Valid approval option:
    - `Bounded Auto Merge`
      - Record or carry an Auto Mode authorization ledger tied to the startup mode selection.
      - Continue within the recorded defaults for one selected or derived route.
  - Validator:
    - Resolve from the loaded Superpowers Project plugin root: `<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1 -RepoRoot <active repo> -AuthorizationPath <ledger>`.
  - Stop outside policy when:
    - Proof is missing.
    - Validation fails.
    - GitHub state is unsafe.
    - A decision falls outside the ledger policy.
    - The selected route reaches closeout.

## Setup Project

- `project_setup_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Continue Project Work`)
      - ASK `project_setup_work_route`.
      - `project_setup_work_route`
        - Prompt: `Which project workflow should start from setup?`
        - Options:
          - `Brainstorm New Spec`
            - START `$superpowers-project:brainstorm-spec`.
          - `Write Plan`
            - START `$superpowers-project:write-plan`.
          - `Create Issues`
            - START `$superpowers-project:create-issues`.
    - Revisit (`Revise / Review Setup`)
      - ASK `project_setup_reiteration_group`.
      - `project_setup_reiteration_group`
        - Prompt: `How should I revisit this setup work?`
        - Options:
          - `Review / Revise Setup`
            - ASK `project_setup_reiteration_route`.
            - `project_setup_reiteration_route`
              - Prompt: `Should I review or revise setup?`
              - Options:
                - `Review Setup`
                  - Show setup summary/rendered artifacts.
                  - LOOP `project_setup_next_step`.
                - `Revise Setup`
                  - Update setup artifacts from follow-up answers.
                  - LOOP `project_setup_next_step`.
          - `Run Align`
            - START `$superpowers-project:align-project`.
    - Stop
      - STOP.

- `project_setup_board_approval`
  - Gate: adjacent setup permission gate.
  - Prompt: not specified in current source.
  - Options:
    - `Create Board`
      - Create or reuse the GitHub Project board after plan evidence.
    - `Verify Only`
      - Validate/report board configuration without mutation.
    - `Stop`
      - STOP.

## Brainstorm Spec

- `project_brainstorm_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Continue From Spec`)
      - ASK `project_brainstorm_plan_route`.
      - `project_brainstorm_plan_route`
        - Prompt: `How should planning start from this brainstorm?`
        - Options:
          - `Create One Plan`
            - START `$superpowers-project:write-plan` from the recently generated spec.
          - `Multi-Spec Planning`
            - ASK `project_brainstorm_multi_spec_route`.
            - `project_brainstorm_multi_spec_route`
              - Prompt: `How should multiple specs become plans?`
              - Options:
                - `Plan Multiple Specs`
                  - START `$superpowers-project:write-plan` from multiple existing specs.
                  - Prompt for spec selection if not known.
                - `Create Multiple Plans`
                  - Create multiple related plans from multiple specs.
                  - Prompt for spec-to-plan grouping if not known.
      - Recovery:
        - If a saved-spec closeout omitted `project_brainstorm_plan_route`, warn about stale loaded skill text and re-ask the missed native route.
    - Revisit (`Revise / Review Brainstorm`)
      - ASK `project_brainstorm_reiteration_route`.
      - `project_brainstorm_reiteration_route`
        - Prompt: `How should I revisit this brainstorm output?`
        - Options:
          - `Revise Spec`
            - Continue `$superpowers-project:brainstorm-spec` with follow-up questions to revise the saved spec or decision summary.
          - `Review Or Restart`
            - ASK `project_brainstorm_review_restart_route`.
            - `project_brainstorm_review_restart_route`
              - Prompt: `Should I review this brainstorm or start another one?`
              - Options:
                - `Review First`
                  - Show the rendered artifact.
                  - Ask for follow-up confirmation.
                  - LOOP `project_brainstorm_next_step`.
                - `Re-run Brainstorm`
                  - START another `$superpowers-project:brainstorm-spec` cycle for a new feature, idea, or major alternative.
    - Stop
      - STOP.

## Write Plan

- `project_plan_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Continue Into Work`)
      - ASK `project_plan_work_route`.
      - `project_plan_work_route`
        - Prompt: `Which workflow should continue from this plan?`
        - Options:
          - `Project Issue First`
            - ASK `project_plan_issue_count`.
            - `project_plan_issue_count`
              - Prompt: `How many issues should be created from this plan?`
              - Options:
                - `One Issue`
                  - Create one vertical-slice issue.
                  - START `$superpowers-project:create-issues`.
                - `Multiple Issues`
                  - ASK `project_plan_issue_count_multiple`.
                  - `project_plan_issue_count_multiple`
                    - Prompt: `How many multiple issues should this plan create?`
                    - Options:
                      - `Two Issues`
                        - Create two coordinated vertical-slice issues.
                        - START `$superpowers-project:create-issues`.
                      - `Three Or More`
                        - Create three or more issues.
                        - Use nested questions to group issue count and dependencies.
                        - START `$superpowers-project:create-issues`.
          - `Project Implement`
            - START `$superpowers-project:implement-plan` using the saved plan path without creating issue mirrors.
          - `Use Ready Issue`
            - ASK `project_plan_issue_execution_route`.
            - `project_plan_issue_execution_route`
              - Prompt: `Which ready-issue execution route should continue from this plan?`
              - Options:
                - `Resolve Issue`
                  - START `$superpowers-project:resolve-issue` for an existing ready issue mirror.
                - `Orchestrate Issues`
                  - START `$superpowers-project:orchestrate-issues` for worker-thread execution.
    - Revisit (`Revise / Review Plan`)
      - ASK `project_plan_review_route`.
      - `project_plan_review_route`
        - Prompt: `How should I revisit this plan?`
        - Options:
          - `Revise Plan`
            - Continue `$superpowers-project:write-plan` with follow-up questions to revise the saved plan.
          - `Review Or Grill`
            - ASK `project_plan_review_grill_route`.
            - `project_plan_review_grill_route`
              - Prompt: `Should I review this plan or re-run the planning grill?`
              - Options:
                - `Review First`
                  - Show the rendered artifact.
                  - Ask for follow-up confirmation.
                  - LOOP `project_plan_next_step`.
                - `Re-run Planning Grill`
                  - Run the planning grill again for an existing spec with no ready plan.
    - Stop
      - STOP.

## Implement Plan

- `implement_plan_topology`
  - Gate: startup execution topology.
  - Prompt: `How should this approved plan be implemented?`
  - Options:
    - `Inline`
      - Implement in this thread on a development branch.
    - `Worker`
      - Delegate to a worker thread with an explicit plan handoff and reporting path.
      - Guard:
        - Valid only when the worker handoff names the orchestrator, role, plan path, branch, reporting path, and reason the worker may ask for `request_agent_input`.
    - `Stop`
      - STOP without edits.

- `implement_plan_push_permission`
  - Gate: adjacent push permission.
  - Prompt: `Should I push this implementation branch before merge routing?`
  - Options:
    - `Push Branch`
      - Push the development branch.
      - Continue toward merge-ready evidence.
    - `Hold`
      - HOLD with the branch preserved.
  - Guard:
    - Merge routing is unavailable until this gate is answered and, when approved, branch push proof exists.

- `project_implement_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Merge Implemented Plan`)
      - START `$superpowers-project:merge-changes` with merge-ready proof.
    - Revisit (`Revise / Review Branch`)
      - ASK `project_implement_reiteration_route`.
      - `project_implement_reiteration_route`
        - Prompt: `How should I revisit this implemented plan?`
        - Options:
          - `Revise Branch`
            - Continue implementation on the current development branch.
          - `Review Evidence`
            - Show the rendered handoff and verification evidence.
            - LOOP `project_implement_next_step`.
    - Stop
      - STOP.

## Create Issues

- `project_issue_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Continue Issue Execution`)
      - ASK `project_issue_execution_route`.
      - `project_issue_execution_route`
        - Prompt: `How should these issues be executed?`
        - Options:
          - `Resolve Issues`
            - ASK `project_issue_resolve_route`.
            - `project_issue_resolve_route`
              - Prompt: `Which issue should be resolved directly?`
              - Options:
                - `Resolve First Ready`
                  - START `$superpowers-project:resolve-issue` on the first ready AFK issue.
                - `Resolve Selected`
                  - Ask for or use a selected ready issue mirror.
                  - START `$superpowers-project:resolve-issue`.
          - `Orchestrate Issues`
            - ASK `project_issue_orchestrate_route`.
            - `project_issue_orchestrate_route`
              - Prompt: `Which issue should be delegated to a worker?`
              - Options:
                - `Orchestrate First Ready`
                  - START `$superpowers-project:orchestrate-issues` on the first ready worker-suitable issue.
                - `Orchestrate Selected`
                  - Ask for or use a selected ready issue mirror.
                  - START `$superpowers-project:orchestrate-issues`.
    - Revisit (`Revise / Review Issues`)
      - ASK `project_issue_reiteration_route`.
      - `project_issue_reiteration_route`
        - Prompt: `How should I revisit this issue set?`
        - Options:
          - `Revise Or Reslice Issues`
            - Revise issue boundaries or reslice the set.
            - LOOP `project_issue_next_step`.
          - `Review Or Repair Issues`
            - ASK `project_issue_review_repair_route`.
            - `project_issue_review_repair_route`
              - Prompt: `Should I review the issues or repair mirrors?`
              - Options:
                - `Review First`
                  - Show rendered issue mirrors.
                  - Ask for follow-up confirmation.
                  - LOOP `project_issue_next_step`.
                - `Repair Issue Mirrors`
                  - Repair local mirror drift.
                  - LOOP `project_issue_next_step`.
    - Stop
      - STOP.

## Resolve Issue

- `project_resolve_push_permission`
  - Gate: adjacent push/PR permission.
  - Prompt: `Should I push this branch and create the PR now?`
  - Options:
    - `Push And Open PR`
      - Push the branch.
      - Open the PR.
      - Continue to PR-ready handoff.
    - `Hold`
      - HOLD with the branch local and explicit hold state.
  - Guard:
    - PR-ready evidence is invalid unless this gate was answered and approved before the push/PR step.

- `project_resolve_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Integrate Resolved Issue`)
      - ASK `project_resolve_integration_route`.
      - `project_resolve_integration_route`
        - Prompt: `What should happen with this PR-ready issue?`
        - Options:
          - `Merge`
            - START `$superpowers-project:merge-changes` from the PR URL or worker handoff.
          - `Continue Another Issue`
            - ASK `project_resolve_another_issue_route`.
            - `project_resolve_another_issue_route`
              - Prompt: `How should the next issue be executed?`
              - Options:
                - `Resolve Another`
                  - START `$superpowers-project:resolve-issue` for another ready issue mirror.
                - `Orchestrate Another`
                  - START `$superpowers-project:orchestrate-issues` for another worker-suitable issue.
    - Revisit (`Review / Revise PR-Ready Work`)
      - ASK `project_resolve_reiteration_route`.
      - `project_resolve_reiteration_route`
        - Prompt: `How should I revisit this PR-ready work?`
        - Options:
          - `Review First`
            - Show PR-ready evidence for main-thread review.
            - LOOP `project_resolve_next_step`.
          - `Revise Or Fix Branch`
            - ASK `project_resolve_fix_route`.
            - `project_resolve_fix_route`
              - Prompt: `Should I revise the branch or address checks?`
              - Options:
                - `Revise Branch`
                  - Continue implementation on the branch.
                  - LOOP `project_resolve_next_step`.
                - `Address CI / Checks`
                  - Inspect and fix checks.
                  - LOOP `project_resolve_next_step`.
    - Stop
      - STOP after terminal closeout validation.

## Orchestrate Issues

- `project_orchestrate_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Integrate Worker Output`)
      - ASK `project_orchestrate_integration_route`.
      - `project_orchestrate_integration_route`
        - Prompt: `What should happen with the worker output?`
        - Options:
          - `Merge`
            - START `$superpowers-project:merge-changes` for the PR-ready handoff.
          - `Start More Worker Work`
            - ASK `project_orchestrate_more_worker_route`.
            - `project_orchestrate_more_worker_route`
              - Prompt: `What worker-backed work should start next?`
              - Options:
                - `Resolve Another Worker Issue`
                  - Start another worker-backed issue route when one is ready.
                - `Start Another Worker`
                  - Create another worker thread for a selected ready issue.
    - Revisit (`Recover / Review Worker Route`)
      - ASK `project_orchestrate_reiteration_route`.
      - `project_orchestrate_reiteration_route`
        - Prompt: `How should I revisit this worker route?`
        - Options:
          - `Recover Audit Workers`
            - Audit and recover workers and worktrees.
          - `Worker Communication`
            - ASK `project_orchestrate_worker_communication_route`.
            - `project_orchestrate_worker_communication_route`
              - Prompt: `How should worker communication continue?`
              - Options:
                - `Ask Worker`
                  - Use `request_agent_input` when the current thread is orchestrating a worker.
                - `Reassign Work`
                  - Stop the current worker route.
                  - Reassign the issue through an approved route.
    - Stop
      - STOP.

## Merge Changes

- `project_merge_approval`
  - Gate: merge approval.
  - Prompt shape:

```text
Premerge proof is clean for <PR URL or local branch>. Merge now?
```

  - Options:
    - `Merge`
      - Merge the issue-backed PR or local branch.
      - Continue closeout cleanup.
    - `Decline`
      - Stop without merging.
      - Report the exact pending state.
      - Optional reassessment follow-up:
        - Prompt: not specified in current source.
        - Options:
          - `User Review`
            - STOP with the PR or branch evidence.
          - `Reassess Plan`
            - START `$superpowers-project:write-plan` for strict execution, testing, acceptance, or branch strategy revision.
          - `Reassess Spec`
            - START `$superpowers-project:brainstorm-spec` for loose idea or scope reassessment.

- `project_merge_final_health_gate`
  - Gate: verified final health gate.
  - Prompt: `Closeout proof is clean. Mark this workflow done?`
  - Guard:
    - `Done` is valid only when clean closeout proof passed and `git status --short` is empty.
  - Options:
    - Done
      - DONE.
    - Revisit
      - Review closeout evidence.
      - LOOP `project_merge_next_step`.
    - Stop
      - STOP with clean closeout proof recorded.

- `project_merge_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Continue Project Execution`)
      - ASK `project_merge_continue_group`.
      - `project_merge_continue_group`
        - Prompt: `Which kind of work should continue after this merge?`
        - Options:
          - `Continue Issues`
            - ASK `project_merge_issue_route`.
            - `project_merge_issue_route`
              - Prompt: `How should the next issue be executed?`
              - Options:
                - `Resolve Another`
                  - START `$superpowers-project:resolve-issue` for another ready issue mirror.
                - `Orchestrate Another`
                  - START `$superpowers-project:orchestrate-issues` for another worker-suitable issue.
          - `Start Planning`
            - ASK `project_merge_planning_route`.
            - `project_merge_planning_route`
              - Prompt: `How should the next work be shaped?`
              - Options:
                - `Plan Next`
                  - START `$superpowers-project:write-plan` from an approved spec or issue mirror.
                - `Brainstorm Next`
                  - START `$superpowers-project:brainstorm-spec` for the next idea, spec, or architecture direction.
    - Revisit (`Review / Repair Closeout`)
      - ASK `project_merge_reiteration_group`.
      - `project_merge_reiteration_group`
        - Prompt: `How should I revisit this merge closeout?`
        - Options:
          - `Review Closeout`
            - Show closeout evidence and rendered artifacts.
            - LOOP `project_merge_next_step`.
          - `Repair / Audit Closeout`
            - ASK `project_merge_repair_route`.
            - `project_merge_repair_route`
              - Prompt: `Which closeout repair route should run?`
              - Options:
                - `Run Align`
                  - START `$superpowers-project:align-project` for post-merge drift alignment or live sync review.
                - `Repair Or Cleanup`
                  - ASK `project_merge_repair_cleanup_route`.
                  - `project_merge_repair_cleanup_route`
                    - Prompt: `Should I repair drift or rerun cleanup?`
                    - Options:
                      - `Repair Drift`
                        - Repair exact closeout drift after approval.
                      - `Re-run Cleanup`
                        - Rerun cleanup and closeout proof.
    - Stop
      - STOP after terminal closeout validation.

## Audit Project

- `project_audit_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Prepare Repair Work`)
      - ASK `project_audit_progress_route`.
      - `project_audit_progress_route`
        - Prompt: `Which repair route should start from the findings spec?`
        - Options:
          - `Write Plan`
            - START `$superpowers-project:write-plan` from the P-coded findings spec.
          - `Create Issues`
            - START `$superpowers-project:create-issues` only when the findings are issue-ready.
    - Revisit (`Review Or Extend Findings`)
      - ASK `project_audit_revisit_route`.
      - `project_audit_revisit_route`
        - Prompt: `How should I revisit these findings?`
        - Options:
          - `Review First`
            - Show the findings spec and evidence summary.
            - LOOP `project_audit_next_step`.
          - `Gather More Evidence`
            - Inspect the requested source or load another companion review skill.
            - LOOP `project_audit_next_step`.
          - `Rerun Focused Audit`
            - Rerun the applicable companion skill on a narrower scope.
            - LOOP `project_audit_next_step`.
    - Stop
      - STOP.

## Align Project

- Final Done eligibility:
  - `Done` is valid only when:
    - The audit result is healthy.
    - There are no blocking findings.
    - There are no repairable findings.
    - There is no remaining repair route.
    - The worktree is clean.
  - If `git status --short` is non-empty:
    - `Done` is invalid.
    - Continue through commit, push, repair, or hold routing.
  - If findings remain:
    - `Stop` remains the terminal option.

- `project_align_next_step`
  - Prompt: `Should I continue on with the workflow?`
  - Options:
    - Yes (`Apply Or Prepare Repair`)
      - ASK `project_align_repair_group`.
      - `project_align_repair_group`
        - Prompt: `How should this audit turn into repair work?`
        - Options:
          - `Apply Repair`
            - APPLY an approved, exact repair plan.
          - `Prepare Repair Work`
            - ASK `project_align_prepare_route`.
            - `project_align_prepare_route`
              - Prompt: `Which repair artifact should be prepared?`
              - Options:
                - `Create Planning Spec`
                  - START `$superpowers-project:brainstorm-spec` for a larger repair design.
                - `Plan Or Issue Repair`
                  - ASK `project_align_plan_issue_route`.
                  - `project_align_plan_issue_route`
                    - Prompt: `Should I plan the repair or create an issue?`
                    - Options:
                      - `Plan Repair`
                        - START `$superpowers-project:write-plan` from the audit findings.
                      - `Create Issue`
                        - START `$superpowers-project:create-issues` only when the repair is already issue-ready.
    - Revisit (`Rerun / Review Alignment`)
      - ASK `project_align_reiteration_route`.
      - `project_align_reiteration_route`
        - Prompt: `How should I revisit this audit?`
        - Options:
          - `Run Align Again`
            - START `$superpowers-project:align-project` after changes or new GitHub evidence.
          - `Review Or Gather Evidence`
            - ASK `project_align_review_evidence_route`.
            - `project_align_review_evidence_route`
              - Prompt: `Should I review the audit or gather more evidence?`
              - Options:
                - `Review First`
                  - Show the audit summary and rendered artifacts for user review.
                  - LOOP `project_align_next_step`.
                - `Gather More Evidence`
                  - Inspect the requested source.
                  - LOOP `project_align_next_step`.
    - Stop
      - STOP.

## Cross-Skill Terminal Leaves

All `Stop` leaves are terminal pause leaves, not proof of completed workflow success.

`Done` exists only at verified final health gates. Repo-owned final health gates use `Done`, `Revisit`, and `Stop`.

- `project_merge_final_health_gate` after clean merge closeout proof.
- `project_align_final_health_gate` after a healthy alignment audit with no blocking or repairable findings, no remaining repair route, cleanup proof, and clean worktree proof.

`Hold` leaves are terminal hold leaves:

- `implement_plan_push_permission` -> `Hold`: branch preserved, merge routing unavailable.
- `project_resolve_push_permission` -> `Hold`: branch local, PR-ready evidence invalid.

`Decline` leaves:

- `project_merge_approval` -> `Decline`: stop without merging, then optional reassessment route may ask `User Review`, `Reassess Plan`, or `Reassess Spec`.

## Wording Gaps To Resolve

These are source gaps or tensions found while building the tree:

- `project_issue_resolution_route` has exact option labels but no exact prompt in current source.
- `project_setup_board_approval` has exact option labels but no exact prompt in current source.
- `project_setup_board_approval` appears in `skills/setup-project/SKILL.md` but not in `skills/setup-project/agents/openai.yaml`.
- Merge decline reassessment has exact option labels but no question id or prompt in current source.
- The global closeout contract says top-level prompt text is `Continue?`, while most skill-specific prompt blocks say `Should I continue on with the workflow?`.
- Top-level option labels are `Yes`, `Revisit`, and `Stop`; parenthesized text preserves the source detail for that route.
- Nested Yes/Revisit route menus omit `Stop` and `Done`; only top-level closeout and final health gates include terminal options.
- Intermediate gates use `Yes`, `Revisit`, and `Stop`; verified final health gates use `Done`, `Revisit`, and `Stop`.
- Most `agents/openai.yaml` files compress the route tree into one folded line, which preserves the broad contract but does not carry every exact prompt, child question id, or option description from `SKILL.md`.

