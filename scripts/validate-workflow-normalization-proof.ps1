[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReceiptPath = "docs/superpowers/milestones/M1-workflow-normalization-validation-receipt.md"
)

$ErrorActionPreference = "Stop"
$phase = "workflow-normalization-proof"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Resolve-RepoPath {
    param([string]$Root, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "path is required" }
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-RelativeRepoPath {
    param([string]$Root, [string]$Path)
    ([IO.Path]::GetRelativePath($Root, $Path) -replace '\\', '/')
}

function Test-ContainsLiteral {
    param([string]$Text, [string]$Needle)
    $Text.Contains($Needle)
}

function Add-ContainsCheck {
    param([string]$Name, [string]$Text, [string]$Needle)
    Add-Check -Name $Name -Ok (Test-ContainsLiteral -Text $Text -Needle $Needle) -Reason "receipt missing $Needle"
}

function Add-CommandReceiptCheck {
    param([string]$Text, [string]$Command)
    $lines = @($Text -split "`r?`n" | Where-Object { $_.Contains($Command) })
    $hasPass = @($lines | Where-Object { $_ -match '\|\s*pass\s*\|' }).Count -gt 0
    Add-Check -Name "command receipt passes: $Command" -Ok ($lines.Count -gt 0 -and $hasPass) -Reason "command receipt missing pass result: $Command"
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $receiptFullPath = Resolve-RepoPath -Root $root -Path $ReceiptPath
    $receiptRelativePath = Get-RelativeRepoPath -Root $root -Path $receiptFullPath
    if (-not (Test-Path -LiteralPath $receiptFullPath -PathType Leaf)) {
        throw "validation receipt is missing: $receiptRelativePath"
    }
    $receiptText = Get-Content -LiteralPath $receiptFullPath -Raw

    foreach ($section in @(
        "# Workflow Normalization Validation Receipt",
        "## Scope",
        "## Project Roadmap Proof",
        "## Command Receipts",
        "## Tracker And Align Proof",
        "## Milestone Linkage",
        "## Clean State Proof"
    )) {
        Add-ContainsCheck -Name "receipt contains section $section" -Text $receiptText -Needle $section
    }

    foreach ($command in @(
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-tracker-roadmap-proof.ps1 -RepoRoot . -IssueNumber 72 -ForbiddenIssueLabel status:ready -RequiredIssueMilestone "M1 - Source Of Truth"',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .',
        'git status --short --branch'
    )) {
        Add-CommandReceiptCheck -Text $receiptText -Command $command
    }

    $roadmapPath = Join-Path $root "docs\agents\project-roadmap.json"
    if (-not (Test-Path -LiteralPath $roadmapPath -PathType Leaf)) {
        throw "project roadmap config is missing: docs/agents/project-roadmap.json"
    }
    $roadmap = Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json
    foreach ($value in @(
        [string]$roadmap.repository,
        [string]$roadmap.milestone_root
    )) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            Add-Check -Name "roadmap scalar is populated" -Ok $false -Reason "project-roadmap.json has an empty required value"
        } else {
            Add-ContainsCheck -Name "receipt includes roadmap value $value" -Text $receiptText -Needle $value
        }
    }
    foreach ($collectionName in @("issue_types", "triage_states", "labels")) {
        foreach ($value in @($roadmap.$collectionName | ForEach-Object { [string]$_ })) {
            Add-ContainsCheck -Name "receipt includes roadmap $collectionName value $value" -Text $receiptText -Needle $value
        }
    }

    foreach ($milestonePage in @(
        "docs/superpowers/milestones/M0-governance.md",
        "docs/superpowers/milestones/M1-source-of-truth.md"
    )) {
        $pagePath = Resolve-RepoPath -Root $root -Path $milestonePage
        if (-not (Test-Path -LiteralPath $pagePath -PathType Leaf)) {
            Add-Check -Name "$milestonePage exists" -Ok $false -Reason "milestone page is missing: $milestonePage"
            continue
        }
        $pageText = Get-Content -LiteralPath $pagePath -Raw
        Add-Check -Name "$milestonePage links receipt" -Ok ($pageText.Contains($receiptRelativePath)) -Reason "$milestonePage does not link $receiptRelativePath"
        Add-ContainsCheck -Name "receipt names $milestonePage" -Text $receiptText -Needle $milestonePage
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{
        ok = ($failed.Count -eq 0)
        phase = $phase
        receipt_path = $receiptRelativePath
        checks = $checks
    } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{
        ok = $false
        phase = $phase
        receipt_path = $ReceiptPath
        reason = $_.Exception.Message
        checks = $checks
    } | ConvertTo-Json -Depth 8
    exit 1
}
