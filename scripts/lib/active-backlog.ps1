$ErrorActionPreference = "Stop"

function Get-ActiveBacklogValidRoutes {
    @(
        "brainstorm-spec",
        "write-plan",
        "create-issues",
        "implement-plan",
        "resolve-issue",
        "orchestrate-issues",
        "merge-changes",
        "audit-project",
        "align-project"
    )
}

function Normalize-ActiveBacklogHeader {
    param([string]$Header)
    (($Header.Trim().ToLowerInvariant()) -replace '[^a-z0-9]+', '_').Trim("_")
}

function Split-ActiveBacklogTableRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith("|")) { $trimmed = $trimmed.Substring(1) }
    if ($trimmed.EndsWith("|")) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
    @($trimmed -split '\|' | ForEach-Object { $_.Trim() })
}

function Resolve-ActiveBacklogSourcePath {
    param([string]$RepoRoot, [string]$SourceArtifact)
    $withoutAnchor = (($SourceArtifact -split '#', 2)[0]).Trim()
    if ([string]::IsNullOrWhiteSpace($withoutAnchor)) { throw "Source artifact is required" }
    if ($withoutAnchor -match '^\s*[-*]\s*\[[ xX]\]') { throw "Source artifact must not be a historical checkbox" }
    $rootFull = [IO.Path]::GetFullPath($RepoRoot)
    $candidate = if ([IO.Path]::IsPathRooted($withoutAnchor)) { [IO.Path]::GetFullPath($withoutAnchor) } else { [IO.Path]::GetFullPath((Join-Path $rootFull $withoutAnchor)) }
    if (-not $candidate.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $candidate -ne $rootFull) {
        throw "Source artifact is outside repo root: $withoutAnchor"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Source artifact does not exist: $withoutAnchor" }
    ([IO.Path]::GetRelativePath($rootFull, $candidate) -replace "\\", "/")
}

function Convert-ActiveBacklogPriorityToRank {
    param([string]$Priority)
    switch ($Priority.Trim().ToUpperInvariant()) {
        "P0" { 0 }
        "P1" { 1 }
        "P2" { 2 }
        "P3" { 3 }
        default { 99 }
    }
}

function Read-ActiveBacklog {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "active backlog file does not exist: $Path" }
    $lines = @(Get-Content -LiteralPath $Path)
    $required = @("id", "route_owner", "source_artifact", "priority", "status", "proof_target")
    $headerIndex = -1
    $headers = @()
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -notmatch '^\s*\|') { continue }
        $candidateHeaders = @(Split-ActiveBacklogTableRow -Line $lines[$index] | ForEach-Object { Normalize-ActiveBacklogHeader $_ })
        $missing = @($required | Where-Object { $candidateHeaders -notcontains $_ })
        if ($missing.Count -eq 0) {
            $headerIndex = $index
            $headers = $candidateHeaders
            break
        }
    }
    if ($headerIndex -lt 0) { throw "active backlog table missing required columns: $($required -join ', ')" }
    if ($headerIndex + 1 -ge $lines.Count -or $lines[$headerIndex + 1] -notmatch '^\s*\|?\s*:?-{3,}') { throw "active backlog table separator is missing" }

    $entries = [System.Collections.Generic.List[object]]::new()
    for ($rowIndex = $headerIndex + 2; $rowIndex -lt $lines.Count; $rowIndex++) {
        $line = $lines[$rowIndex]
        if ($line -notmatch '^\s*\|') { break }
        $cells = @(Split-ActiveBacklogTableRow -Line $line)
        if ($cells.Count -eq 0 -or ($cells -join "").Trim().Length -eq 0) { continue }
        $row = [ordered]@{}
        for ($i = 0; $i -lt $headers.Count; $i++) {
            $row[$headers[$i]] = if ($i -lt $cells.Count) { $cells[$i] } else { "" }
        }
        foreach ($column in $required) {
            if (-not $row.Contains($column) -or [string]::IsNullOrWhiteSpace([string]$row[$column])) {
                $display = ($column -replace '_', ' ')
                throw "$display is required in active backlog row $($rowIndex + 1)"
            }
        }
        $sourcePath = Resolve-ActiveBacklogSourcePath -RepoRoot $RepoRoot -SourceArtifact ([string]$row["source_artifact"])
        $entry = [pscustomobject]@{
            id = [string]$row["id"]
            route_owner = [string]$row["route_owner"]
            source_artifact = [string]$row["source_artifact"]
            source_path = $sourcePath
            priority = [string]$row["priority"]
            priority_rank = Convert-ActiveBacklogPriorityToRank -Priority ([string]$row["priority"])
            status = ([string]$row["status"]).Trim().ToLowerInvariant()
            proof_target = [string]$row["proof_target"]
            reason = if ($row.Contains("reason")) { [string]$row["reason"] } else { "" }
        }
        $entries.Add($entry) | Out-Null
    }
    if ($entries.Count -eq 0) { throw "active backlog table has no entries" }
    @($entries)
}

function Assert-ActiveBacklogEntries {
    param([object[]]$Entries)
    $validRoutes = @(Get-ActiveBacklogValidRoutes)
    $validPriorities = @("P0", "P1", "P2", "P3")
    $validStatuses = @("ready", "blocked", "paused", "deferred")
    foreach ($entry in @($Entries)) {
        if ([string]$entry.route_owner -notin $validRoutes) { throw "Route owner is unsupported for $($entry.id): $($entry.route_owner)" }
        if (([string]$entry.priority).Trim().ToUpperInvariant() -notin $validPriorities) { throw "Priority is unsupported for $($entry.id): $($entry.priority)" }
        if ([string]$entry.status -notin $validStatuses) { throw "Status is not an active backlog status for $($entry.id): $($entry.status)" }
        if ([string]::IsNullOrWhiteSpace([string]$entry.proof_target)) { throw "Proof target is required for $($entry.id)" }
    }
}

function ConvertTo-LoopCandidateFromActiveBacklog {
    param([object]$Entry)
    $status = [string]$Entry.status
    $ready = $status -eq "ready"
    [pscustomobject]@{
        id = [string]$Entry.id
        source = "active-backlog"
        route = [string]$Entry.route_owner
        ready = $ready
        risk = "medium"
        priority = [string]$Entry.priority
        priority_rank = [int]$Entry.priority_rank
        source_path = [string]$Entry.source_path
        proof_target = [string]$Entry.proof_target
        status = $status
        reason = if ($ready) { [string]$Entry.reason } else { "status is ${status}: $($Entry.reason)" }
    }
}
