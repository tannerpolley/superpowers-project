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

function New-DynamicWorkPacketMap {
    param($Handoff, $Decision)
    [ordered]@{
        goal = [string]$Handoff.goal_objective
        success_criteria = @(
            "acceptance criteria covered",
            "verification passes",
            "branch pushed",
            "PR opened and closes linked issue",
            "PR-ready handoff sent to main orchestrator"
        )
        repo_context = [ordered]@{
            issue_url = [string]$Handoff.issue_url
            issue_mirror = Normalize-RepoPath ([string]$Handoff.issue_mirror)
            source_plan = Normalize-RepoPath ([string]$Handoff.source_plan)
            branch = Normalize-RepoPath ([string]$Handoff.branch)
        }
        orchestrator_owner = "main-thread-orchestrator"
        merge_owner = "project-merge"
        full_dynamic_workflow_policy = "Use only when scope, risk, independent packets, separate verification, reusable workflow value, or explicit user request justifies it."
        worker_packet = [ordered]@{
            objective = "Implement the linked issue to PR-ready evidence."
            do = @(
                "use superpowers:using-git-worktrees",
                "use superpowers:test-driven-development unless the source plan records an explicit opt-out",
                "use superpowers:executing-plans or superpowers:subagent-driven-development",
                "use superpowers:verification-before-completion",
                "use superpowers:finishing-a-development-branch",
                "open a PR that closes the exact linked issue",
                "send PR-ready handoff to the main orchestrator"
            )
            do_not = @(
                "merge the PR",
                "delete branches outside the owned implementation branch",
                "create GoalBuddy boards",
                "create .workflow directories for ordinary issue resolution"
            )
            expected_output = "PR-ready handoff ledger"
            verification = Get-StringArray $Handoff.proof_oracle
        }
        wakeup_policy = "worker handoff or bounded heartbeat"
    }
}

function Assert-DynamicWorkPacketMap {
    param($Map)
    if ($null -eq $Map) { throw "dynamic_work_packet_map is required for orchestrated-worker execution" }
    if ($Map -is [string]) { throw "dynamic_work_packet_map must be structured" }
    foreach ($field in @("goal", "success_criteria", "repo_context", "orchestrator_owner", "merge_owner", "worker_packet", "wakeup_policy")) {
        if (-not (Test-Property -Object $Map -Name $field)) { throw "dynamic_work_packet_map missing $field" }
    }
    if ([string]$Map.merge_owner -ne "project-merge") { throw "dynamic_work_packet_map merge_owner must be project-merge" }
}

function New-WorkerHandoff {
    param($Handoff, $Decision)
    [ordered]@{
        issue_url = [string]$Handoff.issue_url
        issue_mirror = Normalize-RepoPath ([string]$Handoff.issue_mirror)
        source_plan = Normalize-RepoPath ([string]$Handoff.source_plan)
        branch = Normalize-RepoPath ([string]$Handoff.branch)
        goal_objective = [string]$Handoff.goal_objective
        proof_oracle = Get-StringArray $Handoff.proof_oracle
        execution_mode = [string]$Decision.selected_mode
        required_skills = @(
            "superpowers:using-git-worktrees",
            "superpowers:test-driven-development",
            "superpowers:executing-plans",
            "superpowers:verification-before-completion",
            "superpowers:finishing-a-development-branch"
        )
        dynamic_work_packet_map = New-DynamicWorkPacketMap -Handoff $Handoff -Decision $Decision
        integration_owner = "project-merge"
    }
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
