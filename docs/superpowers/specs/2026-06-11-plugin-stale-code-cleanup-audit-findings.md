# Plugin Stale Code Cleanup Audit Findings

## Scope And Review Question

Audit the Superpowers Project plugin source for remaining inefficiencies, stale code, stale terminology, or cleanup candidates after the recent contract-hardening work. The review focused on active source files, validation scripts, workflow skill scripts, README/contract summaries, and repo-owned agent configuration.

## Companion Skills Used

- `$superpowers-project:audit-project`
- `thermo-nuclear-code-quality-review`

## Checked Artifacts

- `skills/**/SKILL.md`
- `skills/**/agents/openai.yaml`
- `skills/**/scripts/**/*.ps1`
- `scripts/**/*.ps1`
- `README.md`
- `AGENTS.md`
- `docs/agents/project-roadmap.json`
- `docs/agents/project-roadmap.md`
- `docs/superpowers/CONTRACT_SUMMARY.md`
- `docs/superpowers/PROJECT_CONTEXT.md`

Commands used:

```powershell
git status --short --branch
rg -n "Stop/Done|Stop or Done|stale terminal label|stale terminal option|goal_board|goalbuddy|namespace wrapper|compatibility wrapper|fallback|obsolete|legacy|TODO|FIXME|not_implemented|not_available|debug_question_mode|Use Cases" skills scripts README.md docs/superpowers/CONTRACT_SUMMARY.md -g "*.md" -g "*.ps1" -g "*.yaml"
rg -n "convert-idea-to-issue|milestones-validate|docs/ideas|docs/milestones/<milestone-folder>|canonical-skills|goalbuddy|GoalBuddy|Stop/Done|stale terminal label|stale terminal option|fallback|compatibility wrapper|namespace wrapper" scripts skills README.md AGENTS.md docs/superpowers/CONTRACT_SUMMARY.md docs/superpowers/PROJECT_CONTEXT.md docs/agents -g "*.ps1" -g "*.md" -g "*.yaml" -g "*.json"
```

## Findings

### P2: Retired Root Coverage Is Incomplete In Active Validation

Evidence:

- `AGENTS.md:16` forbids `docs/ideas`, root-level `docs/issues`, root-level `docs/plans`, and retired `docs/milestones/<milestone-folder>/ideas|issues|plans`.
- `scripts/validate.ps1:149-153` only checks `docs/milestones/<milestone-folder>/ideas`, `docs/milestones/<milestone-folder>/issues`, `docs/plans`, and `docs/issues`.
- `docs/agents/project-roadmap.json:29-33` mirrors the same incomplete set.

Impact:

The active validator and roadmap config omit `docs/ideas` and `docs/milestones/<milestone-folder>/plans`, even though repo policy forbids both. That leaves two stale canonical roots as policy-only constraints rather than enforced constraints.

Repair Requirement:

Add `docs/ideas` and `docs/milestones/<milestone-folder>/plans` to the active forbidden-root contract in `scripts/validate.ps1` and `docs/agents/project-roadmap.json`. Add a regression check that fails if AGENTS-level forbidden roots are missing from the validator/config surface.

Proof Oracle:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P2: Dead Retired-Skill Allowlist Remains In The Stale Scan

Evidence:

- `scripts/validate.ps1:345-347` defines `$allowedNegativeFixture = "skills\convert-idea-to-issue\scripts\test-scenarios.ps1"`.
- `Test-Path skills\convert-idea-to-issue\scripts\test-scenarios.ps1` returned `False`.
- `scripts/lib/project-skills.ps1:42` already records `convert-idea-to-issue` as a retired skill name.

Impact:

The stale-reference scan carries an allowlist exception for a fixture path that no longer exists. This is dead validation code and makes the scan harder to reason about because a future matching path could be silently excused by an obsolete exception.

Repair Requirement:

Remove the dead `$allowedNegativeFixture` filter or replace it with an existence-checked fixture policy that fails if an allowlisted path does not exist. Keep `convert-idea-to-issue` in the retired-skill registry only if live cleanup still needs ownership of that retired name.

Proof Oracle:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
rg -n "convert-idea-to-issue" scripts\validate.ps1
```

### P2: Resolve And Merge Contract Libraries Duplicate Core Helpers

Evidence:

- `skills/resolve-issue/scripts/lib/contract.ps1:3`, `:15`, `:20`, `:25`, `:30`, `:44`, `:54`, `:60`, `:67`, `:73`, `:88`, `:103`, `:243`, and `:249` define common helper functions.
- `skills/merge-changes/scripts/lib/contract.ps1:20`, `:32`, `:37`, `:42`, `:47`, `:61`, `:82`, `:104`, `:111`, `:117`, `:122`, `:137`, `:143`, and `:149` define the same helper function names.
- The overlapping functions are `Write-ContractResult`, `Stop-Contract`, `Complete-Contract`, `Test-Property`, `Read-JsonInput`, `Get-StringArray`, `Normalize-RepoPath`, `Resolve-RepoRoot`, `Resolve-RepoFile`, `Get-RelativeRepoPath`, `Get-FieldValue`, `Get-IssueNumberFromUrl`, `Test-ClosingKeywordForIssue`, and `Test-ClosingReferenceIncludesIssue`.

Impact:

Two workflow-contract libraries now carry 14 duplicated helpers. Any bug fix to JSON handling, repo path normalization, field parsing, or issue closing detection must be applied twice. This is exactly the kind of duplicated support code that becomes stale quietly.

Repair Requirement:

Extract the shared helpers into one source-owned PowerShell library, then dot-source it from both workflow contract files. Keep resolve-specific and merge-specific assertions in their current files.

Proof Oracle:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\resolve-issue\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\merge-changes\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P2: Audit Findings Specs Cannot Originate Auto Mode

Evidence:

- `docs/superpowers/CONTRACT_SUMMARY.md:37` lists `audit-project` question ids as `project_audit_next_step`, `project_audit_progress_route`, and `project_audit_revisit_route`, with no `project_auto_mode_authorization`.
- `docs/superpowers/CONTRACT_SUMMARY.md:38` lists `project_auto_mode_authorization` only under `brainstorm-spec`.
- `README.md:48` documents Auto Mode after Brainstorm Spec, while `README.md:57` documents Audit Project next routes as Write Plan, Create Issues, and Review Findings.
- `skills/audit-project/SKILL.md:103-112` defines only `Write Plan` and `Create Issues` for the audit progress route.

Impact:

Audit findings are saved under `docs/superpowers/specs`, but they cannot directly enter the same bounded Auto Mode path available after brainstorm-created specs. That makes "after spec creation" inconsistent: a brainstorm spec can authorize Auto Mode, while an audit findings spec must fall back to manual planning even when it has sufficient evidence and the user wants bounded automation.

Repair Requirement:

Add an Auto Mode route to `$superpowers-project:audit-project` after a findings spec is saved and self-reviewed. The route must ask `project_auto_mode_authorization`, validate the ledger with `scripts/validate-auto-mode-authorization.ps1`, and then continue into `$superpowers-project:write-plan` with the audit findings spec as the source spec. Keep the same bounded policy as brainstorm Auto Mode: `bounded-auto-merge`, `recorded-defaults`, `issue-backed-orchestrate-only`, `preauthorized-after-clean-premerge`, and `stop_outside_policy: true`.

Proof Oracle:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\audit-project\scripts\test-scenarios.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-contract-summary.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P3: Main Validator Still Uses Retired Milestone Naming For Temp Output

Evidence:

- `scripts/validate.ps1:57` creates temporary output under a prefix named `milestones-validate-`.

Impact:

The repo no longer uses the old milestones plugin/source model as the active identity. This prefix is low-risk, but it is stale terminology in the primary validation entry point and makes logs harder to interpret.

Repair Requirement:

Rename the temp prefix to `superpowers-project-validate-` or `project-validate-`.

Proof Oracle:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

### P3: Stale Terminal Placeholder Text Still Appears In Active Test Sources

Evidence:

- `scripts/test-native-qa-svg.ps1:239` contains `stale terminal label`.
- `scripts/test-native-continuation-loop.ps1:269`, `:311`, and `:312` contain `stale terminal label` or `stale terminal option`.
- `scripts/test-advanced-user-input-policy.ps1:120-122` contains old `stale terminal option` policy text as forbidden examples.
- `rg -l "stale terminal label|stale terminal option" skills scripts README.md docs/superpowers/CONTRACT_SUMMARY.md` found 12 files containing `stale terminal label` and 2 files containing `stale terminal option`, all in tests.

Impact:

These hits are test-side forbidden fixtures, not active prompt contracts. Still, keeping the exact stale phrases in active test source creates search noise and makes future agents spend time distinguishing real stale behavior from test fixtures.

Repair Requirement:

Rename the fixture terminology to neutral language such as `legacy terminal placeholder`, or construct the old strings in tests from fragments so broad stale-term searches can return zero active-source hits without weakening the assertions.

Proof Oracle:

```powershell
rg -n "stale terminal label|stale terminal option" skills scripts README.md docs/superpowers/CONTRACT_SUMMARY.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-advanced-user-input-policy.ps1
```

### P3: Debug-Mode Contract Text Is Hand-Copied Across Workflow Surfaces

Evidence:

- `Native Question Debug Ledger` appears in 18 active files.
- `debug_question_mode` appears in 26 active files.
- The repeated policy block appears in every workflow skill that supports native continuation behavior, plus metadata and tests.

Impact:

The duplication is understandable because skill bodies need to be self-contained, but it is still inefficient hand-maintained contract text. The risk is drift: one workflow can keep older debug-mode wording while another gets tightened.

Repair Requirement:

Do not remove self-contained skill instructions blindly. Instead, create one source-owned debug-mode contract snippet or generator and validate that generated/copied surfaces match it. If generated snippets are not acceptable, at least add a focused hash or marker-based validator so the repeated policy cannot drift silently.

Proof Oracle:

```powershell
rg -l "Native Question Debug Ledger" skills scripts README.md docs/superpowers/CONTRACT_SUMMARY.md
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-native-continuation-loop.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

## Non-Findings And Healthy Checks

- The active source did not contain a live `Stop/Done` option-label contract. Remaining `Stop/Done` hits were in historical specs/plans outside active prompt and validation surfaces.
- `GoalBuddy` references in `skills/resolve-issue` are active guardrails, not removable stale code. The current resolver explicitly rejects GoalBuddy board fields because GoalBuddy boards are outside the default execution model.
- `scripts/lib/project-skills.ps1` keeps retired skill names for cleanup ownership. That list should not be deleted wholesale without proving `sync-live.ps1` and live cleanup no longer need those names.
- `docs/agents/project-roadmap.json` intentionally records forbidden roots as configuration, not as active artifact targets. The issue is incompleteness, not the presence of forbidden-root examples.

## Recommended Repair Route

Default route: `$superpowers-project:write-plan`.

The repair work is small enough for one implementation plan with these task groups:

1. Align forbidden-root validation with AGENTS policy.
2. Remove the dead stale-scan allowlist and stale temp naming.
3. Extract duplicated resolve/merge contract helpers.
4. Add Auto Mode authorization after audit findings specs.
5. Rename or fragment stale terminal placeholder fixtures.
6. Decide whether debug-mode policy duplication should become generated/validated rather than hand-copied.

## Open Questions Blocking Planning

- Should the debug-mode duplication be treated as a repair now, or left as intentionally self-contained skill text with only stronger validation?
- Should exact old terminal placeholder strings be allowed in tests, or should the repo aim for zero broad-search hits in active source?
