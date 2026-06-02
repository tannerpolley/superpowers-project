[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

$phase = "test-scenarios"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("riwg-tests-" + [guid]::NewGuid().ToString("N"))
$fixtureRoot = Join-Path $tempRoot "fixtures"
$skillRoot = Split-Path -Parent $PSScriptRoot
$results = [System.Collections.Generic.List[object]]::new()
$previousTestMode = $env:RIWG_TEST_MODE
$env:RIWG_TEST_MODE = "1"

function Get-PackageSnapshot {
    param([Parameter(Mandatory = $true)][string]$Root)
    $snapshot = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName) -replace "\\", "/"
        $snapshot[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    $snapshot
}

function Compare-PackageSnapshot {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Before,
        [Parameter(Mandatory = $true)][hashtable]$After
    )
    $diff = @()
    foreach ($key in @($Before.Keys | Sort-Object)) {
        if (-not $After.ContainsKey($key)) {
            $diff += "deleted $key"
        } elseif ($Before[$key] -ne $After[$key]) {
            $diff += "modified $key"
        }
    }
    foreach ($key in @($After.Keys | Sort-Object)) {
        if (-not $Before.ContainsKey($key)) {
            $diff += "added $key"
        }
    }
    $diff
}

$packageSnapshotBefore = Get-PackageSnapshot -Root $skillRoot

function Add-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Reason,
        [object]$Details = $null
    )
    $results.Add([pscustomobject]@{
        name = $Name
        passed = $Passed
        reason = $Reason
        details = $Details
    })
}

function Invoke-TestGit {
    param(
        [string]$Repo,
        [string[]]$Arguments
    )
    $result = Invoke-Git -RepoRoot $Repo -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($result.Stderr) $($result.Stdout)"
    }
    $result
}

function Commit-TestRepoVisibleChanges {
    param(
        [string]$Repo,
        [string]$Message
    )
    Invoke-TestGit -Repo $Repo -Arguments @("add", ".") | Out-Null
    $diff = Invoke-Git -RepoRoot $Repo -Arguments @("diff", "--cached", "--quiet")
    if ($diff.ExitCode -eq 1) {
        Invoke-TestGit -Repo $Repo -Arguments @("commit", "-m", $Message) | Out-Null
    } elseif ($diff.ExitCode -ne 0) {
        throw "git diff --cached --quiet failed: $($diff.Stderr)"
    }
}

function New-FixturePath {
    param([Parameter(Mandatory = $true)][string]$Name)
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    Join-Path $fixtureRoot $Name
}

function New-TestRepo {
    param(
        [string]$Name,
        [switch]$WithRemote,
        [switch]$WithMattSetup
    )

    $repo = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    $init = Invoke-External -FilePath "git" -Arguments @("init", "-b", "main") -WorkingDirectory $repo
    if ($init.ExitCode -ne 0) {
        $init = Invoke-External -FilePath "git" -Arguments @("init") -WorkingDirectory $repo
        if ($init.ExitCode -ne 0) { throw "git init failed: $($init.Stderr)" }
        Invoke-TestGit -Repo $repo -Arguments @("checkout", "-b", "main") | Out-Null
    }
    Invoke-TestGit -Repo $repo -Arguments @("config", "user.email", "tests@example.invalid") | Out-Null
    Invoke-TestGit -Repo $repo -Arguments @("config", "user.name", "Issue Goal Tests") | Out-Null

    Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "# Test Repo`n" -Encoding UTF8
    if ($WithMattSetup) {
        Set-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Value "# Repo`n`n## Agent skills`n" -Encoding UTF8
        New-Item -ItemType Directory -Path (Join-Path $repo "docs\agents") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repo "docs\agents\issue-tracker.md") -Value "# Issue Tracker: GitHub Issues`n`nUse GitHub Issues for the current git remote origin.`n" -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $repo "docs\agents\triage-labels.md") -Value "# Triage Labels`n" -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $repo "docs\agents\domain.md") -Value "# Domain Docs`n" -Encoding UTF8
    }

    Invoke-TestGit -Repo $repo -Arguments @("add", ".") | Out-Null
    Invoke-TestGit -Repo $repo -Arguments @("commit", "-m", "initial") | Out-Null

    if ($WithRemote) {
        Invoke-TestGit -Repo $repo -Arguments @("remote", "add", "origin", "https://github.com/example/$Name.git") | Out-Null
        Invoke-TestGit -Repo $repo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
        Invoke-TestGit -Repo $repo -Arguments @("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main") | Out-Null
    }

    $repo
}

function New-HandoffJson {
    param(
        [string]$Slug = "test-goal",
        [string[]]$Allowed = @(),
        [string]$BranchPolicy = "create",
        [string]$RequiredChecksPolicy = "require-existing",
        [string]$FullRoadmap = "none",
        [string]$MilestonePolicy = "none",
        [string]$MilestoneTitle = "none",
        [string]$MilestoneSection = "none",
        [string]$ProjectPolicy = "dashboard-only",
        [string]$SliceRoadmap = ""
    )
    $sliceRoadmapPath = if ([string]::IsNullOrWhiteSpace($SliceRoadmap)) { "docs/issues/$Slug.md" } else { $SliceRoadmap }
    @{
        slug = $Slug
        issue_url = "https://github.com/example/repo/issues/1"
        outcome = "Prove the scripted contract gates."
        issue_policy = "link:https://github.com/example/repo/issues/1"
        issue_readiness = @{
            source = "test fixture"
            state = "OPEN"
            single_execution_scope = $true
            acceptance_criteria_present = $true
            linked_plan_file_exists = $true
            issue_plan_alignment = $true
        }
        branch_policy = $BranchPolicy
        branch = "codex/$Slug"
        full_roadmap = $FullRoadmap
        plan_file = $sliceRoadmapPath
        goal_board = "docs/goals/$Slug"
        proof_oracle = @("script scenarios pass")
        non_goals = @("live GitHub writes")
        candidate_allowed_files = @("src/example.txt", "tests/example.test")
        merge_policy = "ready PR, closing keyword for exact issue, checks passing, MERGEABLE, no requested changes, no unresolved non-outdated actionable review threads, squash merge"
        required_checks_policy = $RequiredChecksPolicy
        milestone_policy = $MilestonePolicy
        milestone_title = $MilestoneTitle
        full_roadmap_milestone_section = $MilestoneSection
        project_policy = $ProjectPolicy
        allowed_existing_dirty_paths = $Allowed
    } | ConvertTo-Json -Depth 16
}

function Get-EpcsaftMilestoneFixtureData {
    @(
        @{ title = "M0 - Governance"; description = "Roadmap hygiene, tracker setup, labels, issue templates, completion rules, GoalBuddy/project discipline, and repo-wide process gates."; state = "open"; number = 1 },
        @{ title = "M1 - Packages"; description = "Monorepo package layout, package ownership, test relocation, provider-only build proof, extension-native boundaries, and package CI/docs/release structure."; state = "open"; number = 2 },
        @{ title = "M2 - Python API"; description = "Public Python package surface, user-facing workflow ergonomics, result schemas, diagnostics, examples, import stability, and package-level user experience."; state = "open"; number = 3 },
        @{ title = "M3 - EOS"; description = "Provider EOS/state/parameters, native SDK contract, exact derivatives, CppAD/implicit sensitivities, and provider-only capability claims."; state = "open"; number = 4 },
        @{ title = "M4 - Equilibrium"; description = "epcsaft-equilibrium, GFPE, selector/admission, Ipopt NLP, HELD/TPD, phase discovery, and VLE/LLE/electrolyte/reactive equilibrium workflows."; state = "open"; number = 5 },
        @{ title = "M5 - Regression"; description = "epcsaft-regression, TargetDataset/result contracts, Ceres optimizer, parameter sensitivities, and pure/binary/electrolyte regression workflows."; state = "open"; number = 6 },
        @{ title = "M6 - Validation"; description = "Executable literature benchmarks, registry evidence, capability evidence, docs/test proof, and release-quality validation gates."; state = "open"; number = 7 },
        @{ title = "M7 - Release"; description = "Downstream integration, install proofs, PyPI/release choreography, migration docs, and no private downstream workarounds."; state = "open"; number = 8 }
    )
}

function New-MilestonesFixturePath {
    param(
        [string]$Name = "milestones.json",
        [switch]$Empty
    )
    $path = New-FixturePath $Name
    $milestones = if ($Empty) { @() } else { Get-EpcsaftMilestoneFixtureData }
    if ($milestones.Count -eq 0) {
        "[]" | Set-Content -LiteralPath $path -Encoding UTF8
    } else {
        ConvertTo-Json -InputObject $milestones -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
    }
    $path
}

function New-GenericMilestonesFixturePath {
    param([string]$Name = "milestones-generic.json")
    $path = New-FixturePath $Name
    @(
        @{ title = "Discovery"; description = "Define the problem, constraints, evidence, and acceptance boundary."; state = "open"; number = 1 },
        @{ title = "Build Beta"; description = "Deliver the first integrated implementation slice with local and CI proof."; state = "open"; number = 2 }
    ) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
    $path
}

function New-ProjectsFixturePath {
    param([string]$Name = "projects.json")
    $path = New-FixturePath $Name
    @(
        @{ title = "Roadmap Board"; url = "https://github.com/orgs/example/projects/1"; closed = $false; number = 1 }
    ) | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
    $path
}

function Add-FullRoadmapFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [string]$M4Title = "M4 - Equilibrium",
        [string]$M4Description = "epcsaft-equilibrium, GFPE, selector/admission, Ipopt NLP, HELD/TPD, phase discovery, and VLE/LLE/electrolyte/reactive equilibrium workflows."
    )
    New-Item -ItemType Directory -Path (Join-Path $Repo "docs\roadmaps") -Force | Out-Null
    $milestones = Get-EpcsaftMilestoneFixtureData | ForEach-Object {
        $title = if ($_.title -eq "M4 - Equilibrium") { $M4Title } else { $_.title }
        $description = if ($_.title -eq "M4 - Equilibrium") { $M4Description } else { $_.description }
@"
## $title

$description

"@
    }
    @"
# Roadmap

# 8. Required milestones

GitHub milestones use short dashboard names. This file owns their durable meaning.

$($milestones -join "")
"@ | Set-Content -LiteralPath (Join-Path $Repo "docs\roadmaps\FULL_ROADMAP.md") -Encoding UTF8
}

function Add-ProjectContextRoadmapFixture {
    param([Parameter(Mandatory = $true)][string]$Repo)
    New-Item -ItemType Directory -Path (Join-Path $Repo "docs\milestones") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Repo "docs\milestones\M0-governance\issues") -Force | Out-Null
    $milestones = Get-EpcsaftMilestoneFixtureData | ForEach-Object {
@"
## $($_.title)

$($_.description)

"@
    }
    @"
# Project Context

# 8. Required milestones

GitHub milestones use short dashboard names. This file owns their durable meaning.

$($milestones -join "")
"@ | Set-Content -LiteralPath (Join-Path $Repo "docs\milestones\PROJECT_CONTEXT.md") -Encoding UTF8
}

function Add-GenericFullRoadmapFixture {
    param([Parameter(Mandatory = $true)][string]$Repo)
    New-Item -ItemType Directory -Path (Join-Path $Repo "docs\roadmaps") -Force | Out-Null
    @"
# Product Roadmap

## Milestones

### Discovery

Define the problem, constraints, evidence, and acceptance boundary.

### Build Beta

Deliver the first integrated implementation slice with local and CI proof.

"@ | Set-Content -LiteralPath (Join-Path $Repo "docs\roadmaps\FULL_ROADMAP.md") -Encoding UTF8
}

function New-SetupLedgerJson {
    param(
        [string]$RepoName = "repo",
        [string]$Slug = "test-goal",
        [string]$IssueNumber = "1",
        [string[]]$LocalBranchesBefore = @("main"),
        [string[]]$RemoteBranchesBefore = @("main"),
        [switch]$FakeGoalProof,
        [string]$BranchOverride
    )
    $branch = if ([string]::IsNullOrWhiteSpace($BranchOverride)) { "codex/$Slug" } else { $BranchOverride }
    $issueUrl = "https://github.com/example/$RepoName/issues/$IssueNumber"
    $proof = if ($FakeGoalProof) {
        "get_goal active objective includes issue branch roadmap board oracle closeout"
    } else {
        @{
            source = "get_goal"
            active = $true
            objective = "Complete $issueUrl on $branch using docs/issues/$Slug.md, docs/goals/$Slug, proof oracle, and closeout requirements."
            objective_refs = @{
                issue_url = $issueUrl
                branch = $branch
                plan_file = "docs/issues/$Slug.md"
                goal_board = "docs/goals/$Slug"
                proof_oracle = $true
                closeout_required = $true
            }
        }
    }
    @{
        issue_url = $issueUrl
        branch = $branch
        slice_roadmap_path = "docs/issues/$Slug.md"
        goal_board_path = "docs/goals/$Slug"
        goal_activation_proof = $proof
        proof_oracle = @("script scenarios pass")
        branch_inventory_before = @{
            local = $LocalBranchesBefore
            remote = $RemoteBranchesBefore
        }
    } | ConvertTo-Json -Depth 20
}

function New-VerificationLedgerJson {
    param(
        [string]$RepoName = "repo",
        [string]$PrNumber = "2",
        [int]$ExitCode = 0,
        [string[]]$CoveredFiles = @("src/example.txt", "docs/issues/test-goal.md"),
        [string[]]$Exemptions = @(),
        [switch]$UnsyncedIssue,
        [switch]$UnsyncedRoadmap
    )
    @{
        pr_url = "https://github.com/example/$RepoName/pull/$PrNumber"
        proof_commands = @(@{
            command = "pwsh -NoProfile -File scripts/test-scenarios.ps1"
            exit_code = $ExitCode
            output_receipt = "scenario proof"
            source_label = "local"
        })
        changed_files_covered = $CoveredFiles
        verification_exemptions = $Exemptions
        issue_criteria_synced = -not $UnsyncedIssue.IsPresent
        slice_roadmap_gates_synced = -not $UnsyncedRoadmap.IsPresent
    } | ConvertTo-Json -Depth 20
}

function New-CompletionLedgerJson {
    param(
        [string]$RepoName = "repo",
        [string]$PrNumber = "2",
        [string]$IssueNumber = "1",
        [string]$LocalDeleteTarget = "codex/test-goal",
        [string]$RemoteDeleteTarget = "codex/test-goal",
        [string[]]$RemoteDeletedBranches = @("codex/test-goal"),
        [switch]$FakeStrings
    )
    if ($FakeStrings) {
        return @{
            pr_url = "https://github.com/example/$RepoName/pull/$PrNumber"
            issue_url = "https://github.com/example/$RepoName/issues/$IssueNumber"
            merge_confirmation = "PR merged"
            linked_issue_closed_confirmation = "Issue closed"
            branch_cleanup_confirmation = "Goal-owned branches removed"
            goal_board_deletion_confirmation = "Local board removed"
            cleanup_hook_result = "No matching leftover Codex processes"
        } | ConvertTo-Json -Depth 20
    }
    @{
        pr_url = "https://github.com/example/$RepoName/pull/$PrNumber"
        issue_url = "https://github.com/example/$RepoName/issues/$IssueNumber"
        merge_confirmation = @{
            source = "gh pr view"
            state = "MERGED"
            merged_at = "2026-01-01T00:00:00Z"
        }
        linked_issue_closed_confirmation = @{
            source = "gh issue view"
            state = "CLOSED"
        }
        branch_cleanup_confirmation = @{
            deleted_local = $true
            deleted_remote = $true
            only_goal_owned_removed = $true
            local_delete_target = $LocalDeleteTarget
            remote_delete_target = $RemoteDeleteTarget
            remote_deleted_branches = $RemoteDeletedBranches
        }
        goal_board_deletion_confirmation = @{
            path = "docs/goals/test-goal"
            deleted = $true
        }
        cleanup_hook_result = @{
            command = "codex-cleanup"
            exit_code = 0
            output = "No matching leftover Codex processes"
        }
    } | ConvertTo-Json -Depth 20
}

function New-GoalStateYaml {
    param(
        [switch]$NoWorker,
        [switch]$WorkerMissingVerify
    )
    $worker = if ($NoWorker) {
        ""
    } elseif ($WorkerMissingVerify) {
@"
  - id: T003
    type: worker
    assignee: Worker
    status: queued
    objective: "Implement bounded slice."
    allowed_files:
      - src/example.txt
    stop_if:
      - "Need files outside allowed_files."
    receipt: null
"@
    } else {
@"
  - id: T003
    type: worker
    assignee: Worker
    status: queued
    objective: "Implement bounded slice."
    allowed_files:
      - src/example.txt
    verify:
      - pwsh -NoProfile -File scripts/test.ps1
    stop_if:
      - "Need files outside allowed_files."
    receipt: null
"@
    }
@"
version: 2
goal:
  status: active
  oracle: "script scenarios pass"
rules:
  continuous_until_full_outcome: true
  missing_input_or_credentials_do_not_stop_goal: true
  goal_pressure_requires_oracle: true
agents:
  scout: installed
  worker: installed
  judge: installed
visual_board:
  selected: local
active_task: T001
tasks:
  - id: T001
    type: scout
    assignee: Scout
    status: active
    objective: "Map evidence."
    receipt: null
  - id: T002
    type: judge
    assignee: Judge
    status: queued
    objective: "Select the largest safe useful Worker slice."
    receipt: null
$worker
checks: []
"@
}

function New-IssueMarkerBody {
    param(
        [string]$Slug = "test-goal",
        [string[]]$CandidateAllowedFiles = @("src/example.txt", "tests/example.test"),
        [switch]$NoMarker,
        [switch]$NoCandidateFiles,
        [switch]$NoBranchPolicy,
        [string]$IssueSourcePolicy = "local-main-sync",
        [switch]$ExternalMarkerOnly,
        [string]$TargetRepo = "example/fast-setup"
    )
    $criteria = @"
## Acceptance Criteria

- [ ] Fast setup can prepare the execution handoff.

"@
    if ($ExternalMarkerOnly) {
        $externalMarker = [ordered]@{
            target_repo = $TargetRepo
            source_repo = "example/source-repo"
            issue_source_policy = "external-github-only"
            local_plan_file = "external:none"
            execution_ready = $false
        } | ConvertTo-Json -Depth 12
        return @"
$criteria
Externally sourced issue

## Proof Oracle

- pwsh -NoProfile -File scripts/test.ps1

## Non-Goals

- Do not change unrelated files

## Candidate Allowed Files

- src/example.txt
- tests/example.test

<!-- convert-idea-to-issue-external-source
$externalMarker
-->
"@
    }
    if ($NoMarker) { return $criteria }
    $marker = [ordered]@{
        slug = $Slug
        issue_source_policy = $IssueSourcePolicy
        plan_file = "docs/issues/$Slug.md"
        milestone_policy = "none"
        milestone_title = "none"
        full_roadmap = "none"
        full_roadmap_milestone_section = "none"
        proof_oracle = @("pwsh -NoProfile -File scripts/test.ps1")
        non_goals = @("Do not change unrelated files")
        required_checks_policy = "require-existing"
    }
    if (-not $NoBranchPolicy) {
        $marker.branch_policy = "create"
    }
    if (-not $NoCandidateFiles) {
        $marker.candidate_allowed_files = $CandidateAllowedFiles
    }
    $markerJson = $marker | ConvertTo-Json -Depth 16
@"
$criteria
<!-- resolve-issue-with-goal
$markerJson
-->
"@
}

function New-IssueFixturePath {
    param(
        [string]$Name,
        [string]$RepoName,
        [switch]$NoMarker,
        [switch]$NoCandidateFiles,
        [switch]$NoBranchPolicy,
        [string]$IssueSourcePolicy = "local-main-sync",
        [switch]$ExternalMarkerOnly,
        [string]$MilestoneTitle = ""
    )
    $path = New-FixturePath $Name
    $issue = @{
        url = "https://github.com/example/$RepoName/issues/1"
        number = 1
        title = "Fast setup issue"
        state = "OPEN"
        labels = @(@{ name = "type:feature" })
        body = New-IssueMarkerBody -NoMarker:$NoMarker -NoCandidateFiles:$NoCandidateFiles -NoBranchPolicy:$NoBranchPolicy -IssueSourcePolicy $IssueSourcePolicy -ExternalMarkerOnly:$ExternalMarkerOnly -TargetRepo "example/$RepoName"
    }
    if (-not [string]::IsNullOrWhiteSpace($MilestoneTitle)) {
        $issue.milestone = @{ title = $MilestoneTitle }
    }
    $issue | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $path -Encoding UTF8
    $path
}

function New-NativeGoalProofJson {
    param(
        [string]$RepoName,
        [string]$Slug = "test-goal",
        [switch]$FakeString
    )
    $issueUrl = "https://github.com/example/$RepoName/issues/1"
    if ($FakeString) { return ('native goal was started' | ConvertTo-Json) }
    @{
        source = "get_goal"
        active = $true
        objective = "Resolve $issueUrl on codex/$Slug using docs/issues/$Slug.md and docs/goals/$Slug."
        objective_refs = @{
            issue_url = $issueUrl
            branch = "codex/$Slug"
            plan_file = "docs/issues/$Slug.md"
            goal_board = "docs/goals/$Slug"
            proof_oracle = $true
            closeout_required = $true
        }
    } | ConvertTo-Json -Depth 16
}

function Invoke-ContractScriptForTest {
    param(
        [string]$ScriptName,
        [string[]]$Arguments,
        [switch]$NoTestMode
    )
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not $NoTestMode) {
        $result = Invoke-External -FilePath "pwsh.exe" -Arguments (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $Arguments) -WorkingDirectory $tempRoot
    } else {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "pwsh.exe"
        $psi.WorkingDirectory = $tempRoot
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        [void]$psi.EnvironmentVariables.Remove("RIWG_TEST_MODE")
        foreach ($arg in @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $Arguments) {
            [void]$psi.ArgumentList.Add($arg)
        }
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $psi
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout.Trim(); Stderr = $stderr.Trim() }
    }
    $json = $null
    try {
        $json = $result.Stdout | ConvertFrom-Json
    } catch {
        throw "$ScriptName did not emit JSON. exit=$($result.ExitCode) stdout=$($result.Stdout) stderr=$($result.Stderr)"
    }
    [pscustomobject]@{
        ExitCode = $result.ExitCode
        Result = $json
        Stdout = $result.Stdout
        Stderr = $result.Stderr
    }
}

function Assert-Contract {
    param(
        [string]$Name,
        [object]$Run,
        [bool]$ExpectedOk,
        [string]$ReasonPattern
    )
    $actualOk = [bool]$Run.Result.ok
    $reason = [string]$Run.Result.reason
    $passed = $actualOk -eq $ExpectedOk -and ($reason -match $ReasonPattern)
    Add-TestResult -Name $Name -Passed $passed -Reason $reason -Details @{
        expected_ok = $ExpectedOk
        exit_code = $Run.ExitCode
    }
}

function Initialize-SetupRepo {
    param(
        [string]$Name,
        [switch]$NoWorker,
        [switch]$WorkerMissingVerify
    )
    $repo = New-TestRepo -Name $Name -WithRemote -WithMattSetup
    Invoke-TestGit -Repo $repo -Arguments @("checkout", "-b", "codex/test-goal") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo "docs\issues") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "docs\issues\test-goal.md") -Value "- [x] Gate complete`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $repo ".gitignore") -Value "docs/goals/`n**/.goalbuddy-board/`n" -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $repo "docs\goals\test-goal") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "docs\goals\test-goal\goal.md") -Value "# Test Goal`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $repo "docs\goals\test-goal\state.yaml") -Value (New-GoalStateYaml -NoWorker:$NoWorker -WorkerMissingVerify:$WorkerMissingVerify) -Encoding UTF8
    $repo
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $timeoutProbe = Invoke-External -FilePath "pwsh.exe" -Arguments @("-NoProfile", "-Command", "Start-Sleep -Seconds 5") -WorkingDirectory $tempRoot -TimeoutSeconds 1
    $timeoutProbeStillRunning = $false
    if ($timeoutProbe.ProcessId -gt 0) {
        Start-Sleep -Milliseconds 200
        $timeoutProbeStillRunning = [bool](Get-Process -Id $timeoutProbe.ProcessId -ErrorAction SilentlyContinue)
    }
    Add-TestResult -Name "external helper timeout is bounded" -Passed (
        $timeoutProbe.TimedOut -eq $true -and
        $timeoutProbe.ExitCode -eq 124 -and
        $timeoutProbe.Stderr -match "timed out" -and
        $timeoutProbeStillRunning -eq $false
    ) -Reason "timeout result should prove owned child process termination" -Details @{
        exit_code = $timeoutProbe.ExitCode
        timed_out = $timeoutProbe.TimedOut
        process_id = $timeoutProbe.ProcessId
        still_running = $timeoutProbeStillRunning
        stderr = $timeoutProbe.Stderr
    }
    $handoff = New-HandoffJson
    $emptyMilestonesFixture = New-MilestonesFixturePath -Name "milestones-empty.json" -Empty
    $epcsaftMilestonesFixture = New-MilestonesFixturePath -Name "milestones-epcsaft.json"
    $genericMilestonesFixture = New-GenericMilestonesFixturePath -Name "milestones-generic.json"
    $projectsFixture = New-ProjectsFixturePath -Name "projects-roadmap.json"

    $missingRemoteRepo = New-TestRepo -Name "missing-remote" -WithMattSetup
    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $missingRemoteRepo, "-SkipGhAuth")
    Assert-Contract -Name "repo gate missing GitHub remote blocks" -Run $run -ExpectedOk $false -ReasonPattern "missing GitHub origin remote"

    $missingMattRepo = New-TestRepo -Name "missing-matt" -WithRemote
    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $missingMattRepo, "-SkipGhAuth")
    Assert-Contract -Name "repo gate missing Matt setup blocks" -Run $run -ExpectedOk $false -ReasonPattern "missing AGENTS|lacks ## Agent skills|Matt Pocock"

    $happyGateRepo = New-TestRepo -Name "happy-gate" -WithRemote -WithMattSetup
    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $happyGateRepo, "-SkipGhAuth")
    Assert-Contract -Name "happy repo gate passes" -Run $run -ExpectedOk $true -ReasonPattern "repo gate passed"

    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $happyGateRepo, "-SkipGhAuth", "-ExpectedRemoteSlug", "example/other")
    Assert-Contract -Name "repo gate expected target mismatch blocks" -Run $run -ExpectedOk $false -ReasonPattern "target repo mismatch"

    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $happyGateRepo, "-SkipGhAuth", "-MilestonesFixturePath", $emptyMilestonesFixture, "-ProjectsFixturePath", $projectsFixture)
    Assert-Contract -Name "repo gate reports no milestones and soft projects" -Run $run -ExpectedOk $true -ReasonPattern "repo gate passed"
    Add-TestResult -Name "projects are dashboard evidence only" -Passed ($run.Result.evidence.projects_present -eq $true -and $run.Result.evidence.milestones_present -eq $false) -Reason "repo gate reported projects without blocking" -Details $run.Result.evidence

    $weakMattRepo = New-TestRepo -Name "weak-matt" -WithRemote -WithMattSetup
    Set-Content -LiteralPath (Join-Path $weakMattRepo "docs\agents\issue-tracker.md") -Value "# Issue Tracker`n`nUse whatever tracker is nearby.`n" -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $weakMattRepo, "-SkipGhAuth")
    Assert-Contract -Name "weak Matt issue tracker blocks" -Run $run -ExpectedOk $false -ReasonPattern "GitHub Issues"

    $dottedRepo = New-TestRepo -Name "repo.with.dot" -WithRemote -WithMattSetup
    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $dottedRepo, "-SkipGhAuth")
    Assert-Contract -Name "dotted GitHub repo names pass" -Run $run -ExpectedOk $true -ReasonPattern "repo gate passed"

    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $happyGateRepo, "-HandoffJson", $handoff, "-SkipGhAuth") -NoTestMode
    Assert-Contract -Name "live skip switch blocks" -Run $run -ExpectedOk $false -ReasonPattern "test-only"

    $run = Invoke-ContractScriptForTest -ScriptName "repo-gate.ps1" -Arguments @("-RepoRoot", $happyGateRepo, "-MilestonesFixturePath", $emptyMilestonesFixture) -NoTestMode
    Assert-Contract -Name "live milestone fixture switch blocks" -Run $run -ExpectedOk $false -ReasonPattern "test-only"

    $badSlugHandoff = New-HandoffJson -Slug "Bad_Slug"
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $happyGateRepo, "-HandoffJson", $badSlugHandoff, "-SkipGhAuth")
    Assert-Contract -Name "invalid handoff slug blocks" -Run $run -ExpectedOk $false -ReasonPattern "slug"

    $dirtyRepo = New-TestRepo -Name "dirty" -WithRemote -WithMattSetup
    Set-Content -LiteralPath (Join-Path $dirtyRepo "dirty.txt") -Value "dirty" -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $dirtyRepo, "-HandoffJson", $handoff, "-SkipGhAuth")
    Assert-Contract -Name "unrelated dirty worktree blocks" -Run $run -ExpectedOk $false -ReasonPattern "unrelated dirty"

    $dotDirtyRepo = New-TestRepo -Name "dot-dirty-allowed" -WithRemote -WithMattSetup
    New-Item -ItemType Directory -Path (Join-Path $dotDirtyRepo ".codex\environments") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dotDirtyRepo ".codex\environments\environment.toml") -Value "name = 'before'" -Encoding UTF8
    Commit-TestRepoVisibleChanges -Repo $dotDirtyRepo -Message "add dot codex environment file"
    Invoke-TestGit -Repo $dotDirtyRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    Set-Content -LiteralPath (Join-Path $dotDirtyRepo ".codex\environments\environment.toml") -Value "name = 'after'" -Encoding UTF8
    $dotDirtyHandoff = New-HandoffJson -Allowed @(".codex/environments/environment.toml")
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $dotDirtyRepo, "-HandoffJson", $dotDirtyHandoff, "-SkipGhAuth")
    Assert-Contract -Name "dot-prefixed first dirty path allowed by handoff passes" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $existingBranchRepo = New-TestRepo -Name "existing-branch" -WithRemote -WithMattSetup
    Invoke-TestGit -Repo $existingBranchRepo -Arguments @("branch", "codex/test-goal") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $existingBranchRepo, "-HandoffJson", $handoff, "-SkipGhAuth")
    Assert-Contract -Name "existing branch blocks create policy" -Run $run -ExpectedOk $false -ReasonPattern "branch already exists"

    $nonDefaultRepo = New-TestRepo -Name "non-default-create" -WithRemote -WithMattSetup
    Invoke-TestGit -Repo $nonDefaultRepo -Arguments @("checkout", "-b", "feature/unrelated") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $nonDefaultRepo, "-HandoffJson", $handoff, "-SkipGhAuth")
    Assert-Contract -Name "create policy from non-default branch blocks" -Run $run -ExpectedOk $false -ReasonPattern "remote default branch"

    $behindDefaultRepo = New-TestRepo -Name "behind-default" -WithRemote -WithMattSetup
    $oldHead = (Invoke-TestGit -Repo $behindDefaultRepo -Arguments @("rev-parse", "HEAD")).Stdout
    Set-Content -LiteralPath (Join-Path $behindDefaultRepo "new-origin.txt") -Value "remote-only" -Encoding UTF8
    Invoke-TestGit -Repo $behindDefaultRepo -Arguments @("add", ".") | Out-Null
    Invoke-TestGit -Repo $behindDefaultRepo -Arguments @("commit", "-m", "remote main ahead") | Out-Null
    $newHead = (Invoke-TestGit -Repo $behindDefaultRepo -Arguments @("rev-parse", "HEAD")).Stdout
    Invoke-TestGit -Repo $behindDefaultRepo -Arguments @("update-ref", "refs/remotes/origin/main", $newHead) | Out-Null
    Invoke-TestGit -Repo $behindDefaultRepo -Arguments @("reset", "--hard", $oldHead) | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $behindDefaultRepo, "-HandoffJson", $handoff, "-SkipGhAuth")
    Assert-Contract -Name "create policy from stale default blocks" -Run $run -ExpectedOk $false -ReasonPattern "local default branch"

    $happyPreflightRepo = New-TestRepo -Name "happy-preflight" -WithRemote -WithMattSetup
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $happyPreflightRepo, "-HandoffJson", $handoff, "-SkipGhAuth")
    Assert-Contract -Name "happy preflight passes" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $fastRepo = New-TestRepo -Name "fast-setup" -WithRemote -WithMattSetup
    New-Item -ItemType Directory -Path (Join-Path $fastRepo "docs\issues") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fastRepo "docs\issues\test-goal.md") -Value "- [x] Fast setup gate complete`n" -Encoding UTF8
    Commit-TestRepoVisibleChanges -Repo $fastRepo -Message "add fast setup plan"
    Invoke-TestGit -Repo $fastRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $fastIssueFixture = New-IssueFixturePath -Name "fast-setup-issue.json" -RepoName "fast-setup"
    $inspectRun = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $fastRepo, "-Issue", "1", "-IssueFixturePath", $fastIssueFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect marker creates handoff" -Run $inspectRun -ExpectedOk $true -ReasonPattern "handoff prepared"

    $noBranchPolicyFixture = New-IssueFixturePath -Name "fast-setup-no-branch-policy.json" -RepoName "fast-setup" -NoBranchPolicy
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $fastRepo, "-Issue", "1", "-IssueFixturePath", $noBranchPolicyFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect defaults branch policy at execution" -Run $run -ExpectedOk $true -ReasonPattern "handoff prepared"
    if ([string]$run.Result.evidence.handoff.branch_policy -ne "create") { throw "expected execution inspect to default branch_policy to create" }

    $externalRepo = New-TestRepo -Name "external-localize" -WithRemote -WithMattSetup
    $externalSourceFixture = New-IssueFixturePath -Name "fast-setup-external-source.json" -RepoName "external-localize" -ExternalMarkerOnly
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $externalRepo, "-Issue", "1", "-IssueFixturePath", $externalSourceFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect localizes external sourced issue" -Run $run -ExpectedOk $true -ReasonPattern "handoff prepared"
    $localizedPlan = Join-Path $externalRepo ([string]$run.Result.evidence.handoff.plan_file)
    if (-not (Test-Path -LiteralPath $localizedPlan -PathType Leaf)) { throw "external issue localization did not create local issue file: $localizedPlan" }
    if ($null -eq $run.Result.evidence.external_issue_localization -or $run.Result.evidence.external_issue_localization.issue_body_update_required -ne $true) {
        throw "external issue localization did not emit issue-body update evidence"
    }
    Commit-TestRepoVisibleChanges -Repo $externalRepo -Message "docs: localize external issue plan"
    Invoke-TestGit -Repo $externalRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $externalRepo, "-HandoffJson", ([string]$run.Result.evidence.handoff_json), "-SkipGhAuth")
    Assert-Contract -Name "localized external issue handoff passes preflight after docs sync" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $externalProjectContextRepo = New-TestRepo -Name "external-project-context-localize" -WithRemote -WithMattSetup
    Add-ProjectContextRoadmapFixture -Repo $externalProjectContextRepo
    Commit-TestRepoVisibleChanges -Repo $externalProjectContextRepo -Message "add project context"
    Invoke-TestGit -Repo $externalProjectContextRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $externalProjectContextFixture = New-IssueFixturePath -Name "fast-setup-external-project-context.json" -RepoName "external-project-context-localize" -ExternalMarkerOnly -MilestoneTitle "M0 - Governance"
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $externalProjectContextRepo, "-Issue", "1", "-IssueFixturePath", $externalProjectContextFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect localizes external milestone issue using project context" -Run $run -ExpectedOk $true -ReasonPattern "handoff prepared"
    if ([string]$run.Result.evidence.handoff.full_roadmap -ne "docs/milestones/PROJECT_CONTEXT.md") { throw "external localization did not discover PROJECT_CONTEXT.md" }
    if ([string]$run.Result.evidence.handoff.full_roadmap_milestone_section -ne "Required milestones") { throw "external localization did not normalize the numbered Required milestones section" }
    if (-not ([string]$run.Result.evidence.handoff.plan_file).StartsWith("docs/milestones/M0-governance/issues/")) { throw "external localization did not preserve existing milestone folder casing" }
    Commit-TestRepoVisibleChanges -Repo $externalProjectContextRepo -Message "docs: localize external project-context issue plan"
    Invoke-TestGit -Repo $externalProjectContextRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $externalProjectContextRepo, "-HandoffJson", ([string]$run.Result.evidence.handoff_json), "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "localized external project-context handoff passes preflight after docs sync" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $repairMarkerRepo = New-TestRepo -Name "marker-repair" -WithRemote -WithMattSetup
    Add-FullRoadmapFixture -Repo $repairMarkerRepo
    New-Item -ItemType Directory -Path (Join-Path $repairMarkerRepo "docs\milestones\m4-equilibrium\issues") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repairMarkerRepo "docs\milestones\m4-equilibrium\issues\test-goal.md") -Value "- [x] Repaired marker gate complete`n" -Encoding UTF8
    Commit-TestRepoVisibleChanges -Repo $repairMarkerRepo -Message "add milestone issue file"
    Invoke-TestGit -Repo $repairMarkerRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $brokenMarkerFixture = New-FixturePath "marker-repair-issue.json"
    $brokenMarker = [ordered]@{
        slug = "test-goal"
        target_repo = "example/marker-repair"
        issue_source_policy = "local-main-sync"
        plan_file = "docs/milestones/m4-equilibrium/issues/test-goal.md"
        milestone_policy = "hard"
        milestone_title = "M4 - Equilibrium"
        full_roadmap = "none"
        full_roadmap_milestone_section = "none"
        proof_oracle = @("pwsh -NoProfile -File scripts/test.ps1")
        non_goals = @("Do not change unrelated files")
        candidate_allowed_files = @("src/example.txt", "tests/example.test")
        required_checks_policy = "require-existing"
    } | ConvertTo-Json -Depth 16
    @{
        url = "https://github.com/example/marker-repair/issues/1"
        number = 1
        title = "Repair marker issue"
        state = "OPEN"
        labels = @(@{ name = "type:task" })
        milestone = @{ title = "M4 - Equilibrium" }
        body = @"
## Acceptance Criteria

- [ ] Fast setup can repair the execution marker.

<!-- resolve-issue-with-goal
$brokenMarker
-->
"@
    } | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $brokenMarkerFixture -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $repairMarkerRepo, "-Issue", "1", "-IssueFixturePath", $brokenMarkerFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect repairs missing full roadmap marker" -Run $run -ExpectedOk $true -ReasonPattern "handoff prepared"
    if ($null -eq $run.Result.evidence.readiness_marker_repair -or $run.Result.evidence.readiness_marker_repair.issue_body_update_required -ne $true) {
        throw "missing readiness marker repair evidence"
    }
    if ([string]$run.Result.evidence.handoff.full_roadmap -ne "docs/roadmaps/FULL_ROADMAP.md") {
        throw "expected repaired full_roadmap in handoff"
    }

    $wrongSectionRepo = New-TestRepo -Name "marker-wrong-section-repair" -WithRemote -WithMattSetup
    Add-FullRoadmapFixture -Repo $wrongSectionRepo
    New-Item -ItemType Directory -Path (Join-Path $wrongSectionRepo "docs\milestones\m4-equilibrium\issues") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $wrongSectionRepo "docs\milestones\m4-equilibrium\issues\test-goal.md") -Value "- [x] Wrong section marker gate complete`n" -Encoding UTF8
    Commit-TestRepoVisibleChanges -Repo $wrongSectionRepo -Message "add milestone issue file"
    Invoke-TestGit -Repo $wrongSectionRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $wrongSectionFixture = New-FixturePath "marker-wrong-section-issue.json"
    $wrongSectionMarker = [ordered]@{
        slug = "test-goal"
        target_repo = "example/marker-wrong-section-repair"
        issue_source_policy = "local-main-sync"
        plan_file = "docs/milestones/m4-equilibrium/issues/test-goal.md"
        milestone_policy = "hard"
        milestone_title = "M4 - Equilibrium"
        full_roadmap = "docs/roadmaps/FULL_ROADMAP.md"
        full_roadmap_milestone_section = "## M4 - Equilibrium"
        proof_oracle = @("pwsh -NoProfile -File scripts/test.ps1")
        non_goals = @("Do not change unrelated files")
        candidate_allowed_files = @("src/example.txt", "tests/example.test")
        required_checks_policy = "require-existing"
    } | ConvertTo-Json -Depth 16
    @{
        url = "https://github.com/example/marker-wrong-section-repair/issues/1"
        number = 1
        title = "Repair wrong section marker issue"
        state = "OPEN"
        labels = @(@{ name = "type:task" })
        milestone = @{ title = "M4 - Equilibrium" }
        body = @"
## Acceptance Criteria

- [ ] Fast setup can repair an invalid full roadmap milestone section.

<!-- resolve-issue-with-goal
$wrongSectionMarker
-->
"@
    } | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $wrongSectionFixture -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $wrongSectionRepo, "-Issue", "1", "-IssueFixturePath", $wrongSectionFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect repairs invalid full roadmap marker section" -Run $run -ExpectedOk $true -ReasonPattern "handoff prepared"
    if ($null -eq $run.Result.evidence.readiness_marker_repair -or $run.Result.evidence.readiness_marker_repair.issue_body_update_required -ne $true) {
        throw "missing wrong-section readiness marker repair evidence"
    }
    if ([string]$run.Result.evidence.handoff.full_roadmap_milestone_section -ne "Required milestones") {
        throw "expected invalid section repair to normalize to Required milestones"
    }

    $missingMarkerFixture = New-IssueFixturePath -Name "fast-setup-missing-marker.json" -RepoName "fast-setup" -NoMarker
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $fastRepo, "-Issue", "1", "-IssueFixturePath", $missingMarkerFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect missing marker blocks" -Run $run -ExpectedOk $false -ReasonPattern "convert-idea-to-issue"

    $missingCandidateFixture = New-IssueFixturePath -Name "fast-setup-missing-candidate.json" -RepoName "fast-setup" -NoCandidateFiles
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $fastRepo, "-Issue", "1", "-IssueFixturePath", $missingCandidateFixture, "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect missing candidate files blocks" -Run $run -ExpectedOk $false -ReasonPattern "candidate_allowed_files"

    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "Inspect", "-RepoRoot", $fastRepo, "-Issue", "https://github.com/example/other/issues/1", "-SkipGhAuth")
    Assert-Contract -Name "prepare inspect issue URL repo mismatch blocks" -Run $run -ExpectedOk $false -ReasonPattern "issue URL repository does not match"

    $fastHandoffJson = [string]$inspectRun.Result.evidence.handoff_json
    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "ApplySetup", "-RepoRoot", $fastRepo, "-HandoffJson", $fastHandoffJson)
    Assert-Contract -Name "prepare apply requires preflight proof" -Run $run -ExpectedOk $false -ReasonPattern "preflight proof"

    $fastPreflight = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $fastRepo, "-HandoffJson", $fastHandoffJson, "-SkipGhAuth")
    Assert-Contract -Name "prepare fast handoff passes preflight" -Run $fastPreflight -ExpectedOk $true -ReasonPattern "preflight passed"

    $applyRun = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "ApplySetup", "-RepoRoot", $fastRepo, "-HandoffJson", $fastHandoffJson, "-PreflightJson", $fastPreflight.Stdout)
    Assert-Contract -Name "prepare apply builds GoalBuddy board" -Run $applyRun -ExpectedOk $true -ReasonPattern "setup applied"
    if (-not (Test-Path -LiteralPath (Join-Path $fastRepo "docs\goals\test-goal\notes") -PathType Container)) {
        throw "prepare apply did not create required GoalBuddy notes directory"
    }

    $run = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $fastRepo, "-HandoffJson", $fastHandoffJson, "-PreflightJson", $fastPreflight.Stdout, "-NativeGoalProofJson", (New-NativeGoalProofJson -RepoName "fast-setup" -FakeString))
    Assert-Contract -Name "prepare finalize rejects plain native goal proof" -Run $run -ExpectedOk $false -ReasonPattern "structured|get_goal proof"

    $finalizeRun = Invoke-ContractScriptForTest -ScriptName "prepare-execution.ps1" -Arguments @("-Mode", "FinalizeSetup", "-RepoRoot", $fastRepo, "-HandoffJson", $fastHandoffJson, "-PreflightJson", $fastPreflight.Stdout, "-NativeGoalProofJson", (New-NativeGoalProofJson -RepoName "fast-setup"))
    Assert-Contract -Name "prepare finalize emits setup ledger" -Run $finalizeRun -ExpectedOk $true -ReasonPattern "setup ledger finalized"

    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $fastRepo, "-HandoffJson", $fastHandoffJson, "-SetupLedgerJson", ([string]$finalizeRun.Result.evidence.setup_ledger_json), "-SkipGoalBuddyCheck")
    Assert-Contract -Name "prepare generated setup passes setup gate" -Run $run -ExpectedOk $true -ReasonPattern "setup ledger passed"

    $milestonePlanHandoff = New-HandoffJson -SliceRoadmap "docs/milestones/M0-governance/issues/test-goal.md"
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $happyPreflightRepo, "-HandoffJson", $milestonePlanHandoff, "-SkipGhAuth")
    Assert-Contract -Name "milestone local issue-file path preflight passes" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $milestoneHandoff = New-HandoffJson -FullRoadmap "docs/roadmaps/FULL_ROADMAP.md" -MilestonePolicy "hard" -MilestoneTitle "M4 - Equilibrium" -MilestoneSection "Required milestones"
    $missingFullRoadmapHandoff = New-HandoffJson -FullRoadmap "none" -MilestonePolicy "hard" -MilestoneTitle "M4 - Equilibrium" -MilestoneSection "Required milestones"
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $happyPreflightRepo, "-HandoffJson", $missingFullRoadmapHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "milestones with no full roadmap block" -Run $run -ExpectedOk $false -ReasonPattern "full_roadmap"

    $missingMilestoneHandoff = New-HandoffJson -FullRoadmap "docs/roadmaps/FULL_ROADMAP.md" -MilestonePolicy "hard" -MilestoneTitle "none" -MilestoneSection "Required milestones"
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $happyPreflightRepo, "-HandoffJson", $missingMilestoneHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "missing handoff milestone blocks" -Run $run -ExpectedOk $false -ReasonPattern "milestone_title"

    $milestonePreflightRepo = New-TestRepo -Name "milestone-preflight" -WithRemote -WithMattSetup
    Add-FullRoadmapFixture -Repo $milestonePreflightRepo
    Commit-TestRepoVisibleChanges -Repo $milestonePreflightRepo -Message "add full roadmap"
    Invoke-TestGit -Repo $milestonePreflightRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $milestonePreflightRepo, "-HandoffJson", $milestoneHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "milestone-aligned preflight passes" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $genericMilestoneRepo = New-TestRepo -Name "generic-milestone-preflight" -WithRemote -WithMattSetup
    Add-GenericFullRoadmapFixture -Repo $genericMilestoneRepo
    Commit-TestRepoVisibleChanges -Repo $genericMilestoneRepo -Message "add generic full roadmap"
    Invoke-TestGit -Repo $genericMilestoneRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $genericMilestoneHandoff = New-HandoffJson -FullRoadmap "docs/roadmaps/FULL_ROADMAP.md" -MilestonePolicy "hard" -MilestoneTitle "Build Beta" -MilestoneSection "Milestones"
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $genericMilestoneRepo, "-HandoffJson", $genericMilestoneHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $genericMilestonesFixture)
    Assert-Contract -Name "generic milestone headings pass" -Run $run -ExpectedOk $true -ReasonPattern "preflight passed"

    $nonexistentMilestoneHandoff = New-HandoffJson -FullRoadmap "docs/roadmaps/FULL_ROADMAP.md" -MilestonePolicy "hard" -MilestoneTitle "M9 - Missing" -MilestoneSection "Required milestones"
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $milestonePreflightRepo, "-HandoffJson", $nonexistentMilestoneHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "nonexistent selected milestone blocks" -Run $run -ExpectedOk $false -ReasonPattern "selected GitHub milestone"

    $titleDriftRepo = New-TestRepo -Name "milestone-title-drift" -WithRemote -WithMattSetup
    Add-FullRoadmapFixture -Repo $titleDriftRepo -M4Title "M4 - Wrong"
    Commit-TestRepoVisibleChanges -Repo $titleDriftRepo -Message "add drifted full roadmap"
    Invoke-TestGit -Repo $titleDriftRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $titleDriftRepo, "-HandoffJson", $milestoneHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "roadmap milestone title drift blocks" -Run $run -ExpectedOk $false -ReasonPattern "missing GitHub milestone title"

    $descriptionDriftRepo = New-TestRepo -Name "milestone-description-drift" -WithRemote -WithMattSetup
    Add-FullRoadmapFixture -Repo $descriptionDriftRepo -M4Description "Different equilibrium milestone meaning."
    Commit-TestRepoVisibleChanges -Repo $descriptionDriftRepo -Message "add drifted full roadmap"
    Invoke-TestGit -Repo $descriptionDriftRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "preflight.ps1" -Arguments @("-RepoRoot", $descriptionDriftRepo, "-HandoffJson", $milestoneHandoff, "-SkipGhAuth", "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "roadmap milestone description drift blocks" -Run $run -ExpectedOk $false -ReasonPattern "description drifts"

    $setupMismatchRepo = Initialize-SetupRepo -Name "setup-mismatch"
    $setupMismatchLedger = New-SetupLedgerJson -RepoName "setup-mismatch" -BranchOverride "codex/other"
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $setupMismatchRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupMismatchLedger, "-SkipGoalBuddyCheck")
    Assert-Contract -Name "ledger mismatch blocks" -Run $run -ExpectedOk $false -ReasonPattern "does not match"

    $fakeProofRepo = Initialize-SetupRepo -Name "fake-proof"
    $fakeProofLedger = New-SetupLedgerJson -RepoName "fake-proof" -FakeGoalProof
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $fakeProofRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $fakeProofLedger, "-SkipGoalBuddyCheck")
    Assert-Contract -Name "fake native goal proof blocks" -Run $run -ExpectedOk $false -ReasonPattern "goal_activation_proof"

    $noWorkerRepo = Initialize-SetupRepo -Name "no-worker" -NoWorker
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $noWorkerRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "no-worker"), "-SkipGoalBuddyCheck")
    Assert-Contract -Name "GoalBuddy board without Worker blocks" -Run $run -ExpectedOk $false -ReasonPattern "delegation|Worker"

    $workerMissingVerifyRepo = Initialize-SetupRepo -Name "worker-missing-verify" -WorkerMissingVerify
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $workerMissingVerifyRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "worker-missing-verify"), "-SkipGoalBuddyCheck")
    Assert-Contract -Name "Worker missing verify blocks" -Run $run -ExpectedOk $false -ReasonPattern "delegation|verify"

    $staleTrackedRepo = New-TestRepo -Name "stale-tracked" -WithRemote -WithMattSetup
    New-Item -ItemType Directory -Path (Join-Path $staleTrackedRepo "docs\goals\old") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $staleTrackedRepo "docs\goals\old\goal.md") -Value "# Old`n" -Encoding UTF8
    Invoke-TestGit -Repo $staleTrackedRepo -Arguments @("add", ".") | Out-Null
    Invoke-TestGit -Repo $staleTrackedRepo -Arguments @("commit", "-m", "track old goal") | Out-Null
    Invoke-TestGit -Repo $staleTrackedRepo -Arguments @("checkout", "-b", "codex/test-goal") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $staleTrackedRepo "docs\issues") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $staleTrackedRepo "docs\issues\test-goal.md") -Value "- [x] Gate complete`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $staleTrackedRepo ".gitignore") -Value "docs/goals/`n**/.goalbuddy-board/`n" -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $staleTrackedRepo "docs\goals\test-goal") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $staleTrackedRepo "docs\goals\test-goal\goal.md") -Value "# Test Goal`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $staleTrackedRepo "docs\goals\test-goal\state.yaml") -Value (New-GoalStateYaml) -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $staleTrackedRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "stale-tracked"), "-SkipGoalBuddyCheck")
    Assert-Contract -Name "stale tracked goal docs block" -Run $run -ExpectedOk $false -ReasonPattern "tracked GoalBuddy docs"

    $happySetupRepo = Initialize-SetupRepo -Name "happy-setup"
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $happySetupRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "happy-setup"), "-SkipGoalBuddyCheck")
    Assert-Contract -Name "happy setup passes" -Run $run -ExpectedOk $true -ReasonPattern "setup ledger passed"

    $milestoneSetupRepo = Initialize-SetupRepo -Name "milestone-setup"
    Add-FullRoadmapFixture -Repo $milestoneSetupRepo
    $issueNoMilestone = New-FixturePath "setup-issue-no-milestone.json"
    @{ state = "OPEN"; body = "- [x] Acceptance criterion" } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueNoMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $milestoneSetupRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "milestone-setup"), "-IssueFixturePath", $issueNoMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture, "-SkipGoalBuddyCheck")
    Assert-Contract -Name "setup issue without milestone blocks" -Run $run -ExpectedOk $false -ReasonPattern "no milestone"

    $issueWrongMilestone = New-FixturePath "setup-issue-wrong-milestone.json"
    @{ state = "OPEN"; body = "- [x] Acceptance criterion"; milestone = @{ title = "M3 - EOS" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueWrongMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $milestoneSetupRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "milestone-setup"), "-IssueFixturePath", $issueWrongMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture, "-SkipGoalBuddyCheck")
    Assert-Contract -Name "setup issue wrong milestone blocks" -Run $run -ExpectedOk $false -ReasonPattern "milestone does not match"

    $issueCorrectMilestone = New-FixturePath "setup-issue-correct-milestone.json"
    @{ state = "OPEN"; body = "- [x] Acceptance criterion"; milestone = @{ title = "M4 - Equilibrium" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueCorrectMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "validate-setup.ps1" -Arguments @("-RepoRoot", $milestoneSetupRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", (New-SetupLedgerJson -RepoName "milestone-setup"), "-IssueFixturePath", $issueCorrectMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture, "-SkipGoalBuddyCheck")
    Assert-Contract -Name "milestone-aligned setup passes" -Run $run -ExpectedOk $true -ReasonPattern "setup ledger passed"

    $premergeRepo = Initialize-SetupRepo -Name "premerge"
    Add-FullRoadmapFixture -Repo $premergeRepo
    Commit-TestRepoVisibleChanges -Repo $premergeRepo -Message "prepare premerge state"
    $issueFixture = New-FixturePath "premerge-issue.json"
    @{ state = "OPEN"; body = "- [x] Acceptance criterion" } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueFixture -Encoding UTF8
    $setupPremerge = New-SetupLedgerJson -RepoName "premerge"

    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "other"), "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "verification PR repo mismatch blocks" -Run $run -ExpectedOk $false -ReasonPattern "pr_url does not belong"

    $missingClosing = New-FixturePath "pr-missing-closing.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        mergeable = "MERGEABLE"
        reviewDecision = "REVIEW_REQUIRED"
        body = "Related to #1"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @()
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
        reviewThreads = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $missingClosing -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $missingClosing, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "missing PR closing keyword blocks" -Run $run -ExpectedOk $false -ReasonPattern "closing keyword"

    $wrongIssuePr = New-FixturePath "pr-wrong-issue.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        mergeable = "MERGEABLE"
        reviewDecision = "REVIEW_REQUIRED"
        body = "Closes #999"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 999 })
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
        reviewThreads = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $wrongIssuePr -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $wrongIssuePr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "PR closing wrong issue blocks" -Run $run -ExpectedOk $false -ReasonPattern "exact linked issue|closingIssuesReferences"

    $wrongBranchPr = New-FixturePath "pr-wrong-branch.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        mergeable = "MERGEABLE"
        reviewDecision = "REVIEW_REQUIRED"
        body = "Closes #1"
        headRefName = "not-the-goal-branch"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
        reviewThreads = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $wrongBranchPr -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $wrongBranchPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "PR head branch mismatch blocks" -Run $run -ExpectedOk $false -ReasonPattern "head branch"

    $unknownMergeablePr = New-FixturePath "pr-unknown-mergeable.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        reviewDecision = "REVIEW_REQUIRED"
        body = "Closes #1"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
        reviewThreads = @()
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $unknownMergeablePr -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $unknownMergeablePr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "unknown mergeability blocks" -Run $run -ExpectedOk $false -ReasonPattern "mergeable"

    $missingThreadsPr = New-FixturePath "pr-missing-threads.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        mergeable = "MERGEABLE"
        reviewDecision = "REVIEW_REQUIRED"
        body = "Closes #1"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $missingThreadsPr -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $missingThreadsPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "missing review-thread data blocks" -Run $run -ExpectedOk $false -ReasonPattern "review thread data"

    $unresolvedReview = New-FixturePath "pr-unresolved-review.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        mergeable = "MERGEABLE"
        reviewDecision = "REVIEW_REQUIRED"
        body = "Closes #1"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
        reviewThreads = @(@{ isResolved = $false; isOutdated = $false; comments = @{ nodes = @(@{ url = "https://example.invalid/thread" }) } })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $unresolvedReview -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $unresolvedReview, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "unresolved review thread blocks" -Run $run -ExpectedOk $false -ReasonPattern "unresolved"

    $noCheckboxIssue = New-FixturePath "issue-no-checkbox.json"
    @{ state = "OPEN"; body = "Acceptance criterion without checkbox" } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $noCheckboxIssue -Encoding UTF8
    $happyPr = New-FixturePath "pr-happy.json"
    @{
        url = "https://github.com/example/premerge/pull/2"
        state = "OPEN"
        isDraft = $false
        mergeable = "MERGEABLE"
        reviewDecision = "REVIEW_REQUIRED"
        body = "Closes #1"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
        statusCheckRollup = @(@{ name = "ci"; status = "COMPLETED"; conclusion = "SUCCESS" })
        requiredChecks = @(@{ name = "ci"; bucket = "pass"; state = "SUCCESS"; workflow = "ci"; link = "https://example.invalid/check" })
        files = @(@{ path = "src/example.txt" }, @{ path = "docs/issues/test-goal.md" })
        reviewThreads = @(@{ isResolved = $true; isOutdated = $false; comments = @{ nodes = @() } })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $happyPr -Encoding UTF8

    $premergeResidue = Join-Path $premergeRepo "uncommitted.txt"
    Set-Content -LiteralPath $premergeResidue -Value "residue" -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "git-visible residue before premerge blocks" -Run $run -ExpectedOk $false -ReasonPattern "git-visible residue"
    Remove-Item -LiteralPath $premergeResidue -Force

    $zeroChecksPr = New-FixturePath "pr-zero-required-checks.json"
    @($happyPr | ForEach-Object { Get-Content -LiteralPath $_ -Raw | ConvertFrom-Json }) | ForEach-Object {
        $_.requiredChecks = @()
        $_ | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $zeroChecksPr -Encoding UTF8
    }
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $zeroChecksPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "zero required checks block by default" -Run $run -ExpectedOk $false -ReasonPattern "no required GitHub checks"

    $allowNoChecksHandoff = New-HandoffJson -RequiredChecksPolicy "allow-none-with-local-proof"
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $allowNoChecksHandoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $zeroChecksPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "zero required checks pass only with explicit policy" -Run $run -ExpectedOk $true -ReasonPattern "premerge checks passed"

    $pendingCheckPr = New-FixturePath "pr-pending-required-check.json"
    @($happyPr | ForEach-Object { Get-Content -LiteralPath $_ -Raw | ConvertFrom-Json }) | ForEach-Object {
        $_.requiredChecks = @(@{ name = "ci"; bucket = "pending"; state = "PENDING"; workflow = "ci"; link = "https://example.invalid/check" })
        $_ | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $pendingCheckPr -Encoding UTF8
    }
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $pendingCheckPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "pending required check blocks" -Run $run -ExpectedOk $false -ReasonPattern "required GitHub checks"

    $uncoveredPr = New-FixturePath "pr-uncovered-file.json"
    @($happyPr | ForEach-Object { Get-Content -LiteralPath $_ -Raw | ConvertFrom-Json }) | ForEach-Object {
        $_.files = @(@{ path = "src/uncovered.txt" }, @{ path = "docs/issues/test-goal.md" })
        $_ | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $uncoveredPr -Encoding UTF8
    }
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $uncoveredPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "uncovered PR changed file blocks" -Run $run -ExpectedOk $false -ReasonPattern "cover all PR changed files"

    $closedIssueBeforeMerge = New-FixturePath "issue-preclosed.json"
    @{ state = "CLOSED"; body = "- [x] Acceptance criterion" } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $closedIssueBeforeMerge -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $closedIssueBeforeMerge)
    Assert-Contract -Name "pre-closed linked issue blocks" -Run $run -ExpectedOk $false -ReasonPattern "not open before merge"

    $premergeWrongMilestone = New-FixturePath "premerge-issue-wrong-milestone.json"
    @{ state = "OPEN"; body = "- [x] Acceptance criterion"; milestone = @{ title = "M3 - EOS" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $premergeWrongMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $premergeWrongMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "PR issue milestone changed before merge blocks" -Run $run -ExpectedOk $false -ReasonPattern "milestone does not match"

    $premergeCorrectMilestone = New-FixturePath "premerge-issue-correct-milestone.json"
    @{ state = "OPEN"; body = "- [x] Acceptance criterion"; milestone = @{ title = "M4 - Equilibrium" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $premergeCorrectMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $premergeCorrectMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "milestone-aligned premerge passes" -Run $run -ExpectedOk $true -ReasonPattern "premerge checks passed"

    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $noCheckboxIssue)
    Assert-Contract -Name "issue without checkboxes blocks" -Run $run -ExpectedOk $false -ReasonPattern "no acceptance-criteria"

    Set-Content -LiteralPath (Join-Path $premergeRepo "docs\issues\test-goal.md") -Value "- [ ] Gate incomplete`n" -Encoding UTF8
    Commit-TestRepoVisibleChanges -Repo $premergeRepo -Message "make local issue gate incomplete"
    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "unchecked local issue gate blocks" -Run $run -ExpectedOk $false -ReasonPattern "unchecked gates"
    Set-Content -LiteralPath (Join-Path $premergeRepo "docs\issues\test-goal.md") -Value "- [x] Gate complete`n" -Encoding UTF8
    Commit-TestRepoVisibleChanges -Repo $premergeRepo -Message "restore local issue gate"

    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge" -ExitCode 1), "-PrFixturePath", $happyPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "failing verification ledger blocks" -Run $run -ExpectedOk $false -ReasonPattern "verification command failed"

    $run = Invoke-ContractScriptForTest -ScriptName "premerge.ps1" -Arguments @("-RepoRoot", $premergeRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupPremerge, "-VerificationLedgerJson", (New-VerificationLedgerJson -RepoName "premerge"), "-PrFixturePath", $happyPr, "-IssueFixturePath", $issueFixture)
    Assert-Contract -Name "happy premerge passes" -Run $run -ExpectedOk $true -ReasonPattern "premerge checks passed"

    $closeoutRepo = New-TestRepo -Name "closeout" -WithRemote -WithMattSetup
    Add-FullRoadmapFixture -Repo $closeoutRepo
    Commit-TestRepoVisibleChanges -Repo $closeoutRepo -Message "add full roadmap"
    Invoke-TestGit -Repo $closeoutRepo -Arguments @("update-ref", "refs/remotes/origin/main", "HEAD") | Out-Null
    $setupCloseout = New-SetupLedgerJson -RepoName "closeout"
    $completionCloseout = New-CompletionLedgerJson -RepoName "closeout"
    $completionWrongPrRepo = New-CompletionLedgerJson -RepoName "closeout" | ConvertFrom-Json
    $completionWrongPrRepo.pr_url = "https://github.com/example/other/pull/2"
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", ($completionWrongPrRepo | ConvertTo-Json -Depth 20))
    Assert-Contract -Name "completion PR repo mismatch blocks" -Run $run -ExpectedOk $false -ReasonPattern "pr_url does not belong"

    $issueClosed = New-FixturePath "closeout-issue-closed.json"
    @{ state = "CLOSED"; body = "- [x] Acceptance criterion" } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueClosed -Encoding UTF8
    $prMerged = New-FixturePath "closeout-pr-merged.json"
    @{
        url = "https://github.com/example/closeout/pull/2"
        state = "MERGED"
        mergedAt = "2026-01-01T00:00:00Z"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $prMerged -Encoding UTF8

    $prOpenButMergedAt = New-FixturePath "closeout-pr-open-but-merged.json"
    @{
        url = "https://github.com/example/closeout/pull/2"
        state = "OPEN"
        mergedAt = "2026-01-01T00:00:00Z"
        headRefName = "codex/test-goal"
        baseRefName = "main"
        closingIssuesReferences = @(@{ number = 1 })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $prOpenButMergedAt -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prOpenButMergedAt, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "open PR with mergedAt blocks" -Run $run -ExpectedOk $false -ReasonPattern "not merged"

    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", (New-CompletionLedgerJson -RepoName "closeout" -FakeStrings), "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "fake completion strings block" -Run $run -ExpectedOk $false -ReasonPattern "structured"

    $issueClosedWrongMilestone = New-FixturePath "closeout-issue-wrong-milestone.json"
    @{ state = "CLOSED"; body = "- [x] Acceptance criterion"; milestone = @{ title = "M3 - EOS" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueClosedWrongMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosedWrongMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "closeout issue wrong milestone blocks" -Run $run -ExpectedOk $false -ReasonPattern "milestone does not match"

    $issueClosedCorrectMilestone = New-FixturePath "closeout-issue-correct-milestone.json"
    @{ state = "CLOSED"; body = "- [x] Acceptance criterion"; milestone = @{ title = "M4 - Equilibrium" } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $issueClosedCorrectMilestone -Encoding UTF8
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $milestoneHandoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosedCorrectMilestone, "-MilestonesFixturePath", $epcsaftMilestonesFixture)
    Assert-Contract -Name "milestone-aligned closeout passes" -Run $run -ExpectedOk $true -ReasonPattern "closeout checks passed"

    Invoke-TestGit -Repo $closeoutRepo -Arguments @("branch", "codex/test-goal") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "goal branch still present blocks" -Run $run -ExpectedOk $false -ReasonPattern "branch inventory|local branch still exists"
    Invoke-TestGit -Repo $closeoutRepo -Arguments @("branch", "-D", "codex/test-goal") | Out-Null

    $setupMissingUnrelated = New-SetupLedgerJson -RepoName "closeout" -LocalBranchesBefore @("main", "feature/keep")
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupMissingUnrelated, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "unrelated branch removal blocks" -Run $run -ExpectedOk $false -ReasonPattern "branch inventory"

    $badRemoteCleanup = New-CompletionLedgerJson -RepoName "closeout" -RemoteDeleteTarget "feature/other" -RemoteDeletedBranches @("feature/other")
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $badRemoteCleanup, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "non-goal remote deletion target blocks" -Run $run -ExpectedOk $false -ReasonPattern "remote_delete_target|non-goal"

    Invoke-TestGit -Repo $closeoutRepo -Arguments @("update-ref", "refs/remotes/origin/feature/other", "HEAD") | Out-Null
    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "unrelated remote branch churn does not block" -Run $run -ExpectedOk $true -ReasonPattern "closeout checks passed"

    $run = Invoke-ContractScriptForTest -ScriptName "closeout.ps1" -Arguments @("-RepoRoot", $closeoutRepo, "-HandoffJson", $handoff, "-SetupLedgerJson", $setupCloseout, "-CompletionLedgerJson", $completionCloseout, "-PrFixturePath", $prMerged, "-IssueFixturePath", $issueClosed)
    Assert-Contract -Name "happy closeout passes" -Run $run -ExpectedOk $true -ReasonPattern "closeout checks passed"

    $skillText = Get-Content -LiteralPath (Join-Path $skillRoot "SKILL.md") -Raw
    $scriptContractOk = (
        $skillText -match [regex]::Escape("C:\Users\Tanner\.agents\skills\resolve-issue-with-goal\scripts\") -and
        $skillText -match "Target repositories must not be required to contain" -and
        $skillText -match [regex]::Escape('bundled `scripts\repo-gate.ps1 -RepoRoot <target-repo-root>`') -and
        $skillText -match [regex]::Escape('bundled `scripts\prepare-execution.ps1 -Mode Inspect -RepoRoot <target-repo-root>`') -and
        $skillText -match "issue URL repo and -RepoRoot origin must match"
    )
    Add-TestResult -Name "skill text requires bundled script resolution" -Passed $scriptContractOk -Reason "skill scripts are package-owned and invoked with explicit RepoRoot"

    $superpowersContractOk = (
        $skillText -match "Superpowers And GitHub Specialist Routing" -and
        $skillText -match "superpowers:using-superpowers" -and
        $skillText -match "superpowers:test-driven-development" -and
        $skillText -match "superpowers:systematic-debugging" -and
        $skillText -match "superpowers:subagent-driven-development" -and
        $skillText -match "superpowers:verification-before-completion" -and
        $skillText -match "github:gh-fix-ci" -and
        $skillText -match "github:gh-address-comments" -and
        $skillText -match "gate script wins"
    )
    Add-TestResult -Name "skill text routes Superpowers and GitHub specialists" -Passed $superpowersContractOk -Reason "execution method routes through Superpowers without replacing gate scripts"

    $packageDiff = Compare-PackageSnapshot -Before $packageSnapshotBefore -After (Get-PackageSnapshot -Root $skillRoot)
    Add-TestResult -Name "skill package stays clean after scenarios" -Passed ($packageDiff.Count -eq 0) -Reason ($(if ($packageDiff.Count -eq 0) { "skill package clean" } else { $packageDiff -join "; " })) -Details @{ changes = $packageDiff }

    $failed = @($results | Where-Object { -not $_.passed })
    if ($failed.Count -gt 0) {
        Stop-Contract -Phase $phase -Reason "$($failed.Count) scenario test(s) failed" -Evidence @{ tests = $results }
    }
    Complete-Contract -Phase $phase -Reason "all scenario tests passed" -Evidence @{ tests = $results }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence @{ tests = $results }
} finally {
    if ($null -eq $previousTestMode) {
        Remove-Item Env:\RIWG_TEST_MODE -ErrorAction SilentlyContinue
    } else {
        $env:RIWG_TEST_MODE = $previousTestMode
    }
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
