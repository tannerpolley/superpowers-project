[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$RunResultPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

function Add-TerminalViolation {
    param([System.Collections.Generic.List[string]]$Violations, [string]$Reason)
    $Violations.Add($Reason) | Out-Null
}

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $resultPath = if ([IO.Path]::IsPathRooted($RunResultPath)) { $RunResultPath } else { Join-Path $repo $RunResultPath }
    $result = Read-LoopControllerJson -Path $resultPath
    $violations = [System.Collections.Generic.List[string]]::new()

    foreach ($property in @("run_ledger_valid", "verifier_valid", "metrics_valid", "clean_repo_required", "continuation_decision")) {
        if (-not (Test-LoopControllerProperty -Object $result -Name $property)) {
            Add-TerminalViolation -Violations $violations -Reason "$property is required"
        }
    }

    if ((Test-LoopControllerProperty -Object $result -Name "run_ledger_valid") -and $result.run_ledger_valid -ne $true) {
        Add-TerminalViolation -Violations $violations -Reason "run_ledger_valid proof is required"
    }
    if ((Test-LoopControllerProperty -Object $result -Name "verifier_valid") -and $result.verifier_valid -ne $true) {
        Add-TerminalViolation -Violations $violations -Reason "verifier_valid proof is required"
    }
    if ((Test-LoopControllerProperty -Object $result -Name "metrics_valid") -and $result.metrics_valid -ne $true) {
        Add-TerminalViolation -Violations $violations -Reason "metrics_valid proof is required"
    }

    if ((Test-LoopControllerProperty -Object $result -Name "clean_repo_required") -and $result.clean_repo_required -eq $true) {
        $status = if (Test-LoopControllerProperty -Object $result -Name "clean_repo_status") {
            [string]$result.clean_repo_status
        } else {
            (& git -C $repo status --short 2>$null | Out-String).Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($status)) {
            Add-TerminalViolation -Violations $violations -Reason "clean repo required but git status is not clean"
        }
    }

    if (Test-LoopControllerProperty -Object $result -Name "continuation_decision") {
        $decision = $result.continuation_decision
        foreach ($property in @("question_id", "selected_option", "terminal_state")) {
            if (-not (Test-LoopControllerProperty -Object $decision -Name $property)) {
                Add-TerminalViolation -Violations $violations -Reason "continuation_decision.$property is required"
            }
        }
        if ((Test-LoopControllerProperty -Object $decision -Name "question_id") -and [string]$decision.question_id -ne "project_loop_final_health_gate") {
            Add-TerminalViolation -Violations $violations -Reason "project_loop_final_health_gate question id is required"
        }
        if (Test-LoopControllerProperty -Object $decision -Name "selected_option") {
            $selected = [string]$decision.selected_option
            if ($selected -notin @("Done", "Stop")) {
                Add-TerminalViolation -Violations $violations -Reason "terminal option must be Done or Stop"
            }
            if ($selected -eq "Done" -and [string]$decision.terminal_state -ne "done") {
                Add-TerminalViolation -Violations $violations -Reason "Done requires terminal_state done"
            }
            if ($selected -eq "Stop" -and [string]$decision.terminal_state -ne "stop") {
                Add-TerminalViolation -Violations $violations -Reason "Stop requires terminal_state stop"
            }
        }
    }

    if ($violations.Count -gt 0) {
        throw ($violations -join "; ")
    }

    New-LoopControllerResult -Ok $true -Phase "loop-terminal-closeout" -Reason "terminal closeout is valid" -Evidence @{
        selected_option = [string]$result.continuation_decision.selected_option
        terminal_state = [string]$result.continuation_decision.terminal_state
    } | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-terminal-closeout" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
