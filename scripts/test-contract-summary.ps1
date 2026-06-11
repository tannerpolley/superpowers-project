[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } })
}

function Normalize-Text {
    param([string]$Text)
    (($Text -replace "\r\n", "`n") -replace "\r", "`n").Trim()
}

try {
    $summaryPath = Join-Path $RepoRoot "docs\superpowers\CONTRACT_SUMMARY.md"
    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        throw "contract summary is missing"
    }

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("contract-summary-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $generatedPath = Join-Path $tempDir "CONTRACT_SUMMARY.md"
    $resultRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\generate-contract-summary.ps1") -RepoRoot $RepoRoot -OutputPath $generatedPath
    if ($LASTEXITCODE -ne 0) { throw "generator failed: $($resultRaw | Out-String)" }
    $current = Get-Content -LiteralPath $summaryPath -Raw
    $generated = Get-Content -LiteralPath $generatedPath -Raw
    Add-Check -Name "generated summary is current" -Ok ((Normalize-Text $current) -eq (Normalize-Text $generated)) -Reason "docs/superpowers/CONTRACT_SUMMARY.md is stale; run scripts/generate-contract-summary.ps1"

    foreach ($needle in @(
        '$superpowers-project:*',
        'project_brainstorm_start_route',
        'project_merge_final_health_gate',
        'debug_question_mode',
        'scripts/sync-live.ps1 -Validate',
        'get-agent-plugin-version.ps1',
        '-Banner -RequireCurrent',
        'Startup Version Check',
        'contract_hash',
        'ObservedSkillRoot',
        'matching local plugin cache roots',
        'Plugin cache paths are not durable contracts'
    )) {
        Add-Check -Name "summary contains $needle" -Ok $current.Contains($needle) -Reason "contract summary missing $needle"
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "contract-summary"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "contract-summary"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempDir)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
