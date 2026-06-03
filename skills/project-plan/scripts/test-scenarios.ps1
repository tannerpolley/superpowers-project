[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
$quickApplyScript = Join-Path $scriptRoot "validate-quick-apply.ps1"
$script:quickApplyFixtureRoots = [System.Collections.Generic.List[string]]::new()

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

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw $Message }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Git {
    param([string]$Repo, [string[]]$Arguments)
    $output = & git -C $Repo @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output | Out-String)"
    }
    $output
}

function New-QuickApplyFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) "project-plan-quick-apply-$([guid]::NewGuid().ToString('N'))"
    $origin = Join-Path $root "origin.git"
    $repo = Join-Path $root "repo"
    $script:quickApplyFixtureRoots.Add($root)
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    & git init --bare $origin 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git init --bare failed" }
    & git clone $origin $repo 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
    Invoke-Git $repo @("switch", "-c", "main") | Out-Null
    Invoke-Git $repo @("config", "user.email", "codex@example.test") | Out-Null
    Invoke-Git $repo @("config", "user.name", "Codex Test") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $repo "docs/superpowers/plans") | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "docs/superpowers/plans/quick-plan.md") -Value "# Quick Plan" -Encoding utf8NoBOM
    Invoke-Git $repo @("add", ".") | Out-Null
    Invoke-Git $repo @("commit", "-m", "init") | Out-Null
    Invoke-Git $repo @("push", "-u", "origin", "main") | Out-Null
    $repo
}

function Invoke-QuickApplyGate {
    param([string]$Repo, [hashtable]$Extra)
    $approval = if ($Extra -and $Extra.ContainsKey("ApprovalJson")) { $Extra["ApprovalJson"] } else { @{ question_id = "project_quick_apply_approval"; selected_action = "apply" } | ConvertTo-Json -Depth 8 -Compress }
    $verification = if ($Extra -and $Extra.ContainsKey("VerificationJson")) { $Extra["VerificationJson"] } else { @{ passed = $true; commands = @(@{ command = "pwsh test"; passed = $true }) } | ConvertTo-Json -Depth 8 -Compress }
    $cleanup = if ($Extra -and $Extra.ContainsKey("CleanupJson")) { $Extra["CleanupJson"] } else { @{ passed = $true; command = "codex-cleanup.ps1" } | ConvertTo-Json -Depth 8 -Compress }
    $arguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", $quickApplyScript,
        "-RepoRoot", $Repo,
        "-PlanPath", "docs/superpowers/plans/quick-plan.md",
        "-ApprovalJson", $approval,
        "-VerificationJson", $verification,
        "-CleanupJson", $cleanup
    )
    if ($Extra) {
        foreach ($key in $Extra.Keys) {
            if ($key -in @("ApprovalJson", "VerificationJson", "CleanupJson")) { continue }
            if ($Extra[$key] -is [switch] -or $Extra[$key] -eq $true) {
                $arguments += "-$key"
            } elseif ($Extra[$key] -ne $false -and $null -ne $Extra[$key]) {
                $arguments += "-$key"
                $arguments += $Extra[$key]
            }
        }
    }
    $output = & pwsh.exe @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $json = ($output | Out-String).Trim()
    try {
        $result = $json | ConvertFrom-Json
    } catch {
        $result = [pscustomobject]@{ ok = $false; reason = $json }
    }
    $result | Add-Member -NotePropertyName exit_code -NotePropertyValue $exitCode -Force
    $result
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter is valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-Contains $text "name: project-plan" "missing skill name"
        Assert-Contains $text "description: Use when" "description must start with Use when"
        Assert-Contains $text "# Project Plan" "missing skill title"
    }
    Invoke-Scenario "superpowers writing contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        foreach ($needle in @(
            "superpowers:writing-plans",
            "docs/superpowers/plans",
            "docs/superpowers/specs",
            "docs/superpowers/issues",
            "request_user_input",
            "Interview me relentlessly about every aspect of this plan",
            "superpowers:test-driven-development",
            "superpowers:systematic-debugging",
            "superpowers:verification-before-completion"
        )) {
            Assert-Contains $text $needle "missing project-plan contract: $needle"
        }
    }
    Invoke-Scenario "old milestone issue target is retired" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-NotContains $text "docs/milestones/<milestone-folder>/issues" "old milestone issues path must not be active"
    }
    Invoke-Scenario "metadata routes to project plan" {
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $text = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "project-plan:" "missing metadata key"
        Assert-Contains $text "docs/superpowers/plans" "missing metadata plan path"
        Assert-Contains $text "superpowers:writing-plans" "missing metadata Superpowers route"
        Assert-Contains $text "request_user_input" "missing metadata native question policy"
        Assert-Contains $text "project_plan_next_step" "missing continuation question id"
        Assert-Contains $text "start the selected next skill" "missing executable routing guidance"
        foreach ($needle in @("summarize", "Project Issue First", "Quick Apply", "Review First", "Revise Plan")) {
            Assert-Contains $text $needle "missing metadata continuation route: $needle"
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
            "project_plan_next_step",
            "Project Issue First",
            "Quick Apply",
            "Revise Plan",
            "start the selected next skill",
            "Do not only tell the user what to prompt next"
        )) {
            Assert-Contains $text $needle "missing continuation gate text: $needle"
        }
    }
    Invoke-Scenario "quick apply approval gate is documented" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "project_quick_apply_approval",
            "Apply on Main",
            "Use Issue Flow",
            "validate-quick-apply.ps1",
            "clean synced ``main``",
            "verification commands",
            "cleanup hook",
            "push"
        )) {
            Assert-Contains $text $needle "missing Quick Apply skill contract: $needle"
            Assert-Contains $metadata $needle "missing Quick Apply metadata contract: $needle"
        }
    }
    Invoke-Scenario "quick apply gate blocks unsafe states and allows approved verified main" {
        if (-not (Test-Path -LiteralPath $quickApplyScript -PathType Leaf)) { throw "missing validate-quick-apply.ps1" }

        $repo = New-QuickApplyFixture
        $result = Invoke-QuickApplyGate -Repo $repo
        Assert-True ($result.ok -eq $true) "clean synced main should pass"

        $dirtyRepo = New-QuickApplyFixture
        Set-Content -LiteralPath (Join-Path $dirtyRepo "dirty.txt") -Value "dirty" -Encoding utf8NoBOM
        $result = Invoke-QuickApplyGate -Repo $dirtyRepo
        Assert-True ($result.ok -eq $false -and $result.reason -match "dirty") "dirty state should fail"

        $branchRepo = New-QuickApplyFixture
        Invoke-Git $branchRepo @("switch", "-c", "feature") | Out-Null
        $result = Invoke-QuickApplyGate -Repo $branchRepo
        Assert-True ($result.ok -eq $false -and $result.reason -match "main") "non-main branch should fail"

        $unsyncedRepo = New-QuickApplyFixture
        Set-Content -LiteralPath (Join-Path $unsyncedRepo "ahead.txt") -Value "ahead" -Encoding utf8NoBOM
        Invoke-Git $unsyncedRepo @("add", ".") | Out-Null
        Invoke-Git $unsyncedRepo @("commit", "-m", "ahead") | Out-Null
        $result = Invoke-QuickApplyGate -Repo $unsyncedRepo
        Assert-True ($result.ok -eq $false -and $result.reason -match "synced") "unsynced main should fail"

        $repo = New-QuickApplyFixture
        $result = Invoke-QuickApplyGate -Repo $repo -Extra @{ ApprovalJson = "" }
        Assert-True ($result.ok -eq $false -and $result.reason -match "approval") "missing approval should fail"

        $repo = New-QuickApplyFixture
        $result = Invoke-QuickApplyGate -Repo $repo -Extra @{ VerificationJson = "" }
        Assert-True ($result.ok -eq $false -and $result.reason -match "verification") "missing verification should fail"

        $repo = New-QuickApplyFixture
        $result = Invoke-QuickApplyGate -Repo $repo -Extra @{ CleanupJson = "" }
        Assert-True ($result.ok -eq $false -and $result.reason -match "cleanup") "missing cleanup should fail"

        $repo = New-QuickApplyFixture
        $result = Invoke-QuickApplyGate -Repo $repo -Extra @{ AllowPush = $true }
        Assert-True ($result.ok -eq $false -and $result.reason -match "push") "unapproved push should fail"
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
foreach ($fixtureRoot in $script:quickApplyFixtureRoots) {
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf).StartsWith("project-plan-quick-apply-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
