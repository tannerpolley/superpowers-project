[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$ContractPath = "docs/superpowers/workflow-contract.yml",
    [ValidateRange(500, 5000)][int]$MaxPromptCharacters = 2200
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\workflow-contract.ps1")

$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

function Get-RelativePath {
    param([string]$Root, [string]$Path)
    [IO.Path]::GetRelativePath($Root, $Path) -replace "\\", "/"
}

function Read-MetadataPrompt {
    param([Parameter(Mandatory = $true)][string]$Path)
    $python = Resolve-WorkflowContractPython
    $script = @"
import json
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

interface = data.get("interface") or {}
prompt = interface.get("default_prompt", data.get("default_prompt", "")) or ""
print(json.dumps({"default_prompt": str(prompt)}))
"@
    $raw = & $python.command @($python.prefix) -c $script $Path
    if ($LASTEXITCODE -ne 0) { throw "could not parse metadata YAML: $Path" }
    ($raw | Out-String).Trim() | ConvertFrom-Json
}

function Get-RouteSummaryWindow {
    param([string]$Prompt, [string]$QuestionId)
    $index = $Prompt.IndexOf($QuestionId, [StringComparison]::Ordinal)
    if ($index -lt 0) { return "" }
    $remaining = $Prompt.Substring($index)
    $lineBreak = $remaining.IndexOf("`n", [StringComparison]::Ordinal)
    $period = $remaining.IndexOf(".", [StringComparison]::Ordinal)
    $candidates = @($lineBreak, $period) | Where-Object { $_ -ge 0 }
    $length = if ($candidates.Count -gt 0) { (@($candidates) | Measure-Object -Minimum).Minimum + 1 } else { [Math]::Min(320, $remaining.Length) }
    $remaining.Substring(0, [Math]::Min($length, $remaining.Length))
}

function Test-ContainsWord {
    param([string]$Text, [string]$Needle)
    $Text.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $contractFullPath = if ([IO.Path]::IsPathRooted($ContractPath)) { $ContractPath } else { Join-Path $root $ContractPath }
    $contract = Read-WorkflowContract -Path $contractFullPath
    $skills = $contract.workflow_skills.PSObject.Properties | Sort-Object Name
    $forbiddenGlobalPolicy = @(
        "Strict artifact display is mandatory",
        "Do not merely say something changed",
        "The agent must not get out of the loop by itself",
        "ending a turn after a governed workflow action is invalid",
        "Nested Yes-route menus must not include terminal options",
        "Nested Revisit-route menus must not include terminal options",
        "fresh confirmation question with separate built-in labels",
        "top-level closeout question must use exactly three trajectory options",
        "After every completed action, ask the next native continuation or permission question"
    )
    $terminalLabels = @("Stop", "Done", "Yes", "Revisit", "Hold")

    foreach ($skill in $skills) {
        $skillName = [string]$skill.Name
        $relativeMetadataPath = "skills/$skillName/agents/openai.yaml"
        $metadataPath = Join-Path $root ($relativeMetadataPath -replace "/", "\")
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            Add-Check "$relativeMetadataPath exists" $false "missing metadata file"
            continue
        }

        $prompt = [string](Read-MetadataPrompt -Path $metadataPath).default_prompt
        Add-Check "$relativeMetadataPath default_prompt exists" (-not [string]::IsNullOrWhiteSpace($prompt)) "$relativeMetadataPath default_prompt is empty"
        Add-Check "$relativeMetadataPath prompt is compact" ($prompt.Length -le $MaxPromptCharacters) "$relativeMetadataPath default_prompt is $($prompt.Length) characters; maximum is $MaxPromptCharacters"
        Add-Check "$relativeMetadataPath points to SKILL.md" (Test-ContainsWord -Text $prompt -Needle "SKILL.md") "$relativeMetadataPath must point to SKILL.md for exact behavior"
        Add-Check "$relativeMetadataPath points to workflow contract" (Test-ContainsWord -Text $prompt -Needle "docs/superpowers/workflow-contract.yml") "$relativeMetadataPath must point to docs/superpowers/workflow-contract.yml"

        foreach ($forbidden in $forbiddenGlobalPolicy) {
            Add-Check "$relativeMetadataPath omits duplicated global policy: $forbidden" (-not (Test-ContainsWord -Text $prompt -Needle $forbidden)) "$relativeMetadataPath contains duplicated global policy instead of a compact reference: $forbidden"
        }

        foreach ($route in @($skill.Value.nested_routes)) {
            $questionId = [string]$route.question_id
            if ([string]::IsNullOrWhiteSpace($questionId) -or -not (Test-ContainsWord -Text $prompt -Needle $questionId)) { continue }
            $window = Get-RouteSummaryWindow -Prompt $prompt -QuestionId $questionId
            $allowed = @(Get-WorkflowStringArray -Value $route.options)
            foreach ($option in $allowed) {
                Add-Check "$relativeMetadataPath $questionId contains $option" (Test-ContainsWord -Text $window -Needle $option) "$relativeMetadataPath advertises $questionId but omits contract option '$option'"
            }
            foreach ($label in $terminalLabels) {
                if ($allowed -contains $label) { continue }
                Add-Check "$relativeMetadataPath $questionId omits unsupported $label" (-not (Test-ContainsWord -Text $window -Needle $label)) "$relativeMetadataPath advertises unsupported option '$label' for $questionId; contract options are $($allowed -join ', ')"
            }
        }
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{
        ok = ($failed.Count -eq 0)
        phase = "skill-metadata-contract"
        contract_path = (Get-RelativePath -Root $root -Path $contractFullPath)
        max_prompt_characters = $MaxPromptCharacters
        checks = $checks
    } | ConvertTo-Json -Depth 10
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check "fatal" $false $_.Exception.Message
    [pscustomobject]@{
        ok = $false
        phase = "skill-metadata-contract"
        reason = $_.Exception.Message
        checks = $checks
    } | ConvertTo-Json -Depth 10
    exit 1
}
