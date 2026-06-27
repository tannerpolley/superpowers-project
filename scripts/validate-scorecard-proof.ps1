[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReceiptPath = "docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md"
)

$ErrorActionPreference = "Stop"
$phase = "scorecard-proof"
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

function Add-ContainsCheck {
    param([string]$Name, [string]$Text, [string]$Needle, [string]$Reason = "")
    $failure = if ([string]::IsNullOrWhiteSpace($Reason)) { "missing $Needle" } else { $Reason }
    Add-Check -Name $Name -Ok ($Text.Contains($Needle)) -Reason $failure
}

function Get-SectionText {
    param([string]$Text, [string]$Heading)
    $pattern = "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(?<body>.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups["body"].Value }
    ""
}

function Split-MarkdownTableRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if (-not $trimmed.StartsWith("|")) { return @() }
    @($trimmed.Trim("|") -split "\|" | ForEach-Object { $_.Trim() })
}

function Get-MarkdownTableRows {
    param([string]$SectionText)
    $lines = @($SectionText -split "`r?`n" | Where-Object { $_.Trim().StartsWith("|") })
    if ($lines.Count -lt 2) { return @() }
    $header = Split-MarkdownTableRow -Line $lines[0]
    @($lines | Select-Object -Skip 2 | ForEach-Object {
        $cells = Split-MarkdownTableRow -Line $_
        if ($cells.Count -eq 0) { return }
        $row = [ordered]@{}
        for ($i = 0; $i -lt $header.Count; $i++) {
            $row[$header[$i]] = if ($i -lt $cells.Count) { $cells[$i] } else { "" }
        }
        [pscustomobject]$row
    })
}

function Get-TargetScore {
    param([string]$Target)
    $match = [regex]::Match($Target, '(?<score>\d+(?:\.\d+)?)')
    if (-not $match.Success) { return $null }
    [decimal]$match.Groups["score"].Value
}

function Add-CommandReceiptCheck {
    param([string]$Text, [string]$Command)
    $lines = @($Text -split "`r?`n" | Where-Object { $_.Contains($Command) })
    $hasPass = @($lines | Where-Object { $_ -match '\|\s*pass\s*\|' }).Count -gt 0
    Add-Check -Name "command receipt passes: $Command" -Ok ($lines.Count -gt 0 -and $hasPass) -Reason "command receipt missing pass result: $Command"
}

function Test-CanonicalGeneratedClaim {
    param([string]$Line)
    if ($Line -notmatch '(`?\.chatgpt(?:/|\\|\*\*)|`?\.superpowers(?:/|\\|\*\*))') { return $false }
    if ($Line -notmatch '(?i)\b(canonical|source[- ]of[- ]truth|source of truth)\b') { return $false }
    if ($Line -match '(?i)\b(not canonical|non-canonical|not a source|do not|don''t|cannot|can not|must not|runtime|generated|handoff|input|ephemeral|ignored|avoid|instead of|no doc calls|scan docs|references that present)\b') { return $false }
    $true
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $receiptFullPath = Resolve-RepoPath -Root $root -Path $ReceiptPath
    $receiptRelativePath = Get-RelativeRepoPath -Root $root -Path $receiptFullPath
    if (-not (Test-Path -LiteralPath $receiptFullPath -PathType Leaf)) {
        throw "scorecard receipt is missing: $receiptRelativePath"
    }

    $receiptText = Get-Content -LiteralPath $receiptFullPath -Raw
    foreach ($section in @(
        "# Score 9+ And Looping Mode Hardening Receipt",
        "## Scorecard",
        "## Command Receipts",
        "## Source Artifact Links",
        "## Looping Mode Proof",
        "## Live Sync And Tracker Proof",
        "## Project Context Roles"
    )) {
        Add-ContainsCheck -Name "receipt contains $section" -Text $receiptText -Needle $section
    }

    $requiredAreas = @(
        "Full workflow coverage",
        "Project context + issues",
        "Decision gates",
        "Grilling behavior",
        "Clear goals/outputs",
        "Predictability",
        "Friction/clutter",
        "Ship confidence"
    )
    $scoreRows = @(Get-MarkdownTableRows -SectionText (Get-SectionText -Text $receiptText -Heading "Scorecard"))
    foreach ($area in $requiredAreas) {
        $row = @($scoreRows | Where-Object { [string]$_.Area -eq $area } | Select-Object -First 1)
        Add-Check -Name "scorecard area exists: $area" -Ok ($null -ne $row -and @($row).Count -eq 1) -Reason "missing scorecard area: $area"
        if ($null -eq $row -or @($row).Count -eq 0) { continue }
        $targetScore = Get-TargetScore -Target ([string]$row.Target)
        Add-Check -Name "scorecard target is >= 9: $area" -Ok ($null -ne $targetScore -and $targetScore -ge 9) -Reason "$area target must be >= 9"
        Add-Check -Name "scorecard evidence populated: $area" -Ok (-not [string]::IsNullOrWhiteSpace([string]$row.Evidence)) -Reason "$area evidence must be populated"
        Add-Check -Name "scorecard result passes: $area" -Ok ([string]$row.Result -match '^(?i)pass$') -Reason "$area result must be pass"
    }

    foreach ($command in @(
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1 -RepoRoot .',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-metadata-contract.ps1 -RepoRoot .',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-scorecard-proof.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-scorecard-proof.ps1 -RepoRoot .',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene',
        'pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .',
        'git status --short --branch'
    )) {
        Add-CommandReceiptCheck -Text $receiptText -Command $command
    }

    foreach ($path in @(
        "docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md",
        "docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md",
        "docs/superpowers/workflow-contract.yml",
        "docs/superpowers/loop-mode-contract.yml",
        "docs/superpowers/backlog/ACTIVE.md",
        "docs/superpowers/examples/workflow-golden-paths.md",
        "docs/superpowers/examples/worker-handoff-packets.md",
        "skills/loop-controller/scripts/validate-loop-state-machine.ps1",
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/OUTCOME_WORKFLOW.md",
        "README.md"
    )) {
        Add-ContainsCheck -Name "receipt links source artifact: $path" -Text $receiptText -Needle $path
    }

    foreach ($milestonePage in @(
        "docs/superpowers/milestones/M0-governance.md",
        "docs/superpowers/milestones/M1-source-of-truth.md"
    )) {
        $pagePath = Resolve-RepoPath -Root $root -Path $milestonePage
        if (-not (Test-Path -LiteralPath $pagePath -PathType Leaf)) {
            Add-Check -Name "$milestonePage exists" -Ok $false -Reason "milestone page is missing"
            continue
        }
        $pageText = Get-Content -LiteralPath $pagePath -Raw
        Add-Check -Name "$milestonePage links scorecard receipt" -Ok ($pageText.Contains($receiptRelativePath)) -Reason "$milestonePage does not link $receiptRelativePath"
        Add-ContainsCheck -Name "receipt names $milestonePage" -Text $receiptText -Needle $milestonePage
    }

    $roleDocs = @(
        "README.md",
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/OUTCOME_WORKFLOW.md"
    )
    foreach ($doc in $roleDocs) {
        $docPath = Resolve-RepoPath -Root $root -Path $doc
        if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) {
            Add-Check -Name "$doc exists" -Ok $false -Reason "$doc is missing"
            continue
        }
        $docText = Get-Content -LiteralPath $docPath -Raw
        foreach ($needle in @(
            "docs/superpowers/workflow-contract.yml",
            "docs/superpowers/backlog/ACTIVE.md",
            "docs/superpowers/examples/workflow-golden-paths.md",
            "docs/superpowers/examples/worker-handoff-packets.md",
            "docs/superpowers/milestones/*receipt*.md",
            ".chatgpt/**",
            ".superpowers/**",
            "not canonical project docs"
        )) {
            Add-ContainsCheck -Name "$doc explains role: $needle" -Text $docText -Needle $needle -Reason "$doc must explain $needle"
        }
    }

    $scanFiles = @(
        Resolve-RepoPath -Root $root -Path "README.md"
        Resolve-RepoPath -Root $root -Path "docs"
        Resolve-RepoPath -Root $root -Path "skills"
    )
    $generatedClaimFindings = [System.Collections.Generic.List[object]]::new()
    foreach ($scanRoot in $scanFiles) {
        if (-not (Test-Path -LiteralPath $scanRoot)) { continue }
        $files = if (Test-Path -LiteralPath $scanRoot -PathType Leaf) {
            @(Get-Item -LiteralPath $scanRoot)
        } else {
            @(Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Include *.md,*.yml,*.yaml)
        }
        foreach ($file in $files) {
            $relative = Get-RelativeRepoPath -Root $root -Path $file.FullName
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath $file.FullName) {
                $lineNumber++
                if (Test-CanonicalGeneratedClaim -Line $line) {
                    $generatedClaimFindings.Add([pscustomobject]@{ path = $relative; line = $lineNumber; text = $line.Trim() }) | Out-Null
                }
            }
        }
    }
    Add-Check -Name "generated handoff/runtime paths are not canonical docs" -Ok ($generatedClaimFindings.Count -eq 0) -Reason "found canonical claims for .chatgpt or .superpowers paths"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{
        ok = ($failed.Count -eq 0)
        phase = $phase
        receipt_path = $receiptRelativePath
        generated_claim_findings = $generatedClaimFindings
        checks = $checks
    } | ConvertTo-Json -Depth 10
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{
        ok = $false
        phase = $phase
        receipt_path = $ReceiptPath
        reason = $_.Exception.Message
        checks = $checks
    } | ConvertTo-Json -Depth 10
    exit 1
}
