[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$auditScript = Join-Path $scriptRoot "audit-project.ps1"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $skillRoot "..\..")).Path

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        [pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }
    } catch {
        [pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }
    }
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Invoke-JsonScript {
    param([string]$ScriptPath, [string[]]$Arguments)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $raw = ($output | Out-String).Trim()
    try {
        if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty output" }
        return ($raw | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{ ok = $false; phase = "audit-project"; reason = $raw }
    }
}

function New-TestRepo {
    $repo = Join-Path ([IO.Path]::GetTempPath()) ("project-doctor-audit-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path (Join-Path $repo "docs/superpowers/issues") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "docs/superpowers/milestones") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/PROJECT_CONTEXT.md") -Value "# Project Context`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/milestones/M1-source-of-truth.md") -Value "# M1 - Source Of Truth`n`n## Related Issues`n`n- ``docs/superpowers/issues/12-sample.md```n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/12-sample.md") -Value "# Sample`n`n**GitHub Issue:** https://github.com/example/repo/issues/12`n**GitHub Milestone:** M1 - Source Of Truth`n**Source Plan:** docs/superpowers/plans/2026-06-02-sample-plan.md`n**Classification:** AFK`n`n## Acceptance Criteria`n`n- [x] Sample issue is resolved.`n" -Encoding utf8NoBOM
    $repo
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: project-doctor" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Doctor" "missing title"
    }
    Invoke-Scenario "audit surface contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "docs/superpowers/PROJECT_CONTEXT.md",
            "docs/superpowers/milestones",
            "docs/superpowers/specs",
            "docs/superpowers/plans",
            "docs/superpowers/issues",
            "GitHub issue mirror fields",
            "GitHub milestone linkage",
            "label vocabulary",
            "retired docs/milestones canonical usage",
            "live plugin sync drift"
        )) {
            Assert-Contains $text $needle "missing doctor audit contract: $needle"
        }
    }
    Invoke-Scenario "report-first and drift categories are present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @("report-first", "no mutation without user approval", "blocking", "repairable", "informational", "healthy", "migration report", "goal execution checks")) {
            Assert-Contains $text $needle "missing report/drift contract: $needle"
        }
    }
    Invoke-Scenario "metadata is present" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $metadata "project-doctor:" "missing metadata key"
        Assert-Contains $metadata "docs/superpowers/PROJECT_CONTEXT.md" "missing metadata project context path"
        Assert-Contains $metadata "live plugin sync drift" "missing metadata live sync drift"
        foreach ($needle in @("summarize", "project_doctor_next_step", "Apply Repair", "Create Planning Spec", "Run Audit Again", "Stop", "start the selected next skill")) {
            Assert-Contains $metadata $needle "missing metadata continuation route: $needle"
        }
    }
    Invoke-Scenario "native continuation gate is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Native Continuation Gate",
            "summarize",
            "Review First",
            "stop",
            "request_user_input",
            "start the selected next skill",
            "project_doctor_next_step",
            "Apply Repair",
            "Create Planning Spec",
            "Run Audit Again",
            "Stop"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }
    Invoke-Scenario "scripted audit contract is present" {
        if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) { throw "missing audit-project.ps1" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "audit-project.ps1",
            "-Mode LocalDocs",
            "-Mode GitHubAware",
            "blocking",
            "repairable",
            "informational",
            "healthy",
            "native repair approval"
        )) {
            Assert-Contains $text $needle "missing scripted audit doc contract: $needle"
            Assert-Contains $metadata $needle "missing scripted audit metadata contract: $needle"
        }
    }
    Invoke-Scenario "local docs audit reports structured drift categories" {
        $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $repoRoot -Mode LocalDocs
        if ($LASTEXITCODE -ne 0) { throw "LocalDocs audit failed: $raw" }
        $audit = $raw | ConvertFrom-Json
        if (-not $audit.ok) { throw "LocalDocs audit did not report ok" }
        foreach ($category in @("blocking", "repairable", "informational", "healthy")) {
            if ($audit.findings.PSObject.Properties.Name -notcontains $category) { throw "missing finding category: $category" }
        }
        $allFindingText = ($audit.findings | ConvertTo-Json -Depth 20)
        foreach ($needle in @(
            "native-ui-closeout",
            "ignored-path-traps",
            "live-sync",
            "closed-mirror-lifecycle"
        )) {
            Assert-Contains $allFindingText $needle "missing local docs audit dimension: $needle"
        }
        if ($audit.mutation_allowed -ne $false) { throw "Doctor audit must not allow mutation" }
        Assert-Contains ($audit.repair_policy | ConvertTo-Json -Depth 8) "request_user_input" "missing native repair approval policy"
    }
    Invoke-Scenario "GitHub-aware audit covers tracker drift with fixtures" {
        $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("project-doctor-audit-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        try {
            $issueFixture = Join-Path $fixtureRoot "issues.json"
            $milestoneFixture = Join-Path $fixtureRoot "milestones.json"
            $labelFixture = Join-Path $fixtureRoot "labels.json"
            @(
                [ordered]@{
                    number = 10
                    url = "https://github.com/tannerpolley/milestones-plugin/issues/10"
                    state = "OPEN"
                    title = "Add scripted Project Doctor drift audit"
                    body = "fixture body intentionally differs from the local mirror"
                    milestone = @{ title = "M1 - Source Of Truth" }
                    labels = @(@{ name = "type:feature" })
                }
                [ordered]@{
                    number = 404
                    url = "https://github.com/tannerpolley/milestones-plugin/issues/404"
                    state = "CLOSED"
                    title = "Closed mirror fixture"
                    body = "closed"
                    milestone = @{ title = "M1 - Source Of Truth" }
                    labels = @(@{ name = "type:feature" }, @{ name = "status:ready" })
                }
            ) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $issueFixture -Encoding utf8NoBOM
            @(
                [ordered]@{
                    title = "M1 - Source Of Truth"
                    issues = @(4, 5, 6)
                }
            ) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $milestoneFixture -Encoding utf8NoBOM
            @(
                [ordered]@{ name = "type:feature" },
                [ordered]@{ name = "status:ready" },
                [ordered]@{ name = "status:obsolete" }
            ) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $labelFixture -Encoding utf8NoBOM

            $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $repoRoot -Mode GitHubAware -IssueFixturePath $issueFixture -MilestoneFixturePath $milestoneFixture -LabelFixturePath $labelFixture
            if ($LASTEXITCODE -ne 0) { throw "GitHubAware audit failed: $raw" }
            $audit = $raw | ConvertFrom-Json
            foreach ($category in @("blocking", "repairable", "informational", "healthy")) {
                if ($audit.findings.PSObject.Properties.Name -notcontains $category) { throw "missing GitHubAware finding category: $category" }
            }
            $allFindingText = ($audit.findings | ConvertTo-Json -Depth 20)
            foreach ($needle in @(
                "milestone-membership-drift",
                "mirror-github-drift",
                "label-drift",
                "closed-mirror-lifecycle"
            )) {
                Assert-Contains $allFindingText $needle "missing GitHubAware audit dimension: $needle"
            }
            if ($audit.mode -ne "GitHubAware") { throw "GitHubAware mode not reported" }
            if ($audit.mutation_allowed -ne $false) { throw "GitHubAware audit must not allow mutation" }
        } finally {
            if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
                Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
            }
        }
    }
    Invoke-Scenario "audit-project reports stale closed mirrors as repairable drift" {
        if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) { throw "missing audit-project.ps1" }
        $repo = New-TestRepo
        try {
            $issueFixture = Join-Path $repo "issue-fixture.json"
            @{ issues = @(@{ number = 12; url = "https://github.com/example/repo/issues/12"; state = "CLOSED"; labels = @("status:done"); milestone = @{ title = "M1 - Source Of Truth" } }) } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $issueFixture -Encoding utf8NoBOM
            $result = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-IssueFixturePath", $issueFixture)
            if (-not $result.ok) { throw $result.reason }
            $repairableText = $result.findings.repairable | ConvertTo-Json -Depth 12 -Compress
            Assert-Contains $repairableText "stale closed issue mirror" "closed mirror was not reported as repairable drift"
            Assert-Contains $repairableText "docs/superpowers/issues/12-sample.md" "repairable drift did not name the stale mirror"
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
