[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [string]$Reason = "passed"
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

$checks = [System.Collections.Generic.List[object]]::new()
$readmePath = Join-Path $RepoRoot "README.md"
$svgRelativePath = "docs/assets/native-qa-main-flow.svg"
$svgPath = Join-Path $RepoRoot $svgRelativePath

$readme = Get-Content -LiteralPath $readmePath -Raw
Add-Check $checks "README references SVG" ($readme.Contains("![Native Q&A main workflow flowchart]($svgRelativePath)")) "README must embed $svgRelativePath"
Add-Check $checks "README archived Mermaid removed" (-not $readme.Contains("Archived full setup, Doctor, and router flow")) "README must not keep the archived full Mermaid flowchart"
Add-Check $checks "SVG exists" (Test-Path -LiteralPath $svgPath -PathType Leaf) "missing SVG: $svgPath"

if (Test-Path -LiteralPath $svgPath -PathType Leaf) {
    [xml]$svg = Get-Content -LiteralPath $svgPath -Raw
    $svgText = Get-Content -LiteralPath $svgPath -Raw

    foreach ($needle in @("--bg", "--line", "--label", "@media (prefers-color-scheme: dark)", ".canvas", ".arrow-head")) {
        Add-Check $checks "SVG contains $needle" ($svgText.Contains($needle)) "SVG must contain theme contract token: $needle"
    }

    $rects = @($svg.svg.rect)
    $skillRects = @($rects | Where-Object { $_.class -eq "skill" })
    $sideRects = @($rects | Where-Object { $_.class -eq "side" })
    $stopRects = @($rects | Where-Object { $_.class -eq "stop" })

    $skillXValues = @($skillRects | ForEach-Object { [int]$_.x } | Sort-Object -Unique)
    $skillWidthValues = @($skillRects | ForEach-Object { [int]$_.width } | Sort-Object -Unique)
    Add-Check $checks "skill boxes share x" ($skillXValues.Count -eq 1 -and $skillXValues[0] -eq 520) "skill boxes must all use x=520"
    Add-Check $checks "skill boxes share width" ($skillWidthValues.Count -eq 1 -and $skillWidthValues[0] -eq 360) "skill boxes must all use width=360"
    Add-Check $checks "side boxes left of skills" (@($sideRects | Where-Object { [int]$_.x -ge 520 }).Count -eq 0) "side boxes must be left of the main skill column"
    Add-Check $checks "stop nodes right of skills" (@($stopRects | Where-Object { [int]$_.x -le 880 }).Count -eq 0) "stop nodes must be right of the main skill column"
}

$failed = @($checks | Where-Object { -not $_.ok })
$result = [pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "native-qa-svg-contract"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) {
    exit 1
}
