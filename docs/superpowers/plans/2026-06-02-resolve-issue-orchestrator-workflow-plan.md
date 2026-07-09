# Resolve Issue Orchestrator Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit inline-versus-worker execution decision to `resolve-issue`, with native UI questioning, worktree-thread orchestration, TDD, PR finishing, and safety-focused script gates.

**Architecture:** Keep `resolve-issue` as the lifecycle owner for one GitHub issue mirror. The skill asks for execution topology before branch setup, records the answer in the setup ledger, and then either executes inline or orchestrates a worker worktree thread while the main thread owns review and closeout. Existing Bash scripts continue to validate path, goal, branch, PR, issue, and cleanup proof, while workflow preferences become readable metadata and advisory checks.

**Tech Stack:** Codex skills, native `request_user_input`, native goal tools, Codex thread/worktree tools when callable, Bash 7 validation scripts, Markdown issue mirrors, GitHub issue and PR evidence, Superpowers execution/TDD/verification/branch-finish skills.

---

## Source Spec

- `docs/superpowers/specs/2026-06-02-resolve-issue-orchestrator-workflow-design.md`

## Acceptance Criteria

- `resolve-issue` asks a native UI question in normal runs: open a worker worktree thread or resolve in the current thread.
- The native question uses dynamic recommendation logic based on issue complexity.
- `debug_question_mode` can exercise the same decision in smoke tests without calling `request_user_input`.
- Setup ledgers record `execution_decision`, `workflow_policy`, and worker handoff details when worker mode is selected.
- Inline mode still uses worktree isolation, native goal proof, TDD, plan execution, verification, PR finish, merge, issue close, goal completion, branch cleanup, and cleanup proof.
- Worker mode keeps the main thread as orchestrator, reviewer, merge owner, issue close owner, goal completion owner, and cleanup owner.
- Issue mirrors include workflow metadata fields for execution mode, worktree policy, integration policy, TDD policy, parallelization plan, reviewer role, and script gate mode.
- Scripts block safety/proof failures and report missing workflow metadata as advisory during migration.
- Dummy repo validation covers inline and worker setup shapes.
- `scripts/validate.sh`, `scripts/sync-live.sh --validate`, and the repo cleanup hook pass.

## File Map

- Modify: `canonical-skills/resolve-issue/SKILL.md`
- Modify: `canonical-skills/resolve-issue/agents/openai.yaml`
- Modify: `canonical-skills/resolve-issue/scripts/prepare-execution.sh`
- Modify: `canonical-skills/resolve-issue/scripts/validate-setup.sh`
- Modify: `canonical-skills/resolve-issue/scripts/test-scenarios.sh`
- Modify: `canonical-skills/create-issues/SKILL.md`
- Modify: `canonical-skills/create-issues/scripts/validate-issue-mirror.sh`
- Modify: `canonical-skills/create-issues/scripts/test-scenarios.sh`
- Modify: `canonical-skills/create-issues/agents/openai.yaml`
- Modify: `docs/superpowers/issues/README.md`
- Modify: `docs/superpowers/issues/smoke-test-workflow.md`
- Modify: `scripts/test-superpowers-project-repo-contract.sh`
- Modify: `scripts/test-superpowers-project-dummy-repo.sh`

## Required Superpowers Skills During Execution

- Use `superpowers:using-git-worktrees` before implementation work starts.
- Use `superpowers:test-driven-development` for feature and bug code.
- Use `superpowers:systematic-debugging` or diagnose discipline for bug, regression, CI, or unclear failure work.
- Use `codex-dynamic-workflows` when the issue needs an orchestrator/worker split or work packet map.
- Use `superpowers:dispatching-parallel-agents` when independent packets can run in parallel.
- Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to execute source-plan tasks.
- Use `superpowers:verification-before-completion` before PR-ready, merge-ready, or complete claims.
- Use `superpowers:finishing-a-development-branch` after verification and before integration.

## Task 1: Add Workflow Metadata To Issue Mirrors

**Files:**
- Modify: `canonical-skills/create-issues/SKILL.md`
- Modify: `canonical-skills/create-issues/agents/openai.yaml`
- Modify: `canonical-skills/create-issues/scripts/validate-issue-mirror.sh`
- Modify: `canonical-skills/create-issues/scripts/test-scenarios.sh`
- Modify: `docs/superpowers/issues/README.md`
- Modify: `docs/superpowers/issues/smoke-test-workflow.md`

- [ ] **Step 1: Write the failing create-issues scenario**

In `canonical-skills/create-issues/scripts/test-scenarios.sh`, extend the happy AFK issue fixture with:

```markdown
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only
```

Add these required needles to the `issue slicing contract is present` scenario:

```bash
foreach ($needle in @(
    "Execution Mode",
    "Worktree Policy",
    "Integration Policy",
    "TDD Policy",
    "Parallelization Plan",
    "Reviewer Role",
    "Script Gate Mode"
)) {
    Assert-Contains $text $needle "missing workflow metadata contract: $needle"
}
```

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```bash
./canonical-skills/create-issues/scripts/test-scenarios.sh
```

Expected: fails because the skill text and validator do not yet define the new workflow metadata contract.

- [ ] **Step 3: Update the issue mirror skill contract**

In `canonical-skills/create-issues/SKILL.md`, add this block to the issue mirror shape:

```markdown
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only
```

Add this policy paragraph after the mirror shape:

```markdown
Workflow metadata guides `$project:resolve-issue`. Missing metadata is advisory during migration, but malformed metadata should be corrected before publication because it creates ambiguous execution instructions. `Execution Mode` should normally be `Ask at runtime` so the resolver asks whether to solve inline or open a worker worktree thread.
```

In `canonical-skills/create-issues/agents/openai.yaml`, include the same field names in the default prompt.

- [ ] **Step 4: Add advisory workflow checks to the mirror validator**

In `canonical-skills/create-issues/scripts/validate-issue-mirror.sh`, after the goal command check, insert:

```bash
$workflowFields = [ordered]@{
    "Execution Mode" = @("Ask at runtime", "Inline", "Orchestrated worker")
    "Worktree Policy" = @("Native Codex worktree thread first")
    "Integration Policy" = @("Worker PR reviewed by main thread", "Current thread owns PR")
    "TDD Policy" = @("Required", "User-approved opt-out")
    "Parallelization Plan" = @("None", "Source plan packets")
    "Reviewer Role" = @("Main thread orchestrator")
    "Script Gate Mode" = @("Safety only")
}

foreach ($fieldName in $workflowFields.Keys) {
    $value = Get-FieldValue -Text $text -Name $fieldName
    if ([string]::IsNullOrWhiteSpace($value)) {
        Add-Check -Name "workflow metadata: $fieldName" -Ok $false -Reason "advisory: missing"
        continue
    }
    if ($workflowFields[$fieldName] -notcontains $value) {
        Complete -Ok $false -Reason "$fieldName must be one of: $($workflowFields[$fieldName] -join ', ')"
    }
    Add-Check -Name "workflow metadata: $fieldName" -Ok $true -Reason "passed"
}
```

- [ ] **Step 5: Update repo issue docs and smoke mirror**

In `docs/superpowers/issues/README.md`, add a `Workflow Metadata` section with the seven fields from Step 3.

In `docs/superpowers/issues/smoke-test-workflow.md`, add the seven workflow fields below `Branch` if a branch field exists, or below `Goal Command` otherwise.

- [ ] **Step 6: Run the focused test and commit**

Run:

```bash
./canonical-skills/create-issues/scripts/test-scenarios.sh
```

Expected: exits zero.

Commit:

```bash
git add canonical-skills/create-issues docs/superpowers/issues
git commit -m "feat: add issue workflow metadata"
```

## Task 2: Add The Resolver Execution Topology Decision

**Files:**
- Modify: `canonical-skills/resolve-issue/SKILL.md`
- Modify: `canonical-skills/resolve-issue/agents/openai.yaml`
- Modify: `canonical-skills/resolve-issue/scripts/test-scenarios.sh`

- [ ] **Step 1: Write failing resolver text scenarios**

In `canonical-skills/resolve-issue/scripts/test-scenarios.sh`, extend the `skill text declares native goal state machine` scenario needles:

```bash
foreach ($needle in @(
    "execution topology question",
    "Open worker thread",
    "Current thread",
    "request_user_input",
    "debug_question_mode",
    "using-git-worktrees",
    "codex-dynamic-workflows",
    "dispatching-parallel-agents",
    "test-driven-development",
    "verification-before-completion",
    "finishing-a-development-branch",
    "main thread orchestrator"
)) {
    Assert-True ($text.Contains($needle)) "missing resolver workflow text: $needle"
}
```

- [ ] **Step 2: Run the resolver scenario and verify failure**

Run:

```bash
./canonical-skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: fails because the skill text does not yet require the topology question and orchestration behavior.

- [ ] **Step 3: Update the resolver state machine**

In `canonical-skills/resolve-issue/SKILL.md`, replace the current state machine with:

```markdown
1. `repo gate`: verify the active repo and explicit target when needed.
2. `issue mirror validation`: inspect `docs/superpowers/issues/<issue>.md`.
3. `source plan validation`: read the linked `docs/superpowers/plans/<plan>.md`.
4. `preflight`: verify the repo is ready for one issue execution.
5. `execution topology question`: ask whether to open a worker thread or resolve in the current thread.
6. `native goal activation`: call `get_goal`, create or activate the native `/goal`, then call `get_goal` again and capture structured proof.
7. `setup validation`: write and validate the setup ledger, including the execution decision.
8. `worktree and branch setup`: create or verify inline worktree/branch, or create the worker handoff for a worker worktree thread.
9. `Superpowers execution`: use Superpowers execution, TDD, debugging, dynamic workflow, and verification skills as applicable.
10. `development branch finish`: use `superpowers:finishing-a-development-branch`, with PR as the default finish path.
11. `main thread review`: review worker or inline PR evidence before merge.
12. `premerge`: validate PR closure, checks, issue criteria, changed-file coverage, and proof receipts.
13. `merge`: squash-merge the approved PR.
14. `issue close`: verify the exact linked GitHub issue is closed.
15. `goal complete`: call native goal completion with tool support or record exact slash-command completion evidence.
16. `cleanup`: sync default branch, delete only the goal branch, remove owned temporary scaffolding, and run the repo cleanup hook.
```

- [ ] **Step 4: Add the native question contract**

In `canonical-skills/resolve-issue/SKILL.md`, add:

```markdown
## Execution Topology Question

Before branch setup or implementation, ask the user how to resolve the issue when `request_user_input` is callable.

Question id: `resolve_execution_topology`

Prompt: `How should this issue be resolved?`

Options:

- `Open worker thread`: create a Codex worktree thread for implementation while this thread acts as main thread orchestrator and reviewer.
- `Current thread`: resolve the issue in this thread using worktree isolation.

Recommend `Open worker thread` for non-trivial AFK issues, source plans with multiple independent tasks, risky shared-code changes, or work naturally ending in a PR. Recommend `Current thread` for small, single-step, low-risk issues.

For explicit smoke tests, use `debug_question_mode` instead of `request_user_input` and record the Native Question Debug Ledger entry in the setup ledger.
```

- [ ] **Step 5: Add the orchestration contract**

In the same skill file, add:

```markdown
## Orchestrated Worker Mode

When the selected mode is `orchestrated-worker`, this thread remains the lifecycle owner. It creates the native goal, prepares the worker handoff, opens a Codex worktree thread when native thread tools are callable, reviews the worker PR, handles CI or review feedback, merges, closes the linked issue, completes the native goal, syncs default, deletes the owned branch, and records cleanup proof.

The worker thread must use `superpowers:using-git-worktrees`, `superpowers:test-driven-development`, `superpowers:executing-plans` or `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, and `superpowers:finishing-a-development-branch`. Use `codex-dynamic-workflows` and `superpowers:dispatching-parallel-agents` when the source plan contains independent packets.

If native thread tools are absent, stop after producing the worker handoff and ask the user to open the worker thread. Do not silently convert the run to inline execution.
```

- [ ] **Step 6: Update resolver metadata prompt**

In `canonical-skills/resolve-issue/agents/openai.yaml`, add this sentence to the default prompt:

```yaml
Ask the native execution topology question before branch setup: open a worker worktree thread or resolve in the current thread; keep the main thread as orchestrator, reviewer, merge owner, issue close owner, native goal completion owner, and cleanup owner.
```

- [ ] **Step 7: Run the resolver scenario and commit**

Run:

```bash
./canonical-skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: exits zero.

Commit:

```bash
git add canonical-skills/resolve-issue
git commit -m "feat: add resolver execution topology decision"
```

## Task 3: Carry Execution Decisions Through Setup Ledgers

**Files:**
- Modify: `canonical-skills/resolve-issue/scripts/prepare-execution.sh`
- Modify: `canonical-skills/resolve-issue/scripts/validate-setup.sh`
- Modify: `canonical-skills/resolve-issue/scripts/test-scenarios.sh`

- [ ] **Step 1: Add failing setup ledger scenarios**

In `canonical-skills/resolve-issue/scripts/test-scenarios.sh`, add helpers:

```bash
function New-ExecutionDecision {
    param([string]$SelectedMode = "inline", [string]$Source = "request_user_input")
    @{
        question_id = "resolve_execution_topology"
        source = $Source
        selected_mode = $SelectedMode
        recommended_mode = $SelectedMode
        options = @("orchestrated-worker", "inline")
    } | ConvertTo-Json -Depth 8 -Compress
}
```

Add scenarios:

```bash
Invoke-Scenario "missing execution decision blocks setup finalization" {
    $result = Invoke-JsonScript -ScriptName "prepare-execution.sh" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof))
    Assert-True (-not $result.ok -and $result.reason -match "execution decision") "expected missing execution decision failure"
}

Invoke-Scenario "inline execution decision is recorded" {
    $result = Invoke-JsonScript -ScriptName "prepare-execution.sh" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "inline"))
    Assert-True ($result.ok) $result.reason
    Assert-True ($result.setup_ledger.execution_decision.selected_mode -eq "inline") "inline mode was not recorded"
}

Invoke-Scenario "orchestrated worker execution decision is recorded with worker handoff" {
    $result = Invoke-JsonScript -ScriptName "prepare-execution.sh" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $repo, "-HandoffJson", (New-Handoff), "-GoalProofJson", (New-GoalProof), "-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "orchestrated-worker"))
    Assert-True ($result.ok) $result.reason
    Assert-True ($result.setup_ledger.execution_decision.selected_mode -eq "orchestrated-worker") "worker mode was not recorded"
    Assert-True ($result.setup_ledger.worker_handoff.issue_mirror -eq "docs/superpowers/issues/12-sample.md") "worker handoff missing issue mirror"
}
```

- [ ] **Step 2: Run the resolver scenario and verify failure**

Run:

```bash
./canonical-skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: fails because `prepare-execution.sh` does not accept or validate `ExecutionDecisionJson`.

- [ ] **Step 3: Add the execution decision parameter**

In `canonical-skills/resolve-issue/scripts/prepare-execution.sh`, add the parameter:

```bash
[string]$ExecutionDecisionJson,
[string]$ExecutionDecisionPath,
```

Place it after `GoalProofPath`.

- [ ] **Step 4: Add execution decision validation helpers**

In `canonical-skills/resolve-issue/scripts/lib/contract.sh`, add:

```bash
function Assert-ExecutionDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "execution decision is required" }
    if ($Decision -is [string]) { throw "execution decision must be structured, not a string" }
    foreach ($field in @("question_id", "source", "selected_mode", "recommended_mode", "options")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "execution decision missing $field" }
    }
    if ([string]$Decision.question_id -ne "resolve_execution_topology") { throw "execution decision question_id mismatch" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "execution decision source must be request_user_input or debug_question_mode" }
    if ([string]$Decision.selected_mode -notin @("inline", "orchestrated-worker")) { throw "execution decision selected_mode must be inline or orchestrated-worker" }
    if ([string]$Decision.recommended_mode -notin @("inline", "orchestrated-worker")) { throw "execution decision recommended_mode must be inline or orchestrated-worker" }
}

function New-WorkerHandoff {
    param($Handoff, $Decision)
    [ordered]@{
        issue_url = [string]$Handoff.issue_url
        issue_mirror = Normalize-RepoPath ([string]$Handoff.issue_mirror)
        source_plan = Normalize-RepoPath ([string]$Handoff.source_plan)
        branch = Normalize-RepoPath ([string]$Handoff.branch)
        goal_objective = [string]$Handoff.goal_objective
        proof_oracle = Get-StringArray $Handoff.proof_oracle
        execution_mode = [string]$Decision.selected_mode
        required_skills = @(
            "superpowers:using-git-worktrees",
            "superpowers:test-driven-development",
            "superpowers:executing-plans",
            "superpowers:verification-before-completion",
            "superpowers:finishing-a-development-branch"
        )
        closeout_owner = "main-thread-orchestrator"
    }
}
```

- [ ] **Step 5: Read and record the execution decision in setup finalization**

In `prepare-execution.sh`, before `$goalProof = Read-JsonInput ...`, add:

```bash
$executionDecision = Read-JsonInput -Json $ExecutionDecisionJson -Path $ExecutionDecisionPath -Name "execution decision"
Assert-ExecutionDecision -Decision $executionDecision
```

In `$setupLedger`, add:

```bash
execution_decision = $executionDecision
workflow_policy = [ordered]@{
    worktree_policy = "Native Codex worktree thread first"
    integration_policy = if ([string]$executionDecision.selected_mode -eq "orchestrated-worker") { "Worker PR reviewed by main thread" } else { "Current thread owns PR" }
    tdd_policy = "Required"
    reviewer_role = "Main thread orchestrator"
    script_gate_mode = "Safety only"
}
worker_handoff = if ([string]$executionDecision.selected_mode -eq "orchestrated-worker") { New-WorkerHandoff -Handoff $handoff -Decision $executionDecision } else { $null }
```

- [ ] **Step 6: Require the setup ledger decision**

In `validate-setup.sh`, add `execution_decision` to the required field list and call:

```bash
Assert-ExecutionDecision -Decision $ledger.execution_decision
```

If `selected_mode` is `orchestrated-worker`, require `worker_handoff`:

```bash
if ([string]$ledger.execution_decision.selected_mode -eq "orchestrated-worker" -and -not (Test-Property -Object $ledger -Name "worker_handoff")) {
    throw "worker_handoff is required for orchestrated-worker execution"
}
```

- [ ] **Step 7: Update existing happy setup tests**

Every existing `FinalizeSetup` call in `canonical-skills/resolve-issue/scripts/test-scenarios.sh` must pass:

```bash
"-ExecutionDecisionJson", (New-ExecutionDecision -SelectedMode "inline")
```

- [ ] **Step 8: Run the resolver scenario and commit**

Run:

```bash
./canonical-skills/resolve-issue/scripts/test-scenarios.sh
```

Expected: exits zero.

Commit:

```bash
git add canonical-skills/resolve-issue/scripts
git commit -m "feat: record resolver execution decisions"
```

## Task 4: Expand Repo And Dummy Smoke Validation

**Files:**
- Modify: `scripts/test-superpowers-project-repo-contract.sh`
- Modify: `scripts/test-superpowers-project-dummy-repo.sh`
- Modify: `docs/superpowers/issues/smoke-test-workflow.md`

- [ ] **Step 1: Add repo contract checks for workflow metadata**

In `scripts/test-superpowers-project-repo-contract.sh`, after the issue mirror validator loop, add:

```bash
foreach ($issueFile in $issueFiles) {
    $text = Get-Content -LiteralPath $issueFile.FullName -Raw
    foreach ($needle in @(
        "Execution Mode",
        "Worktree Policy",
        "Integration Policy",
        "TDD Policy",
        "Parallelization Plan",
        "Reviewer Role",
        "Script Gate Mode"
    )) {
        if (-not $text.Contains($needle)) {
            throw "$($issueFile.Name) is missing workflow metadata: $needle"
        }
    }
}
Add-Check -Name "issue workflow metadata" -Ok $true -Reason "passed"
```

- [ ] **Step 2: Add workflow metadata to the dummy issue fixture**

In `scripts/test-superpowers-project-dummy-repo.sh`, add these fields below `Branch` in the generated dummy issue:

```markdown
**Execution Mode:** Ask at runtime
**Worktree Policy:** Native Codex worktree thread first
**Integration Policy:** Worker PR reviewed by main thread
**TDD Policy:** Required
**Parallelization Plan:** None
**Reviewer Role:** Main thread orchestrator
**Script Gate Mode:** Safety only
```

- [ ] **Step 3: Add inline and worker setup decisions to dummy validation**

In `scripts/test-superpowers-project-dummy-repo.sh`, add:

```bash
$inlineDecision = @{
    question_id = "resolve_execution_topology"
    source = "debug_question_mode"
    selected_mode = "inline"
    recommended_mode = "inline"
    options = @("orchestrated-worker", "inline")
} | ConvertTo-Json -Depth 8 -Compress

$workerDecision = @{
    question_id = "resolve_execution_topology"
    source = "debug_question_mode"
    selected_mode = "orchestrated-worker"
    recommended_mode = "orchestrated-worker"
    options = @("orchestrated-worker", "inline")
} | ConvertTo-Json -Depth 8 -Compress
```

Use `$inlineDecision` in the existing `FinalizeSetup` call. Add a second `FinalizeSetup` call with `$workerDecision` and assert:

```bash
if ($workerFinalize.setup_ledger.execution_decision.selected_mode -ne "orchestrated-worker") { throw "worker execution decision was not recorded" }
if (-not $workerFinalize.setup_ledger.worker_handoff) { throw "worker handoff was not recorded" }
```

- [ ] **Step 4: Run repo smoke tests and commit**

Run:

```bash
./scripts/test-superpowers-project-repo-contract.sh
./scripts/test-superpowers-project-dummy-repo.sh
```

Expected: both commands exit zero.

Commit:

```bash
git add scripts/test-superpowers-project-repo-contract.sh scripts/test-superpowers-project-dummy-repo.sh docs/superpowers/issues/smoke-test-workflow.md
git commit -m "test: cover resolver orchestration workflow"
```

## Task 5: Full Validation, Live Sync, And Closeout

**Files:**
- Modify only if earlier validation exposes a concrete repo-owned defect.

- [ ] **Step 1: Run full validation**

Run:

```bash
./scripts/validate.sh
```

Expected: exits zero.

- [ ] **Step 2: Sync live plugin and deployed user skills**

Run:

```bash
./scripts/sync-live.sh --validate
```

Expected: exits zero and deploys the seven active skills.

- [ ] **Step 3: Run cleanup**

Run:

```bash
"$HOME\.codex\hooks\codex-cleanup.sh" -RepoRoot .
```

Expected: exits zero.

- [ ] **Step 4: Inspect git status**

Run:

```bash
git status --short
```

Expected: no uncommitted files.

## Self-Review

- Spec coverage: all decisions from the native UI grilling are covered by Tasks 1 through 5.
- Placeholder scan: no placeholder sections or future-fill markers are present.
- Type consistency: setup ledger uses `execution_decision`, `workflow_policy`, and `worker_handoff` consistently across script, validator, and tests.
- Risk: Task 3 changes setup script arguments, so every existing `FinalizeSetup` call must be updated in the same commit.
- Execution choice after plan approval: use `superpowers:subagent-driven-development` for Tasks 1 through 4 and keep Task 5 inline in the main thread.

