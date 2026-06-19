[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$SetupLedgerPath,
    [string]$PrNumber,
    [string]$PrJson,
    [string]$PrFixturePath,
    [string]$IssueNumber,
    [string]$IssueJson,
    [string]$IssueFixturePath,
    [string[]]$VerificationCommands = @(),
    [string[]]$ChangedFilesCovered = @(),
    [string]$ContractReviewJson,
    [string]$ContractReviewPath,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")
$phase = "collect-premerge-ledger"

function Write-CollectorResult {
    param([bool]$Ok, [string]$Reason, [object]$Ledger = $null, [string]$LedgerPath = $null, [object]$Pr = $null, [object]$Issue = $null)
    [ordered]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        ledger = $Ledger
        ledger_json = if ($null -eq $Ledger) { $null } else { $Ledger | ConvertTo-Json -Depth 32 -Compress }
        ledger_path = $LedgerPath
        pr = $Pr
        pr_json = if ($null -eq $Pr) { $null } else { $Pr | ConvertTo-Json -Depth 32 -Compress }
        issue = $Issue
        issue_json = if ($null -eq $Issue) { $null } else { $Issue | ConvertTo-Json -Depth 32 -Compress }
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function New-OutputPath {
    param([string]$OutputDir)
    $targetDir = $OutputDir
    if ([string]::IsNullOrWhiteSpace($targetDir)) {
        $targetDir = Join-Path ([IO.Path]::GetTempPath()) ("merge-changes-premerge-" + [guid]::NewGuid().ToString("N"))
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Join-Path $targetDir "premerge-ledger.json"
}

function Invoke-GhJson {
    param([string[]]$Arguments)
    $ghCommand = "gh"
    $windowsGh = "C:\Program Files\GitHub CLI\gh.exe"
    if (-not (Get-Command $ghCommand -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $windowsGh -PathType Leaf)) {
        $ghCommand = $windowsGh
    }
    $output = & $ghCommand @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments -join ' ') failed: $($output | Out-String)" }
    ($output | Out-String).Trim() | ConvertFrom-Json
}

function Get-PrEvidence {
    if (-not [string]::IsNullOrWhiteSpace($PrJson) -or -not [string]::IsNullOrWhiteSpace($PrFixturePath)) {
        return Read-JsonInput -Json $PrJson -Path $PrFixturePath -Name "PR evidence"
    }
    if ([string]::IsNullOrWhiteSpace($PrNumber)) { throw "PrNumber or PrJson is required" }
    $raw = Invoke-GhJson -Arguments @("pr", "view", $PrNumber, "--json", "number,url,state,body,closingIssuesReferences,files,statusCheckRollup")
    [ordered]@{
        url = [string]$raw.url
        state = [string]$raw.state
        body = [string]$raw.body
        closingIssuesReferences = @($raw.closingIssuesReferences)
        requiredChecks = @($raw.statusCheckRollup)
        files = @($raw.files)
    }
}

function Get-IssueEvidence {
    if (-not [string]::IsNullOrWhiteSpace($IssueJson) -or -not [string]::IsNullOrWhiteSpace($IssueFixturePath)) {
        return Read-JsonInput -Json $IssueJson -Path $IssueFixturePath -Name "issue evidence"
    }
    if ([string]::IsNullOrWhiteSpace($IssueNumber)) { throw "IssueNumber or IssueJson is required" }
    Invoke-GhJson -Arguments @("issue", "view", $IssueNumber, "--json", "number,url,state,body,title")
}

function Expand-ListValues {
    param($Value)
    @(Get-StringArray $Value | ForEach-Object {
        [string]$_ -split ','
    } | ForEach-Object {
        ([string]$_).Trim()
    } | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    })
}

try {
    [void](Resolve-RepoRoot -RepoRoot $RepoRoot)
    $setup = Read-JsonInput -Path $SetupLedgerPath -Name "setup ledger"
    $pr = Get-PrEvidence
    $issue = Get-IssueEvidence
    $contractReview = Read-JsonInput -Json $ContractReviewJson -Path $ContractReviewPath -Name "contract review"
    Assert-ContractReviewProof -Proof $contractReview
    $covered = Expand-ListValues $ChangedFilesCovered
    if ($covered.Count -eq 0) {
        $covered = @($pr.files | ForEach-Object { Normalize-RepoPath ([string]$_.path) })
    }
    $proof = Get-StringArray $VerificationCommands
    $ledger = [ordered]@{
        required_checks_policy = if (Test-Property -Object $setup -Name "required_checks_policy") { [string]$setup.required_checks_policy } else { "require-existing" }
        required_checks = @($pr.requiredChecks | ForEach-Object { if (Test-Property -Object $_ -Name "name") { [string]$_.name } } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        optional_checks = @()
        acceptance_criteria_closeout_proof = $true
        changed_files_covered = @($covered | ForEach-Object { Normalize-RepoPath $_ })
        verification_exemptions = @()
        proof_commands = $proof
        contract_review = $contractReview
    }
    if ($ledger.proof_commands.Count -eq 0) { throw "VerificationCommands is required" }
    $ledgerPath = New-OutputPath -OutputDir $OutputDir
    $ledger | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
    Write-CollectorResult -Ok $true -Reason "premerge ledger collected" -Ledger $ledger -LedgerPath $ledgerPath -Pr $pr -Issue $issue
} catch {
    Write-CollectorResult -Ok $false -Reason $_.Exception.Message
}
