# Plugin Contract Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the Superpowers Project plugin contracts so a fresh agent gets unambiguous native routing, drift proof, namespace guidance, debug-mode rules, and issue execution metadata.

**Architecture:** Add a shared project-skill registry and read-only live-install comparer, then make validators consume those shared contracts. Normalize the native final-gate schema, Align final gate, canonical namespace text, issue metadata strictness, debug-mode proof policy, and metadata readability in active skill text, metadata YAML, and scenario tests.

**Tech Stack:** Bash 7, Markdown, YAML, Git, existing repo validation scripts, existing Superpowers Project skill scenario tests.

---

## Source And Approval Evidence

Source findings spec:

- `docs/superpowers/specs/2026-06-10-plugin-contract-softness-audit-findings.md`

User planning decisions recorded through native UI:

- Canonical user-facing skill invocation spelling: `$superpowers-project:*`
- Align final policy: add an explicit `project_align_final_health_gate`
- Issue workflow metadata policy: strict for all mirrors, including old mirrors

This plan covers all 10 audit findings. The first repair slice is P1-1 through P1-3 because those affect live drift proof and terminal UI semantics.

## Acceptance Criteria

- Align LocalDocs live-sync checks detect drift in manifest, assets, every active plugin skill, the user-level `advanced-user-input` copy, marketplace entry, retired live plugin roots, and stale owned skill directories.
- Active skill names, workflow skill names, final-capable skill names, user-level skill names, retired skill names, and owned skill names come from one shared registry.
- No active skill is listed as retired.
- Intermediate continuation gates use `Yes`, `Revisit`, `Stop`.
- Verified final health gates use `Done`, `Revisit`, `Stop`.
- Align defines and validates `project_align_final_health_gate`.
- Active contracts no longer use the plain phrase `Stop or Done` as a soft terminal instruction, and no option-label context permits `Stop/Done`.
- `$superpowers-project:*` is the canonical user-facing namespace in README, plugin prompt text, issue docs, active skills, and metadata.
- `$project:*` is absent from active docs and active skill contracts except inside explicitly named historical plan files if old plans are intentionally left untouched.
- Missing issue workflow metadata fails `validate-issue-mirror.sh` for every mirror.
- Debug mode policy is centralized through `advanced-user-input` and every skill uses the same proof and guard requirements.
- `skills/*/agents/openai.yaml` remains parseable YAML, but `default_prompt` text is wrapped into readable physical lines with a validator-enforced line-length limit.
- Full repo validation and live sync validation pass before the implementation branch is considered ready.

## Non-Goals

- Do not redesign the whole workflow graph.
- Do not add compatibility wrappers or old-name forwarding skills.
- Do not edit deployed live plugin copies directly.
- Do not rewrite historical completed plan files unless a validator intentionally declares them active contract inputs.
- Do not make issue execution metadata lenient through a migration flag; the selected policy is strict for all mirrors.

## Test Complete And Metrics

Test complete means all of these commands exit `0` from the repo root:

```bash
git diff --check
./scripts/test-plugin-only-live-sync.sh
./scripts/test-native-continuation-loop.sh
./scripts/test-advanced-user-input-policy.sh
./scripts/test-project-namespace-migration.sh
./skills/align-project/scripts/test-scenarios.sh
./skills/create-issues/scripts/test-scenarios.sh
./scripts/validate.sh
./scripts/sync-live.sh --validate
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Pass/fail metrics:

- `scripts/validate.sh` returns JSON with `"ok": true`.
- `scripts/sync-live.sh --validate` returns JSON with `"ok": true` and no drift exception.
- Metadata line-length validator reports zero lines above the agreed limit.
- Native continuation validators report zero active `Stop/Done` option labels and zero plain active-contract `Stop or Done` instructions.
- Issue mirror validator rejects a fixture missing any workflow metadata field.

This is not scientific or numerical modeling work. No units, tolerances, statistical thresholds, or error bounds apply.

## File Map

Create:

- `scripts/lib/project-skills.sh`
- `scripts/lib/live-install.sh`
- `scripts/test-skill-metadata-readability.sh`

Modify:

- `README.md`
- `.codex-plugin/plugin.json`
- `docs/superpowers/closeout-startup-decision-tree-dev.md`
- `docs/superpowers/issues/README.md`
- `scripts/validate.sh`
- `scripts/sync-live.sh`
- `scripts/lib/sync-tree.sh`
- `scripts/test-advanced-user-input-policy.sh`
- `scripts/test-native-continuation-loop.sh`
- `scripts/test-plugin-only-live-sync.sh`
- `scripts/test-project-namespace-migration.sh`
- `skills/advanced-user-input/SKILL.md`
- `skills/advanced-user-input/agents/openai.yaml`
- `skills/align-project/SKILL.md`
- `skills/align-project/agents/openai.yaml`
- `skills/align-project/scripts/align-project.sh`
- `skills/align-project/scripts/test-scenarios.sh`
- `skills/audit-project/SKILL.md`
- `skills/audit-project/agents/openai.yaml`
- `skills/brainstorm-spec/SKILL.md`
- `skills/brainstorm-spec/agents/openai.yaml`
- `skills/create-issues/SKILL.md`
- `skills/create-issues/agents/openai.yaml`
- `skills/create-issues/scripts/validate-issue-mirror.sh`
- `skills/create-issues/scripts/test-scenarios.sh`
- `skills/implement-plan/SKILL.md`
- `skills/implement-plan/agents/openai.yaml`
- `skills/initiate-workflow/SKILL.md`
- `skills/initiate-workflow/agents/openai.yaml`
- `skills/merge-changes/SKILL.md`
- `skills/merge-changes/agents/openai.yaml`
- `skills/orchestrate-issues/SKILL.md`
- `skills/orchestrate-issues/agents/openai.yaml`
- `skills/resolve-issue/SKILL.md`
- `skills/resolve-issue/agents/openai.yaml`
- `skills/setup-project/SKILL.md`
- `skills/setup-project/agents/openai.yaml`
- `skills/write-plan/SKILL.md`
- `skills/write-plan/agents/openai.yaml`

## Task 1: Shared Skill Registry And Live-Install Drift Proof

**Files:**

- Create: `scripts/lib/project-skills.sh`
- Create: `scripts/lib/live-install.sh`
- Modify: `scripts/lib/sync-tree.sh`
- Modify: `scripts/sync-live.sh`
- Modify: `scripts/validate.sh`
- Modify: `scripts/test-plugin-only-live-sync.sh`
- Modify: `scripts/test-project-namespace-migration.sh`
- Modify: `skills/align-project/scripts/align-project.sh`
- Modify: `skills/align-project/scripts/test-scenarios.sh`

- [ ] **Step 1: Write the failing shared-registry tests**

  In `scripts/test-plugin-only-live-sync.sh`, dot-source `scripts/lib/project-skills.sh` and add checks with this exact intent:

  ```bash
  $active = @(Get-ProjectActiveSkillNames)
  $retired = @(Get-ProjectRetiredSkillNames)
  $intersection = @($active | Where-Object { $retired -contains $_ })
  if ($intersection.Count -ne 0) {
      throw "active skills must not be retired: $($intersection -join ', ')"
  }
  $sourceSkills = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "skills") -Directory | Select-Object -ExpandProperty Name | Sort-Object)
  if (($active | Sort-Object) -join "`n" -ne $sourceSkills -join "`n") {
      throw "active skill registry must match skills directory"
  }
  ```

  Expected first run:

  ```bash
  ./scripts/test-plugin-only-live-sync.sh
  ```

  Expected result before implementation: fail because `scripts/lib/project-skills.sh` does not exist.

- [ ] **Step 2: Write the failing live-install comparer test**

  In `scripts/test-plugin-only-live-sync.sh`, create temp source, live plugin, user skill, and marketplace roots. Copy a source tree, then mutate `live\skills/merge-changes\agents\openai.yaml` and `user\advanced-user-input\SKILL.md`. Assert `Compare-SuperpowersProjectLiveInstall` returns drift labels containing:

  ```text
  plugin skill merge-changes
  user skill advanced-user-input
  ```

  Expected result before implementation: fail because `Compare-SuperpowersProjectLiveInstall` does not exist.

- [ ] **Step 3: Write the failing Align LocalDocs drift scenario**

  In `skills/align-project/scripts/test-scenarios.sh`, add a scenario named `LocalDocs reports full plugin live drift`. The fixture should pass temp `-LivePluginRoot`, `-UserSkillsRoot`, and `-MarketplacePath` arguments to `align-project.sh`, mutate only `merge-changes/agents/openai.yaml`, and assert the resulting repairable findings contain `live-sync`.

  Expected result before implementation: fail because Align does not accept those live-install arguments and only compares the Align skill file.

- [ ] **Step 4: Implement the shared registry**

  Add `scripts/lib/project-skills.sh` with these functions:

  ```bash
  function Get-ProjectActiveSkillNames { @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "../../skills") -Directory | Sort-Object Name | Select-Object -ExpandProperty Name) }
  function Get-ProjectWorkflowSkillNames { @(Get-ProjectActiveSkillNames | Where-Object { $_ -ne "advanced-user-input" }) }
  function Get-ProjectFinalCapableSkillNames { @("align-project", "merge-changes") }
  function Get-ProjectUserSkillNames { @("advanced-user-input") }
  function Get-ProjectRetiredSkillNames { @("using-milestones", "setup-project-milestones", "explore-ideas", "milestone-writing-issue-plan", "convert-idea-to-issue", "project-writing-plan", "plan-to-issue", "resolve-issue-with-goal", "milestones-doctor", "project-context", "superpowers-project", "project-setup", "project-orchestrate", "project-brainstorm", "project-plan", "project-issue", "project-resolve", "project-merge", "project-doctor", "workflow", "setup") }
  function Get-ProjectOwnedSkillNames { @((Get-ProjectActiveSkillNames) + (Get-ProjectRetiredSkillNames) | Sort-Object -Unique) }
  function Get-ProjectCanonicalPromptNamespace { '$superpowers-project' }
  ```

  Keep the active list discovered from the source `skills` root. Keep current active skill names out of `Get-ProjectRetiredSkillNames`.

- [ ] **Step 5: Implement the live-install comparer**

  Add `scripts/lib/live-install.sh`. Dot-source `sync-tree.sh` and `project-skills.sh`. Implement `Compare-SuperpowersProjectLiveInstall` as a read-only function that compares:

  - `.codex-plugin` manifest directory
  - `assets` when source assets exist
  - each active plugin skill under live plugin root
  - each user skill from `Get-ProjectUserSkillNames`
  - marketplace entry name and `source.path`
  - retired live plugin roots `~/plugins/milestones` and `~/plugins/project`
  - stale owned skill directories under live plugin and user skill roots

  It must return objects shaped like:

  ```bash
  [pscustomobject]@{
      label = "plugin skill merge-changes"
      source = $sourcePath
      target = $targetPath
      drift = "content-diff"
      path = "agents/openai.yaml"
  }
  ```

  Add `Assert-SuperpowersProjectLiveInstallInSync` that throws when the comparer returns any drift object.

- [ ] **Step 6: Replace scattered active-skill lists**

  Update `scripts/sync-live.sh`, `scripts/validate.sh`, `scripts/test-native-continuation-loop.sh`, `scripts/test-project-namespace-migration.sh`, and `scripts/test-plugin-only-live-sync.sh` to consume `project-skills.sh`.

  In `scripts/sync-live.sh`, replace `$retiredSkillNames` with:

  ```bash
  $activeSkillNames = @(Get-ProjectActiveSkillNames)
  $userSkillNames = @(Get-ProjectUserSkillNames)
  $retiredSkillNames = @(Get-ProjectRetiredSkillNames)
  ```

  Keep `Remove-StaleOwnedSkillDirectories` parameter names unchanged unless Task 1 tests show a clearer rename is needed.

- [ ] **Step 7: Make sync and Align use the comparer**

  In `scripts/sync-live.sh`, after copying and marketplace sync, call `Assert-SuperpowersProjectLiveInstallInSync` instead of manually looping over one-off `Assert-NoTreeDrift` calls.

  In `skills/align-project/scripts/align-project.sh`, add parameters:

  ```bash
  [string]$LivePluginRoot = (Join-Path $HOME "plugins/superpowers-project"),
  [string]$UserSkillsRoot = (Join-Path $HOME ".agents\skills"),
  [string]$MarketplacePath = (Join-Path $HOME ".agents\plugins/marketplace.json")
  ```

  Replace the current two-file live check with `Compare-SuperpowersProjectLiveInstall`. Report any returned drift under repairable finding id `live-sync`; report healthy only when the comparer returns zero drift.

- [ ] **Step 8: Run targeted tests and commit**

  Run:

  ```bash
  ./scripts/test-plugin-only-live-sync.sh
  ./scripts/test-project-namespace-migration.sh
  ./skills/align-project/scripts/test-scenarios.sh
  ```

  Expected result: all return `"ok": true`.

  Commit:

  ```bash
  git add scripts/lib/project-skills.sh scripts/lib/live-install.sh scripts/lib/sync-tree.sh scripts/sync-live.sh scripts/validate.sh scripts/test-plugin-only-live-sync.sh scripts/test-project-namespace-migration.sh skills/align-project/scripts/align-project.sh skills/align-project/scripts/test-scenarios.sh
  git commit -m "test: harden live plugin drift checks"
  ```

## Task 2: Final Gate Schema, Align Done Gate, And Terminal Wording

**Files:**

- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `skills/align-project/SKILL.md`
- Modify: `skills/align-project/agents/openai.yaml`
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `README.md`
- Modify: `docs/superpowers/closeout-startup-decision-tree-dev.md`
- Modify: `scripts/test-advanced-user-input-policy.sh`
- Modify: `scripts/test-native-continuation-loop.sh`
- Modify: `skills/align-project/scripts/test-scenarios.sh`

- [ ] **Step 1: Write failing final-gate schema tests**

  In `scripts/test-advanced-user-input-policy.sh`, replace the current final-gate expectation with these required strings:

  ```text
  Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop
  Verified final health gates use exactly three top-level options: Done, Revisit, and Stop
  Done is invalid whenever ``git status --short`` is non-empty
  A verified final Done gate requires final proof and a clean worktree
  ```

  Add forbidden checks for:

  ```text
  Stop/Done
  Final clean closeout gates may use exactly three top-level options: Yes, Revisit, and Done
  ```

  Expected first run:

  ```bash
  ./scripts/test-advanced-user-input-policy.sh
  ```

  Expected result before implementation: fail on the old `Yes`, `Revisit`, `Done` final-gate text.

- [ ] **Step 2: Write failing final-capable skill tests**

  In `scripts/test-native-continuation-loop.sh`, for each skill from `Get-ProjectFinalCapableSkillNames`, require a question block ending in `_final_health_gate` that contains:

  ```text
  Done
  Revisit
  Stop
  git status --short
  ```

  Add a regex check that fails if any final-health block offers `Yes`.

  Expected result before implementation: fail for `align-project` because no `project_align_final_health_gate` exists.

- [ ] **Step 3: Implement the shared final-gate policy**

  In `skills/advanced-user-input/SKILL.md` and metadata, state:

  ```text
  Intermediate closeout gates use exactly three top-level options: Yes, Revisit, and Stop.
  Verified final health gates use exactly three top-level options: Done, Revisit, and Stop.
  Done is valid only after required verification, cleanup, and clean `git status --short` proof.
  Stop remains selectable for user control but must not be recommended while a safe forward route exists.
  ```

  Replace plain active-contract phrasing that says `Stop or Done` with:

  ```text
  If a custom answer requests `Stop` or `Done`, ask a fresh confirmation question with separate built-in labels.
  ```

  Do the same replacement in all active skill `SKILL.md` files and `agents/openai.yaml` files where the plain soft phrase appears.

- [ ] **Step 4: Add Align's final health gate**

  In `skills/align-project/SKILL.md`, add this gate after `project_align_next_step` and before nested repair routes:

  ```markdown
  Question id: `project_align_final_health_gate`

  Prompt: `Alignment is healthy. Should I close this workflow as done?`

  Options:

  - `Done`: close only when the audit has no blocking or repairable findings, no remaining repair route, cleanup passed, and `git status --short` is clean.
  - `Revisit`: review findings, rerun Align, or gather more evidence before deciding.
  - `Stop`: pause without claiming final completion.
  ```

  In Align metadata, add the same `project_align_final_health_gate` name and the same three labels.

- [ ] **Step 5: Normalize merge final-gate wording**

  Keep `project_merge_final_health_gate` using `Done`, `Revisit`, `Stop`. Update any surrounding text that implies final gates use `Yes`.

  In `docs/superpowers/closeout-startup-decision-tree-dev.md`, replace the mismatch note with the new shared schema and explicitly say Align and Merge are final-capable.

- [ ] **Step 6: Run targeted tests and commit**

  Run:

  ```bash
  ./scripts/test-advanced-user-input-policy.sh
  ./scripts/test-native-continuation-loop.sh
  ./skills/align-project/scripts/test-scenarios.sh
  ```

  Expected result: all return `"ok": true`.

  Commit:

  ```bash
  git add skills scripts README.md docs/superpowers/closeout-startup-decision-tree-dev.md
  git commit -m "fix: normalize final continuation gates"
  ```

## Task 3: Canonical `$superpowers-project:*` Namespace

**Files:**

- Modify: `README.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `docs/superpowers/issues/README.md`
- Modify: `scripts/test-project-namespace-migration.sh`
- Modify: active `skills/*/SKILL.md`
- Modify: active `skills/*/agents/openai.yaml`

- [ ] **Step 1: Write the failing namespace scan**

  In `scripts/test-project-namespace-migration.sh`, require:

  ```bash
  Assert-Contains -Text $readme -Needle 'prompt surface is `$superpowers-project:*`' -Reason "README must declare canonical prompt surface"
  ```

  Add a scan over `README.md`, `.codex-plugin/plugin.json`, `docs/superpowers/issues/README.md`, `skills/*/SKILL.md`, and `skills/*/agents/openai.yaml` that fails on `'$project:'`.

  Add a manifest prompt check that every `superpowers-project:` prompt string is written as `$superpowers-project:`.

  Expected first run:

  ```bash
  ./scripts/test-project-namespace-migration.sh
  ```

  Expected result before implementation: fail on `docs/superpowers/issues/README.md` and `.codex-plugin/plugin.json`.

- [ ] **Step 2: Update canonical namespace text**

  Update README line-level meaning to:

  ```text
  The canonical plugin identity is `superpowers-project`, the GitHub repository is `tannerpolley/superpowers-project`, and the canonical user-facing prompt surface is `$superpowers-project:*`.
  ```

  In `.codex-plugin/plugin.json`, update every prompt from:

  ```text
  Use superpowers-project:<skill>
  ```

  to:

  ```text
  Use $superpowers-project:<skill>
  ```

  In `docs/superpowers/issues/README.md`, replace every `$project:<skill>` with `$superpowers-project:<skill>`.

- [ ] **Step 3: Update active skill references**

  Run:

  ```bash
  rg -n '\$project:|(?<!\$)superpowers-project:' README.md .codex-plugin docs/superpowers/issues skills
  ```

  Update only active contract text to canonical `$superpowers-project:*`. Keep `plugin manifest name` and filesystem names as `superpowers-project`.

- [ ] **Step 4: Run targeted tests and commit**

  Run:

  ```bash
  ./scripts/test-project-namespace-migration.sh
  ```

  Expected result: returns `"ok": true`.

  Commit:

  ```bash
  git add README.md .codex-plugin/plugin.json docs/superpowers/issues/README.md skills scripts/test-project-namespace-migration.sh
  git commit -m "docs: standardize project plugin namespace"
  ```

## Task 4: Strict Issue Workflow Metadata

**Files:**

- Modify: `skills/create-issues/SKILL.md`
- Modify: `skills/create-issues/agents/openai.yaml`
- Modify: `skills/create-issues/scripts/validate-issue-mirror.sh`
- Modify: `skills/create-issues/scripts/test-scenarios.sh`
- Modify: `docs/superpowers/issues/README.md`

- [ ] **Step 1: Write the failing strict-metadata scenario**

  In `skills/create-issues/scripts/test-scenarios.sh`, add a scenario named `issue mirror validator rejects missing workflow metadata`. Create a temp issue mirror with source plan, GitHub issue, classification, goal command, acceptance criteria, and Project Merge section, but omit `Execution Mode`.

  Assert:

  ```bash
  $result = Run-Validator -RepoRoot $root -IssuePath $issuePath
  if ($result.ok) { throw "missing workflow metadata must fail validation" }
  if (-not ([string]$result.reason).Contains("Execution Mode is required")) {
      throw "missing metadata reason must name Execution Mode"
  }
  ```

  Expected first run:

  ```bash
  ./skills/create-issues/scripts/test-scenarios.sh
  ```

  Expected result before implementation: fail because missing workflow metadata is currently advisory.

- [ ] **Step 2: Make missing workflow metadata blocking**

  In `skills/create-issues/scripts/validate-issue-mirror.sh`, replace:

  ```bash
  Add-Check -Name "workflow metadata: $fieldName" -Ok $false -Reason "advisory: missing"
  continue
  ```

  with:

  ```bash
  Complete -Ok $false -Reason "$fieldName is required"
  ```

  Keep malformed allowed-value checks unchanged.

- [ ] **Step 3: Update docs and metadata**

  In `skills/create-issues/SKILL.md`, replace the migration-advisory wording with:

  ```text
  Workflow metadata guides `$superpowers-project:resolve-issue` and `$superpowers-project:orchestrate-issues`. Missing or malformed metadata is blocking for every issue mirror because it creates ambiguous execution instructions.
  ```

  Replace the self-review line:

  ```text
  workflow metadata is present or reported as advisory migration drift
  ```

  with:

  ```text
  workflow metadata is present and valid
  ```

  Mirror the same policy in `skills/create-issues/agents/openai.yaml` and `docs/superpowers/issues/README.md`.

- [ ] **Step 4: Run targeted tests and commit**

  Run:

  ```bash
  ./skills/create-issues/scripts/test-scenarios.sh
  ```

  Expected result: returns `"ok": true`.

  Commit:

  ```bash
  git add skills/create-issues docs/superpowers/issues/README.md
  git commit -m "fix: require issue workflow metadata"
  ```

## Task 5: Central Debug Mode Guard

**Files:**

- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: active `skills/*/SKILL.md`
- Modify: active `skills/*/agents/openai.yaml`
- Modify: `scripts/test-advanced-user-input-policy.sh`
- Modify: `scripts/test-native-continuation-loop.sh`

- [ ] **Step 1: Write failing debug-policy tests**

  In `scripts/test-advanced-user-input-policy.sh`, require advanced-user-input to contain these exact policy fragments:

  ```text
  Native Question Debug Mode
  no tool exists to answer the modal prompt
  observed_status: waitingOnUserInput
  thread_id
  question_id
  answer_source
  debug mode must not approve mutation
  ```

  In `scripts/test-native-continuation-loop.sh`, scan every workflow skill `SKILL.md` and metadata file that contains `debug_question_mode`. Fail unless it also contains `no tool exists to answer the modal prompt` and `Native Question Debug Ledger`.

  Expected result before implementation: fail for the weaker local debug-mode paragraphs.

- [ ] **Step 2: Centralize the policy**

  In `skills/advanced-user-input/SKILL.md`, add a `## Native Question Debug Mode` section with exact ledger fields:

  ```yaml
  skill_name: <canonical skill name>
  thread_id: <Codex thread id when available>
  observed_status: waitingOnUserInput
  question_id: <native question id>
  prompt: <native prompt text>
  options: [<visible labels>]
  recommended_option: <label>
  selected_answer: <label or debug answer>
  answer_source: recommended-default | user-provided-debug-answer
  no_answer_tool_available: true
  mutation_allowed: false
  ```

  State directly that debug mode is only for explicit non-interactive smoke tests or a background native prompt proven stuck in `waitingOnUserInput`, and only when no tool exists to answer the modal prompt.

- [ ] **Step 3: Replace weaker local paragraphs**

  In each workflow skill and metadata file, replace local debug-mode text with a reference to `advanced-user-input` plus the strict guard. The local paragraph must still include:

  ```text
  debug_question_mode
  Native Question Debug Ledger
  no tool exists to answer the modal prompt
  must not approve mutation
  ```

  Keep route-specific mutation limits, such as "must not publish GitHub issues" or "must not perform repairs", where they are stricter.

- [ ] **Step 4: Run targeted tests and commit**

  Run:

  ```bash
  ./scripts/test-advanced-user-input-policy.sh
  ./scripts/test-native-continuation-loop.sh
  ```

  Expected result: both return `"ok": true`.

  Commit:

  ```bash
  git add skills scripts/test-advanced-user-input-policy.sh scripts/test-native-continuation-loop.sh
  git commit -m "docs: centralize native question debug policy"
  ```

## Task 6: Readable Metadata Prompts

**Files:**

- Create: `scripts/test-skill-metadata-readability.sh`
- Modify: `scripts/validate.sh`
- Modify: active `skills/*/agents/openai.yaml`

- [ ] **Step 1: Write the failing metadata readability test**

  Add `scripts/test-skill-metadata-readability.sh`. It must:

  - Resolve every `skills/*/agents/openai.yaml`
  - Parse each file through the same Python/PyYAML path used by `scripts/validate.sh`
  - Fail when any physical line exceeds 240 characters
  - Fail when `default_prompt` is empty
  - Report each failure as `path:line:length`

  The core line check should be:

  ```bash
  $maxLength = 240
  $lines = Get-Content -LiteralPath $yamlPath
  for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Length -gt $maxLength) {
          throw "$yamlPath:$($i + 1):$($lines[$i].Length) exceeds $maxLength"
      }
  }
  ```

  Wire it into `scripts/validate.sh` as `Skill metadata readability`.

  Expected first run:

  ```bash
  ./scripts/test-skill-metadata-readability.sh
  ```

  Expected result before implementation: fail because current `default_prompt` lines are thousands of characters long.

- [ ] **Step 2: Rewrap metadata without changing meaning**

  For every active `skills/*/agents/openai.yaml`, keep `default_prompt: >-` but wrap the prompt at sentence or clause boundaries so every physical line is below 240 characters.

  Do not delete route names, question ids, option labels, or proof requirements while wrapping. Preserve `$superpowers-project:*` references from Task 3.

- [ ] **Step 3: Run targeted tests and commit**

  Run:

  ```bash
  ./scripts/test-skill-metadata-readability.sh
  ./scripts/validate.sh -SkipScenarioTests
  ```

  Expected result: both commands return success.

  Commit:

  ```bash
  git add scripts/test-skill-metadata-readability.sh scripts/validate.sh skills
  git commit -m "docs: wrap skill metadata prompts"
  ```

## Task 7: End-To-End Validation, Sync, And Ready State

**Files:**

- Modify only if previous tasks expose a final validation wiring gap.

- [ ] **Step 1: Run whitespace and targeted validators**

  Run:

  ```bash
  git diff --check
  ./scripts/test-plugin-only-live-sync.sh
  ./scripts/test-native-continuation-loop.sh
  ./scripts/test-advanced-user-input-policy.sh
  ./scripts/test-project-namespace-migration.sh
  ./scripts/test-skill-metadata-readability.sh
  ./skills/align-project/scripts/test-scenarios.sh
  ./skills/create-issues/scripts/test-scenarios.sh
  ```

  Expected result: every command exits `0`.

- [ ] **Step 2: Run full validation**

  Run:

  ```bash
  ./scripts/validate.sh
  ```

  Expected result: final JSON contains `"ok": true`.

- [ ] **Step 3: Sync live install from source**

  Run:

  ```bash
  ./scripts/sync-live.sh --validate
  ```

  Expected result: final JSON contains `"ok": true`, `deployed_plugin_skills` lists all active skills, and `deployed_user_skills` lists `advanced-user-input`.

- [ ] **Step 4: Run cleanup**

  Run:

  ```bash
  "$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
  ```

  Expected result: no leftover Codex processes under the repo root.

- [ ] **Step 5: Commit final validation wiring**

  If Task 7 needed edits, commit them:

  ```bash
  git add .
  git commit -m "test: validate plugin contract hardening"
  ```

  If Task 7 needed no edits, record the validation and sync output in the final handoff instead of creating an empty commit.

## Risk Notes

- Rewrapping metadata is broad and mechanical. Keep it isolated in Task 6 so behavioral diffs from Tasks 1 through 5 stay reviewable.
- Adding strict issue metadata may cause old mirrors in this repo or downstream repos to fail. That is intentional per the selected policy; repair those mirrors rather than adding leniency.
- Align's live-install comparer must stay read-only. Mutations remain owned by `scripts/sync-live.sh` and require the existing approval path.
- Namespace standardization is user-facing only. Do not rename skill directories or plugin manifest identity.

## Self-Review

- Save path is under `docs/superpowers/plans`.
- Source spec is `docs/superpowers/specs/2026-06-10-plugin-contract-softness-audit-findings.md`.
- Every audit finding maps to at least one task:
  - Finding 1: Task 1
  - Finding 2: Task 2
  - Finding 3: Task 2
  - Finding 4: Task 2
  - Finding 5: Task 3
  - Finding 6: Task 1
  - Finding 7: Task 1
  - Finding 8: Task 6
  - Finding 9: Task 5
  - Finding 10: Task 4
- TDD is required for all code and validator changes.
- Completion requires `superpowers:verification-before-completion` before any worker claims the plan is complete.
- Bug-specific systematic debugging is not required because this is contract hardening, not a runtime failure fix.
