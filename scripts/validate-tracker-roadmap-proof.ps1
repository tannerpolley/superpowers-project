[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$LabelFixturePath,
    [string]$MilestoneFixturePath,
    [string]$IssueFixturePath,
    [int]$IssueNumber = 0,
    [string]$RequiredIssueLabel,
    [string]$ForbiddenIssueLabel,
    [string]$RequiredIssueMilestone
)

$ErrorActionPreference = "Stop"
$phase = "tracker-roadmap-proof"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Read-JsonInput {
    param([string]$Path, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "$Name path is required" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name fixture is missing: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-NameArray {
    param($Items)
    @($Items | ForEach-Object {
        if ($_ -is [string]) { [string]$_ }
        elseif ($_.PSObject.Properties.Name -contains "name") { [string]$_.name }
        elseif ($_.PSObject.Properties.Name -contains "title") { [string]$_.title }
        else { [string]$_ }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-ExpectedMilestoneTitles {
    param([string]$Root)
    $contextPath = Join-Path $Root "docs\superpowers\PROJECT_CONTEXT.md"
    if (-not (Test-Path -LiteralPath $contextPath -PathType Leaf)) {
        throw "project context is missing: docs/superpowers/PROJECT_CONTEXT.md"
    }
    $text = Get-Content -LiteralPath $contextPath -Raw
    $matches = [regex]::Matches($text, '`(?<title>M\d+\s+-\s+[^`]+)`')
    @($matches | ForEach-Object { $_.Groups["title"].Value.Trim() } | Select-Object -Unique)
}

function Read-TrackerLabels {
    param([string]$Repository, [string]$FixturePath)
    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        return @(Read-JsonInput -Path $FixturePath -Name "label")
    }
    $json = gh label list --repo $Repository --json name --limit 200
    if ($LASTEXITCODE -ne 0) { throw "gh label list failed for $Repository" }
    @($json | ConvertFrom-Json)
}

function Read-TrackerMilestones {
    param([string]$Repository, [string]$FixturePath)
    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        return @(Read-JsonInput -Path $FixturePath -Name "milestone")
    }
    $json = gh api "repos/$Repository/milestones?state=all&per_page=100"
    if ($LASTEXITCODE -ne 0) { throw "gh milestone inspection failed for $Repository" }
    @($json | ConvertFrom-Json)
}

function Read-TrackerIssue {
    param([string]$Repository, [string]$FixturePath, [int]$Number)
    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        return Read-JsonInput -Path $FixturePath -Name "issue"
    }
    if ($Number -le 0) { return $null }
    $json = gh issue view $Number --repo $Repository --json number,title,state,labels,milestone
    if ($LASTEXITCODE -ne 0) { throw "gh issue view failed for $Repository#$Number" }
    $json | ConvertFrom-Json
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $roadmapPath = Join-Path $root "docs\agents\project-roadmap.json"
    if (-not (Test-Path -LiteralPath $roadmapPath -PathType Leaf)) {
        throw "project roadmap config is missing: docs/agents/project-roadmap.json"
    }
    $roadmap = Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json
    $repository = [string]$roadmap.repository
    if ([string]::IsNullOrWhiteSpace($repository)) {
        throw "project-roadmap.json repository is empty"
    }

    $trackerLabels = @(Read-TrackerLabels -Repository $repository -FixturePath $LabelFixturePath)
    $labelNames = @(Get-NameArray -Items $trackerLabels)
    foreach ($label in @($roadmap.labels | ForEach-Object { [string]$_ })) {
        Add-Check -Name "tracker contains roadmap label $label" -Ok ($labelNames -contains $label) -Reason "tracker missing roadmap label: $label"
    }

    $trackerMilestones = @(Read-TrackerMilestones -Repository $repository -FixturePath $MilestoneFixturePath)
    $milestoneTitles = @(Get-NameArray -Items $trackerMilestones)
    $expectedMilestoneTitles = @(Get-ExpectedMilestoneTitles -Root $root)
    foreach ($milestone in $expectedMilestoneTitles) {
        Add-Check -Name "tracker contains roadmap milestone $milestone" -Ok ($milestoneTitles -contains $milestone) -Reason "tracker missing roadmap milestone: $milestone"
    }

    $issue = Read-TrackerIssue -Repository $repository -FixturePath $IssueFixturePath -Number $IssueNumber
    $issueLabels = @()
    $issueMilestone = ""
    $issueState = ""
    if ($null -ne $issue) {
        $issueLabels = @(Get-NameArray -Items $issue.labels)
        if ($issue.PSObject.Properties.Name -contains "milestone" -and $null -ne $issue.milestone) {
            if ($issue.milestone -is [string]) { $issueMilestone = [string]$issue.milestone }
            elseif ($issue.milestone.PSObject.Properties.Name -contains "title") { $issueMilestone = [string]$issue.milestone.title }
        }
        if ($issue.PSObject.Properties.Name -contains "state") { $issueState = [string]$issue.state }
        if (-not [string]::IsNullOrWhiteSpace($RequiredIssueLabel)) {
            Add-Check -Name "issue $IssueNumber has required label $RequiredIssueLabel" -Ok ($issueLabels -contains $RequiredIssueLabel) -Reason "issue $IssueNumber missing required label: $RequiredIssueLabel"
        }
        if (-not [string]::IsNullOrWhiteSpace($ForbiddenIssueLabel)) {
            Add-Check -Name "issue $IssueNumber omits forbidden label $ForbiddenIssueLabel" -Ok ($issueLabels -notcontains $ForbiddenIssueLabel) -Reason "issue $IssueNumber still has forbidden label: $ForbiddenIssueLabel"
        }
        if (-not [string]::IsNullOrWhiteSpace($RequiredIssueMilestone)) {
            Add-Check -Name "issue $IssueNumber uses milestone $RequiredIssueMilestone" -Ok ($issueMilestone -eq $RequiredIssueMilestone) -Reason "issue $IssueNumber milestone is '$issueMilestone', expected '$RequiredIssueMilestone'"
        }
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{
        ok = ($failed.Count -eq 0)
        phase = $phase
        repository = $repository
        missing_labels = @($checks | Where-Object { -not $_.ok -and $_.name -like "tracker contains roadmap label *" } | ForEach-Object { $_.reason })
        missing_milestones = @($checks | Where-Object { -not $_.ok -and $_.name -like "tracker contains roadmap milestone *" } | ForEach-Object { $_.reason })
        issue = if ($null -eq $issue) { $null } else { [ordered]@{ number = $IssueNumber; state = $issueState; labels = $issueLabels; milestone = $issueMilestone } }
        checks = $checks
    } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{
        ok = $false
        phase = $phase
        reason = $_.Exception.Message
        checks = $checks
    } | ConvertTo-Json -Depth 8
    exit 1
}
