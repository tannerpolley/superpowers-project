[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$InventoryPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

function Get-LoopCandidateRiskScore {
    param([string]$Risk)
    switch ($Risk) {
        "low" { 0 }
        "medium" { 10 }
        "high" { 20 }
        default { 30 }
    }
}

function Get-LoopFieldValue {
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

function ConvertTo-LoopBool {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [bool]) { return $Value }
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    switch -Regex (([string]$Value).Trim()) {
        '^(?i:true|yes)$' { return $true }
        '^(?i:false|no)$' { return $false }
        default { return $null }
    }
}

function Get-CandidateHierarchy {
    param([string]$RepoRoot, $Candidate, [string]$SourcePath)
    $role = ""
    $executable = $null
    $parentIssue = ""
    $parentMirror = ""
    $mode = ""
    if (Test-LoopControllerProperty -Object $Candidate -Name "sub_issue_role") { $role = [string]$Candidate.sub_issue_role }
    if (Test-LoopControllerProperty -Object $Candidate -Name "hierarchy_role") { $role = [string]$Candidate.hierarchy_role }
    if (Test-LoopControllerProperty -Object $Candidate -Name "executable") { $executable = ConvertTo-LoopBool -Value $Candidate.executable }
    if ($SourcePath -match 'docs[\\/]+superpowers[\\/]+issues[\\/].+\.md$' -and (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        $text = Get-Content -LiteralPath $SourcePath -Raw
        if ([string]::IsNullOrWhiteSpace($role)) { $role = [string](Get-LoopFieldValue -Text $text -Name "Sub-Issue Role") }
        if ($null -eq $executable) { $executable = ConvertTo-LoopBool -Value (Get-LoopFieldValue -Text $text -Name "Executable") }
        $mode = [string](Get-LoopFieldValue -Text $text -Name "Hierarchy Mode")
        $parentIssue = [string](Get-LoopFieldValue -Text $text -Name "Parent Issue")
        $parentMirror = [string](Get-LoopFieldValue -Text $text -Name "Parent Mirror")
    }
    [pscustomobject]@{
        has_hierarchy = -not [string]::IsNullOrWhiteSpace($role) -or $null -ne $executable -or -not [string]::IsNullOrWhiteSpace($mode)
        role = if ([string]::IsNullOrWhiteSpace($role)) { "" } else { $role.Trim().ToLowerInvariant() }
        executable = $executable
        mode = if ([string]::IsNullOrWhiteSpace($mode)) { "" } else { $mode.Trim().ToLowerInvariant() }
        parent_issue = $parentIssue
        parent_mirror = $parentMirror
    }
}

function Assert-ExecutableHierarchyCandidate {
    param($Candidate, $Hierarchy)
    $route = [string]$Candidate.route
    if ($route -notin @("resolve-issue", "orchestrate-issues")) { return }
    if (-not $Hierarchy.has_hierarchy) { return }
    if ($Hierarchy.role -in @("parent", "plan-wrapper") -or $Hierarchy.executable -eq $false) {
        throw "non-leaf hierarchy issue must route to rollup, align, or tracker repair instead of implementation"
    }
    if ($Hierarchy.role -eq "leaf" -and $Hierarchy.executable -ne $true) {
        throw "leaf hierarchy issue must be explicitly executable before implementation"
    }
}

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $inventoryFullPath = if ([IO.Path]::IsPathRooted($InventoryPath)) { $InventoryPath } else { Join-Path $repo $InventoryPath }
    if ([IO.Path]::GetExtension($inventoryFullPath) -ieq ".md") {
        . (Join-Path $repo "scripts\lib\active-backlog.ps1")
        $activeEntries = @(Read-ActiveBacklog -RepoRoot $repo -Path $inventoryFullPath)
        $inventory = [pscustomobject]@{ candidates = @($activeEntries | ForEach-Object { ConvertTo-LoopCandidateFromActiveBacklog -Entry $_ }) }
    } else {
        $inventory = Read-LoopControllerJson -Path $inventoryFullPath
    }
    Assert-LoopRequiredProperties -Object $inventory -Names @("candidates")

    $validRoutes = @("brainstorm-spec", "write-plan", "create-issues", "implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes", "audit-project", "align-project")
    $ready = [System.Collections.Generic.List[object]]::new()
    $skipped = [System.Collections.Generic.List[object]]::new()
    $candidateHierarchy = @{}

    foreach ($candidate in @($inventory.candidates)) {
        try {
            Assert-LoopRequiredProperties -Object $candidate -Names @("id", "source", "route", "ready", "risk", "source_path", "reason")
            if ([string]$candidate.route -notin $validRoutes) { throw "invalid route: $($candidate.route)" }
            $sourcePath = Join-Path $repo ([string]$candidate.source_path)
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "source path missing: $($candidate.source_path)" }
            if ($candidate.ready -ne $true) { throw "candidate is not ready: $($candidate.reason)" }
            $hierarchy = Get-CandidateHierarchy -RepoRoot $repo -Candidate $candidate -SourcePath $sourcePath
            $candidateHierarchy[[string]$candidate.id] = $hierarchy
            Assert-ExecutableHierarchyCandidate -Candidate $candidate -Hierarchy $hierarchy
            $ready.Add($candidate) | Out-Null
        } catch {
            $candidateId = if (Test-LoopControllerProperty -Object $candidate -Name "id") { [string]$candidate.id } else { "unknown" }
            $hierarchyEvidence = if ($candidateHierarchy.ContainsKey($candidateId)) { $candidateHierarchy[$candidateId] } else { $null }
            $skip = [ordered]@{ id = $candidateId; reason = $_.Exception.Message }
            if ($null -ne $hierarchyEvidence -and $hierarchyEvidence.has_hierarchy) {
                $skip["hierarchy_role"] = [string]$hierarchyEvidence.role
                $skip["reserved_route"] = "rollup-align-or-tracker-repair"
            }
            $skipped.Add([pscustomobject]$skip) | Out-Null
        }
    }

    if ($ready.Count -eq 0) { throw "no ready candidates" }

    $selected = @(
        $ready |
            Sort-Object @{ Expression = { if (Test-LoopControllerProperty -Object $_ -Name "priority_rank") { [int]$_.priority_rank } else { 99 } } }, @{ Expression = { Get-LoopCandidateRiskScore -Risk ([string]$_.risk) } }, @{ Expression = { [string]$_.id } } |
            Select-Object -First 1
    )[0]

    [pscustomobject]@{
        ok = $true
        phase = "candidate-selection"
        selected_candidate_id = [string]$selected.id
        selected_route = [string]$selected.route
        route_reason = [string]$selected.reason
        skipped = @($skipped)
        selected_hierarchy = if ($candidateHierarchy.ContainsKey([string]$selected.id)) { $candidateHierarchy[[string]$selected.id] } else { $null }
    } | ConvertTo-Json -Depth 10
} catch {
    New-LoopControllerResult -Ok $false -Phase "candidate-selection" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
