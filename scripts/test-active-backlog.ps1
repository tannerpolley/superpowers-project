[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("active-backlog-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-JsonScript {
    param([string]$Path, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ exit_code = 127; raw = "missing script: $Path"; json = $null }
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    $text = ($raw | Out-String).Trim()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = $text; json = $json }
}

function Write-BacklogFixture {
    param([string]$Path, [string[]]$Rows)
    @(
        "# Active Backlog Fixture",
        "",
        "| ID | Route owner | Source artifact | Priority | Status | Proof target | Reason |",
        "|---|---|---|---|---|---|---|"
    ) + $Rows | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $validator = Join-Path $RepoRoot "scripts\validate-active-backlog.ps1"
    $selector = Join-Path $RepoRoot "skills\loop-controller\scripts\select-candidate.ps1"

    $validBacklog = Join-Path $tempRoot "valid-active.md"
    Write-BacklogFixture -Path $validBacklog -Rows @(
        "| 70 | resolve-issue | docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md | P2 | ready | pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1 | Add worker handoff and PR-ready packets. |",
        "| 71 | resolve-issue | docs/superpowers/issues/71-golden-path-workflow-fixtures.md | P2 | blocked | pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-examples.ps1 | Blocked by worker packets. |"
    )
    $valid = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $validBacklog)
    Add-Check -Name "valid active backlog passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true -and $valid.json.ready_count -eq 1) -Reason $valid.raw

    $missingProof = Join-Path $tempRoot "missing-proof.md"
    Write-BacklogFixture -Path $missingProof -Rows @(
        "| 70 | resolve-issue | docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md | P2 | ready |  | missing proof target |"
    )
    $missingProofResult = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $missingProof)
    Add-Check -Name "missing proof target fails" -Ok ($missingProofResult.exit_code -ne 0 -and $missingProofResult.raw.Contains("proof target")) -Reason "missing proof target should fail"

    $unsupportedRoute = Join-Path $tempRoot "unsupported-route.md"
    Write-BacklogFixture -Path $unsupportedRoute -Rows @(
        "| 99 | unknown-route | docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md | P2 | ready | pwsh.exe -File fixture.ps1 | bad route |"
    )
    $unsupportedRouteResult = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $unsupportedRoute)
    Add-Check -Name "unsupported route owner fails" -Ok ($unsupportedRouteResult.exit_code -ne 0 -and $unsupportedRouteResult.raw.Contains("Route owner")) -Reason "unsupported route should fail"

    $historicalCheckbox = Join-Path $tempRoot "historical-checkbox.md"
    Write-BacklogFixture -Path $historicalCheckbox -Rows @(
        "| old-checkbox | resolve-issue | - [ ] Task 6 historical plan checkbox | P3 | ready | pwsh.exe -File fixture.ps1 | plan checkbox noise |"
    )
    $historicalCheckboxResult = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $historicalCheckbox)
    Add-Check -Name "historical checkbox source fails" -Ok ($historicalCheckboxResult.exit_code -ne 0 -and $historicalCheckboxResult.raw.Contains("historical checkbox")) -Reason "historical checkbox source should fail"

    $selectorBacklog = Join-Path $tempRoot "selector-active.md"
    Write-BacklogFixture -Path $selectorBacklog -Rows @(
        "| old-plan | write-plan | docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md | P0 | archived | historical checkbox | archived historical checkbox |",
        "| 70 | resolve-issue | docs/superpowers/issues/70-worker-handoff-pr-ready-packets.md | P2 | ready | pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1 | Add worker handoff and PR-ready packets. |"
    )
    $selection = Invoke-JsonScript -Path $selector -Arguments @("-RepoRoot", $RepoRoot, "-InventoryPath", $selectorBacklog)
    Add-Check -Name "selector chooses active backlog item" -Ok ($selection.exit_code -eq 0 -and $selection.json.selected_candidate_id -eq "70") -Reason $selection.raw
    Add-Check -Name "selector skips archived historical row" -Ok (@($selection.json.skipped | Where-Object { $_.id -eq "old-plan" -and $_.reason -match "status" }).Count -eq 1) -Reason "archived row should be skipped"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "active-backlog"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "active-backlog"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
