[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Name, [bool]$Ok, [string]$Reason) $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason }) }
function Assert-Contains { param([string]$Text, [string]$Needle, [string]$Reason) if (-not $Text.Contains($Needle)) { throw $Reason } }

try {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $metadataFile -Raw

    try {
        foreach ($needle in @('docs/superpowers/PROJECT_CONTEXT.md','docs/superpowers/milestones','request_user_input','Project context shape','Milestone page shape','GitHub tracker config','/goal','Superpowers Project')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing project-context contract: $needle"
        }
        Add-Result -Name "project context contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "project context contract present" -Ok $false -Reason $_.Exception.Message }

    try {
        Assert-Contains -Text $metadata -Needle 'project-context' -Reason "metadata missing skill name"
        Assert-Contains -Text $metadata -Needle 'docs/superpowers/PROJECT_CONTEXT.md' -Reason "metadata missing project context path"
        foreach ($needle in @('summarize','project_context_next_step','Project Brainstorm','Project Plan','Project Issue','Project Doctor','Stop','start the selected next skill')) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing continuation route: $needle"
        }
        Add-Result -Name "metadata present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "metadata present" -Ok $false -Reason $_.Exception.Message }

    try {
        foreach ($needle in @(
            '## Native Continuation Gate',
            'summarize',
            'Review First',
            'stop',
            'request_user_input',
            'start the selected next skill',
            'project_context_next_step',
            'Project Brainstorm',
            'Project Plan',
            'Project Issue',
            'Project Doctor',
            'Stop'
        )) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing continuation gate text: $needle"
        }
        Add-Result -Name "native continuation gate is present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "native continuation gate is present" -Ok $false -Reason $_.Exception.Message }

    $failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
