[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet("spec", "plan")][string]$Kind
)

$ErrorActionPreference = "Stop"
$script:RequiredColumns = @("Decision", "Source", "Answer", "Impact", "Deferred?", "Risk owner")

function Normalize-RelativePath {
    param([string]$Path)
    ($Path -replace '\\', '/').TrimStart('.', '/')
}

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path)
    $rootFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $rootFull $Path)) }
    if (-not $candidate.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $candidate -ne $rootFull) {
        throw "artifact path is outside repo root: $candidate"
    }
    $candidate
}

function Get-MarkdownSection {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $escaped = [regex]::Escape($Name)
    $pattern = "(?ims)^\s{0,3}##\s+$escaped\s*$\r?\n(?<body>.*?)(?=^\s{0,3}##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    $match.Groups["body"].Value
}

function Normalize-ColumnName {
    param([string]$Name)
    (($Name -replace '`', '') -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function Split-MarkdownTableRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith("|")) { $trimmed = $trimmed.Substring(1) }
    if ($trimmed.EndsWith("|")) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
    @($trimmed -split '(?<!\\)\|' | ForEach-Object { ($_ -replace '\\\|', '|').Trim() })
}

function Test-SeparatorRow {
    param([string[]]$Cells)
    if ($Cells.Count -eq 0) { return $false }
    foreach ($cell in $Cells) {
        if ($cell -notmatch '^\s*:?-{3,}:?\s*$') { return $false }
    }
    $true
}

function Test-ConcreteValue {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^(tbd|todo|unknown|unspecified|none|n/a|na|later|someone|owner|-)$') { return $false }
    $true
}

function Test-DeferredValue {
    param([string]$Value)
    $trimmed = $Value.Trim().ToLowerInvariant()
    if ($trimmed -in @("yes", "y", "true", "deferred")) { return [pscustomobject]@{ ok = $true; deferred = $true } }
    if ($trimmed -in @("no", "n", "false", "resolved")) { return [pscustomobject]@{ ok = $true; deferred = $false } }
    [pscustomobject]@{ ok = $false; deferred = $false }
}

function Get-DecisionLedgerRows {
    param([Parameter(Mandatory = $true)][string]$SectionText)

    $lines = [string[]]($SectionText -split "\r?\n")
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch '^\s*\|.*\|\s*$') { continue }
        $header = @(Split-MarkdownTableRow -Line $lines[$index])
        $separatorIndex = $index + 1
        while ($separatorIndex -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$separatorIndex])) {
            $separatorIndex++
        }
        if ($separatorIndex -ge $lines.Count) { break }
        $separator = @(Split-MarkdownTableRow -Line $lines[$separatorIndex])
        if (-not (Test-SeparatorRow -Cells $separator)) { continue }

        $rows = [System.Collections.Generic.List[object]]::new()
        for ($rowIndex = $separatorIndex + 1; $rowIndex -lt $lines.Count; $rowIndex++) {
            $line = [string]$lines[$rowIndex]
            if ([string]::IsNullOrWhiteSpace($line)) { break }
            if ($line -notmatch '^\s*\|.*\|\s*$') { break }
            $cells = @(Split-MarkdownTableRow -Line $line)
            if ($cells.Count -ne $header.Count) {
                throw "Decision Ledger row $($rows.Count + 1) has $($cells.Count) cells but header has $($header.Count)"
            }
            $row = [ordered]@{}
            for ($cellIndex = 0; $cellIndex -lt $header.Count; $cellIndex++) {
                $row[(Normalize-ColumnName -Name $header[$cellIndex])] = $cells[$cellIndex]
            }
            $rows.Add([pscustomobject]$row) | Out-Null
        }

        return [pscustomobject]@{
            columns = $header
            rows = @($rows)
        }
    }

    throw "Decision Ledger must contain a Markdown table"
}

try {
    $repoRootFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
    $artifactFull = Resolve-RepoPath -Root $repoRootFull -Path $Path
    if (-not (Test-Path -LiteralPath $artifactFull -PathType Leaf)) {
        throw "$Kind artifact does not exist: $Path"
    }

    $relativePath = Normalize-RelativePath ([IO.Path]::GetRelativePath($repoRootFull, $artifactFull))
    $requiredPrefix = if ($Kind -eq "spec") { "docs/superpowers/specs/" } else { "docs/superpowers/plans/" }
    if (-not $relativePath.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Kind artifact must be under $requiredPrefix"
    }

    $text = Get-Content -LiteralPath $artifactFull -Raw
    $section = Get-MarkdownSection -Text $text -Name "Decision Ledger"
    if ($null -eq $section) {
        throw "missing ## Decision Ledger"
    }

    $table = Get-DecisionLedgerRows -SectionText $section
    $normalizedColumns = @($table.columns | ForEach-Object { Normalize-ColumnName -Name $_ })
    foreach ($required in $script:RequiredColumns) {
        if ($normalizedColumns -notcontains (Normalize-ColumnName -Name $required)) {
            throw "missing required Decision Ledger column: $required"
        }
    }
    if ($table.rows.Count -eq 0) {
        throw "Decision Ledger must include at least one decision row"
    }

    for ($rowIndex = 0; $rowIndex -lt $table.rows.Count; $rowIndex++) {
        $row = $table.rows[$rowIndex]
        foreach ($required in $script:RequiredColumns) {
            if ($required -in @("Impact", "Risk owner")) { continue }
            $key = Normalize-ColumnName -Name $required
            if (-not (Test-ConcreteValue -Value ([string]$row.$key))) {
                throw "Decision Ledger row $($rowIndex + 1) has empty or weak $required"
            }
        }

        $deferred = Test-DeferredValue -Value ([string]$row.'deferred?')
        if (-not $deferred.ok) {
            throw "Decision Ledger row $($rowIndex + 1) Deferred? must be Yes or No"
        }
        if ($deferred.deferred) {
            if (-not (Test-ConcreteValue -Value ([string]$row.'risk owner'))) {
                throw "Decision Ledger row $($rowIndex + 1) deferred decision lacks a concrete risk owner"
            }
            if (-not (Test-ConcreteValue -Value ([string]$row.impact))) {
                throw "Decision Ledger row $($rowIndex + 1) deferred decision lacks downstream impact"
            }
        } else {
            foreach ($required in @("Impact", "Risk owner")) {
                $key = Normalize-ColumnName -Name $required
                if (-not (Test-ConcreteValue -Value ([string]$row.$key))) {
                    throw "Decision Ledger row $($rowIndex + 1) has empty or weak $required"
                }
            }
        }
    }

    [pscustomobject]@{
        ok = $true
        phase = "decision-ledger"
        kind = $Kind
        path = $relativePath
        reason = "Decision Ledger passed"
        row_count = $table.rows.Count
        required_columns = $script:RequiredColumns
    } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{
        ok = $false
        phase = "decision-ledger"
        kind = $Kind
        path = Normalize-RelativePath $Path
        reason = $_.Exception.Message
    } | ConvertTo-Json -Depth 8
    exit 1
}
