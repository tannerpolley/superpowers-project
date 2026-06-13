[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    }) | Out-Null
}

function Assert-Contains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    Add-Check -Name $Name -Ok $text.Contains($Needle) -Reason "$Path missing $Needle"
}

try {
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "name: companion-interface" -Name "skill frontmatter exists"
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "evidence and interpretation channel" -Name "skill defines evidence channel"
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "must not record approval" -Name "skill preserves native approvals"
    Assert-Contains -Path "skills\companion-interface\agents\openai.yaml" -Needle "companion-interface" -Name "metadata exists"
    Assert-Contains -Path ".codex-plugin\plugin.json" -Needle '$superpowers-project:companion-interface' -Name "plugin prompt lists companion"
    Assert-Contains -Path "README.md" -Needle '$superpowers-project:companion-interface' -Name "README lists companion"
    Assert-Contains -Path "docs\superpowers\PROJECT_CONTEXT.md" -Needle "companion-interface" -Name "project context lists companion"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "companion-interface-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "companion-interface-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
