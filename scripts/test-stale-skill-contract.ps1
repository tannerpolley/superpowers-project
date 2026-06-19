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

try {
    $liveRoot = Join-Path ([IO.Path]::GetTempPath()) ("stale-live-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path (Join-Path $liveRoot "skills\brainstorm-spec\agents") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot "skills\brainstorm-spec\SKILL.md") -Destination (Join-Path $liveRoot "skills\brainstorm-spec\SKILL.md")
    Copy-Item -LiteralPath (Join-Path $RepoRoot "skills\brainstorm-spec\agents\openai.yaml") -Destination (Join-Path $liveRoot "skills\brainstorm-spec\agents\openai.yaml")
    $okRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\detect-stale-skill-contract.ps1") -RepoRoot $RepoRoot -LivePluginRoot $liveRoot -SkillName "brainstorm-spec" -ExpectedQuestionId "project_brainstorm_plan_route"
    $okResult = ($okRaw | Out-String | ConvertFrom-Json)
    Add-Check -Name "fresh live skill passes" -Ok ($okResult.ok -eq $true) -Reason "fresh live skill should pass"

    $staleText = (Get-Content -LiteralPath (Join-Path $liveRoot "skills\brainstorm-spec\SKILL.md") -Raw).Replace("project_brainstorm_plan_route", "project_old_route")
    Set-Content -LiteralPath (Join-Path $liveRoot "skills\brainstorm-spec\SKILL.md") -Value $staleText -Encoding utf8NoBOM
    $badRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\detect-stale-skill-contract.ps1") -RepoRoot $RepoRoot -LivePluginRoot $liveRoot -SkillName "brainstorm-spec" -ExpectedQuestionId "project_brainstorm_plan_route" 2>&1
    $badExit = $LASTEXITCODE
    $badResult = ($badRaw | Out-String | ConvertFrom-Json)
    Add-Check -Name "stale live skill fails" -Ok ($badExit -ne 0 -and $badResult.ok -eq $false) -Reason "stale live skill should fail"
    Add-Check -Name "stale recovery guidance present" -Ok ([string]$badResult.recommended_recovery -like "*re-ask the native gate*") -Reason "stale detector must provide recovery guidance"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "stale-skill-contract-tests"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "stale-skill-contract-tests"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($liveRoot -and (Test-Path -LiteralPath $liveRoot)) {
        $resolvedTemp = [IO.Path]::GetFullPath($liveRoot)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
