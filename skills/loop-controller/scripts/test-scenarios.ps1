[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
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
