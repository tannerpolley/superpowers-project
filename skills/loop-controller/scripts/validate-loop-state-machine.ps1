[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$StatePath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

$phase = "loop-state-machine"
$validRoutes = @("brainstorm-spec", "write-plan", "create-issues", "implement-plan", "resolve-issue", "orchestrate-issues", "merge-changes", "audit-project", "align-project")
$validSources = @("active-backlog", "ready-issue-mirror", "approved-plan", "approved-spec", "audit-finding", "alignment-drift", "version-drift", "live-sync-drift")
$completeOwnerStates = @("completed", "merged", "closed", "paused", "blocked")

function Add-Violation {
    param([System.Collections.Generic.List[string]]$Violations, [string]$Reason)
    $Violations.Add($Reason) | Out-Null
}

function Has-Property {
    param([object]$Object, [string]$Name)
    $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

function Read-RequiredState {
    param([string]$RepoRoot, [string]$Path)
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) }
    Read-LoopControllerJson -Path $full
}

function Test-TruthyOk {
    param([object]$Object)
    (Has-Property -Object $Object -Name "ok") -and $Object.ok -eq $true
}

function Test-ContinuationDecision {
    param([object]$Decision)
    (Has-Property -Object $Decision -Name "question_id") -and
    [string]$Decision.question_id -eq "project_loop_next_step" -and
    (Has-Property -Object $Decision -Name "selected_option") -and
    [string]$Decision.selected_option -eq "Yes" -and
    (Has-Property -Object $Decision -Name "terminal_state") -and
    [string]$Decision.terminal_state -eq "continue"
}

try {
    [void](Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot)
    $state = Read-RequiredState -RepoRoot $RepoRoot -Path $StatePath
    $violations = [System.Collections.Generic.List[string]]::new()

    foreach ($property in @("selected_mode", "status", "selection_authority", "candidates_ready_count", "iterations", "skipped")) {
        if (-not (Has-Property -Object $state -Name $property)) {
            Add-Violation -Violations $violations -Reason "$property is required"
        }
    }

    if ((Has-Property -Object $state -Name "selected_mode") -and [string]$state.selected_mode -ne "looping") {
        Add-Violation -Violations $violations -Reason "selected_mode must be looping"
    }

    if ((Has-Property -Object $state -Name "selection_authority") -and [string]$state.selection_authority -eq "auto-mode") {
        Add-Violation -Violations $violations -Reason "Auto Mode authorization cannot drive Looping Mode queue draining"
    }
    if ((Has-Property -Object $state -Name "auto_mode_authorization_drives_queue") -and $state.auto_mode_authorization_drives_queue -eq $true) {
        Add-Violation -Violations $violations -Reason "Auto Mode authorization cannot drive Looping Mode queue draining"
    }

    $dirtyRepoStatus = if (Has-Property -Object $state -Name "dirty_repo_status") { [string]$state.dirty_repo_status } else { "" }
    if (-not [string]::IsNullOrWhiteSpace($dirtyRepoStatus)) {
        Add-Violation -Violations $violations -Reason "dirty repo blocks candidate selection"
    }

    $iterations = if (Has-Property -Object $state -Name "iterations") { @($state.iterations) } else { @() }
    $readyCount = if (Has-Property -Object $state -Name "candidates_ready_count") { [int]$state.candidates_ready_count } else { 0 }

    if ($readyCount -eq 0) {
        if ($iterations.Count -gt 0) {
            Add-Violation -Violations $violations -Reason "no-ready state must not select a candidate"
        }
        if (-not (Has-Property -Object $state -Name "no_ready_proof") -or -not (Has-Property -Object $state.no_ready_proof -Name "reason") -or [string]::IsNullOrWhiteSpace([string]$state.no_ready_proof.reason)) {
            Add-Violation -Violations $violations -Reason "no-ready candidates require no_ready_proof"
        }
    } elseif ($iterations.Count -eq 0 -and [string]$state.status -notin @("paused", "blocked")) {
        Add-Violation -Violations $violations -Reason "ready candidates require one selected iteration or an explicit paused/blocked state"
    }

    for ($index = 0; $index -lt $iterations.Count; $index++) {
        $iteration = $iterations[$index]
        foreach ($property in @("selected_candidate_id", "candidate_source", "selected_route", "owner_route", "owner_result", "budget_check_before_selection")) {
            if (-not (Has-Property -Object $iteration -Name $property)) {
                Add-Violation -Violations $violations -Reason "iteration $($index + 1) missing $property"
            }
        }

        $selectedIds = if (Has-Property -Object $iteration -Name "selected_candidate_ids") { @($iteration.selected_candidate_ids) } else { @([string]$iteration.selected_candidate_id) }
        if ($selectedIds.Count -ne 1) {
            Add-Violation -Violations $violations -Reason "one_candidate_per_iteration requires exactly one selected candidate"
        }

        if ((Has-Property -Object $iteration -Name "candidate_source") -and [string]$iteration.candidate_source -notin $validSources) {
            Add-Violation -Violations $violations -Reason "candidate source is invalid: $($iteration.candidate_source)"
        }
        if ((Has-Property -Object $iteration -Name "selected_route") -and [string]$iteration.selected_route -notin $validRoutes) {
            Add-Violation -Violations $violations -Reason "selected route is invalid: $($iteration.selected_route)"
        }
        if ((Has-Property -Object $iteration -Name "owner_route") -and [string]$iteration.owner_route -notin $validRoutes) {
            Add-Violation -Violations $violations -Reason "owner route is invalid: $($iteration.owner_route)"
        }
        if ((Has-Property -Object $iteration -Name "selected_route") -and (Has-Property -Object $iteration -Name "owner_route") -and [string]$iteration.selected_route -ne [string]$iteration.owner_route) {
            Add-Violation -Violations $violations -Reason "owner route must match selected route"
        }
        if ((Has-Property -Object $iteration -Name "budget_check_before_selection") -and -not (Test-TruthyOk -Object $iteration.budget_check_before_selection)) {
            Add-Violation -Violations $violations -Reason "budget check before selection must pass"
        }

        $ownerStatus = if ((Has-Property -Object $iteration -Name "owner_result") -and (Has-Property -Object $iteration.owner_result -Name "status")) { [string]$iteration.owner_result.status } else { "" }
        if ([string]::IsNullOrWhiteSpace($ownerStatus)) {
            Add-Violation -Violations $violations -Reason "owner result status is required"
        }

        if ($index -lt ($iterations.Count - 1)) {
            if ($ownerStatus -notin $completeOwnerStates) {
                Add-Violation -Violations $violations -Reason "owner result must finish before selecting another candidate"
            }
            if (-not (Has-Property -Object $iteration -Name "budget_recheck_after_candidate") -or -not (Test-TruthyOk -Object $iteration.budget_recheck_after_candidate)) {
                Add-Violation -Violations $violations -Reason "budget recheck after candidate must pass before selecting another candidate"
            }
            if (-not (Has-Property -Object $iteration -Name "continuation_decision") -or -not (Test-ContinuationDecision -Decision $iteration.continuation_decision)) {
                Add-Violation -Violations $violations -Reason "project_loop_next_step continuation is required before selecting another candidate"
            }
        }
    }

    foreach ($skipped in @(if (Has-Property -Object $state -Name "skipped") { $state.skipped } else { @() })) {
        if ((Has-Property -Object $skipped -Name "source") -and [string]$skipped.source -eq "historical-checkbox") {
            $reason = if (Has-Property -Object $skipped -Name "reason") { [string]$skipped.reason } else { "" }
            if ($reason -notmatch "(?i)historical|archived|status") {
                Add-Violation -Violations $violations -Reason "historical checkbox skips require explicit rejection reason"
            }
        }
    }

    if (Has-Property -Object $state -Name "terminal_decision") {
        $terminal = $state.terminal_decision
        if ((Has-Property -Object $terminal -Name "selected_option") -and [string]$terminal.selected_option -eq "Done") {
            if ([string]$state.status -ne "complete") { Add-Violation -Violations $violations -Reason "Done requires status complete" }
            foreach ($proof in @("run_ledger_valid", "verifier_valid", "metrics_valid")) {
                if (-not (Has-Property -Object $state -Name $proof) -or $state.$proof -ne $true) {
                    Add-Violation -Violations $violations -Reason "Done requires $proof"
                }
            }
            $cleanStatus = if (Has-Property -Object $state -Name "clean_repo_status") { [string]$state.clean_repo_status } else { (& git -C (Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot) status --short 2>$null | Out-String).Trim() }
            if (-not [string]::IsNullOrWhiteSpace($cleanStatus)) {
                Add-Violation -Violations $violations -Reason "Done requires clean repo"
            }
        }
    }

    if ($violations.Count -gt 0) {
        throw ($violations -join "; ")
    }

    New-LoopControllerResult -Ok $true -Phase $phase -Reason "loop state machine is valid" -Evidence @{
        iterations = $iterations.Count
        candidates_ready_count = $readyCount
    } | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase $phase -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
