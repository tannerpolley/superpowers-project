[CmdletBinding()]
param(
    [ValidateSet("Inspect", "ApplySetup", "FinalizeSetup")]
    [string]$Mode = "Inspect",
    [string]$RepoRoot = ".",
    [string]$Issue = $env:RIWG_ISSUE,
    [string]$BranchPolicy = $env:RIWG_BRANCH_POLICY,
    [string]$Slug = $env:RIWG_SLUG,
    [string]$OutputDir = $env:RIWG_OUTPUT_DIR,
    [string]$HandoffJson,
    [string]$HandoffPath,
    [string]$PreflightJson,
    [string]$PreflightPath,
    [string]$NativeGoalProofJson,
    [string]$NativeGoalProofPath,
    [string]$IssueFixturePath,
    [switch]$SkipGhAuth
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\contract.ps1")

function Read-OptionalJson {
    param([string]$Json, [string]$Path, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Json) -and [string]::IsNullOrWhiteSpace($Path)) {
        throw "missing $Name JSON"
    }
    Read-JsonInput -Json $Json -Path $Path -Name $Name
}

function Get-IssueMarker {
    param([Parameter(Mandatory = $true)][string]$Body)
    $marker = Find-IssueMarker -Body $Body
    if ($null -eq $marker) {
        throw 'run $convert-idea-to-issue first: issue is missing hidden resolve-issue-with-goal readiness marker'
    }
    $marker
}

function Find-IssueMarker {
    param([Parameter(Mandatory = $true)][string]$Body)
    $match = [regex]::Match($Body, '<!--\s*resolve-issue-with-goal\s*(?<json>.*?)\s*-->', [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        return $null
    }
    try {
        $match.Groups["json"].Value.Trim() | ConvertFrom-Json
    } catch {
        throw "hidden resolve-issue-with-goal marker contains invalid JSON: $($_.Exception.Message)"
    }
}

function Get-ExternalIssueMarker {
    param([Parameter(Mandatory = $true)][string]$Body)
    $match = [regex]::Match($Body, '<!--\s*convert-idea-to-issue-external-source\s*(?<json>.*?)\s*-->', [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        return $null
    }
    try {
        $match.Groups["json"].Value.Trim() | ConvertFrom-Json
    } catch {
        throw "hidden convert-idea-to-issue external-source marker contains invalid JSON: $($_.Exception.Message)"
    }
}

function ConvertTo-Slug {
    param([Parameter(Mandatory = $true)][string]$Value)
    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if ($slug.Length -gt 63) { $slug = $slug.Substring(0, 63).Trim('-') }
    if ([string]::IsNullOrWhiteSpace($slug)) { throw "could not derive slug from external issue title" }
    $slug
}

function Set-MarkerProperty {
    param(
        [Parameter(Mandatory = $true)]$Marker,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )
    if (Test-Property -Object $Marker -Name $Name) {
        $Marker.$Name = $Value
    } else {
        $Marker | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Get-IssueUrl {
    param($IssueObject, [string]$RemoteSlug)
    if (-not [string]::IsNullOrWhiteSpace([string]$IssueObject.url)) {
        return [string]$IssueObject.url
    }
    if ($null -ne $IssueObject.number) {
        return "https://github.com/$RemoteSlug/issues/$($IssueObject.number)"
    }
    throw "issue fixture must include url or number"
}

function Get-MarkdownSectionItems {
    param(
        [Parameter(Mandatory = $true)][string]$Body,
        [Parameter(Mandatory = $true)][string[]]$Names
    )
    $items = [System.Collections.Generic.List[string]]::new()
    $capture = $false
    foreach ($line in ($Body -split '\r?\n')) {
        if ($line -match '^\s{0,3}#{1,6}\s+(?<heading>.+?)\s*$') {
            $heading = ($Matches.heading -replace '\s+', ' ').Trim()
            $capture = @($Names | Where-Object { $heading -match $_ }).Count -gt 0
            continue
        }
        if (-not $capture) { continue }
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^[-*]\s+\[[ xX]\]\s*(?<value>.+)$') {
            $items.Add($Matches.value.Trim())
        } elseif ($trimmed -match '^[-*]\s+(?<value>.+)$') {
            $items.Add($Matches.value.Trim())
        }
    }
    @($items)
}

function Get-MarkdownCheckboxLines {
    param([Parameter(Mandatory = $true)][string]$Body)
    @($Body -split '\r?\n' | Where-Object { $_ -match '^\s*[-*]\s+\[[ xX]\]' } | ForEach-Object { $_.TrimEnd() })
}

function Find-FullRoadmapPath {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    foreach ($candidate in @("docs/milestones/PROJECT_CONTEXT.md", "FULL_ROADMAP.md", "docs/roadmaps/FULL_ROADMAP.md", "docs/FULL_ROADMAP.md")) {
        if (Test-Path -LiteralPath (Join-Path $RepoRoot $candidate) -PathType Leaf) {
            return $candidate
        }
    }
    "none"
}

function Find-RoadmapSectionForMilestone {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$FullRoadmap,
        [Parameter(Mandatory = $true)][string]$MilestoneTitle
    )
    if ([string]::IsNullOrWhiteSpace($FullRoadmap) -or $FullRoadmap -eq "none") { return "none" }
    $path = Join-Path $RepoRoot $FullRoadmap
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return "none" }
    $headings = @()
    foreach ($line in (Get-Content -LiteralPath $path)) {
        if ($line -match '^\s{0,3}#{1,6}\s+(?<heading>.+?)\s*$') {
            $heading = ($Matches.heading -replace '\s+', ' ').Trim()
            if (-not [string]::IsNullOrWhiteSpace($heading) -and (Normalize-ContractText $heading) -ne (Normalize-ContractText $MilestoneTitle)) {
                $headings += $heading
            }
        }
    }
    foreach ($heading in $headings) {
        try {
            $sectionName = ($heading -replace '^\d+\.\s*', '').Trim()
            $entries = Get-RoadmapMilestoneEntries -RepoRoot $RepoRoot -FullRoadmap $FullRoadmap -SectionName $sectionName -ExpectedTitles @($MilestoneTitle)
            if ($entries.ContainsKey((Normalize-ContractText $MilestoneTitle))) {
                return $sectionName
            }
        } catch {
            continue
        }
    }
    "none"
}

function Test-RoadmapSectionForMilestone {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$FullRoadmap,
        [Parameter(Mandatory = $true)][string]$SectionName,
        [Parameter(Mandatory = $true)][string]$MilestoneTitle
    )
    if ([string]::IsNullOrWhiteSpace($FullRoadmap) -or $FullRoadmap -eq "none") { return $false }
    if ([string]::IsNullOrWhiteSpace($SectionName) -or $SectionName -eq "none") { return $false }
    try {
        $entries = Get-RoadmapMilestoneEntries -RepoRoot $RepoRoot -FullRoadmap $FullRoadmap -SectionName $SectionName -ExpectedTitles @($MilestoneTitle)
        return $entries.ContainsKey((Normalize-ContractText $MilestoneTitle))
    } catch {
        return $false
    }
}

function Find-MilestoneFolderName {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$MilestoneTitle
    )
    $slug = ConvertTo-Slug $MilestoneTitle
    $milestoneRoot = Join-Path $RepoRoot "docs\milestones"
    if (Test-Path -LiteralPath $milestoneRoot -PathType Container) {
        foreach ($folder in (Get-ChildItem -LiteralPath $milestoneRoot -Directory)) {
            if ($folder.Name.ToLowerInvariant() -eq $slug.ToLowerInvariant()) {
                return $folder.Name
            }
        }
    }
    $slug
}

function New-ExternalPlanMarkdown {
    param(
        [Parameter(Mandatory = $true)]$IssueObject,
        [Parameter(Mandatory = $true)][string]$IssueUrl,
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][string[]]$ProofOracle,
        [Parameter(Mandatory = $true)][string[]]$NonGoals,
        [Parameter(Mandatory = $true)][string[]]$CandidateFiles
    )
    $checkboxes = Get-MarkdownCheckboxLines -Body ([string]$IssueObject.body)
    if ($checkboxes.Count -eq 0) {
        $checkboxes = @("- [ ] Resolve the externally sourced issue as scoped in GitHub.")
    }
@"
# $([string]$IssueObject.title)

Issue: $IssueUrl
Slug: $Slug
Source: externally sourced GitHub issue localized in the target repository before GoalBuddy execution.

## Outcome

$([string]$IssueObject.title)

## Acceptance Criteria

$($checkboxes -join "`n")

## Proof Oracle

$($ProofOracle | ForEach-Object { "- $_" } | Out-String)
## Non-Goals

$($NonGoals | ForEach-Object { "- $_" } | Out-String)
## Candidate Execution Files

$($CandidateFiles | ForEach-Object { "- $_" } | Out-String)
"@
}

function New-LocalizedExternalReadinessMarker {
    param(
        [Parameter(Mandatory = $true)]$IssueObject,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$RemoteSlug,
        $ExistingMarker
    )
    if ($null -ne $ExistingMarker -and (Test-Property -Object $ExistingMarker -Name "target_repo") -and -not [string]::IsNullOrWhiteSpace([string]$ExistingMarker.target_repo) -and [string]$ExistingMarker.target_repo -ne $RemoteSlug) {
        throw "external issue target_repo does not match target RepoRoot remote: marker='$($ExistingMarker.target_repo)' repo_root='$RemoteSlug'"
    }
    $slugValue = if (-not [string]::IsNullOrWhiteSpace($Slug)) {
        $Slug
    } elseif ($null -ne $ExistingMarker -and (Test-Property -Object $ExistingMarker -Name "slug") -and -not [string]::IsNullOrWhiteSpace([string]$ExistingMarker.slug)) {
        [string]$ExistingMarker.slug
    } else {
        ConvertTo-Slug ([string]$IssueObject.title)
    }
    if ($slugValue -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
        throw "localized external issue slug must be kebab-case lowercase alphanumeric"
    }

    $issueMilestone = if ($null -ne $IssueObject.milestone -and (Test-Property -Object $IssueObject.milestone -Name "title")) { [string]$IssueObject.milestone.title } else { "" }
    $milestonePolicy = if ([string]::IsNullOrWhiteSpace($issueMilestone)) { "none" } else { "hard" }
    $milestoneTitle = if ($milestonePolicy -eq "hard") { $issueMilestone } else { "none" }
    $fullRoadmap = if ($milestonePolicy -eq "hard") { Find-FullRoadmapPath -RepoRoot $RepoRoot } else { "none" }
    $section = if ($milestonePolicy -eq "hard") { Find-RoadmapSectionForMilestone -RepoRoot $RepoRoot -FullRoadmap $fullRoadmap -MilestoneTitle $milestoneTitle } else { "none" }
    $milestoneFolder = if ($milestonePolicy -eq "hard") { Find-MilestoneFolderName -RepoRoot $RepoRoot -MilestoneTitle $milestoneTitle } else { "" }
    $planFile = if ($milestonePolicy -eq "hard") { "docs/milestones/$milestoneFolder/issues/$slugValue.md" } else { "docs/issues/$slugValue.md" }

    $proofOracle = @()
    if ($null -ne $ExistingMarker -and (Test-Property -Object $ExistingMarker -Name "proof_oracle")) {
        $proofOracle = Get-StringArray $ExistingMarker.proof_oracle
    }
    if ($proofOracle.Count -eq 0) {
        $proofOracle = Get-MarkdownSectionItems -Body ([string]$IssueObject.body) -Names @('^(Proof Oracle|Proof|Validation)$')
    }
    if ($proofOracle.Count -eq 0) {
        $proofOracle = @("Run the target repo's relevant local verification and satisfy every issue acceptance criterion before PR merge.")
    }

    $nonGoals = @()
    if ($null -ne $ExistingMarker -and (Test-Property -Object $ExistingMarker -Name "non_goals")) {
        $nonGoals = Get-StringArray $ExistingMarker.non_goals
    }
    if ($nonGoals.Count -eq 0) {
        $nonGoals = Get-MarkdownSectionItems -Body ([string]$IssueObject.body) -Names @('^(Non-Goals|Non Goals|Out of Scope)$')
    }
    if ($nonGoals.Count -eq 0) {
        $nonGoals = @("Do not make unrelated changes outside this issue scope.")
    }

    $candidateFiles = @()
    if ($null -ne $ExistingMarker -and (Test-Property -Object $ExistingMarker -Name "candidate_allowed_files")) {
        $candidateFiles = Get-StringArray $ExistingMarker.candidate_allowed_files
    }
    if ($candidateFiles.Count -eq 0) {
        $candidateFiles = Get-MarkdownSectionItems -Body ([string]$IssueObject.body) -Names @('^(Candidate Allowed Files|Candidate Files|Execution Files)$')
    }
    if ($candidateFiles.Count -eq 0) {
        $candidateFiles = @("**/*")
    }

    $requiredChecksPolicy = if ($null -ne $ExistingMarker -and (Test-Property -Object $ExistingMarker -Name "required_checks_policy") -and -not [string]::IsNullOrWhiteSpace([string]$ExistingMarker.required_checks_policy)) {
        [string]$ExistingMarker.required_checks_policy
    } else {
        "require-existing"
    }

    $marker = [ordered]@{
        slug = $slugValue
        target_repo = $RemoteSlug
        issue_source_policy = "local-main-sync"
        plan_file = $planFile
        milestone_policy = $milestonePolicy
        milestone_title = $milestoneTitle
        full_roadmap = $fullRoadmap
        full_roadmap_milestone_section = $section
        proof_oracle = $proofOracle
        non_goals = $nonGoals
        candidate_allowed_files = $candidateFiles
        required_checks_policy = $requiredChecksPolicy
    }
    [pscustomobject]@{
        marker = $marker
        slug = $slugValue
        plan_file = $planFile
        proof_oracle = $proofOracle
        non_goals = $nonGoals
        candidate_allowed_files = $candidateFiles
    }
}

function Repair-ReadyMarkerMilestoneRoadmap {
    param(
        [Parameter(Mandatory = $true)]$Marker,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ([string]$Marker.milestone_policy -ne "hard") { return $null }
    Assert-NonWeakString -Value ([string]$Marker.milestone_title) -Name "marker milestone_title"

    $needsRoadmap = (-not (Test-Property -Object $Marker -Name "full_roadmap")) -or [string]::IsNullOrWhiteSpace([string]$Marker.full_roadmap) -or [string]$Marker.full_roadmap -eq "none"
    $needsSection = (-not (Test-Property -Object $Marker -Name "full_roadmap_milestone_section")) -or [string]::IsNullOrWhiteSpace([string]$Marker.full_roadmap_milestone_section) -or [string]$Marker.full_roadmap_milestone_section -eq "none"

    $roadmap = if ($needsRoadmap) { Find-FullRoadmapPath -RepoRoot $RepoRoot } else { [string]$Marker.full_roadmap }
    if ([string]::IsNullOrWhiteSpace($roadmap) -or $roadmap -eq "none") {
        throw "marker full_roadmap is required when milestone_policy is hard"
    }
    if (-not $needsSection) {
        $needsSection = -not (Test-RoadmapSectionForMilestone -RepoRoot $RepoRoot -FullRoadmap $roadmap -SectionName ([string]$Marker.full_roadmap_milestone_section) -MilestoneTitle ([string]$Marker.milestone_title))
    }
    $section = if ($needsSection) { Find-RoadmapSectionForMilestone -RepoRoot $RepoRoot -FullRoadmap $roadmap -MilestoneTitle ([string]$Marker.milestone_title) } else { [string]$Marker.full_roadmap_milestone_section }
    if ([string]::IsNullOrWhiteSpace($section) -or $section -eq "none") {
        throw "marker full_roadmap_milestone_section is required when milestone_policy is hard"
    }
    if (-not ($needsRoadmap -or $needsSection)) { return $null }

    Set-MarkerProperty -Marker $Marker -Name "full_roadmap" -Value $roadmap
    Set-MarkerProperty -Marker $Marker -Name "full_roadmap_milestone_section" -Value $section
    [pscustomobject]@{
        issue_body_update_required = $true
        reason = "milestone-backed readiness marker was missing or had invalid full roadmap fields"
        full_roadmap = $roadmap
        full_roadmap_milestone_section = $section
        readiness_marker = ConvertTo-PrettyJson $Marker
    }
}

function Invoke-ExternalIssueLocalization {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)]$IssueObject,
        [Parameter(Mandatory = $true)][string]$IssueUrl,
        [Parameter(Mandatory = $true)]$Localization
    )
    $planFile = Assert-SafeRelativePath -Path ([string]$Localization.plan_file) -Name "localized plan_file"
    if (-not (Test-SlicePlanPath -Path $planFile -Slug ([string]$Localization.slug))) {
        throw "localized plan_file must match the slug-derived local issue-file path"
    }
    $planPath = Assert-UnderRepo -Repo $RepoRoot -Path (Join-Path $RepoRoot $planFile) -Name "localized plan_file"
    $created = $false
    if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $planPath) -Force | Out-Null
        Set-Content -LiteralPath $planPath -Value (New-ExternalPlanMarkdown -IssueObject $IssueObject -IssueUrl $IssueUrl -Slug ([string]$Localization.slug) -ProofOracle $Localization.proof_oracle -NonGoals $Localization.non_goals -CandidateFiles $Localization.candidate_allowed_files) -Encoding UTF8
        $created = $true
    }
    [pscustomobject]@{
        created_plan_file = $created
        plan_file = $planFile
        readiness_marker = ConvertTo-PrettyJson $Localization.marker
        issue_body_update_required = $true
        default_branch_sync_required = $true
    }
}

function Get-SafeGlobArray {
    param($Value, [string]$Name)
    $items = Get-StringArray $Value
    if ($items.Count -eq 0) { throw "$Name must be non-empty" }
    foreach ($item in $items) {
        $normalized = Normalize-RepoPath $item
        if ([string]::IsNullOrWhiteSpace($normalized) -or [IO.Path]::IsPathRooted($item) -or $normalized.StartsWith("/") -or $normalized -match '(^|/)\.\.(/|$)' -or $normalized -match '[<>:"|?]') {
            throw "$Name contains unsafe repo-relative path or glob: $item"
        }
    }
    $items
}

function Assert-PrepareOutputDir {
    param([string]$Root, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $full = [IO.Path]::GetFullPath($Path)
    $repo = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if ($full.TrimEnd('\', '/').StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) {
        throw "RIWG_OUTPUT_DIR must be outside the repo so generated handoff/ledger files are not tracked"
    }
    New-Item -ItemType Directory -Path $full -Force | Out-Null
    $full
}

function Write-OutputFile {
    param([string]$Directory, [string]$Name, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Directory)) { return $null }
    $path = Join-Path $Directory $Name
    Set-Content -LiteralPath $path -Value $Value -Encoding UTF8
    $path
}

function ConvertTo-PrettyJson {
    param($Value)
    $Value | ConvertTo-Json -Depth 32
}

function ConvertTo-YamlSingleQuoted {
    param([string]$Value)
    "'" + ($Value -replace "'", "''") + "'"
}

function Format-YamlList {
    param([string[]]$Items, [int]$Indent = 6)
    $spaces = " " * $Indent
    (@($Items) | ForEach-Object { "$spaces- $(ConvertTo-YamlSingleQuoted ([string]$_))" }) -join "`n"
}

function New-NativeGoalObjective {
    param($Handoff)
    $proof = (Get-StringArray $Handoff.proof_oracle) -join "; "
    $nonGoals = (Get-StringArray $Handoff.non_goals) -join "; "
    "Resolve $($Handoff.issue_url) on $($Handoff.branch) using plan $($Handoff.plan_file) and local GoalBuddy board $($Handoff.goal_board). Proof oracle: $proof. Non-goals: $nonGoals. Complete only after PR merge, exact linked issue closure, default branch sync, goal branch cleanup, local board deletion, and cleanup-hook proof."
}

function New-GoalMarkdown {
    param($Handoff, [string[]]$CandidateFiles)
@"
# $($Handoff.slug)

Issue: $($Handoff.issue_url)
Plan: $($Handoff.plan_file)
Branch: $($Handoff.branch)

## Outcome

$($Handoff.outcome)

## Proof Oracle

$((Get-StringArray $Handoff.proof_oracle | ForEach-Object { "- $_" }) -join "`n")

## Non-Goals

$((Get-StringArray $Handoff.non_goals | ForEach-Object { "- $_" }) -join "`n")

## Initial Worker Boundary

$($CandidateFiles | ForEach-Object { "- $_" } | Out-String)
"@
}

function New-StateYaml {
    param($Handoff, [string[]]$CandidateFiles)
    $verifyItems = Get-StringArray $Handoff.proof_oracle
    $oracle = (Get-StringArray $Handoff.proof_oracle) -join "; "
    $allowedYaml = Format-YamlList -Items $CandidateFiles
    $verifyYaml = Format-YamlList -Items $verifyItems
@"
version: 2
goal:
  status: active
  oracle: $(ConvertTo-YamlSingleQuoted $oracle)
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
    objective: $(ConvertTo-YamlSingleQuoted "Map the issue, local issue file, existing code/docs/tests, and candidate Worker boundary without editing files.")
    receipt: null
  - id: T002
    type: judge
    assignee: Judge
    status: queued
    objective: $(ConvertTo-YamlSingleQuoted "Validate readiness, choose the largest safe useful Worker slice, and preserve receipts for issue/PR closeout.")
    receipt: null
  - id: T003
    type: worker
    assignee: Worker
    status: queued
    objective: $(ConvertTo-YamlSingleQuoted "Implement the first bounded slice that makes the issue measurably closer to done.")
    allowed_files:
$allowedYaml
    verify:
$verifyYaml
    stop_if:
      - 'Need files outside allowed_files.'
      - 'Issue scope, non-goals, or proof oracle is contradicted.'
      - 'Required credentials or external services cannot be reached.'
    receipt: null
checks: []
"@
}

function Assert-UnderRepo {
    param([string]$Repo, [string]$Path, [string]$Name)
    $repoFull = [IO.Path]::GetFullPath($Repo).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name resolved outside repo: $Path"
    }
    $full
}

function Get-PreflightProof {
    param([string]$Json, [string]$Path)
    $proof = Read-OptionalJson -Json $Json -Path $Path -Name "preflight proof"
    if ($proof.ok -ne $true -or [string]$proof.phase -ne "preflight") {
        throw "ApplySetup requires successful preflight proof"
    }
    if ($null -eq $proof.evidence -or $null -eq $proof.evidence.branch_inventory_before) {
        throw "preflight proof is missing branch_inventory_before evidence"
    }
    $proof
}

function Get-IssueObject {
    param([string]$Root, [string]$RemoteSlug)
    if (-not [string]::IsNullOrWhiteSpace($IssueFixturePath)) {
        Assert-TestModeSwitch -Name "-IssueFixturePath"
        return Read-JsonInput -Path $IssueFixturePath -Name "issue fixture"
    }
    if ([string]::IsNullOrWhiteSpace($Issue)) {
        throw "missing issue; pass -Issue or set RIWG_ISSUE"
    }
    $issueArg = $Issue
    $repoArg = $RemoteSlug
    if ($Issue -match '^https://github\.com/[^/]+/[^/]+/issues/(?<n>\d+)') {
        $issueRepo = Get-RepoSlugFromIssueUrl -IssueUrl $Issue
        if ([string]$issueRepo -ne [string]$RemoteSlug) {
            throw "issue URL repository does not match target RepoRoot: issue='$issueRepo' repo_root='$RemoteSlug'"
        }
        $issueArg = $Matches.n
    }
    $result = Invoke-Gh -Arguments @("issue", "view", $issueArg, "--repo", $repoArg, "--json", "url,number,title,body,state,labels,milestone") -WorkingDirectory $Root
    if ($result.ExitCode -ne 0) {
        throw "could not read GitHub issue: $($result.Stderr)"
    }
    $result.Stdout | ConvertFrom-Json
}

$phase = "prepare-execution.$($Mode.ToLowerInvariant())"
$evidence = @{}

try {
    if ($SkipGhAuth.IsPresent) { Assert-TestModeSwitch -Name "-SkipGhAuth" }
    $root = Get-CanonicalRepoRoot -RepoRoot $RepoRoot
    $outputRoot = Assert-PrepareOutputDir -Root $root -Path $OutputDir

    if ($Mode -eq "Inspect") {
        $context = Get-GithubRepoContext -RepoRoot $root -SkipGhAuth:$SkipGhAuth
        $issueObject = Get-IssueObject -Root $root -RemoteSlug $context.remote_slug
        if ([string]$issueObject.state -ne "OPEN") {
            throw "run $convert-idea-to-issue first: issue is not OPEN"
        }
        $body = [string]$issueObject.body
        if (-not (Test-HasCheckbox -Text $body)) {
            throw 'run $convert-idea-to-issue first: issue has no acceptance-criteria checkboxes'
        }
        $marker = Find-IssueMarker -Body $body
        $externalMarker = Get-ExternalIssueMarker -Body $body
        $externalLocalization = $null
        $readinessMarkerRepair = $null
        if ($null -eq $marker) {
            if ($null -eq $externalMarker) {
                throw 'run $convert-idea-to-issue first: issue is missing hidden resolve-issue-with-goal readiness marker'
            }
            $issueUrlForLocalization = Get-IssueUrl -IssueObject $issueObject -RemoteSlug $context.remote_slug
            $localized = New-LocalizedExternalReadinessMarker -IssueObject $issueObject -RepoRoot $root -RemoteSlug $context.remote_slug -ExistingMarker $externalMarker
            $externalLocalization = Invoke-ExternalIssueLocalization -RepoRoot $root -IssueObject $issueObject -IssueUrl $issueUrlForLocalization -Localization $localized
            $marker = $localized.marker
        } elseif ((Test-Property -Object $marker -Name "issue_source_policy") -and [string]$marker.issue_source_policy -ne "local-main-sync") {
            $issueUrlForLocalization = Get-IssueUrl -IssueObject $issueObject -RemoteSlug $context.remote_slug
            $localized = New-LocalizedExternalReadinessMarker -IssueObject $issueObject -RepoRoot $root -RemoteSlug $context.remote_slug -ExistingMarker $marker
            $externalLocalization = Invoke-ExternalIssueLocalization -RepoRoot $root -IssueObject $issueObject -IssueUrl $issueUrlForLocalization -Localization $localized
            $marker = $localized.marker
        } else {
            $readinessMarkerRepair = Repair-ReadyMarkerMilestoneRoadmap -Marker $marker -RepoRoot $root
        }
        $candidateFiles = Get-SafeGlobArray -Value $marker.candidate_allowed_files -Name "candidate_allowed_files"
        $slugValue = if ([string]::IsNullOrWhiteSpace($Slug)) { [string]$marker.slug } else { $Slug }
        if ($slugValue -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
            throw "marker slug must be kebab-case lowercase alphanumeric"
        }
        $planFile = Assert-SafeRelativePath -Path ([string]$marker.plan_file) -Name "marker plan_file"
        if (-not (Test-SlicePlanPath -Path $planFile -Slug $slugValue)) {
            throw "marker plan_file must match the slug-derived local issue-file path"
        }
        $planPath = Join-Path $root $planFile
        if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
            throw "run $convert-idea-to-issue first: linked local issue file is missing"
        }
        if ([string]$marker.milestone_policy -eq "hard") {
            Assert-NonWeakString -Value ([string]$marker.milestone_title) -Name "marker milestone_title"
            if ([string]$marker.full_roadmap -eq "none") { throw "marker full_roadmap is required when milestone_policy is hard" }
            if ($null -eq $issueObject.milestone -or [string]$issueObject.milestone.title -ne [string]$marker.milestone_title) {
                throw "run $convert-idea-to-issue first: issue milestone does not match hidden marker"
            }
        }
        $markerBranchPolicy = if (Test-Property -Object $marker -Name "branch_policy") { [string]$marker.branch_policy } else { "" }
        $branchPolicyValue = if (-not [string]::IsNullOrWhiteSpace($BranchPolicy)) {
            $BranchPolicy
        } elseif (-not [string]::IsNullOrWhiteSpace($markerBranchPolicy)) {
            $markerBranchPolicy
        } else {
            "create"
        }
        if ($branchPolicyValue -notin @("create", "reuse-current")) {
            throw "branch_policy must be create or reuse-current"
        }
        $requiredChecksPolicy = [string]$marker.required_checks_policy
        if ($requiredChecksPolicy -notin @("require-existing", "allow-none-with-local-proof")) {
            throw "required_checks_policy must be require-existing or allow-none-with-local-proof"
        }
        $issueUrl = [string]$issueObject.url
        if ([string]::IsNullOrWhiteSpace($issueUrl)) {
            if ($null -ne $issueObject.number) {
                $issueUrl = "https://github.com/$($context.remote_slug)/issues/$($issueObject.number)"
            } else {
                throw "issue fixture must include url or number"
            }
        }
        $handoff = [ordered]@{
            slug = $slugValue
            target_repo = $context.remote_slug
            issue_url = $issueUrl
            outcome = if ([string]::IsNullOrWhiteSpace([string]$issueObject.title)) { "Resolve $issueUrl" } else { [string]$issueObject.title }
            issue_policy = "link:$issueUrl"
            issue_readiness = [ordered]@{
                source = "prepare-execution Inspect"
                state = "OPEN"
                single_execution_scope = $true
                acceptance_criteria_present = $true
                linked_plan_file_exists = $true
                issue_plan_alignment = $true
            }
            branch_policy = $branchPolicyValue
            branch = "codex/$slugValue"
            full_roadmap = [string]$marker.full_roadmap
            milestone_policy = [string]$marker.milestone_policy
            milestone_title = [string]$marker.milestone_title
            full_roadmap_milestone_section = [string]$marker.full_roadmap_milestone_section
            project_policy = "dashboard-only"
            plan_file = $planFile
            goal_board = "docs/goals/$slugValue"
            proof_oracle = Get-StringArray $marker.proof_oracle
            non_goals = Get-StringArray $marker.non_goals
            candidate_allowed_files = $candidateFiles
            merge_policy = "ready PR, closing keyword for exact issue, checks passing, MERGEABLE, no requested changes, no unresolved non-outdated actionable review threads, squash merge"
            required_checks_policy = $requiredChecksPolicy
            allowed_existing_dirty_paths = @()
        }
        $handoffJson = ConvertTo-PrettyJson $handoff
        [void](Get-Handoff -HandoffJson $handoffJson)
        $objective = New-NativeGoalObjective -Handoff $handoff
        $handoffPathOut = Write-OutputFile -Directory $outputRoot -Name "handoff.json" -Value $handoffJson
        $objectivePathOut = Write-OutputFile -Directory $outputRoot -Name "native-goal-objective.txt" -Value $objective
        $evidence = @{
            mode = "Inspect"
            repo_root = $root
            remote_slug = $context.remote_slug
            issue_url = $issueUrl
            external_issue_localization = $externalLocalization
            readiness_marker_repair = $readinessMarkerRepair
            handoff = $handoff
            handoff_json = $handoffJson
            handoff_path = $handoffPathOut
            native_goal_objective = $objective
            native_goal_objective_path = $objectivePathOut
            labels = @($issueObject.labels | ForEach-Object { if ($_ -is [string]) { $_ } else { [string]$_.name } })
        }
        Complete-Contract -Phase $phase -Reason "execution handoff prepared" -Evidence $evidence
    }

    $handoffObject = Get-Handoff -HandoffJson $HandoffJson -HandoffPath $HandoffPath
    $origin = Invoke-Git -RepoRoot $root -Arguments @("remote", "get-url", "origin")
    if ($origin.ExitCode -ne 0) { throw "missing GitHub origin remote" }
    $remoteSlug = Get-OriginRemoteSlug -RemoteUrl $origin.Stdout
    if ([string]::IsNullOrWhiteSpace($remoteSlug)) { throw "origin remote is not a GitHub repository" }
    if ([string]$handoffObject.target_repo -ne [string]$remoteSlug) {
        throw "handoff target_repo does not match target RepoRoot remote"
    }

    if ($Mode -eq "ApplySetup") {
        $preflight = Get-PreflightProof -Json $PreflightJson -Path $PreflightPath
        $candidateFiles = Get-SafeGlobArray -Value $handoffObject.candidate_allowed_files -Name "candidate_allowed_files"
        $currentBranch = Invoke-Git -RepoRoot $root -Arguments @("branch", "--show-current")
        if ($currentBranch.ExitCode -ne 0) { throw "could not resolve current branch: $($currentBranch.Stderr)" }
        if ([string]$handoffObject.branch_policy -eq "create") {
            $checkout = Invoke-Git -RepoRoot $root -Arguments @("checkout", "-b", ([string]$handoffObject.branch))
            if ($checkout.ExitCode -ne 0) { throw "could not create goal branch: $($checkout.Stderr)" }
        } elseif ((Normalize-RepoPath $currentBranch.Stdout) -ne (Normalize-RepoPath ([string]$handoffObject.branch))) {
            throw "branch_policy reuse-current requires current branch to equal handoff branch"
        }

        $gitignorePath = Join-Path $root ".gitignore"
        $gitignore = if (Test-Path -LiteralPath $gitignorePath -PathType Leaf) { Get-Content -LiteralPath $gitignorePath -Raw } else { "" }
        $linesToAdd = @()
        if ($gitignore -notmatch "(?m)^\s*docs/goals/?\s*$" -and $gitignore -notmatch "(?m)^\s*docs/goals/\*\s*$") { $linesToAdd += "docs/goals/" }
        if ($gitignore -notmatch "(?m)\.goalbuddy-board/") { $linesToAdd += "**/.goalbuddy-board/" }
        if ($linesToAdd.Count -gt 0) {
            $prefix = if ([string]::IsNullOrWhiteSpace($gitignore) -or $gitignore.EndsWith("`n")) { "" } else { "`n" }
            Add-Content -LiteralPath $gitignorePath -Value ($prefix + ($linesToAdd -join "`n")) -Encoding UTF8
        }

        $trackedGoalPaths = @(Get-TrackedGoalPaths -RepoRoot $root | Where-Object {
            $normalized = Normalize-RepoPath $_
            ($normalized -match '^docs/goals/' -and $normalized -ne 'docs/goals/README.md') -or $normalized -match '(^|/)\.goalbuddy-board/'
        })
        if ($trackedGoalPaths.Count -gt 0) {
            $rm = Invoke-Git -RepoRoot $root -Arguments (@("rm", "-r", "--ignore-unmatch", "--") + $trackedGoalPaths)
            if ($rm.ExitCode -ne 0) { throw "could not remove stale tracked GoalBuddy docs: $($rm.Stderr)" }
        }

        $goalBoardPath = Assert-UnderRepo -Repo $root -Path (Join-Path $root ([string]$handoffObject.goal_board)) -Name "goal_board"
        if (Test-Path -LiteralPath $goalBoardPath) {
            Remove-Item -LiteralPath $goalBoardPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $goalBoardPath -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $goalBoardPath "notes") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $goalBoardPath "goal.md") -Value (New-GoalMarkdown -Handoff $handoffObject -CandidateFiles $candidateFiles) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $goalBoardPath "state.yaml") -Value (New-StateYaml -Handoff $handoffObject -CandidateFiles $candidateFiles) -Encoding UTF8

        $validator = Join-Path $PSScriptRoot "validate-goalbuddy-contract.mjs"
        $stateYaml = Join-Path $goalBoardPath "state.yaml"
        $contractCheck = Invoke-External -FilePath "node" -Arguments @($validator, $stateYaml) -WorkingDirectory $root
        if ($contractCheck.ExitCode -ne 0) {
            throw "generated GoalBuddy board failed delegation contract: $($contractCheck.Stdout) $($contractCheck.Stderr)"
        }

        $draftLedger = [ordered]@{
            issue_url = [string]$handoffObject.issue_url
            branch = [string]$handoffObject.branch
            slice_roadmap_path = [string]$handoffObject.plan_file
            goal_board_path = [string]$handoffObject.goal_board
            proof_oracle = Get-StringArray $handoffObject.proof_oracle
            branch_inventory_before = $preflight.evidence.branch_inventory_before
        }
        $objective = New-NativeGoalObjective -Handoff $handoffObject
        $draftJson = ConvertTo-PrettyJson $draftLedger
        $draftPathOut = Write-OutputFile -Directory $outputRoot -Name "setup-ledger-draft.json" -Value $draftJson
        $objectivePathOut = Write-OutputFile -Directory $outputRoot -Name "native-goal-objective.txt" -Value $objective
        $evidence = @{
            mode = "ApplySetup"
            issue_url = $handoffObject.issue_url
            branch = $handoffObject.branch
            goal_board_path = $handoffObject.goal_board
            setup_ledger_draft = $draftLedger
            setup_ledger_draft_json = $draftJson
            setup_ledger_draft_path = $draftPathOut
            native_goal_objective = $objective
            native_goal_objective_path = $objectivePathOut
            tracked_goal_paths_removed = $trackedGoalPaths
            delegation_contract = ($contractCheck.Stdout | ConvertFrom-Json)
        }
        Complete-Contract -Phase $phase -Reason "execution setup applied; native goal activation required" -Evidence $evidence
    }

    if ($Mode -eq "FinalizeSetup") {
        $preflight = Get-PreflightProof -Json $PreflightJson -Path $PreflightPath
        $nativeProof = Read-OptionalJson -Json $NativeGoalProofJson -Path $NativeGoalProofPath -Name "native goal proof"
        $ledger = [ordered]@{
            issue_url = [string]$handoffObject.issue_url
            branch = [string]$handoffObject.branch
            slice_roadmap_path = [string]$handoffObject.plan_file
            goal_board_path = [string]$handoffObject.goal_board
            goal_activation_proof = $nativeProof
            proof_oracle = Get-StringArray $handoffObject.proof_oracle
            branch_inventory_before = $preflight.evidence.branch_inventory_before
        }
        $ledgerJson = ConvertTo-PrettyJson $ledger
        [void](Get-SetupLedger -SetupLedgerJson $ledgerJson -Handoff $handoffObject -RemoteSlug $remoteSlug)
        $ledgerPathOut = Write-OutputFile -Directory $outputRoot -Name "setup-ledger.json" -Value $ledgerJson
        $evidence = @{
            mode = "FinalizeSetup"
            issue_url = $handoffObject.issue_url
            branch = $handoffObject.branch
            setup_ledger = $ledger
            setup_ledger_json = $ledgerJson
            setup_ledger_path = $ledgerPathOut
        }
        Complete-Contract -Phase $phase -Reason "setup ledger finalized" -Evidence $evidence
    }
} catch {
    Stop-Contract -Phase $phase -Reason $_.Exception.Message -Evidence $evidence
}
