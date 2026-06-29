[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$SourcePlanPath,
    [ValidateSet("flat", "issue-set", "sub-milestone")][string]$HierarchyMode = "flat",
    [string]$GitHubMilestoneTitle,
    [string]$ParentTitle,
    [string[]]$WrapperTitles = @(),
    [string[]]$LeafTitles = @(),
    [string[]]$ExistingChildIssueUrls = @(),
    [string[]]$Labels = @(),
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Complete {
    param([bool]$Ok, [string]$Reason, [object[]]$Order = @(), [object[]]$Payloads = @(), [string[]]$Commands = @())
    $result = [pscustomobject]@{
        ok = $Ok
        phase = "issue-hierarchy-plan"
        reason = $Reason
        hierarchy_mode = $HierarchyMode
        publication_order = $Order
        mirror_payloads = $Payloads
        dry_commands = $Commands
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

function Quote-Arg {
    param([string]$Value)
    '"' + ($Value -replace '"', '\"') + '"'
}

function Test-CleanTitle {
    param([string]$Title)
    $numbers = @(0..20 | ForEach-Object { "M$_" })
    $validator = Join-Path $PSScriptRoot "validate-issue-title-policy.ps1"
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -Title $Title -KnownMilestoneTitles $GitHubMilestoneTitle -KnownMilestoneNumbers ($numbers -join ",") -Json
    $result = ($raw | Out-String) | ConvertFrom-Json
    if (-not $result.ok) { throw $result.reason }
}

function Expand-ListArgument {
    param([string[]]$Values)
    @($Values | ForEach-Object { [string]$_ -split '\s*,\s*' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $planPath = if ([IO.Path]::IsPathRooted($SourcePlanPath)) {
        [IO.Path]::GetFullPath($SourcePlanPath)
    } else {
        [IO.Path]::GetFullPath((Join-Path $root $SourcePlanPath))
    }
    if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) { throw "source plan does not exist" }

    $WrapperTitles = @(Expand-ListArgument -Values $WrapperTitles)
    $LeafTitles = @(Expand-ListArgument -Values $LeafTitles)
    $ExistingChildIssueUrls = @(Expand-ListArgument -Values $ExistingChildIssueUrls)
    $Labels = @(Expand-ListArgument -Values $Labels)

    if ($HierarchyMode -ne "flat" -and [string]::IsNullOrWhiteSpace($ParentTitle)) {
        throw "ParentTitle is required for hierarchy modes"
    }
    foreach ($title in @($ParentTitle) + @($WrapperTitles) + @($LeafTitles)) {
        if (-not [string]::IsNullOrWhiteSpace($title)) { Test-CleanTitle -Title $title }
    }

    $order = [System.Collections.Generic.List[object]]::new()
    $payloads = [System.Collections.Generic.List[object]]::new()
    $commands = [System.Collections.Generic.List[string]]::new()
    $labelArgs = if ($Labels.Count -gt 0) { " " + (($Labels | ForEach-Object { "--label " + (Quote-Arg $_) }) -join " ") } else { "" }
    $milestoneArg = if ([string]::IsNullOrWhiteSpace($GitHubMilestoneTitle)) { "" } else { " --milestone " + (Quote-Arg $GitHubMilestoneTitle) }

    if ($HierarchyMode -eq "flat") {
        foreach ($leaf in $LeafTitles) {
            $order.Add([pscustomobject]@{ role = "leaf"; title = $leaf; parent_ref = "" }) | Out-Null
            $payloads.Add([pscustomobject]@{ title = $leaf; hierarchy_mode = "flat"; role = "leaf"; executable = $true; parent = "" }) | Out-Null
            $commands.Add("gh issue create --title $(Quote-Arg $leaf)$milestoneArg$labelArgs") | Out-Null
        }
        Complete -Ok $true -Reason "hierarchy plan built" -Order $order -Payloads $payloads -Commands $commands
    }

    $parentRef = "<parent-url>"
    $order.Add([pscustomobject]@{ role = "parent"; title = $ParentTitle; parent_ref = "" }) | Out-Null
    $payloads.Add([pscustomobject]@{ title = $ParentTitle; hierarchy_mode = $HierarchyMode; role = "parent"; executable = $false; parent = ""; rollup_policy = "all-required-children-closed" }) | Out-Null
    $commands.Add("gh issue create --title $(Quote-Arg $ParentTitle)$milestoneArg$labelArgs") | Out-Null

    $leafParentRef = $parentRef
    foreach ($wrapper in $WrapperTitles) {
        $wrapperRef = "<wrapper-url>"
        $order.Add([pscustomobject]@{ role = "plan-wrapper"; title = $wrapper; parent_ref = $parentRef }) | Out-Null
        $payloads.Add([pscustomobject]@{ title = $wrapper; hierarchy_mode = $HierarchyMode; role = "plan-wrapper"; executable = $false; parent = $parentRef; rollup_policy = "all-required-children-closed" }) | Out-Null
        $commands.Add("gh issue create --title $(Quote-Arg $wrapper)$milestoneArg$labelArgs --parent $(Quote-Arg $parentRef)") | Out-Null
        $leafParentRef = $wrapperRef
    }

    foreach ($leaf in $LeafTitles) {
        $order.Add([pscustomobject]@{ role = "leaf"; title = $leaf; parent_ref = $leafParentRef }) | Out-Null
        $payloads.Add([pscustomobject]@{ title = $leaf; hierarchy_mode = $HierarchyMode; role = "leaf"; executable = $true; parent = $leafParentRef; rollup_policy = "none" }) | Out-Null
        $commands.Add("gh issue create --title $(Quote-Arg $leaf)$milestoneArg$labelArgs --parent $(Quote-Arg $leafParentRef)") | Out-Null
    }
    foreach ($url in $ExistingChildIssueUrls) {
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        $order.Add([pscustomobject]@{ role = "existing-child"; title = ""; parent_ref = $leafParentRef; issue_url = $url }) | Out-Null
        $commands.Add("gh issue edit $(Quote-Arg $url) --add-sub-issue $(Quote-Arg $leafParentRef)") | Out-Null
    }

    Complete -Ok $true -Reason "hierarchy plan built" -Order $order -Payloads $payloads -Commands $commands
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
