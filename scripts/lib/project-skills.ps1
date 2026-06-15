$ErrorActionPreference = "Stop"

function Resolve-ProjectPluginRoot {
    param([string]$RepoRoot)

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -LiteralPath $RepoRoot).Path
    }

    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
}

function Get-ProjectActiveSkillNames {
    param([string]$RepoRoot)

    $root = Resolve-ProjectPluginRoot -RepoRoot $RepoRoot
    $skillsRoot = Join-Path $root "skills"
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)
}

function Get-ProjectWorkflowSkillNames {
    param([string]$RepoRoot)

    @(Get-ProjectActiveSkillNames -RepoRoot $RepoRoot | Where-Object { $_ -ne "advanced-user-input" })
}

function Get-ProjectFinalCapableSkillNames {
    @("align-project", "loop-controller", "merge-changes")
}

function Get-ProjectUserSkillNames {
    @("advanced-user-input")
}

function Get-ProjectRetiredSkillNames {
    @(
        "using-milestones",
        "setup-project-milestones",
        "explore-ideas",
        "milestone-writing-issue-plan",
        "convert-idea-to-issue",
        "project-writing-plan",
        "plan-to-issue",
        "resolve-issue-with-goal",
        "milestones-doctor",
        "project-context",
        "superpowers-project",
        "project-setup",
        "project-orchestrate",
        "project-brainstorm",
        "project-plan",
        "project-issue",
        "project-resolve",
        "project-merge",
        "project-doctor",
        "workflow",
        "setup"
    )
}

function Get-ProjectOwnedSkillNames {
    param([string]$RepoRoot)

    @((Get-ProjectActiveSkillNames -RepoRoot $RepoRoot) + (Get-ProjectRetiredSkillNames) | Sort-Object -Unique)
}

function Get-ProjectCanonicalPromptNamespace {
    '$superpowers-project'
}
