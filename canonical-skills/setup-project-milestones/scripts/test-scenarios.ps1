[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$validator = Join-Path $scriptRoot "validate-setup-plan.ps1"
$skillFile = Join-Path (Split-Path $scriptRoot -Parent) "SKILL.md"
$yamlFile = Join-Path (Split-Path $scriptRoot -Parent) "agents\openai.yaml"

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        [pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }
    } catch {
        [pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Run-Validator {
    param([hashtable]$Plan)
    $json = $Plan | ConvertTo-Json -Depth 32 -Compress
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -PlanJson $json | ConvertFrom-Json
}

function Base-Plan {
    @{
        target_repo = "example/repo"
        target_repo_root = "C:\work\repo"
        source_docs = @(
            "https://docs.github.com/en/issues",
            "https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-the-issue-type-field"
        )
        full_roadmap = "docs/milestones/PROJECT_CONTEXT.md"
        full_roadmap_policy = "read-existing"
        milestone_policy = "mirror-full-roadmap"
        milestone_question_log = @(
            @{
                tool = "request_user_input"
                question = "Which milestones should this repo use?"
                agent_recommendation = @("M0 - Governance", "M1 - Packages")
                answer = "Use M0 - Governance and M1 - Packages."
            }
        )
        milestones = @(
            @{
                title = "M0 - Governance"
                folder = "M0-governance"
                description = "Roadmap, tracker, labels, forms, and process setup."
                source = "agent-proposed-user-approved"
                github_milestone = "create"
                local_readme = "docs/milestones/M0-governance/README.md"
                local_ideas_dir = "docs/milestones/M0-governance/ideas"
                local_issues_dir = "docs/milestones/M0-governance/issues"
            },
            @{
                title = "M1 - Packages"
                folder = "M1-packages"
                description = "Package layout and package-facing workflow setup."
                source = "agent-proposed-user-approved"
                github_milestone = "create"
                local_readme = "docs/milestones/M1-packages/README.md"
                local_ideas_dir = "docs/milestones/M1-packages/ideas"
                local_issues_dir = "docs/milestones/M1-packages/issues"
            }
        )
        project_policy = "dashboard-only"
        issue_types = @("bug", "feature", "task")
        labels = @("type:bug", "type:feature", "type:task", "status:triage", "status:ready", "status:blocked")
        issue_forms = @("bug", "feature", "task")
        local_files = @(
            "docs/milestones/PROJECT_CONTEXT.md",
            "docs/milestones/README.md",
            "docs/milestones/M0-governance/README.md",
            "docs/milestones/M0-governance/ideas/README.md",
            "docs/milestones/M0-governance/issues/README.md",
            "docs/milestones/M1-packages/README.md",
            "docs/milestones/M1-packages/ideas/README.md",
            "docs/milestones/M1-packages/issues/README.md",
            "docs/agents/project-roadmap.md",
            "docs/agents/project-roadmap.json",
            ".github/ISSUE_TEMPLATE/bug.yml",
            ".github/ISSUE_TEMPLATE/feature.yml",
            ".github/ISSUE_TEMPLATE/task.yml"
        )
        apply_policy = "default-branch-commit-push"
        projects_required_by_repo_config = $false
    }
}

$scenarios = @(
    Invoke-Scenario "happy setup plan passes" {
        $result = Run-Validator -Plan (Base-Plan)
        Assert-True $result.ok $result.reason
    }
    Invoke-Scenario "missing issue type blocks" {
        $plan = Base-Plan
        $plan.issue_types = @("bug", "feature")
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "bug, feature, and task") "expected issue type failure"
    }
    Invoke-Scenario "missing type labels blocks" {
        $plan = Base-Plan
        $plan.labels = @("type:bug", "type:feature")
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "type:bug") "expected label failure"
    }
    Invoke-Scenario "projects hard gate requires repo config" {
        $plan = Base-Plan
        $plan.project_policy = "repo-config-required"
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "repo config") "expected project policy failure"
    }
    Invoke-Scenario "milestone mirroring requires project context" {
        $plan = Base-Plan
        $plan.full_roadmap = "none"
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "full_roadmap|PROJECT_CONTEXT") "expected project context failure"
    }
    Invoke-Scenario "docs issues fallback blocks" {
        $plan = Base-Plan
        $plan.local_files += "docs/issues/README.md"
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "docs/issues") "expected docs/issues fallback failure"
    }
    Invoke-Scenario "global docs ideas folder blocks" {
        $plan = Base-Plan
        $plan.local_files += "docs/ideas/README.md"
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "docs/ideas") "expected global docs/ideas setup failure"
    }
    Invoke-Scenario "missing milestone idea folder blocks" {
        $plan = Base-Plan
        $plan.local_files = @($plan.local_files | Where-Object { $_ -ne "docs/milestones/M0-governance/ideas/README.md" })
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "milestone ideas README") "expected milestone ideas folder failure"
    }
    Invoke-Scenario "missing milestone question blocks" {
        $plan = Base-Plan
        $plan.milestone_question_log = @()
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "milestone_question_log") "expected milestone question failure"
    }
    Invoke-Scenario "missing milestone issue folder blocks" {
        $plan = Base-Plan
        $plan.local_files = @($plan.local_files | Where-Object { $_ -ne "docs/milestones/M0-governance/issues/README.md" })
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "milestone issues README") "expected milestone issues folder failure"
    }
    Invoke-Scenario "plans folder blocks" {
        $plan = Base-Plan
        $plan.local_files += "docs/milestones/M0-governance/plans/README.md"
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "plans") "expected plans folder failure"
    }
    Invoke-Scenario "execution branch fields block" {
        $plan = Base-Plan
        $plan.branch_policy = "create"
        $result = Run-Validator -Plan $plan
        Assert-True (-not $result.ok -and $result.reason -match "branch_policy") "expected branch_policy failure"
    }
    Invoke-Scenario "skill text covers setup contract" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match "setup-matt-pocock-skills") "missing Matt setup prerequisite"
        Assert-True ($text -match "bug`, `feature`, and `task|bug, feature, and task") "missing issue type categories"
        Assert-True ($text -match "docs/agents/project-roadmap.json") "missing project roadmap json"
        Assert-True ($text -match "docs/ideas.*legacy|legacy.*docs/ideas") "missing docs/ideas legacy warning"
        Assert-True ($text -match "docs/milestones/PROJECT_CONTEXT.md") "missing milestone context contract"
        Assert-True ($text -match "docs/milestones/<milestone-folder>/ideas") "missing milestone ideas folder contract"
        Assert-True ($text -match "docs/milestones/<milestone-folder>/issues") "missing milestone issues folder contract"
        Assert-True ($text -match "issue files are the execution plans") "missing issues-as-plans contract"
        Assert-True ($text -match "milestones-doctor") "missing existing-setup doctor route"
        Assert-True ($text -match "request_user_input") "missing milestone question UI contract"
        Assert-True ($text -match "default branch") "missing default branch apply rule"
        Assert-True ($text -match "Projects are dashboard") "missing Projects dashboard rule"
    }
    Invoke-Scenario "openai yaml exists" {
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-True ($text -match "setup-project-milestones") "missing openai yaml skill key"
        Assert-True ($text -match "milestones-doctor") "missing doctor routing summary"
        Assert-True ($text -match "bug/feature/task") "missing issue type summary"
        Assert-True ($text -match "docs/milestones") "missing milestones folder summary"
        Assert-True ($text -match "PROJECT_CONTEXT") "missing milestone context summary"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
