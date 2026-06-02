[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\sync-tree.ps1")

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("milestones-sync-tests-" + [guid]::NewGuid().ToString("N"))
try {
    $source = Join-Path $tempRoot "source"
    $target = Join-Path $tempRoot "target"
    New-Item -ItemType Directory -Path (Join-Path $source "active-skill") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $target "retired-skill") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $target "unrelated-skill") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source "active-skill\SKILL.md") -Value "# Active`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $target "retired-skill\SKILL.md") -Value "# Retired`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $target "unrelated-skill\SKILL.md") -Value "# Unrelated`n" -Encoding UTF8

    Copy-SkillDirectories -SourceRoot $source -TargetRoot $target
    $removed = @(Remove-StaleOwnedSkillDirectories -TargetRoot $target -ActiveSkillNames @("active-skill") -RetiredSkillNames @("retired-skill"))

    if ($removed -ne "retired-skill") { throw "expected retired-skill cleanup, got: $($removed -join ', ')" }
    if (-not (Test-Path -LiteralPath (Join-Path $target "active-skill\SKILL.md") -PathType Leaf)) { throw "active skill was not deployed" }
    if (Test-Path -LiteralPath (Join-Path $target "retired-skill")) { throw "retired owned skill remains" }
    if (-not (Test-Path -LiteralPath (Join-Path $target "unrelated-skill\SKILL.md") -PathType Leaf)) { throw "unrelated skill was removed" }

    Assert-NoTreeDrift -SourceRoot (Join-Path $source "active-skill") -TargetRoot (Join-Path $target "active-skill") -Label "active skill"
    [pscustomobject]@{ ok = $true; removed = $removed } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{ ok = $false; reason = $_.Exception.Message } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
