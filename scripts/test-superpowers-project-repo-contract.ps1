[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Complete {
    param([bool]$Ok, [string]$Reason)
    [pscustomobject]@{ ok = $Ok; phase = "superpowers-project-repo-contract"; reason = $Reason; checks = $checks } | ConvertTo-Json -Depth 8
    if ($Ok) { exit 0 }
    exit 1
}

function Assert-RelativePathExists {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [ValidateSet("File", "Directory")][string]$Kind = "File"
    )
    $path = Join-Path $repoRoot $RelativePath
    $pathType = if ($Kind -eq "File") { "Leaf" } else { "Container" }
    if (-not (Test-Path -LiteralPath $path -PathType $pathType)) {
        throw "missing required ${Kind}: $RelativePath"
    }
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string[]]$Needles
    )
    $path = Join-Path $repoRoot $RelativePath
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($needle in $Needles) {
        if (-not $text.Contains($needle)) {
            throw "$RelativePath is missing required text: $needle"
        }
    }
}

function Invoke-JsonScript {
    param([string]$ScriptPath, [string[]]$Arguments)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $raw = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{ ok = $false; reason = "empty output from $ScriptPath" }
    }
    try {
        return ($raw | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{ ok = $false; reason = $raw }
    }
}

try {
    foreach ($requiredDirectory in @(
        "docs/superpowers/milestones",
        "docs/superpowers/specs",
        "docs/superpowers/plans",
        "docs/superpowers/issues"
    )) {
        Assert-RelativePathExists -RelativePath $requiredDirectory -Kind Directory
    }
    foreach ($requiredFile in @(
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/milestones/README.md",
        "docs/superpowers/issues/README.md",
        "docs/agents/issue-tracker.md",
        "docs/agents/project-roadmap.md",
        "docs/agents/project-roadmap.json",
        "docs/agents/triage-labels.md"
    )) {
        Assert-RelativePathExists -RelativePath $requiredFile -Kind File
    }
    Add-Check -Name "required artifact paths" -Ok $true -Reason "passed"

    Assert-TextContains -RelativePath "docs/superpowers/PROJECT_CONTEXT.md" -Needles @(
        "## Durable Intent",
        "## Artifact Model",
        "## Roadmap And Milestones",
        "## GitHub Tracker Config",
        "## Execution Model",
        "## Extension Skills",
        "## Current Open Questions",
        "tannerpolley/milestones-plugin",
        "docs/superpowers/issues/"
    )
    Add-Check -Name "project context shape" -Ok $true -Reason "passed"

    Assert-TextContains -RelativePath "AGENTS.md" -Needles @(
        "docs/superpowers/specs/",
        "docs/superpowers/plans/",
        "docs/superpowers/issues/",
        "docs/superpowers/milestones/"
    )
    $agentsText = Get-Content -LiteralPath (Join-Path $repoRoot "AGENTS.md") -Raw
    if ($agentsText.Contains("New idea briefs for this repo belong under `docs/milestones") -or
        $agentsText.Contains("Local issue files for this repo belong under `docs/milestones")) {
        throw "AGENTS.md still routes new work to retired docs/milestones artifact paths"
    }
    Add-Check -Name "repo agent routing" -Ok $true -Reason "passed"

    $roadmap = Get-Content -LiteralPath (Join-Path $repoRoot "docs/agents/project-roadmap.json") -Raw | ConvertFrom-Json
    if ($roadmap.tracker -ne "github") { throw "project-roadmap.json tracker must be github" }
    if ($roadmap.repository -ne "tannerpolley/milestones-plugin") { throw "project-roadmap.json repository mismatch" }
    foreach ($label in @("type:bug", "type:feature", "type:task", "status:triage", "status:ready", "status:blocked")) {
        if ($roadmap.labels -notcontains $label) { throw "project-roadmap.json missing label: $label" }
    }
    Add-Check -Name "tracker config" -Ok $true -Reason "passed"

    foreach ($skillName in @(
        "superpowers-project",
        "project-context",
        "project-brainstorm",
        "project-plan",
        "project-issue",
        "project-resolve",
        "project-merge",
        "project-doctor"
    )) {
        $skillPath = Join-Path $repoRoot "skills/$skillName/SKILL.md"
        $skillText = Get-Content -LiteralPath $skillPath -Raw
        foreach ($needle in @(
            "## Native Question Debug Mode",
            "debug_question_mode",
            "waitingOnUserInput",
            "Native Question Debug Ledger",
            "recommended-default",
            "user-provided-debug-answer",
            "Debug mode must not"
        )) {
            if (-not $skillText.Contains($needle)) {
                throw "$skillName is missing native question debug mode contract: $needle"
            }
        }
    }
    Add-Check -Name "native question debug mode" -Ok $true -Reason "passed"

    $issueFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs/superpowers/issues") -Filter "*.md" -File | Where-Object { $_.Name -ne "README.md" })
    if ($issueFiles.Count -lt 1) { throw "docs/superpowers/issues must contain at least one issue mirror for smoke validation" }
    $validator = Join-Path $repoRoot "skills/project-issue/scripts/validate-issue-mirror.ps1"
    foreach ($issueFile in $issueFiles) {
        $relative = [IO.Path]::GetRelativePath($repoRoot, $issueFile.FullName) -replace '\\', '/'
        $result = Invoke-JsonScript -ScriptPath $validator -Arguments @("-RepoRoot", $repoRoot, "-IssueFile", $relative, "-MilestoneRequired")
        if (-not $result.ok) {
            throw "issue mirror validation failed for ${relative}: $($result.reason)"
        }
    }
    Add-Check -Name "repo issue mirrors" -Ok $true -Reason "passed"

    foreach ($issueFile in $issueFiles) {
        $text = Get-Content -LiteralPath $issueFile.FullName -Raw
        foreach ($needle in @(
            "Execution Mode",
            "Worktree Policy",
            "Integration Policy",
            "TDD Policy",
            "Parallelization Plan",
            "Reviewer Role",
            "Script Gate Mode",
            "Project Merge",
            "Merge Owner",
            "Merge Gate",
            "Merge Policy",
            "Worktree Cleanup Policy",
            "Orchestrator Wakeup Policy"
        )) {
            if (-not $text.Contains($needle)) {
                throw "$($issueFile.Name) is missing workflow metadata: $needle"
            }
        }
    }
    Add-Check -Name "issue workflow metadata" -Ok $true -Reason "passed"

    $staleActiveRouting = @(rg -n "New idea briefs for this repo belong under|Local issue files for this repo belong under|keep implementation issues under `?docs/milestones|ready-for-agent|needs-info|type:enhancement" `
        (Join-Path $repoRoot "AGENTS.md") `
        (Join-Path $repoRoot "skills") `
        (Join-Path $repoRoot "docs/agents") `
        (Join-Path $repoRoot "docs/superpowers") 2>$null)
    if ($staleActiveRouting.Count -gt 0) {
        throw "stale active routing or label text remains: $($staleActiveRouting -join '; ')"
    }
    Add-Check -Name "stale routing scan" -Ok $true -Reason "passed"

    Complete -Ok $true -Reason "passed"
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    Complete -Ok $false -Reason $_.Exception.Message
}
