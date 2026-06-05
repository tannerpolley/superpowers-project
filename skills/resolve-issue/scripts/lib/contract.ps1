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

function Resolve-RepoFile {
    param([string]$RepoRoot, [string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-RelativeRepoPath {
    param([string]$RepoRoot, [string]$Path)
    Normalize-RepoPath ([IO.Path]::GetRelativePath($RepoRoot, (Resolve-RepoFile -RepoRoot $RepoRoot -Path $Path)))
}

function Assert-UnderRepoPath {
    param([string]$RepoRoot, [string]$Path, [string]$Prefix, [string]$Name)
    $relative = Get-RelativeRepoPath -RepoRoot $RepoRoot -Path $Path
    $normalizedPrefix = (Normalize-RepoPath $Prefix).TrimEnd('/') + '/'
    if (-not $relative.StartsWith($normalizedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name must be under $($normalizedPrefix.TrimEnd('/'))"
    }
    $relative
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
    $null
}

function Get-IssueNumberFromUrl {
    param([string]$IssueUrl)
    if ($IssueUrl -match '/issues/(?<n>\d+)(?:$|[?#])') { return [int]$Matches.n }
    $null
}

function Get-PullNumberFromUrl {
    param([string]$PullUrl)
    if ($PullUrl -match '/pull/(?<n>\d+)(?:$|[?#])') { return [int]$Matches.n }
    $null
}

function Get-RepoSlugFromIssueUrl {
    param([string]$IssueUrl)
    if ($IssueUrl -match '^https://github\.com/(?<repo>[^/]+/[^/]+)/issues/\d+(?:[?#].*)?$') { return $Matches.repo }
    $null
}

function Get-RepoSlugFromPullUrl {
    param([string]$PullUrl)
    if ($PullUrl -match '^https://github\.com/(?<repo>[^/]+/[^/]+)/pull/\d+(?:[?#].*)?$') { return $Matches.repo }
    $null
}

function Invoke-GitSimple {
    param([string]$RepoRoot, [string[]]$Arguments)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "git"
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($arg in @("-C", $RepoRoot) + $Arguments) { [void]$psi.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout.Trim(); Stderr = $stderr.Trim() }
}

function Get-BranchInventorySafe {
    param([string]$RepoRoot)
    $local = Invoke-GitSimple -RepoRoot $RepoRoot -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/heads")
    $remote = Invoke-GitSimple -RepoRoot $RepoRoot -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin")
    [pscustomobject]@{
        local = @($local.Stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
        remote = @($remote.Stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "origin/HEAD" } | ForEach-Object { $_ -replace '^origin/', '' } | Sort-Object)
    }
}

function Assert-NativeGoalProof {
    param($Proof)
    if ($null -eq $Proof) { throw "goal_activation_proof is required" }
    if ($Proof -is [string]) { throw "goal_activation_proof must be structured, not a string" }
    if (-not (Test-Property -Object $Proof -Name "source")) { throw "goal_activation_proof missing source" }
    if ([string]$Proof.source -ne "get_goal") { throw "goal_activation_proof source must be get_goal" }
    if (-not (Test-Property -Object $Proof -Name "active") -or $Proof.active -ne $true) { throw "goal_activation_proof must show an active native goal" }
    if (-not (Test-Property -Object $Proof -Name "objective") -or [string]::IsNullOrWhiteSpace([string]$Proof.objective)) { throw "goal_activation_proof missing objective" }
    if (-not (Test-Property -Object $Proof -Name "goal_id") -and -not (Test-Property -Object $Proof -Name "thread_goal_proof")) {
        throw "goal_id or thread goal proof is required"
    }
}

function Assert-ExecutionDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "execution decision is required" }
    if ($Decision -is [string]) { throw "execution decision must be structured, not a string" }
    foreach ($field in @("question_id", "source", "selected_mode", "recommended_mode", "options")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "execution decision missing $field" }
    }
    if ([string]$Decision.question_id -ne "resolve_execution_topology") { throw "execution decision question_id mismatch" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "execution decision source must be request_user_input or debug_question_mode" }
    if ([string]$Decision.selected_mode -notin @("inline", "orchestrated-worker")) { throw "execution decision selected_mode must be inline or orchestrated-worker" }
    if ([string]$Decision.recommended_mode -notin @("inline", "orchestrated-worker")) { throw "execution decision recommended_mode must be inline or orchestrated-worker" }
    $options = Get-StringArray $Decision.options
    foreach ($requiredOption in @("orchestrated-worker", "inline")) {
        if ($options -notcontains $requiredOption) { throw "execution decision options must include $requiredOption" }
    }
}

function Assert-PushPermission {
    param($Permission)
    if ($null -eq $Permission) { throw "push permission is required" }
    if ($Permission -is [string]) { throw "push permission must be structured, not a string" }
    foreach ($field in @("question_id", "source", "selected_action", "recommended_action", "options")) {
        if (-not (Test-Property -Object $Permission -Name $field)) { throw "push permission missing $field" }
    }
    if ([string]$Permission.question_id -ne "project_resolve_push_permission") { throw "push permission question_id mismatch" }
    if ([string]$Permission.source -notin @("request_user_input", "debug_question_mode")) { throw "push permission source must be request_user_input or debug_question_mode" }
    if ([string]$Permission.selected_action -notin @("push-pr", "hold")) { throw "push permission selected_action must be push-pr or hold" }
    if ([string]$Permission.recommended_action -ne "push-pr") { throw "push permission recommended_action must be push-pr after clean verification" }
    $options = Get-StringArray $Permission.options
    foreach ($requiredOption in @("push-pr", "hold")) {
        if ($options -notcontains $requiredOption) { throw "push permission options must include $requiredOption" }
    }
    if ([string]$Permission.selected_action -ne "push-pr") { throw "push was not approved by the user" }
}

function Assert-ResolveContinuationDecision {
    param($Decision)
    if ($null -eq $Decision) { throw "continuation decision is required" }
    if ($Decision -is [string]) { throw "continuation decision must be structured, not a string" }
    foreach ($field in @("skill", "question_id", "prompt", "source", "selected_option_id", "recommended_option_id", "option_ids", "terminal_state")) {
        if (-not (Test-Property -Object $Decision -Name $field)) { throw "continuation decision missing $field" }
    }
    if ([string]$Decision.skill -ne "resolve-issue") { throw "continuation decision skill must be resolve-issue" }
    $questionId = [string]$Decision.question_id
    $allowedQuestionIds = @(
        "project_resolve_next_step",
        "project_resolve_integration_route",
        "project_resolve_another_issue_route",
        "project_resolve_reiteration_route",
        "project_resolve_fix_route"
    )
    if ($questionId -notin $allowedQuestionIds) { throw "continuation decision question_id is not recognized for resolve-issue" }
    if ([string]$Decision.source -notin @("request_user_input", "debug_question_mode")) { throw "continuation decision source must be request_user_input or debug_question_mode" }
    $selectedOptionId = [string]$Decision.selected_option_id
    $recommendedOptionId = [string]$Decision.recommended_option_id
    $optionIds = Get-StringArray $Decision.option_ids
    if ($optionIds.Count -eq 0) { throw "continuation decision option_ids must be populated" }
    if ($optionIds -notcontains $selectedOptionId) { throw "continuation decision selected_option_id must appear in option_ids" }
    if ($optionIds -notcontains $recommendedOptionId) { throw "continuation decision recommended_option_id must appear in option_ids" }
    $terminalState = [string]$Decision.terminal_state
    if ($terminalState -notin @("stop", "done", "continue", "revisit")) { throw "continuation decision terminal_state must be stop, done, continue, or revisit" }
    if ($selectedOptionId -eq "stop" -and $terminalState -ne "stop") { throw "continuation decision stop must use terminal_state stop" }
    if ($selectedOptionId -eq "done" -and $terminalState -ne "done") { throw "continuation decision done must use terminal_state done" }
}

function Assert-ResolveTerminalContinuationDecision {
    param($Decision)
    Assert-ResolveContinuationDecision -Decision $Decision
    $selectedOptionId = [string]$Decision.selected_option_id
    $terminalState = [string]$Decision.terminal_state
    if ($selectedOptionId -eq "stop" -and $terminalState -eq "stop") { return }
    if ($terminalState -eq "done" -or $selectedOptionId -eq "done") {
        throw "resolve-issue has no verified final Done gate; explicit Stop is required to end the workflow"
    }
    throw "resolve-issue cannot terminate on continuation decision '$selectedOptionId'; continue the selected route or record explicit Stop"
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
