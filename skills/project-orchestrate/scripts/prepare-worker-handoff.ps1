[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$IssueFile,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$phase = "prepare-worker-handoff"

function Complete {
    param([bool]$Ok, [string]$Reason, [object]$Handoff = $null, [string]$HandoffPath = "")
    [ordered]@{ ok = $Ok; phase = $phase; reason = $Reason; handoff = $Handoff; handoff_path = $HandoffPath } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    foreach ($pattern in @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    $null
}

function Get-SectionBulletValues {
    param([string]$Text, [string]$Heading)
    $escaped = [regex]::Escape($Heading)
    $match = [regex]::Match($Text, "(?ims)^##\s+$escaped\s*$\s*(?<body>.*?)(?=^##\s+|\z)")
    if (-not $match.Success) { return @() }
    @($match.Groups["body"].Value -split "`r?`n" | Where-Object { $_ -match '^\s*-\s+(.+?)\s*$' } | ForEach-Object { $Matches[1].Trim() })
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $issuePath = if ([IO.Path]::IsPathRooted($IssueFile)) {
        [IO.Path]::GetFullPath($IssueFile)
    } else {
        [IO.Path]::GetFullPath((Join-Path $root $IssueFile))
    }
    if (-not (Test-Path -LiteralPath $issuePath -PathType Leaf)) { throw "issue mirror is missing" }
    $relative = ([IO.Path]::GetRelativePath($root, $issuePath) -replace '\\', '/')
    $validator = Join-Path $root "skills/project-issue/scripts/validate-issue-mirror.ps1"
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        $validator = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "project-issue/scripts/validate-issue-mirror.ps1"
    }
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw "issue mirror validator is missing" }
    $validationRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $root -IssueFile $relative -MilestoneRequired 2>&1
    $validationText = ($validationRaw | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "issue mirror validation failed: $validationText" }
    $text = Get-Content -LiteralPath $issuePath -Raw
    $sourcePlan = Get-FieldValue -Text $text -Name "Source Plan"
    if ([string]::IsNullOrWhiteSpace($sourcePlan) -or $sourcePlan -eq "none") { throw "Source Plan is required for worker orchestration" }
    $sourcePlanPath = if ([IO.Path]::IsPathRooted($sourcePlan)) { $sourcePlan } else { Join-Path $root $sourcePlan }
    if (-not (Test-Path -LiteralPath $sourcePlanPath -PathType Leaf)) { throw "Source Plan does not exist: $sourcePlan" }
    $identityRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "derive-worker-identity.ps1") -RepoRoot $root -IssueFile $relative 2>&1
    $identityText = ($identityRaw | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "worker identity derivation failed: $identityText" }
    $identityResult = $identityText | ConvertFrom-Json
    $proofOracle = @(Get-SectionBulletValues -Text $text -Heading "Proof Oracle")
    if ($proofOracle.Count -eq 0) { throw "Proof Oracle section with commands is required" }
    $handoff = [ordered]@{
        issue_mirror = $relative
        issue_url = Get-FieldValue -Text $text -Name "GitHub Issue"
        source_plan = ([IO.Path]::GetRelativePath($root, $sourcePlanPath) -replace '\\', '/')
        classification = Get-FieldValue -Text $text -Name "Classification"
        goal_command = Get-FieldValue -Text $text -Name "Goal Command"
        worker_identity = $identityResult.identity
        branch = $identityResult.identity.branch
        proof_oracle = $proofOracle
        topology_handoff = [ordered]@{
            orchestrator_role = "main-thread-orchestrator"
            worker_role = "implementation-worker"
            merge_owner = "project-merge"
            worker_must_not_merge = $true
            wakeup_policy = "worker handoff or bounded heartbeat"
        }
        required_skills = @(
            "superpowers:using-git-worktrees",
            "superpowers:test-driven-development",
            "superpowers:executing-plans",
            "superpowers:verification-before-completion",
            "superpowers:finishing-a-development-branch"
        )
    }
    $written = ""
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $target = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $root $OutputPath }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        $handoff | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $target -Encoding utf8NoBOM
        $written = ([IO.Path]::GetRelativePath($root, $target) -replace '\\', '/')
    }
    Complete -Ok $true -Reason "worker handoff prepared" -Handoff $handoff -HandoffPath $written
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
