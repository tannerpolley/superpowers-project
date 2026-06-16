[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$BudgetLedgerPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\loop-controller.ps1")

function Add-LimitViolation {
    param(
        [System.Collections.Generic.List[string]]$Violations,
        [object]$Ledger,
        [string]$Actual,
        [string]$Maximum,
        [ValidateSet("GreaterThanOrEqual", "GreaterThan")][string]$Mode
    )
    Assert-LoopRequiredProperties -Object $Ledger -Names @($Actual, $Maximum)
    $actualValue = [int]$Ledger.$Actual
    $maximumValue = [int]$Ledger.$Maximum
    $failed = if ($Mode -eq "GreaterThanOrEqual") { $actualValue -ge $maximumValue } else { $actualValue -gt $maximumValue }
    if ($failed) {
        $operator = if ($Mode -eq "GreaterThanOrEqual") { ">=" } else { ">" }
        $Violations.Add("$Actual exhausted: $actualValue $operator $maximumValue") | Out-Null
    }
}

try {
    $repo = Resolve-LoopControllerRepoRoot -RepoRoot $RepoRoot
    $budgetPath = if ([IO.Path]::IsPathRooted($BudgetLedgerPath)) { $BudgetLedgerPath } else { Join-Path $repo $BudgetLedgerPath }
    $budget = Read-LoopControllerJson -Path $budgetPath
    $violations = [System.Collections.Generic.List[string]]::new()

    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "candidates_completed" -Maximum "max_candidates" -Mode GreaterThanOrEqual
    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "current_phase_attempts" -Maximum "max_attempts_per_phase" -Mode GreaterThanOrEqual
    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "repeated_same_failure_count" -Maximum "max_repeated_same_failure" -Mode GreaterThanOrEqual
    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "changed_files" -Maximum "max_changed_files" -Mode GreaterThan
    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "github_mutations" -Maximum "max_github_mutations" -Mode GreaterThan
    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "validator_reruns" -Maximum "max_validator_reruns" -Mode GreaterThan
    Add-LimitViolation -Violations $violations -Ledger $budget -Actual "unreviewed_diff_lines" -Maximum "max_unreviewed_diff_lines" -Mode GreaterThan

    if ($violations.Count -gt 0) {
        throw ($violations -join "; ")
    }

    New-LoopControllerResult -Ok $true -Phase "loop-budget" -Reason "budget is within policy" -Evidence @{ budget_ledger_path = [string]$BudgetLedgerPath } | ConvertTo-Json -Depth 8
} catch {
    New-LoopControllerResult -Ok $false -Phase "loop-budget" -Reason $_.Exception.Message | ConvertTo-Json -Depth 8
    exit 1
}
