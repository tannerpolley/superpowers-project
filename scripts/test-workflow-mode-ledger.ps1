[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("workflow-mode-ledger-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Write-Ledger {
    param([string]$Name, [hashtable]$Ledger)
    $path = Join-Path $tempRoot $Name
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $Ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    $path
}

function Invoke-Validator {
    param([string]$Path, [string]$ActiveRepoRoot = $RepoRoot)
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/validate-workflow-mode-ledger.ps1") -RepoRoot $ActiveRepoRoot -ModeLedgerPath $Path 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        raw = ($raw | Out-String).Trim()
        json = (($raw | Out-String).Trim() | ConvertFrom-Json)
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $base = @{
        question_id = "project_workflow_mode"
        source = "request_user_input"
        repo_root = $RepoRoot
        plugin_manifest_version = "0.2.0+fixture"
        plugin_contract_hash = "fixture"
        started_at = "2026-06-16T00:00:00Z"
        mutation_scope = @("current-repo", "development-branch")
        route_policy = @{ use_existing_flowchart = $true }
        proof_policy = @{ require_final_proof = $true; require_clean_repo_for_done = $true }
        stop_conditions = @("missing-proof", "failed-validation", "decision-outside-policy")
        downstream_ledger_paths = @()
    }

    $manual = $base.Clone()
    $manual.selected_mode = "manual"
    $manual.autonomy_scope = "ask-every-material-decision"
    $manual.candidate_scope = @()

    $auto = $base.Clone()
    $auto.selected_mode = "auto"
    $auto.autonomy_scope = "one-route"
    $auto.candidate_scope = @("selected-route")
    $auto.route_policy = @{ use_existing_flowchart = $true; one_route_only = $true; continue_to_next_candidate = $false }

    $looping = $base.Clone()
    $looping.selected_mode = "looping"
    $looping.autonomy_scope = "bounded-loop"
    $looping.candidate_scope = @("ready-issues", "approved-plans", "saved-specs", "audit-findings", "alignment-drift", "stale-version")
    $looping.budget_policy = @{ max_candidates = 3; max_attempts_per_phase = 2; max_github_mutations = 6 }

    foreach ($fixture in @(
        @{ name = "manual passes"; path = Write-Ledger "manual.json" $manual; ok = $true },
        @{ name = "auto passes"; path = Write-Ledger "auto.json" $auto; ok = $true },
        @{ name = "looping passes"; path = Write-Ledger "looping.json" $looping; ok = $true }
    )) {
        $result = Invoke-Validator $fixture.path
        Add-Check $fixture.name ($result.exit_code -eq 0 -and $result.json.ok -eq $true) $result.raw
    }

    $badAuto = $auto.Clone()
    $badAuto.route_policy = @{ use_existing_flowchart = $true; one_route_only = $true; continue_to_next_candidate = $true }
    $badAutoResult = Invoke-Validator (Write-Ledger "bad-auto.json" $badAuto)
    Add-Check "auto queue authority fails" ($badAutoResult.exit_code -ne 0 -and [string]$badAutoResult.json.reason -match "one-route") "Auto Mode queue authority should fail"

    $badLooping = $looping.Clone()
    $badLooping.Remove("budget_policy")
    $badLoopingResult = Invoke-Validator (Write-Ledger "bad-looping.json" $badLooping)
    Add-Check "looping without budget fails" ($badLoopingResult.exit_code -ne 0 -and [string]$badLoopingResult.json.reason -match "budget_policy") "Looping Mode without budget must fail"

    $externalRoot = Join-Path $tempRoot "external-target-repo"
    New-Item -ItemType Directory -Path (Join-Path $externalRoot ".superpowers\runs\external-loop") -Force | Out-Null
    $externalLooping = $looping.Clone()
    $externalLooping.repo_root = $externalRoot
    $externalLedgerPath = Join-Path $externalRoot ".superpowers\runs\external-loop\workflow-mode-ledger.json"
    $externalLooping | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $externalLedgerPath -Encoding utf8NoBOM
    $externalResult = Invoke-Validator ".superpowers\runs\external-loop\workflow-mode-ledger.json" $externalRoot
    Add-Check "external project repo mode ledger passes" ($externalResult.exit_code -eq 0 -and $externalResult.json.ok -eq $true) "Plugin-rooted validator must accept ledgers in a target repo without target repo scripts"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "workflow-mode-ledger"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check "fatal" $false $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "workflow-mode-ledger"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
