[CmdletBinding()]
param(
    [switch]$LocalOnly,
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } })
}

function Invoke-JsonFile {
    param([string]$ScriptPath, [string[]]$Arguments)
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
    $text = ($raw | Out-String).Trim()
    try {
        return [pscustomobject]@{ exit_code = $LASTEXITCODE; json = ($text | ConvertFrom-Json); raw = $text }
    } catch {
        return [pscustomobject]@{ exit_code = $LASTEXITCODE; json = [pscustomobject]@{ ok = $false; reason = $text }; raw = $text }
    }
}

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output | Out-String)" }
    ($output | Out-String).Trim()
}

try {
    if (-not $LocalOnly) { throw "test-e2e-project-workflow requires -LocalOnly" }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("project-e2e-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tempRoot "repo"
    $origin = Join-Path $tempRoot "origin.git"
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    Invoke-Git -Root $repo -Arguments @("init", "-b", "main") | Out-Null
    Invoke-Git -Root $repo -Arguments @("config", "user.email", "tests@example.invalid") | Out-Null
    Invoke-Git -Root $repo -Arguments @("config", "user.name", "Project E2E Tests") | Out-Null
    Invoke-Git -Root $repo -Arguments @("config", "core.autocrlf", "false") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "docs\superpowers\plans") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "# Local Fixture`n" -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $repo "docs\superpowers\plans\sample-plan.md") -Value "# Sample Plan`n" -Encoding utf8NoBOM
    Invoke-Git -Root $repo -Arguments @("add", ".") | Out-Null
    Invoke-Git -Root $repo -Arguments @("commit", "-m", "initial") | Out-Null
    & git init --bare $origin | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git init --bare failed" }
    Invoke-Git -Root $repo -Arguments @("remote", "add", "origin", $origin) | Out-Null
    Invoke-Git -Root $repo -Arguments @("push", "-u", "origin", "main") | Out-Null
    Invoke-Git -Root $repo -Arguments @("checkout", "-b", "codex/e2e-smoke") | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "feature.txt") -Value "fixture change`n" -Encoding utf8NoBOM
    Invoke-Git -Root $repo -Arguments @("add", ".") | Out-Null
    Invoke-Git -Root $repo -Arguments @("commit", "-m", "fixture branch change") | Out-Null
    Invoke-Git -Root $repo -Arguments @("push", "-u", "origin", "codex/e2e-smoke") | Out-Null
    Invoke-Git -Root $repo -Arguments @("checkout", "main") | Out-Null
    Invoke-Git -Root $repo -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null

    $setupPath = Join-Path $tempRoot "setup-ledger.json"
    @{
        merge_mode = "local-branch"
        source_plan = "docs/superpowers/plans/sample-plan.md"
        branch = "codex/e2e-smoke"
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM
    $outDir = Join-Path $tempRoot "evidence"
    $prepare = Invoke-JsonFile -ScriptPath (Join-Path $RepoRoot "skills\merge-changes\scripts\prepare-local-branch-closeout.ps1") -Arguments @(
        "-RepoRoot", $repo,
        "-SetupLedgerPath", $setupPath,
        "-ValidationCommand", "exit 0",
        "-OutputDir", $outDir
    )
    Add-Check -Name "local branch prepare passes" -Ok ($prepare.exit_code -eq 0 -and $prepare.json.ok -eq $true) -Reason ([string]$prepare.json.reason)

    $doneDecision = @{
        skill = "merge-changes"
        question_id = "project_merge_final_health_gate"
        prompt = "Closeout proof is clean. Mark this workflow done?"
        source = "debug_question_mode"
        selected_option_id = "done"
        recommended_option_id = "done"
        option_ids = @("done", "revisit", "stop")
        terminal_state = "done"
    } | ConvertTo-Json -Depth 8 -Compress
    $blocked = Invoke-JsonFile -ScriptPath (Join-Path $RepoRoot "skills\merge-changes\scripts\validate-terminal-closeout.ps1") -Arguments @(
        "-RepoRoot", $repo,
        "-CloseoutResultJson", (@{ ok = $false; phase = "closeout"; reason = "missing closeout"; evidence = @{} } | ConvertTo-Json -Depth 8 -Compress),
        "-ContinuationDecisionJson", $doneDecision
    )
    Add-Check -Name "done blocked before closeout proof" -Ok ($blocked.exit_code -ne 0 -and [string]$blocked.json.reason -match "closeout result") -Reason "terminal Done should fail before closeout proof"

    $liveRoot = Join-Path $tempRoot "stale-live"
    New-Item -ItemType Directory -Path (Join-Path $liveRoot "skills\brainstorm-spec\agents") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot "skills\brainstorm-spec\SKILL.md") -Destination (Join-Path $liveRoot "skills\brainstorm-spec\SKILL.md")
    Copy-Item -LiteralPath (Join-Path $RepoRoot "skills\brainstorm-spec\agents\openai.yaml") -Destination (Join-Path $liveRoot "skills\brainstorm-spec\agents\openai.yaml")
    $skillPath = Join-Path $liveRoot "skills\brainstorm-spec\SKILL.md"
    (Get-Content -LiteralPath $skillPath -Raw).Replace("project_brainstorm_start_route", "project_old_route") | Set-Content -LiteralPath $skillPath -Encoding utf8NoBOM
    $stale = Invoke-JsonFile -ScriptPath (Join-Path $RepoRoot "scripts\detect-stale-skill-contract.ps1") -Arguments @(
        "-RepoRoot", $RepoRoot,
        "-LivePluginRoot", $liveRoot,
        "-SkillName", "brainstorm-spec",
        "-ExpectedQuestionId", "project_brainstorm_start_route"
    )
    Add-Check -Name "stale expected question id fails" -Ok ($stale.exit_code -ne 0 -and $stale.json.ok -eq $false) -Reason "stale detector should fail when expected question id is missing"

    $mergeDecisionPath = Join-Path $tempRoot "merge-decision.json"
    @{
        question_id = "project_merge_approval"
        source = "debug_question_mode"
        selected_action = "merge"
        recommended_action = "merge"
        options = @("merge", "decline")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $mergeDecisionPath -Encoding utf8NoBOM
    $apply = Invoke-JsonFile -ScriptPath (Join-Path $RepoRoot "skills\merge-changes\scripts\apply-local-branch-closeout.ps1") -Arguments @(
        "-RepoRoot", $repo,
        "-SetupLedgerPath", $setupPath,
        "-PremergeResultPath", ([string]$prepare.json.evidence.premerge_result_path),
        "-MergeDecisionPath", $mergeDecisionPath,
        "-ValidationCommand", "exit 0",
        "-CleanupHookCommand", "exit 0",
        "-OutputDir", $outDir
    )
    Add-Check -Name "local branch apply passes" -Ok ($apply.exit_code -eq 0 -and $apply.json.ok -eq $true) -Reason ([string]$apply.json.reason)
    $status = Invoke-Git -Root $repo -Arguments @("status", "--short")
    Add-Check -Name "fixture repo clean after closeout" -Ok ([string]::IsNullOrWhiteSpace($status)) -Reason "fixture repo should be clean after local branch closeout"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "e2e-project-workflow"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "e2e-project-workflow"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
} finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
