[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$PlanPath,
    [string]$ApprovalJson,
    [string]$ApprovalPath,
    [string]$VerificationJson,
    [string]$VerificationPath,
    [string]$CleanupJson,
    [string]$CleanupPath,
    [ValidateSet("PreChange", "PostChange")][string]$Mode = "PreChange",
    [string[]]$ChangedFiles = @()
)

$ErrorActionPreference = "Stop"

function Complete-QuickApply {
    param([string]$Reason, [hashtable]$Evidence)
    [ordered]@{
        ok = $true
        phase = "quick-apply"
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 16
    exit 0
}

function Fail-QuickApply {
    param([string]$Reason, [hashtable]$Evidence = @{})
    [ordered]@{
        ok = $false
        phase = "quick-apply"
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 16
    exit 1
}

function Resolve-RepoFile {
    param([string]$Root, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "path is required" }
    $combined = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $Root $Path }
    [IO.Path]::GetFullPath($combined)
}

function Normalize-RepoPath {
    param([string]$Path)
    $Path.Replace("\", "/").Trim()
}

function Read-JsonInput {
    param([string]$Json, [string]$Path, [string]$Name)
    if (-not [string]::IsNullOrWhiteSpace($Json) -and -not [string]::IsNullOrWhiteSpace($Path)) {
        throw "$Name must use either JSON or path, not both"
    }
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name path does not exist" }
        $Json = Get-Content -LiteralPath $Path -Raw
    }
    if ([string]::IsNullOrWhiteSpace($Json)) { throw "$Name JSON is required" }
    try {
        $Json | ConvertFrom-Json
    } catch {
        throw "$Name must be valid JSON"
    }
}

function Test-Property {
    param($Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Invoke-GitSimple {
    param([string]$Root, [string[]]$Arguments)
    $stdout = & git -C $Root @Arguments 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = ($stdout | Out-String).Trim()
    }
}

try {
    $root = [IO.Path]::GetFullPath($RepoRoot)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "RepoRoot does not exist" }

    $gitRoot = Invoke-GitSimple -Root $root -Arguments @("rev-parse", "--show-toplevel")
    if ($gitRoot.exit_code -ne 0) { throw "RepoRoot is not a git repository" }
    $repoTop = [IO.Path]::GetFullPath($gitRoot.output)

    $planFull = Resolve-RepoFile -Root $repoTop -Path $PlanPath
    if (-not $planFull.StartsWith($repoTop, [StringComparison]::OrdinalIgnoreCase)) { throw "PlanPath must be inside the repo" }
    $relativePlan = Normalize-RepoPath ([IO.Path]::GetRelativePath($repoTop, $planFull))
    if (-not $relativePlan.StartsWith("docs/superpowers/plans/", [StringComparison]::Ordinal)) {
        throw "PlanPath must be under docs/superpowers/plans"
    }
    if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) { throw "PlanPath does not exist" }

    $branch = Invoke-GitSimple -Root $repoTop -Arguments @("branch", "--show-current")
    if ($branch.exit_code -ne 0 -or [string]::IsNullOrWhiteSpace($branch.output)) { throw "current branch is required" }
    if ((Normalize-RepoPath $branch.output) -ne "main") { throw "Quick Apply requires current branch main" }

    $originMain = Invoke-GitSimple -Root $repoTop -Arguments @("rev-parse", "--verify", "origin/main")
    if ($originMain.exit_code -ne 0) { throw "origin/main is required to prove main is synced" }
    $sync = Invoke-GitSimple -Root $repoTop -Arguments @("rev-list", "--left-right", "--count", "HEAD...origin/main")
    if ($sync.exit_code -ne 0) { throw "could not compare main to origin/main" }
    $counts = $sync.output -split "\s+"
    if ($counts.Count -lt 2 -or $counts[0] -ne "0" -or $counts[1] -ne "0") {
        throw "main must be synced to origin/main before Quick Apply"
    }

    $status = Invoke-GitSimple -Root $repoTop -Arguments @("status", "--short")
    if ($status.exit_code -ne 0) { throw "could not inspect git status" }
    $statusLines = @($status.output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($Mode -eq "PreChange" -and $statusLines.Count -gt 0) {
        throw "Quick Apply requires a clean git status before edits; dirty state detected"
    }
    if ($Mode -eq "PostChange") {
        if ($ChangedFiles.Count -eq 0) { throw "PostChange mode requires known changed files" }
        $known = @($ChangedFiles | ForEach-Object { Normalize-RepoPath $_ })
        foreach ($line in $statusLines) {
            $path = Normalize-RepoPath ($line.Substring([Math]::Min(3, $line.Length)).Trim().Trim('"'))
            if ($known -notcontains $path) { throw "dirty file is outside known changed files: $path" }
        }
    }

    $approval = Read-JsonInput -Json $ApprovalJson -Path $ApprovalPath -Name "approval"
    if (-not (Test-Property $approval "question_id") -or [string]$approval.question_id -ne "project_quick_apply_approval") {
        throw "approval question_id must be project_quick_apply_approval"
    }
    if (-not (Test-Property $approval "selected_action") -or [string]$approval.selected_action -ne "apply") {
        throw "approval selected_action must be apply"
    }

    $verification = Read-JsonInput -Json $VerificationJson -Path $VerificationPath -Name "verification"
    if (-not (Test-Property $verification "passed") -or $verification.passed -ne $true) {
        throw "verification must be present and passed"
    }
    if (-not (Test-Property $verification "commands")) { throw "verification commands are required" }
    $commands = @($verification.commands)
    if ($commands.Count -eq 0) { throw "verification commands are required" }
    foreach ($command in $commands) {
        if (-not (Test-Property $command "command") -or [string]::IsNullOrWhiteSpace([string]$command.command)) {
            throw "verification command text is required"
        }
        if (-not (Test-Property $command "passed") -or $command.passed -ne $true) {
            throw "verification command must be passed"
        }
    }

    $cleanup = Read-JsonInput -Json $CleanupJson -Path $CleanupPath -Name "cleanup"
    if (-not (Test-Property $cleanup "passed") -or $cleanup.passed -ne $true) {
        throw "cleanup hook result must be present and passed"
    }
    if (-not (Test-Property $cleanup "command") -or [string]$cleanup.command -notmatch "codex-cleanup\.ps1") {
        throw "cleanup hook command must include codex-cleanup.ps1"
    }

    Complete-QuickApply -Reason "Quick Apply gate passed" -Evidence @{
        repo_root = $repoTop
        plan_path = $relativePlan
        branch = "main"
        mode = $Mode
        verification_commands = $commands.Count
        cleanup_command = [string]$cleanup.command
    }
} catch {
    Fail-QuickApply -Reason $_.Exception.Message
}
