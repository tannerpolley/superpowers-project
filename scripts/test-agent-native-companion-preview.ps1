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

function Convert-AgentNativeJson {
    param([Parameter(Mandatory = $true)][string]$Text)

    $jsonStart = $Text.IndexOf("{")
    $jsonEnd = $Text.LastIndexOf("}")
    if ($jsonStart -lt 0 -or $jsonEnd -le $jsonStart) {
        throw "Agent-Native command did not emit JSON: $Text"
    }
    $Text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
}

try {
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $tempRoot = Join-Path $tempBase ("agent-native-companion-" + [guid]::NewGuid().ToString("N"))
    $planDir = Join-Path $tempRoot "plans\fixture-agent-native-companion"
    New-Item -ItemType Directory -Path $planDir -Force | Out-Null

    $planPath = Join-Path $planDir "plan.mdx"
    Set-Content -LiteralPath $planPath -Encoding utf8NoBOM -Value @'
# Fixture Agent-Native Companion Plan

> **Decision:** This fixture proves local Agent-Native visual-plan preview works from repo-owned MDX shape.

## Verification

- Native approval remains outside the visual plan.
- The source file is `plans/<slug>/plan.mdx`.
'@

    $checkFixtureRaw = & npx -y @agent-native/core@latest plan local check --dir $planDir 2>&1
    $checkFixtureText = ($checkFixtureRaw | Out-String).Trim()
    Add-Check -Name "fixture check exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $checkFixtureText
    $checkFixtureJson = Convert-AgentNativeJson -Text $checkFixtureText
    Add-Check -Name "fixture schema validates" -Ok ($checkFixtureJson.ok -eq $true -and $checkFixtureJson.validation -eq "passed") -Reason $checkFixtureText

    $raw = & npx -y @agent-native/core@latest plan local preview --dir $planDir --kind plan 2>&1
    $text = ($raw | Out-String).Trim()
    Add-Check -Name "preview command exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $text
    $json = Convert-AgentNativeJson -Text $text
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

    $verifyRaw = & npx -y @agent-native/core@latest plan local verify --dir $planDir --kind plan --port 0 2>&1
    $verifyText = ($verifyRaw | Out-String).Trim()
    Add-Check -Name "fixture bridge verify exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $verifyText
    $verifyJson = Convert-AgentNativeJson -Text $verifyText
    Add-Check -Name "fixture bridge verify passes" -Ok ($verifyJson.ok -eq $true -and $verifyJson.bridge.ok -eq $true -and $verifyJson.bridge.localOnly -eq $true) -Reason $verifyText

    $repoPlanDir = Join-Path $RepoRoot "plans\agent-native-companion-replacement"
    if (Test-Path -LiteralPath (Join-Path $repoPlanDir "plan.mdx") -PathType Leaf) {
        $checkRaw = & npx -y @agent-native/core@latest plan local check --dir $repoPlanDir 2>&1
        $checkText = ($checkRaw | Out-String).Trim()
        Add-Check -Name "checked-in companion check exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $checkText
        $checkJson = Convert-AgentNativeJson -Text $checkText
        Add-Check -Name "checked-in companion schema validates" -Ok ($checkJson.ok -eq $true -and $checkJson.validation -eq "passed") -Reason $checkText

        $repoVerifyRaw = & npx -y @agent-native/core@latest plan local verify --dir $repoPlanDir --kind plan --port 0 2>&1
        $repoVerifyText = ($repoVerifyRaw | Out-String).Trim()
        Add-Check -Name "checked-in companion bridge verify exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $repoVerifyText
        $repoVerifyJson = Convert-AgentNativeJson -Text $repoVerifyText
        Add-Check -Name "checked-in companion bridge verify passes" -Ok ($repoVerifyJson.ok -eq $true -and $repoVerifyJson.bridge.ok -eq $true -and $repoVerifyJson.bridge.localOnly -eq $true) -Reason $repoVerifyText

        $repoPreviewPath = Join-Path $tempRoot "repo-companion-preview.html"
        $repoPreviewRaw = & npx -y @agent-native/core@latest plan local preview --dir $repoPlanDir --kind plan --out $repoPreviewPath 2>&1
        $repoPreviewText = ($repoPreviewRaw | Out-String).Trim()
        Add-Check -Name "checked-in companion preview exits zero" -Ok ($LASTEXITCODE -eq 0) -Reason $repoPreviewText
        $repoPreviewJson = Convert-AgentNativeJson -Text $repoPreviewText
        Add-Check -Name "checked-in companion preview output exists" -Ok ($repoPreviewJson.ok -eq $true -and (Test-Path -LiteralPath $repoPreviewPath -PathType Leaf)) -Reason $repoPreviewText
        if (Test-Path -LiteralPath $repoPreviewPath -PathType Leaf) {
            $repoPreviewHtml = Get-Content -Raw -LiteralPath $repoPreviewPath
            $rawBlockPattern = '<(AnnotatedCode|Callout|Checklist|Code|Columns|DataModel|Diagram|Diff|Endpoint|FileTree|HtmlBlock|Json|Mermaid|OpenApi|QuestionForm|Table|TabsBlock|VisualQuestions|WireframeBlock)\b'
            Add-Check -Name "checked-in companion preview hides raw Agent-Native components" -Ok (-not [regex]::IsMatch($repoPreviewHtml, $rawBlockPattern)) -Reason "preview HTML contains raw Agent-Native JSX component source"
            $rawMarkdownPattern = '<p>\s*(\||&gt;|\[ \])'
            Add-Check -Name "checked-in companion preview avoids raw Markdown-only structures" -Ok (-not [regex]::IsMatch($repoPreviewHtml, $rawMarkdownPattern)) -Reason "preview HTML contains literal table, blockquote, or checkbox Markdown"
        }
    }

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
