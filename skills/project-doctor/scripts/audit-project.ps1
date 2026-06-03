[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [ValidateSet("LocalDocs", "GitHubAware")][string]$Mode = "LocalDocs",
    [string]$IssueFixturePath,
    [string]$MilestoneFixturePath,
    [string]$LabelFixturePath
)

$ErrorActionPreference = "Stop"
$phase = "audit-project"

function Write-AuditResult {
    param([bool]$Ok, [string]$Reason, [object]$Findings, [object[]]$CheckedArtifacts)
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        mode = $Mode
        checked_artifacts = $CheckedArtifacts
        findings = $Findings
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Resolve-RepoRoot {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "repo root does not exist: $Path" }
    [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
}

function Normalize-RepoPath {
    param([string]$Path)
    if ($null -eq $Path) { return "" }
    ($Path -replace '\\', '/').Trim()
}

function Get-RelativeRepoPath {
    param([string]$RepoRoot, [string]$Path)
    Normalize-RepoPath ([IO.Path]::GetRelativePath($RepoRoot, [IO.Path]::GetFullPath($Path)))
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    $null
}

function Get-IssueNumberFromUrl {
    param([string]$Url)
    if ($Url -match '/issues/(?<n>\d+)(?:$|[?#])') { return [int]$Matches.n }
    $null
}

function Read-JsonFile {
    param([string]$Path, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name fixture not found: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-FixtureIssuesByNumber {
    param($Fixture)
    $map = @{}
    if ($null -eq $Fixture) { return $map }
    $issues = if ($Fixture.PSObject.Properties.Name -contains "issues") { @($Fixture.issues) } else { @($Fixture) }
    foreach ($issue in $issues) {
        if ($issue.PSObject.Properties.Name -contains "number") { $map[[int]$issue.number] = $issue }
    }
    $map
}

try {
    $root = Resolve-RepoRoot -Path $RepoRoot
    $checked = [System.Collections.Generic.List[object]]::new()
    $blocking = [System.Collections.Generic.List[object]]::new()
    $repairable = [System.Collections.Generic.List[object]]::new()
    $informational = [System.Collections.Generic.List[object]]::new()
    $healthy = [System.Collections.Generic.List[object]]::new()

    foreach ($path in @(
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/milestones",
        "docs/superpowers/specs",
        "docs/superpowers/plans",
        "docs/superpowers/issues"
    )) {
        $full = Join-Path $root $path
        $exists = Test-Path -LiteralPath $full
        $checked.Add([ordered]@{ path = $path; exists = $exists })
        if ($exists) {
            $healthy.Add([ordered]@{ type = "artifact-present"; path = $path })
        } else {
            $repairable.Add([ordered]@{ type = "missing-project-artifact"; path = $path })
        }
    }

    $issueFixture = Read-JsonFile -Path $IssueFixturePath -Name "issue"
    $issuesByNumber = Get-FixtureIssuesByNumber -Fixture $issueFixture
    if ($Mode -eq "GitHubAware" -and $issuesByNumber.Count -eq 0) {
        $informational.Add([ordered]@{ type = "github-checks-skipped"; reason = "no issue fixture was provided" })
    }

    $issueRoot = Join-Path $root "docs/superpowers/issues"
    if (Test-Path -LiteralPath $issueRoot -PathType Container) {
        foreach ($mirror in Get-ChildItem -LiteralPath $issueRoot -Filter "*.md") {
            if ($mirror.Name -eq "README.md") { continue }
            $relativeMirror = Get-RelativeRepoPath -RepoRoot $root -Path $mirror.FullName
            $text = Get-Content -LiteralPath $mirror.FullName -Raw
            $prePublication = Get-FieldValue -Text $text -Name "Pre-Publication"
            if ([string]$prePublication -eq "true") {
                $healthy.Add([ordered]@{ type = "pre-publication issue mirror"; issue_mirror = $relativeMirror })
                continue
            }
            $issueUrl = Get-FieldValue -Text $text -Name "GitHub Issue"
            $issueNumber = Get-IssueNumberFromUrl -Url $issueUrl
            if ($null -eq $issueNumber) {
                $repairable.Add([ordered]@{ type = "issue-mirror-missing-github-issue"; issue_mirror = $relativeMirror })
                continue
            }
            if ($Mode -eq "GitHubAware" -and $issuesByNumber.ContainsKey($issueNumber)) {
                $issue = $issuesByNumber[$issueNumber]
                $retentionMarked = $text -match '(?im)^\s*\*\*Mirror Retention:\*\*\s*Keep\s*$'
                if ([string]$issue.state -eq "CLOSED" -and -not $retentionMarked) {
                    $repairable.Add([ordered]@{
                        type = "stale closed issue mirror"
                        issue_mirror = $relativeMirror
                        issue_url = $issueUrl
                        repair = "delete mirror after confirming milestone closed-summary with issue and PR links"
                    })
                } elseif ([string]$issue.state -eq "CLOSED") {
                    $informational.Add([ordered]@{ type = "closed issue mirror retained"; issue_mirror = $relativeMirror; issue_url = $issueUrl })
                } else {
                    $healthy.Add([ordered]@{ type = "open issue mirror active"; issue_mirror = $relativeMirror; issue_url = $issueUrl })
                }
            }
        }
    }

    $findings = [ordered]@{
        blocking = @($blocking)
        repairable = @($repairable)
        informational = @($informational)
        healthy = @($healthy)
    }
    Write-AuditResult -Ok $true -Reason "project audit completed" -Findings $findings -CheckedArtifacts @($checked)
} catch {
    $findings = [ordered]@{ blocking = @([ordered]@{ type = "audit-error"; message = $_.Exception.Message }); repairable = @(); informational = @(); healthy = @() }
    Write-AuditResult -Ok $false -Reason $_.Exception.Message -Findings $findings -CheckedArtifacts @()
}
