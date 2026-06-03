# Flat Artifact Roots And Milestone Index Views Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use superpowers:test-driven-development for script and scenario behavior changes.

**Goal:** Codify the Milestones plugin source-of-truth rule: canonical specs, plans, and issues stay in the flat `docs/superpowers/specs`, `docs/superpowers/plans`, and `docs/superpowers/issues` roots. Milestone identity lives in artifact metadata, filenames where useful, and generated milestone README/index views, not nested canonical folders under `docs/superpowers/milestones/<milestone>/`.

**Architecture:** Keep milestones as index/dashboard views. Skills that create, repair, validate, plan, issue, or resolve artifacts must point to the flat canonical roots and must treat nested milestone `specs`, `plans`, or `issues` folders as drift unless explicitly documented as generated view output.

**Tech Stack:** Codex skill Markdown/YAML, PowerShell 7 scenario and validation scripts, GitHub issue mirrors, milestone Markdown indexes, `docs/superpowers` artifacts, and existing repo validation through `scripts/validate.ps1`.

---

## Source And Decisions

**Source issue:** `docs/superpowers/issues/15-flat-artifact-roots-milestone-indexes.md`

**GitHub issue:** https://github.com/tannerpolley/milestones-plugin/issues/15

**Planning decision evidence:**

- Specs remain loose upstream idea/design/PRD records. They may mention milestones, packages, categories, or future issues, but they are not milestone-owned implementation records.
- Plans are the milestone-aware execution design when work becomes implementation-facing.
- Issues are the official implementation records and must link to source plans, GitHub metadata, milestone ownership, acceptance criteria, proof oracle, AFK/HITL classification, branch, and execution metadata.
- Flat canonical artifact roots are mandatory for `docs/superpowers/specs`, `docs/superpowers/plans`, and `docs/superpowers/issues`.
- Milestone README/dashboard pages index flat artifacts and may contain generated view output, but they must not own nested canonical copies.

## Acceptance Criteria

- [ ] Project Context, Project Doctor, Project Brainstorm, Project Plan, Project Issue, and Project Resolve documentation agree that canonical specs, plans, and issues directories are flat.
- [ ] Skill documentation describes the lifecycle as `spec -> plan -> issue`, with different metadata requirements at each stage.
- [ ] Spec templates and validators do not require milestone, GitHub issue, source plan, implementation branch, proof oracle, or issue-ready execution metadata.
- [ ] Spec filenames require creation date and slug; milestone identity is optional and only used when naturally helpful.
- [ ] Plan templates and validators support linking to one or more specs or a raw approved idea, and require milestone/package ownership only when the plan is implementation-facing.
- [ ] Issue templates and validators require source plan linkage, GitHub issue metadata, milestone ownership, acceptance criteria, proof oracle, AFK/HITL classification, and branch/worktree execution fields.
- [ ] Generated or repaired artifact filenames include creation date plus milestone identity where applicable, and issue mirrors include the GitHub issue number.
- [ ] Milestone README/dashboard generation links to the flat canonical artifacts instead of owning nested copies.
- [ ] Project Doctor detects and flags nested canonical artifact folders under milestone directories, unless explicitly marked as generated index/view output.
- [ ] Migration guidance explains why milestone subfolders are not canonical and how milestone/category views are represented through frontmatter plus generated indexes.
- [ ] Existing test scenarios cover brainstorming, creating context, planning, issuing, resolving, and doctor-repairing artifacts without producing nested canonical subfolders.

## Non-Goals

- Do not move canonical issue mirrors under `docs/superpowers/milestones/<milestone>/issues`.
- Do not introduce duplicate milestone-owned copies of specs, plans, or issues.
- Do not remove milestone README/index views.
- Do not redesign GitHub labels, milestones, or issue dependency semantics beyond this lifecycle/source-of-truth rule.
- Do not require every loose spec to map to a milestone or GitHub issue.

## File Map

Modify:

- `docs/superpowers/issues/README.md`
- `docs/superpowers/milestones/README.md`
- `docs/superpowers/milestones/M1-source-of-truth.md`
- `skills/project-context/SKILL.md`
- `skills/project-context/agents/openai.yaml`
- `skills/project-context/scripts/test-scenarios.ps1`
- `skills/project-brainstorm/SKILL.md`
- `skills/project-brainstorm/agents/openai.yaml`
- `skills/project-brainstorm/scripts/test-scenarios.ps1`
- `skills/project-plan/SKILL.md`
- `skills/project-plan/agents/openai.yaml`
- `skills/project-plan/scripts/test-scenarios.ps1`
- `skills/project-issue/SKILL.md`
- `skills/project-issue/agents/openai.yaml`
- `skills/project-issue/scripts/test-scenarios.ps1`
- `skills/project-resolve/SKILL.md`
- `skills/project-resolve/agents/openai.yaml`
- `skills/project-resolve/scripts/test-scenarios.ps1`
- `skills/project-doctor/SKILL.md`
- `skills/project-doctor/agents/openai.yaml`
- `skills/project-doctor/scripts/test-scenarios.ps1`
- `scripts/validate.ps1`

Create only if existing scripts need a shared check:

- `scripts/test-flat-artifact-roots.ps1`

## Proof Oracle

- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-context\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-doctor\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-issue\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\project-resolve\scripts\test-scenarios.ps1`
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

## Task 1: Add Flat-Root Scenario Coverage

**Files:**

- Modify the test-scenario scripts listed in the file map.
- Create `scripts/test-flat-artifact-roots.ps1` only if cross-skill validation is clearer as a shared repo contract.

- [ ] Add failing assertions that skill docs and scenario fixtures point canonical specs, plans, and issues to `docs/superpowers/specs`, `docs/superpowers/plans`, and `docs/superpowers/issues`.
- [ ] Add failing assertions that nested `docs/superpowers/milestones/<milestone>/specs`, `plans`, or `issues` paths are rejected or called out as drift.
- [ ] Add failing assertions that milestone README/dashboard content links to flat canonical artifacts.
- [ ] Run the affected scenario scripts and record the red state.

## Task 2: Update Skill Documentation And Prompts

**Files:**

- Modify the six named skill docs and agent prompts in the file map.

- [ ] Document `spec -> plan -> issue` with stage-specific metadata requirements.
- [ ] Document flat canonical roots in Project Context, Project Doctor, Project Brainstorm, Project Plan, Project Issue, and Project Resolve.
- [ ] Document filename expectations: specs and plans include date and slug, plans include milestone identity where applicable, and issue mirrors include the GitHub issue number.
- [ ] Document that milestone pages are index/view output and do not own canonical nested copies.
- [ ] Add migration guidance for moving or repairing nested milestone artifact folders back to flat canonical roots.

## Task 3: Add Doctor And Validation Drift Checks

**Files:**

- Modify `skills/project-doctor/scripts/test-scenarios.ps1`.
- Modify `scripts/validate.ps1`.
- Create or modify a repo contract script for flat-root validation.

- [ ] Add Doctor scenario coverage for nested milestone `specs`, `plans`, and `issues` folders.
- [ ] Implement validation that flags nested canonical artifact folders under `docs/superpowers/milestones`, unless the path is explicitly documented as generated index/view output.
- [ ] Run the focused Doctor scenario and shared validation to confirm the new checks pass after implementation.

## Task 4: Update Milestone Index Guidance

**Files:**

- Modify milestone README/index docs and any generator guidance in skill docs or prompts.

- [ ] Ensure milestone index guidance links to flat canonical artifacts.
- [ ] Ensure milestone/category views are represented through metadata/frontmatter plus indexes.
- [ ] Ensure generated or repaired examples do not create nested canonical artifact folders.

## Task 5: Verify And Prepare PR-Ready Evidence

- [ ] Run the proof oracle commands.
- [ ] Run the repo cleanup hook.
- [ ] Commit the implementation branch.
- [ ] Push `codex/flat-artifact-roots-milestone-indexes`.
- [ ] Open a PR that closes https://github.com/tannerpolley/milestones-plugin/issues/15.
- [ ] Record PR-ready handoff evidence for `$project-merge`.
