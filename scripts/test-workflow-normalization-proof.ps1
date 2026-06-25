[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("workflow-normalization-proof-" + [guid]::NewGuid().ToString("N"))

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

function Initialize-FixtureRepo {
    param([string]$Root)
    New-Item -ItemType Directory -Path (Join-Path $Root "docs\agents") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root "docs\superpowers\milestones") -Force | Out-Null
    [pscustomobject]@{
        tracker = "github"
        repository = "tannerpolley/superpowers-project"
        milestone_root = "docs/superpowers/milestones"
        issue_types = @("bug", "feature", "task")
        triage_states = @("status:triage", "status:ready", "status:blocked")
        labels = @("type:bug", "type:feature", "type:task", "status:triage", "status:ready", "status:blocked")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root "docs\agents\project-roadmap.json") -Encoding utf8NoBOM
    "# M0`n`n## Validation Receipts`n`n- ``docs/superpowers/milestones/M1-workflow-normalization-validation-receipt.md```n" | Set-Content -LiteralPath (Join-Path $Root "docs\superpowers\milestones\M0-governance.md") -Encoding utf8NoBOM
    "# M1`n`n## Validation Receipts`n`n- ``docs/superpowers/milestones/M1-workflow-normalization-validation-receipt.md```n" | Set-Content -LiteralPath (Join-Path $Root "docs\superpowers\milestones\M1-source-of-truth.md") -Encoding utf8NoBOM
}

function Write-Receipt {
    param(
        [string]$Path,
        [switch]$MissingTriageLabel
    )
    $triage = if ($MissingTriageLabel) { "" } else { '- `status:triage`' }
    @(
        '# Workflow Normalization Validation Receipt',
        "",
        '## Scope',
        "",
        '- Source issue: `https://github.com/tannerpolley/superpowers-project/issues/72`',
        '- Source plan: `docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md`',
        '- Issue mirror: `docs/superpowers/issues/72-live-sync-tracker-align-validation.md`',
        "",
        '## Project Roadmap Proof',
        "",
        '- Repository: `tannerpolley/superpowers-project`',
        '- Milestone root: `docs/superpowers/milestones`',
        '- Issue types: `bug`, `feature`, `task`',
        '- Labels:',
        '- `type:bug`',
        '- `type:feature`',
        '- `type:task`',
        $triage,
        '- `status:ready`',
        $blocked,
        "",
        '## Command Receipts',
        "",
        '| Proof | Command | Result |',
        '|---|---|---|',
        '| repo validation | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` | pass |',
        '| live sync validation | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-live.ps1 -Validate` | pass |',
        '| version freshness | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\get-agent-plugin-version.ps1 -Banner -RequireCurrent` | pass |',
        '| tracker roadmap proof | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-tracker-roadmap-proof.ps1 -RepoRoot . -IssueNumber 72 -RequiredIssueLabel status:ready -ForbiddenIssueLabel status:blocked -RequiredIssueMilestone "M1 - Source Of Truth"` | pass |',
        '| tracker align proof | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\align-project\scripts\align-project.ps1 -RepoRoot . -Mode GitHubAware -TrackerHygiene` | pass |',
        '| cleanup | `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .` | pass |',
        '| clean git state | `git status --short --branch` | pass |',
        "",
        '## Tracker And Align Proof',
        "",
        '- GitHub-aware align and tracker hygiene proof passed.',
        "",
        '## Milestone Linkage',
        "",
        '- `docs/superpowers/milestones/M0-governance.md` links this receipt.',
        '- `docs/superpowers/milestones/M1-source-of-truth.md` links this receipt.',
        "",
        '## Clean State Proof',
        "",
        '- Cleanup hook and clean Git state are required before final Done.'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $validator = Join-Path $RepoRoot "scripts\validate-workflow-normalization-proof.ps1"
    $fixture = Join-Path $tempRoot "fixture"
    Initialize-FixtureRepo -Root $fixture
    $receiptPath = Join-Path $fixture "docs\superpowers\milestones\M1-workflow-normalization-validation-receipt.md"
    Write-Receipt -Path $receiptPath

    $valid = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $fixture)
    Add-Check -Name "valid receipt passes" -Ok ($valid.exit_code -eq 0 -and $valid.json.ok -eq $true) -Reason $valid.raw

    $missingLabelFixture = Join-Path $tempRoot "missing-label"
    Initialize-FixtureRepo -Root $missingLabelFixture
    Write-Receipt -Path (Join-Path $missingLabelFixture "docs\superpowers\milestones\M1-workflow-normalization-validation-receipt.md") -MissingTriageLabel
    $missingLabel = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $missingLabelFixture)
    Add-Check -Name "missing roadmap label fails" -Ok ($missingLabel.exit_code -ne 0 -and $missingLabel.raw.Contains("status:triage")) -Reason "missing roadmap label should fail"

    $missingLinkFixture = Join-Path $tempRoot "missing-link"
    Initialize-FixtureRepo -Root $missingLinkFixture
    Write-Receipt -Path (Join-Path $missingLinkFixture "docs\superpowers\milestones\M1-workflow-normalization-validation-receipt.md")
    "# M1`n" | Set-Content -LiteralPath (Join-Path $missingLinkFixture "docs\superpowers\milestones\M1-source-of-truth.md") -Encoding utf8NoBOM
    $missingLink = Invoke-JsonScript -Path $validator -Arguments @("-RepoRoot", $missingLinkFixture)
    Add-Check -Name "missing milestone link fails" -Ok ($missingLink.exit_code -ne 0 -and $missingLink.raw.Contains("M1-source-of-truth.md")) -Reason "missing milestone link should fail"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "workflow-normalization-proof"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "workflow-normalization-proof"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
