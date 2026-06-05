function Test-AutoModeAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Authorization,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    function Has-AuthProperty {
        param([object]$Object, [string]$Name)
        if ($Object -is [System.Collections.IDictionary]) {
            return $Object.Contains($Name)
        }
        return $null -ne $Object -and (@($Object.PSObject.Properties.Name) -contains $Name)
    }

    $requiredFields = @(
        "question_id",
        "source",
        "selected_authority",
        "source_spec",
        "route_policy",
        "decision_policy",
        "merge_permission",
        "mutation_scope",
        "required_proof",
        "stop_conditions"
    )

    foreach ($field in $requiredFields) {
        if (-not (Has-AuthProperty -Object $Authorization -Name $field)) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "missing $field" }
        }
    }

    if ([string]$Authorization.question_id -ne "project_auto_mode_authorization") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "question_id must be project_auto_mode_authorization" }
    }
    if ([string]$Authorization.source -ne "request_user_input") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "source must be request_user_input" }
    }
    if ([string]$Authorization.selected_authority -ne "bounded-auto-merge") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "selected_authority must be bounded-auto-merge" }
    }

    $specPath = Join-Path $RepoRoot ([string]$Authorization.source_spec)
    $specRoot = Join-Path $RepoRoot "docs\superpowers\specs"
    $resolvedSpecRoot = [IO.Path]::GetFullPath($specRoot)
    $resolvedSpecPath = [IO.Path]::GetFullPath($specPath)
    if (-not $resolvedSpecPath.StartsWith($resolvedSpecRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "source_spec must be under docs/superpowers/specs" }
    }
    if (-not (Test-Path -LiteralPath $resolvedSpecPath -PathType Leaf)) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "source_spec does not exist" }
    }

    if ([string]$Authorization.route_policy.selected_mode -ne "agent-chooses") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "route_policy.selected_mode must be agent-chooses" }
    }
    if ([string]$Authorization.route_policy.worker_route -ne "issue-backed-orchestrate-only") {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "worker_route must be issue-backed-orchestrate-only" }
    }
    if ([string]$Authorization.decision_policy.selected_mode -ne "recorded-defaults" -or $Authorization.decision_policy.stop_outside_policy -ne $true) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "decision_policy must use recorded-defaults and stop_outside_policy true" }
    }
    if ([string]$Authorization.merge_permission.selected_mode -ne "preauthorized-after-clean-premerge" -or $Authorization.merge_permission.require_clean_premerge -ne $true) {
        return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "merge_permission must require clean premerge" }
    }

    foreach ($needed in @("current-repo", "development-branch")) {
        if (@($Authorization.mutation_scope) -notcontains $needed) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "mutation_scope missing $needed" }
        }
    }
    foreach ($needed in @("plan-proof-oracle", "verification-receipts", "cleanup-hook", "premerge-proof", "closeout-proof")) {
        if (@($Authorization.required_proof) -notcontains $needed) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "required_proof missing $needed" }
        }
    }
    foreach ($needed in @("missing-proof", "dirty-unsafe-state", "failed-validation", "decision-outside-policy")) {
        if (@($Authorization.stop_conditions) -notcontains $needed) {
            return [pscustomobject]@{ ok = $false; phase = "auto-mode-authorization"; reason = "stop_conditions missing $needed" }
        }
    }

    [pscustomobject]@{ ok = $true; phase = "auto-mode-authorization"; reason = "passed" }
}
