[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Normalize-PathText {
    param([string]$Path)
    $Path.Replace("\", "/")
}

function Get-RepoRelativePath {
    param([string]$Root, [string]$Path)
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith($fullRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return Normalize-PathText ($fullPath.Substring($fullRoot.Length + 1))
    }
    Normalize-PathText $fullPath
}

function Write-Result {
    param([bool]$Ok, [string]$Reason, [hashtable]$Evidence = @{})
    [ordered]@{
        ok = $Ok
        phase = "milestones-doctor-audit"
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $milestonesRoot = Join-Path $root "docs\milestones"
    $projectContext = Join-Path $milestonesRoot "PROJECT_CONTEXT.md"
    $milestonesReadme = Join-Path $milestonesRoot "README.md"
    $projectRoadmapMd = Join-Path $root "docs\agents\project-roadmap.md"
    $projectRoadmapJson = Join-Path $root "docs\agents\project-roadmap.json"

    $obsoletePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @("docs\ideas", "docs\issues", "docs\plans")) {
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path) { $obsoletePaths.Add((Normalize-PathText $relative)) }
    }
    if (Test-Path -LiteralPath $milestonesRoot -PathType Container) {
        Get-ChildItem -LiteralPath $milestonesRoot -Directory | ForEach-Object {
            $plansPath = Join-Path $_.FullName "plans"
            if (Test-Path -LiteralPath $plansPath) {
                $obsoletePaths.Add((Get-RepoRelativePath -Root $root -Path $plansPath))
            }
        }
    }

    $milestoneFolders = @()
    if (Test-Path -LiteralPath $milestonesRoot -PathType Container) {
        $milestoneFolders = @(Get-ChildItem -LiteralPath $milestonesRoot -Directory | Where-Object {
            $_.Name -notin @(".git", ".github")
        } | Sort-Object Name | ForEach-Object {
            $folder = $_.Name
            $readme = Join-Path $_.FullName "README.md"
            $ideasDir = Join-Path $_.FullName "ideas"
            $issuesDir = Join-Path $_.FullName "issues"
            [ordered]@{
                folder = $folder
                readme = if (Test-Path -LiteralPath $readme -PathType Leaf) { "present" } else { "missing" }
                ideas_dir = if (Test-Path -LiteralPath $ideasDir -PathType Container) { "present" } else { "missing" }
                ideas_readme = if (Test-Path -LiteralPath (Join-Path $ideasDir "README.md") -PathType Leaf) { "present" } else { "missing" }
                issues_dir = if (Test-Path -LiteralPath $issuesDir -PathType Container) { "present" } else { "missing" }
                issues_readme = if (Test-Path -LiteralPath (Join-Path $issuesDir "README.md") -PathType Leaf) { "present" } else { "missing" }
                idea_files = if (Test-Path -LiteralPath $ideasDir -PathType Container) { @((Get-ChildItem -LiteralPath $ideasDir -Filter "*.md" -File | Where-Object Name -ne "README.md").Count)[0] } else { 0 }
                issue_files = if (Test-Path -LiteralPath $issuesDir -PathType Container) { @((Get-ChildItem -LiteralPath $issuesDir -Filter "*.md" -File | Where-Object Name -ne "README.md").Count)[0] } else { 0 }
            }
        })
    }

    $blocking = [System.Collections.Generic.List[string]]::new()
    $repairable = [System.Collections.Generic.List[string]]::new()
    $reviewNeeded = [System.Collections.Generic.List[string]]::new()
    $healthy = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path -LiteralPath $milestonesRoot -PathType Container)) {
        $blocking.Add("docs/milestones is missing")
    } else {
        $healthy.Add("docs/milestones exists")
    }
    if (-not (Test-Path -LiteralPath $projectContext -PathType Leaf)) {
        $blocking.Add("docs/milestones/PROJECT_CONTEXT.md is missing")
    } else {
        $healthy.Add("docs/milestones/PROJECT_CONTEXT.md exists")
    }
    foreach ($required in @(
        @{ path = $milestonesReadme; label = "docs/milestones/README.md" },
        @{ path = $projectRoadmapMd; label = "docs/agents/project-roadmap.md" },
        @{ path = $projectRoadmapJson; label = "docs/agents/project-roadmap.json" }
    )) {
        if (Test-Path -LiteralPath $required.path -PathType Leaf) {
            $healthy.Add("$($required.label) exists")
        } else {
            $repairable.Add("$($required.label) is missing")
        }
    }
    foreach ($folder in $milestoneFolders) {
        foreach ($field in @("readme", "ideas_dir", "ideas_readme", "issues_dir", "issues_readme")) {
            if ($folder.$field -eq "missing") {
                $repairable.Add("docs/milestones/$($folder.folder) missing $field")
            }
        }
    }
    foreach ($path in $obsoletePaths) {
        $reviewNeeded.Add("obsolete path needs review before cleanup: $path")
    }

    $evidence = @{
        repo_root = $root
        local_contract = @{
            project_context = if (Test-Path -LiteralPath $projectContext -PathType Leaf) { "present" } else { "missing" }
            milestone_root = if (Test-Path -LiteralPath $milestonesRoot -PathType Container) { "present" } else { "missing" }
            milestone_folders = $milestoneFolders
            obsolete_paths = @($obsoletePaths)
        }
        findings = @{
            blocking = @($blocking)
            repairable = @($repairable)
            review_needed = @($reviewNeeded)
            healthy = @($healthy)
        }
    }

    $reason = if ($blocking.Count -gt 0 -or $repairable.Count -gt 0 -or $reviewNeeded.Count -gt 0) {
        "milestone audit found issues"
    } else {
        "milestone audit passed"
    }
    Write-Result -Ok $true -Reason $reason -Evidence $evidence
} catch {
    Write-Result -Ok $false -Reason $_.Exception.Message
}
