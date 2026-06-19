[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = $null

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    }) | Out-Null
}

try {
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $tempRoot = Join-Path $tempBase ("agent-native-companion-" + [guid]::NewGuid().ToString("N"))
    $planDir = Join-Path $tempRoot "plans\fixture-agent-native-companion"
    New-Item -ItemType Directory -Path $planDir -Force | Out-Null

    $planPath = Join-Path $planDir "plan.mdx"
    Set-Content -LiteralPath $planPath -Encoding utf8NoBOM -Value @'
# Fixture Agent-Native Companion Plan

<Callout id="fixture-decision" tone="decision">

This fixture proves local Agent-Native visual-plan preview works from repo-owned MDX shape.

</Callout>

## Verification

- Native approval remains outside the visual plan.
- The source file is `plans/<slug>/plan.mdx`.
'@

    $raw = & npx -y @agent-native/core@latest plan local preview --dir $planDir --kind plan 2>&1
    $text = ($raw | Out-String).Trim()
    Add-Check -Name "preview command exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $text
    $jsonStart = $text.IndexOf("{")
    $jsonEnd = $text.LastIndexOf("}")
    if ($jsonStart -lt 0 -or $jsonEnd -le $jsonStart) {
        throw "preview command did not emit JSON: $text"
    }
    $json = $text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
    Add-Check -Name "preview reports ok" -Ok ($json.ok -eq $true) -Reason $text
    $previewTargetOk = $false
    if (-not [string]::IsNullOrWhiteSpace([string]$json.out)) {
        $previewTargetOk = Test-Path -LiteralPath $json.out -PathType Leaf
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$json.url)) {
        $previewUri = $null
        $previewTargetOk = [Uri]::TryCreate([string]$json.url, [UriKind]::Absolute, [ref]$previewUri) -and
            @("http", "https", "file").Contains($previewUri.Scheme)
    }
    Add-Check -Name "preview target returned" -Ok $previewTargetOk -Reason "preview output or URL missing"
    Add-Check -Name "preview includes plan source" -Ok (@($json.files) -contains "plan.mdx") -Reason "plan.mdx was not reported"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{
        ok = ($failed.Count -eq 0)
        phase = "agent-native-companion-preview"
        checks = $checks
    } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{
        ok = $false
        phase = "agent-native-companion-preview"
        reason = $_.Exception.Message
        checks = $checks
    } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
        if ($resolvedTemp.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $resolvedTemp)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
