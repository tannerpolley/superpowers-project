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
        ".codex-plugin/plugin.json",
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/RELEASE_POLICY.md",
        "docs/superpowers/milestones/README.md",
        "docs/superpowers/issues/README.md",
        "docs/agents/issue-tracker.md",
        "docs/agents/project-roadmap.md",
        "docs/agents/project-roadmap.json",
        "docs/agents/triage-labels.md"
    )) {
        Assert-RelativePathExists -RelativePath $requiredFile -Kind File
    }
    if (Test-Path -LiteralPath (Join-Path $repoRoot "docs/milestones") -PathType Container) {
        throw "retired docs/milestones tree must not exist; use docs/superpowers/*"
    }
    Add-Check -Name "required artifact paths" -Ok $true -Reason "passed"

    $manifest = Get-Content -LiteralPath (Join-Path $repoRoot ".codex-plugin/plugin.json") -Raw | ConvertFrom-Json
    if ($manifest.name -ne "project") { throw "plugin manifest name must be project" }
    if ($manifest.author.name -ne "Tanner Polley") { throw "plugin manifest author must use public author identity" }
    if ($manifest.interface.developerName -ne "Tanner Polley") { throw "plugin manifest developerName must use public author identity" }
    if ($manifest.repository -ne "https://github.com/tannerpolley/codex-superpowers-project") { throw "plugin manifest repository must target codex-superpowers-project" }
    if ($manifest.homepage -ne "https://github.com/tannerpolley/codex-superpowers-project") { throw "plugin manifest homepage must target codex-superpowers-project" }
    if ($manifest.license -ne "MIT") { throw "plugin manifest license must be MIT" }
    if ($manifest.keywords -notcontains "codex" -or $manifest.keywords -notcontains "superpowers") { throw "plugin manifest keywords must include codex and superpowers" }
    Add-Check -Name "public plugin manifest metadata" -Ok $true -Reason "passed"

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

    Assert-TextContains -RelativePath "README.md" -Needles @(
        "codex-superpowers-project",
        "plugins\project",
        'After install, start with `$project:workflow`'
    )
    $publicTemplatePaths = @(
        ".github/ISSUE_TEMPLATE/bug.yml",
        ".github/ISSUE_TEMPLATE/feature.yml",
        ".github/ISSUE_TEMPLATE/task.yml"
    )
    foreach ($relativeTemplate in $publicTemplatePaths) {
        $templateText = Get-Content -LiteralPath (Join-Path $repoRoot $relativeTemplate) -Raw
        if ($templateText.Contains("Milestones plugin")) { throw "$relativeTemplate still uses retired product name" }
        if ($templateText.Contains("docs/milestones")) { throw "$relativeTemplate still references retired docs/milestones path" }
        if (-not $templateText.Contains("docs/superpowers/issues/<issue-number>-<slug>.md")) { throw "$relativeTemplate missing Superpowers issue mirror path hint" }
    }
    $workflowText = Get-Content -LiteralPath (Join-Path $repoRoot ".github/workflows/validate.yml") -Raw
    if ($workflowText.Contains("Validate Milestones plugin")) { throw "validate workflow still uses retired product name" }
    if (-not $workflowText.Contains("Validate Superpowers Project plugin")) { throw "validate workflow missing Superpowers Project job label" }
    $syncText = Get-Content -LiteralPath (Join-Path $repoRoot "scripts/sync-live.ps1") -Raw
    if (-not $syncText.Contains("plugins\project")) { throw "sync-live.ps1 must deploy to plugins/project" }
    if (-not $syncText.Contains("plugins\milestones")) { throw "sync-live.ps1 must clean up retired plugins/milestones path" }
    $doctorAuditText = Get-Content -LiteralPath (Join-Path $repoRoot "skills/audit-project/scripts/audit-project.ps1") -Raw
    if (-not $doctorAuditText.Contains("plugins/project/skills/audit-project/SKILL.md")) { throw "audit-project audit must inspect plugins/project" }
    Add-Check -Name "public readiness paths" -Ok $true -Reason "passed"

    $roadmap = Get-Content -LiteralPath (Join-Path $repoRoot "docs/agents/project-roadmap.json") -Raw | ConvertFrom-Json
    if ($roadmap.tracker -ne "github") { throw "project-roadmap.json tracker must be github" }
    if ($roadmap.repository -ne "tannerpolley/milestones-plugin") { throw "project-roadmap.json repository mismatch" }
    foreach ($label in @("type:bug", "type:feature", "type:task", "status:triage", "status:ready", "status:blocked")) {
        if ($roadmap.labels -notcontains $label) { throw "project-roadmap.json missing label: $label" }
    }
    Add-Check -Name "tracker config" -Ok $true -Reason "passed"

    foreach ($skillName in @(
        "workflow",
        "setup",
        "orchestrate-issues",
        "brainstorm-spec",
        "write-plan",
        "create-issues",
        "resolve-issue",
        "merge-changes",
        "audit-project"
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

    Assert-RelativePathExists -RelativePath "scripts/validate-skill-script-contract.ps1" -Kind File
    Assert-TextContains -RelativePath "scripts/validate.ps1" -Needles @(
        "validate-skill-script-contract.ps1",
        "skill script parameter contract"
    )
    Add-Check -Name "skill script parameter contract wiring" -Ok $true -Reason "passed"

    Assert-RelativePathExists -RelativePath "skills/audit-project/scripts/audit-project.ps1" -Kind File
    Assert-TextContains -RelativePath "skills/audit-project/SKILL.md" -Needles @(
        "audit-project.ps1",
        "-Mode LocalDocs",
        "-Mode GitHubAware",
        "native repair approval"
    )
    Assert-TextContains -RelativePath "skills/audit-project/agents/openai.yaml" -Needles @(
        "audit-project.ps1",
        "-Mode LocalDocs",
        "-Mode GitHubAware"
    )
    Add-Check -Name "project doctor audit gate wiring" -Ok $true -Reason "passed"

    $issueFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs/superpowers/issues") -Filter "*.md" -File | Where-Object { $_.Name -ne "README.md" })
    if ($issueFiles.Count -lt 1) { throw "docs/superpowers/issues must contain at least one issue mirror for smoke validation" }
    $validator = Join-Path $repoRoot "skills/create-issues/scripts/validate-issue-mirror.ps1"
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

