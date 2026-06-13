$ErrorActionPreference = "Stop"

function Resolve-CompanionRepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
    }
    (Resolve-Path -LiteralPath $RepoRoot).Path
}

function ConvertTo-CompanionRelativePath {
    param([string]$RepoRoot, [string]$Path)
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "path is outside repo root: $candidate"
    }
    ([IO.Path]::GetRelativePath($root, $candidate) -replace "\\", "/")
}

function Assert-CompanionReportRoot {
    param([string]$RepoRoot, [string]$ReportRoot)
    $relative = ConvertTo-CompanionRelativePath -RepoRoot $RepoRoot -Path $ReportRoot
    if (-not $relative.StartsWith(".superpowers/reports/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "report root must be under .superpowers/reports: $relative"
    }
    $relative
}

function New-CompanionRunId {
    param([string]$WorkflowName)
    $safeWorkflow = ($WorkflowName.ToLowerInvariant() -replace "[^a-z0-9-]", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeWorkflow)) { throw "workflow name is required" }
    "$safeWorkflow-" + (Get-Date -Format "HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
}

function Get-CompanionReportRoot {
    param([string]$RepoRoot, [string]$RunId)
    $date = Get-Date -Format "yyyy-MM-dd"
    Join-Path $RepoRoot (Join-Path ".superpowers\reports" (Join-Path $date $RunId))
}

function Write-CompanionJson {
    param([string]$Path, [object]$Value)
    $json = $Value | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $Path -Encoding utf8NoBOM -Value $json
}

function ConvertTo-CompanionJsonLine {
    param([object]$Value)
    $Value | ConvertTo-Json -Depth 20 -Compress
}

function ConvertTo-CompanionHtmlText {
    param([AllowNull()][object]$Value)
    [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Resolve-CompanionArtifactFile {
    param([string]$RepoRoot, [string]$ArtifactPath)
    if ([string]::IsNullOrWhiteSpace($ArtifactPath)) { throw "artifact path is required" }
    $relative = ConvertTo-CompanionRelativePath -RepoRoot $RepoRoot -Path $ArtifactPath
    $resolved = [IO.Path]::GetFullPath((Join-Path $RepoRoot $relative))
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "artifact file is missing: $relative" }
    [pscustomobject]@{
        full_path = $resolved
        relative_path = $relative
    }
}

function ConvertTo-CompanionReportRelativePath {
    param([string]$ReportRoot, [string]$ArtifactFullPath)
    $reportRootPath = [IO.Path]::GetFullPath($ReportRoot)
    $artifactPath = [IO.Path]::GetFullPath($ArtifactFullPath)
    if (-not $artifactPath.StartsWith($reportRootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "artifact must be inside report root for browser rendering: $artifactPath"
    }
    ([IO.Path]::GetRelativePath($reportRootPath, $artifactPath) -replace "\\", "/")
}

function Split-CompanionMarkdownFrontmatter {
    param([string]$MarkdownPath)
    $text = Get-Content -LiteralPath $MarkdownPath -Raw
    $match = [regex]::Match($text, "\A---\r?\n(?<frontmatter>.*?)\r?\n---\r?\n", [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { return [pscustomobject]@{ frontmatter = ""; body = $text } }
    [pscustomobject]@{
        frontmatter = $match.Groups["frontmatter"].Value.Trim()
        body = $text.Substring($match.Length)
    }
}

function Convert-CompanionMarkdownToHtml {
    param([Parameter(Mandatory = $true)][string]$MarkdownPath)
    if (-not (Test-Path -LiteralPath $MarkdownPath -PathType Leaf)) { throw "markdown artifact is missing: $MarkdownPath" }
    $pandoc = Get-Command pandoc -ErrorAction Stop
    $rendered = & $pandoc.Source --from gfm+yaml_metadata_block+tex_math_dollars --to html5 --mathml --highlight-style=tango $MarkdownPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "pandoc markdown render failed for $MarkdownPath using $($pandoc.Source): $($rendered | Out-String)"
    }
    $parts = Split-CompanionMarkdownFrontmatter -MarkdownPath $MarkdownPath
    $frontmatterHtml = ""
    if (-not [string]::IsNullOrWhiteSpace([string]$parts.frontmatter)) {
        $frontmatterHtml = "<aside class=""frontmatter""><h4>YAML Frontmatter</h4><pre>$([System.Net.WebUtility]::HtmlEncode([string]$parts.frontmatter))</pre></aside>"
    }
    $bodyHtml = ($rendered | Out-String).Trim()
    $bodyHtml = $bodyHtml -replace '\s+xmlns="http://www\.w3\.org/1998/Math/MathML"', ""
    "<div class=""markdown-artifact"">$frontmatterHtml$bodyHtml</div>"
}

function ConvertTo-CompanionStatusClass {
    param([AllowNull()][object]$Value)
    $status = ([string]$Value).ToLowerInvariant()
    switch ($status) {
        "pass" { "status-pass" }
        "passed" { "status-pass" }
        "success" { "status-pass" }
        "ok" { "status-pass" }
        "fail" { "status-fail" }
        "failed" { "status-fail" }
        "error" { "status-fail" }
        "warn" { "status-warn" }
        "warning" { "status-warn" }
        default { "" }
    }
}

function Convert-CompanionTableToHtml {
    param([Parameter(Mandatory = $true)][string]$TablePath)
    if (-not (Test-Path -LiteralPath $TablePath -PathType Leaf)) { throw "table artifact is missing: $TablePath" }
    $extension = [IO.Path]::GetExtension($TablePath).ToLowerInvariant()
    if ($extension -eq ".csv") {
        $rows = @(Import-Csv -LiteralPath $TablePath)
    } elseif ($extension -eq ".json") {
        $json = Get-Content -LiteralPath $TablePath -Raw | ConvertFrom-Json
        $rows = @($json)
    } else {
        throw "table artifact must be .csv or .json: $TablePath"
    }
    if ($rows.Count -eq 0) { return '<p class="empty">No table rows.</p>' }
    $columns = @($rows | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique)
    $head = ($columns | ForEach-Object { "<th>$(ConvertTo-CompanionHtmlText $_)</th>" }) -join ""
    $bodyRows = foreach ($row in $rows) {
        $cells = foreach ($column in $columns) {
            $value = $row.$column
            $class = ConvertTo-CompanionStatusClass -Value $value
            $classAttribute = if ([string]::IsNullOrWhiteSpace($class)) { "" } else { " class=""$class""" }
            "<td$classAttribute>$(ConvertTo-CompanionHtmlText $value)</td>"
        }
        "<tr>$($cells -join '')</tr>"
    }
    "<table class=""artifact-table""><thead><tr>$head</tr></thead><tbody>$($bodyRows -join '')</tbody></table>"
}

function Convert-CompanionValidationToHtml {
    param([object]$Payload)
    $command = if ($null -ne $Payload -and $Payload.PSObject.Properties.Name -contains "command") { [string]$Payload.command } else { "" }
    $workingDirectory = if ($null -ne $Payload -and $Payload.PSObject.Properties.Name -contains "working_directory") { [string]$Payload.working_directory } else { "" }
    $exitCode = if ($null -ne $Payload -and $Payload.PSObject.Properties.Name -contains "exit_code") { [string]$Payload.exit_code } else { "" }
    $status = if ($null -ne $Payload -and $Payload.PSObject.Properties.Name -contains "status") { [string]$Payload.status } else { "" }
    $excerpt = if ($null -ne $Payload -and $Payload.PSObject.Properties.Name -contains "excerpt") { [string]$Payload.excerpt } else { "" }
    $statusClass = ConvertTo-CompanionStatusClass -Value $status
    @"
<div class="receipt">
  <dl>
    <dt>Command</dt><dd><code>$(ConvertTo-CompanionHtmlText $command)</code></dd>
    <dt>Working directory</dt><dd><code>$(ConvertTo-CompanionHtmlText $workingDirectory)</code></dd>
    <dt>Exit code</dt><dd>$(ConvertTo-CompanionHtmlText $exitCode)</dd>
    <dt>Status</dt><dd class="$statusClass">$(ConvertTo-CompanionHtmlText $status)</dd>
  </dl>
  <pre>$(ConvertTo-CompanionHtmlText $excerpt)</pre>
</div>
"@
}

function Convert-CompanionArtifactPathToHtml {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ReportRoot,
        [Parameter(Mandatory = $true)][string]$ArtifactPath,
        [string]$Caption = ""
    )
    $artifact = Resolve-CompanionArtifactFile -RepoRoot $RepoRoot -ArtifactPath $ArtifactPath
    $extension = [IO.Path]::GetExtension([string]$artifact.full_path).ToLowerInvariant()
    if ($extension -notin @(".svg", ".png", ".jpg", ".jpeg")) {
        throw "plot artifact must be .svg, .png, .jpg, or .jpeg: $($artifact.relative_path)"
    }
    $src = ConvertTo-CompanionReportRelativePath -ReportRoot $ReportRoot -ArtifactFullPath ([string]$artifact.full_path)
    $captionHtml = if ([string]::IsNullOrWhiteSpace($Caption)) { [string]$artifact.relative_path } else { $Caption }
    "<figure class=""plot-artifact""><img src=""$(ConvertTo-CompanionHtmlText $src)"" alt=""$(ConvertTo-CompanionHtmlText $captionHtml)""><figcaption>$(ConvertTo-CompanionHtmlText $captionHtml)</figcaption></figure>"
}
