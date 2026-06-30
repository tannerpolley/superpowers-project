[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$IssueUrl,
    [string]$IssueBodyPath,
    [string]$IssueJsonPath,
    [string]$IssueTitle,
    [string]$OutputPlanSlug
)

$ErrorActionPreference = "Stop"
$phase = "hydrate-external-issue"

function Complete {
    param(
        [bool]$Ok,
        [string]$Reason,
        [string]$IssueMirror = "",
        [string]$SourcePlan = "",
        [bool]$CreatedSourcePlan = $false,
        [bool]$ReadyForExecution = $false,
        [object]$Validation = $null
    )
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        issue_mirror = $IssueMirror
        source_plan = $SourcePlan
        created_source_plan = $CreatedSourcePlan
        ready_for_execution = $ReadyForExecution
        validation = $Validation
    } | ConvertTo-Json -Depth 16
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

function Set-FieldValue {
    param([string]$Text, [string]$Name, [string]$Value)
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*.+?\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*.+?\s*$",
        "(?im)^\s*$escaped\s*:\s*.+?\s*$"
    )
    foreach ($pattern in $patterns) {
        if ([regex]::IsMatch($Text, $pattern)) {
            return [regex]::Replace($Text, $pattern, "**${Name}:** $Value", 1)
        }
    }
    $title = [regex]::Match($Text, "(?m)^#\s+.+$")
    if ($title.Success) {
        return $Text.Insert($title.Index + $title.Length, "`n`n**${Name}:** $Value")
    }
    "**${Name}:** $Value`n`n$Text"
}

function Get-IssueNumber {
    param([string]$Url)
    $match = [regex]::Match($Url, "/issues/(\d+)(?:\D*)?$")
    if (-not $match.Success) { throw "IssueUrl must end with /issues/<number>" }
    [int]$match.Groups[1].Value
}

function ConvertTo-Slug {
    param([string]$Value)
    $lower = $Value.ToLowerInvariant()
    $slug = [regex]::Replace($lower, "[^a-z0-9]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) { throw "issue title must contain letters or digits" }
    $slug
}

function Get-ObjectProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    $null
}

function Get-IssueRecord {
    param([string]$BodyPath, [string]$JsonPath, [string]$Url)
    if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
        if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) { throw "IssueJsonPath file is missing" }
        return Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
    }
    if (-not [string]::IsNullOrWhiteSpace($BodyPath)) {
        if (-not (Test-Path -LiteralPath $BodyPath -PathType Leaf)) { throw "IssueBodyPath file is missing" }
        return [pscustomobject]@{
            body = Get-Content -LiteralPath $BodyPath -Raw
            title = $IssueTitle
            url = $Url
            number = Get-IssueNumber -Url $Url
            milestone = $null
            labels = @()
            issueType = $null
            parent = $null
            subIssues = @{ nodes = @(); totalCount = 0 }
            subIssuesSummary = @{ total = 0; completed = 0; percentCompleted = 0 }
        }
    }
    $raw = & gh issue view $Url --json body,parent,subIssues,subIssuesSummary,milestone,labels,issueType,title,url,number 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh issue view failed: $(($raw | Out-String).Trim())" }
    ($raw | Out-String) | ConvertFrom-Json
}

function Get-Title {
    param([string]$Text, [string]$Provided)
    if (-not [string]::IsNullOrWhiteSpace($Provided)) { return $Provided.Trim() }
    $match = [regex]::Match($Text, "(?m)^#\s+(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    throw "issue body must start with a markdown title or IssueTitle must be provided"
}

function Set-MarkdownTitle {
    param([string]$Text, [string]$Title)
    if ([regex]::IsMatch($Text, "(?m)^#\s+.+$")) {
        return [regex]::Replace($Text, "(?m)^#\s+.+$", "# $Title", 1)
    }
    "# $Title`n`n$Text"
}

function Get-IssueRecordUrl {
    param($Issue, [string]$Fallback)
    $url = [string](Get-ObjectProperty -Object $Issue -Name "url")
    if ([string]::IsNullOrWhiteSpace($url)) { return $Fallback }
    $url
}

function Get-IssueRecordNumber {
    param($Issue, [string]$Url)
    $number = Get-ObjectProperty -Object $Issue -Name "number"
    if ($null -ne $number -and -not [string]::IsNullOrWhiteSpace([string]$number)) { return [int]$number }
    Get-IssueNumber -Url $Url
}

function Get-GitHubTitle {
    param($Issue)
    $title = [string](Get-ObjectProperty -Object $Issue -Name "title")
    if ([string]::IsNullOrWhiteSpace($title)) { return "" }
    $title.Trim()
}

function Get-GitHubMilestoneTitle {
    param($Issue)
    $milestone = Get-ObjectProperty -Object $Issue -Name "milestone"
    if ($null -eq $milestone) { return "" }
    $title = [string](Get-ObjectProperty -Object $milestone -Name "title")
    if ([string]::IsNullOrWhiteSpace($title)) { return "" }
    $title.Trim()
}

function Get-GitHubIssueTypeName {
    param($Issue)
    $issueType = Get-ObjectProperty -Object $Issue -Name "issueType"
    if ($null -eq $issueType) { return "" }
    if ($issueType -is [string]) { return $issueType.Trim() }
    $name = [string](Get-ObjectProperty -Object $issueType -Name "name")
    if ([string]::IsNullOrWhiteSpace($name)) { return "" }
    $name.Trim()
}

function Get-GitHubLabelNames {
    param($Issue)
    $labels = Get-ObjectProperty -Object $Issue -Name "labels"
    if ($null -eq $labels) { return @() }
    @($labels | ForEach-Object {
        if ($_ -is [string]) { $_.Trim() }
        else {
            $name = [string](Get-ObjectProperty -Object $_ -Name "name")
            if (-not [string]::IsNullOrWhiteSpace($name)) { $name.Trim() }
        }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-GitHubSubIssueNodes {
    param($Issue)
    $subIssues = Get-ObjectProperty -Object $Issue -Name "subIssues"
    if ($null -eq $subIssues) { return @() }
    $nodes = Get-ObjectProperty -Object $subIssues -Name "nodes"
    if ($null -eq $nodes) { return @() }
    @($nodes)
}

function Get-GitHubSubIssueUrls {
    param($Issue)
    @(Get-GitHubSubIssueNodes -Issue $Issue | ForEach-Object {
        $url = [string](Get-ObjectProperty -Object $_ -Name "url")
        if (-not [string]::IsNullOrWhiteSpace($url)) { $url.Trim() }
    })
}

function ConvertTo-ParentMirrorPath {
    param($Parent)
    if ($null -eq $Parent) { return "None" }
    $number = Get-ObjectProperty -Object $Parent -Name "number"
    $title = [string](Get-ObjectProperty -Object $Parent -Name "title")
    if ($null -eq $number -or [string]::IsNullOrWhiteSpace($title)) { return "None" }
    "docs/superpowers/issues/$([int]$number)-$(ConvertTo-Slug -Value $title).md"
}

function Set-GitHubTrackerFields {
    param([string]$Text, $Issue, [string]$Url)
    $result = Set-FieldValue -Text $Text -Name "GitHub Issue" -Value $Url
    $milestoneTitle = Get-GitHubMilestoneTitle -Issue $Issue
    if (-not [string]::IsNullOrWhiteSpace($milestoneTitle)) {
        $result = Set-FieldValue -Text $result -Name "GitHub Milestone" -Value $milestoneTitle
    }
    $issueType = Get-GitHubIssueTypeName -Issue $Issue
    if (-not [string]::IsNullOrWhiteSpace($issueType)) {
        $result = Set-FieldValue -Text $result -Name "Issue Type" -Value $issueType
    }
    $labels = @(Get-GitHubLabelNames -Issue $Issue)
    if ($labels.Count -gt 0) {
        $result = Set-FieldValue -Text $result -Name "Labels" -Value ($labels -join ", ")
    }
    $result
}

function Set-HierarchyFields {
    param([string]$Text, $Issue)
    $parent = Get-ObjectProperty -Object $Issue -Name "parent"
    $parentUrl = if ($null -ne $parent) { [string](Get-ObjectProperty -Object $parent -Name "url") } else { "" }
    $childUrls = @(Get-GitHubSubIssueUrls -Issue $Issue)
    $hasParent = -not [string]::IsNullOrWhiteSpace($parentUrl)
    $hasChildren = $childUrls.Count -gt 0
    if (-not $hasParent -and -not $hasChildren) { return $Text }

    $role = if ($hasParent -and $hasChildren) { "plan-wrapper" } elseif ($hasParent) { "leaf" } else { "parent" }
    $executable = if ($role -eq "leaf") { "true" } else { "false" }
    $rollup = if ($role -eq "leaf") { "none" } else { "all-required-children-closed" }
    $parentIssue = if ($hasParent) { $parentUrl.Trim() } else { "None" }
    $parentMirror = if ($hasParent) { ConvertTo-ParentMirrorPath -Parent $parent } else { "None" }
    $childIssues = if ($hasChildren) { $childUrls -join ", " } else { "None" }

    $result = Set-FieldValue -Text $Text -Name "Hierarchy Mode" -Value "sub-milestone"
    $result = Set-FieldValue -Text $result -Name "Sub-Issue Role" -Value $role
    $result = Set-FieldValue -Text $result -Name "Executable" -Value $executable
    $result = Set-FieldValue -Text $result -Name "Parent Issue" -Value $parentIssue
    $result = Set-FieldValue -Text $result -Name "Parent Mirror" -Value $parentMirror
    $result = Set-FieldValue -Text $result -Name "Child Issues" -Value $childIssues
    $result = Set-FieldValue -Text $result -Name "Rollup Policy" -Value $rollup
    Set-FieldValue -Text $result -Name "Title Policy" -Value "Clean GitHub title"
}

function Test-UnresolvedSourcePlan {
    param([string]$Value)
    [string]::IsNullOrWhiteSpace($Value) -or $Value -in @("TBD", "none")
}

function New-PlanText {
    param([string]$Title, [string]$IssueUrl, [string]$Body)
    @"
# $Title Implementation Plan

**Source:** $IssueUrl

## Intake Summary

This plan was created during external GitHub issue hydration so the local issue mirror has an auditable source plan before execution routing.

## Issue Body

$Body

## Verification

Run the proof oracle recorded in the hydrated issue mirror.
"@
}

function New-OutcomeSummaryText {
    param([string]$SourcePlan, [string]$Title)
    @"
## Outcome Summary

**Outcome Source:** $SourcePlan#outcome-proof
**Intent:** Hydrate external issue '$Title' into Superpowers Project execution records.
**Target Output:** Maintainer sees a local issue mirror with source plan linkage and validation proof.
**Owner:** ``skills/create-issues/scripts/hydrate-external-issue.ps1``
**Interface:** Markdown issue mirror fields consumed by validate-issue-mirror.ps1.
**Cutover:** Convert external intake into local docs/superpowers issue mirror before execution.
**Replaced Path:** Raw external issue URL without local mirror and source plan.
**Acceptance Proof:** issue mirror validation returns ``ok: true``.
**Stop Criteria:** Block execution until source plan and local mirror validation pass.
**Avoid:** Do not execute from a raw GitHub issue URL.
"@
}

function Set-OutcomeSummary {
    param([string]$Text, [string]$SourcePlan, [string]$Title)
    $summary = New-OutcomeSummaryText -SourcePlan $SourcePlan -Title $Title
    if (-not [regex]::IsMatch($Text, "(?im)^\s{0,3}##\s+Outcome Summary\s*$")) {
        return ($Text.TrimEnd() + "`n`n" + $summary + "`n")
    }
    Set-FieldValue -Text $Text -Name "Outcome Source" -Value "$SourcePlan#outcome-proof"
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction SilentlyContinue)
    if ($null -eq $root) {
        New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null
        $root = Resolve-Path -LiteralPath $RepoRoot
    }
    $rootPath = $root.Path
    $issue = Get-IssueRecord -BodyPath $IssueBodyPath -JsonPath $IssueJsonPath -Url $IssueUrl
    $body = [string](Get-ObjectProperty -Object $issue -Name "body")
    if ([string]::IsNullOrWhiteSpace($body)) { throw "GitHub issue body is empty" }
    $recordTitle = Get-GitHubTitle -Issue $issue
    $providedTitle = if (-not [string]::IsNullOrWhiteSpace($IssueTitle)) { $IssueTitle } elseif (-not [string]::IsNullOrWhiteSpace($recordTitle)) { $recordTitle } else { "" }
    $title = Get-Title -Text $body -Provided $providedTitle
    $body = Set-MarkdownTitle -Text $body -Title $title
    $issueUrlValue = Get-IssueRecordUrl -Issue $issue -Fallback $IssueUrl
    $number = Get-IssueRecordNumber -Issue $issue -Url $issueUrlValue
    $slug = ConvertTo-Slug -Value $title

    $sourcePlan = Get-FieldValue -Text $body -Name "Source Plan"
    $createdPlan = $false
    if (Test-UnresolvedSourcePlan -Value $sourcePlan) {
        $planSlug = if ([string]::IsNullOrWhiteSpace($OutputPlanSlug)) { "$slug-plan" } else { ConvertTo-Slug -Value $OutputPlanSlug }
        $sourcePlan = "docs/superpowers/plans/$planSlug.md"
        $createdPlan = $true
    }

    $planPath = Join-Path $rootPath $sourcePlan
    if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $planPath) -Force | Out-Null
        New-PlanText -Title $title -IssueUrl $IssueUrl -Body $body | Set-Content -LiteralPath $planPath -Encoding utf8NoBOM
        $createdPlan = $true
    }

    $mirrorText = Set-GitHubTrackerFields -Text $body -Issue $issue -Url $issueUrlValue
    $mirrorText = Set-FieldValue -Text $mirrorText -Name "Source Plan" -Value ($sourcePlan -replace '\\', '/')
    $mirrorText = Set-HierarchyFields -Text $mirrorText -Issue $issue
    $mirrorText = Set-OutcomeSummary -Text $mirrorText -SourcePlan ($sourcePlan -replace '\\', '/') -Title $title

    $mirrorRelative = "docs/superpowers/issues/$number-$slug.md"
    $mirrorPath = Join-Path $rootPath $mirrorRelative
    New-Item -ItemType Directory -Path (Split-Path -Parent $mirrorPath) -Force | Out-Null
    $mirrorText | Set-Content -LiteralPath $mirrorPath -Encoding utf8NoBOM

    $validator = Join-Path $rootPath "skills/create-issues/scripts/validate-issue-mirror.ps1"
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        $validator = Join-Path $PSScriptRoot "validate-issue-mirror.ps1"
    }
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw "issue mirror validator is missing" }

    $validationRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $rootPath -IssueFile $mirrorRelative -MilestoneRequired 2>&1
    $validationText = ($validationRaw | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "issue mirror validation failed: $validationText" }
    $validation = $validationText | ConvertFrom-Json
    $ready = (-not $createdPlan) -and $validation.ok

    Complete -Ok $true -Reason "external issue hydrated" -IssueMirror $mirrorRelative -SourcePlan ($sourcePlan -replace '\\', '/') -CreatedSourcePlan $createdPlan -ReadyForExecution $ready -Validation $validation
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
