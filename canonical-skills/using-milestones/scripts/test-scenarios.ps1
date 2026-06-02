[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$pluginWrapper = "C:\Users\Tanner\plugins\milestones\skills\using-milestones\SKILL.md"

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

$requiredRoutes = @(
    '$setup-project-milestones',
    '$milestones-doctor',
    '$explore-ideas',
    'superpowers:brainstorming',
    '$convert-idea-to-issue',
    '$milestone-writing-issue-plan',
    '$resolve-issue-with-goal'
)

$requiredSuperpowers = @(
    'superpowers:using-superpowers',
    'superpowers:brainstorming',
    'superpowers:writing-plans',
    'superpowers:test-driven-development',
    'superpowers:systematic-debugging',
    'superpowers:subagent-driven-development',
    'superpowers:requesting-code-review',
    'superpowers:receiving-code-review',
    'superpowers:verification-before-completion'
)

$requiredPathStrings = @(
    'docs/milestones/<milestone-folder>/ideas',
    'docs/milestones/<milestone-folder>/issues',
    'docs/ideas',
    'legacy only',
    'docs/plans',
    'docs/issues',
    'docs/milestones/<milestone-folder>/plans',
    'docs/roadmaps'
)

$scenarios = @(
    Invoke-Scenario "canonical skill metadata exists" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match '(?m)^---\s*\r?\nname: using-milestones') "missing using-milestones frontmatter"
        Assert-True ($text -match 'description: .*Milestones.*meta-router|description: .*Routes Milestones') "missing route-focused description"
        Assert-True ($text -match 'This is a meta-router only') "missing meta-router scope"
    }
    Invoke-Scenario "canonical skill contains required routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($route in $requiredRoutes) {
            Assert-True ($text.Contains($route)) "missing route: $route"
        }
        Assert-True ($text -match 'First-time setup') "missing first-time setup route label"
        Assert-True ($text -match 'Existing workflow audit, cleanup, migration, drift repair, or verification') "missing existing workflow route label"
        Assert-True ($text -match 'earliest unfinished phase') "missing mixed-phase routing rule"
    }
    Invoke-Scenario "canonical skill lists all Superpowers routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($route in $requiredSuperpowers) {
            Assert-True ($text.Contains($route)) "missing Superpowers route: $route"
        }
    }
    Invoke-Scenario "canonical skill enforces milestone path contract" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($value in $requiredPathStrings) {
            Assert-True ($text.Contains($value)) "missing path contract string: $value"
        }
        Assert-True ($text -match 'Idea briefs belong under') "missing idea brief path rule"
        Assert-True ($text -match 'Local issue files belong under') "missing local issue file path rule"
    }
    Invoke-Scenario "openai metadata contains required routes and path contract" {
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-True ($text -match 'version: 1') "missing yaml version"
        Assert-True ($text -match 'using-milestones:') "missing using-milestones yaml key"
        foreach ($route in ($requiredRoutes + $requiredSuperpowers)) {
            Assert-True ($text.Contains($route)) "missing yaml route: $route"
        }
        Assert-True ($text.Contains('docs/milestones/<milestone-folder>/ideas')) "missing yaml idea path"
        Assert-True ($text.Contains('docs/milestones/<milestone-folder>/issues')) "missing yaml issue path"
        Assert-True ($text -match 'legacy only') "missing yaml legacy docs/ideas policy"
        Assert-True ($text -match 'Do not implement workflow behavior') "missing yaml router-only warning"
    }
    Invoke-Scenario "plugin wrapper points to canonical skill" {
        $text = Get-Content -LiteralPath $pluginWrapper -Raw
        Assert-True ($text -match '(?m)^---\s*\r?\nname: using-milestones') "missing wrapper frontmatter"
        Assert-True ($text.Contains('C:\Users\Tanner\.agents\skills\using-milestones\SKILL.md')) "missing canonical wrapper path"
        Assert-True ($text -match 'namespace wrapper') "missing namespace wrapper wording"
        Assert-True ($text -match 'Read the canonical `SKILL.md`') "missing canonical read instruction"
        Assert-True ($text -match 'do not invent separate behavior') "missing no separate behavior warning"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
