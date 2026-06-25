[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "scripts\validate-worker-packets.ps1"
$example = Join-Path $repoRoot "docs\superpowers\examples\worker-handoff-packets.md"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Add-Result -Name $Name -Ok $true -Reason "passed"
    } catch {
        Add-Result -Name $Name -Ok $false -Reason $_.Exception.Message
    }
}

function Invoke-JsonValidator {
    param([string]$Path, [switch]$ExpectFail)
    $raw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $repoRoot -PacketPath $Path 2>&1
    $text = ($raw | Out-String).Trim()
    $jsonStart = $text.IndexOf("{")
    if ($jsonStart -lt 0) { throw "validator did not emit JSON: $text" }
    $result = $text.Substring($jsonStart) | ConvertFrom-Json
    if ($ExpectFail) {
        if ($result.ok -ne $false) { throw "validator unexpectedly accepted $Path" }
    } elseif ($result.ok -ne $true) {
        throw "validator rejected ${Path}: $($result.reason)"
    }
    $result
}

function Write-JsonFixture {
    param([string]$Path, [object]$Value)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $Value | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Copy-FixtureObject {
    param([object]$Value)
    $Value | ConvertTo-Json -Depth 16 | ConvertFrom-Json
}

try {
    Invoke-Scenario "validator exists" {
        if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw "missing scripts/validate-worker-packets.ps1" }
    }

    Invoke-Scenario "checked-in packet example validates" {
        if (-not (Test-Path -LiteralPath $example -PathType Leaf)) { throw "missing docs/superpowers/examples/worker-handoff-packets.md" }
        [void](Invoke-JsonValidator -Path $example)
    }

    $temp = Join-Path ([IO.Path]::GetTempPath()) ("worker-packets-" + [guid]::NewGuid().ToString("N"))

    $workerPacket = [ordered]@{
        packet_type = "worker_handoff"
        issue_mirror = "docs/superpowers/issues/71-golden-path-workflow-fixtures.md"
        source_plan = "docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md"
        goal_command = "/goal Add sample worker handoff and PR-ready packets with validation for orchestrated issue work."
        branch = "codex/issue-71-golden-path-workflow-fixtures"
        branch_worktree_policy = "worker creates an isolated worktree for the branch"
        reviewer_role = "main-thread-orchestrator"
        proof_oracle = @(
            "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1",
            "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\test-scenarios.ps1"
        )
        validation = [ordered]@{
            required_commands = @(
                "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\orchestrate-issues\scripts\validate-worker-handoff.ps1 -RepoRoot . -HandoffPath <handoff-json>"
            )
        }
        merge_handoff = [ordered]@{
            merge_owner = "merge-changes"
            worker_must_not_merge = $true
        }
    }

    $prReadyPacket = [ordered]@{
        packet_type = "pr_ready"
        issue_mirror = "docs/superpowers/issues/71-golden-path-workflow-fixtures.md"
        source_plan = "docs/superpowers/plans/2026-06-21-m0-m1-workflow-contract-normalization-plan.md"
        branch = "codex/issue-71-golden-path-workflow-fixtures"
        proof_oracle = @(
            "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1",
            "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1"
        )
        diff_scope = [ordered]@{
            changed_files = @(
                "docs/superpowers/examples/worker-handoff-packets.md",
                "skills/orchestrate-issues/SKILL.md"
            )
        }
        validation_receipt = [ordered]@{
            commands = @(
                [ordered]@{ command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-worker-packets.ps1"; exit_code = 0 }
            )
        }
        merge_handoff = [ordered]@{
            route = "merge-changes"
            pr_url = "https://github.com/tannerpolley/superpowers-project/pull/71"
            closes_issue = "https://github.com/tannerpolley/superpowers-project/issues/71"
            worker_must_not_merge = $true
        }
    }

    $workerPath = Join-Path $temp "worker.json"
    $prReadyPath = Join-Path $temp "pr-ready.json"
    Write-JsonFixture -Path $workerPath -Value $workerPacket
    Write-JsonFixture -Path $prReadyPath -Value $prReadyPacket

    Invoke-Scenario "worker handoff packet fixture validates" {
        [void](Invoke-JsonValidator -Path $workerPath)
    }

    Invoke-Scenario "PR-ready packet fixture validates" {
        [void](Invoke-JsonValidator -Path $prReadyPath)
    }

    Invoke-Scenario "worker handoff packet rejects missing source plan" {
        $bad = Copy-FixtureObject -Value $workerPacket
        $bad.PSObject.Properties.Remove("source_plan")
        $badPath = Join-Path $temp "worker-missing-source-plan.json"
        Write-JsonFixture -Path $badPath -Value $bad
        [void](Invoke-JsonValidator -Path $badPath -ExpectFail)
    }

    Invoke-Scenario "worker handoff packet rejects missing validation command" {
        $bad = Copy-FixtureObject -Value $workerPacket
        $bad.validation = [ordered]@{ required_commands = @() }
        $badPath = Join-Path $temp "worker-missing-validation.json"
        Write-JsonFixture -Path $badPath -Value $bad
        [void](Invoke-JsonValidator -Path $badPath -ExpectFail)
    }

    Invoke-Scenario "PR-ready packet rejects missing branch" {
        $bad = Copy-FixtureObject -Value $prReadyPacket
        $bad.PSObject.Properties.Remove("branch")
        $badPath = Join-Path $temp "pr-ready-missing-branch.json"
        Write-JsonFixture -Path $badPath -Value $bad
        [void](Invoke-JsonValidator -Path $badPath -ExpectFail)
    }

    Invoke-Scenario "PR-ready packet rejects missing merge handoff" {
        $bad = Copy-FixtureObject -Value $prReadyPacket
        $bad.PSObject.Properties.Remove("merge_handoff")
        $badPath = Join-Path $temp "pr-ready-missing-merge-handoff.json"
        Write-JsonFixture -Path $badPath -Value $bad
        [void](Invoke-JsonValidator -Path $badPath -ExpectFail)
    }
} finally {
    if ($temp -and (Test-Path -LiteralPath $temp)) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}

$results | ConvertTo-Json -Depth 8
if (@($results | Where-Object { -not $_.ok }).Count -gt 0) { exit 1 }
