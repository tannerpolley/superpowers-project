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

function Get-OptionLabels {
    param([object]$Gate)
    @(Get-WorkflowContractOptionLabels -Gate $Gate)
}

function Test-StringArrayEqual {
    param([string[]]$Actual, [string[]]$Expected)
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Actual.Count; $index++) {
        if ($Actual[$index] -ne $Expected[$index]) { return $false }
    }
    $true
}

function Get-AllowlistedNativeIdentifiers {
    param($Contract)
    if ($null -eq $Contract.native_identifier_allowlist) { return @{} }
    $allowlist = @{}
    foreach ($entry in @($Contract.native_identifier_allowlist)) {
        if ($null -eq $entry -or -not ($entry.PSObject.Properties.Name -contains "id")) { continue }
        $allowlist[[string]$entry.id] = [string]$entry.reason
    }
    $allowlist
}

function Get-NativeIdentifierAllowlistEntries {
    param($Contract)
    if ($null -eq $Contract.native_identifier_allowlist) { return @() }
    @($Contract.native_identifier_allowlist | Where-Object { $null -ne $_ })
}

function Test-GateTypeRules {
    param([object]$Gate)

    $questionId = [string]$Gate.question_id
    $gateType = [string]$Gate.gate_type
    $labels = @(Get-OptionLabels -Gate $Gate)
    switch ($gateType) {
        "top_level_continuation" {
            if (-not (Test-StringArrayEqual -Actual $labels -Expected @("Yes", "Revisit", "Stop"))) {
                return "top-level continuation ${questionId} must use exactly Yes, Revisit, Stop"
            }
        }
        "final_health" {
            if (-not (Test-StringArrayEqual -Actual $labels -Expected @("Done", "Revisit", "Stop"))) {
                return "final health ${questionId} must use exactly Done, Revisit, Stop"
            }
        }
        "nested_yes_route" {
            $bad = @($labels | Where-Object { $_ -in @("Stop", "Done", "Revisit") })
            if ($bad.Count -gt 0) { return "nested Yes route ${questionId} contains invalid terminal/revisit option(s): $($bad -join ', ')" }
        }
        "nested_revisit_route" {
            $bad = @($labels | Where-Object { $_ -in @("Stop", "Done", "Yes") })
            if ($bad.Count -gt 0) { return "nested Revisit route ${questionId} contains invalid terminal/progress option(s): $($bad -join ', ')" }
        }
        "approval" {
            foreach ($option in @($Gate.options)) {
                if (-not ($option.PSObject.Properties.Name -contains "approval_effect") -or [string]::IsNullOrWhiteSpace([string]$option.approval_effect)) {
                    return "approval gate ${questionId} option '$($option.label)' must declare approval_effect"
                }
            }
        }
        "permission" {
            foreach ($option in @($Gate.options)) {
                if (-not ($option.PSObject.Properties.Name -contains "permission_effect") -or [string]::IsNullOrWhiteSpace([string]$option.permission_effect)) {
                    return "permission gate ${questionId} option '$($option.label)' must declare permission_effect"
                }
            }
        }
        "topology" {
            $allowTerminal = ($Gate.PSObject.Properties.Name -contains "allow_terminal_options") -and $Gate.allow_terminal_options -eq $true
            if (-not $allowTerminal -and $labels -contains "Stop") { return "topology gate ${questionId} may include Stop only when allow_terminal_options is true" }
        }
        default {
            if ($gateType -notin @("workflow_mode", "nested_yes_route", "nested_revisit_route", "approval", "permission", "topology", "final_health", "top_level_continuation", "repair_choice", "data_selection")) {
                return "gate ${questionId} has unsupported gate_type: ${gateType}"
            }
        }
    }
    ""
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
    $nativeIdentifierAllowlist = Get-AllowlistedNativeIdentifiers -Contract $contract
    Add-Check -Name "contract file parses" -Ok $true -Reason "passed"

    foreach ($entry in @(Get-NativeIdentifierAllowlistEntries -Contract $contract)) {
        $id = if ($entry.PSObject.Properties.Name -contains "id") { [string]$entry.id } else { "" }
        $reason = if ($entry.PSObject.Properties.Name -contains "reason") { [string]$entry.reason } else { "" }
        Add-Check -Name "native identifier allowlist reason: $id" -Ok (-not [string]::IsNullOrWhiteSpace($id) -and -not [string]::IsNullOrWhiteSpace($reason)) -Reason "native_identifier_allowlist entries require id and non-empty reason"
    }

    $workflowSkillsObject = $contract.workflow_skills
    if ($null -eq $workflowSkillsObject) { Complete -Ok $false -Reason "workflow_skills is required" }
    $contractSkillNames = @($workflowSkillsObject.PSObject.Properties.Name | Sort-Object)
    $expectedSkillNames = @($WorkflowSkillNames | Sort-Object)
    $allContractQuestionIds = @($contractSkillNames | ForEach-Object {
        Get-WorkflowContractQuestionIds -SkillContract $workflowSkillsObject.$_
    } | Sort-Object -Unique)

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

        $actualGates = @(Get-WorkflowSkillGates -SkillPath $skillPath)
        $actualQuestionIds = @($actualGates | Select-Object -ExpandProperty question_id | Sort-Object -Unique)
        $contractQuestionIds = @(Get-WorkflowContractQuestionIds -SkillContract $skillContract)
        $missingQuestionIds = @($actualQuestionIds | Where-Object { $contractQuestionIds -notcontains $_ })
        $extraQuestionIds = @($contractQuestionIds | Where-Object { $actualQuestionIds -notcontains $_ })
        Add-Check -Name "$skillName contract lists skill question ids" -Ok ($missingQuestionIds.Count -eq 0) -Reason "$skillName missing question id(s): $($missingQuestionIds -join ', ')"
        Add-Check -Name "$skillName contract question ids exist in skill" -Ok ($extraQuestionIds.Count -eq 0) -Reason "$skillName contract has unknown question id(s): $($extraQuestionIds -join ', ')"

        $contractGates = @(Get-WorkflowContractGates -SkillContract $skillContract)
        Add-Check -Name "$skillName typed gates declared" -Ok ($contractGates.Count -eq $contractQuestionIds.Count) -Reason "$skillName must declare one typed gate for every question id"
        $contractGateIds = @($contractGates | ForEach-Object { [string]$_.question_id } | Sort-Object -Unique)
        $missingGateIds = @($contractQuestionIds | Where-Object { $contractGateIds -notcontains $_ })
        $extraGateIds = @($contractGateIds | Where-Object { $contractQuestionIds -notcontains $_ })
        Add-Check -Name "$skillName typed gates cover question ids" -Ok ($missingGateIds.Count -eq 0 -and $extraGateIds.Count -eq 0) -Reason "$skillName gate/question mismatch. Missing: $($missingGateIds -join ', '); extra: $($extraGateIds -join ', ')"

        $declaredIds = @($allContractQuestionIds + @($nativeIdentifierAllowlist.Keys) | Sort-Object -Unique)
        $proseIdentifiers = @(Get-WorkflowNativeIdentifiers -SkillPath $skillPath)
        $unregisteredIdentifiers = @($proseIdentifiers | Where-Object { $declaredIds -notcontains $_ })
        Add-Check -Name "$skillName native identifiers registered or allowlisted" -Ok ($unregisteredIdentifiers.Count -eq 0) -Reason "$skillName has unregistered native identifier(s): $($unregisteredIdentifiers -join ', ')"

        foreach ($contractGate in $contractGates) {
            $questionId = [string]$contractGate.question_id
            $actualGate = @($actualGates | Where-Object { [string]$_.question_id -eq $questionId } | Select-Object -First 1)
            if ($actualGate.Count -eq 0) { continue }
            $actualOptions = @($actualGate[0].options)
            $contractOptions = @(Get-OptionLabels -Gate $contractGate)
            Add-Check -Name "$skillName exact options match: $questionId" -Ok (Test-StringArrayEqual -Actual $actualOptions -Expected $contractOptions) -Reason "$skillName ${questionId} options differ. Skill: [$($actualOptions -join ', ')]; contract: [$($contractOptions -join ', ')]"
            $gateTypeViolation = Test-GateTypeRules -Gate $contractGate
            Add-Check -Name "$skillName gate type valid: $questionId" -Ok ([string]::IsNullOrWhiteSpace($gateTypeViolation)) -Reason $gateTypeViolation
        }

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
            $routeGate = @($contractGates | Where-Object { [string]$_.question_id -eq $routeQuestionId } | Select-Object -First 1)
            $routeGateType = if ($routeGate.Count -gt 0) { [string]$routeGate[0].gate_type } else { "" }
            if ($routeGateType -in @("nested_yes_route", "nested_revisit_route")) {
                $terminalOptions = @($routeOptions | Where-Object { $_ -in @("Stop", "Done") })
                Add-Check -Name "$skillName nested route excludes terminal options: $routeQuestionId" -Ok ($terminalOptions.Count -eq 0) -Reason "$skillName nested route $routeQuestionId includes terminal option(s): $($terminalOptions -join ', ')"
            }
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
