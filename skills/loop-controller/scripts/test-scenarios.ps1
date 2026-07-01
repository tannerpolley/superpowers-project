[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("loop-controller-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-JsonScript {
    param([string]$Path, [string[]]$Arguments)
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = ($raw | Out-String).Trim(); json = (($raw | Out-String).Trim() | ConvertFrom-Json) }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $runRoot = Join-Path $RepoRoot ".superpowers\runs\fixture-run"
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
    $validLedger = Join-Path $runRoot "loop-run-ledger.json"
    @{
        run_id = "fixture-run"
        trigger_source = "manual"
        repo_root = $RepoRoot
        plugin_manifest_version = "0.2.0+fixture"
        plugin_contract_hash = "abc123"
        started_at = "2026-06-15T00:00:00Z"
        updated_at = "2026-06-15T00:00:01Z"
        status = "running"
        current_phase = "candidate-selection"
        candidate_source = "fixture"
        candidate_id = "candidate-1"
        selected_route = "write-plan"
        route_reason = "approved spec needs plan"
        budget_policy = @{ max_candidates = 1; max_attempts_per_phase = 2; max_repeated_same_failure = 1; max_changed_files = 20; max_github_mutations = 0; max_validator_reruns = 5; max_unreviewed_diff_lines = 800 }
        attempts = @()
        last_blocker = $null
        branch = "codex/loop-controller-contracts"
        worktree_path = $null
        auto_mode_authorization_path = $null
        proof_artifacts = @()
        verifier_artifacts = @()
        metrics_artifacts = @()
        terminal_decision = $null
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $validLedger -Encoding utf8NoBOM

    $validator = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-run-ledger.ps1"
    $valid = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-RunLedgerPath", $validLedger)
    Add-Check -Name "valid run ledger passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason $valid.raw

    $externalRoot = Join-Path $tempRoot "external-target-repo"
    $externalRunRoot = Join-Path $externalRoot ".superpowers\runs\fixture-run"
    New-Item -ItemType Directory -Path $externalRunRoot -Force | Out-Null
    $externalLedger = Join-Path $externalRunRoot "loop-run-ledger.json"
    $externalLedgerObject = Get-Content -LiteralPath $validLedger -Raw | ConvertFrom-Json
    $externalLedgerObject.repo_root = $externalRoot
    $externalLedgerObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $externalLedger -Encoding utf8NoBOM
    $externalRunLedger = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $externalRoot, "-RunLedgerPath", ".superpowers\runs\fixture-run\loop-run-ledger.json")
    Add-Check -Name "external project repo run ledger passes" -Ok ($externalRunLedger.exit_code -eq 0 -and $externalRunLedger.json.ok -eq $true) -Reason "Plugin-rooted loop validator must accept a target repo without loop-controller scripts"

    $invalidLedger = Join-Path $tempRoot "missing-contract-hash.json"
    $invalid = Get-Content -LiteralPath $validLedger -Raw | ConvertFrom-Json
    $invalid.PSObject.Properties.Remove("plugin_contract_hash")
    $invalid | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $invalidLedger -Encoding utf8NoBOM
    $invalidResult = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-RunLedgerPath", $invalidLedger)
    Add-Check -Name "missing contract hash fails" -Ok ($invalidResult.exit_code -ne 0 -and $invalidResult.json.ok -eq $false) -Reason "missing contract hash should fail"

    $budgetScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-budget.ps1"
    $budgetOkPath = Join-Path $tempRoot "budget-ok.json"
    @{
        max_candidates = 2
        candidates_completed = 1
        max_attempts_per_phase = 3
        current_phase_attempts = 1
        max_repeated_same_failure = 2
        repeated_same_failure_count = 0
        max_changed_files = 20
        changed_files = 3
        max_github_mutations = 0
        github_mutations = 0
        max_validator_reruns = 6
        validator_reruns = 2
        max_unreviewed_diff_lines = 800
        unreviewed_diff_lines = 120
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $budgetOkPath -Encoding utf8NoBOM
    $budgetOk = Invoke-JsonScript -Path $budgetScript -Arguments @("-RepoRoot", $RepoRoot, "-BudgetLedgerPath", $budgetOkPath)
    Add-Check -Name "budget within policy passes" -Ok ($budgetOk.exit_code -eq 0 -and $budgetOk.json.ok -eq $true) -Reason $budgetOk.raw

    $budgetFailPath = Join-Path $tempRoot "budget-fail.json"
    @{
        max_candidates = 1
        candidates_completed = 1
        max_attempts_per_phase = 2
        current_phase_attempts = 2
        max_repeated_same_failure = 1
        repeated_same_failure_count = 1
        max_changed_files = 4
        changed_files = 5
        max_github_mutations = 0
        github_mutations = 1
        max_validator_reruns = 3
        validator_reruns = 4
        max_unreviewed_diff_lines = 100
        unreviewed_diff_lines = 101
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $budgetFailPath -Encoding utf8NoBOM
    $budgetFail = Invoke-JsonScript -Path $budgetScript -Arguments @("-RepoRoot", $RepoRoot, "-BudgetLedgerPath", $budgetFailPath)
    Add-Check -Name "exhausted budget fails" -Ok ($budgetFail.exit_code -ne 0 -and $budgetFail.json.ok -eq $false) -Reason "exhausted budget should fail"
    $budgetFailureReason = [string]$budgetFail.json.reason
    Add-Check -Name "exhausted budget reports all failed limits" -Ok (
        $budgetFailureReason.Contains("candidates_completed") -and
        $budgetFailureReason.Contains("current_phase_attempts") -and
        $budgetFailureReason.Contains("repeated_same_failure_count") -and
        $budgetFailureReason.Contains("changed_files") -and
        $budgetFailureReason.Contains("github_mutations") -and
        $budgetFailureReason.Contains("validator_reruns") -and
        $budgetFailureReason.Contains("unreviewed_diff_lines")
    ) -Reason "exhausted budget reason must list every failed limit"

    $selectorScript = Join-Path $RepoRoot "skills\loop-controller\scripts\select-candidate.ps1"
    $inventoryPath = Join-Path $tempRoot "candidate-inventory.json"
    @{
        candidates = @(
            @{ id = "broad-audit"; source = "audit"; route = "audit-project"; ready = $true; risk = "medium"; source_path = "docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md"; reason = "broad follow-up" },
            @{ id = "approved-spec-plan"; source = "spec"; route = "write-plan"; ready = $true; risk = "low"; source_path = "docs/superpowers/specs/2026-06-15-auto-mode-loop-controller-design.md"; reason = "approved spec needs plan" },
            @{ id = "missing-source"; source = "issue"; route = "resolve-issue"; ready = $false; risk = "low"; source_path = "docs/superpowers/issues/missing.md"; reason = "source mirror missing" }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $inventoryPath -Encoding utf8NoBOM
    $selection = Invoke-JsonScript -Path $selectorScript -Arguments @("-RepoRoot", $RepoRoot, "-InventoryPath", $inventoryPath)
    Add-Check -Name "selector chooses low-risk ready candidate" -Ok ($selection.exit_code -eq 0 -and $selection.json.selected_candidate_id -eq "approved-spec-plan") -Reason $selection.raw
    Add-Check -Name "selector records skipped candidates" -Ok ($selection.json.skipped.Count -ge 1) -Reason "skipped candidates missing"

    $maintenanceInventoryPath = Join-Path $tempRoot "maintenance-candidate-inventory.json"
    @{
        candidates = @(
            @{ id = "ready-plan"; source = "approved-plan"; route = "implement-plan"; ready = $true; risk = "low"; source_path = "docs/superpowers/plans/2026-06-16-m0-workflow-mode-entry-plan.md"; reason = "approved plan needs implementation" },
            @{ id = "stale-version"; source = "stale-version"; route = "align-project"; ready = $true; risk = "low"; source_path = "scripts/get-agent-plugin-version.ps1"; reason = "version drift repair" },
            @{ id = "broad-audit"; source = "audit"; route = "audit-project"; ready = $true; risk = "medium"; source_path = "docs/superpowers/specs/2026-06-16-workflow-mode-entry-design.md"; reason = "broad maintenance audit" }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $maintenanceInventoryPath -Encoding utf8NoBOM
    $maintenanceSelection = Invoke-JsonScript -Path $selectorScript -Arguments @("-RepoRoot", $RepoRoot, "-InventoryPath", $maintenanceInventoryPath)
    Add-Check -Name "selector accepts broad maintenance candidates" -Ok ($maintenanceSelection.exit_code -eq 0 -and $maintenanceSelection.json.selected_candidate_id -eq "ready-plan") -Reason $maintenanceSelection.raw
    Add-Check -Name "broad maintenance selector keeps skipped list" -Ok ($null -ne $maintenanceSelection.json.skipped) -Reason "broad maintenance skipped list missing"

    $hierarchyRepo = Join-Path $tempRoot "hierarchy-target-repo"
    $hierarchyIssueRoot = Join-Path $hierarchyRepo "docs\superpowers\issues"
    New-Item -ItemType Directory -Path $hierarchyIssueRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $hierarchyIssueRoot "fixture-parent-rollup.md") -Value "# Parent Rollup`n`n**Hierarchy Mode:** issue-set`n**Sub-Issue Role:** parent`n**Executable:** false`n**Parent Issue:** None`n**Parent Mirror:** None`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $hierarchyIssueRoot "fixture-plan-wrapper.md") -Value "# Plan Wrapper`n`n**Hierarchy Mode:** issue-set`n**Sub-Issue Role:** plan-wrapper`n**Executable:** false`n**Parent Issue:** None`n**Parent Mirror:** None`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $hierarchyIssueRoot "fixture-leaf.md") -Value "# Leaf Issue`n`n**Hierarchy Mode:** issue-set`n**Sub-Issue Role:** leaf`n**Executable:** true`n**Parent Issue:** https://github.com/example/repo/issues/97`n**Parent Mirror:** docs/superpowers/issues/fixture-parent-rollup.md`n" -Encoding utf8NoBOM
    $hierarchyInventoryPath = Join-Path $tempRoot "hierarchy-candidate-inventory.json"
    @{
        candidates = @(
            @{ id = "rollup-parent"; source = "ready-issue-mirror"; route = "resolve-issue"; ready = $true; risk = "low"; source_path = "docs/superpowers/issues/fixture-parent-rollup.md"; reason = "parent rollup should not execute" },
            @{ id = "plan-wrapper"; source = "ready-issue-mirror"; route = "orchestrate-issues"; ready = $true; risk = "low"; source_path = "docs/superpowers/issues/fixture-plan-wrapper.md"; reason = "wrapper should route to repair"; hierarchy_role = "plan-wrapper"; executable = $false },
            @{ id = "leaf-issue"; source = "ready-issue-mirror"; route = "resolve-issue"; ready = $true; risk = "low"; source_path = "docs/superpowers/issues/fixture-leaf.md"; reason = "leaf issue is executable" }
        )
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hierarchyInventoryPath -Encoding utf8NoBOM
    $hierarchySelection = Invoke-JsonScript -Path $selectorScript -Arguments @("-RepoRoot", $hierarchyRepo, "-InventoryPath", $hierarchyInventoryPath)
    Add-Check -Name "selector chooses executable hierarchy leaf" -Ok ($hierarchySelection.exit_code -eq 0 -and $hierarchySelection.json.selected_candidate_id -eq "leaf-issue") -Reason $hierarchySelection.raw
    Add-Check -Name "selector skips hierarchy rollups for implementation" -Ok (
        @($hierarchySelection.json.skipped | Where-Object { $_.id -eq "rollup-parent" -and $_.hierarchy_role -eq "parent" -and $_.reserved_route -eq "rollup-align-or-tracker-repair" }).Count -eq 1 -and
        @($hierarchySelection.json.skipped | Where-Object { $_.id -eq "plan-wrapper" -and $_.hierarchy_role -eq "plan-wrapper" -and $_.reserved_route -eq "rollup-align-or-tracker-repair" }).Count -eq 1
    ) -Reason "parent and wrapper candidates should be skipped with reserved route evidence"
    Add-Check -Name "selector records selected leaf hierarchy evidence" -Ok ($hierarchySelection.json.selected_hierarchy.role -eq "leaf" -and $hierarchySelection.json.selected_hierarchy.executable -eq $true) -Reason "selected leaf hierarchy evidence missing"

    $activeBacklogPath = Join-Path $tempRoot "active-backlog.md"
    @(
        "# Active Backlog Fixture",
        "",
        "| ID | Route owner | Source artifact | Priority | Status | Proof target | Reason |",
        "|---|---|---|---|---|---|---|",
        "| archived-plan-checkbox | write-plan | docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md | P0 | archived | historical checkbox | historical plan checkbox noise |",
        "| final-proof | align-project | docs/superpowers/milestones/M1-workflow-normalization-validation-receipt.md | P2 | ready | pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 | active receipt proof |"
    ) | Set-Content -LiteralPath $activeBacklogPath -Encoding utf8NoBOM
    $activeBacklogSelection = Invoke-JsonScript -Path $selectorScript -Arguments @("-RepoRoot", $RepoRoot, "-InventoryPath", $activeBacklogPath)
    Add-Check -Name "selector accepts active backlog markdown" -Ok ($activeBacklogSelection.exit_code -eq 0 -and $activeBacklogSelection.json.selected_candidate_id -eq "final-proof") -Reason $activeBacklogSelection.raw
    Add-Check -Name "selector skips archived historical checkbox rows" -Ok (@($activeBacklogSelection.json.skipped | Where-Object { $_.id -eq "archived-plan-checkbox" -and $_.reason -match "status" }).Count -eq 1) -Reason "archived historical checkbox row should be skipped"

    $verifierScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-verifier-ledger.ps1"
    $terminalScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-terminal-closeout.ps1"
    $stateMachineScript = Join-Path $RepoRoot "skills\loop-controller\scripts\validate-loop-state-machine.ps1"
    $metricsScript = Join-Path $RepoRoot "skills\loop-controller\scripts\write-metrics-report.ps1"

    $oneCandidateStatePath = Join-Path $tempRoot "loop-state-one-candidate.json"
    @{
        selected_mode = "looping"
        status = "running"
        dirty_repo_status = ""
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 1
        iterations = @(
            @{
                selected_candidate_id = "86"
                selected_candidate_ids = @("86")
                candidate_source = "active-backlog"
                selected_route = "resolve-issue"
                owner_route = "resolve-issue"
                owner_result = @{ status = "merged"; proof = "pr-ready and closeout proof" }
                budget_check_before_selection = @{ ok = $true }
                budget_recheck_after_candidate = @{ ok = $true }
                continuation_decision = @{ question_id = "project_loop_next_step"; selected_option = "Yes"; terminal_state = "continue" }
            }
        )
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $oneCandidateStatePath -Encoding utf8NoBOM
    $oneCandidateState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $oneCandidateStatePath)
    Add-Check -Name "loop state accepts one candidate iteration" -Ok ($oneCandidateState.exit_code -eq 0 -and $oneCandidateState.json.ok -eq $true) -Reason $oneCandidateState.raw

    $missingContinuationStatePath = Join-Path $tempRoot "loop-state-missing-continuation.json"
    @{
        selected_mode = "looping"
        status = "running"
        dirty_repo_status = ""
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 2
        iterations = @(
            @{
                selected_candidate_id = "86"
                selected_candidate_ids = @("86")
                candidate_source = "active-backlog"
                selected_route = "resolve-issue"
                owner_route = "resolve-issue"
                owner_result = @{ status = "merged"; proof = "closeout proof" }
                budget_check_before_selection = @{ ok = $true }
                budget_recheck_after_candidate = @{ ok = $true }
            },
            @{
                selected_candidate_id = "88"
                selected_candidate_ids = @("88")
                candidate_source = "active-backlog"
                selected_route = "resolve-issue"
                owner_route = "resolve-issue"
                owner_result = @{ status = "selected"; proof = "second selection" }
                budget_check_before_selection = @{ ok = $true }
            }
        )
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $missingContinuationStatePath -Encoding utf8NoBOM
    $missingContinuationState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $missingContinuationStatePath)
    Add-Check -Name "loop state blocks second candidate before continuation" -Ok ($missingContinuationState.exit_code -ne 0 -and $missingContinuationState.json.reason.Contains("project_loop_next_step")) -Reason "second candidate selection must require continuation gate"

    $noReadyStatePath = Join-Path $tempRoot "loop-state-no-ready.json"
    @{
        selected_mode = "looping"
        status = "paused"
        dirty_repo_status = ""
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 0
        iterations = @()
        no_ready_proof = @{ source = "select-candidate"; reason = "no ready candidates" }
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $noReadyStatePath -Encoding utf8NoBOM
    $noReadyState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $noReadyStatePath)
    Add-Check -Name "loop state accepts explicit no-ready proof" -Ok ($noReadyState.exit_code -eq 0 -and $noReadyState.json.ok -eq $true) -Reason $noReadyState.raw

    $autoMisuseStatePath = Join-Path $tempRoot "loop-state-auto-misuse.json"
    @{
        selected_mode = "looping"
        status = "running"
        dirty_repo_status = ""
        selection_authority = "auto-mode"
        auto_mode_authorization_path = ".superpowers/runs/fixture/auto-mode.json"
        candidates_ready_count = 1
        iterations = @(
            @{
                selected_candidate_id = "86"
                selected_candidate_ids = @("86")
                candidate_source = "active-backlog"
                selected_route = "resolve-issue"
                owner_route = "resolve-issue"
                owner_result = @{ status = "merged"; proof = "closeout proof" }
                budget_check_before_selection = @{ ok = $true }
                budget_recheck_after_candidate = @{ ok = $true }
            }
        )
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $autoMisuseStatePath -Encoding utf8NoBOM
    $autoMisuseState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $autoMisuseStatePath)
    Add-Check -Name "loop state rejects Auto Mode queue authority" -Ok ($autoMisuseState.exit_code -ne 0 -and $autoMisuseState.json.reason.Contains("Auto Mode")) -Reason "Auto Mode must not authorize Looping Mode queue draining"

    $budgetExhaustedStatePath = Join-Path $tempRoot "loop-state-budget-exhausted.json"
    @{
        selected_mode = "looping"
        status = "running"
        dirty_repo_status = ""
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 1
        iterations = @(
            @{
                selected_candidate_id = "86"
                selected_candidate_ids = @("86")
                candidate_source = "active-backlog"
                selected_route = "resolve-issue"
                owner_route = "resolve-issue"
                owner_result = @{ status = "selected"; proof = "selection" }
                budget_check_before_selection = @{ ok = $false; reason = "candidates_completed exhausted" }
            }
        )
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $budgetExhaustedStatePath -Encoding utf8NoBOM
    $budgetExhaustedState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $budgetExhaustedStatePath)
    Add-Check -Name "loop state rejects exhausted budget before selection" -Ok ($budgetExhaustedState.exit_code -ne 0 -and $budgetExhaustedState.json.reason.Contains("budget")) -Reason "budget exhaustion should block candidate selection"

    $dirtyRepoStatePath = Join-Path $tempRoot "loop-state-dirty-repo.json"
    @{
        selected_mode = "looping"
        status = "running"
        dirty_repo_status = " M docs/superpowers/backlog/ACTIVE.md"
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 1
        iterations = @()
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $dirtyRepoStatePath -Encoding utf8NoBOM
    $dirtyRepoState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $dirtyRepoStatePath)
    Add-Check -Name "loop state rejects dirty repo before selection" -Ok ($dirtyRepoState.exit_code -ne 0 -and $dirtyRepoState.json.reason.Contains("dirty repo")) -Reason "dirty repo should block candidate selection"

    $ownerMismatchStatePath = Join-Path $tempRoot "loop-state-owner-mismatch.json"
    @{
        selected_mode = "looping"
        status = "running"
        dirty_repo_status = ""
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 1
        iterations = @(
            @{
                selected_candidate_id = "86"
                selected_candidate_ids = @("86")
                candidate_source = "active-backlog"
                selected_route = "resolve-issue"
                owner_route = "orchestrate-issues"
                owner_result = @{ status = "merged"; proof = "wrong owner" }
                budget_check_before_selection = @{ ok = $true }
                budget_recheck_after_candidate = @{ ok = $true }
            }
        )
        skipped = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ownerMismatchStatePath -Encoding utf8NoBOM
    $ownerMismatchState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $ownerMismatchStatePath)
    Add-Check -Name "loop state rejects owner route mismatch" -Ok ($ownerMismatchState.exit_code -ne 0 -and $ownerMismatchState.json.reason.Contains("owner route")) -Reason "candidate owner route must match selected route"

    $historicalSkippedStatePath = Join-Path $tempRoot "loop-state-historical-skipped.json"
    @{
        selected_mode = "looping"
        status = "paused"
        dirty_repo_status = ""
        selection_authority = "looping-mode-ledger"
        candidates_ready_count = 0
        iterations = @()
        no_ready_proof = @{ source = "select-candidate"; reason = "no ready candidates" }
        skipped = @(
            @{ id = "archived-plan-checkbox"; source = "historical-checkbox"; reason = "historical checkbox rejected by status" }
        )
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $historicalSkippedStatePath -Encoding utf8NoBOM
    $historicalSkippedState = Invoke-JsonScript -Path $stateMachineScript -Arguments @("-RepoRoot", $RepoRoot, "-StatePath", $historicalSkippedStatePath)
    Add-Check -Name "loop state accepts skipped historical checkbox proof" -Ok ($historicalSkippedState.exit_code -eq 0 -and $historicalSkippedState.json.ok -eq $true) -Reason $historicalSkippedState.raw

    $verifierPath = Join-Path $tempRoot "verifier-ledger.json"
    @{
        candidate_id = "approved-spec-plan"
        route = "write-plan"
        risk = "low"
        verifier_type = "script"
        independent = $false
        proof = @(
            @{ command = "pwsh -File scripts/validate-plan-task-use-cases.ps1"; ok = $true; artifact = "docs/superpowers/plans/fixture.md" }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $verifierPath -Encoding utf8NoBOM
    $verifierOk = Invoke-JsonScript -Path $verifierScript -Arguments @("-RepoRoot", $RepoRoot, "-VerifierLedgerPath", $verifierPath)
    Add-Check -Name "low-risk verifier proof passes" -Ok ($verifierOk.exit_code -eq 0 -and $verifierOk.json.ok -eq $true) -Reason $verifierOk.raw

    $highRiskVerifierPath = Join-Path $tempRoot "high-risk-verifier-ledger.json"
    @{
        candidate_id = "high-risk-merge"
        route = "merge-changes"
        risk = "high"
        verifier_type = "script"
        independent = $false
        proof = @(
            @{ command = "pwsh -File scripts/validate.ps1"; ok = $true; artifact = "validation-output" }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $highRiskVerifierPath -Encoding utf8NoBOM
    $highRiskVerifier = Invoke-JsonScript -Path $verifierScript -Arguments @("-RepoRoot", $RepoRoot, "-VerifierLedgerPath", $highRiskVerifierPath)
    Add-Check -Name "high-risk verifier requires independent proof" -Ok ($highRiskVerifier.exit_code -ne 0 -and $highRiskVerifier.json.reason.Contains("independent verifier proof")) -Reason "high-risk verifier should fail without independent proof"

    $terminalPath = Join-Path $tempRoot "terminal-closeout.json"
    @{
        run_ledger_valid = $true
        verifier_valid = $true
        metrics_valid = $true
        clean_repo_required = $false
        continuation_decision = @{
            question_id = "project_loop_final_health_gate"
            selected_option = "Done"
            terminal_state = "done"
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $terminalPath -Encoding utf8NoBOM
    $terminalOk = Invoke-JsonScript -Path $terminalScript -Arguments @("-RepoRoot", $RepoRoot, "-RunResultPath", $terminalPath)
    Add-Check -Name "terminal done proof passes" -Ok ($terminalOk.exit_code -eq 0 -and $terminalOk.json.ok -eq $true -and $terminalOk.json.selected_option -eq "Done") -Reason $terminalOk.raw

    $terminalStopPath = Join-Path $tempRoot "terminal-stop.json"
    @{
        run_ledger_valid = $true
        verifier_valid = $true
        metrics_valid = $true
        clean_repo_required = $false
        continuation_decision = @{
            question_id = "project_loop_final_health_gate"
            selected_option = "Stop"
            terminal_state = "stop"
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $terminalStopPath -Encoding utf8NoBOM
    $terminalStop = Invoke-JsonScript -Path $terminalScript -Arguments @("-RepoRoot", $RepoRoot, "-RunResultPath", $terminalStopPath)
    Add-Check -Name "terminal stop proof passes as paused" -Ok ($terminalStop.exit_code -eq 0 -and $terminalStop.json.ok -eq $true -and $terminalStop.json.selected_option -eq "Stop") -Reason $terminalStop.raw

    $terminalFailPath = Join-Path $tempRoot "terminal-fail.json"
    @{
        run_ledger_valid = $false
        verifier_valid = $false
        metrics_valid = $false
        clean_repo_required = $true
        clean_repo_status = " M fixture"
        continuation_decision = @{
            question_id = "project_loop_next_step"
            selected_option = "Yes"
            terminal_state = "continue"
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $terminalFailPath -Encoding utf8NoBOM
    $terminalFail = Invoke-JsonScript -Path $terminalScript -Arguments @("-RepoRoot", $RepoRoot, "-RunResultPath", $terminalFailPath)
    $terminalFailureReason = [string]$terminalFail.json.reason
    Add-Check -Name "terminal closeout rejects missing proof and dirty state" -Ok (
        $terminalFail.exit_code -ne 0 -and
        $terminalFailureReason.Contains("run_ledger_valid") -and
        $terminalFailureReason.Contains("verifier_valid") -and
        $terminalFailureReason.Contains("metrics_valid") -and
        $terminalFailureReason.Contains("clean repo") -and
        $terminalFailureReason.Contains("project_loop_final_health_gate")
    ) -Reason "terminal closeout should list every missing proof"

    $metricsInput = Join-Path $tempRoot "metrics-input.json"
    $metricsOutput = Join-Path $tempRoot "metrics-output.json"
    @{
        run_id = "fixture-run"
        started_at = "2026-06-15T00:00:00Z"
        completed_at = "2026-06-15T00:00:05Z"
        attempts_by_phase = @{ candidate_selection = 1; validation = 2; verification = 1 }
        validation_failures_by_phase = @{ validation = 1 }
        retry_count = 1
        human_input_count = 1
        github_mutation_count = 0
        created_pr_count = 0
        closed_issue_count = 0
        reverted_or_reopened_count = 0
        final_outcome = "done"
        accepted_change_evidence = @("skills/loop-controller/scripts/test-scenarios.ps1")
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metricsInput -Encoding utf8NoBOM
    $metrics = Invoke-JsonScript -Path $metricsScript -Arguments @("-RepoRoot", $RepoRoot, "-MetricsInputPath", $metricsInput, "-OutputPath", $metricsOutput)
    $metricsReport = if (Test-Path -LiteralPath $metricsOutput -PathType Leaf) { Get-Content -LiteralPath $metricsOutput -Raw | ConvertFrom-Json } else { $null }
    Add-Check -Name "metrics report writes json" -Ok ($metrics.exit_code -eq 0 -and $metrics.json.ok -eq $true -and $null -ne $metricsReport) -Reason $metrics.raw
    Add-Check -Name "metrics report records required fields" -Ok (
        $null -ne $metricsReport -and
        $metricsReport.elapsed_seconds -eq 5 -and
        $metricsReport.retry_count -eq 1 -and
        $metricsReport.human_input_count -eq 1 -and
        $metricsReport.github_mutation_count -eq 0 -and
        $metricsReport.final_outcome -eq "done" -and
        @($metricsReport.accepted_change_evidence).Count -eq 1
    ) -Reason "metrics report missing required fields"
    Add-Check -Name "metrics report omits unsupported token or billing claims" -Ok (
        $null -ne $metricsReport -and
        -not (Test-LoopControllerProperty -Object $metricsReport -Name "token_count") -and
        -not (Test-LoopControllerProperty -Object $metricsReport -Name "billing_cost")
    ) -Reason "metrics report must not invent token or billing data"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "loop-controller-scenarios"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "loop-controller-scenarios"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    $fixtureRun = Join-Path $RepoRoot ".superpowers\runs\fixture-run"
    if (Test-Path -LiteralPath $fixtureRun) { Remove-Item -LiteralPath $fixtureRun -Recurse -Force }
}
