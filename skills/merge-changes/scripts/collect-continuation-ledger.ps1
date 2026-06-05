[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [Parameter(Mandatory = $true)][string]$QuestionId,
    [Parameter(Mandatory = $true)][string]$Prompt,
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$SelectedOptionId,
    [string]$SelectedOptionLabel,
    [Parameter(Mandatory = $true)][string]$RecommendedOptionId,
    [string]$RecommendedOptionLabel,
    [Parameter(Mandatory = $true)][string]$TerminalState,
    [Parameter(Mandatory = $true)][string[]]$OptionIds,
    [string]$NextSkill,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "collect-continuation-ledger"

function Write-CollectorResult {
    param([bool]$Ok, [string]$Reason, [object]$Ledger = $null, [string]$LedgerPath = $null)
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        ledger = $Ledger
        ledger_json = if ($null -eq $Ledger) { $null } else { $Ledger | ConvertTo-Json -Depth 32 -Compress }
        ledger_path = $LedgerPath
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function New-OutputPath {
    param([string]$OutputDir)
    $targetDir = $OutputDir
    if ([string]::IsNullOrWhiteSpace($targetDir)) {
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("merge-changes-continuation-" + [guid]::NewGuid().ToString("N"))
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Join-Path $targetDir "continuation-ledger.json"
}

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $normalizedOptionIds = @((($OptionIds -join ",") -split '\s*,\s*') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $decision = [pscustomobject]([ordered]@{
        skill = "merge-changes"
        question_id = $QuestionId
        prompt = $Prompt
        source = $Source
        selected_option_id = $SelectedOptionId
        selected_option_label = if ([string]::IsNullOrWhiteSpace($SelectedOptionLabel)) { $SelectedOptionId } else { $SelectedOptionLabel }
        recommended_option_id = $RecommendedOptionId
        recommended_option_label = if ([string]::IsNullOrWhiteSpace($RecommendedOptionLabel)) { $RecommendedOptionId } else { $RecommendedOptionLabel }
        option_ids = $normalizedOptionIds
        terminal_state = $TerminalState
        next_skill = if ([string]::IsNullOrWhiteSpace($NextSkill)) { $null } else { $NextSkill }
    })
    Assert-MergeContinuationDecision -Decision $decision
    $ledgerPath = New-OutputPath -OutputDir $OutputDir
    $decision | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
    Write-CollectorResult -Ok $true -Reason "continuation ledger collected" -Ledger $decision -LedgerPath $ledgerPath
} catch {
    Write-CollectorResult -Ok $false -Reason $_.Exception.Message
}
