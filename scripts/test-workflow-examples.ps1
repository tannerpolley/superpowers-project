[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("workflow-examples-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-JsonScript {
    param([string]$Path, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ exit_code = 127; raw = "missing script: $Path"; json = $null }
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    $text = ($raw | Out-String).Trim()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = $text; json = $json }
}

function Get-ValidExamplesMarkdown {
    @'
# Workflow Golden Paths

## Idea To Local Merge

**Example ID:** idea-to-local-merge
**Route sequence:** brainstorm-spec -> write-plan -> implement-plan -> merge-changes
**Question IDs:** project_brainstorm_next_step, project_brainstorm_plan_route, project_plan_next_step, project_plan_work_route, implement_plan_topology, implement_plan_push_permission, project_implement_next_step, project_merge_approval, project_merge_final_health_gate
**Artifacts:** docs/superpowers/specs/<idea-spec>.md; docs/superpowers/plans/<implementation-plan>.md; pull request; closeout ledger
**Validators:** scripts/validate-plan-outcome-proof.ps1; scripts/validate-plan-task-use-cases.ps1; scripts/validate.ps1
**Stop point:** project_merge_final_health_gate after clean local merge closeout.

## Spec To Issues To Merge

**Example ID:** spec-to-issues-to-merge
**Route sequence:** write-plan -> create-issues -> resolve-issue -> merge-changes
**Question IDs:** project_plan_next_step, project_plan_work_route, project_plan_issue_count, project_issue_next_step, project_issue_execution_route, project_resolve_push_permission, project_resolve_next_step, project_resolve_integration_route, project_merge_approval, project_merge_final_health_gate
**Artifacts:** docs/superpowers/plans/<approved-plan>.md; docs/superpowers/issues/<issue>.md; pull request; milestone summary
**Validators:** skills/create-issues/scripts/validate-issue-mirror.ps1; skills/resolve-issue/scripts/validate-pr-ready.ps1; skills/merge-changes/scripts/closeout.ps1
**Stop point:** project_merge_final_health_gate after the linked issue is closed.

## Audit To Auto Mode Single Route

**Example ID:** audit-to-auto-mode-single-route
**Route sequence:** audit-project -> write-plan
**Question IDs:** project_audit_next_step, project_audit_progress_route, project_auto_mode_authorization, project_plan_next_step, project_plan_work_route
**Artifacts:** docs/superpowers/specs/<audit-findings>.md; docs/superpowers/plans/<repair-plan>.md; auto-mode authorization ledger
**Validators:** scripts/validate-auto-mode-authorization.ps1; scripts/validate-plan-outcome-proof.ps1; scripts/validate.ps1
**Stop point:** project_plan_next_step after one route only; Auto Mode does not continue to another candidate.

## Looping Mode Candidate Selection

**Example ID:** looping-mode-candidate-selection
**Route sequence:** initiate-workflow -> loop-controller -> resolve-issue -> merge-changes -> loop-controller
**Question IDs:** project_workflow_mode, project_loop_next_step, project_resolve_push_permission, project_resolve_next_step, project_resolve_integration_route, project_merge_approval, project_merge_final_health_gate, project_loop_next_step
**Artifacts:** docs/superpowers/loop-mode-contract.yml; .superpowers/runs/<run-id>/run-ledger.json; .superpowers/runs/<run-id>/budget-ledger.json; .superpowers/runs/<run-id>/loop-state-machine.json; docs/superpowers/backlog/ACTIVE.md; closeout ledger
**Validators:** skills/loop-controller/scripts/validate-run-ledger.ps1; skills/loop-controller/scripts/validate-budget.ps1; skills/loop-controller/scripts/select-candidate.ps1; skills/loop-controller/scripts/validate-loop-state-machine.ps1
**Stop point:** project_loop_next_step after owner-route proof, verifier proof, budget recheck, and state-machine proof.
'@
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $validator = Join-Path $RepoRoot "scripts\validate-workflow-examples.ps1"
    $validPath = Join-Path $tempRoot "valid-examples.md"
    Get-ValidExamplesMarkdown | Set-Content -LiteralPath $validPath -Encoding utf8NoBOM

    $valid = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $validPath)
    Add-Check -Name "valid workflow examples pass" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true -and $valid.json.example_count -eq 4) -Reason $valid.raw

    $unknownQuestionPath = Join-Path $tempRoot "unknown-question.md"
    (Get-ValidExamplesMarkdown).Replace("project_plan_work_route", "project_plan_route_that_does_not_exist") | Set-Content -LiteralPath $unknownQuestionPath -Encoding utf8NoBOM
    $unknownQuestion = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $unknownQuestionPath)
    Add-Check -Name "unknown question id fails" -Ok ($unknownQuestion.exit_code -ne 0 -and $unknownQuestion.raw.Contains("question id")) -Reason "unknown question id should fail"

    $missingStopPath = Join-Path $tempRoot "missing-stop.md"
    (Get-ValidExamplesMarkdown) -replace '(?m)^\*\*Stop point:\*\*.*\r?\n', '' | Set-Content -LiteralPath $missingStopPath -Encoding utf8NoBOM
    $missingStop = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $missingStopPath)
    Add-Check -Name "missing stop point fails" -Ok ($missingStop.exit_code -ne 0 -and $missingStop.raw.Contains("Stop point")) -Reason "missing stop point should fail"

    $loopWithoutBudgetPath = Join-Path $tempRoot "loop-without-budget.md"
    (Get-ValidExamplesMarkdown).Replace("budget recheck, and ", "") | Set-Content -LiteralPath $loopWithoutBudgetPath -Encoding utf8NoBOM
    $loopWithoutBudget = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $loopWithoutBudgetPath)
    Add-Check -Name "loop example requires budget recheck" -Ok ($loopWithoutBudget.exit_code -ne 0 -and $loopWithoutBudget.raw.Contains("budget recheck")) -Reason "loop example without budget recheck should fail"

    $loopWithoutStateMachinePath = Join-Path $tempRoot "loop-without-state-machine.md"
    (Get-ValidExamplesMarkdown).
        Replace("docs/superpowers/loop-mode-contract.yml; ", "").
        Replace("; .superpowers/runs/<run-id>/loop-state-machine.json", "").
        Replace("; skills/loop-controller/scripts/validate-loop-state-machine.ps1", "").
        Replace(", and state-machine proof", "") |
        Set-Content -LiteralPath $loopWithoutStateMachinePath -Encoding utf8NoBOM
    $loopWithoutStateMachine = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $loopWithoutStateMachinePath)
    Add-Check -Name "loop example requires state-machine proof" -Ok ($loopWithoutStateMachine.exit_code -ne 0 -and $loopWithoutStateMachine.raw.Contains("state-machine")) -Reason "loop example without state-machine proof should fail"

    $autoContinuesPath = Join-Path $tempRoot "auto-continues.md"
    (Get-ValidExamplesMarkdown).Replace("after one route only; Auto Mode does not continue to another candidate", "after continuing to another candidate") | Set-Content -LiteralPath $autoContinuesPath -Encoding utf8NoBOM
    $autoContinues = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $RepoRoot, "-Path", $autoContinuesPath)
    Add-Check -Name "auto mode example requires one-route stop" -Ok ($autoContinues.exit_code -ne 0 -and $autoContinues.raw.Contains("one route")) -Reason "auto mode continuing to another candidate should fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "workflow-examples"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "workflow-examples"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
