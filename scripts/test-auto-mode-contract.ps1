[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$helper = Join-Path $repoRoot "scripts\lib\auto-mode-contract.ps1"
$validator = Join-Path $repoRoot "scripts\validate-auto-mode-authorization.ps1"
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

Invoke-Scenario "validator exists" {
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw "missing validator: $validator" }
}

if (Test-Path -LiteralPath $helper -PathType Leaf) {
    . $helper
}

function New-HappyAuthorization {
    param([string]$SourceSpec = "docs/superpowers/specs/2026-06-04-auto-mode-after-spec-design.md")

    @{
        question_id = "project_auto_mode_authorization"
        source = "request_user_input"
        selected_authority = "bounded-auto-merge"
        source_spec = $SourceSpec
        route_policy = @{
            selected_mode = "agent-chooses"
            direct_route = "implement-plan"
            issue_route = "direct-inline-resolve-issue"
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

Invoke-Scenario "ordered authorization passes" {
    $plain = New-HappyAuthorization
    $auth = [ordered]@{}
    foreach ($entry in $plain.GetEnumerator()) { $auth[$entry.Key] = $entry.Value }
    $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
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

Invoke-Scenario "orchestrate-only issue route blocks" {
    $auth = New-HappyAuthorization
    $auth.route_policy.issue_route = "issue-backed-orchestrate-only"
    $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
    if ($result.ok) { throw "orchestrate-only Auto Mode issue routing should fail" }
}

Invoke-Scenario "legacy worker_route field blocks" {
    $auth = New-HappyAuthorization
    $auth.route_policy.worker_route = "issue-backed-orchestrate-only"
    $result = Test-AutoModeAuthorization -Authorization $auth -RepoRoot $repoRoot
    if ($result.ok) { throw "legacy worker_route field should fail" }
}

Invoke-Scenario "plugin validator accepts external project repo" {
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("auto-mode-project-" + [guid]::NewGuid().ToString("N"))
    try {
        $specRel = "docs/superpowers/specs/2026-06-11-auto-mode-fixture.md"
        $specPath = Join-Path $fixtureRoot $specRel
        New-Item -ItemType Directory -Path (Split-Path -Parent $specPath) -Force | Out-Null
        Set-Content -LiteralPath $specPath -Value "# Auto Mode fixture" -Encoding utf8NoBOM
        $auth = New-HappyAuthorization -SourceSpec $specRel
        $json = $auth | ConvertTo-Json -Depth 16 -Compress
        $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $fixtureRoot -AuthorizationJson $json 2>&1
        $result = (($raw | Out-String).Trim() | ConvertFrom-Json)
        if ($LASTEXITCODE -ne 0 -or $result.ok -ne $true) {
            throw "validator rejected external project repo: $($raw | Out-String)"
        }
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) {
            $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
            $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            if ($resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
            }
        }
    }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
