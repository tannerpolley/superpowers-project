[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$auditScript = Join-Path $scriptRoot "align-project.ps1"
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

function ConvertTo-JsonText {
    param($Value, [int]$Depth = 12)
    $text = $Value | ConvertTo-Json -Depth $Depth -Compress
    if ($null -eq $text) { return "" }
    [string]$text
}

function Invoke-JsonScript {
    param([string]$ScriptPath, [string[]]$Arguments)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $raw = ($output | Out-String).Trim()
    try {
        if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty output" }
        return ($raw | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{ ok = $false; phase = "align-project"; reason = $raw }
    }
}

function New-TestRepo {
    $repo = Join-Path ([IO.Path]::GetTempPath()) ("align-project-audit-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path (Join-Path $repo "docs/superpowers/issues") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "docs/superpowers/milestones") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/PROJECT_CONTEXT.md") -Value "# Project Context`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/milestones/M1-source-of-truth.md") -Value "# M1 - Source Of Truth`n`n## Related Issues`n`n- ``docs/superpowers/issues/12-sample.md```n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/12-sample.md") -Value "# Sample`n`n**GitHub Issue:** https://github.com/example/repo/issues/12`n**GitHub Milestone:** M1 - Source Of Truth`n**Source Plan:** docs/superpowers/plans/2026-06-02-sample-plan.md`n**Classification:** AFK`n`n## Acceptance Criteria`n`n- [x] Sample issue is resolved.`n" -Encoding utf8NoBOM
    & git -C $repo init -b main | Out-Null
    & git -C $repo config user.email tests@example.invalid | Out-Null
    & git -C $repo config user.name "Align Project Tests" | Out-Null
    & git -C $repo add . | Out-Null
    & git -C $repo commit -m initial | Out-Null
    $repo
}

function New-IssueFixture {
    param([string]$Path, [object[]]$Issues)
    @{ issues = @($Issues) } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: align-project" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Align" "missing title"
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
            Assert-Contains $text $needle "missing align audit contract: $needle"
        }
    }
    Invoke-Scenario "flat artifact root drift contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "flat canonical roots",
            "spec -> plan -> issue",
            "docs/superpowers/specs",
            "docs/superpowers/plans",
            "docs/superpowers/issues",
            "Milestone pages are index views",
            "frontmatter plus milestone indexes",
            "nested canonical milestone artifact folders are drift",
            "generated index/view output"
        )) {
            Assert-Contains $text $needle "missing flat artifact root align contract: $needle"
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
        Assert-Contains $metadata "default_prompt:" "missing metadata default_prompt"
        Assert-Contains $metadata "docs/superpowers/PROJECT_CONTEXT.md" "missing metadata project context path"
        Assert-Contains $metadata "live plugin sync drift" "missing metadata live sync drift"
        Assert-Contains $metadata "nested canonical milestone artifact folders are drift" "missing metadata nested artifact drift"
        Assert-Contains $metadata "generated index/view output" "missing metadata generated view exception"
        foreach ($needle in @("summarize", "artifact review gate", "broader project context", "recommended next route", "machine-readable artifacts", "project_align_next_step", "top-level continuation gate", "docs/superpowers/workflow-contract.yml", "child routes", "starting the selected next skill")) {
            Assert-Contains $metadata $needle "missing metadata continuation route: $needle"
        }
    }
    Invoke-Scenario "native continuation gate is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "## Native Continuation Gate",
            "skills/advanced-user-input/SKILL.md",
            "artifact review gate",
            "route-specific artifact inventory:",
            "blocking findings",
            "repairable findings",
            "healthy checks",
            "skipped checks",
            "machine-readable artifacts",
            "Review First",
            "stop",
            "request_user_input",
            "start the selected next skill",
            "project_align_next_step",
            "Apply Repair",
            "Create Planning Spec",
            "Run Align Again",
            "Stop"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }
    Invoke-Scenario "scripted audit contract is present" {
        if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) { throw "missing align-project.ps1" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "skills/align-project/scripts/align-project.ps1",
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
            "closed-mirror-lifecycle",
            "dirty-worktree"
        )) {
            Assert-Contains $allFindingText $needle "missing local docs audit dimension: $needle"
        }
        if ($audit.mutation_allowed -ne $false) { throw "Align audit must not allow mutation" }
        Assert-Contains ($audit.repair_policy | ConvertTo-Json -Depth 8) "request_user_input" "missing native repair approval policy"
    }
    Invoke-Scenario "LocalDocs reports full plugin live drift" {
        $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("align-live-sync-" + [guid]::NewGuid().ToString("N"))
        try {
            $livePluginRoot = Join-Path $fixtureRoot "plugins\superpowers-project"
            $userSkillsRoot = Join-Path $fixtureRoot "user-skills"
            $marketplacePath = Join-Path $fixtureRoot "marketplace.json"
            New-Item -ItemType Directory -Path $livePluginRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $userSkillsRoot -Force | Out-Null

            Copy-Item -LiteralPath (Join-Path $repoRoot ".codex-plugin") -Destination (Join-Path $livePluginRoot ".codex-plugin") -Recurse
            if (Test-Path -LiteralPath (Join-Path $repoRoot "assets") -PathType Container) {
                Copy-Item -LiteralPath (Join-Path $repoRoot "assets") -Destination (Join-Path $livePluginRoot "assets") -Recurse
            }
            New-Item -ItemType Directory -Path (Join-Path $livePluginRoot "scripts") -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\lib") -Destination (Join-Path $livePluginRoot "scripts\lib") -Recurse
            Copy-Item -LiteralPath (Join-Path $repoRoot "skills") -Destination (Join-Path $livePluginRoot "skills") -Recurse
            Copy-Item -LiteralPath (Join-Path $repoRoot "skills\advanced-user-input") -Destination (Join-Path $userSkillsRoot "advanced-user-input") -Recurse

            [pscustomobject]@{
                name = "personal"
                interface = [pscustomobject]@{ displayName = "Personal" }
                plugins = @(
                    [pscustomobject]@{
                        name = "superpowers-project"
                        source = [pscustomobject]@{ source = "local"; path = "./plugins/superpowers-project" }
                        policy = [pscustomobject]@{ installation = "AVAILABLE"; authentication = "ON_INSTALL" }
                        category = "Productivity"
                    }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $marketplacePath -Encoding utf8NoBOM

            Add-Content -LiteralPath (Join-Path $livePluginRoot "skills\merge-changes\agents\openai.yaml") -Value "# fixture drift"
            $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $repoRoot -Mode LocalDocs -LivePluginRoot $livePluginRoot -UserSkillsRoot $userSkillsRoot -MarketplacePath $marketplacePath
            if ($LASTEXITCODE -ne 0) { throw "LocalDocs audit failed: $raw" }
            $audit = $raw | ConvertFrom-Json
            $repairableText = [string]($audit.findings.repairable | ConvertTo-Json -Depth 20)
            Assert-Contains $repairableText "live-sync" "full live sync drift was not reported"
            Assert-Contains $repairableText "plugin skill merge-changes" "non-Align plugin skill drift was not reported"
        } finally {
            if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
        }
    }
    Invoke-Scenario "dirty worktree is repairable drift" {
        $repo = New-TestRepo
        try {
            Set-Content -LiteralPath (Join-Path $repo "DIRTY.txt") -Value "dirty`n" -Encoding utf8NoBOM
            $audit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "LocalDocs")
            Assert-Contains (($audit.findings.repairable | ConvertTo-Json -Depth 12)) "dirty-worktree" "dirty repo was not reported as repairable drift"
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }
    Invoke-Scenario "product repo without Align source skips native closeout repair" {
        $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("align-project-product-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/superpowers/milestones") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/superpowers/specs") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/superpowers/plans") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/superpowers/issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/agents") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "scripts") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $fixtureRoot "docs/superpowers/PROJECT_CONTEXT.md") -Value "# Product Context`n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $fixtureRoot "docs/agents/triage-labels.md") -Value '`type:bug` `status:ready`' -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $fixtureRoot "scripts/sync-live.ps1") -Value "# product repo placeholder`n" -Encoding utf8NoBOM
            & git -C $fixtureRoot init -b main | Out-Null
            $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $fixtureRoot -Mode LocalDocs
            if ($LASTEXITCODE -ne 0) { throw "LocalDocs product fixture audit failed: $raw" }
            $audit = $raw | ConvertFrom-Json
            $repairableText = [string]($audit.findings.repairable | ConvertTo-Json -Depth 12)
            if ($null -eq $repairableText) { $repairableText = "" }
            if ($repairableText.Contains("native-ui-closeout")) { throw "absent Align source was reported as repairable" }
            $informationalText = [string]($audit.findings.informational | ConvertTo-Json -Depth 12)
            if ($null -eq $informationalText) { $informationalText = "" }
            Assert-Contains $informationalText "native-ui-closeout" "absent Align source skip was not informational"
        } finally {
            if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
        }
    }
    Invoke-Scenario "GitHub-aware audit covers tracker drift with fixtures" {
        $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("align-project-audit-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        try {
            $issueFixture = Join-Path $fixtureRoot "issues.json"
            $milestoneFixture = Join-Path $fixtureRoot "milestones.json"
            $labelFixture = Join-Path $fixtureRoot "labels.json"
            @(
                [ordered]@{
                    number = 10
                    url = "https://github.com/tannerpolley/superpowers-project/issues/10"
                    state = "OPEN"
                    title = "Add scripted Project Align drift audit"
                    body = "fixture body intentionally differs from the local mirror"
                    milestone = @{ title = "M1 - Source Of Truth" }
                    labels = @(@{ name = "type:feature" })
                }
                [ordered]@{
                    number = 404
                    url = "https://github.com/tannerpolley/superpowers-project/issues/404"
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

            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/superpowers/issues") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "docs/superpowers/milestones") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $fixtureRoot "docs/superpowers/PROJECT_CONTEXT.md") -Value "# Project Context`n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $fixtureRoot "docs/superpowers/milestones/M1-source-of-truth.md") -Value "# M1 - Source Of Truth`n`n## Related Issues`n`n- ``docs/superpowers/issues/10-fixture.md```n- ``docs/superpowers/issues/404-closed-fixture.md```n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $fixtureRoot "docs/superpowers/issues/10-fixture.md") -Value "# Local Fixture Title`n`n**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/10`n**GitHub Milestone:** Local Milestone`n**Labels:** status:ready`n`n## Acceptance Criteria`n`n- [ ] Fixture remains intentionally drifted.`n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $fixtureRoot "docs/superpowers/issues/404-closed-fixture.md") -Value "# Closed Mirror Fixture`n`n**GitHub Issue:** https://github.com/tannerpolley/superpowers-project/issues/404`n**GitHub Milestone:** M1 - Source Of Truth`n**Labels:** type:feature, status:ready`n`n## Acceptance Criteria`n`n- [x] Fixture remains closed.`n" -Encoding utf8NoBOM

            $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -RepoRoot $fixtureRoot -Mode GitHubAware -IssueFixturePath $issueFixture -MilestoneFixturePath $milestoneFixture -LabelFixturePath $labelFixture
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
    Invoke-Scenario "GitHub-aware audit resolves repository metadata from roadmap repository" {
        $repo = New-TestRepo
        try {
            New-Item -ItemType Directory -Path (Join-Path $repo "docs/agents") -Force | Out-Null
            @{ repository = "example/repository-source" } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $repo "docs/agents/project-roadmap.json") -Encoding utf8NoBOM
            $issueFixture = Join-Path $repo "issue-fixture.json"
            New-IssueFixture -Path $issueFixture -Issues @(
                @{ number = 12; url = "https://github.com/example/repository-source/issues/12"; state = "OPEN"; title = "Sample"; labels = @("type:feature"); milestone = @{ title = "M1 - Source Of Truth" } }
            )
            $result = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-IssueFixturePath", $issueFixture)
            if (-not $result.ok) { throw $result.reason }
            if ($result.target_repo -ne "example/repository-source") { throw "repository metadata did not resolve target_repo" }
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }
    Invoke-Scenario "GitHub-aware issue mirror drift uses concise mirror metadata" {
        $repo = New-TestRepo
        try {
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/15-frontmatter-title.md") -Value "---`ntitle: Frontmatter Mirror Title`n---`n`n**GitHub Issue:** https://github.com/example/repo/issues/15`n**GitHub Milestone:** M1 - Source Of Truth`n**Labels:** type:bug, status:ready`n`n## Acceptance Criteria`n`n- [ ] Frontmatter title is parsed.`n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/16-h1-after-frontmatter.md") -Value "---`nowner: test`n---`n`n# H1 After Frontmatter`n`n**GitHub Issue:** https://github.com/example/repo/issues/16`n**GitHub Milestone:** M1 - Source Of Truth`n**Labels:** type:task, status:ready`n`n## Acceptance Criteria`n`n- [ ] H1 title is parsed after frontmatter.`n" -Encoding utf8NoBOM
            $issueFixture = Join-Path $repo "issue-fixture.json"
            New-IssueFixture -Path $issueFixture -Issues @(
                @{ number = 15; url = "https://github.com/example/repo/issues/15"; state = "OPEN"; title = "Frontmatter Mirror Title"; body = "Full GitHub body is intentionally not copied into the concise mirror."; labels = @("type:bug", "status:ready"); milestone = @{ title = "M1 - Source Of Truth" } },
                @{ number = 16; url = "https://github.com/example/repo/issues/16"; state = "OPEN"; title = "H1 After Frontmatter"; body = "Another full body intentionally omitted by the mirror."; labels = @("type:task", "status:ready"); milestone = @{ title = "M1 - Source Of Truth" } }
            )
            & git -C $repo add . | Out-Null
            & git -C $repo commit -m concise | Out-Null
            $result = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-IssueFixturePath", $issueFixture)
            if (-not $result.ok) { throw $result.reason }
            $repairableText = ConvertTo-JsonText $result.findings.repairable
            if ($repairableText.Contains("15-frontmatter-title.md") -or $repairableText.Contains("16-h1-after-frontmatter.md")) { throw "concise mirrors were reported as repairable drift" }
            $healthyText = ConvertTo-JsonText $result.findings.healthy
            Assert-Contains $healthyText "15-frontmatter-title.md" "frontmatter title mirror was not reported healthy"
            Assert-Contains $healthyText "16-h1-after-frontmatter.md" "H1 after frontmatter mirror was not reported healthy"
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }
    Invoke-Scenario "GitHub-aware issue mirror metadata drift is informational without repair receipt" {
        $repo = New-TestRepo
        try {
            $issueFixture = Join-Path $repo "issue-fixture.json"
            New-IssueFixture -Path $issueFixture -Issues @(
                @{ number = 12; url = "https://github.com/example/repo/issues/12"; state = "OPEN"; title = "Changed Sample Title"; labels = @("type:feature"); milestone = @{ title = "M1 - Source Of Truth" } }
            )
            $result = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-IssueFixturePath", $issueFixture)
            if (-not $result.ok) { throw $result.reason }
            $repairableText = ConvertTo-JsonText $result.findings.repairable
            if ($repairableText.Contains("mirror-github-drift")) { throw "manual mirror drift was reported as repairable" }
            $informationalText = ConvertTo-JsonText $result.findings.informational
            Assert-Contains $informationalText "mirror-github-drift" "manual mirror drift was not informational"
            Assert-Contains $informationalText "title" "manual mirror drift did not report the changed field"
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }
    Invoke-Scenario "align-project reports stale closed mirrors as repairable drift" {
        if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) { throw "missing align-project.ps1" }
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
    Invoke-Scenario "tracker hygiene audit and repair covers issue labels and Project V2 drift" {
        if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) { throw "missing align-project.ps1" }
        $repo = New-TestRepo
        try {
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/13-open.md") -Value "# Open Issue`n`n**GitHub Issue:** https://github.com/example/repo/issues/13`n**GitHub Milestone:** M1 - Source Of Truth`n**Labels:** type:feature, status:ready`n**Project Status:** Ready`n**Project Priority:** High`n`n## Acceptance Criteria`n`n- [ ] Open issue stays routed.`n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/14-missing-project.md") -Value "# Missing Project Item`n`n**GitHub Issue:** https://github.com/example/repo/issues/14`n**GitHub Milestone:** M1 - Source Of Truth`n**Labels:** type:task, status:triage`n**Project Status:** Triage`n`n## Acceptance Criteria`n`n- [ ] Missing Project item is reported.`n" -Encoding utf8NoBOM
            $issueFixture = Join-Path $repo "issue-fixture.json"
            $projectFixture = Join-Path $repo "project-fixture.json"
            @{
                issues = @(
                    @{ number = 12; url = "https://github.com/example/repo/issues/12"; state = "CLOSED"; title = "Sample"; labels = @("type:feature", "status:ready"); milestone = @{ title = "M1 - Source Of Truth" }; node_id = "ISSUE_12" },
                    @{ number = 13; url = "https://github.com/example/repo/issues/13"; state = "OPEN"; title = "Open Issue"; labels = @("type:feature"); milestone = @{ title = "M1 - Source Of Truth" }; node_id = "ISSUE_13" },
                    @{ number = 14; url = "https://github.com/example/repo/issues/14"; state = "OPEN"; title = "Missing Project Item"; labels = @("type:task", "status:triage"); milestone = @{ title = "M1 - Source Of Truth" }; node_id = "ISSUE_14" }
                )
            } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $issueFixture -Encoding utf8NoBOM
            @{
                project = @{ number = 7; owner = "example"; title = "Canonical Project"; id = "PROJECT_7" }
                status_field = @{ id = "FIELD_STATUS"; name = "Status"; options = @(@{ id = "OPT_TRIAGE"; name = "Triage" }, @{ id = "OPT_READY"; name = "Ready" }, @{ id = "OPT_DONE"; name = "Done" }) }
                fields = @(@{ id = "FIELD_PRIORITY"; name = "Priority"; options = @(@{ id = "OPT_HIGH"; name = "High" }) })
                items = @(
                    @{ id = "ITEM_12"; type = "Issue"; issue_number = 12; content_id = "ISSUE_12"; status = "Ready"; fields = @{ Priority = "High" } },
                    @{ id = "ITEM_13"; type = "Issue"; issue_number = 13; content_id = "ISSUE_13"; status = "Done"; fields = @{ Priority = "Low" } },
                    @{ id = "DRAFT_1"; type = "DraftIssue"; title = "Unpublished cleanup note"; status = "Triage"; fields = @{} }
                )
            } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $projectFixture -Encoding utf8NoBOM

            $audit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-TrackerHygiene", "-IssueFixturePath", $issueFixture, "-ProjectFixturePath", $projectFixture)
            if (-not $audit.ok) { throw $audit.reason }
            if ($audit.mutation_allowed -ne $false) { throw "tracker hygiene audit mutated by default" }
            $findingText = $audit.findings | ConvertTo-Json -Depth 20 -Compress
            foreach ($needle in @("closed-status-label-drift", "missing-routing-label", "open-project-done-mismatch", "missing-project-item", "project-field-drift", "project-draft-item")) {
                Assert-Contains $findingText $needle "missing tracker hygiene finding: $needle"
            }

            $repair = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-TrackerHygiene", "-ApplyTrackerRepairs", "-IssueFixturePath", $issueFixture, "-ProjectFixturePath", $projectFixture)
            if (-not $repair.ok) { throw $repair.reason }
            if ($repair.mutation_allowed -ne $true) { throw "repair mode did not mark mutation_allowed true" }
            $receiptText = $repair.repair_receipt | ConvertTo-Json -Depth 20 -Compress
            foreach ($needle in @("remove-label", "set-project-status", "add-project-item", "set-project-field", "ISSUE_12", "ITEM_12", "ISSUE_14", "FIELD_PRIORITY")) {
                Assert-Contains $receiptText $needle "missing repair receipt entry: $needle"
            }
            if ($receiptText.Contains("DRAFT_1") -and $receiptText.Contains("delete")) { throw "draft Project item must not be deleted automatically" }
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }

    Invoke-Scenario "GitHub-aware audit resolves target repo from roadmap and git remote" {
        $targetRepo = New-TestRepo
        $remoteRepo = New-TestRepo
        try {
            New-Item -ItemType Directory -Path (Join-Path $targetRepo "docs/agents") -Force | Out-Null
            @{ target_repo = "ePC-SAFT/ePC-SAFT"; target_repo_root = $targetRepo } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $targetRepo "docs/agents/project-roadmap.json") -Encoding utf8NoBOM
            $targetAudit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $targetRepo, "-Mode", "GitHubAware")
            if (-not $targetAudit.ok) { throw $targetAudit.reason }
            if ($targetAudit.target_repo -ne "ePC-SAFT/ePC-SAFT") { throw "target_repo was not read from roadmap target_repo" }

            & git -C $remoteRepo init -b main | Out-Null
            & git -C $remoteRepo remote add origin "git@github.com:example/from-remote.git" | Out-Null
            $remoteAudit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $remoteRepo, "-Mode", "GitHubAware")
            if (-not $remoteAudit.ok) { throw $remoteAudit.reason }
            if ($remoteAudit.target_repo -ne "example/from-remote") { throw "target_repo was not parsed from git remote" }
        } finally {
            foreach ($repo in @($targetRepo, $remoteRepo)) {
                if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
            }
        }
    }

    Invoke-Scenario "concise frontmatter issue mirrors compare structured GitHub fields without body drift" {
        $repo = New-TestRepo
        try {
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/15-frontmatter.md") -Value "---`ntitle: Concise Mirror`n---`n`n# Concise Mirror`n`n**GitHub Issue:** https://github.com/example/repo/issues/15`n**GitHub Milestone:** M1 - Source Of Truth`n**Labels:** type:task, status:ready`n`n## Acceptance Criteria`n`n- [ ] Concise mirror remains enough for audit.`n" -Encoding utf8NoBOM
            $issueFixture = Join-Path $repo "issue-fixture.json"
            @{
                issues = @(
                    @{ number = 15; url = "https://github.com/example/repo/issues/15"; state = "OPEN"; title = "Concise Mirror"; body = "The full GitHub body is intentionally longer than the concise mirror."; labels = @("type:task", "status:ready"); milestone = @{ title = "M1 - Source Of Truth" }; node_id = "ISSUE_15" }
                )
            } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $issueFixture -Encoding utf8NoBOM
            $audit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-IssueFixturePath", $issueFixture)
            if (-not $audit.ok) { throw $audit.reason }
            $repairableText = ConvertTo-JsonText $audit.findings.repairable -Depth 20
            if ($repairableText.Contains("mirror-github-drift")) { throw "concise body mirror drift must not be repairable" }
            $healthyText = ConvertTo-JsonText $audit.findings.healthy -Depth 20
            Assert-Contains $healthyText "Issue mirror matches inspected GitHub issue fields" "concise mirror did not compare healthy"
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }

    Invoke-Scenario "align-project reports native issue type drift and label-only fallback" {
        $repo = New-TestRepo
        try {
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/16-type-drift.md") -Value "# Type Drift`n`n**GitHub Issue:** https://github.com/example/repo/issues/16`n**GitHub Milestone:** M1 - Source Of Truth`n**Issue Type:** feature`n**Labels:** type:feature, status:ready`n`n## Acceptance Criteria`n`n- [ ] Native type drift is reported.`n" -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/issues/17-label-only.md") -Value "# Label Only`n`n**GitHub Issue:** https://github.com/example/repo/issues/17`n**GitHub Milestone:** M1 - Source Of Truth`n**Issue Type:** task`n**Labels:** type:task, status:ready`n`n## Acceptance Criteria`n`n- [ ] Label-only repos continue explicitly.`n" -Encoding utf8NoBOM
            $issueFixture = Join-Path $repo "issue-fixture.json"
            @{
                issues = @(
                    @{ number = 16; url = "https://github.com/example/repo/issues/16"; state = "OPEN"; title = "Type Drift"; body = "body"; labels = @("type:feature", "status:ready"); milestone = @{ title = "M1 - Source Of Truth" }; node_id = "ISSUE_16"; issueType = @{ name = "Bug" } },
                    @{ number = 17; url = "https://github.com/example/repo/issues/17"; state = "OPEN"; title = "Label Only"; body = "body"; labels = @("type:task", "status:ready"); milestone = @{ title = "M1 - Source Of Truth" }; node_id = "ISSUE_17"; issueType = $null }
                )
            } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $issueFixture -Encoding utf8NoBOM
            $audit = Invoke-JsonScript -ScriptPath $auditScript -Arguments @("-RepoRoot", $repo, "-Mode", "GitHubAware", "-TrackerHygiene", "-IssueFixturePath", $issueFixture)
            if (-not $audit.ok) { throw $audit.reason }
            $informationalText = $audit.findings.informational | ConvertTo-Json -Depth 20 -Compress
            Assert-Contains $informationalText "native_issue_type" "native issue type drift was not reported"
            Assert-Contains $informationalText "native-issue-type-label-only" "label-only native issue type fallback was not reported"
        } finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force }
        }
    }

    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        $globalPolicyNeedles = @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )
        foreach ($needle in $globalPolicyNeedles) {
            if ($text.Contains($needle)) { throw "SKILL.md duplicates helper-owned global policy instead of compact contract reference: $needle" }
            if ($metadata.Contains($needle)) { throw "metadata duplicates native continuation policy instead of compact contract reference: $needle" }
        }
        foreach ($needle in @(
            "skills/advanced-user-input/SKILL.md",
            "global native question geometry",
            "route-specific question IDs",
            "selected answers are executable routing"
        )) {
            if (-not $text.Contains($needle)) { throw "missing compact native continuation helper reference: $needle" }
        }

        foreach ($needle in @(
            "docs/superpowers/workflow-contract.yml",
            "project_align_next_step",
            "top-level continuation gate",
            "child routes",
            "starting the selected next skill"
        )) {
            if (-not $metadata.Contains($needle)) { throw "missing compact continuation metadata: $needle" }
        }

        $questionIds = [regex]::Matches($text, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $text.Length }
            $block = $text.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: terminal option: break the continuation loop.')) {
                throw "nested question $questionId must not repeat stale terminal label"
            }
        }

        if ($metadata.Contains("Right terminal label")) { throw "metadata must not use old Right terminal label wording" }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
