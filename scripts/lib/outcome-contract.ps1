$ErrorActionPreference = "Stop"

$script:OutcomeContractFields = @(
    "Intent",
    "Current Behavior",
    "Expected Outcome",
    "Target-Perspective Output",
    "Truth Owner",
    "Contract Interface",
    "Cutover Decision",
    "Displaced Path",
    "Evidence Lane",
    "Acceptance Evidence",
    "Kill Criteria",
    "Forbidden Moves",
    "Risk If Wrong"
)

$script:ArchitectureSliceFields = @(
    "Files To Create",
    "Files To Modify",
    "Files To Avoid",
    "Source Of Truth",
    "Read Path",
    "Write Path",
    "Integration Points",
    "Migration Or Cutover",
    "Displaced Path Handling",
    "Acceptance Evidence Gate"
)

$script:IssueOutcomeContractFields = @(
    "Outcome Contract Source",
    "Intent",
    "Target-Perspective Output",
    "Truth Owner",
    "Contract Interface",
    "Cutover Decision",
    "Displaced Path",
    "Acceptance Evidence",
    "Kill Criteria",
    "Forbidden Moves"
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

function Get-ContractFieldValue {
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

function Test-ConcreteContractValue {
    param(
        [Parameter(Mandatory = $true)][string]$Field,
        [AllowNull()][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{ ok = $false; reason = "$Field is empty" }
    }

    $trimmed = $Value.Trim()
    if ($trimmed -match '^(none|n/a|na|not applicable|same as above|-)$') {
        return [pscustomobject]@{ ok = $false; reason = "$Field uses a generic value" }
    }

    if ($Field -eq "Acceptance Evidence" -and $trimmed -match '^(tests?\s+pass(?:ed)?|unit tests?\s+pass(?:ed)?|lint\s+pass(?:ed)?|diff\s+reviewed)$') {
        return [pscustomobject]@{ ok = $false; reason = "Acceptance Evidence must prove target-perspective behavior, not only tests or diffs" }
    }

    if ($Field -eq "Evidence Lane" -and $trimmed -match '^(tests?|unit tests?|lint|diff)$') {
        return [pscustomobject]@{ ok = $false; reason = "Evidence Lane must name a target-perspective lane" }
    }

    [pscustomobject]@{ ok = $true; reason = "passed" }
}

function Test-RequiredContractFields {
    param(
        [Parameter(Mandatory = $true)][string]$SectionText,
        [Parameter(Mandatory = $true)][string[]]$Fields,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    $values = [ordered]@{}
    foreach ($field in $Fields) {
        $value = Get-ContractFieldValue -Text $SectionText -Name $field
        $valueCheck = Test-ConcreteContractValue -Field $field -Value $value
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

function Test-TaskUseCaseContractCoverage {
    param([Parameter(Mandatory = $true)][string]$Text)

    $lines = [string[]]($Text -split "\r?\n")
    $useCases = @(Get-TaskUseCaseLines -Lines $lines)
    if ($useCases.Count -eq 0) {
        return [pscustomobject]@{ ok = $false; reason = "Task # Use Cases are required to cover outcome contract evidence and cutover" }
    }

    $combined = ($useCases -join "`n").ToLowerInvariant()
    $hasEvidence = $combined -match 'acceptance|evidence|proof|target-perspective|validator|visible|operator-visible'
    $hasCutover = $combined -match 'cutover|displaced|migration|old path|duplicate|retire|redirect|demote|shim'
    if (-not $hasEvidence -or -not $hasCutover) {
        return [pscustomobject]@{ ok = $false; reason = "Task # Use Cases must cover acceptance evidence and cutover or displaced path handling" }
    }

    [pscustomobject]@{ ok = $true; reason = "passed"; use_case_count = $useCases.Count }
}

function Test-PlanOutcomeContract {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $outcomeSection = Get-MarkdownSection -Text $Text -Name "Outcome Contract"
    if ($null -eq $outcomeSection) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-contract"; reason = "missing ## Outcome Contract"; fields = @{} }
    }

    $outcome = Test-RequiredContractFields -SectionText $outcomeSection -Fields $script:OutcomeContractFields -SectionName "Outcome Contract"
    if (-not $outcome.ok) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-contract"; reason = $outcome.reason; fields = $outcome.fields }
    }

    $architectureSection = Get-MarkdownSection -Text $Text -Name "Architecture Slice"
    if ($null -eq $architectureSection) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-contract"; reason = "missing ## Architecture Slice"; fields = $outcome.fields }
    }

    $architecture = Test-RequiredContractFields -SectionText $architectureSection -Fields $script:ArchitectureSliceFields -SectionName "Architecture Slice"
    if (-not $architecture.ok) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-contract"; reason = $architecture.reason; fields = $outcome.fields }
    }

    $coverage = Test-TaskUseCaseContractCoverage -Text $Text
    if (-not $coverage.ok) {
        return [pscustomobject]@{ ok = $false; phase = "plan-outcome-contract"; reason = $coverage.reason; fields = $outcome.fields }
    }

    [pscustomobject]@{
        ok = $true
        phase = "plan-outcome-contract"
        reason = "outcome contract passed"
        fields = [ordered]@{
            outcome_contract = $outcome.fields
            architecture_slice = $architecture.fields
        }
    }
}

function Test-IssueOutcomeContractSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $summarySection = Get-MarkdownSection -Text $Text -Name "Outcome Contract Summary"
    if ($null -eq $summarySection) {
        return [pscustomobject]@{ ok = $false; phase = "issue-outcome-contract"; reason = "missing ## Outcome Contract Summary"; fields = @{} }
    }

    $summary = Test-RequiredContractFields -SectionText $summarySection -Fields $script:IssueOutcomeContractFields -SectionName "Outcome Contract Summary"
    if (-not $summary.ok) {
        return [pscustomobject]@{ ok = $false; phase = "issue-outcome-contract"; reason = $summary.reason; fields = $summary.fields }
    }

    $source = [string]$summary.fields["Outcome Contract Source"]
    if (($source -replace '\\', '/') -match '(^|/)docs/goals(/|$)') {
        return [pscustomobject]@{ ok = $false; phase = "issue-outcome-contract"; reason = "Outcome Contract Source must not use docs/goals"; fields = $summary.fields }
    }

    [pscustomobject]@{ ok = $true; phase = "issue-outcome-contract"; reason = "issue outcome contract summary passed"; fields = $summary.fields }
}
