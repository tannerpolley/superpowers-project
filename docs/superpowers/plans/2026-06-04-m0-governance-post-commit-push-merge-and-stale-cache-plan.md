# Workflow Governance Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce explicit post-commit push approval, block final `Done` on dirty worktrees, fix the Auto Mode authorization helper/object-shape gap, and keep repo-owned workflow contracts and tests aligned.

**Architecture:** Update the repo at three layers together: shared continuation policy text and repo-level tests, per-skill workflow contracts plus their concrete Bash validators/collectors, and the Auto Mode authorization helper that gates the route after brainstorming. Keep the work in the source repo only, validate locally, then run live-sync validation so source and installed copies stay aligned.

**Tech Stack:** Bash 7, Markdown skill contracts, repo validation scripts, git, local live-sync tooling

---

**Source Spec:** `docs/superpowers/specs/2026-06-04-post-commit-push-merge-and-stale-cache-design.md`

**Milestone:** `M0 - Governance`, `M1 - Source Of Truth`

**Execution Route:** `Project Implement` is the right downstream route after this plan because this repo policy explicitly allows routine plugin-skill maintenance without creating issue mirrors, and the work is repo-owned contract/test hardening rather than tracker-first feature delivery.

## Acceptance Criteria

- Shared continuation policy states that final `Done` is invalid when `git status --short` is non-empty.
- `audit-project` cannot reach its healthy final `Done` path while the repo has uncommitted changes.
- `implement-plan` asks an explicit push gate after commit-producing work and before any merge route is available.
- `resolve-issue` asks an explicit push gate after verification and before branch push / PR creation.
- `merge-changes` keeps explicit merge approval and explicitly ties final `Done` to clean closeout plus clean worktree state.
- The Auto Mode authorization helper accepts both plain and ordered ledger objects with the same valid fields.
- Repo tests fail when any of those rules regress.
- `./scripts/validate.sh` passes.
- `./scripts/sync-live.sh --validate` passes.

## Non-Goals

- Do not repair plugin cache files directly.
- Do not weaken merge approval, PR-ready proof, or closeout proof.
- Do not introduce fallback behavior that silently skips push/merge questions.
- Do not route this work through new GitHub issue mirrors unless implementation uncovers a separate tracker problem that actually needs them.

## Proof Oracle

- `./scripts/test-auto-mode-contract.sh`
- `./scripts/test-advanced-user-input-policy.sh`
- `./scripts/test-native-continuation-loop.sh`
- `./skills/audit-project/scripts/test-scenarios.sh`
- `./skills/implement-plan/scripts/test-scenarios.sh`
- `./skills/resolve-issue/scripts/test-scenarios.sh`
- `./skills/merge-changes/scripts/test-scenarios.sh`
- `./scripts/validate.sh`
- `./scripts/sync-live.sh --validate`

## Risks And Dependencies

- `implement-plan` and `resolve-issue` already have concrete contract validators; if the docs change without the validators, the workflow will still be weak.
- `audit-project` currently relies on report categories to define whether the repo is healthy. Dirty-worktree blocking should therefore exist in the audit script itself, not only in prose.
- `merge-changes` already enforces clean repo proof in its closeout path, so the main risk there is contract drift between Markdown/YAML and validator behavior.
- The Auto Mode helper bug is object-shape-sensitive. Tests need to cover both `@{}` and `[ordered]@{}` so a refactor cannot reintroduce the same failure mode.

### Task 1: Harden shared continuation policy and Auto Mode helper behavior

**Files:**
- Modify: `skills/advanced-user-input/SKILL.md`
- Modify: `skills/advanced-user-input/agents/openai.yaml`
- Modify: `scripts/lib/auto-mode-contract.sh`
- Modify: `scripts/test-advanced-user-input-policy.sh`
- Modify: `scripts/test-native-continuation-loop.sh`
- Modify: `scripts/test-auto-mode-contract.sh`
- Test: `scripts/test-auto-mode-contract.sh`
- Test: `scripts/test-advanced-user-input-policy.sh`
- Test: `scripts/test-native-continuation-loop.sh`

- [ ] **Step 1: Add the failing helper regression test for ordered ledgers**

```bash
Invoke-Scenario "ordered authorization passes" {
    $plain = New-HappyAuthorization
    $auth = [ordered]@{}
    foreach ($entry in $plain.GetEnumerator()) { $auth[$entry.Key] = $entry.Value }
    $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
    if (-not $result.ok) { throw $result.reason }
}
```

- [ ] **Step 2: Add the failing shared-policy checks for dirty-worktree final Done rules**

```bash
foreach ($needle in @(
    "Done is invalid whenever `git status --short` is non-empty",
    "A clean worktree is required before any verified final Done gate"
)) {
    Add-Check $checks "advanced-user-input contains $needle" ($text.Contains($needle)) "$skillPath must contain policy: $needle"
}
```

- [ ] **Step 3: Update the Auto Mode helper so it accepts ordered dictionaries and PSCustomObject ledgers**

```bash
function Has-AuthProperty {
    param([object]$Object, [string]$Name)
    if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
    return $null -ne $Object -and (@($Object.PSObject.Properties.Name) -contains $Name)
}
```

- [ ] **Step 4: Update the shared continuation contract text and metadata to state that dirty repos block final Done**

```markdown
Done is invalid whenever `git status --short` is non-empty.
A verified final Done gate requires both final proof and a clean worktree.
```

- [ ] **Step 5: Run the targeted shared-policy tests and verify they pass**

```bash
./scripts/test-auto-mode-contract.sh
./scripts/test-advanced-user-input-policy.sh
./scripts/test-native-continuation-loop.sh
```

Expected: all three scripts exit `0`, and the ordered-ledger scenario passes instead of failing with `missing question_id`.

- [ ] **Step 6: Commit the shared-policy/helper hardening**

```bash
git add skills/advanced-user-input/SKILL.md skills/advanced-user-input/agents/openai.yaml scripts/lib/auto-mode-contract.sh scripts/test-advanced-user-input-policy.sh scripts/test-native-continuation-loop.sh scripts/test-auto-mode-contract.sh
git commit -m "Harden final Done and Auto Mode helper contracts"
```

### Task 2: Make Project Doctor report dirty worktrees as non-final state

**Files:**
- Modify: `skills/audit-project/SKILL.md`
- Modify: `skills/audit-project/agents/openai.yaml`
- Modify: `skills/audit-project/scripts/audit-project.sh`
- Modify: `skills/audit-project/scripts/test-scenarios.sh`
- Test: `skills/audit-project/scripts/test-scenarios.sh`

- [ ] **Step 1: Add a failing audit scenario for a dirty repo**

```bash
Invoke-Scenario "dirty worktree is repairable drift" {
    $repo = New-TestRepo
    Set-Content -LiteralPath (Join-Path $repo "DIRTY.txt") -Value "dirty`n" -Encoding utf8NoBOM
    $audit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "LocalDocs")
    Assert-Contains (($audit.findings.repairable | ConvertTo-Json -Depth 12)) "dirty-worktree" "dirty repo was not reported as repairable drift"
}
```

- [ ] **Step 2: Add git-worktree inspection to the audit script**

```bash
$statusOutput = (& git -C $RepoRoot status --short 2>$null | Out-String).Trim()
if (-not [string]::IsNullOrWhiteSpace($statusOutput)) {
    $findings.repairable.Add([ordered]@{
        key = "dirty-worktree"
        reason = "repo has uncommitted changes, so healthy final Done is invalid"
        evidence = @{ status_output = $statusOutput }
    })
}
```

- [ ] **Step 3: Tighten the Doctor closeout wording in both Markdown surfaces**

```markdown
For `audit-project`, final `Done` is valid only when the audit is healthy, no repair route remains, and the git worktree is clean.
If the repo has uncommitted changes, route to repair/commit/push/hold work instead of asking `Done`.
```

- [ ] **Step 4: Run the Doctor scenario script**

```bash
./skills/audit-project/scripts/test-scenarios.sh
```

Expected: the new dirty-worktree scenario passes, and existing LocalDocs/GitHubAware coverage stays green.

- [ ] **Step 5: Commit the Doctor dirty-worktree hardening**

```bash
git add skills/audit-project/SKILL.md skills/audit-project/agents/openai.yaml skills/audit-project/scripts/audit-project.sh skills/audit-project/scripts/test-scenarios.sh
git commit -m "Block Doctor final Done on dirty worktrees"
```

### Task 3: Add explicit push gates to implement-plan and resolve-issue

**Files:**
- Modify: `skills/implement-plan/SKILL.md`
- Modify: `skills/implement-plan/agents/openai.yaml`
- Modify: `skills/implement-plan/scripts/lib/contract.sh`
- Modify: `skills/implement-plan/scripts/test-scenarios.sh`
- Modify: `skills/resolve-issue/SKILL.md`
- Modify: `skills/resolve-issue/agents/openai.yaml`
- Modify: `skills/resolve-issue/scripts/collect-pr-ready-ledger.sh`
- Modify: `skills/resolve-issue/scripts/validate-pr-ready.sh`
- Modify: `skills/resolve-issue/scripts/test-scenarios.sh`
- Test: `skills/implement-plan/scripts/test-scenarios.sh`
- Test: `skills/resolve-issue/scripts/test-scenarios.sh`

- [ ] **Step 1: Replace the implement-plan finish question with an explicit push gate**

```markdown
Question id: `implement_plan_push_permission`

Prompt: `Should I push this implementation branch before merge routing?`

Options:
- `Push Branch`: push the development branch and continue toward merge-ready handoff.
- `Hold`: keep the branch local and stop with the branch preserved.
```

- [ ] **Step 2: Update the implement-plan ledger contract to require push approval and push proof before merge-ready output**

```bash
if (-not (Test-Property $Ledger "push_permission")) { throw "native push permission is required" }
if ([string]$Ledger.push_permission.question_id -ne "implement_plan_push_permission") { throw "push permission question_id is invalid" }
if ([string]$Ledger.push_permission.selected_action -notin @("push-branch", "hold")) { throw "push permission selected_action is invalid" }
if ([string]$Ledger.push_permission.selected_action -eq "push-branch" -and (-not (Test-Property $Ledger "branch_push_proof") -or $Ledger.branch_push_proof.pushed -ne $true)) {
    throw "branch push proof is required before merge-ready output"
}
```

- [ ] **Step 3: Add a resolve-issue push gate before branch push and PR creation**

```markdown
Question id: `project_resolve_push_permission`

Prompt: `Should I push this branch and create the PR now?`

Options:
- `Push And Open PR`: push the branch, open the PR, and continue to PR-ready handoff.
- `Hold`: keep the branch local and stop with explicit hold state.
```

- [ ] **Step 4: Thread the resolve push decision into the PR-ready collector and validator**

```bash
param(
    [string]$PushPermissionJson,
    [string]$PushPermissionPath
)

$pushPermission = Read-JsonInput -Json $PushPermissionJson -Path $PushPermissionPath -Name "push permission"
if ([string]$pushPermission.question_id -ne "project_resolve_push_permission") { throw "push permission question_id is invalid" }
if ([string]$pushPermission.selected_action -ne "push-pr") { throw "PR-ready handoff requires approved push permission" }
```

- [ ] **Step 5: Add scenario failures for “commit -> merge” and “verify -> push/PR” without explicit push approval**

```bash
Invoke-Scenario "implement-plan rejects missing push gate" {
    $repo = New-FixtureRepo
    $ledger = New-HappyLedger
    $ledger | Add-Member -NotePropertyName push_permission -NotePropertyValue $null
    $failed = $false
    try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "push permission" }
    Assert-True $failed "missing push gate should fail"
}

Invoke-Scenario "resolve PR-ready rejects missing push permission" {
    $setupJson = New-SetupLedger
    $prReady = @{
        pr_url = "https://github.com/example/repo/pull/5"
        issue_url = "https://github.com/example/repo/issues/12"
        branch = "codex/sample-issue"
        branch_pushed = $true
        pr_closes_issue = $true
        acceptance_criteria_covered = $true
        verification_passed = $true
        branch_push_proof = @{ source = "PR evidence"; pr_url = "https://github.com/example/repo/pull/5" }
        handoff_sent = @{ source = "worker-final-message"; status = "sent"; recipient = "main-thread-orchestrator" }
        goal_completion_proof = @{ source = "update_goal"; status = "complete"; issue_url = "https://github.com/example/repo/issues/12" }
    } | ConvertTo-Json -Depth 16 -Compress
    $result = Invoke-JsonScript -ScriptName "validate-pr-ready.sh" -Arguments @("-RepoRoot", $repo, "-SetupLedgerJson", $setupJson, "-PrReadyLedgerJson", $prReady)
    Assert-True (-not $result.ok -and $result.reason -match "push permission") "expected missing push gate failure"
}
```

- [ ] **Step 6: Run both execution-path scenario suites**

```bash
./skills/implement-plan/scripts/test-scenarios.sh
./skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: both suites pass, and the new negative cases explicitly fail when the push gate or push proof is absent.

- [ ] **Step 7: Commit the push-gate execution hardening**

```bash
git add skills/implement-plan/SKILL.md skills/implement-plan/agents/openai.yaml skills/implement-plan/scripts/lib/contract.sh skills/implement-plan/scripts/test-scenarios.sh skills/resolve-issue/SKILL.md skills/resolve-issue/agents/openai.yaml skills/resolve-issue/scripts/collect-pr-ready-ledger.sh skills/resolve-issue/scripts/validate-pr-ready.sh skills/resolve-issue/scripts/test-scenarios.sh
git commit -m "Require explicit push approval before merge routes"
```

### Task 4: Align merge closeout wording, validate the full repo, and sync the live install

**Files:**
- Modify: `skills/merge-changes/SKILL.md`
- Modify: `skills/merge-changes/agents/openai.yaml`
- Modify: `skills/merge-changes/scripts/test-scenarios.sh`
- Modify: `scripts/validate.sh` (only if a newly added script is not already covered)
- Test: `skills/merge-changes/scripts/test-scenarios.sh`
- Test: `scripts/validate.sh`
- Test: `scripts/sync-live.sh`

- [ ] **Step 1: Make merge-changes say explicitly that final Done requires clean closeout proof and a clean worktree**

```markdown
Done is valid only from `project_merge_final_health_gate` after clean closeout proof and a clean `git status --short` result.
If the repo is still dirty after merge or cleanup, `Done` is invalid and the workflow must revisit cleanup instead.
```

- [ ] **Step 2: Add test assertions that the final merge gate still enforces clean repo semantics**

```bash
foreach ($needle in @(
    "clean repo proof",
    "project_merge_final_health_gate",
    "Done is valid only"
)) {
    Assert-Contains $text $needle "missing final merge closeout rule: $needle"
}
```

- [ ] **Step 3: Run the merge scenario suite and full repo validation**

```bash
./skills/merge-changes/scripts/test-scenarios.sh
./scripts/validate.sh
```

Expected: merge scenarios stay green, and repo validation reports success for the shared-policy, skill-scenario, and Auto Mode helper checks.

- [ ] **Step 4: Run live-sync validation without mutating the source of truth directly**

```bash
./scripts/sync-live.sh --validate
```

Expected: validation succeeds against the live install surfaces, proving the source repo and deployed copy both expose the corrected workflow contracts.

- [ ] **Step 5: Commit the closeout/validation alignment**

```bash
git add skills/merge-changes/SKILL.md skills/merge-changes/agents/openai.yaml skills/merge-changes/scripts/test-scenarios.sh scripts/validate.sh
git commit -m "Align merge closeout and validation contracts"
```

## Plan Self-Review

1. **Spec coverage:** The plan maps the spec into shared policy, Doctor dirty-worktree enforcement, implement-plan/resolve-issue push gates, merge closeout alignment, and live-sync validation.
2. **Placeholder scan:** No `TBD` or “handle appropriately” language remains; every task names exact files, commands, and expected outcomes.
3. **Task/file consistency:** The plan points at the concrete validators and collectors that actually control behavior (`auto-mode-contract.sh`, `audit-project.sh`, `implement-plan/scripts/lib/contract.sh`, `collect-pr-ready-ledger.sh`, `validate-pr-ready.sh`, `merge-changes` tests), not just the Markdown skill files.
4. **Scope check:** This is one coherent governance hardening slice. It is broad enough to need staged commits, but it stays within one repo-owned implementation plan and does not require issue-mirror creation.
