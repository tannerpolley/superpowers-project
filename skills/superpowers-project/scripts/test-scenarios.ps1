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
        foreach ($needle in @('project-context','project-brainstorm','project-writing-plan','plan-to-issue','resolve-issue-with-goal','project-doctor','superpowers:brainstorming','superpowers:writing-plans','superpowers:executing-plans','request_user_input','docs/superpowers','/goal')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing router contract: $needle"
        }
        Add-Result -Name "router contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "router contract present" -Ok $false -Reason $_.Exception.Message }

    try {
        Assert-Contains -Text $metadata -Needle 'superpowers-project' -Reason "metadata missing skill name"
        Assert-Contains -Text $metadata -Needle 'docs/superpowers' -Reason "metadata missing artifact root"
        Add-Result -Name "metadata present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "metadata present" -Ok $false -Reason $_.Exception.Message }

    $failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}
