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

try {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $metadataFile -Raw

    try {
        foreach ($needle in @('project-setup','project-orchestrate','project-brainstorm','project-plan','project-issue','project-resolve','project-merge','project-doctor','superpowers:brainstorming','superpowers:writing-plans','superpowers:executing-plans','request_user_input','docs/superpowers','/goal','Continuation Routing','project_issue_resolution_route')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router contract: $needle"
        }
        foreach ($needle in @('## Native Continuation Gate','summarize','Review First','stop','start the selected next skill','selected native answers','executable routing')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router continuation contract: $needle"
        }
        Add-Result -Name "router contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "router contract present" -Ok $false -Reason $_.Exception.Message }

    try {
        Assert-Contains -Text $metadata -Needle 'superpowers-project' -Reason "metadata missing skill name"
        Assert-Contains -Text $metadata -Needle 'docs/superpowers' -Reason "metadata missing artifact root"
        foreach ($needle in @('summarize','selected native answers','executable routing','start selected continuation routes','project-setup','project-orchestrate','project_issue_resolution_route')) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing router continuation contract: $needle"
        }
        Add-Result -Name "metadata present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "metadata present" -Ok $false -Reason $_.Exception.Message }

    try {
        if (-not (Test-Path -LiteralPath $readmeFile -PathType Leaf)) { throw "missing README.md" }
        $readme = Get-Content -LiteralPath $readmeFile -Raw
        foreach ($needle in @('Quick Apply','small-work escape hatch','issue-backed','non-trivial','project_quick_apply_approval','validate-quick-apply.ps1')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router Quick Apply contract: $needle"
            Assert-Contains -Text $metadata -Needle $needle -Reason "missing metadata Quick Apply contract: $needle"
            Assert-Contains -Text $readme -Needle $needle -Reason "missing README Quick Apply contract: $needle"
        }
        Add-Result -Name "quick apply router contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "quick apply router contract present" -Ok $false -Reason $_.Exception.Message }

    $failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
