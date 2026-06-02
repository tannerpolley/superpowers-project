$ErrorActionPreference = "Stop"

function Write-ContractResult {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{}
    )
    [ordered]@{ ok = $Ok; phase = $Phase; reason = $Reason; evidence = $Evidence } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Stop-Contract {
    param([string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    Write-ContractResult -Phase $Phase -Ok $false -Reason $Reason -Evidence $Evidence
}

function Complete-Contract {
    param([string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    Write-ContractResult -Phase $Phase -Ok $true -Reason $Reason -Evidence $Evidence
}

function Test-Property {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name)
    return $null -ne $Object -and ($Object.PSObject.Properties.Name -contains $Name)
}

function Read-JsonInput {
    param([string]$Json, [string]$Path, [string]$Name = "json")
    $text = $null
    if (-not [string]::IsNullOrWhiteSpace($Json)) {
        $text = $Json
    } elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name path not found: $Path" }
        $text = Get-Content -LiteralPath $Path -Raw
    } else {
        throw "Missing $Name input."
    }
    try { return ($text | ConvertFrom-Json) } catch { throw "Invalid $Name JSON: $($_.Exception.Message)" }
}

function Get-StringArray {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    @($Value | ForEach-Object { [string]$_ })
}

function Normalize-RepoPath {
    param([string]$Path)
    if ($null -eq $Path) { return "" }
    ($Path -replace '\\', '/').Trim()
}

function Resolve-RepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = "." }
    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) { throw "repo root does not exist: $RepoRoot" }
    [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
}

function Get-IssueNumberFromUrl {
    param([string]$IssueUrl)
    if ($IssueUrl -match '/issues/(?<n>\d+)(?:$|[?#])') { return [int]$Matches.n }
    $null
}

function Test-ClosingKeywordForIssue {
    param([string]$Body, [int]$IssueNumber)
    if ([string]::IsNullOrWhiteSpace($Body) -or $IssueNumber -le 0) { return $false }
    [bool]($Body -match "(?im)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#$IssueNumber(?!\d)\b")
}

function Test-ClosingReferenceIncludesIssue {
    param($References, [int]$IssueNumber)
    foreach ($reference in @($References)) {
        if ($null -ne $reference -and [int]$reference.number -eq $IssueNumber) { return $true }
    }
    $false
}

function Assert-MergeDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "merge decision is required" }
    if ($Decision -is [string]) { throw "merge decision must be structured, not a string" }
    foreach ($field in @("question_id", "source", "selected_action", "recommended_action", "options")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "merge decision missing $field" }
    }
    if ([string]$Decision.question_id -ne "project_merge_approval") { throw "merge decision question_id mismatch" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "merge decision source must be request_user_input or debug_question_mode" }
    if ([string]$Decision.selected_action -notin @("merge", "decline")) { throw "merge decision selected_action must be merge or decline" }
    if ([string]$Decision.recommended_action -ne "merge") { throw "merge decision recommended_action must be merge after clean premerge proof" }
    $options = Get-StringArray $Decision.options
    foreach ($requiredOption in @("merge", "decline")) {
        if ($options -notcontains $requiredOption) { throw "merge decision options must include $requiredOption" }
    }
    if ([string]$Decision.selected_action -eq "decline") { throw "merge declined by user" }
}

function Assert-CleanRepoProof {
    param($Proof)
    if ($null -eq $Proof -or $Proof -is [string]) { throw "clean repo proof must be structured" }
    foreach ($field in @("source", "exit_code", "status_output")) {
        if (-not (Test-Property -Object $Proof -Name $field)) { throw "clean repo proof missing $field" }
    }
    if ([int]$Proof.exit_code -ne 0) { throw "clean repo proof command must pass" }
    if (-not [string]::IsNullOrWhiteSpace([string]$Proof.status_output)) { throw "repo status must be clean" }
}
