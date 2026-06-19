[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$IssueUrl,
    [string]$IssueBodyPath,
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

function Get-BodyText {
    param([string]$Path, [string]$Url)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "IssueBodyPath file is missing" }
        return Get-Content -LiteralPath $Path -Raw
    }
    $raw = & gh issue view $Url --json body --jq ".body" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh issue view failed: $(($raw | Out-String).Trim())" }
    ($raw | Out-String).TrimEnd()
}

function Get-Title {
    param([string]$Text, [string]$Provided)
    if (-not [string]::IsNullOrWhiteSpace($Provided)) { return $Provided.Trim() }
    $match = [regex]::Match($Text, "(?m)^#\s+(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    throw "issue body must start with a markdown title or IssueTitle must be provided"
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
    $body = Get-BodyText -Path $IssueBodyPath -Url $IssueUrl
    $title = Get-Title -Text $body -Provided $IssueTitle
    $number = Get-IssueNumber -Url $IssueUrl
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

    $mirrorText = Set-FieldValue -Text $body -Name "GitHub Issue" -Value $IssueUrl
    $mirrorText = Set-FieldValue -Text $mirrorText -Name "Source Plan" -Value ($sourcePlan -replace '\\', '/')
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
