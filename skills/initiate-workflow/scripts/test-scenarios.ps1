[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
$repoRoot = Split-Path (Split-Path $skillRoot -Parent) -Parent
$readmeFile = Join-Path $repoRoot "README.md"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Name, [bool]$Ok, [string]$Reason) $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason }) }
function Assert-Contains { param([string]$Text, [string]$Needle, [string]$Reason) if (-not $Text.Contains($Needle)) { throw $Reason } }
function Assert-NotContains { param([string]$Text, [string]$Needle, [string]$Reason) if ($Text.Contains($Needle)) { throw $Reason } }

try {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $metadataFile -Raw

    try {
        foreach ($needle in @('setup','orchestrate-issues','brainstorm-spec','write-plan','create-issues','resolve-issue','merge-changes','audit-project','align-project','superpowers:brainstorming','superpowers:writing-plans','superpowers:executing-plans','request_user_input','docs/superpowers','/goal','Continuation Routing','project_issue_resolution_route','project_auto_mode_authorization','Bounded Auto Merge','Auto Mode authorization ledger','the plugin-provided Auto Mode validator','<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1','stop outside policy','artifact review gate','machine-readable artifacts','broader project context','recommended next route','project_workflow_mode','Manual Mode','Looping Mode','workflow mode ledger','scripts/validate-workflow-mode-ledger.ps1','one-route autonomy','bounded repeated maintenance autonomy')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router contract: $needle"
        }
        foreach ($needle in @('## Native Continuation Gate','artifact review gate','Review First','stop','start the selected next skill','selected native answers','executable routing','what the agent thinks those results mean','machine-readable artifacts')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router continuation contract: $needle"
        }
        Add-Result -Name "router contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "router contract present" -Ok $false -Reason $_.Exception.Message }

    try {
        Assert-Contains -Text $metadata -Needle 'workflow' -Reason "metadata missing skill name"
        Assert-Contains -Text $metadata -Needle 'docs/superpowers' -Reason "metadata missing artifact root"
        foreach ($needle in @('artifact review gate','what the agent thinks those results mean','machine-readable artifacts','broader project context','recommended next route','selected native answers','executable routing','start selected continuation routes','setup','orchestrate-issues','project_issue_resolution_route','project_auto_mode_authorization','Bounded Auto Merge','Auto Mode authorization ledger','<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1','project_workflow_mode','Manual Mode','Looping Mode','workflow mode ledger','scripts/validate-workflow-mode-ledger.ps1','one-route autonomy','bounded repeated maintenance autonomy')) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing router continuation contract: $needle"
        }
        Add-Result -Name "metadata present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "metadata present" -Ok $false -Reason $_.Exception.Message }

    try {
        foreach ($needle in @(
            "Selecting `Auto Mode` at `project_workflow_mode` is the Auto Mode invocation",
            "Resolve the Auto Mode validator from the loaded Superpowers Project plugin root",
            "<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1"
        )) {
            Assert-Contains -Text $skill -Needle $needle -Reason "router missing startup Auto Mode ownership text: $needle"
        }
        foreach ($needle in @(
            "Selecting Auto Mode at project_workflow_mode is the Auto Mode invocation",
            "loaded Superpowers Project plugin root",
            "<Superpowers Project plugin root>\scripts\validate-auto-mode-authorization.ps1"
        )) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing startup Auto Mode ownership text: $needle"
        }
        foreach ($forbidden in @(
            'After `$superpowers-project:brainstorm-spec` saves a spec',
            '-File .\scripts\validate-auto-mode-authorization.ps1'
        )) {
            Assert-NotContains -Text $skill -Needle $forbidden -Reason "router must not use old Auto Mode route/path: $forbidden"
            Assert-NotContains -Text $metadata -Needle $forbidden -Reason "metadata must not use old Auto Mode route/path: $forbidden"
        }
        Add-Result -Name "startup Auto Mode ownership" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "startup Auto Mode ownership" -Ok $false -Reason $_.Exception.Message }

    try {
        if (-not (Test-Path -LiteralPath $readmeFile -PathType Leaf)) { throw "missing README.md" }
        $readme = Get-Content -LiteralPath $readmeFile -Raw
        foreach ($needle in @('implement-plan','approved plan without a GitHub issue','development branch','issue-backed','non-trivial')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router implement-plan contract: $needle"
            Assert-Contains -Text $metadata -Needle $needle -Reason "missing metadata implement-plan contract: $needle"
            Assert-Contains -Text $readme -Needle $needle -Reason "missing README implement-plan contract: $needle"
        }
        foreach ($removed in @('Quick Apply','small-work escape hatch','project_quick_apply_approval','validate-quick-apply.ps1','Apply on Main','Use Issue Flow')) {
            Assert-NotContains -Text $skill -Needle $removed -Reason "router must not advertise removed local-main path: $removed"
            Assert-NotContains -Text $metadata -Needle $removed -Reason "metadata must not advertise removed local-main path: $removed"
            Assert-NotContains -Text $readme -Needle $removed -Reason "README must not advertise removed local-main path: $removed"
        }
        Add-Result -Name "implement-plan router contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "implement-plan router contract present" -Ok $false -Reason $_.Exception.Message }

    
    try {
        foreach ($needle in @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing native continuation policy in SKILL.md: $needle"
            Assert-Contains -Text $metadata -Needle $needle -Reason "missing native continuation policy in metadata: $needle"
        }

        $questionIds = [regex]::Matches($skill, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $skill.Length }
            $block = $skill.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: terminal option: break the continuation loop.')) { throw "nested question $questionId must not repeat stale terminal label" }
        }
        Assert-NotContains -Text $metadata -Needle "Right terminal label" -Reason "metadata must not use old Right terminal label wording"
        Add-Result -Name "native continuation policy avoids nested stop routes" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "native continuation policy avoids nested stop routes" -Ok $false -Reason $_.Exception.Message }
$failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
