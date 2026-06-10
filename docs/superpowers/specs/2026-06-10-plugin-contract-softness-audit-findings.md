# Superpowers Project Plugin Contract Softness Audit Findings

## Scope

Audit the Superpowers Project plugin as a brand-new agent would encounter it, with the intended behavior understood from the current workflow contract: native continuation gates must use clear route labels, live plugin drift checks must prove the deployed user-level state, and skill text must be direct enough that a fresh thread does not infer fake terminal options or stale routes.

## Companion Skills Used

- `project:audit-project`
- `thermo-nuclear-code-quality-review`
- `stop-slop`

## Checked Artifacts

- `README.md`
- `.codex-plugin/plugin.json`
- `skills/*/SKILL.md`
- `skills/*/agents/openai.yaml`
- `skills/*/scripts/*.ps1`
- `scripts/validate.ps1`
- `scripts/sync-live.ps1`
- `scripts/test-advanced-user-input-policy.ps1`
- `scripts/test-native-continuation-loop.ps1`
- `docs/superpowers/closeout-startup-decision-tree-dev.md`
- `docs/superpowers/issues/README.md`

## Findings

### P1: Align live-sync audit does not audit the live plugin install it claims to audit

Evidence:

- `skills/align-project/SKILL.md:76` through `skills/align-project/SKILL.md:86` says Align checks live plugin install versus source, including retired skill directories and active wrappers.
- `skills/align-project/scripts/align-project.ps1:521` through `skills/align-project/scripts/align-project.ps1:535` compares only `skills/align-project/SKILL.md` against live targets.
- `skills/align-project/scripts/align-project.ps1:523` through `skills/align-project/scripts/align-project.ps1:525` includes `~/.agents/skills/align-project/SKILL.md`, but `scripts/sync-live.ps1:44` deploys only `advanced-user-input` into the user skill root.

Impact:

A brand-new agent can run Align, see a healthy `live-sync` finding, and still miss drift in the plugin manifest, assets, metadata YAML, every other skill, the marketplace entry, or the actual user-level `advanced-user-input` copy. This is a false sense of safety for the exact class of stale plugin behavior the workflow is supposed to catch.

Repair requirement:

Make Align's live-sync audit call a shared dry-run compare that covers the same surfaces as `sync-live.ps1`: manifest, assets, all active plugin skills, the user-level `advanced-user-input` copy, marketplace entry, retired plugin roots, and stale owned skill directories.

Proof oracle:

Create a fixture where only `skills/merge-changes/agents/openai.yaml` or `~/.agents/skills/advanced-user-input/SKILL.md` drifts. `align-project.ps1 -Mode LocalDocs` must report repairable live-sync drift.

### P1: Final gate vocabulary contradicts itself across shared and merge-specific contracts

Evidence:

- `skills/advanced-user-input/SKILL.md:140` says final clean closeout gates may use exactly `Yes`, `Revisit`, and `Done`.
- `skills/merge-changes/SKILL.md:117` through `skills/merge-changes/SKILL.md:125` defines `project_merge_final_health_gate` with `Done`, `Revisit`, and `Stop`.
- `docs/superpowers/closeout-startup-decision-tree-dev.md:711` explicitly records this mismatch.

Impact:

A fresh agent cannot know whether a final gate should offer `Yes` or `Stop` as the third option. That ambiguity directly produces bad UI shapes such as merged terminal labels or repeated terminal routes.

Repair requirement:

Define one final-gate schema. If clean final gates may include `Stop`, update `advanced-user-input` and tests. If they must use `Yes`, change `project_merge_final_health_gate`. Do not leave the mismatch as a documented exception.

Proof oracle:

Add a validator that reads every `*_final_health_gate` block and fails unless its options match the declared final-gate schema.

### P1: Active contracts still use the ambiguous phrase "Stop or Done"

Evidence:

- `skills/advanced-user-input/SKILL.md:50` says a custom answer that appears to ask for "Stop or Done" should trigger confirmation.
- `skills/advanced-user-input/SKILL.md:154` repeats "Stop or Done."
- `skills/merge-changes/SKILL.md:127` repeats the same phrase inside the generic closeout paragraph.
- `scripts/test-advanced-user-input-policy.ps1:85` requires the phrase.

Impact:

The phrase is meant as prose, but it reads like a combined terminal option. A stale or overloaded thread can turn that into a visible `Stop/Done` label, which violates the intended UI model.

Repair requirement:

Replace prose with explicit wording: "If a custom answer requests either `Stop` or `Done`, ask a fresh confirmation question with separate valid labels." Add tests that reject `Stop/Done` and reject `Stop or Done` inside option-label contexts.

Proof oracle:

`rg -n 'Stop/Done|Stop\\s*/\\s*Done' skills scripts docs README.md` must return no active-contract hits. A native-option fixture using `Stop/Done` must fail validation.

### P2: Align defines Done eligibility but does not define a final Done gate

Evidence:

- `skills/align-project/SKILL.md:124` says `Done` is valid for a healthy Align audit with no blocking or repairable findings and a clean worktree.
- `skills/align-project/SKILL.md:128` through `skills/align-project/SKILL.md:136` defines only `project_align_next_step` with `Yes`, `Revisit`, and `Stop`.
- `docs/superpowers/closeout-startup-decision-tree-dev.md:689` says an alignment `Done` UI is valid only if a healthy audit final gate is explicitly asked, but no such gate exists in `align-project/SKILL.md`.

Impact:

An agent can know that Align may be "done" but has no exact question id, prompt, or option set to ask. That makes final healthy audits depend on improvisation.

Repair requirement:

Either add `project_align_final_health_gate` with exact prompt, options, and validation rules, or remove Align's Done eligibility and state that Align always ends through `Stop` unless routed onward.

Proof oracle:

The continuation-loop validator must fail when a final-capable skill declares Done eligibility without an exact `Question id:` block for its final gate.

### P2: User-facing skill invocation names are stale or inconsistent

Evidence:

- `README.md:15` says the prompt surface is `superpowers-project:*`.
- `README.md:19` through `README.md:29` uses `$superpowers-project:*`.
- `.codex-plugin/plugin.json:34` through `.codex-plugin/plugin.json:44` uses `superpowers-project:*` without `$`.
- `docs/superpowers/issues/README.md:37`, `docs/superpowers/issues/README.md:53`, `docs/superpowers/issues/README.md:57`, and `docs/superpowers/issues/README.md:67` still use `$project:*`.

Impact:

A new agent or user sees at least three invocation forms. The stale `$project:*` names are especially risky because issue mirrors are runtime inputs for resolve, orchestrate, merge, and audit routes.

Repair requirement:

Declare one canonical spelling plus any accepted aliases in one place, then update README, plugin manifest prompts, issue docs, tests, and skill metadata to use that vocabulary consistently.

Proof oracle:

Add a namespace scan that fails on `$project:` in active docs and fails on mixed `$superpowers-project:` versus `superpowers-project:` unless the file is explicitly documenting aliases.

### P2: `sync-live.ps1` labels current active skills as retired

Evidence:

- `scripts/sync-live.ps1:45` starts `$retiredSkillNames`.
- `scripts/sync-live.ps1:67` through `scripts/sync-live.ps1:77` includes current active skills such as `initiate-workflow`, `setup-project`, `align-project`, and `audit-project`.
- `scripts/validate.ps1:120` through `scripts/validate.ps1:132` separately lists those same names as active.

Impact:

The behavior happens to work because active names are protected by `ActiveSkillNames`, but the variable name lies. A maintainer changing the cleanup logic could delete live active skills or misread the deployment model.

Repair requirement:

Split the data into `retiredSkillNames` and `ownedSkillNames`, or remove current active skills from the retired list and compute owned names as `active + retired` at the call site.

Proof oracle:

Add a test that intersects `Get-ActiveSkillNames` with `retiredSkillNames` and fails if the intersection is non-empty.

### P2: Active skill lists are hard-coded in multiple validators

Evidence:

- `scripts/validate.ps1:120` through `scripts/validate.ps1:132` hard-codes active skill names.
- `scripts/test-native-continuation-loop.ps1:70` through `scripts/test-native-continuation-loop.ps1:94` hard-codes workflow, intermediate, and final-capable skills.
- `scripts/test-project-namespace-migration.ps1:19` through `scripts/test-project-namespace-migration.ps1:24` hard-codes target skills.
- `scripts/sync-live.ps1:43` discovers active skill names from the `skills` directory.

Impact:

Adding or renaming a skill requires editing several disconnected lists. That is exactly how stale validation gaps appear: deployment can include a skill while one validator silently ignores it.

Repair requirement:

Create one source of truth for active workflow skills and final-capable skills. Generate validator inputs from the skill directories plus explicit frontmatter fields such as `workflow: true` and `final_capable: true`.

Proof oracle:

A test fixture adding a dummy workflow skill must fail until the single metadata source declares whether it is intermediate or final-capable; no validator should require a separate hard-coded list edit.

### P2: Metadata prompts are giant single-line contracts

Evidence:

- Every `skills/*/agents/openai.yaml` stores `default_prompt` as one folded line on line 5.
- Measured max line lengths range from 4,559 characters for `advanced-user-input` to 8,626 characters for `initiate-workflow`.
- `docs/superpowers/closeout-startup-decision-tree-dev.md:40` admits YAML is less precise than `SKILL.md`, but each YAML line still repeats most of the route contract.

Impact:

The metadata is too dense for a new agent to inspect and too brittle for maintainers to patch safely. It also creates hidden drift risk because tests mostly search for substrings rather than validating structured route fields.

Repair requirement:

Move metadata route summaries into structured YAML keys or generated compact sections. Keep `default_prompt` short and point to exact `SKILL.md` sections for route tables.

Proof oracle:

Add a line-length or structured-schema validator for `agents/openai.yaml`. No `default_prompt` line should exceed an agreed threshold unless generated and explicitly checked.

### P2: Debug mode is an under-specified escape hatch

Evidence:

- `skills/brainstorm-spec/SKILL.md:28`, `skills/setup-project/SKILL.md:50`, `skills/audit-project/SKILL.md:80`, and `skills/align-project/SKILL.md:104` allow `debug_question_mode` when a background-thread prompt is "proven stuck" in `waitingOnUserInput`.
- `skills/initiate-workflow/SKILL.md:85` and `skills/merge-changes/SKILL.md:107` add the stricter requirement that no tool exists to answer the modal prompt.
- The weaker skill blocks do not define what proof establishes that a prompt is stuck.

Impact:

A new agent can use debug mode differently depending on which skill it loaded. In the worst case, it may bypass a real native question because "stuck" was interpreted loosely.

Repair requirement:

Centralize debug mode policy in `advanced-user-input` and require all skills to reference it. Define the exact proof fields needed before debug mode can run, and require the "no tool exists to answer the modal prompt" guard everywhere.

Proof oracle:

Validation must fail if any skill defines a local debug mode paragraph that omits the centralized guard, proof fields, and mutation restrictions.

### P2: Issue workflow metadata is advisory even though downstream execution depends on it

Evidence:

- `skills/create-issues/SKILL.md:106` says missing workflow metadata is advisory during migration.
- `skills/create-issues/scripts/validate-issue-mirror.ps1:114` through `skills/create-issues/scripts/validate-issue-mirror.ps1:119` records missing workflow metadata as `"advisory: missing"` and continues.
- `docs/superpowers/issues/README.md:37` says those fields tell the runtime how to ask the execution question and who owns integration.

Impact:

A mirror can pass validation without fields that resolve and orchestrate use for execution routing, worktree policy, integration policy, TDD policy, reviewer role, and script gate mode. That turns a supposed executable issue mirror into an ambiguous intake artifact.

Repair requirement:

Make missing workflow metadata blocking for newly created or hydrated issue mirrors. If old migration artifacts still need leniency, require an explicit migration mode flag and report the result as repairable drift, not a passing validation.

Proof oracle:

`validate-issue-mirror.ps1` must fail a non-migration mirror missing any workflow metadata field. Scenario tests should cover both strict new mirrors and explicit migration fixtures.

## Healthy Checks

- The active repo worktree was clean before the audit.
- Active skill text no longer exposes old `Down`, `Left`, and `Right` option labels in closeout route blocks.
- The current continuation-loop validators already check many stale terminal label patterns, but they do not yet cover the ambiguities called out above.

## Recommended Repair Route

Start with a targeted `$superpowers-project:write-plan` from this findings spec. The first repair slice should cover findings P1-1 through P1-3 because they affect live drift proof and terminal UI semantics. The second repair slice should cover naming/source-of-truth cleanup. The third repair slice should decompose metadata prompts and tighten debug/issue-metadata validators.

## Open Questions

- Which invocation spelling should be canonical in user-facing docs: `$superpowers-project:*`, `superpowers-project:*`, or the runtime-exposed `project:*` alias?
- Should Align have a real final Done gate, or should Align remain an audit route that ends only through `Stop` or a follow-up route?
- Should old issue mirrors be allowed to pass validation with missing workflow metadata, or should migration leniency move into a separate audit-only command?
