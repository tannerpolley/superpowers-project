[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("tracker-roadmap-proof-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-JsonScript {
    param([string]$Path, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ exit_code = 127; raw = "missing script: $Path"; json = $null }
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    $text = ($raw | Out-String).Trim()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = $text; json = $json }
}

function Initialize-FixtureRepo {
    param([string]$Root)
    $labels = @(
        "type:bug",
        "type:feature",
        "type:task",
        "type:issue-set",
        "type:sub-milestone",
        "type:plan-wrapper",
        "status:triage",
        "status:ready",
        "status:blocked"
    )
    New-Item -ItemType Directory -Path (Join-Path $Root "docs\agents") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root "docs\superpowers") -Force | Out-Null
    [pscustomobject]@{
        tracker = "github"
        repository = "tannerpolley/superpowers-project"
        hierarchy_labels = @("type:issue-set", "type:sub-milestone", "type:plan-wrapper")
        labels = $labels
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root "docs\agents\project-roadmap.json") -Encoding utf8NoBOM
    @(
        "# Context",
        "",
        "- `M0 - Governance`: validation.",
        "- `M1 - Source Of Truth`: alignment.",
        "- `M2 - Distribution`: release."
    ) | Set-Content -LiteralPath (Join-Path $Root "docs\superpowers\PROJECT_CONTEXT.md") -Encoding utf8NoBOM
}

function Write-Fixtures {
    param(
        [string]$Root,
        [switch]$MissingLabel,
        [switch]$MissingHierarchyLabel,
        [switch]$BlockedIssue
    )
    $labels = @(
        "type:bug",
        "type:feature",
        "type:task",
        "type:issue-set",
        "type:sub-milestone",
        "type:plan-wrapper",
        "status:triage",
        "status:ready",
        "status:blocked"
    )
    if ($MissingLabel) { $labels = @($labels | Where-Object { $_ -ne "status:blocked" }) }
    if ($MissingHierarchyLabel) { $labels = @($labels | Where-Object { $_ -ne "type:sub-milestone" }) }
    @($labels | ForEach-Object { [pscustomobject]@{ name = $_ } }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root "labels.json") -Encoding utf8NoBOM
    @("M0 - Governance", "M1 - Source Of Truth", "M2 - Distribution") | ForEach-Object { [pscustomobject]@{ title = $_ } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root "milestones.json") -Encoding utf8NoBOM
    $issueLabels = if ($BlockedIssue) { @("type:task", "status:blocked") } else { @("type:task", "status:ready") }
    [pscustomobject]@{
        number = 72
        state = "OPEN"
        labels = @($issueLabels | ForEach-Object { [pscustomobject]@{ name = $_ } })
        milestone = [pscustomobject]@{ title = "M1 - Source Of Truth" }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root "issue.json") -Encoding utf8NoBOM
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $validator = Join-Path $RepoRoot "scripts\validate-tracker-roadmap-proof.ps1"

    $validRoot = Join-Path $tempRoot "valid"
    Initialize-FixtureRepo -Root $validRoot
    Write-Fixtures -Root $validRoot
    $valid = Invoke-JsonScript -Path $validator -Arguments @(
        "-RepoRoot", $validRoot,
        "-LabelFixturePath", (Join-Path $validRoot "labels.json"),
        "-MilestoneFixturePath", (Join-Path $validRoot "milestones.json"),
        "-IssueFixturePath", (Join-Path $validRoot "issue.json"),
        "-IssueNumber", "72",
        "-RequiredIssueLabel", "status:ready",
        "-ForbiddenIssueLabel", "status:blocked",
        "-RequiredIssueMilestone", "M1 - Source Of Truth"
    )
    Add-Check -Name "valid tracker proof passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason $valid.raw

    $missingLabelRoot = Join-Path $tempRoot "missing-label"
    Initialize-FixtureRepo -Root $missingLabelRoot
    Write-Fixtures -Root $missingLabelRoot -MissingLabel
    $missingLabel = Invoke-JsonScript -Path $validator -Arguments @(
        "-RepoRoot", $missingLabelRoot,
        "-LabelFixturePath", (Join-Path $missingLabelRoot "labels.json"),
        "-MilestoneFixturePath", (Join-Path $missingLabelRoot "milestones.json"),
        "-IssueFixturePath", (Join-Path $missingLabelRoot "issue.json"),
        "-IssueNumber", "72",
        "-RequiredIssueLabel", "status:ready",
        "-ForbiddenIssueLabel", "status:blocked",
        "-RequiredIssueMilestone", "M1 - Source Of Truth"
    )
    Add-Check -Name "missing roadmap label fails" -Ok ($missingLabel.exit_code -ne 0 -and $missingLabel.raw.Contains("status:blocked")) -Reason "missing roadmap label should fail"

    $missingHierarchyRoot = Join-Path $tempRoot "missing-hierarchy-label"
    Initialize-FixtureRepo -Root $missingHierarchyRoot
    Write-Fixtures -Root $missingHierarchyRoot -MissingHierarchyLabel
    $missingHierarchy = Invoke-JsonScript -Path $validator -Arguments @(
        "-RepoRoot", $missingHierarchyRoot,
        "-LabelFixturePath", (Join-Path $missingHierarchyRoot "labels.json"),
        "-MilestoneFixturePath", (Join-Path $missingHierarchyRoot "milestones.json"),
        "-IssueFixturePath", (Join-Path $missingHierarchyRoot "issue.json"),
        "-IssueNumber", "72",
        "-RequiredIssueLabel", "status:ready",
        "-ForbiddenIssueLabel", "status:blocked",
        "-RequiredIssueMilestone", "M1 - Source Of Truth"
    )
    Add-Check -Name "missing hierarchy roadmap label fails" -Ok ($missingHierarchy.exit_code -ne 0 -and $missingHierarchy.raw.Contains("type:sub-milestone")) -Reason "missing hierarchy roadmap label should fail"

    $blockedIssueRoot = Join-Path $tempRoot "blocked-issue"
    Initialize-FixtureRepo -Root $blockedIssueRoot
    Write-Fixtures -Root $blockedIssueRoot -BlockedIssue
    $blockedIssue = Invoke-JsonScript -Path $validator -Arguments @(
        "-RepoRoot", $blockedIssueRoot,
        "-LabelFixturePath", (Join-Path $blockedIssueRoot "labels.json"),
        "-MilestoneFixturePath", (Join-Path $blockedIssueRoot "milestones.json"),
        "-IssueFixturePath", (Join-Path $blockedIssueRoot "issue.json"),
        "-IssueNumber", "72",
        "-RequiredIssueLabel", "status:ready",
        "-ForbiddenIssueLabel", "status:blocked",
        "-RequiredIssueMilestone", "M1 - Source Of Truth"
    )
    Add-Check -Name "blocked issue label fails" -Ok ($blockedIssue.exit_code -ne 0 -and $blockedIssue.raw.Contains("status:ready")) -Reason "blocked issue label should fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "tracker-roadmap-proof"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "tracker-roadmap-proof"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
