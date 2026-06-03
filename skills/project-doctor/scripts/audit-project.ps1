[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [ValidateSet("LocalDocs", "GitHubAware")][string]$Mode = "LocalDocs",
    [string]$IssueFixturePath,
    [string]$MilestoneFixturePath,
    [string]$LabelFixturePath
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "RepoRoot is required" }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "RepoRoot does not exist: $Path" }
    (Resolve-Path -LiteralPath $Path).Path
}

function Get-RepoFile {
    param([string]$Root, [string]$RelativePath)
    Join-Path $Root $RelativePath
}

function ConvertTo-RepoPath {
    param([string]$Root, [string]$Path)
    ([IO.Path]::GetRelativePath($Root, $Path) -replace '\\', '/')
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    $null
}

function Get-IssueNumber {
    param([string]$IssueUrl, [string]$Path)
    if ($IssueUrl -match '/issues/(?<n>\d+)(?:$|[?#])') { return [int]$Matches.n }
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ($name -match '^(?<n>\d+)-') { return [int]$Matches.n }
    $null
}

function Get-StringArray {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    @($Value | ForEach-Object { [string]$_ })
}

function Read-JsonArray {
    param([string]$Path, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name fixture does not exist: $Path" }
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($null -eq $value) { return @() }
    @($value)
}

function New-Finding {
    param(
        [string]$Id,
        [string]$Severity,
        [string]$Dimension,
        [string]$Message,
        [string]$Artifact = "",
        [hashtable]$Evidence = @{}
    )
    [ordered]@{
        id = $Id
        severity = $Severity
        dimension = $Dimension
        message = $Message
        artifact = $Artifact
        evidence = $Evidence
    }
}

function Add-Finding {
    param(
        [hashtable]$Findings,
        [ValidateSet("blocking", "repairable", "informational", "healthy")][string]$Category,
        [object]$Finding
    )
    $Findings[$Category].Add($Finding) | Out-Null
}

function Test-TextContainsAll {
    param([string]$Text, [string[]]$Needles)
    foreach ($needle in $Needles) {
        if (-not $Text.Contains($needle)) { return $false }
    }
    $true
}

function Get-IssueMirrors {
    param([string]$Root)
    $issueRoot = Get-RepoFile -Root $Root -RelativePath "docs/superpowers/issues"
    if (-not (Test-Path -LiteralPath $issueRoot -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $issueRoot -Filter "*.md" -File |
        Where-Object { $_.Name -ne "README.md" } |
        ForEach-Object {
            $text = Get-Content -LiteralPath $_.FullName -Raw
            $labelText = Get-FieldValue -Text $text -Name "Labels"
            $labels = @()
            if (-not [string]::IsNullOrWhiteSpace($labelText)) {
                $labels = @($labelText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
            $issueUrl = Get-FieldValue -Text $text -Name "GitHub Issue"
            [pscustomobject]@{
                path = ConvertTo-RepoPath -Root $Root -Path $_.FullName
                full_name = $_.FullName
                text = $text
                title = ($text -split "`r?`n" | Select-Object -First 1) -replace '^#\s+', ''
                issue_url = $issueUrl
                number = Get-IssueNumber -IssueUrl $issueUrl -Path $_.Name
                milestone = Get-FieldValue -Text $text -Name "GitHub Milestone"
                labels = $labels
                mirror_retention = Get-FieldValue -Text $text -Name "Mirror Retention"
            }
        })
}

function Get-MilestonePages {
    param([string]$Root)
    $milestoneRoot = Get-RepoFile -Root $Root -RelativePath "docs/superpowers/milestones"
    if (-not (Test-Path -LiteralPath $milestoneRoot -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $milestoneRoot -Filter "*.md" -File |
        Where-Object { $_.Name -ne "README.md" } |
        ForEach-Object {
            $text = Get-Content -LiteralPath $_.FullName -Raw
            $title = Get-FieldValue -Text $text -Name "Title"
            if ([string]::IsNullOrWhiteSpace($title)) {
                $title = (($text -split "`r?`n" | Select-Object -First 1) -replace '^#\s+', '').Trim()
            }
            $issueNumbers = @([regex]::Matches($text, 'docs/superpowers/issues/(?<n>\d+)-[^`\)\s]+\.md') | ForEach-Object { [int]$_.Groups["n"].Value } | Sort-Object -Unique)
            [pscustomobject]@{
                path = ConvertTo-RepoPath -Root $Root -Path $_.FullName
                title = $title
                issue_numbers = $issueNumbers
                text = $text
            }
        })
}

function Get-LabelVocabulary {
    param([string]$Root)
    $path = Get-RepoFile -Root $Root -RelativePath "docs/agents/triage-labels.md"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $text = Get-Content -LiteralPath $path -Raw
    @([regex]::Matches($text, '`(?<label>(type|status):[^`]+)`') | ForEach-Object { $_.Groups["label"].Value } | Sort-Object -Unique)
}

function Test-GitIgnored {
    param([string]$Root, [string]$RelativePath)
    $output = & git -C $Root check-ignore --quiet -- $RelativePath 2>$null
    $exit = $LASTEXITCODE
    $null = $output
    $exit -eq 0
}

function Compare-LiveFile {
    param([string]$SourcePath, [string]$TargetPath)
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return [pscustomobject]@{ checked = $false; equal = $false; reason = "target file not inspected"; target = $TargetPath }
    }
    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $TargetPath -Algorithm SHA256).Hash
    [pscustomobject]@{ checked = $true; equal = ($sourceHash -eq $targetHash); source_hash = $sourceHash; target_hash = $targetHash; target = $TargetPath }
}

function Get-RepoSlug {
    param([string]$Root)
    $roadmapPath = Get-RepoFile -Root $Root -RelativePath "docs/agents/project-roadmap.json"
    if (Test-Path -LiteralPath $roadmapPath -PathType Leaf) {
        $roadmap = Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace([string]$roadmap.repository)) { return [string]$roadmap.repository }
    }
    $null
}

function Read-GitHubIssues {
    param([string]$Root, [string]$FixturePath)
    $fixture = @(Read-JsonArray -Path $FixturePath -Name "issue")
    if ($fixture.Count -gt 0) {
        if ($fixture.Count -eq 1 -and $fixture[0].PSObject.Properties.Name -contains "issues") {
            return @($fixture[0].issues)
        }
        return $fixture
    }
    $repo = Get-RepoSlug -Root $Root
    if ([string]::IsNullOrWhiteSpace($repo)) { return @() }
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $gh) { return @() }
    $raw = & gh issue list --repo $repo --state all --limit 200 --json number,title,state,body,url,labels,milestone 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($raw | Out-String))) { return @() }
    @($raw | ConvertFrom-Json)
}

function Invoke-LocalDocsAudit {
    param([string]$Root, [hashtable]$Findings)
    $required = @(
        "docs/superpowers/PROJECT_CONTEXT.md",
        "docs/superpowers/milestones",
        "docs/superpowers/specs",
        "docs/superpowers/plans",
        "docs/superpowers/issues",
        "docs/agents/triage-labels.md",
        "scripts/sync-live.ps1"
    )
    foreach ($relative in $required) {
        $path = Get-RepoFile -Root $Root -RelativePath $relative
        if (Test-Path -LiteralPath $path) {
            Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "local-docs-required-path" -Severity "healthy" -Dimension "project-docs" -Message "Required project artifact is present." -Artifact $relative)
        } else {
            Add-Finding -Findings $Findings -Category blocking -Finding (New-Finding -Id "local-docs-required-path" -Severity "blocking" -Dimension "project-docs" -Message "Required project artifact is missing." -Artifact $relative)
        }
    }

    $skillPath = Get-RepoFile -Root $Root -RelativePath "skills/project-doctor/SKILL.md"
    $skillText = if (Test-Path -LiteralPath $skillPath -PathType Leaf) { Get-Content -LiteralPath $skillPath -Raw } else { "" }
    if (-not [string]::IsNullOrWhiteSpace($skillText) -and (Test-TextContainsAll -Text $skillText -Needles @("## Native Continuation Gate", "request_user_input", "project_doctor_next_step", "Review First", "Stop"))) {
        Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "native-ui-closeout" -Severity "healthy" -Dimension "native-ui-contracts" -Message "Doctor native closeout wording is present." -Artifact "skills/project-doctor/SKILL.md")
    } else {
        Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "native-ui-closeout" -Severity "repairable" -Dimension "native-ui-contracts" -Message "Doctor native closeout wording needs repair." -Artifact "skills/project-doctor/SKILL.md")
    }

    foreach ($relative in @("AGENTS.md", "docs/agents/triage-labels.md", "docs/superpowers/PROJECT_CONTEXT.md", "docs/superpowers/issues/README.md", "skills/project-doctor/SKILL.md")) {
        if (Test-GitIgnored -Root $Root -RelativePath $relative) {
            Add-Finding -Findings $Findings -Category blocking -Finding (New-Finding -Id "ignored-path-traps" -Severity "blocking" -Dimension "ignored-files" -Message "Source-of-truth path is ignored by Git." -Artifact $relative)
        } else {
            Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "ignored-path-traps" -Severity "healthy" -Dimension "ignored-files" -Message "Source-of-truth path is not ignored by Git." -Artifact $relative)
        }
    }

    $readmePath = Get-RepoFile -Root $Root -RelativePath "docs/superpowers/issues/README.md"
    $readmeText = if (Test-Path -LiteralPath $readmePath -PathType Leaf) { Get-Content -LiteralPath $readmePath -Raw } else { "" }
    if ($readmeText.Contains("closed mirror") -or $readmeText.Contains("Mirror Retention")) {
        Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "closed-mirror-lifecycle" -Severity "healthy" -Dimension "closed-mirror-lifecycle" -Message "Closed mirror lifecycle policy is documented." -Artifact "docs/superpowers/issues/README.md")
    } else {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "closed-mirror-lifecycle" -Severity "informational" -Dimension "closed-mirror-lifecycle" -Message "LocalDocs mode cannot verify closed GitHub state; lifecycle policy wording should be checked with GitHub evidence." -Artifact "docs/superpowers/issues/README.md")
    }

    $sourceSkill = Get-RepoFile -Root $Root -RelativePath "skills/project-doctor/SKILL.md"
    if (Test-Path -LiteralPath $sourceSkill -PathType Leaf) {
        $liveTargets = @(
            Join-Path $env:USERPROFILE "plugins/superpowers-project/skills/project-doctor/SKILL.md"
            Join-Path $env:USERPROFILE ".agents/skills/project-doctor/SKILL.md"
        )
        $liveChecks = @($liveTargets | ForEach-Object { Compare-LiveFile -SourcePath $sourceSkill -TargetPath $_ })
        $checked = @($liveChecks | Where-Object { $_.checked })
        $drifted = @($checked | Where-Object { -not $_.equal })
        if ($drifted.Count -gt 0) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "live-sync" -Severity "repairable" -Dimension "live-sync" -Message "Live deployed Doctor skill differs from source." -Artifact "skills/project-doctor/SKILL.md" -Evidence @{ targets = @($drifted.target) })
        } elseif ($checked.Count -gt 0) {
            Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "live-sync" -Severity "healthy" -Dimension "live-sync" -Message "Checked live Doctor skill target matches source." -Artifact "skills/project-doctor/SKILL.md" -Evidence @{ targets = @($checked.target) })
        } else {
            Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "live-sync" -Severity "informational" -Dimension "live-sync" -Message "Live deployed Doctor skill target was not inspected." -Artifact "skills/project-doctor/SKILL.md" -Evidence @{ targets = $liveTargets })
        }
        $retiredLiveRoot = Join-Path $env:USERPROFILE "plugins/milestones"
        if (Test-Path -LiteralPath $retiredLiveRoot -PathType Container) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "retired-live-plugin-root" -Severity "repairable" -Dimension "live-sync" -Message "Retired Milestones live plugin root still exists; sync-live should remove the owned retired copy." -Artifact $retiredLiveRoot)
        }
    } else {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "live-sync" -Severity "informational" -Dimension "live-sync" -Message "Live sync comparison skipped because the source Doctor skill file is absent." -Artifact "skills/project-doctor/SKILL.md")
    }
}

function Invoke-GitHubAwareAudit {
    param(
        [string]$Root,
        [hashtable]$Findings,
        [object[]]$Mirrors,
        [object[]]$MilestonePages,
        [string[]]$LabelVocabulary
    )
    $githubIssues = @(Read-GitHubIssues -Root $Root -FixturePath $IssueFixturePath)
    $githubMilestones = @(Read-JsonArray -Path $MilestoneFixturePath -Name "milestone")
    $githubLabels = @(Read-JsonArray -Path $LabelFixturePath -Name "label")
    $issuesByNumber = @{}
    foreach ($issue in $githubIssues) {
        if ($null -ne $issue.number) { $issuesByNumber[[int]$issue.number] = $issue }
    }

    foreach ($mirror in $Mirrors) {
        if ($null -eq $mirror.number -or -not $issuesByNumber.ContainsKey([int]$mirror.number)) {
            Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "mirror-github-drift" -Severity "informational" -Dimension "mirror-versus-github" -Message "No GitHub issue evidence was inspected for this mirror." -Artifact $mirror.path)
            continue
        }
        $issue = $issuesByNumber[[int]$mirror.number]
        $issueLabels = @(Get-StringArray (@($issue.labels | ForEach-Object { if ($_.PSObject.Properties.Name -contains "name") { $_.name } else { $_ } })))
        $mirrorLabels = @(Get-StringArray $mirror.labels)
        $drift = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace([string]$issue.title) -and [string]$issue.title -ne [string]$mirror.title) { $drift.Add("title") | Out-Null }
        if (-not [string]::IsNullOrWhiteSpace([string]$issue.body) -and -not $mirror.text.Contains([string]$issue.body)) { $drift.Add("body") | Out-Null }
        $issueMilestoneTitle = ""
        if ($null -ne $issue.milestone -and $issue.milestone.PSObject.Properties.Name -contains "title") { $issueMilestoneTitle = [string]$issue.milestone.title }
        if (-not [string]::IsNullOrWhiteSpace($issueMilestoneTitle) -and $issueMilestoneTitle -ne [string]$mirror.milestone) { $drift.Add("milestone") | Out-Null }
        $missingLabels = @($mirrorLabels | Where-Object { $issueLabels -notcontains $_ })
        $extraLabels = @($issueLabels | Where-Object { $mirrorLabels -notcontains $_ -and $_ -match '^(type|status):' })
        if ($missingLabels.Count -gt 0 -or $extraLabels.Count -gt 0) { $drift.Add("labels") | Out-Null }

        if ($drift.Count -gt 0) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "mirror-github-drift" -Severity "repairable" -Dimension "mirror-versus-github" -Message "Issue mirror differs from inspected GitHub issue evidence." -Artifact $mirror.path -Evidence @{ fields = @($drift); github_issue = $issue.url })
        } else {
            Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "mirror-github-drift" -Severity "healthy" -Dimension "mirror-versus-github" -Message "Issue mirror matches inspected GitHub issue fields." -Artifact $mirror.path -Evidence @{ github_issue = $issue.url })
        }

        if ([string]$issue.state -eq "CLOSED" -and [string]$mirror.mirror_retention -ne "retain") {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "closed-mirror-lifecycle" -Severity "repairable" -Dimension "closed-mirror-lifecycle" -Message "stale closed issue mirror still exists without retention evidence." -Artifact $mirror.path -Evidence @{ github_issue = $issue.url })
        }
    }

    if (@($Findings.repairable | Where-Object { $_.id -eq "closed-mirror-lifecycle" }).Count -eq 0) {
        Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "closed-mirror-lifecycle" -Severity "healthy" -Dimension "closed-mirror-lifecycle" -Message "No stale closed mirror was found in inspected GitHub issue evidence.")
    }

    if ($githubMilestones.Count -gt 0) {
        foreach ($milestone in $githubMilestones) {
            $title = [string]$milestone.title
            $page = @($MilestonePages | Where-Object { $_.title -eq $title } | Select-Object -First 1)
            if ($page.Count -eq 0) {
                Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "milestone-membership-drift" -Severity "repairable" -Dimension "milestone-membership" -Message "GitHub milestone has no local milestone page." -Artifact $title)
                continue
            }
            $localIssues = @(Get-StringArray $page[0].issue_numbers | ForEach-Object { [int]$_ })
            $githubIssueNumbers = @(Get-StringArray $milestone.issues | ForEach-Object { [int]$_ })
            $missingLocal = @($githubIssueNumbers | Where-Object { $localIssues -notcontains $_ })
            $extraLocal = @($localIssues | Where-Object { $githubIssueNumbers -notcontains $_ })
            if ($missingLocal.Count -gt 0 -or $extraLocal.Count -gt 0) {
                Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "milestone-membership-drift" -Severity "repairable" -Dimension "milestone-membership" -Message "Local milestone page membership differs from inspected GitHub milestone evidence." -Artifact $page[0].path -Evidence @{ missing_local = $missingLocal; extra_local = $extraLocal })
            } else {
                Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "milestone-membership-drift" -Severity "healthy" -Dimension "milestone-membership" -Message "Local milestone membership matches inspected GitHub evidence." -Artifact $page[0].path)
            }
        }
    } else {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "milestone-membership-drift" -Severity "informational" -Dimension "milestone-membership" -Message "GitHub milestone evidence was not inspected.")
    }

    if ($githubLabels.Count -gt 0) {
        $githubLabelNames = @(Get-StringArray (@($githubLabels | ForEach-Object { if ($_.PSObject.Properties.Name -contains "name") { $_.name } else { $_ } })))
        $unknown = @($githubLabelNames | Where-Object { $_ -match '^(type|status):' -and $LabelVocabulary -notcontains $_ })
        $missing = @($LabelVocabulary | Where-Object { $githubLabelNames -notcontains $_ })
        if ($unknown.Count -gt 0 -or $missing.Count -gt 0) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "label-drift" -Severity "repairable" -Dimension "label-vocabulary" -Message "GitHub labels differ from local label vocabulary." -Artifact "docs/agents/triage-labels.md" -Evidence @{ unknown_github_labels = $unknown; missing_github_labels = $missing })
        } else {
            Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "label-drift" -Severity "healthy" -Dimension "label-vocabulary" -Message "GitHub labels match local label vocabulary." -Artifact "docs/agents/triage-labels.md")
        }
    } else {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "label-drift" -Severity "informational" -Dimension "label-vocabulary" -Message "GitHub label evidence was not inspected." -Artifact "docs/agents/triage-labels.md")
    }
}

$root = Resolve-RepoRoot -Path $RepoRoot
$findings = @{
    blocking = [System.Collections.Generic.List[object]]::new()
    repairable = [System.Collections.Generic.List[object]]::new()
    informational = [System.Collections.Generic.List[object]]::new()
    healthy = [System.Collections.Generic.List[object]]::new()
}

$mirrors = @(Get-IssueMirrors -Root $root)
$milestonePages = @(Get-MilestonePages -Root $root)
$labelVocabulary = @(Get-LabelVocabulary -Root $root)

Invoke-LocalDocsAudit -Root $root -Findings $findings
if ($Mode -eq "GitHubAware") {
    Invoke-GitHubAwareAudit -Root $root -Findings $findings -Mirrors $mirrors -MilestonePages $milestonePages -LabelVocabulary $labelVocabulary
} else {
    Add-Finding -Findings $findings -Category informational -Finding (New-Finding -Id "mirror-github-drift" -Severity "informational" -Dimension "mirror-versus-github" -Message "GitHub issue field comparison was not inspected in LocalDocs mode.")
    Add-Finding -Findings $findings -Category informational -Finding (New-Finding -Id "milestone-membership-drift" -Severity "informational" -Dimension "milestone-membership" -Message "GitHub milestone membership was not inspected in LocalDocs mode.")
    Add-Finding -Findings $findings -Category informational -Finding (New-Finding -Id "label-drift" -Severity "informational" -Dimension "label-vocabulary" -Message "GitHub label state was not inspected in LocalDocs mode.")
}

[ordered]@{
    ok = $true
    phase = "project-doctor-audit"
    mode = $Mode
    repo_root = $root
    target_repo = Get-RepoSlug -Root $root
    mutation_allowed = $false
    repair_policy = [ordered]@{
        report_first = $true
        native_repair_approval = "request_user_input"
        allowed_after_approval = @("project docs", "issue mirrors", "labels", "milestone metadata", "wrappers", "live sync cleanup owned by this plugin")
        blocked_mutations = @("product code", "implementation tests", "runtime config", "branches", "PR merges", "issue close state", "native goals")
    }
    checked_artifacts = [ordered]@{
        issue_mirrors = @($mirrors.path)
        milestone_pages = @($milestonePages.path)
        label_vocabulary = "docs/agents/triage-labels.md"
    }
    findings = [ordered]@{
        blocking = @($findings.blocking)
        repairable = @($findings.repairable)
        informational = @($findings.informational)
        healthy = @($findings.healthy)
    }
} | ConvertTo-Json -Depth 32
