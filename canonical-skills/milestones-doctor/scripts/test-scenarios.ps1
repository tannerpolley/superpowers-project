[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$auditScript = Join-Path $scriptRoot "audit-milestones.ps1"
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

function New-TestRepo {
    param([string]$Name)
    $root = Join-Path ([IO.Path]::GetTempPath()) ("milestones-doctor-" + [guid]::NewGuid().ToString("N") + "-" + $Name)
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $root
}

function Run-Audit {
    param([string]$RepoRoot)
    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $RepoRoot | ConvertFrom-Json
}

$scenarios = @(
    Invoke-Scenario "healthy milestone tree passes audit" {
        $repo = New-TestRepo "healthy"
        foreach ($path in @(
            "docs\milestones\M0-governance\ideas",
            "docs\milestones\M0-governance\issues",
            "docs\agents"
        )) { New-Item -ItemType Directory -Path (Join-Path $repo $path) -Force | Out-Null }
        foreach ($file in @(
            "docs\milestones\PROJECT_CONTEXT.md",
            "docs\milestones\README.md",
            "docs\milestones\M0-governance\README.md",
            "docs\milestones\M0-governance\ideas\README.md",
            "docs\milestones\M0-governance\issues\README.md",
            "docs\agents\project-roadmap.md",
            "docs\agents\project-roadmap.json"
        )) { Set-Content -LiteralPath (Join-Path $repo $file) -Value "# test`n" -Encoding UTF8 }
        $result = Run-Audit -RepoRoot $repo
        Assert-True $result.ok $result.reason
        Assert-True ($result.reason -eq "milestone audit passed") "expected healthy audit"
    }
    Invoke-Scenario "missing project context is blocking" {
        $repo = New-TestRepo "missing-context"
        New-Item -ItemType Directory -Path (Join-Path $repo "docs\milestones") -Force | Out-Null
        $result = Run-Audit -RepoRoot $repo
        Assert-True $result.ok $result.reason
        Assert-True (@(@($result.evidence.findings.blocking) -match "PROJECT_CONTEXT").Count -gt 0) "expected project context blocking finding"
    }
    Invoke-Scenario "missing milestone ideas folder is repairable" {
        $repo = New-TestRepo "missing-ideas"
        foreach ($path in @("docs\milestones\M0-governance\issues", "docs\agents")) {
            New-Item -ItemType Directory -Path (Join-Path $repo $path) -Force | Out-Null
        }
        foreach ($file in @(
            "docs\milestones\PROJECT_CONTEXT.md",
            "docs\milestones\README.md",
            "docs\milestones\M0-governance\README.md",
            "docs\milestones\M0-governance\issues\README.md",
            "docs\agents\project-roadmap.md",
            "docs\agents\project-roadmap.json"
        )) { Set-Content -LiteralPath (Join-Path $repo $file) -Value "# test`n" -Encoding UTF8 }
        $result = Run-Audit -RepoRoot $repo
        Assert-True $result.ok $result.reason
        Assert-True (@(@($result.evidence.findings.repairable) -match "ideas_dir").Count -gt 0) "expected missing ideas_dir repair finding"
    }
    Invoke-Scenario "obsolete docs folders require review" {
        $repo = New-TestRepo "obsolete"
        foreach ($path in @(
            "docs\ideas",
            "docs\issues",
            "docs\plans",
            "docs\milestones\M0-governance\plans"
        )) { New-Item -ItemType Directory -Path (Join-Path $repo $path) -Force | Out-Null }
        $result = Run-Audit -RepoRoot $repo
        Assert-True $result.ok $result.reason
        Assert-True (@($result.evidence.findings.review_needed).Count -ge 3) "expected obsolete path review findings"
        Assert-True (@(@($result.evidence.findings.review_needed) -match "docs/ideas").Count -gt 0) "expected global docs/ideas legacy finding"
    }
    Invoke-Scenario "skill text is report first" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match "report-first") "missing report-first contract"
        Assert-True ($text -match "must not delete") "missing delete guard"
        Assert-True ($text -match "docs/milestones/PROJECT_CONTEXT.md") "missing project context audit"
        Assert-True ($text -match "docs/milestones/<milestone-folder>/ideas") "missing milestone ideas audit"
        Assert-True ($text -match "docs/milestones/<milestone-folder>/issues") "missing milestone issues audit"
        Assert-True ($text -match "explicit approval") "missing approval gate"
    }
    Invoke-Scenario "openai yaml exists" {
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-True ($text -match "milestones-doctor") "missing openai yaml skill key"
        Assert-True ($text -match "audit") "missing audit prompt"
        Assert-True ($text -match "do not mutate") "missing mutation guard"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
