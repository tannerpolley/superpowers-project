[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("artifact-review-card-" + [guid]::NewGuid().ToString("N"))

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-Validator {
    param([string]$Path)
    $validator = Join-Path $RepoRoot "scripts\validate-artifact-review-card.ps1"
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $RepoRoot 2>&1
    } else {
        $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $RepoRoot -Path $Path 2>&1
    }
    $text = ($raw | Out-String).Trim()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }
    [pscustomobject]@{ exit_code = $LASTEXITCODE; raw = $text; json = $json }
}

function Write-Card {
    param(
        [string]$Path,
        [string]$Gate,
        [string]$Created = '- `docs/superpowers/examples/card.md` - created example card.',
        [string]$Proof = '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1` passed.',
        [string]$Decisions,
        [string]$Risks = '- No remaining risk. Owner: `merge-changes`.',
        [string]$Next = '- `merge-changes`'
    )
    if ([string]::IsNullOrWhiteSpace($Decisions)) {
        $Decisions = "- Selected $Gate gate after artifact review."
    }
    @(
        "# Artifact Review Card",
        "",
        "Gate: $Gate",
        "",
        "## Created/changed",
        $Created,
        "",
        "## Proof",
        $Proof,
        "",
        "## Decisions",
        $Decisions,
        "",
        "## Risks",
        $Risks,
        "",
        "## Recommended next route",
        $Next
    ) | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    $valid = Join-Path $tempRoot "valid-continuation.md"
    Write-Card -Path $valid -Gate "continuation" -Next '- `write-plan`'
    $validResult = Invoke-Validator -Path $valid
    Add-Check -Name "valid continuation card passes" -Ok ($validResult.exit_code -eq 0 -and $validResult.json.ok -eq $true) -Reason $validResult.raw

    foreach ($gate in @("push", "publish", "merge")) {
        $fixture = Join-Path $tempRoot "$gate.md"
        Write-Card -Path $fixture -Gate $gate -Created '- `skills/advanced-user-input/SKILL.md` - updated Artifact Review Card schema.' -Proof '- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-artifact-review-card.ps1` passed.' -Decisions "- $gate gate may be asked after the card is shown." -Risks '- Approval risk remains bounded by native gate. Owner: `advanced-user-input`.' -Next '- `merge-changes`'
        $result = Invoke-Validator -Path $fixture
        Add-Check -Name "$gate card passes" -Ok ($result.exit_code -eq 0 -and $result.json.ok -eq $true) -Reason $result.raw
    }

    $missingPath = Join-Path $tempRoot "missing-path.md"
    Write-Card -Path $missingPath -Gate "push" -Created "- Changed the docs."
    $missingPathResult = Invoke-Validator -Path $missingPath
    Add-Check -Name "missing exact path fails" -Ok ($missingPathResult.exit_code -ne 0 -and $missingPathResult.raw.Contains("exact path")) -Reason "missing exact path should fail"

    $missingProof = Join-Path $tempRoot "missing-proof.md"
    Write-Card -Path $missingProof -Gate "merge" -Proof ""
    $missingProofResult = Invoke-Validator -Path $missingProof
    Add-Check -Name "missing proof fails" -Ok ($missingProofResult.exit_code -ne 0 -and $missingProofResult.raw.Contains("Proof")) -Reason "missing proof should fail"

    $missingRiskOwner = Join-Path $tempRoot "missing-risk-owner.md"
    Write-Card -Path $missingRiskOwner -Gate "continuation" -Risks "- Remaining migration risk."
    $missingRiskOwnerResult = Invoke-Validator -Path $missingRiskOwner
    Add-Check -Name "missing risk owner fails" -Ok ($missingRiskOwnerResult.exit_code -ne 0 -and $missingRiskOwnerResult.raw.Contains("risk owner")) -Reason "missing risk owner should fail"

    $repoPolicy = Invoke-Validator -Path ""
    Add-Check -Name "repo Artifact Review Card policy passes" -Ok ($repoPolicy.exit_code -eq 0 -and $repoPolicy.json.ok -eq $true) -Reason $repoPolicy.raw

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "artifact-review-card"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "artifact-review-card"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
