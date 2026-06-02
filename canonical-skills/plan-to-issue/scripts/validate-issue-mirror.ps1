[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$IssueFile,
    [switch]$MilestoneRequired
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Complete {
    param([bool]$Ok, [string]$Reason)
    [pscustomobject]@{ ok = $Ok; reason = $Reason; checks = $checks } | ConvertTo-Json -Depth 8
    if ($Ok) { exit 0 }
    exit 1
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
    return $null
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $issuePath = if ([System.IO.Path]::IsPathRooted($IssueFile)) {
        [System.IO.Path]::GetFullPath($IssueFile)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $root $IssueFile))
    }

    if (-not (Test-Path -LiteralPath $issuePath -PathType Leaf)) {
        Complete -Ok $false -Reason "issue mirror file is missing"
    }

    $relativeIssuePath = [System.IO.Path]::GetRelativePath($root, $issuePath) -replace '\\', '/'
    if (-not $relativeIssuePath.StartsWith("docs/superpowers/issues/", [System.StringComparison]::OrdinalIgnoreCase)) {
        Complete -Ok $false -Reason "issue mirror path must be under docs/superpowers/issues"
    }
    Add-Check -Name "issue path" -Ok $true -Reason "passed"

    $text = Get-Content -LiteralPath $issuePath -Raw

    $sourceSpec = Get-FieldValue -Text $text -Name "Source Spec"
    $sourcePlan = Get-FieldValue -Text $text -Name "Source Plan"
    $sourceCandidates = @($sourceSpec, $sourcePlan) | Where-Object { $_ -and $_ -ne "none" }
    if ($sourceCandidates.Count -eq 0) {
        Complete -Ok $false -Reason "source spec or source plan is required"
    }
    $sourceExists = $false
    foreach ($candidate in $sourceCandidates) {
        $candidatePath = if ([System.IO.Path]::IsPathRooted($candidate)) { $candidate } else { Join-Path $root $candidate }
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) { $sourceExists = $true; break }
    }
    if (-not $sourceExists) {
        Complete -Ok $false -Reason "source spec or source plan must exist"
    }
    Add-Check -Name "source artifact" -Ok $true -Reason "passed"

    $githubIssue = Get-FieldValue -Text $text -Name "GitHub Issue"
    $prePublication = [regex]::IsMatch($text, "(?im)^\s*(?:\*\*)?Pre-Publication(?:\*\*)?\s*:\s*true\s*$")
    if (-not $githubIssue -and -not $prePublication) {
        Complete -Ok $false -Reason "GitHub Issue is required unless Pre-Publication is true"
    }
    Add-Check -Name "github issue" -Ok $true -Reason "passed"

    $githubMilestone = Get-FieldValue -Text $text -Name "GitHub Milestone"
    if ($MilestoneRequired -and (-not $githubMilestone -or $githubMilestone -eq "none")) {
        Complete -Ok $false -Reason "GitHub Milestone is required when milestone policy is hard"
    }
    Add-Check -Name "github milestone" -Ok $true -Reason "passed"

    if (-not [regex]::IsMatch($text, "(?m)^\s*-\s*\[[ xX]\]\s+\S")) {
        Complete -Ok $false -Reason "Acceptance Criteria must be checkboxes"
    }
    Add-Check -Name "acceptance criteria" -Ok $true -Reason "passed"

    $classification = Get-FieldValue -Text $text -Name "Classification"
    if ($classification -notin @("AFK", "HITL")) {
        Complete -Ok $false -Reason "Classification must be AFK or HITL"
    }
    Add-Check -Name "classification" -Ok $true -Reason "passed"

    $goalCommand = Get-FieldValue -Text $text -Name "Goal Command"
    if ($classification -eq "AFK" -and (-not $goalCommand -or -not $goalCommand.StartsWith("/goal"))) {
        Complete -Ok $false -Reason "Goal Command is required for AFK issues"
    }
    Add-Check -Name "goal command" -Ok $true -Reason "passed"

    $issueType = Get-FieldValue -Text $text -Name "Issue Type"
    if ($issueType -and $issueType.Equals("bug", [System.StringComparison]::OrdinalIgnoreCase)) {
        $hasBugEvidence = [regex]::IsMatch($text, "(?im)^##\s*(Repro|Reproduction|Feedback Loop)\b")
        if (-not $hasBugEvidence) {
            Complete -Ok $false -Reason "bug issue mirrors require a repro or feedback loop section"
        }
        Add-Check -Name "bug evidence" -Ok $true -Reason "passed"
    }

    Complete -Ok $true -Reason "passed"
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
