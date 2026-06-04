[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [ValidateSet("LocalDocs", "GitHubAware")][string]$Mode = "LocalDocs",
    [string]$IssueFixturePath,
    [string]$MilestoneFixturePath,
    [string]$LabelFixturePath,
    [string]$ProjectFixturePath,
    [switch]$TrackerHygiene,
    [switch]$ApplyTrackerRepairs
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
                project_status = Get-FieldValue -Text $text -Name "Project Status"
                project_priority = Get-FieldValue -Text $text -Name "Project Priority"
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

function Read-ProjectFixture {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "project fixture does not exist: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ProjectItems {
    param($Project)
    if ($null -eq $Project -or $Project.PSObject.Properties.Name -notcontains "items") { return @() }
    @($Project.items)
}

function Get-ProjectItemFieldValue {
    param($Item, [string]$Name)
    if ($null -eq $Item -or $null -eq $Item.fields) { return "" }
    if ($Item.fields -is [hashtable] -and $Item.fields.ContainsKey($Name)) { return [string]$Item.fields[$Name] }
    if ($Item.fields.PSObject.Properties.Name -contains $Name) { return [string]$Item.fields.$Name }
    ""
}

function Get-MirrorProjectFieldMap {
    param($Mirror)
    $fields = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace([string]$Mirror.project_priority)) {
        $fields["Priority"] = [string]$Mirror.project_priority
    }
    $fields
}

function Find-ProjectItemForIssue {
    param([object[]]$Items, [int]$IssueNumber)
    @($Items | Where-Object {
        [string]$_.type -eq "Issue" -and $null -ne $_.issue_number -and [int]$_.issue_number -eq $IssueNumber
    } | Select-Object -First 1)
}

function Add-RepairReceiptEntry {
    param(
        [System.Collections.Generic.List[object]]$Receipt,
        [string]$Action,
        [string]$ObjectType,
        [string]$ObjectId,
        [string]$Field = "",
        [string]$From = "",
        [string]$To = "",
        [hashtable]$Evidence = @{}
    )
    $Receipt.Add([ordered]@{
        action = $Action
        object_type = $ObjectType
        object_id = $ObjectId
        field = $Field
        from = $From
        to = $To
        evidence = $Evidence
    }) | Out-Null
}

function Invoke-TrackerHygieneAudit {
    param(
        [hashtable]$Findings,
        [object[]]$Mirrors,
        [object[]]$GitHubIssues,
        $ProjectFixture,
        [bool]$ApplyRepairs,
        [System.Collections.Generic.List[object]]$RepairReceipt
    )

    $issuesByNumber = @{}
    foreach ($issue in $GitHubIssues) {
        if ($null -ne $issue.number) { $issuesByNumber[[int]$issue.number] = $issue }
    }

    $projectItems = @(Get-ProjectItems -Project $ProjectFixture)
    foreach ($item in @($projectItems | Where-Object { [string]$_.type -eq "DraftIssue" })) {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "project-draft-item" -Severity "informational" -Dimension "tracker-hygiene" -Message "Project V2 draft item remains unpublished and must be handled manually." -Artifact ([string]$item.id) -Evidence @{ title = [string]$item.title; status = [string]$item.status })
    }

    foreach ($mirror in $Mirrors) {
        if ($null -eq $mirror.number -or -not $issuesByNumber.ContainsKey([int]$mirror.number)) { continue }
        $issue = $issuesByNumber[[int]$mirror.number]
        $issueLabels = @(Get-StringArray (@($issue.labels | ForEach-Object { if ($_.PSObject.Properties.Name -contains "name") { $_.name } else { $_ } })))
        $statusLabels = @($issueLabels | Where-Object { $_ -match '^status:' })
        $issueObjectId = if (-not [string]::IsNullOrWhiteSpace([string]$issue.node_id)) { [string]$issue.node_id } else { "issue:$($issue.number)" }
        $item = @(Find-ProjectItemForIssue -Items $projectItems -IssueNumber ([int]$mirror.number) | Select-Object -First 1)
        $hasProjectItem = $item.Count -gt 0

        if ([string]$issue.state -eq "CLOSED") {
            if ($statusLabels.Count -gt 0) {
                Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "closed-status-label-drift" -Severity "repairable" -Dimension "tracker-hygiene" -Message "Closed GitHub issue still has status routing labels." -Artifact $mirror.path -Evidence @{ github_issue = $issue.url; labels = $statusLabels })
                if ($ApplyRepairs) {
                    foreach ($label in $statusLabels) {
                        Add-RepairReceiptEntry -Receipt $RepairReceipt -Action "remove-label" -ObjectType "github-issue" -ObjectId $issueObjectId -Field "labels" -From $label -To "" -Evidence @{ issue_number = [int]$issue.number; url = [string]$issue.url }
                    }
                }
            }
            if ($hasProjectItem -and [string]$item[0].status -ne "Done") {
                Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "closed-project-not-done" -Severity "repairable" -Dimension "tracker-hygiene" -Message "Closed GitHub issue Project item is not Done." -Artifact ([string]$item[0].id) -Evidence @{ issue_number = [int]$issue.number; from = [string]$item[0].status; to = "Done" })
                if ($ApplyRepairs) {
                    Add-RepairReceiptEntry -Receipt $RepairReceipt -Action "set-project-status" -ObjectType "project-item" -ObjectId ([string]$item[0].id) -Field "Status" -From ([string]$item[0].status) -To "Done" -Evidence @{ issue_number = [int]$issue.number; content_id = $issueObjectId }
                }
            }
            continue
        }

        if ($statusLabels.Count -eq 0) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "missing-routing-label" -Severity "repairable" -Dimension "tracker-hygiene" -Message "Open GitHub issue has no status routing label." -Artifact $mirror.path -Evidence @{ github_issue = $issue.url })
        }

        if (-not $hasProjectItem) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "missing-project-item" -Severity "repairable" -Dimension "tracker-hygiene" -Message "Mirrored open issue is missing from the canonical Project V2 board." -Artifact $mirror.path -Evidence @{ github_issue = $issue.url; content_id = $issueObjectId })
            if ($ApplyRepairs) {
                Add-RepairReceiptEntry -Receipt $RepairReceipt -Action "add-project-item" -ObjectType "project" -ObjectId ([string]$ProjectFixture.project.id) -Field "items" -From "" -To $issueObjectId -Evidence @{ issue_number = [int]$issue.number; url = [string]$issue.url }
            }
            continue
        }

        if ([string]$item[0].status -eq "Done") {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "open-project-done-mismatch" -Severity "repairable" -Dimension "tracker-hygiene" -Message "Open GitHub issue Project item is marked Done." -Artifact ([string]$item[0].id) -Evidence @{ issue_number = [int]$issue.number; status = [string]$item[0].status })
            if ($ApplyRepairs -and -not [string]::IsNullOrWhiteSpace([string]$mirror.project_status)) {
                Add-RepairReceiptEntry -Receipt $RepairReceipt -Action "set-project-status" -ObjectType "project-item" -ObjectId ([string]$item[0].id) -Field "Status" -From ([string]$item[0].status) -To ([string]$mirror.project_status) -Evidence @{ issue_number = [int]$issue.number; content_id = $issueObjectId }
            }
        }

        $mirrorProjectFields = Get-MirrorProjectFieldMap -Mirror $mirror
        foreach ($fieldName in $mirrorProjectFields.Keys) {
            $expected = [string]$mirrorProjectFields[$fieldName]
            $actual = Get-ProjectItemFieldValue -Item $item[0] -Name $fieldName
            if ($actual -ne $expected) {
                Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "project-field-drift" -Severity "repairable" -Dimension "tracker-hygiene" -Message "Project V2 item field differs from mirror metadata." -Artifact ([string]$item[0].id) -Evidence @{ issue_number = [int]$issue.number; field = $fieldName; from = $actual; to = $expected })
                if ($ApplyRepairs) {
                    Add-RepairReceiptEntry -Receipt $RepairReceipt -Action "set-project-field" -ObjectType "project-item" -ObjectId ([string]$item[0].id) -Field $fieldName -From $actual -To $expected -Evidence @{ issue_number = [int]$issue.number; field_id = "FIELD_$($fieldName.ToUpperInvariant())" }
                }
            }
        }
    }
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

    $skillPath = Get-RepoFile -Root $Root -RelativePath "skills/audit-project/SKILL.md"
    $ownsDoctorSource = Test-Path -LiteralPath $skillPath -PathType Leaf
    $skillText = if ($ownsDoctorSource) { Get-Content -LiteralPath $skillPath -Raw } else { "" }
    if (-not $ownsDoctorSource) {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "native-ui-closeout" -Severity "informational" -Dimension "native-ui-contracts" -Message "Doctor native closeout wording check skipped because this repo does not own the Doctor source skill." -Artifact "skills/audit-project/SKILL.md")
    } elseif (Test-TextContainsAll -Text $skillText -Needles @("## Native Continuation Gate", "request_user_input", "project_doctor_next_step", "Review First", "Stop")) {
        Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "native-ui-closeout" -Severity "healthy" -Dimension "native-ui-contracts" -Message "Doctor native closeout wording is present." -Artifact "skills/audit-project/SKILL.md")
    } else {
        Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "native-ui-closeout" -Severity "repairable" -Dimension "native-ui-contracts" -Message "Doctor native closeout wording needs repair." -Artifact "skills/audit-project/SKILL.md")
    }

    foreach ($relative in @("AGENTS.md", "docs/agents/triage-labels.md", "docs/superpowers/PROJECT_CONTEXT.md", "docs/superpowers/issues/README.md", "skills/audit-project/SKILL.md")) {
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

    $sourceSkill = Get-RepoFile -Root $Root -RelativePath "skills/audit-project/SKILL.md"
    if (Test-Path -LiteralPath $sourceSkill -PathType Leaf) {
        $liveTargets = @(
            Join-Path $env:USERPROFILE "plugins/project/skills/audit-project/SKILL.md"
            Join-Path $env:USERPROFILE ".agents/skills/audit-project/SKILL.md"
        )
        $liveChecks = @($liveTargets | ForEach-Object { Compare-LiveFile -SourcePath $sourceSkill -TargetPath $_ })
        $checked = @($liveChecks | Where-Object { $_.checked })
        $drifted = @($checked | Where-Object { -not $_.equal })
        if ($drifted.Count -gt 0) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "live-sync" -Severity "repairable" -Dimension "live-sync" -Message "Live deployed Doctor skill differs from source." -Artifact "skills/audit-project/SKILL.md" -Evidence @{ targets = @($drifted.target) })
        } elseif ($checked.Count -gt 0) {
            Add-Finding -Findings $Findings -Category healthy -Finding (New-Finding -Id "live-sync" -Severity "healthy" -Dimension "live-sync" -Message "Checked live Doctor skill target matches source." -Artifact "skills/audit-project/SKILL.md" -Evidence @{ targets = @($checked.target) })
        } else {
            Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "live-sync" -Severity "informational" -Dimension "live-sync" -Message "Live deployed Doctor skill target was not inspected." -Artifact "skills/audit-project/SKILL.md" -Evidence @{ targets = $liveTargets })
        }
        $retiredLiveRoot = Join-Path $env:USERPROFILE "plugins/milestones"
        if (Test-Path -LiteralPath $retiredLiveRoot -PathType Container) {
            Add-Finding -Findings $Findings -Category repairable -Finding (New-Finding -Id "retired-live-plugin-root" -Severity "repairable" -Dimension "live-sync" -Message "Retired Milestones live plugin root still exists; sync-live should remove the owned retired copy." -Artifact $retiredLiveRoot)
        }
    } else {
        Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "live-sync" -Severity "informational" -Dimension "live-sync" -Message "Live sync comparison skipped because the source Doctor skill file is absent." -Artifact "skills/audit-project/SKILL.md")
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
    $projectFixture = Read-ProjectFixture -Path $ProjectFixturePath
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

    if ($TrackerHygiene) {
        if ($null -eq $projectFixture) {
            Add-Finding -Findings $Findings -Category informational -Finding (New-Finding -Id "project-v2-state" -Severity "informational" -Dimension "tracker-hygiene" -Message "Project V2 state evidence was not inspected." -Artifact "GitHub Project V2")
        } else {
            Invoke-TrackerHygieneAudit -Findings $Findings -Mirrors $Mirrors -GitHubIssues $githubIssues -ProjectFixture $projectFixture -ApplyRepairs:$ApplyTrackerRepairs.IsPresent -RepairReceipt $script:repairReceipt
        }
    }
}

$root = Resolve-RepoRoot -Path $RepoRoot
$findings = @{
    blocking = [System.Collections.Generic.List[object]]::new()
    repairable = [System.Collections.Generic.List[object]]::new()
    informational = [System.Collections.Generic.List[object]]::new()
    healthy = [System.Collections.Generic.List[object]]::new()
}
$script:repairReceipt = [System.Collections.Generic.List[object]]::new()

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
    phase = "audit-project-audit"
    mode = $Mode
    repo_root = $root
    target_repo = Get-RepoSlug -Root $root
    tracker_hygiene = $TrackerHygiene.IsPresent
    mutation_allowed = $ApplyTrackerRepairs.IsPresent
    repair_receipt = @($script:repairReceipt)
    repair_policy = [ordered]@{
        report_first = $true
        native_repair_approval = "request_user_input"
        allowed_after_approval = @("project docs", "issue mirrors", "labels", "milestone metadata", "wrappers", "live sync cleanup owned by this plugin", "status labels on closed GitHub issues", "canonical Project V2 item fields")
        blocked_mutations = @("product code", "implementation tests", "runtime config", "branches", "PR merges", "issue close state", "native goals", "Project V2 draft publication or deletion")
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

