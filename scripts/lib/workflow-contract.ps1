$ErrorActionPreference = "Stop"

function Resolve-WorkflowContractPython {
    $candidates = @(
        @{ command = "py"; prefix = @("-3.12"); label = "py -3.12" },
        @{ command = "python"; prefix = @(); label = "python" }
    )
    foreach ($candidate in $candidates) {
        try {
            & $candidate.command @($candidate.prefix) -c "import yaml, json" 2>$null
            if ($LASTEXITCODE -eq 0) { return $candidate }
        } catch {
            continue
        }
    }
    throw "no Python interpreter with PyYAML found; expected py -3.12 or python to import yaml"
}

function Read-WorkflowContract {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "workflow contract file is missing: $Path"
    }

    $python = Resolve-WorkflowContractPython
    $script = @"
import json
import sys
import yaml

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

print(json.dumps(data))
"@
    $raw = & $python.command @($python.prefix) -c $script $Path
    if ($LASTEXITCODE -ne 0) { throw "could not parse workflow contract: $Path" }
    ($raw | Out-String).Trim() | ConvertFrom-Json
}

function Get-WorkflowContractQuestionIds {
    param([object]$SkillContract)

    if ($null -eq $SkillContract -or $null -eq $SkillContract.question_ids) { return @() }
    @($SkillContract.question_ids | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Get-WorkflowSkillQuestionIds {
    param([Parameter(Mandatory = $true)][string]$SkillPath)

    $text = Get-Content -LiteralPath $SkillPath -Raw
    @([regex]::Matches($text, 'Question id:\s*`([^`]+)`') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}

function Get-WorkflowSkillGates {
    param([Parameter(Mandatory = $true)][string]$SkillPath)

    $lines = @(Get-Content -LiteralPath $SkillPath)
    $gates = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $questionMatch = [regex]::Match([string]$lines[$index], 'Question id:\s*`([^`]+)`')
        if (-not $questionMatch.Success) { continue }

        $questionId = $questionMatch.Groups[1].Value
        $prompt = ""
        $options = [System.Collections.Generic.List[string]]::new()
        $optionsStarted = $false
        for ($cursor = $index + 1; $cursor -lt $lines.Count; $cursor++) {
            $line = [string]$lines[$cursor]
            if ($line -match '^\s*Question id:\s*`') { break }
            if ($line -match '^\s{0,3}##\s+' -and $cursor -gt $index + 1) { break }
            if ($line -match '^\s*Prompt:\s*`([^`]+)`') {
                $prompt = $Matches[1]
                continue
            }
            if ($line -match '^\s*Options:\s*$') {
                $optionsStarted = $true
                continue
            }
            if (-not $optionsStarted) { continue }
            if ([string]::IsNullOrWhiteSpace($line)) {
                if ($options.Count -gt 0) { break }
                continue
            }
            if ($line -match '^\s*-\s+`([^`]+)`\s*:') {
                $options.Add($Matches[1]) | Out-Null
                continue
            }
            if ($line -match '^\s*-\s+([^:`]+?)\s*:') {
                $options.Add($Matches[1].Trim()) | Out-Null
                continue
            }
            if ($options.Count -gt 0 -and $line -notmatch '^\s{2,}\S') { break }
        }

        $gates.Add([pscustomobject]@{
            question_id = $questionId
            prompt = $prompt
            options = @($options)
        }) | Out-Null
    }
    @($gates)
}

function Get-WorkflowStringArray {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-WorkflowContractGates {
    param([object]$SkillContract)

    if ($null -eq $SkillContract -or $null -eq $SkillContract.gates) { return @() }
    @($SkillContract.gates | Where-Object { $null -ne $_ })
}

function Get-WorkflowContractOptionLabels {
    param([object]$Gate)

    if ($null -eq $Gate -or $null -eq $Gate.options) { return @() }
    @($Gate.options | ForEach-Object {
        if ($null -eq $_) { return }
        $label = if ($_.PSObject.Properties.Name -contains "label") { $_.label } else { $_ }
        if ($label -is [bool]) {
            if ($label) { "Yes" } else { "No" }
        } else {
            [string]$label
        }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-WorkflowNativeIdentifiers {
    param([Parameter(Mandatory = $true)][string]$SkillPath)

    $text = Get-Content -LiteralPath $SkillPath -Raw
    @([regex]::Matches($text, '\b(?:project|implement_plan)_[a-z0-9_]+\b') |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique)
}
