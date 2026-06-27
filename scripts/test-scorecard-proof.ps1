[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("scorecard-proof-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-JsonScript {
    param([string]$Path, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ exit_code = 127; raw = "missing script: $Path"; json = $null }
    }
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    $text = ($raw | Out-String).Trim()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = $text; json = $json }
}

function Write-FixtureFile {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Text -Encoding utf8NoBOM
}

function Initialize-FixtureRepo {
    param([string]$Root, [switch]$GeneratedCanonicalClaim)
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    foreach ($path in @(
        "docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md",
        "docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md",
        "docs/superpowers/workflow-contract.yml",
        "docs/superpowers/loop-mode-contract.yml",
        "docs/superpowers/backlog/ACTIVE.md",
        "docs/superpowers/examples/workflow-golden-paths.md",
        "docs/superpowers/examples/worker-handoff-packets.md",
        "skills/loop-controller/scripts/validate-loop-state-machine.ps1"
    )) {
        Write-FixtureFile -Path (Join-Path $Root $path) -Text "fixture"
    }
    $roleText = @'
# Fixture Role Doc

- `docs/superpowers/workflow-contract.yml` is the route contract.
- `docs/superpowers/backlog/ACTIVE.md` is the active Looping Mode candidate source.
- `docs/superpowers/examples/workflow-golden-paths.md` is an examples surface.
- `docs/superpowers/examples/worker-handoff-packets.md` is packet shape evidence.
- `docs/superpowers/milestones/*receipt*.md` files are validation receipts.
- `.chatgpt/**` and `.superpowers/**` are not canonical project docs.
'@
    if ($GeneratedCanonicalClaim) {
        $roleText += "`n- `.superpowers/runs/latest.json` is canonical project documentation.`n"
    }
    foreach ($doc in @(
        "README.md",
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/OUTCOME_WORKFLOW.md"
    )) {
        Write-FixtureFile -Path (Join-Path $Root $doc) -Text $roleText
    }
    foreach ($page in @(
        "docs/superpowers/milestones/M0-governance.md",
        "docs/superpowers/milestones/M1-source-of-truth.md"
    )) {
        Write-FixtureFile -Path (Join-Path $Root $page) -Text "# Milestone`n`n## Validation Receipts`n`n- ``docs/superpowers/milestones/M1-score-9-loop-mode-hardening-receipt.md```n"
    }
}

function Write-Receipt {
    param(
        [string]$Path,
        [switch]$TargetBelowNine,
        [switch]$MissingCommand,
        [switch]$MissingLoopProof
    )
    $projectContextTarget = if ($TargetBelowNine) { "8.9" } else { ">=9" }
    $loopProof = if ($MissingLoopProof) { "" } else { '- Loop proof: `docs/superpowers/loop-mode-contract.yml` and `skills/loop-controller/scripts/validate-loop-state-machine.ps1`.' }
    $loopContractLink = if ($MissingLoopProof) { "" } else { '- `docs/superpowers/loop-mode-contract.yml`' }
    $loopValidatorLink = if ($MissingLoopProof) { "" } else { '- `skills/loop-controller/scripts/validate-loop-state-machine.ps1`' }
    $scorecardCommand = if ($MissingCommand) { "" } else { '| scorecard validator | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-scorecard-proof.ps1 -RepoRoot .` | pass |' }
    @(
        '# Score 9+ And Looping Mode Hardening Receipt',
        '',
        '## Scorecard',
        '',
        '| Area | Target | Evidence | Result |',
        '|---|---:|---|---|',
        '| Full workflow coverage | >=9 | `docs/superpowers/workflow-contract.yml`, exact option validators | pass |',
        "| Project context + issues | $projectContextTarget | `docs/superpowers/PROJECT_CONTEXT.md`, `docs/superpowers/backlog/ACTIVE.md` | pass |",
        '| Decision gates | >=9 | `scripts/validate-workflow-contract.ps1` | pass |',
        '| Grilling behavior | >=9 | `scripts/test-decision-ledger.ps1` and Decision Ledger examples plan | pass |',
        '| Clear goals/outputs | >=9 | Outcome Proof and Artifact Review Card validators | pass |',
        '| Predictability | >=9 | metadata, contract, and loop validators | pass |',
        '| Friction/clutter | >=9 | compact metadata and duplicate policy validators | pass |',
        '| Ship confidence | >=9 | validate, sync-live, tracker, loop, cleanup proof | pass |',
        '',
        '## Command Receipts',
        '',
        '| Proof | Command | Result |',
        '|---|---|---|',
        '| workflow contract tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-contract.ps1` | pass |',
        '| workflow contract validator | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-workflow-contract.ps1 -RepoRoot .` | pass |',
        '| metadata tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-skill-metadata-contract.ps1` | pass |',
        '| metadata validator | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill-metadata-contract.ps1 -RepoRoot .` | pass |',
        '| loop controller tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-loop-controller.ps1` | pass |',
        '| loop scenarios | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\loop-controller\scripts\test-scenarios.ps1` | pass |',
        '| scorecard tests | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-scorecard-proof.ps1` | pass |',
        $scorecardCommand,
        '| repo validation | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` | pass |',
        '| live sync validation | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` | pass |',
        '| version freshness | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent` | pass |',
        '| tracker align proof | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` | pass |',
        '| cleanup | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .` | pass |',
        '| clean git state | `git status --short --branch` | pass |',
        '',
        '## Source Artifact Links',
        '',
        '- `docs/superpowers/specs/2026-06-26-score-9-loop-mode-hardening-spec.md`',
        '- `docs/superpowers/plans/2026-06-26-score-9-loop-mode-hardening-plan.md`',
        '- `docs/superpowers/workflow-contract.yml`',
        $loopContractLink,
        '- `docs/superpowers/backlog/ACTIVE.md`',
        '- `docs/superpowers/examples/workflow-golden-paths.md`',
        '- `docs/superpowers/examples/worker-handoff-packets.md`',
        $loopValidatorLink,
        '- `docs/superpowers/PROJECT_CONTEXT.md`',
        '- `docs/superpowers/OUTCOME_WORKFLOW.md`',
        '- `README.md`',
        '',
        '## Looping Mode Proof',
        '',
        $loopProof,
        '',
        '## Live Sync And Tracker Proof',
        '',
        '- Live sync and tracker align command receipts are listed above.',
        '',
        '## Project Context Roles',
        '',
        '- `docs/superpowers/milestones/M0-governance.md` links this receipt.',
        '- `docs/superpowers/milestones/M1-source-of-truth.md` links this receipt.',
        '- `.chatgpt/**` and `.superpowers/**` are not canonical project docs.'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $validator = Join-Path $RepoRoot "scripts\validate-scorecard-proof.ps1"

    $validRoot = Join-Path $tempRoot "valid"
    Initialize-FixtureRepo -Root $validRoot
    Write-Receipt -Path (Join-Path $validRoot "docs\superpowers\milestones\M1-score-9-loop-mode-hardening-receipt.md")
    $valid = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $validRoot)
    Add-Check -Name "valid scorecard receipt passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason $valid.raw

    $lowTargetRoot = Join-Path $tempRoot "low-target"
    Initialize-FixtureRepo -Root $lowTargetRoot
    Write-Receipt -Path (Join-Path $lowTargetRoot "docs\superpowers\milestones\M1-score-9-loop-mode-hardening-receipt.md") -TargetBelowNine
    $lowTarget = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $lowTargetRoot)
    Add-Check -Name "target below nine fails" -Ok ($lowTarget.exit_code -ne 0 -and $lowTarget.raw.Contains("Project context + issues target")) -Reason "target below 9 should fail"

    $missingCommandRoot = Join-Path $tempRoot "missing-command"
    Initialize-FixtureRepo -Root $missingCommandRoot
    Write-Receipt -Path (Join-Path $missingCommandRoot "docs\superpowers\milestones\M1-score-9-loop-mode-hardening-receipt.md") -MissingCommand
    $missingCommand = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $missingCommandRoot)
    Add-Check -Name "missing command receipt fails" -Ok ($missingCommand.exit_code -ne 0 -and $missingCommand.raw.Contains("validate-scorecard-proof.ps1")) -Reason "missing command receipt should fail"

    $missingLoopRoot = Join-Path $tempRoot "missing-loop"
    Initialize-FixtureRepo -Root $missingLoopRoot
    Write-Receipt -Path (Join-Path $missingLoopRoot "docs\superpowers\milestones\M1-score-9-loop-mode-hardening-receipt.md") -MissingLoopProof
    $missingLoop = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $missingLoopRoot)
    Add-Check -Name "missing loop proof fails" -Ok ($missingLoop.exit_code -ne 0 -and $missingLoop.raw.Contains("loop-mode-contract.yml")) -Reason "missing loop proof should fail"

    $canonicalClaimRoot = Join-Path $tempRoot "canonical-claim"
    Initialize-FixtureRepo -Root $canonicalClaimRoot -GeneratedCanonicalClaim
    Write-Receipt -Path (Join-Path $canonicalClaimRoot "docs\superpowers\milestones\M1-score-9-loop-mode-hardening-receipt.md")
    $canonicalClaim = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $canonicalClaimRoot)
    Add-Check -Name "generated canonical claim fails" -Ok ($canonicalClaim.exit_code -ne 0 -and $canonicalClaim.raw.Contains("canonical claims")) -Reason "generated state canonical claim should fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "scorecard-proof"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "scorecard-proof"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
