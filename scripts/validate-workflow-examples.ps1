[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$Path = "docs/superpowers/examples/workflow-golden-paths.md",
    [string]$SubIssuesPath = "docs/superpowers/examples/sub-issues-workflow-examples.md",
    [string]$ContractPath = "docs/superpowers/workflow-contract.yml"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\workflow-contract.ps1")

$phase = "workflow-examples"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Complete {
    param([bool]$Ok, [string]$Reason = "", [int]$ExampleCount = 0)
    $result = [ordered]@{ ok = $Ok; phase = $phase; example_count = $ExampleCount; checks = $checks }
    if (-not [string]::IsNullOrWhiteSpace($Reason)) { $result.reason = $Reason }
    [pscustomobject]$result | ConvertTo-Json -Depth 12
    if ($Ok) { exit 0 }
    exit 1
}

function Resolve-InputPath {
    param([string]$Root, [string]$InputPath)
    if ([IO.Path]::IsPathRooted($InputPath)) { return [IO.Path]::GetFullPath($InputPath) }
    [IO.Path]::GetFullPath((Join-Path $Root $InputPath))
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $pattern = "(?im)^\s*\*\*$([regex]::Escape($Name)):\*\*\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    ""
}

function Split-List {
    param([string]$Value, [string]$SeparatorPattern)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    @($Value -split $SeparatorPattern | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Read-WorkflowExamples {
    param([string]$ExamplePath)
    $text = Get-Content -LiteralPath $ExamplePath -Raw
    $matches = [regex]::Matches($text, '(?ms)^##\s+(?<title>.+?)\r?\n(?<body>.*?)(?=^##\s+|\z)')
    @($matches | ForEach-Object {
        $body = $_.Groups["body"].Value
        [pscustomobject]@{
            title = $_.Groups["title"].Value.Trim()
            id = Get-FieldValue -Text $body -Name "Example ID"
            route_sequence = Split-List -Value (Get-FieldValue -Text $body -Name "Route sequence") -SeparatorPattern '\s*->\s*'
            question_ids = Split-List -Value (Get-FieldValue -Text $body -Name "Question IDs") -SeparatorPattern '\s*,\s*'
            artifacts = Split-List -Value (Get-FieldValue -Text $body -Name "Artifacts") -SeparatorPattern '\s*;\s*'
            validators = Split-List -Value (Get-FieldValue -Text $body -Name "Validators") -SeparatorPattern '\s*;\s*'
            stop_point = Get-FieldValue -Text $body -Name "Stop point"
        }
    })
}

function Test-GhIssueCreateTitlesAreClean {
    param([string]$Text)
    $matches = @([regex]::Matches($Text, 'gh issue create\s+--title\s+"(?<title>[^"]+)"'))
    if ($matches.Count -eq 0) { return $false }
    foreach ($match in $matches) {
        $title = $match.Groups["title"].Value
        if ($title -match '(?i)^\s*M\d+\b') { return $false }
        if ($title -match '(?i)\[[^\]]*M\d+[^\]]*\]') { return $false }
        if ($title -match '(?i)\bsub-?milestone\s+\d+\b') { return $false }
        if ($title -match '^\s*\d+(?:\.\d+)+\s+') { return $false }
    }
    $true
}

function Test-SubIssueExamples {
    param([string]$Root, [string]$InputPath)
    $subIssuePath = Resolve-InputPath -Root $Root -InputPath $InputPath
    if (-not (Test-Path -LiteralPath $subIssuePath -PathType Leaf)) {
        Add-Check -Name "sub-issue examples file exists" -Ok $false -Reason "sub-issue examples file is missing: $InputPath"
        return
    }
    $text = Get-Content -LiteralPath $subIssuePath -Raw
    foreach ($needle in @(
        "## Flat Issue",
        "## Issue Set",
        "## Pseudo Sub-Milestone",
        "## External Hydration",
        "## Rollup Closeout",
        "## Selective Migration",
        "Sub-issues section",
        "Nested child rows",
        "Child parent link",
        "Progress count",
        "GitHub Milestone",
        "Parent Issue",
        "Parent Mirror",
        "subIssuesSummary",
        "Clean GitHub title",
        "requires_native_approval",
        "project_rollup_closeout_approval",
        "native approval"
    )) {
        Add-Check -Name "sub-issue examples contain $needle" -Ok $text.Contains($needle) -Reason "sub-issue examples missing $needle"
    }
    Add-Check -Name "sub-issue examples keep gh create titles clean" -Ok (Test-GhIssueCreateTitlesAreClean -Text $text) -Reason "gh issue create titles must not encode milestone identity"
    Add-Check -Name "sub-issue examples distinguish milestones from parent issues" -Ok ($text.Contains("does not replace the milestone")) -Reason "sub-issue examples must distinguish GitHub Milestones from parent issues"
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $examplePath = Resolve-InputPath -Root $root -InputPath $Path
    $contractFullPath = Resolve-InputPath -Root $root -InputPath $ContractPath
    if (-not (Test-Path -LiteralPath $examplePath -PathType Leaf)) { throw "workflow examples file is missing: $Path" }

    $contract = Read-WorkflowContract -Path $contractFullPath
    $routeNames = @($contract.workflow_skills.PSObject.Properties.Name | Sort-Object -Unique)
    $questionIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($routeName in $routeNames) {
        foreach ($questionId in @(Get-WorkflowContractQuestionIds -SkillContract $contract.workflow_skills.$routeName)) {
            [void]$questionIds.Add($questionId)
        }
    }

    $examples = @(Read-WorkflowExamples -ExamplePath $examplePath)
    Add-Check -Name "examples parsed" -Ok ($examples.Count -gt 0) -Reason "no workflow examples found"

    $requiredIds = @(
        "idea-to-local-merge",
        "spec-to-issues-to-merge",
        "sub-issue-hierarchy-to-parent-rollup",
        "audit-to-auto-mode-single-route",
        "looping-mode-candidate-selection"
    )
    foreach ($requiredId in $requiredIds) {
        Add-Check -Name "required example exists: $requiredId" -Ok (@($examples | Where-Object { $_.id -eq $requiredId }).Count -eq 1) -Reason "missing required example: $requiredId"
    }

    foreach ($example in $examples) {
        $label = if ([string]::IsNullOrWhiteSpace([string]$example.id)) { $example.title } else { [string]$example.id }
        Add-Check -Name "$label has Example ID" -Ok (-not [string]::IsNullOrWhiteSpace([string]$example.id)) -Reason "$label Example ID is required"
        Add-Check -Name "$label has route sequence" -Ok (@($example.route_sequence).Count -gt 0) -Reason "$label Route sequence is required"
        Add-Check -Name "$label has question ids" -Ok (@($example.question_ids).Count -gt 0) -Reason "$label Question IDs are required"
        Add-Check -Name "$label has artifacts" -Ok (@($example.artifacts).Count -gt 0) -Reason "$label Artifacts are required"
        Add-Check -Name "$label has validators" -Ok (@($example.validators).Count -gt 0) -Reason "$label Validators are required"
        Add-Check -Name "$label has Stop point" -Ok (-not [string]::IsNullOrWhiteSpace([string]$example.stop_point)) -Reason "$label Stop point is required"

        foreach ($route in @($example.route_sequence)) {
            Add-Check -Name "$label route is in workflow contract: $route" -Ok ($routeNames -contains $route) -Reason "$label route is not in workflow contract: $route"
        }
        foreach ($questionId in @($example.question_ids)) {
            Add-Check -Name "$label question id is in workflow contract: $questionId" -Ok ($questionIds.Contains($questionId)) -Reason "$label question id is not in workflow contract: $questionId"
        }
    }

    $autoExample = @($examples | Where-Object { $_.id -eq "audit-to-auto-mode-single-route" } | Select-Object -First 1)
    if ($autoExample) {
        Add-Check -Name "auto mode example uses authorization gate" -Ok (@($autoExample.question_ids) -contains "project_auto_mode_authorization") -Reason "Auto Mode example must include project_auto_mode_authorization"
        Add-Check -Name "auto mode example stops after one route" -Ok ([string]$autoExample.stop_point -match 'one route') -Reason "Auto Mode example must stop after one route"
    }

    $loopExample = @($examples | Where-Object { $_.id -eq "looping-mode-candidate-selection" } | Select-Object -First 1)
    if ($loopExample) {
        Add-Check -Name "looping mode example uses loop continuation gate" -Ok (@($loopExample.question_ids) -contains "project_loop_next_step") -Reason "Looping Mode example must include project_loop_next_step"
        Add-Check -Name "looping mode example requires budget recheck" -Ok ([string]$loopExample.stop_point -match 'budget recheck') -Reason "Looping Mode example must mention budget recheck"
        Add-Check -Name "looping mode example uses state machine validator" -Ok (@($loopExample.validators) -contains "skills/loop-controller/scripts/validate-loop-state-machine.ps1") -Reason "Looping Mode example must include validate-loop-state-machine.ps1"
        Add-Check -Name "looping mode example lists source contract" -Ok (@($loopExample.artifacts) -contains "docs/superpowers/loop-mode-contract.yml") -Reason "Looping Mode example must list docs/superpowers/loop-mode-contract.yml"
        Add-Check -Name "looping mode example stops at state-machine proof" -Ok ([string]$loopExample.stop_point -match 'state-machine proof') -Reason "Looping Mode stop point must mention state-machine proof"
    }

    $hierarchyExample = @($examples | Where-Object { $_.id -eq "sub-issue-hierarchy-to-parent-rollup" } | Select-Object -First 1)
    if ($hierarchyExample) {
        Add-Check -Name "sub-issue hierarchy example uses create hierarchy gates" -Ok ((@($hierarchyExample.question_ids) -contains "project_issue_hierarchy_mode") -and (@($hierarchyExample.question_ids) -contains "project_issue_hierarchy_publish")) -Reason "Sub-issue hierarchy example must include create-issues hierarchy gates"
        Add-Check -Name "sub-issue hierarchy example validates hierarchy and closeout" -Ok ((@($hierarchyExample.validators) -contains "skills/create-issues/scripts/validate-issue-hierarchy.ps1") -and (@($hierarchyExample.validators) -contains "skills/merge-changes/scripts/closeout.ps1")) -Reason "Sub-issue hierarchy example must include hierarchy and closeout validators"
        Add-Check -Name "sub-issue hierarchy example records parent progress" -Ok ([string]$hierarchyExample.stop_point -match 'parent progress') -Reason "Sub-issue hierarchy stop point must mention parent progress"
        Add-Check -Name "sub-issue hierarchy example blocks parent auto-close" -Ok ([string]$hierarchyExample.stop_point -match 'approval-gated') -Reason "Sub-issue hierarchy stop point must mention approval-gated parent rollup"
    }

    Test-SubIssueExamples -Root $root -InputPath $SubIssuesPath

    $failed = @($checks | Where-Object { -not $_.ok })
    Complete -Ok ($failed.Count -eq 0) -Reason $(if ($failed.Count -eq 0) { "workflow examples passed" } else { "workflow examples failed" }) -ExampleCount $examples.Count
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    Complete -Ok $false -Reason $_.Exception.Message
}
