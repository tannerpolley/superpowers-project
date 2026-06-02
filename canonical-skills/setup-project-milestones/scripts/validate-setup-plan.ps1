[CmdletBinding()]
param(
    [string]$PlanJson,
    [string]$PlanPath
)

$ErrorActionPreference = "Stop"

function Write-Result {
    param([bool]$Ok, [string]$Reason, [hashtable]$Evidence = @{})
    [ordered]@{
        ok = $Ok
        phase = "setup-project-milestones-plan"
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Read-JsonInput {
    param([string]$Json, [string]$Path)
    $text = if (-not [string]::IsNullOrWhiteSpace($Json)) {
        $Json
    } elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "setup plan path not found: $Path" }
        Get-Content -LiteralPath $Path -Raw
    } else {
        throw "missing setup plan JSON"
    }
    $trimmed = $text.Trim()
    if ($trimmed -match '```') {
        $capture = $false
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in ($text -split '\r?\n')) {
            if (-not $capture -and $line -match '^```\S*\s*setup_project_milestones_plan\s*$') {
                $capture = $true
                continue
            }
            if ($capture -and $line -match '^```\s*$') { break }
            if ($capture) { $lines.Add($line) }
        }
        if ($lines.Count -gt 0) { $trimmed = ($lines -join "`n").Trim() }
    }
    $trimmed | ConvertFrom-Json
}

function Has-Field {
    param($Object, [string]$Name)
    $Object.PSObject.Properties.Name -contains $Name
}

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    @($Value)
}

try {
    $plan = Read-JsonInput -Json $PlanJson -Path $PlanPath
    $required = @(
        "target_repo", "target_repo_root", "source_docs", "full_roadmap", "full_roadmap_policy", "milestone_policy",
        "milestone_question_log", "milestones", "project_policy", "issue_types", "labels", "issue_forms", "local_files",
        "apply_policy", "projects_required_by_repo_config"
    )
    $missing = @()
    foreach ($field in $required) {
        if (-not (Has-Field $plan $field) -or $null -eq $plan.$field) { $missing += $field }
    }
    if ($missing.Count -gt 0) { throw "setup plan missing required fields: $($missing -join ', ')" }

    if ([string]$plan.target_repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "target_repo must be GitHub owner/repo" }
    if (-not [IO.Path]::IsPathRooted([string]$plan.target_repo_root)) { throw "target_repo_root must be an absolute local path" }
    if ([string]$plan.full_roadmap_policy -notin @("read-existing", "create-approved")) { throw "full_roadmap_policy must be read-existing or create-approved" }
    if ([string]$plan.milestone_policy -ne "mirror-full-roadmap") { throw "milestone_policy must be mirror-full-roadmap" }
    if ([string]$plan.project_policy -notin @("dashboard-only", "repo-config-required")) { throw "project_policy must be dashboard-only or repo-config-required" }
    if ([string]$plan.project_policy -eq "repo-config-required" -and $plan.projects_required_by_repo_config -ne $true) {
        throw "Projects may be required only when repo config explicitly requires them"
    }
    if ([string]$plan.apply_policy -ne "default-branch-commit-push") { throw "apply_policy must be default-branch-commit-push" }
    $fullRoadmap = ([string]$plan.full_roadmap).Replace("\", "/")
    if ($fullRoadmap -ne "docs/milestones/PROJECT_CONTEXT.md") {
        throw "full_roadmap must be docs/milestones/PROJECT_CONTEXT.md"
    }

    $milestoneQuestions = @(As-Array $plan.milestone_question_log)
    if ($milestoneQuestions.Count -eq 0) { throw "milestone_question_log must record the request_user_input milestone selection" }
    foreach ($entry in $milestoneQuestions) {
        foreach ($field in @("tool", "question", "agent_recommendation", "answer")) {
            if (-not (Has-Field $entry $field) -or $null -eq $entry.$field) { throw "milestone_question_log entries must include tool, question, agent_recommendation, and answer" }
        }
        if ([string]$entry.tool -ne "request_user_input") { throw "milestone_question_log tool must be request_user_input" }
        if ((As-Array $entry.agent_recommendation).Count -eq 0) { throw "milestone_question_log agent_recommendation must be non-empty" }
        if ([string]::IsNullOrWhiteSpace([string]$entry.answer)) { throw "milestone_question_log answer must be non-empty" }
    }

    $issueTypes = @(As-Array $plan.issue_types | ForEach-Object { ([string]$_).ToLowerInvariant() })
    foreach ($issueType in @("bug", "feature", "task")) {
        if ($issueTypes -notcontains $issueType) { throw "issue_types must include bug, feature, and task" }
    }

    $labels = @(As-Array $plan.labels | ForEach-Object { ([string]$_).ToLowerInvariant() })
    foreach ($label in @("type:bug", "type:feature", "type:task")) {
        if ($labels -notcontains $label) { throw "labels must include type:bug, type:feature, and type:task" }
    }

    $forms = @(As-Array $plan.issue_forms | ForEach-Object { ([string]$_).ToLowerInvariant() })
    foreach ($form in @("bug", "feature", "task")) {
        if ($forms -notcontains $form) { throw "issue_forms must include bug, feature, and task" }
    }

    $localFiles = @(As-Array $plan.local_files | ForEach-Object { ([string]$_).Replace("\", "/") })
    foreach ($file in $localFiles) {
        if ($file -match '(^|/)plans(/|$)' -or $file -match '^docs/plans(/|$)') {
            throw "local_files must not include docs/plans or milestone plans folders"
        }
    }
    if ($localFiles -contains "docs/ideas/README.md") {
        throw "strict milestone setup must not create docs/ideas/README.md; use docs/milestones/<milestone-folder>/ideas/README.md"
    }
    foreach ($file in @("docs/milestones/PROJECT_CONTEXT.md", "docs/milestones/README.md", "docs/agents/project-roadmap.md", "docs/agents/project-roadmap.json", ".github/ISSUE_TEMPLATE/bug.yml", ".github/ISSUE_TEMPLATE/feature.yml", ".github/ISSUE_TEMPLATE/task.yml")) {
        if ($localFiles -notcontains $file) { throw "local_files missing required setup file: $file" }
    }
    if ($localFiles -contains "docs/issues/README.md") {
        throw "strict milestone setup must not create docs/issues/README.md"
    }

    $milestones = @(As-Array $plan.milestones)
    if ($milestones.Count -eq 0) { throw "milestones must be non-empty when milestone_policy is mirror-full-roadmap" }
    $seenFolders = @{}
    foreach ($milestone in $milestones) {
        foreach ($field in @("title", "folder", "description", "source", "github_milestone", "local_readme", "local_ideas_dir", "local_issues_dir")) {
            if (-not (Has-Field $milestone $field) -or [string]::IsNullOrWhiteSpace([string]$milestone.$field)) {
                throw "milestones entries must include non-empty title, folder, description, source, github_milestone, local_readme, local_ideas_dir, and local_issues_dir"
            }
        }
        $folder = ([string]$milestone.folder).Replace("\", "/")
        if ($folder -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "milestone folder must be repo-safe: $folder" }
        if ($seenFolders.ContainsKey($folder.ToLowerInvariant())) { throw "duplicate milestone folder: $folder" }
        $seenFolders[$folder.ToLowerInvariant()] = $true
        if ([string]$milestone.source -notin @("existing-github", "full-roadmap", "agent-proposed-user-approved")) {
            throw "milestone source must be existing-github, full-roadmap, or agent-proposed-user-approved"
        }
        if ([string]$milestone.github_milestone -notin @("create", "update", "exists")) {
            throw "milestone github_milestone must be create, update, or exists"
        }
        $expectedReadme = "docs/milestones/$folder/README.md"
        $expectedIdeasReadme = "docs/milestones/$folder/ideas/README.md"
        $expectedIssuesReadme = "docs/milestones/$folder/issues/README.md"
        if (([string]$milestone.local_readme).Replace("\", "/") -ne $expectedReadme) { throw "milestone local_readme must equal $expectedReadme" }
        if (([string]$milestone.local_ideas_dir).Replace("\", "/") -ne "docs/milestones/$folder/ideas") { throw "milestone local_ideas_dir must equal docs/milestones/$folder/ideas" }
        if (([string]$milestone.local_issues_dir).Replace("\", "/") -ne "docs/milestones/$folder/issues") { throw "milestone local_issues_dir must equal docs/milestones/$folder/issues" }
        if ($localFiles -notcontains $expectedReadme) { throw "local_files missing milestone README: $expectedReadme" }
        if ($localFiles -notcontains $expectedIdeasReadme) { throw "local_files missing milestone ideas README: $expectedIdeasReadme" }
        if ($localFiles -notcontains $expectedIssuesReadme) { throw "local_files missing milestone issues README: $expectedIssuesReadme" }
    }

    foreach ($forbidden in @("branch", "branch_policy", "goal_board", "pr_url", "merge_confirmation")) {
        if (Has-Field $plan $forbidden) { throw "setup plan must not include execution-owned field: $forbidden" }
    }

    Write-Result -Ok $true -Reason "setup project milestones plan passed" -Evidence @{
        target_repo = $plan.target_repo
        issue_types = $issueTypes
        project_policy = $plan.project_policy
        milestone_policy = $plan.milestone_policy
        full_roadmap = $plan.full_roadmap
        milestone_count = $milestones.Count
    }
} catch {
    Write-Result -Ok $false -Reason $_.Exception.Message
}
