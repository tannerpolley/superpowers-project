[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$IssueMirrorPath,
    [string]$GitHubIssueFixturePath,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\issue-hierarchy.ps1")

function Complete {
    param([bool]$Ok, [string]$Reason, [object[]]$Checks = @(), $Hierarchy = $null)
    $result = [pscustomobject]@{
        ok = $Ok
        phase = "issue-hierarchy"
        reason = $Reason
        hierarchy = $Hierarchy
        checks = $Checks
    }
    if ($Json) {
        $result | ConvertTo-Json -Depth 12
    } elseif ($Ok) {
        "passed"
    } else {
        $Reason
    }
    if ($Ok) { exit 0 }
    exit 1
}

function Add-Check {
    param([System.Collections.Generic.List[object]]$Checks, [string]$Name)
    $Checks.Add([pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }) | Out-Null
}

try {
    $checks = [System.Collections.Generic.List[object]]::new()
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $issuePath = if ([IO.Path]::IsPathRooted($IssueMirrorPath)) {
        [IO.Path]::GetFullPath($IssueMirrorPath)
    } else {
        [IO.Path]::GetFullPath((Join-Path $root $IssueMirrorPath))
    }
    if (-not (Test-Path -LiteralPath $issuePath -PathType Leaf)) { throw "issue mirror file is missing" }
    $text = Get-Content -LiteralPath $issuePath -Raw
    $hierarchy = Read-IssueHierarchyMirror -Text $text

    if (-not $hierarchy.has_hierarchy_fields) {
        Add-Check -Checks $checks -Name "flat mirror without hierarchy fields"
        Complete -Ok $true -Reason "flat mirror passed" -Checks $checks -Hierarchy $hierarchy
    }

    if ($hierarchy.mode -notin @("flat", "issue-set", "sub-milestone")) {
        throw "unsupported Hierarchy Mode: $($hierarchy.mode)"
    }
    Add-Check -Checks $checks -Name "hierarchy mode"

    if ($hierarchy.mode -eq "flat") {
        if ($hierarchy.role -notin @("none", "leaf")) { throw "flat hierarchy cannot use role $($hierarchy.role)" }
        if ($hierarchy.child_issues.Count -gt 0) { throw "flat hierarchy must not list child issues" }
        if (-not [string]::IsNullOrWhiteSpace($hierarchy.parent_issue) -and $hierarchy.parent_issue -ne "None") { throw "flat hierarchy must not list a parent issue" }
        Add-Check -Checks $checks -Name "flat hierarchy fields"
        Complete -Ok $true -Reason "flat hierarchy passed" -Checks $checks -Hierarchy $hierarchy
    }

    if ($hierarchy.role -notin @("parent", "plan-wrapper", "leaf")) {
        throw "Sub-Issue Role must be parent, plan-wrapper, or leaf"
    }
    Add-Check -Checks $checks -Name "sub-issue role"

    if ($null -eq $hierarchy.executable) { throw "Executable is required for hierarchy mirrors" }
    Add-Check -Checks $checks -Name "executable field"

    if ([string]::IsNullOrWhiteSpace($hierarchy.title_policy) -or -not $hierarchy.title_policy.Equals("Clean GitHub title", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Title Policy must be Clean GitHub title"
    }
    Add-Check -Checks $checks -Name "title policy"

    if ($hierarchy.role -in @("parent", "plan-wrapper")) {
        if ($hierarchy.executable -ne $false) { throw "$($hierarchy.role) mirrors require Executable false" }
        if ($hierarchy.child_issues.Count -eq 0) { throw "$($hierarchy.role) mirrors require child issues" }
        if ([string]::IsNullOrWhiteSpace($hierarchy.rollup_policy) -or $hierarchy.rollup_policy -eq "none") {
            throw "$($hierarchy.role) mirrors require a rollup policy"
        }
    }

    if ($hierarchy.role -eq "plan-wrapper") {
        if ([string]::IsNullOrWhiteSpace($hierarchy.parent_issue) -or $hierarchy.parent_issue -eq "None") {
            throw "plan-wrapper mirrors require Parent Issue"
        }
        if ([string]::IsNullOrWhiteSpace($hierarchy.parent_mirror) -or $hierarchy.parent_mirror -eq "None") {
            throw "plan-wrapper mirrors require Parent Mirror"
        }
    }

    if ($hierarchy.role -eq "leaf") {
        if ($hierarchy.executable -ne $true) { throw "leaf mirrors require Executable true" }
        if ([string]::IsNullOrWhiteSpace($hierarchy.parent_issue) -or $hierarchy.parent_issue -eq "None") {
            throw "leaf mirrors require Parent Issue"
        }
        if ([string]::IsNullOrWhiteSpace($hierarchy.parent_mirror) -or $hierarchy.parent_mirror -eq "None") {
            throw "leaf mirrors require Parent Mirror"
        }
        if ($hierarchy.child_issues.Count -gt 0) { throw "leaf mirrors must not list child issues" }
        if ($hierarchy.rollup_policy -ne "none") { throw "leaf mirrors require Rollup Policy none" }
    }
    Add-Check -Checks $checks -Name "role consistency"

    if (-not [string]::IsNullOrWhiteSpace($GitHubIssueFixturePath)) {
        $fixturePath = if ([IO.Path]::IsPathRooted($GitHubIssueFixturePath)) {
            [IO.Path]::GetFullPath($GitHubIssueFixturePath)
        } else {
            [IO.Path]::GetFullPath((Join-Path $root $GitHubIssueFixturePath))
        }
        if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) { throw "GitHub issue fixture is missing" }
        $github = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
        if ($null -ne $github.parent) {
            $githubParentNumber = [int]$github.parent.number
            if ($hierarchy.parent_number -and $hierarchy.parent_number -ne $githubParentNumber) {
                throw "parent parity drift: mirror parent #$($hierarchy.parent_number) does not match GitHub parent #$githubParentNumber"
            }
        } elseif ($hierarchy.role -in @("leaf", "plan-wrapper")) {
            throw "parent parity drift: GitHub fixture has no parent"
        }

        $githubChildUrls = @(Get-GitHubSubIssueNodes -Issue $github | ForEach-Object { [string]$_.url } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
        $mirrorChildUrls = @($hierarchy.child_issues | Sort-Object)
        if (($githubChildUrls -join "`n") -ne ($mirrorChildUrls -join "`n")) {
            throw "subIssues parity drift: mirror child issues do not match GitHub subIssues"
        }
        if ($github.PSObject.Properties.Name -contains "subIssuesSummary" -and $null -ne $github.subIssuesSummary) {
            $total = [int]$github.subIssuesSummary.total
            if ($total -ne $mirrorChildUrls.Count) {
                throw "subIssuesSummary parity drift: total $total does not match mirror child count $($mirrorChildUrls.Count)"
            }
        }
        Add-Check -Checks $checks -Name "GitHub hierarchy fixture parity"
    }

    Complete -Ok $true -Reason "hierarchy mirror passed" -Checks $checks -Hierarchy $hierarchy
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
