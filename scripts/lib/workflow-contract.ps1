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

function Get-WorkflowStringArray {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
