[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$ContractPath,
    [string]$SkillRoot,
    [string[]]$WorkflowSkillNames = @()
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-skills.ps1")
. (Join-Path $PSScriptRoot "lib\workflow-contract.ps1")

$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Complete {
    param([bool]$Ok, [string]$Reason = "")
    $result = [ordered]@{ ok = $Ok; phase = "workflow-contract"; checks = $checks }
    if (-not [string]::IsNullOrWhiteSpace($Reason)) { $result.reason = $Reason }
    [pscustomobject]$result | ConvertTo-Json -Depth 12
    if ($Ok) { exit 0 }
    exit 1
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    if ([string]::IsNullOrWhiteSpace($ContractPath)) {
        $ContractPath = Join-Path $root "docs\superpowers\workflow-contract.yml"
    } elseif (-not [IO.Path]::IsPathRooted($ContractPath)) {
        $ContractPath = Join-Path $root $ContractPath
    }
    if ([string]::IsNullOrWhiteSpace($SkillRoot)) {
        $SkillRoot = Join-Path $root "skills"
    } elseif (-not [IO.Path]::IsPathRooted($SkillRoot)) {
        $SkillRoot = Join-Path $root $SkillRoot
    }
    if ($WorkflowSkillNames.Count -eq 0) {
        $WorkflowSkillNames = @(Get-ProjectWorkflowSkillNames -RepoRoot $root)
    }

    $contract = Read-WorkflowContract -Path $ContractPath
    Add-Check -Name "contract file parses" -Ok $true -Reason "passed"

    $workflowSkillsObject = $contract.workflow_skills
    if ($null -eq $workflowSkillsObject) { Complete -Ok $false -Reason "workflow_skills is required" }
    $contractSkillNames = @($workflowSkillsObject.PSObject.Properties.Name | Sort-Object)
    $expectedSkillNames = @($WorkflowSkillNames | Sort-Object)

    $missing = @($expectedSkillNames | Where-Object { $contractSkillNames -notcontains $_ })
    $extra = @($contractSkillNames | Where-Object { $expectedSkillNames -notcontains $_ })
    Add-Check -Name "contract includes every workflow skill" -Ok ($missing.Count -eq 0) -Reason "missing workflow skill(s): $($missing -join ', ')"
    Add-Check -Name "contract has no unknown workflow skills" -Ok ($extra.Count -eq 0) -Reason "unknown workflow skill(s): $($extra -join ', ')"

    $helperNames = if ($null -eq $contract.helpers) { @() } else { @($contract.helpers.PSObject.Properties.Name) }
    Add-Check -Name "advanced-user-input helper declared" -Ok ($helperNames -contains "advanced-user-input") -Reason "helpers.advanced-user-input is required"

    $finalCapable = @(Get-ProjectFinalCapableSkillNames)
    foreach ($skillName in $expectedSkillNames) {
        $skillContract = $workflowSkillsObject.$skillName
        if ($null -eq $skillContract) { continue }
        $skillPath = Join-Path $SkillRoot "$skillName\SKILL.md"
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
            Add-Check -Name "$skillName skill file exists" -Ok $false -Reason "missing skill file: $skillPath"
            continue
        }
        Add-Check -Name "$skillName skill file exists" -Ok $true -Reason "passed"

        $actualQuestionIds = @(Get-WorkflowSkillQuestionIds -SkillPath $skillPath)
        $contractQuestionIds = @(Get-WorkflowContractQuestionIds -SkillContract $skillContract)
        $missingQuestionIds = @($actualQuestionIds | Where-Object { $contractQuestionIds -notcontains $_ })
        $extraQuestionIds = @($contractQuestionIds | Where-Object { $actualQuestionIds -notcontains $_ })
        Add-Check -Name "$skillName contract lists skill question ids" -Ok ($missingQuestionIds.Count -eq 0) -Reason "$skillName missing question id(s): $($missingQuestionIds -join ', ')"
        Add-Check -Name "$skillName contract question ids exist in skill" -Ok ($extraQuestionIds.Count -eq 0) -Reason "$skillName contract has unknown question id(s): $($extraQuestionIds -join ', ')"

        if ($finalCapable -contains $skillName) {
            $finalGate = [string]$skillContract.final_health_gate
            Add-Check -Name "$skillName final gate declared" -Ok (-not [string]::IsNullOrWhiteSpace($finalGate)) -Reason "$skillName must declare final_health_gate"
            Add-Check -Name "$skillName final gate is a question id" -Ok ($contractQuestionIds -contains $finalGate) -Reason "$skillName final_health_gate must appear in question_ids"
        }

        $validators = @(Get-WorkflowStringArray $skillContract.validators)
        $artifacts = @(Get-WorkflowStringArray $skillContract.artifacts)
        Add-Check -Name "$skillName validators declared" -Ok ($validators.Count -gt 0) -Reason "$skillName must declare validators"
        Add-Check -Name "$skillName artifacts declared" -Ok ($artifacts.Count -gt 0) -Reason "$skillName must declare expected artifacts"

        foreach ($route in @($skillContract.nested_routes)) {
            if ($null -eq $route) { continue }
            $routeQuestionId = [string]$route.question_id
            Add-Check -Name "$skillName nested route question id exists: $routeQuestionId" -Ok ($contractQuestionIds -contains $routeQuestionId) -Reason "$skillName nested route uses undeclared question id: $routeQuestionId"
            $routeOptions = @(Get-WorkflowStringArray $route.options)
            $terminalOptions = @($routeOptions | Where-Object { $_ -in @("Stop", "Done") })
            Add-Check -Name "$skillName nested route excludes terminal options: $routeQuestionId" -Ok ($terminalOptions.Count -eq 0) -Reason "$skillName nested route $routeQuestionId includes terminal option(s): $($terminalOptions -join ', ')"
        }

        foreach ($nextRoute in @(Get-WorkflowStringArray $skillContract.next_routes)) {
            Add-Check -Name "$skillName next route is known: $nextRoute" -Ok ($expectedSkillNames -contains $nextRoute) -Reason "$skillName has unknown next route: $nextRoute"
        }
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    Complete -Ok ($failed.Count -eq 0) -Reason $(if ($failed.Count -eq 0) { "workflow contract passed" } else { "workflow contract failed" })
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    Complete -Ok $false -Reason $_.Exception.Message
}
