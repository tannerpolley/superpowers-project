[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$helper = Join-Path $repoRoot "scripts\lib\auto-mode-contract.ps1"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Add-Result -Name $Name -Ok $true -Reason "passed"
    } catch {
        Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message
    }
}

Invoke-Scenario "helper exists" {
    if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) { throw "missing helper: $helper" }
}

if (Test-Path -LiteralPath $helper -PathType Leaf) {
    . $helper
}

function New-HappyAuthorization {
    @{
        question_id = "project_auto_mode_authorization"
        source = "request_user_input"
        selected_authority = "bounded-auto-merge"
        source_spec = "docs/superpowers/specs/2026-06-04-auto-mode-after-spec-design.md"
        route_policy = @{
            selected_mode = "agent-chooses"
            direct_route = "implement-plan"
            issue_route = "create-issues"
            worker_route = "issue-backed-orchestrate-only"
        }
        decision_policy = @{
            selected_mode = "recorded-defaults"
            stop_outside_policy = $true
        }
        merge_permission = @{
            selected_mode = "preauthorized-after-clean-premerge"
            require_clean_premerge = $true
        }
        mutation_scope = @("current-repo", "development-branch", "github-issues", "github-pr", "merge")
        required_proof = @("plan-proof-oracle", "verification-receipts", "cleanup-hook", "premerge-proof", "closeout-proof")
        stop_conditions = @("missing-proof", "dirty-unsafe-state", "failed-validation", "github-auth-failure", "pending-required-check", "decision-outside-policy")
    }
}

Invoke-Scenario "happy authorization passes" {
    $result = Test-AutoModeAuthorization -Authorization (New-HappyAuthorization) -RepoRoot $repoRoot
    if (-not $result.ok) { throw $result.reason }
}

foreach ($field in @("question_id", "source_spec", "route_policy", "decision_policy", "merge_permission", "mutation_scope", "required_proof", "stop_conditions")) {
    Invoke-Scenario "missing $field blocks" {
        $auth = New-HappyAuthorization
        $auth.Remove($field)
        $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
        if ($result.ok) { throw "missing $field should fail" }
    }
}

Invoke-Scenario "direct worker mode blocks" {
    $auth = New-HappyAuthorization
    $auth.route_policy.worker_route = "direct-implement-worker"
    $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
    if ($result.ok) { throw "direct Auto Mode workers are out of first-pass scope" }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
