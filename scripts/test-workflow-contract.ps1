[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("workflow-contract-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Write-TextFile {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Text -Encoding utf8NoBOM
}

function Invoke-WorkflowContractValidator {
    param(
        [string]$ContractPath,
        [string]$SkillRoot,
        [string[]]$WorkflowSkillNames
    )

    $arguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $RepoRoot "scripts\validate-workflow-contract.ps1"),
        "-RepoRoot", $RepoRoot,
        "-ContractPath", $ContractPath,
        "-SkillRoot", $SkillRoot
    )
    if ($WorkflowSkillNames.Count -gt 0) {
        $arguments += "-WorkflowSkillNames"
        $arguments += $WorkflowSkillNames
    }

    $raw = & pwsh.exe @arguments 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        raw = ($raw | Out-String).Trim()
        json = if ($LASTEXITCODE -eq 0) { (($raw | Out-String).Trim() | ConvertFrom-Json) } else { $null }
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $skillRoot = Join-Path $tempRoot "skills"
    $alphaSkill = Join-Path $skillRoot "alpha\SKILL.md"
    Write-TextFile -Path $alphaSkill -Text @"
---
name: alpha
description: Fixture workflow skill.
---

# Alpha

Question id: ``alpha_next_step``

Options:

- Yes: continue.
- Revisit: review.
- Stop: pause.

Question id: ``alpha_action_route``

Options:

- ``Do Work``: start the forward route.

Question id: ``alpha_approval``

Options:

- ``Approve``: approve.
- ``Decline``: decline.

Question id: ``alpha_permission``

Options:

- ``Push``: push.
- ``Hold``: hold.

Question id: ``alpha_topology``

Options:

- ``Inline``: run inline.
- ``Worker``: run worker.
- Stop: stop.

Question id: ``alpha_final_health``

Options:

- Done: finish.
- Revisit: review.
- Stop: stop.
"@

    $validContract = Join-Path $tempRoot "valid.yml"
    Write-TextFile -Path $validContract -Text @"
version: 1
helpers:
  advanced-user-input:
    owns: native-continuation-policy
workflow_skills:
  alpha:
    purpose: Fixture workflow skill.
    question_ids:
      - alpha_next_step
      - alpha_action_route
      - alpha_approval
      - alpha_permission
      - alpha_topology
      - alpha_final_health
    final_health_gate:
    top_level_options:
      - Yes
      - Revisit
      - Stop
    nested_routes:
      - question_id: alpha_action_route
        parent_option: Yes
        options:
          - Do Work
    gates:
      - question_id: alpha_next_step
        gate_type: top_level_continuation
        options:
          - label: Yes
            terminal_state: continue
          - label: Revisit
            terminal_state: revisit
          - label: Stop
            terminal_state: stop
      - question_id: alpha_action_route
        gate_type: nested_yes_route
        parent_question_id: alpha_next_step
        parent_option: Yes
        options:
          - label: Do Work
            terminal_state: continue
            next_route: alpha
      - question_id: alpha_approval
        gate_type: approval
        options:
          - label: Approve
            approval_effect: approve
          - label: Decline
            approval_effect: decline
      - question_id: alpha_permission
        gate_type: permission
        options:
          - label: Push
            permission_effect: approve-push
          - label: Hold
            permission_effect: hold
      - question_id: alpha_topology
        gate_type: topology
        allow_terminal_options: true
        options:
          - label: Inline
            topology: inline
          - label: Worker
            topology: worker
          - label: Stop
            terminal_state: stop
      - question_id: alpha_final_health
        gate_type: final_health
        options:
          - label: Done
            terminal_state: done
          - label: Revisit
            terminal_state: revisit
          - label: Stop
            terminal_state: stop
    validators:
      - scripts/validate.ps1
    artifacts:
      - docs/superpowers/specs/example.md
    next_routes:
      - alpha
"@

    $badNestedContract = Join-Path $tempRoot "bad-nested.yml"
    Write-TextFile -Path $badNestedContract -Text @"
version: 1
helpers:
  advanced-user-input:
    owns: native-continuation-policy
workflow_skills:
  alpha:
    purpose: Fixture workflow skill.
    question_ids:
      - alpha_next_step
      - alpha_action_route
      - alpha_approval
      - alpha_permission
      - alpha_topology
      - alpha_final_health
    final_health_gate:
    top_level_options:
      - Yes
      - Revisit
      - Stop
    nested_routes:
      - question_id: alpha_action_route
        parent_option: Yes
        options:
          - Do Work
          - Stop
    gates:
      - question_id: alpha_next_step
        gate_type: top_level_continuation
        options:
          - label: Yes
          - label: Revisit
          - label: Stop
      - question_id: alpha_action_route
        gate_type: nested_yes_route
        parent_question_id: alpha_next_step
        parent_option: Yes
        options:
          - label: Do Work
          - label: Stop
      - question_id: alpha_approval
        gate_type: approval
        options:
          - label: Approve
            approval_effect: approve
          - label: Decline
            approval_effect: decline
      - question_id: alpha_permission
        gate_type: permission
        options:
          - label: Push
            permission_effect: approve-push
          - label: Hold
            permission_effect: hold
      - question_id: alpha_topology
        gate_type: topology
        allow_terminal_options: true
        options:
          - label: Inline
          - label: Worker
          - label: Stop
      - question_id: alpha_final_health
        gate_type: final_health
        options:
          - label: Done
          - label: Revisit
          - label: Stop
    validators:
      - scripts/validate.ps1
    artifacts:
      - docs/superpowers/specs/example.md
    next_routes:
      - alpha
"@

    $badOptionContract = Join-Path $tempRoot "bad-option.yml"
    $badOptionText = Get-Content -LiteralPath $validContract -Raw
    $badOptionText = $badOptionText.Replace("label: Do Work", "label: Do Different Work")
    Write-TextFile -Path $badOptionContract -Text $badOptionText

    $missingGateContract = Join-Path $tempRoot "missing-gate.yml"
    $missingGateText = Get-Content -LiteralPath $validContract -Raw
    $missingGateText = $missingGateText -replace '(?ms)\n      - question_id: alpha_permission\n        gate_type: permission.*?(?=\n      - question_id: alpha_topology)', ''
    Write-TextFile -Path $missingGateContract -Text $missingGateText

    $valid = Invoke-WorkflowContractValidator -ContractPath $validContract -SkillRoot $skillRoot -WorkflowSkillNames @("alpha")
    Add-Check -Name "fixture contract passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason $valid.raw

    $bad = Invoke-WorkflowContractValidator -ContractPath $badNestedContract -SkillRoot $skillRoot -WorkflowSkillNames @("alpha")
    Add-Check -Name "nested terminal option fails" -Ok ($bad.exit_code -ne 0 -and $bad.raw -match "nested route") -Reason "nested routes must reject terminal options"

    $badOption = Invoke-WorkflowContractValidator -ContractPath $badOptionContract -SkillRoot $skillRoot -WorkflowSkillNames @("alpha")
    Add-Check -Name "exact option mismatch fails" -Ok ($badOption.exit_code -ne 0 -and $badOption.raw -match "options differ") -Reason "contract options must match skill options"

    $missingGate = Invoke-WorkflowContractValidator -ContractPath $missingGateContract -SkillRoot $skillRoot -WorkflowSkillNames @("alpha")
    Add-Check -Name "missing typed gate fails" -Ok ($missingGate.exit_code -ne 0 -and $missingGate.raw -match "typed gates") -Reason "every question id needs a typed gate"

    $repoContract = Join-Path $RepoRoot "docs\superpowers\workflow-contract.yml"
    $repoResult = Invoke-WorkflowContractValidator -ContractPath $repoContract -SkillRoot (Join-Path $RepoRoot "skills") -WorkflowSkillNames @()
    Add-Check -Name "repo contract passes" -Ok ($repoResult.exit_code -eq 0 -and $repoResult.json.ok -eq $true) -Reason $repoResult.raw

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "workflow-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "workflow-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
