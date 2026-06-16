[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$ModeLedgerPath
)

$ErrorActionPreference = "Stop"

function Test-Property {
    param([object]$Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Test-RequiredField {
    param([object]$Object, [string]$Name)
    if (-not (Test-Property $Object $Name)) { return $false }
    $value = $Object.$Name
    if ($null -eq $value) { return $false }
    if ($value -is [string]) { return -not [string]::IsNullOrWhiteSpace($value) }
    return $true
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $path = if ([IO.Path]::IsPathRooted($ModeLedgerPath)) { $ModeLedgerPath } else { Join-Path $root $ModeLedgerPath }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "mode ledger not found: $ModeLedgerPath" }
    $ledger = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

    $required = @(
        "question_id",
        "source",
        "selected_mode",
        "repo_root",
        "plugin_manifest_version",
        "plugin_contract_hash",
        "started_at",
        "autonomy_scope",
        "mutation_scope",
        "candidate_scope",
        "route_policy",
        "proof_policy",
        "stop_conditions",
        "downstream_ledger_paths"
    )
    $missing = @($required | Where-Object { -not (Test-RequiredField $ledger $_) })
    if ($missing.Count -gt 0) { throw "missing required field(s): $($missing -join ', ')" }
    if ([string]$ledger.question_id -ne "project_workflow_mode") { throw "question_id must be project_workflow_mode" }

    $mode = ([string]$ledger.selected_mode).ToLowerInvariant()
    if ($mode -notin @("manual", "auto", "looping")) { throw "unsupported selected_mode: $($ledger.selected_mode)" }

    if ($mode -eq "manual") {
        if ([string]$ledger.autonomy_scope -ne "ask-every-material-decision") {
            throw "manual mode must use ask-every-material-decision autonomy_scope"
        }
    }

    if ($mode -eq "auto") {
        if ([string]$ledger.autonomy_scope -ne "one-route") { throw "auto mode must be one-route autonomy" }
        if (-not (Test-Property $ledger.route_policy "one_route_only") -or $ledger.route_policy.one_route_only -ne $true) {
            throw "auto mode requires route_policy.one_route_only true"
        }
        if ((Test-Property $ledger.route_policy "continue_to_next_candidate") -and $ledger.route_policy.continue_to_next_candidate -eq $true) {
            throw "auto mode must remain one-route and cannot continue to next candidate"
        }
    }

    if ($mode -eq "looping") {
        if ([string]$ledger.autonomy_scope -ne "bounded-loop") { throw "looping mode must use bounded-loop autonomy_scope" }
        foreach ($field in @("budget_policy", "candidate_scope", "proof_policy", "stop_conditions")) {
            if (-not (Test-Property $ledger $field)) { throw "looping mode requires $field" }
        }
        if (@($ledger.candidate_scope).Count -eq 0) { throw "looping mode requires non-empty candidate_scope" }
        if (@($ledger.stop_conditions).Count -eq 0) { throw "looping mode requires non-empty stop_conditions" }
    }

    [pscustomobject]@{
        ok = $true
        phase = "workflow-mode-ledger"
        selected_mode = $mode
        path = [IO.Path]::GetFullPath($path)
    } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{
        ok = $false
        phase = "workflow-mode-ledger"
        reason = $_.Exception.Message
    } | ConvertTo-Json -Depth 8
    exit 1
}
