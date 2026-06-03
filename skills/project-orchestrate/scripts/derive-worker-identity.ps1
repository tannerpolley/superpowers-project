[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$IssueFile
)

$ErrorActionPreference = "Stop"
$phase = "derive-worker-identity"

function Complete {
    param([bool]$Ok, [string]$Reason, [object]$Identity = $null)
    [ordered]@{ ok = $Ok; phase = $phase; reason = $Reason; identity = $Identity } | ConvertTo-Json -Depth 16
    if ($Ok) { exit 0 }
    exit 1
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    foreach ($pattern in @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    $null
}

function Convert-SlugToTitle {
    param([string]$Slug)
    $words = @($Slug -split '-' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $knownTitle = @{
        "api" = "API"
        "ci" = "CI"
        "github" = "GitHub"
        "ui" = "UI"
        "pr" = "PR"
        "tdd" = "TDD"
        "project" = "Project"
        "doctor" = "Doctor"
        "codex" = "Codex"
    }
    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $words.Count; $i++) {
        $word = $words[$i].ToLowerInvariant()
        if ($knownTitle.ContainsKey($word)) {
            $out.Add($knownTitle[$word]) | Out-Null
        } elseif ($i -eq 0) {
            $out.Add($word.Substring(0, 1).ToUpperInvariant() + $word.Substring(1)) | Out-Null
        } else {
            $out.Add($word) | Out-Null
        }
    }
    $out -join " "
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $issuePath = if ([IO.Path]::IsPathRooted($IssueFile)) {
        [IO.Path]::GetFullPath($IssueFile)
    } else {
        [IO.Path]::GetFullPath((Join-Path $root $IssueFile))
    }
    if (-not (Test-Path -LiteralPath $issuePath -PathType Leaf)) { throw "issue mirror is missing" }
    $relative = ([IO.Path]::GetRelativePath($root, $issuePath) -replace '\\', '/')
    if (-not $relative.StartsWith("docs/superpowers/issues/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "issue mirror must be under docs/superpowers/issues"
    }
    $text = Get-Content -LiteralPath $issuePath -Raw
    $fileBase = [IO.Path]::GetFileNameWithoutExtension($issuePath)
    $issueUrl = Get-FieldValue -Text $text -Name "GitHub Issue"
    $issueNumber = $null
    if ($issueUrl -match '/issues/(?<n>\d+)(?:$|[?#])') { $issueNumber = [int]$Matches.n }
    if ($null -eq $issueNumber -and $fileBase -match '^(?<n>\d+)-(?<slug>.+)$') { $issueNumber = [int]$Matches.n }
    if ($null -eq $issueNumber) { throw "issue number must be present in GitHub Issue URL or issue mirror filename" }
    $slug = if ($fileBase -match '^\d+-(?<slug>.+)$') { $Matches.slug } else { $fileBase }
    $slug = (($slug.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '^-|-$', '')
    if ([string]::IsNullOrWhiteSpace($slug)) { throw "issue slug could not be derived" }
    $issueTitle = Convert-SlugToTitle -Slug $slug
    $identity = [ordered]@{
        issue_number = $issueNumber
        issue_slug = $slug
        issue_title = $issueTitle
        issue_mirror = $relative
        issue_url = $issueUrl
        thread_title = "Resolve #${issueNumber}: $issueTitle"
        branch = "codex/issue-${issueNumber}-$slug"
        evidence_folder = "project-orchestrate-issue-${issueNumber}-$slug"
        pr_title = "Resolve #${issueNumber}: $issueTitle"
    }
    Complete -Ok $true -Reason "worker identity derived" -Identity $identity
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
