$ErrorActionPreference = "Stop"

function Write-ContractResult {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{},
        [int]$FailureExitCode = 1
    )

    [ordered]@{
        ok = $Ok
        phase = $Phase
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 32

    if ($Ok) { exit 0 }
    exit $FailureExitCode
}

function Stop-Contract {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{}
    )
    Write-ContractResult -Phase $Phase -Ok $false -Reason $Reason -Evidence $Evidence
}

function Complete-Contract {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{}
    )
    Write-ContractResult -Phase $Phase -Ok $true -Reason $Reason -Evidence $Evidence
}

function Test-RiwgTestMode {
    return [string]$env:RIWG_TEST_MODE -eq "1"
}

function Assert-TestModeSwitch {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Test-RiwgTestMode)) {
        throw "$Name is test-only and cannot be used in live runs"
    }
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 60
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    try {
        [void]$process.Start()
        $processId = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        $exited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            try {
                $process.Kill($true)
            } catch {
                if (-not $process.HasExited) { throw }
            }
            $process.WaitForExit()
            [void]$stdoutTask.Wait(1000)
            [void]$stderrTask.Wait(1000)
            [pscustomobject]@{
                ExitCode = 124
                Stdout = (($stdoutTask.Result) -replace "(\r?\n)+$", "")
                Stderr = "external command timed out after $TimeoutSeconds seconds: $FilePath $($Arguments -join ' ')"
                TimedOut = $true
                TimeoutSeconds = $TimeoutSeconds
                ProcessId = $processId
            }
            return
        }

        $process.WaitForExit()
        [void]$stdoutTask.Wait(1000)
        [void]$stderrTask.Wait(1000)
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = (($stdoutTask.Result) -replace "(\r?\n)+$", "")
            Stderr = (($stderrTask.Result) -replace "(\r?\n)+$", "")
            TimedOut = $false
            TimeoutSeconds = $TimeoutSeconds
            ProcessId = $processId
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    Invoke-External -FilePath "git" -Arguments (@("-C", $RepoRoot) + $Arguments) -WorkingDirectory $RepoRoot
}

function Invoke-Gh {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = (Get-Location).Path
    )
    Invoke-External -FilePath "gh" -Arguments $Arguments -WorkingDirectory $WorkingDirectory
}

function Get-CanonicalRepoRoot {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
        throw "Repo root does not exist: $RepoRoot"
    }

    $git = Invoke-Git -RepoRoot $RepoRoot -Arguments @("rev-parse", "--show-toplevel")
    if ($git.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($git.Stdout)) {
        throw "Not a git repository: $RepoRoot"
    }
    [IO.Path]::GetFullPath($git.Stdout)
}

function Get-OriginRemoteSlug {
    param([Parameter(Mandatory = $true)][string]$RemoteUrl)

    $value = $RemoteUrl.Trim()
    if ($value -match "^(?:git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") {
        return "$($Matches.owner)/$($Matches.repo)"
    }
    if ($value -match "^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") {
        return "$($Matches.owner)/$($Matches.repo)"
    }
    return $null
}

function Read-JsonInput {
    param(
        [string]$Json,
        [string]$Path,
        [string]$Name = "json"
    )

    $text = $null
    if (-not [string]::IsNullOrWhiteSpace($Json)) {
        $text = $Json
    } elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "$Name path not found: $Path"
        }
        $text = Get-Content -LiteralPath $Path -Raw
    } else {
        throw "Missing $Name input."
    }

    $trimmed = $text.Trim()
    if ($trimmed -match '```') {
        $lines = $text -split '\r?\n'
        $capture = $false
        $captured = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $lines) {
            if (-not $capture -and $line -match '^```\S*\s*resolve_issue_with_goal_handoff\s*$') {
                $capture = $true
                continue
            }
            if (-not $capture -and $line -match '^```\s*(json|JSON)?\s*$') {
                $capture = $true
                continue
            }
            if ($capture -and $line -match '^```\s*$') {
                break
            }
            if ($capture) {
                $captured.Add($line)
            }
        }
        if ($captured.Count -gt 0) {
            $trimmed = ($captured -join "`n").Trim()
        }
    }

    try {
        $trimmed | ConvertFrom-Json
    } catch {
        throw "Invalid $Name JSON: $($_.Exception.Message)"
    }
}

function Test-Property {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    return $Object.PSObject.Properties.Name -contains $Name
}

function Get-StringArray {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    return @($Value | ForEach-Object { [string]$_ })
}

function Test-RequiredFields {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string[]]$Fields
    )

    $missing = @()
    foreach ($field in $Fields) {
        if (-not (Test-Property -Object $Object -Name $field)) {
            $missing += $field
            continue
        }
        $value = $Object.$field
        if ($null -eq $value) {
            $missing += $field
        } elseif ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            $missing += $field
        }
    }
    $missing
}

function Normalize-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "\\", "/").Trim()
}

function Assert-SafeRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $normalized = Normalize-RepoPath $Path
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "$Name is empty"
    }
    if ([IO.Path]::IsPathRooted($Path) -or $normalized -match '^[A-Za-z]:' -or $normalized.StartsWith("/")) {
        throw "$Name must be repo-relative: $Path"
    }
    if ($normalized -match '(^|/)\.\.(/|$)') {
        throw "$Name must not contain parent traversal: $Path"
    }
    if ($normalized -match '[<>:"|?*]') {
        throw "$Name contains invalid path characters: $Path"
    }
    $normalized
}

function Assert-NonWeakString {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $normalized = $Value.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($Value) -or $normalized -in @("unknown", "tbd", "todo", "none", "n/a", "na") -or $normalized -match '^<.*>$') {
        throw "$Name is weak or placeholder"
    }
}

function Test-SlicePlanPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Slug
    )

    $normalized = Normalize-RepoPath $Path
    $escapedSlug = [regex]::Escape($Slug)
    return (
        $normalized -eq "docs/issues/$Slug.md" -or
        $normalized -match "^docs/issues/\d{1,6}-$escapedSlug\.md$" -or
        $normalized -eq "docs/milestones/no-milestone/issues/$Slug.md" -or
        $normalized -match "^docs/milestones/[^/]+/issues/$escapedSlug\.md$" -or
        $normalized -match "^docs/milestones/[^/]+/issues/\d{1,6}-$escapedSlug\.md$"
    )
}

function Normalize-ContractText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return (($Text -replace '\s+', ' ').Trim())
}

function Get-MilestoneList {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$RemoteSlug,
        [string]$FixturePath
    )

    $raw = if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        Read-JsonInput -Path $FixturePath -Name "milestones fixture"
    } else {
        $result = Invoke-Gh -Arguments @("api", "repos/$RemoteSlug/milestones?state=all&per_page=100") -WorkingDirectory $RepoRoot
        if ($result.ExitCode -ne 0) { throw "could not read GitHub milestones: $($result.Stderr)" }
        $result.Stdout | ConvertFrom-Json
    }

    if ($null -eq $raw) { return @() }
    if (Test-Property -Object $raw -Name "milestones") { return @($raw.milestones) }
    @($raw)
}

function Get-GithubProjectsSummary {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$RemoteSlug,
        [string]$FixturePath
    )

    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        $raw = Read-JsonInput -Path $FixturePath -Name "projects fixture"
        $projects = if (Test-Property -Object $raw -Name "projects") { @($raw.projects) } else { @($raw) }
        return [pscustomobject]@{
            checked = $true
            error = $null
            projects = $projects
        }
    }

    $parts = $RemoteSlug -split "/", 2
    if ($parts.Count -ne 2) {
        return [pscustomobject]@{ checked = $false; error = "invalid remote slug"; projects = @() }
    }
    $query = @"
query(`$owner:String!, `$repo:String!) {
  repository(owner: `$owner, name: `$repo) {
    projectsV2(first: 20) {
      nodes { title url closed number }
    }
    owner {
      __typename
      ... on Organization {
        projectsV2(first: 20) {
          nodes { title url closed number }
        }
      }
      ... on User {
        projectsV2(first: 20) {
          nodes { title url closed number }
        }
      }
    }
  }
}
"@
    $result = Invoke-Gh -Arguments @("api", "graphql", "-f", "query=$query", "-F", "owner=$($parts[0])", "-F", "repo=$($parts[1])") -WorkingDirectory $RepoRoot
    if ($result.ExitCode -ne 0) {
        return [pscustomobject]@{ checked = $false; error = $result.Stderr; projects = @() }
    }

    try {
        $object = $result.Stdout | ConvertFrom-Json
        $projects = @()
        $projects += @($object.data.repository.projectsV2.nodes)
        $projects += @($object.data.repository.owner.projectsV2.nodes)
        return [pscustomobject]@{
            checked = $true
            error = $null
            projects = @($projects | Where-Object { $null -ne $_ })
        }
    } catch {
        return [pscustomobject]@{ checked = $false; error = $_.Exception.Message; projects = @() }
    }
}

function Get-RoadmapMilestoneEntries {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$FullRoadmap,
        [Parameter(Mandatory = $true)][string]$SectionName,
        [string[]]$ExpectedTitles = @()
    )

    $roadmapPath = Join-Path $RepoRoot $FullRoadmap
    if (-not (Test-Path -LiteralPath $roadmapPath -PathType Leaf)) {
        throw "selected full roadmap does not exist: $FullRoadmap"
    }

    $wantedSection = Normalize-ContractText $SectionName
    $entries = @{}
    $inSection = $false
    $sectionLevel = 0
    $currentTitle = $null
    $descriptionLines = [System.Collections.Generic.List[string]]::new()
    $descriptionClosed = $false
    $expectedTitleSet = @{}
    foreach ($title in $ExpectedTitles) {
        $normalizedTitle = Normalize-ContractText $title
        if (-not [string]::IsNullOrWhiteSpace($normalizedTitle)) {
            $expectedTitleSet[$normalizedTitle] = $true
        }
    }

    foreach ($line in (Get-Content -LiteralPath $roadmapPath)) {
        if ($line -match '^(?<hash>#{1,6})\s+(?<text>.+?)\s*$') {
            $level = $Matches.hash.Length
            $headingText = $Matches.text.Trim()
            $comparableHeading = Normalize-ContractText ($headingText -replace '^\d+\.\s*', '')

            if (-not $inSection -and $comparableHeading -eq $wantedSection) {
                $inSection = $true
                $sectionLevel = $level
                continue
            }

            if ($inSection -and $level -le $sectionLevel) {
                if (-not [string]::IsNullOrWhiteSpace($currentTitle)) {
                    $entries[$currentTitle] = Normalize-ContractText ($descriptionLines -join " ")
                }
                break
            }

            if ($inSection) {
                $normalizedHeading = Normalize-ContractText $headingText
                if ($expectedTitleSet.Count -eq 0 -or $expectedTitleSet.ContainsKey($normalizedHeading)) {
                    if (-not [string]::IsNullOrWhiteSpace($currentTitle)) {
                        $entries[$currentTitle] = Normalize-ContractText ($descriptionLines -join " ")
                    }
                    $currentTitle = $normalizedHeading
                    $descriptionLines = [System.Collections.Generic.List[string]]::new()
                    $descriptionClosed = $false
                } elseif (-not [string]::IsNullOrWhiteSpace($currentTitle) -and $descriptionLines.Count -gt 0) {
                    $descriptionClosed = $true
                }
                continue
            }
        }

        if ($inSection -and (-not [string]::IsNullOrWhiteSpace($currentTitle)) -and (-not $descriptionClosed)) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                if ($descriptionLines.Count -gt 0) { $descriptionClosed = $true }
                continue
            }
            if ($trimmed -match '^[-*]\s+') {
                if ($descriptionLines.Count -gt 0) { $descriptionClosed = $true }
                continue
            }
            $descriptionLines.Add($trimmed)
        }
    }

    if ($inSection -and (-not [string]::IsNullOrWhiteSpace($currentTitle))) {
        $entries[$currentTitle] = Normalize-ContractText ($descriptionLines -join " ")
    }
    if ($entries.Count -eq 0) {
        throw "full roadmap milestone section not found or contains no matching milestone headings: $SectionName"
    }
    $entries
}

function Assert-MilestoneContract {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)]$Handoff,
        [Parameter(Mandatory = $true)][AllowNull()]$Milestones
    )

    $milestoneArray = @($Milestones | Where-Object { $null -ne $_ })
    $policy = [string]$Handoff.milestone_policy

    if ($milestoneArray.Count -eq 0) {
        if ($policy -ne "none") {
            throw "handoff milestone_policy is $policy but the repo has no GitHub milestones"
        }
        return [pscustomobject]@{
            policy = $policy
            milestones_present = $false
            milestone_count = 0
        }
    }

    if ($policy -ne "hard") {
        throw "GitHub milestones exist but handoff milestone_policy is not hard"
    }

    $selectedTitle = Normalize-ContractText ([string]$Handoff.milestone_title)
    $sectionName = Normalize-ContractText ([string]$Handoff.full_roadmap_milestone_section)
    Assert-NonWeakString -Value $selectedTitle -Name "handoff milestone_title"
    Assert-NonWeakString -Value $sectionName -Name "handoff full_roadmap_milestone_section"

    if ([string]$Handoff.full_roadmap -eq "none") {
        throw "GitHub milestones exist but no full roadmap was selected"
    }

    $expectedTitles = @($milestoneArray | ForEach-Object { Normalize-ContractText ([string]$_.title) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $roadmapEntries = Get-RoadmapMilestoneEntries -RepoRoot $RepoRoot -FullRoadmap ([string]$Handoff.full_roadmap) -SectionName $sectionName -ExpectedTitles $expectedTitles
    $selectedMilestone = @($milestoneArray | Where-Object { (Normalize-ContractText ([string]$_.title)) -eq $selectedTitle } | Select-Object -First 1)
    if ($selectedMilestone.Count -eq 0) {
        throw "selected GitHub milestone does not exist: $selectedTitle"
    }

    $missingTitles = @()
    $descriptionDrift = @()
    foreach ($milestone in $milestoneArray) {
        $title = Normalize-ContractText ([string]$milestone.title)
        if ([string]::IsNullOrWhiteSpace($title)) { continue }
        if (-not $roadmapEntries.ContainsKey($title)) {
            $missingTitles += $title
            continue
        }
        $roadmapDescription = Normalize-ContractText ([string]$roadmapEntries[$title])
        $githubDescription = Normalize-ContractText ([string]$milestone.description)
        if ($roadmapDescription -ne $githubDescription) {
            $descriptionDrift += "title='$title' roadmap='$roadmapDescription' github='$githubDescription'"
        }
    }

    if ($missingTitles.Count -gt 0) {
        throw "full roadmap milestone taxonomy is missing GitHub milestone title(s): $($missingTitles -join '; ')"
    }
    if ($descriptionDrift.Count -gt 0) {
        throw "full roadmap milestone description drifts from GitHub milestone: $($descriptionDrift -join ' | ')"
    }

    [pscustomobject]@{
        policy = $policy
        milestones_present = $true
        milestone_count = $milestoneArray.Count
        milestone_title = $selectedTitle
        full_roadmap = [string]$Handoff.full_roadmap
        full_roadmap_milestone_section = $sectionName
    }
}

function Assert-IssueMilestone {
    param(
        [Parameter(Mandatory = $true)]$Issue,
        [Parameter(Mandatory = $true)]$Handoff,
        [Parameter(Mandatory = $true)][string]$IssueUrl
    )

    if ([string]$Handoff.milestone_policy -eq "none") { return }

    $expected = Normalize-ContractText ([string]$Handoff.milestone_title)
    $actual = $null
    if ((Test-Property -Object $Issue -Name "milestone") -and $null -ne $Issue.milestone) {
        if ($Issue.milestone -is [string]) {
            $actual = Normalize-ContractText ([string]$Issue.milestone)
        } elseif (Test-Property -Object $Issue.milestone -Name "title") {
            $actual = Normalize-ContractText ([string]$Issue.milestone.title)
        }
    }

    if ([string]::IsNullOrWhiteSpace($actual)) {
        throw "linked issue has no milestone: $IssueUrl"
    }
    if ($actual -ne $expected) {
        throw "linked issue milestone does not match handoff milestone: issue='$actual' handoff='$expected'"
    }
}

function Get-Handoff {
    param(
        [string]$HandoffJson,
        [string]$HandoffPath
    )

    $handoff = Read-JsonInput -Json $HandoffJson -Path $HandoffPath -Name "handoff"
    if (-not (Test-Property -Object $handoff -Name "issue_url")) {
        if ((Test-Property -Object $handoff -Name "issue_policy") -and [string]$handoff.issue_policy -match '^link:(?<url>https://github\.com/[^/]+/[^/]+/issues/\d+(?:[?#].*)?)$') {
            $handoff | Add-Member -NotePropertyName "issue_url" -NotePropertyValue $Matches.url
        } elseif ((Test-Property -Object $handoff -Name "issue_policy") -and [string]$handoff.issue_policy -eq "create" -and (Test-RiwgTestMode)) {
            $handoff | Add-Member -NotePropertyName "issue_url" -NotePropertyValue "https://github.com/example/repo/issues/1"
        }
    }
    if (-not (Test-Property -Object $handoff -Name "issue_policy") -and (Test-Property -Object $handoff -Name "issue_url")) {
        $handoff | Add-Member -NotePropertyName "issue_policy" -NotePropertyValue ("link:" + [string]$handoff.issue_url)
    }
    if (-not (Test-Property -Object $handoff -Name "target_repo") -and (Test-Property -Object $handoff -Name "issue_url")) {
        $repoSlug = Get-RepoSlugFromIssueUrl -IssueUrl ([string]$handoff.issue_url)
        if (-not [string]::IsNullOrWhiteSpace($repoSlug)) {
            $handoff | Add-Member -NotePropertyName "target_repo" -NotePropertyValue $repoSlug
        }
    }
    if (-not (Test-Property -Object $handoff -Name "issue_readiness") -and (Test-RiwgTestMode)) {
        $handoff | Add-Member -NotePropertyName "issue_readiness" -NotePropertyValue ([pscustomobject]@{
            source = "test fixture"
            state = "OPEN"
            single_execution_scope = $true
            acceptance_criteria_present = $true
            linked_plan_file_exists = $true
            issue_plan_alignment = $true
        })
    }
    $required = @(
        "slug",
        "target_repo",
        "issue_url",
        "outcome",
        "issue_policy",
        "issue_readiness",
        "branch_policy",
        "branch",
        "full_roadmap",
        "plan_file",
        "goal_board",
        "proof_oracle",
        "non_goals",
        "merge_policy",
        "required_checks_policy",
        "milestone_policy",
        "milestone_title",
        "full_roadmap_milestone_section",
        "project_policy",
        "allowed_existing_dirty_paths"
    )
    $missing = Test-RequiredFields -Object $handoff -Fields $required
    if ($missing.Count -gt 0) {
        throw "Handoff JSON missing required fields: $($missing -join ', ')"
    }

    $slug = [string]$handoff.slug
    if ($slug -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
        throw "handoff slug must be kebab-case lowercase alphanumeric"
    }
    Assert-NonWeakString -Value ([string]$handoff.outcome) -Name "handoff outcome"

    if ([string]$handoff.branch_policy -notin @("create", "reuse-current")) {
        throw "handoff branch_policy must be create or reuse-current"
    }
    $expectedBranch = "codex/$slug"
    if ((Normalize-RepoPath ([string]$handoff.branch)) -ne $expectedBranch) {
        throw "handoff branch must equal $expectedBranch"
    }

    $issueUrl = [string]$handoff.issue_url
    if ($issueUrl -notmatch '^https://github\.com/[^/]+/[^/]+/issues/\d+(?:[?#].*)?$') {
        throw "handoff issue_url must be a GitHub issue URL"
    }
    $issueRepo = Get-RepoSlugFromIssueUrl -IssueUrl $issueUrl
    if ([string]$handoff.target_repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "handoff target_repo must be GitHub owner/repo"
    }
    if ($issueRepo -ne [string]$handoff.target_repo) {
        throw "handoff issue_url repository does not match target_repo"
    }
    $issuePolicy = [string]$handoff.issue_policy
    if ($issuePolicy -eq "create" -and -not (Test-RiwgTestMode)) {
        throw "execution handoff requires an existing issue_url; run convert-idea-to-issue first"
    }
    if ($issuePolicy -ne "create" -and $issuePolicy -ne "link:$issueUrl") {
        throw "handoff issue_policy must link the exact issue_url"
    }

    if ($handoff.issue_readiness -is [string]) {
        throw "issue_readiness must be structured"
    }
    $readinessMissing = Test-RequiredFields -Object $handoff.issue_readiness -Fields @(
        "source",
        "state",
        "single_execution_scope",
        "acceptance_criteria_present",
        "linked_plan_file_exists",
        "issue_plan_alignment"
    )
    if ($readinessMissing.Count -gt 0) {
        throw "issue_readiness missing required fields: $($readinessMissing -join ', ')"
    }
    if ([string]$handoff.issue_readiness.state -ne "OPEN") {
        throw "issue_readiness must prove the issue is OPEN"
    }
    foreach ($flag in @("single_execution_scope", "acceptance_criteria_present", "linked_plan_file_exists", "issue_plan_alignment")) {
        if ($handoff.issue_readiness.$flag -ne $true) {
            throw "issue_readiness $flag must be true"
        }
    }

    $sliceRoadmap = Assert-SafeRelativePath -Path ([string]$handoff.plan_file) -Name "handoff plan_file"
    $goalBoard = Assert-SafeRelativePath -Path ([string]$handoff.goal_board) -Name "handoff goal_board"
    if (-not (Test-SlicePlanPath -Path $sliceRoadmap -Slug $slug)) {
        throw "handoff plan_file must be a local issue file: docs/issues/$slug.md or docs/milestones/<milestone-folder>/issues/$slug.md"
    }
    if ($goalBoard -ne "docs/goals/$slug") {
        throw "handoff goal_board must equal docs/goals/$slug"
    }
    if ([string]$handoff.full_roadmap -ne "none") {
        [void](Assert-SafeRelativePath -Path ([string]$handoff.full_roadmap) -Name "handoff full_roadmap")
    }

    $milestonePolicy = [string]$handoff.milestone_policy
    if ($milestonePolicy -notin @("hard", "none")) {
        throw "handoff milestone_policy must be hard or none"
    }
    if ($milestonePolicy -eq "hard") {
        Assert-NonWeakString -Value ([string]$handoff.milestone_title) -Name "handoff milestone_title"
        Assert-NonWeakString -Value ([string]$handoff.full_roadmap_milestone_section) -Name "handoff full_roadmap_milestone_section"
        if ([string]$handoff.full_roadmap -eq "none") {
            throw "handoff full_roadmap is required when milestone_policy is hard"
        }
    } else {
        if ([string]$handoff.milestone_title -ne "none" -or [string]$handoff.full_roadmap_milestone_section -ne "none") {
            throw "handoff milestone_title and full_roadmap_milestone_section must be none when milestone_policy is none"
        }
    }
    if ([string]$handoff.project_policy -ne "dashboard-only") {
        throw "handoff project_policy must be dashboard-only"
    }

    $proofOracle = Get-StringArray $handoff.proof_oracle
    if ($proofOracle.Count -eq 0) { throw "handoff proof_oracle must be non-empty" }
    foreach ($item in $proofOracle) { Assert-NonWeakString -Value $item -Name "handoff proof_oracle item" }
    if ((Get-StringArray $handoff.non_goals).Count -eq 0) { throw "handoff non_goals must be non-empty" }

    foreach ($path in (Get-StringArray $handoff.allowed_existing_dirty_paths)) {
        [void](Assert-SafeRelativePath -Path $path -Name "allowed_existing_dirty_paths item")
    }

    if ([string]$handoff.merge_policy -notmatch 'squash' -or [string]$handoff.merge_policy -notmatch 'closing keyword') {
        throw "handoff merge_policy must require closing keyword and squash merge"
    }

    if ([string]$handoff.required_checks_policy -notin @("require-existing", "allow-none-with-local-proof")) {
        throw "handoff required_checks_policy must be require-existing or allow-none-with-local-proof"
    }

    $handoff
}

function Get-Ledger {
    param(
        [string]$LedgerJson,
        [string]$LedgerPath,
        [string[]]$RequiredFields,
        [string]$Name
    )

    $ledger = Read-JsonInput -Json $LedgerJson -Path $LedgerPath -Name $Name
    $missing = Test-RequiredFields -Object $ledger -Fields $RequiredFields
    if ($missing.Count -gt 0) {
        throw "$Name JSON missing required fields: $($missing -join ', ')"
    }
    $ledger
}

function Assert-SetupLedger {
    param(
        [Parameter(Mandatory = $true)]$Ledger,
        [Parameter(Mandatory = $true)]$Handoff,
        [string]$RemoteSlug
    )

    if ((Normalize-RepoPath ([string]$Ledger.branch)) -ne (Normalize-RepoPath ([string]$Handoff.branch))) {
        throw "setup ledger branch does not match handoff branch"
    }
    if ((Normalize-RepoPath ([string]$Ledger.slice_roadmap_path)) -ne (Normalize-RepoPath ([string]$Handoff.plan_file))) {
        throw "setup ledger local issue path does not match handoff plan_file"
    }
    if ((Normalize-RepoPath ([string]$Ledger.goal_board_path)) -ne (Normalize-RepoPath ([string]$Handoff.goal_board))) {
        throw "setup ledger goal_board_path does not match handoff"
    }

    $issueUrl = [string]$Ledger.issue_url
    if (-not [string]::IsNullOrWhiteSpace($RemoteSlug)) {
        $escaped = [regex]::Escape($RemoteSlug)
        if ($issueUrl -notmatch "^https://github\.com/$escaped/issues/\d+(?:[?#].*)?$") {
            throw "setup ledger issue_url does not belong to the active GitHub remote"
        }
    } elseif ($issueUrl -notmatch "^https://github\.com/[^/]+/[^/]+/issues/\d+(?:[?#].*)?$") {
        throw "setup ledger issue_url is not a GitHub issue URL"
    }

    $proofOracle = Get-StringArray $Ledger.proof_oracle
    if ($proofOracle.Count -eq 0) { throw "setup ledger proof_oracle must be non-empty" }

    if ($Ledger.goal_activation_proof -is [string]) {
        throw "goal_activation_proof must be structured get_goal proof, not a string"
    }
    $proofMissing = Test-RequiredFields -Object $Ledger.goal_activation_proof -Fields @("source", "active", "objective", "objective_refs")
    if ($proofMissing.Count -gt 0) {
        throw "goal_activation_proof missing required fields: $($proofMissing -join ', ')"
    }
    if ([string]$Ledger.goal_activation_proof.source -ne "get_goal") {
        throw "goal_activation_proof source must be get_goal"
    }
    if ($Ledger.goal_activation_proof.active -ne $true) {
        throw "goal_activation_proof must show an active native goal"
    }
    if ($Ledger.goal_activation_proof.objective_refs -is [string]) {
        throw "goal_activation_proof objective_refs must be structured"
    }
    $refs = $Ledger.goal_activation_proof.objective_refs
    $refsMissing = Test-RequiredFields -Object $refs -Fields @("issue_url", "branch", "plan_file", "goal_board", "proof_oracle", "closeout_required")
    if ($refsMissing.Count -gt 0) {
        throw "goal_activation_proof objective_refs missing required fields: $($refsMissing -join ', ')"
    }
    if ([string]$refs.issue_url -ne $issueUrl) {
        throw "goal_activation_proof objective_refs issue_url does not match setup ledger"
    }
    if ((Normalize-RepoPath ([string]$refs.branch)) -ne (Normalize-RepoPath ([string]$Ledger.branch))) {
        throw "goal_activation_proof objective_refs branch does not match setup ledger"
    }
    if ((Normalize-RepoPath ([string]$refs.plan_file)) -ne (Normalize-RepoPath ([string]$Ledger.slice_roadmap_path))) {
        throw "goal_activation_proof objective_refs plan_file does not match setup ledger"
    }
    if ((Normalize-RepoPath ([string]$refs.goal_board)) -ne (Normalize-RepoPath ([string]$Ledger.goal_board_path))) {
        throw "goal_activation_proof objective_refs goal_board does not match setup ledger"
    }
    if ($refs.proof_oracle -ne $true -or $refs.closeout_required -ne $true) {
        throw "goal_activation_proof objective_refs must prove proof_oracle and closeout_required"
    }

    if ($Ledger.branch_inventory_before -is [string]) {
        throw "branch_inventory_before must be structured"
    }
    $inventoryMissing = Test-RequiredFields -Object $Ledger.branch_inventory_before -Fields @("local", "remote")
    if ($inventoryMissing.Count -gt 0) {
        throw "branch_inventory_before missing required fields: $($inventoryMissing -join ', ')"
    }
}

function Get-SetupLedger {
    param(
        [string]$SetupLedgerJson,
        [string]$SetupLedgerPath,
        [Parameter(Mandatory = $true)]$Handoff,
        [string]$RemoteSlug
    )
    $ledger = Get-Ledger -LedgerJson $SetupLedgerJson -LedgerPath $SetupLedgerPath -Name "setup ledger" -RequiredFields @(
        "issue_url",
        "branch",
        "slice_roadmap_path",
        "goal_board_path",
        "goal_activation_proof",
        "proof_oracle",
        "branch_inventory_before"
    )
    Assert-SetupLedger -Ledger $ledger -Handoff $Handoff -RemoteSlug $RemoteSlug
    $ledger
}

function Get-VerificationLedger {
    param(
        [string]$VerificationLedgerJson,
        [string]$VerificationLedgerPath,
        [Parameter(Mandatory = $true)]$SetupLedger
    )

    $ledger = Get-Ledger -LedgerJson $VerificationLedgerJson -LedgerPath $VerificationLedgerPath -Name "verification ledger" -RequiredFields @(
        "pr_url",
        "proof_commands",
        "changed_files_covered",
        "issue_criteria_synced",
        "slice_roadmap_gates_synced"
    )

    if ([string]$ledger.pr_url -notmatch '^https://github\.com/[^/]+/[^/]+/pull/\d+(?:[?#].*)?$') {
        throw "verification ledger pr_url is not a GitHub PR URL"
    }
    $setupRepo = Get-RepoSlugFromIssueUrl -IssueUrl ([string]$SetupLedger.issue_url)
    $prRepo = Get-RepoSlugFromPullUrl -PullUrl ([string]$ledger.pr_url)
    if ([string]::IsNullOrWhiteSpace($setupRepo) -or [string]::IsNullOrWhiteSpace($prRepo) -or $prRepo -ne $setupRepo) {
        throw "verification ledger pr_url does not belong to the setup issue repository"
    }
    $commands = @($ledger.proof_commands)
    if ($commands.Count -eq 0) { throw "verification ledger proof_commands must be non-empty" }
    foreach ($command in $commands) {
        $missing = Test-RequiredFields -Object $command -Fields @("command", "exit_code", "output_receipt")
        if ($missing.Count -gt 0) { throw "verification command missing required fields: $($missing -join ', ')" }
        if ([int]$command.exit_code -ne 0) { throw "verification command failed: $($command.command)" }
        Assert-NonWeakString -Value ([string]$command.command) -Name "verification command"
        Assert-NonWeakString -Value ([string]$command.output_receipt) -Name "verification output_receipt"
        if ((-not (Test-Property -Object $command -Name "timestamp")) -and (-not (Test-Property -Object $command -Name "source_label"))) {
            throw "verification command requires timestamp or source_label"
        }
    }
    $covered = Get-StringArray $ledger.changed_files_covered
    if ($covered.Count -eq 0) { throw "verification ledger changed_files_covered must be non-empty" }
    foreach ($path in $covered) { [void](Assert-SafeRelativePath -Path $path -Name "changed_files_covered item") }
    if (Test-Property -Object $ledger -Name "verification_exemptions") {
        foreach ($path in (Get-StringArray $ledger.verification_exemptions)) {
            [void](Assert-SafeRelativePath -Path $path -Name "verification_exemptions item")
        }
    }
    if ($ledger.issue_criteria_synced -ne $true) { throw "verification ledger issue_criteria_synced must be true" }
    if ($ledger.slice_roadmap_gates_synced -ne $true) { throw "verification ledger slice_roadmap_gates_synced must be true" }
    $ledger
}

function Get-CompletionLedger {
    param(
        [string]$CompletionLedgerJson,
        [string]$CompletionLedgerPath,
        [Parameter(Mandatory = $true)]$SetupLedger
    )

    $ledger = Get-Ledger -LedgerJson $CompletionLedgerJson -LedgerPath $CompletionLedgerPath -Name "completion ledger" -RequiredFields @(
        "pr_url",
        "issue_url",
        "merge_confirmation",
        "linked_issue_closed_confirmation",
        "branch_cleanup_confirmation",
        "goal_board_deletion_confirmation",
        "cleanup_hook_result"
    )

    if ([string]$ledger.issue_url -ne [string]$SetupLedger.issue_url) {
        throw "completion ledger issue_url does not match setup ledger"
    }
    if ([string]$ledger.pr_url -notmatch '^https://github\.com/[^/]+/[^/]+/pull/\d+(?:[?#].*)?$') {
        throw "completion ledger pr_url is not a GitHub PR URL"
    }
    $setupRepo = Get-RepoSlugFromIssueUrl -IssueUrl ([string]$SetupLedger.issue_url)
    $prRepo = Get-RepoSlugFromPullUrl -PullUrl ([string]$ledger.pr_url)
    if ([string]::IsNullOrWhiteSpace($setupRepo) -or [string]::IsNullOrWhiteSpace($prRepo) -or $prRepo -ne $setupRepo) {
        throw "completion ledger pr_url does not belong to the setup issue repository"
    }
    foreach ($field in @("merge_confirmation", "linked_issue_closed_confirmation", "branch_cleanup_confirmation", "goal_board_deletion_confirmation", "cleanup_hook_result")) {
        if ($ledger.$field -is [string]) {
            throw "completion ledger $field must be structured, not a string"
        }
    }
    if ([string]$ledger.merge_confirmation.state -ne "MERGED" -or [string]::IsNullOrWhiteSpace([string]$ledger.merge_confirmation.merged_at)) {
        throw "completion ledger merge_confirmation must prove MERGED state and merged_at"
    }
    if ([string]$ledger.linked_issue_closed_confirmation.state -ne "CLOSED") {
        throw "completion ledger linked_issue_closed_confirmation must prove CLOSED issue state"
    }
    if ($ledger.branch_cleanup_confirmation.deleted_local -ne $true -or $ledger.branch_cleanup_confirmation.deleted_remote -ne $true -or $ledger.branch_cleanup_confirmation.only_goal_owned_removed -ne $true) {
        throw "completion ledger branch_cleanup_confirmation must prove only goal-owned branch cleanup"
    }
    $goalBranch = Normalize-RepoPath ([string]$SetupLedger.branch)
    if ((Normalize-RepoPath ([string]$ledger.branch_cleanup_confirmation.local_delete_target)) -ne $goalBranch) {
        throw "completion ledger branch_cleanup_confirmation local_delete_target must equal setup branch"
    }
    if ((Normalize-RepoPath ([string]$ledger.branch_cleanup_confirmation.remote_delete_target)) -ne $goalBranch) {
        throw "completion ledger branch_cleanup_confirmation remote_delete_target must equal setup branch"
    }
    if (Test-Property -Object $ledger.branch_cleanup_confirmation -Name "remote_deleted_branches") {
        $remoteDeletedBranches = Get-StringArray $ledger.branch_cleanup_confirmation.remote_deleted_branches
        if ($remoteDeletedBranches.Count -eq 0) {
            throw "completion ledger branch_cleanup_confirmation remote_deleted_branches must not be empty when present"
        }
        foreach ($branch in $remoteDeletedBranches) {
            if ((Normalize-RepoPath $branch) -ne $goalBranch) {
                throw "completion ledger branch_cleanup_confirmation includes non-goal remote deletion target"
            }
        }
    }
    if ($ledger.goal_board_deletion_confirmation.deleted -ne $true) {
        throw "completion ledger goal_board_deletion_confirmation must prove deletion"
    }
    if ([int]$ledger.cleanup_hook_result.exit_code -ne 0 -or [string]::IsNullOrWhiteSpace([string]$ledger.cleanup_hook_result.output)) {
        throw "completion ledger cleanup_hook_result must include exit_code 0 and output"
    }
    $ledger
}

function Get-GitStatusEntries {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $status = Invoke-Git -RepoRoot $RepoRoot -Arguments @("status", "--porcelain=v1", "-uall")
    if ($status.ExitCode -ne 0) {
        throw "git status failed: $($status.Stderr)"
    }
    if ([string]::IsNullOrWhiteSpace($status.Stdout)) { return @() }

    $entries = @()
    foreach ($line in ($status.Stdout -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $statusCode = $line.Substring(0, 2)
        $rawPath = $line.Substring(3)
        $paths = if ($rawPath -match " -> ") { $rawPath -split " -> " } else { @($rawPath) }
        foreach ($path in $paths) {
            $entries += [pscustomobject]@{
                Status = $statusCode
                Path = $path.Trim('"')
            }
        }
    }
    $entries
}

function Get-StagedEntries {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $diff = Invoke-Git -RepoRoot $RepoRoot -Arguments @("diff", "--cached", "--name-status")
    if ($diff.ExitCode -ne 0) {
        throw "git diff --cached failed: $($diff.Stderr)"
    }
    if ([string]::IsNullOrWhiteSpace($diff.Stdout)) { return @() }

    $entries = @()
    foreach ($line in ($diff.Stdout -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }
        $entries += [pscustomobject]@{
            Status = $parts[0]
            Path = $parts[-1]
        }
    }
    $entries
}

function Test-HasCheckbox {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return [bool]($Text -match "(?m)^\s*[-*]\s+\[[ xX]\]")
}

function Test-UncheckedCheckbox {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return [bool]($Text -match "(?m)^\s*[-*]\s+\[\s\]")
}

function Get-RepoSlugFromIssueUrl {
    param([Parameter(Mandatory = $true)][string]$IssueUrl)
    if ($IssueUrl -match '^https://github\.com/(?<repo>[^/]+/[^/]+)/issues/\d+(?:[?#].*)?$') {
        return $Matches.repo
    }
    return $null
}

function Get-RepoSlugFromPullUrl {
    param([Parameter(Mandatory = $true)][string]$PullUrl)
    if ($PullUrl -match '^https://github\.com/(?<repo>[^/]+/[^/]+)/pull/\d+(?:[?#].*)?$') {
        return $Matches.repo
    }
    return $null
}

function Get-PullNumberFromUrl {
    param([Parameter(Mandatory = $true)][string]$PullUrl)
    if ($PullUrl -match '^https://github\.com/[^/]+/[^/]+/pull/(?<number>\d+)(?:[?#].*)?$') {
        return [int]$Matches.number
    }
    return $null
}

function Get-IssueNumberFromUrl {
    param([string]$IssueUrl)
    if ($IssueUrl -match "/issues/(?<number>\d+)(?:$|[?#])") {
        return [int]$Matches.number
    }
    return $null
}

function Get-BranchDefault {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $originHead = Invoke-Git -RepoRoot $RepoRoot -Arguments @("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if ($originHead.ExitCode -eq 0 -and (-not [string]::IsNullOrWhiteSpace($originHead.Stdout))) {
        return ($originHead.Stdout -replace "^origin/", "")
    }

    $remoteShow = Invoke-Git -RepoRoot $RepoRoot -Arguments @("remote", "show", "origin")
    if ($remoteShow.ExitCode -eq 0 -and $remoteShow.Stdout -match "HEAD branch:\s*(?<branch>\S+)") {
        return $Matches.branch
    }

    return $null
}

function Get-BranchInventory {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $local = Invoke-Git -RepoRoot $RepoRoot -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/heads")
    if ($local.ExitCode -ne 0) { throw "could not list local branches: $($local.Stderr)" }
    $remote = Invoke-Git -RepoRoot $RepoRoot -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin")
    if ($remote.ExitCode -ne 0) { throw "could not list remote branches: $($remote.Stderr)" }

    [pscustomobject]@{
        local = @($local.Stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
        remote = @($remote.Stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "origin/HEAD" -and $_ -ne "origin" } | ForEach-Object { $_ -replace "^origin/", "" } | Sort-Object)
    }
}

function Compare-StringSet {
    param(
        [string[]]$Expected,
        [string[]]$Actual
    )
    $expectedSet = @($Expected | Sort-Object -Unique)
    $actualSet = @($Actual | Sort-Object -Unique)
    [pscustomobject]@{
        missing = @($expectedSet | Where-Object { $actualSet -notcontains $_ })
        added = @($actualSet | Where-Object { $expectedSet -notcontains $_ })
    }
}

function Get-TrackedGoalPaths {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $result = Invoke-Git -RepoRoot $RepoRoot -Arguments @("ls-files", "--", "docs/goals", ".goalbuddy-board")
    if ($result.ExitCode -ne 0) {
        throw "git ls-files for GoalBuddy paths failed: $($result.Stderr)"
    }
    if ([string]::IsNullOrWhiteSpace($result.Stdout)) { return @() }
    @($result.Stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-ClosingKeywordForIssue {
    param(
        [string]$Body,
        [int]$IssueNumber,
        [string]$RemoteSlug
    )
    if ([string]::IsNullOrWhiteSpace($Body) -or $IssueNumber -le 0) { return $false }
    $issueRef = "#$IssueNumber"
    $fullRef = if ([string]::IsNullOrWhiteSpace($RemoteSlug)) { $null } else { "$RemoteSlug#$IssueNumber" }
    $refs = @([regex]::Escape($issueRef))
    if ($fullRef) { $refs += [regex]::Escape($fullRef) }
    $joinedRefs = $refs -join "|"
    return [bool]($Body -match "(?im)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+($joinedRefs)(?!\d)\b")
}

function Test-ClosingReferenceIncludesIssue {
    param(
        $References,
        [int]$IssueNumber
    )
    foreach ($reference in @($References)) {
        if ($null -eq $reference) { continue }
        if ([int]$reference.number -eq $IssueNumber) { return $true }
    }
    return $false
}

function Get-GithubRepoContext {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [switch]$SkipGhAuth
    )

    if ($SkipGhAuth.IsPresent) { Assert-TestModeSwitch -Name "-SkipGhAuth" }

    $root = Get-CanonicalRepoRoot -RepoRoot $RepoRoot
    $origin = Invoke-Git -RepoRoot $root -Arguments @("remote", "get-url", "origin")
    if ($origin.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($origin.Stdout)) {
        throw "missing GitHub origin remote"
    }
    $remoteSlug = Get-OriginRemoteSlug -RemoteUrl $origin.Stdout
    if ([string]::IsNullOrWhiteSpace($remoteSlug)) {
        throw "origin remote is not a GitHub repository"
    }

    if (-not $SkipGhAuth) {
        $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
        if ($null -eq $ghCommand) { throw "gh CLI is not installed or not on PATH" }
        $ghAuth = Invoke-Gh -Arguments @("auth", "status") -WorkingDirectory $root
        if ($ghAuth.ExitCode -ne 0) { throw "gh CLI is not authenticated" }
    }

    $agentFiles = @("AGENTS.md", "CLAUDE.md") | ForEach-Object { Join-Path $root $_ }
    $agentFile = $agentFiles | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($agentFile)) {
        throw "missing AGENTS.md or CLAUDE.md with Matt Pocock setup"
    }
    $agentText = Get-Content -LiteralPath $agentFile -Raw
    if ($agentText -notmatch "(?m)^## Agent skills\s*$") {
        throw "AGENTS.md or CLAUDE.md lacks ## Agent skills setup marker"
    }

    $docsAgents = Join-Path $root "docs\agents"
    $issueTrackerPath = Join-Path $docsAgents "issue-tracker.md"
    $triagePath = Join-Path $docsAgents "triage-labels.md"
    $domainPath = Join-Path $docsAgents "domain.md"
    foreach ($requiredPath in @($issueTrackerPath, $triagePath, $domainPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Matt Pocock setup marker missing: $([IO.Path]::GetFileName($requiredPath))"
        }
    }

    $issueTrackerText = Get-Content -LiteralPath $issueTrackerPath -Raw
    $githubIssuesMatch = $issueTrackerText -match "(?i)\bGitHub\s+Issues\b"
    $currentOriginMatch = $issueTrackerText -match "(?i)\b(current|active)\s+(git\s+)?origin\b" -or $issueTrackerText -match "(?i)\bgit\s+remote\s+origin\b"
    $explicitRemoteMatch = $issueTrackerText -match [regex]::Escape($remoteSlug)
    if (-not ($githubIssuesMatch -and ($currentOriginMatch -or $explicitRemoteMatch))) {
        throw "docs/agents/issue-tracker.md does not clearly identify GitHub Issues for the active origin remote"
    }

    [pscustomobject]@{
        repo_root = $root
        origin = $origin.Stdout
        remote_slug = $remoteSlug
        agent_file = $agentFile
        issue_tracker = $issueTrackerPath
        gh_auth_checked = -not $SkipGhAuth.IsPresent
        matt_pocock_setup = "github"
    }
}
