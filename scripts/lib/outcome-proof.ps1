$ErrorActionPreference = "Stop"

$script:OutcomeProofFields = @(
    "Intent",
    "Current Behavior",
    "Expected Outcome",
    "Target Output",
    "Owner",
    "Interface",
    "Cutover",
    "Replaced Path",
    "Evidence",
    "Acceptance Proof",
    "Stop Criteria",
    "Avoid",
    "Risk"
)

$script:ImplementationBoundaryFields = @(
    "Files To Create",
    "Files To Modify",
    "Files To Avoid",
    "Source Of Truth",
    "Read Path",
    "Write Path",
    "Integration Points",
    "Migration Or Cutover",
    "Replaced Path Handling",
    "Acceptance Proof Gate"
)

$script:IssueOutcomeSummaryFields = @(
    "Outcome Source",
    "Intent",
    "Target Output",
    "Owner",
    "Interface",
    "Cutover",
    "Replaced Path",
    "Acceptance Proof",
    "Stop Criteria",
    "Avoid"
)

function Get-MarkdownSection {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $escaped = [regex]::Escape($Name)
    $pattern = "(?ims)^\s{0,3}##\s+$escaped\s*$\r?\n(?<body>.*?)(?=^\s{0,3}##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    $match.Groups["body"].Value
}

function Get-OutcomeFieldValue {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

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

function Test-ConcreteOutcomeValue {
    param(
        [Parameter(Mandatory = $true)][string]$Field,
        [AllowNull()][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{ ok = $false; reason = "$Field is empty" }
    }

    $trimmed = $Value.Trim()
    if ($trimmed -match '^(tbd|none|n/a|na|not applicable|same as above|-)$') {
        return [pscustomobject]@{ ok = $false; reason = "$Field uses a generic value" }
    }

    if ($Field -eq "Acceptance Proof" -and $trimmed -match '^(tests?\s+pass(?:ed)?|unit tests?\s+pass(?:ed)?|lint\s+pass(?:ed)?|diff\s+reviewed)$') {
        return [pscustomobject]@{ ok = $false; reason = "Acceptance Proof must prove target-perspective behavior, not only tests or diffs" }
    }

    if ($Field -eq "Evidence" -and $trimmed -match '^(tests?|unit tests?|lint|diff)$') {
        return [pscustomobject]@{ ok = $false; reason = "Evidence must name a target-perspective lane" }
    }

    [pscustomobject]@{ ok = $true; reason = "passed" }
}

function Test-RequiredOutcomeFields {
    param(
        [Parameter(Mandatory = $true)][string]$SectionText,
        [Parameter(Mandatory = $true)][string[]]$Fields,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    $values = [ordered]@{}
    foreach ($field in $Fields) {
        $value = Get-OutcomeFieldValue -Text $SectionText -Name $field
        $valueCheck = Test-ConcreteOutcomeValue -Field $field -Value $value
        if (-not $valueCheck.ok) {
            return [pscustomobject]@{
                ok = $false
                reason = "$SectionName $($valueCheck.reason)"
                fields = $values
            }
        }
        $values[$field] = $value
    }

    [pscustomobject]@{ ok = $true; reason = "passed"; fields = $values }
}

function Get-TaskUseCaseLines {
    param([string[]]$Lines)

    $tasks = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $match = [regex]::Match($Lines[$index], '^\s{0,3}#{2,4}\s+Task\s+(?<number>\d+)\s*[:.-]\s*(?<title>.+?)\s*$')
        if ($match.Success) {
            $tasks.Add([pscustomobject]@{ number = [int]$match.Groups["number"].Value; title = $match.Groups["title"].Value; start = $index }) | Out-Null
        }
    }

    $useCases = [System.Collections.Generic.List[string]]::new()
    for ($taskIndex = 0; $taskIndex -lt $tasks.Count; $taskIndex++) {
        $start = $tasks[$taskIndex].start
        $end = if ($taskIndex + 1 -lt $tasks.Count) { $tasks[$taskIndex + 1].start } else { $Lines.Count }
        $block = @($Lines[$start..($end - 1)])
        $useCaseIndex = -1
        for ($lineIndex = 0; $lineIndex -lt $block.Count; $lineIndex++) {
            if ($block[$lineIndex] -match '^\s*\*\*Use Cases:\*\*\s*$') {
                $useCaseIndex = $lineIndex
                break
            }
        }
        if ($useCaseIndex -lt 0) { continue }
        for ($lineIndex = $useCaseIndex + 1; $lineIndex -lt $block.Count; $lineIndex++) {
            $line = [string]$block[$lineIndex]
            if ($line -match '^\s{0,3}#{1,6}\s+' -or $line -match '^\s*\*\*[^*]+:\*\*\s*$') { break }
            if ($line -match '^\s*[-*]\s+\S' -or $line -match '^\s*\d+\.\s+\S') {
                $useCases.Add($line.Trim()) | Out-Null
            }
        }
    }

    @($useCases)
}

function Test-TaskUseCaseOutcomeCoverage {
    param([Parameter(Mandatory = $true)][string]$Text)

    $lines = [string[]]($Text -split "\r?\n")
    $useCases = @(Get-TaskUseCaseLines -Lines $lines)
    if ($useCases.Count -eq 0) {
        return [pscustomobject]@{ ok = $false; reason = "Task # Use Cases are required to cover outcome evidence and cutover" }
    }

    $combined = ($useCases -join "`n").ToLowerInvariant()
    $hasEvidence = $combined -match 'acceptance|evidence|proof|target-perspective|validator|visible|operator-visible'
    $hasCutover = $combined -match 'cutover|displaced|migration|old path|duplicate|retire|redirect|demote|shim'
    if (-not $hasEvidence -or -not $hasCutover) {
        return [pscustomobject]@{ ok = $false; reason = "Task # Use Cases must cover acceptance evidence and cutover or displaced path handling" }
    }

    [pscustomobject]@{ ok = $true; reason = "passed"; use_case_count = $useCases.Count }
}

function Test-PlanOutcomeProof {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $outcomeSection = Get-MarkdownSection -Text $Text -Name "Outcome Proof"
    if ($null -eq $outcomeSection) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-proof"; reason = "missing ## Outcome Proof"; fields = @{} }
    }

    $outcome = Test-RequiredOutcomeFields -SectionText $outcomeSection -Fields $script:OutcomeProofFields -SectionName "Outcome Proof"
    if (-not $outcome.ok) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-proof"; reason = $outcome.reason; fields = $outcome.fields }
    }

    $architectureSection = Get-MarkdownSection -Text $Text -Name "Implementation Boundaries"
    if ($null -eq $architectureSection) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-proof"; reason = "missing ## Implementation Boundaries"; fields = $outcome.fields }
    }

    $architecture = Test-RequiredOutcomeFields -SectionText $architectureSection -Fields $script:ImplementationBoundaryFields -SectionName "Implementation Boundaries"
    if (-not $architecture.ok) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-proof"; reason = $architecture.reason; fields = $outcome.fields }
    }

    $coverage = Test-TaskUseCaseOutcomeCoverage -Text $Text
    if (-not $coverage.ok) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-proof"; reason = $coverage.reason; fields = $outcome.fields }
    }

    [pscustomobject]@{
        ok = $true
        phase = "plan-outcome-proof"
        reason = "outcome proof passed"
        fields = [ordered]@{
            outcome_proof = $outcome.fields
            implementation_boundaries = $architecture.fields
        }
    }
}

function Test-IssueOutcomeSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $summarySection = Get-MarkdownSection -Text $Text -Name "Outcome Summary"
    if ($null -eq $summarySection) {
        return [pscustomobject]@{ ok = $false; phase = "issue-outcome-summary"; reason = "missing ## Outcome Summary"; fields = @{} }
    }

    $summary = Test-RequiredOutcomeFields -SectionText $summarySection -Fields $script:IssueOutcomeSummaryFields -SectionName "Outcome Summary"
    if (-not $summary.ok) {
        return [pscustomobject]@{ ok = $false; phase = "issue-outcome-summary"; reason = $summary.reason; fields = $summary.fields }
    }

    $source = [string]$summary.fields["Outcome Source"]
    if (($source -replace '\\', '/') -match '(^|/)docs/goals(/|$)') {
        return [pscustomobject]@{ ok = $false; phase = "issue-outcome-summary"; reason = "Outcome Source must not use docs/goals"; fields = $summary.fields }
    }

    [pscustomobject]@{ ok = $true; phase = "issue-outcome-summary"; reason = "issue outcome summary passed"; fields = $summary.fields }
}

