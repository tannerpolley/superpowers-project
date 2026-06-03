[CmdletBinding()]
param(
    [ValidateSet("Inspect", "ApplySetup", "FinalizeSetup")][string]$Mode = "Inspect",
    [string]$RepoRoot = ".",
    [string]$IssueMirror,
    [string]$HandoffJson,
    [string]$HandoffPath,
    [string]$GoalProofJson,
    [string]$GoalProofPath,
    [string]$ExecutionDecisionJson,
    [string]$ExecutionDecisionPath,
    [string]$OutputDir,
    [ValidateSet("create", "reuse-current")][string]$BranchPolicy = "create"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "prepare-$($Mode.ToLowerInvariant())"

function Read-IssueMirrorContract {
    param([string]$RepoRoot, [string]$IssueMirror)
    if ([string]::IsNullOrWhiteSpace($IssueMirror)) { throw "IssueMirror is required" }
    $relativeIssueMirror = Assert-UnderRepoPath -RepoRoot $RepoRoot -Path $IssueMirror -Prefix "docs/superpowers/issues" -Name "issue mirror"
    $issuePath = Resolve-RepoFile -RepoRoot $RepoRoot -Path $IssueMirror
    if (-not (Test-Path -LiteralPath $issuePath -PathType Leaf)) { throw "issue mirror file is missing: $relativeIssueMirror" }
    $text = Get-Content -LiteralPath $issuePath -Raw
    $sourcePlan = Get-FieldValue -Text $text -Name "Source Plan"
    if ([string]::IsNullOrWhiteSpace($sourcePlan) -or $sourcePlan -eq "none") { throw "source plan is required in issue mirror" }
    $relativeSourcePlan = Assert-UnderRepoPath -RepoRoot $RepoRoot -Path $sourcePlan -Prefix "docs/superpowers/plans" -Name "source plan"
    $sourcePlanPath = Resolve-RepoFile -RepoRoot $RepoRoot -Path $sourcePlan
    if (-not (Test-Path -LiteralPath $sourcePlanPath -PathType Leaf)) { throw "source plan does not exist: $relativeSourcePlan" }
    $issueUrl = Get-FieldValue -Text $text -Name "GitHub Issue"
    if ([string]::IsNullOrWhiteSpace($issueUrl) -or $issueUrl -eq "pre-publication") { throw "GitHub Issue is required before execution" }
    $branch = Get-FieldValue -Text $text -Name "Branch"
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $slug = [IO.Path]::GetFileNameWithoutExtension($relativeIssueMirror) -replace '^\d+-', ''
        $branch = "codex/$slug"
    }
    $proof = @()
    if ($text -match "(?ims)^##\s*Proof Oracle\s*(?<body>.*?)(?:^##\s|\z)") {
        $proof = @($Matches.body -split "`r?`n" | Where-Object { $_ -match '^\s*[-*]\s+' } | ForEach-Object { ($_ -replace '^\s*[-*]\s+', '').Trim() })
    }
    if ($proof.Count -eq 0) { $proof = @("issue acceptance criteria checked") }
    $goalObjective = "Resolve $issueUrl on $branch using $relativeIssueMirror and $relativeSourcePlan. Complete proof oracle: $($proof -join '; ')."
    [ordered]@{
        issue_url = $issueUrl
        issue_mirror = $relativeIssueMirror
        source_plan = $relativeSourcePlan
        branch = Normalize-RepoPath $branch
        branch_policy = $BranchPolicy
        goal_objective = $goalObjective
        proof_oracle = $proof
        required_checks_policy = "require-existing"
    }
}

try {
    $root = Resolve-RepoRoot -RepoRoot $RepoRoot
    if ($Mode -eq "Inspect") {
        $handoff = Read-IssueMirrorContract -RepoRoot $root -IssueMirror $IssueMirror
        Complete-Contract -Phase $phase -Reason "issue mirror inspected" -Evidence @{ handoff = $handoff; handoff_json = ($handoff | ConvertTo-Json -Depth 16 -Compress) }
    }

    $handoff = Read-JsonInput -Json $HandoffJson -Path $HandoffPath -Name "handoff"
    $issueMirror = Assert-UnderRepoPath -RepoRoot $root -Path ([string]$handoff.issue_mirror) -Prefix "docs/superpowers/issues" -Name "issue mirror"
    $sourcePlan = Assert-UnderRepoPath -RepoRoot $root -Path ([string]$handoff.source_plan) -Prefix "docs/superpowers/plans" -Name "source plan"
    if (-not (Test-Path -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $issueMirror) -PathType Leaf)) { throw "issue mirror file is missing" }
    if (-not (Test-Path -LiteralPath (Resolve-RepoFile -RepoRoot $root -Path $sourcePlan) -PathType Leaf)) { throw "source plan does not exist" }

    if ($Mode -eq "ApplySetup") {
        $inventoryBefore = Get-BranchInventorySafe -RepoRoot $root
        $branch = Normalize-RepoPath ([string]$handoff.branch)
        if ([string]::IsNullOrWhiteSpace($branch)) { throw "branch is required" }
        if ([string]$handoff.branch_policy -eq "reuse-current") {
            $current = Invoke-GitSimple -RepoRoot $root -Arguments @("branch", "--show-current")
            if ($current.ExitCode -ne 0 -or (Normalize-RepoPath $current.Stdout) -ne $branch) { throw "reuse-current requires the current branch to match handoff branch" }
        } else {
            $existing = @($inventoryBefore.local) -contains $branch
            if ($existing) { throw "implementation branch already exists: $branch" }
            $switch = Invoke-GitSimple -RepoRoot $root -Arguments @("switch", "-c", $branch)
            if ($switch.ExitCode -ne 0) { throw "could not create implementation branch: $($switch.Stderr)" }
        }
        Complete-Contract -Phase $phase -Reason "branch ready; native goal activation required next" -Evidence @{ branch = $branch; issue_mirror = $issueMirror; source_plan = $sourcePlan; goal_objective = [string]$handoff.goal_objective; branch_inventory_before = $inventoryBefore }
    }

    $executionDecision = Read-JsonInput -Json $ExecutionDecisionJson -Path $ExecutionDecisionPath -Name "execution decision"
    Assert-ExecutionDecision -Decision $executionDecision
    if ([string]$executionDecision.selected_mode -eq "orchestrated-worker") {
        throw "orchestrated worker execution is owned by project-orchestrate; use project-resolve only for direct current-thread execution"
    }
    $goalProof = Read-JsonInput -Json $GoalProofJson -Path $GoalProofPath -Name "goal proof"
    Assert-NativeGoalProof -Proof $goalProof
    $inventory = Get-BranchInventorySafe -RepoRoot $root
    $goalId = if (Test-Property -Object $goalProof -Name "goal_id") { [string]$goalProof.goal_id } else { [string]$goalProof.thread_goal_proof }
    $setupLedger = [ordered]@{
        issue_url = [string]$handoff.issue_url
        issue_mirror = $issueMirror
        source_plan = $sourcePlan
        branch = Normalize-RepoPath ([string]$handoff.branch)
        goal_id = $goalId
        goal_objective = [string]$handoff.goal_objective
        goal_activation_proof = $goalProof
        execution_decision = $executionDecision
        workflow_policy = [ordered]@{
            worktree_policy = "Native Codex worktree thread first"
            integration_policy = "Current thread owns PR"
            tdd_policy = "Required"
            reviewer_role = "Main thread orchestrator"
            script_gate_mode = "Safety only"
        }
        dynamic_work_packet_map = $null
        worker_handoff = $null
        proof_oracle = Get-StringArray $handoff.proof_oracle
        branch_inventory_before = $inventory
    }
    $ledgerPath = $null
    if (-not [string]::IsNullOrWhiteSpace($OutputDir)) {
        $resolvedOutput = [IO.Path]::GetFullPath($OutputDir)
        $resolvedRoot = [IO.Path]::GetFullPath($root)
        if ($resolvedOutput.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "OutputDir must be outside the repo" }
        New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
        $ledgerPath = Join-Path $resolvedOutput "setup-ledger.json"
        $setupLedger | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
    }
    $json = $setupLedger | ConvertTo-Json -Depth 32 -Compress
    [ordered]@{ ok = $true; phase = $phase; reason = "setup finalized with native goal proof"; setup_ledger = $setupLedger; setup_ledger_json = $json; setup_ledger_path = $ledgerPath } | ConvertTo-Json -Depth 32
    exit 0
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{}
}
