[CmdletBinding()]
param(
    [string]$HandoffJson,
    [string]$HandoffPath,
    [switch]$AbstractStrategy,
    [switch]$VagueFeatureWork,
    [switch]$ArchitectureWork,
    [switch]$BugOrFailureWork,
    [switch]$LargeScope
)

$ErrorActionPreference = "Stop"

function Write-Result {
    param([bool]$Ok, [string]$Reason, [hashtable]$Evidence = @{})
    [ordered]@{
        ok = $Ok
        phase = "plan-handoff"
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Read-JsonInput {
    param([string]$Json, [string]$Path)
    $text = if (-not [string]::IsNullOrWhiteSpace($Json)) {
        $Json
    } elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "handoff path not found: $Path" }
        Get-Content -LiteralPath $Path -Raw
    } else {
        throw "missing handoff JSON"
    }

    $trimmed = $text.Trim()
    if ($trimmed -match '```') {
        $capture = $false
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in ($text -split '\r?\n')) {
            if (-not $capture -and $line -match '^```\S*\s*convert_idea_to_issue_handoff\s*$') {
                $capture = $true
                continue
            }
            if ($capture -and $line -match '^```\s*$') { break }
            if ($capture) { $lines.Add($line) }
        }
        if ($lines.Count -gt 0) { $trimmed = ($lines -join "`n").Trim() }
    }
    $trimmed | ConvertFrom-Json
}

function Has-Field {
    param($Object, [string]$Name)
    $Object.PSObject.Properties.Name -contains $Name
}

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    @($Value)
}

function Normalize-Path {
    param([string]$Path)
    ($Path -replace "\\", "/").Trim()
}

function Has-Text {
    param($Value)
    -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Test-WeakValue {
    param($Value)
    $text = ([string]$Value).Trim().ToLowerInvariant()
    [string]::IsNullOrWhiteSpace($text) -or $text -in @("none", "unknown", "tbd", "todo", "n/a", "na", "external:none") -or $text -match '^<.*>$'
}

function Normalize-HeadingText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $normalized = ($Text -replace '^\s{0,3}#{1,6}\s+', '')
    $normalized = ($normalized -replace '^\d+\.\s*', '')
    (($normalized -replace '\s+', ' ').Trim())
}

function Assert-RoadmapMilestoneSectionContainsTitle {
    param(
        [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
        [Parameter(Mandatory = $true)][string]$FullRoadmap,
        [Parameter(Mandatory = $true)][string]$SectionName,
        [Parameter(Mandatory = $true)][string]$MilestoneTitle,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path -LiteralPath $TargetRepoRoot -PathType Container)) { return }
    $roadmapPath = Join-Path $TargetRepoRoot $FullRoadmap
    if (-not (Test-Path -LiteralPath $roadmapPath -PathType Leaf)) {
        throw "$Name full_roadmap does not exist under target_repo_root: $FullRoadmap"
    }

    $wantedSection = Normalize-HeadingText $SectionName
    $wantedMilestone = Normalize-HeadingText $MilestoneTitle
    $inSection = $false
    $sectionFound = $false
    $milestoneFound = $false
    $sectionLevel = 0

    foreach ($line in (Get-Content -LiteralPath $roadmapPath)) {
        if ($line -notmatch '^(?<hash>#{1,6})\s+(?<text>.+?)\s*$') { continue }
        $level = $Matches.hash.Length
        $heading = Normalize-HeadingText $Matches.text

        if (-not $inSection -and $heading -eq $wantedSection) {
            $inSection = $true
            $sectionFound = $true
            $sectionLevel = $level
            continue
        }
        if ($inSection -and $level -le $sectionLevel) { break }
        if ($inSection -and $heading -eq $wantedMilestone) {
            $milestoneFound = $true
            break
        }
    }

    if (-not $sectionFound) {
        throw "$Name full_roadmap_milestone_section is not a heading in full_roadmap: $SectionName"
    }
    if (-not $milestoneFound) {
        throw "$Name full_roadmap_milestone_section must name the roadmap section containing milestone '$MilestoneTitle', not the milestone heading itself"
    }
}

function Assert-SafePlanPath {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Name)
    $normalized = Normalize-Path $Path
    if ([IO.Path]::IsPathRooted($Path) -or $normalized -match '(^|/)\.\.(/|$)' -or [string]::IsNullOrWhiteSpace($normalized)) {
        throw "$Name must be a safe repo-relative path"
    }
    $normalized
}

function Test-LocalIssueFilePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Slug
    )
    $normalized = Normalize-Path $Path
    $escapedSlug = [regex]::Escape($Slug)
    return (
        $normalized -eq "docs/issues/$Slug.md" -or
        $normalized -match "^docs/issues/\d{1,6}-$escapedSlug\.md$" -or
        $normalized -eq "docs/milestones/no-milestone/issues/$Slug.md" -or
        $normalized -match "^docs/milestones/[^/]+/issues/$escapedSlug\.md$" -or
        $normalized -match "^docs/milestones/[^/]+/issues/\d{1,6}-$escapedSlug\.md$"
    )
}

function Assert-LocalIdeaSourcePath {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$SourcePolicy
    )
    if ($SourcePolicy -ne "local-main-sync") { return }

    $normalized = Normalize-Path $Source
    if ($normalized -match '^[A-Za-z][A-Za-z0-9+.-]*:') { return }
    $looksLikeRepoPath = $normalized -match '^docs/' -or $normalized -match '\.md$'
    if (-not $looksLikeRepoPath) { return }

    [void](Assert-SafePlanPath -Path $normalized -Name "canonical_issue_scope.source")
    if ($normalized -match '^docs/ideas(/|$)') {
        throw "local-main-sync source idea briefs must be under docs/milestones/<milestone-folder>/ideas, not legacy docs/ideas"
    }
    if ($normalized -notmatch '^docs/milestones/[^/]+/ideas/\d{4}-\d{2}-\d{2}-[a-z0-9][a-z0-9-]*\.md$') {
        throw "local-main-sync source idea brief must be docs/milestones/<milestone-folder>/ideas/<YYYY-MM-DD>-<slug>.md"
    }
}

function Assert-MilestonePlanningFields {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$SourcePolicy,
        [string]$TargetRepoRoot = ""
    )

    $policy = [string]$Object.milestone_policy
    if ($policy -notin @("hard", "none")) { throw "$Name milestone_policy must be hard or none" }

    if ($policy -eq "hard") {
        if (Test-WeakValue $Object.milestone_title) { throw "$Name milestone_title is required when milestone_policy is hard" }
        if ($SourcePolicy -eq "local-main-sync") {
            if (Test-WeakValue $Object.full_roadmap) { throw "$Name full_roadmap is required when milestone_policy is hard" }
            if (Test-WeakValue $Object.full_roadmap_milestone_section) { throw "$Name full_roadmap_milestone_section is required when milestone_policy is hard" }
            [void](Assert-SafePlanPath -Path ([string]$Object.full_roadmap) -Name "$Name full_roadmap")
            if (-not [string]::IsNullOrWhiteSpace($TargetRepoRoot)) {
                Assert-RoadmapMilestoneSectionContainsTitle `
                    -TargetRepoRoot $TargetRepoRoot `
                    -FullRoadmap ([string]$Object.full_roadmap) `
                    -SectionName ([string]$Object.full_roadmap_milestone_section) `
                    -MilestoneTitle ([string]$Object.milestone_title) `
                    -Name $Name
            }
        }
    } else {
        if ([string]$Object.milestone_title -ne "none") { throw "$Name milestone_title must be none when milestone_policy is none" }
        if ([string]$Object.full_roadmap -ne "none") { throw "$Name full_roadmap must be none when milestone_policy is none" }
        if ([string]$Object.full_roadmap_milestone_section -ne "none") { throw "$Name full_roadmap_milestone_section must be none when milestone_policy is none" }
    }
}

function Assert-IssueSpec {
    param(
        [Parameter(Mandatory = $true)]$Issue,
        [Parameter(Mandatory = $true)][string]$TargetRepo,
        [Parameter(Mandatory = $true)][string]$SourcePolicy,
        [string]$TargetRepoRoot = "",
        [hashtable]$SeenSlugs,
        [hashtable]$SeenPlanFiles
    )

    $requiredIssueFields = @(
        "slug", "title", "outcome", "issue_policy", "milestone_policy", "milestone_title",
        "full_roadmap", "full_roadmap_milestone_section", "plan_file",
        "required_checks_policy", "labels", "acceptance_criteria", "non_goals", "proof_oracle",
        "candidate_allowed_files"
    )
    $missingIssueFields = @()
    foreach ($field in $requiredIssueFields) {
        if (-not (Has-Field $Issue $field) -or $null -eq $Issue.$field) { $missingIssueFields += $field }
    }
    if ($missingIssueFields.Count -gt 0) { throw "issue_set item missing required fields: $($missingIssueFields -join ', ')" }

    $issueSlug = [string]$Issue.slug
    if ($issueSlug -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') { throw "issue_set slug must be kebab-case lowercase alphanumeric" }
    if ($SeenSlugs.ContainsKey($issueSlug)) { throw "issue_set contains duplicate slug: $issueSlug" }
    $SeenSlugs[$issueSlug] = $true

    if ([string]$Issue.issue_policy -ne "create" -and [string]$Issue.issue_policy -notmatch '^update:https://github\.com/[^/]+/[^/]+/issues/\d+(?:[?#].*)?$') {
        throw "issue_set issue_policy must be create or update:<GitHub issue URL>"
    }
    if ([string]$Issue.issue_policy -match '^update:https://github\.com/(?<repo>[^/]+/[^/]+)/issues/\d+(?:[?#].*)?$' -and $Matches.repo -ne $TargetRepo) {
        throw "issue_set update URL must belong to target_repo"
    }
    Assert-MilestonePlanningFields -Object $Issue -Name "issue_set" -SourcePolicy $SourcePolicy -TargetRepoRoot $TargetRepoRoot
    if ([string]$Issue.required_checks_policy -notin @("require-existing", "allow-none-with-local-proof")) { throw "issue_set required_checks_policy must be require-existing or allow-none-with-local-proof" }
    foreach ($arrayField in @("labels", "acceptance_criteria", "non_goals", "proof_oracle")) {
        if ((As-Array $Issue.$arrayField).Count -eq 0) { throw "issue_set $arrayField must be non-empty" }
    }

    $issuePlanFile = Normalize-Path ([string]$Issue.plan_file)
    $issueCandidateFiles = @(As-Array $Issue.candidate_allowed_files)
    if ($SourcePolicy -eq "local-main-sync") {
        [void](Assert-SafePlanPath -Path ([string]$Issue.plan_file) -Name "issue_set plan_file")
        if (-not (Test-LocalIssueFilePath -Path $issuePlanFile -Slug $issueSlug)) {
            throw "issue_set plan_file must be a local issue file: docs/issues/$issueSlug.md or docs/milestones/<milestone-folder>/issues/$issueSlug.md"
        }
        if ($SeenPlanFiles.ContainsKey($issuePlanFile)) { throw "issue_set contains duplicate plan_file: $issuePlanFile" }
        $SeenPlanFiles[$issuePlanFile] = $true
        if ($issueCandidateFiles.Count -eq 0) { throw "issue_set candidate_allowed_files must be non-empty for local-main-sync" }
        foreach ($path in $issueCandidateFiles) {
            $normalized = Normalize-Path ([string]$path)
            if ([IO.Path]::IsPathRooted([string]$path) -or $normalized -match '(^|/)\.\.(/|$)' -or [string]::IsNullOrWhiteSpace($normalized)) {
                throw "issue_set candidate_allowed_files must contain safe repo-relative paths or globs"
            }
        }
    } elseif ($issuePlanFile -ne "external:none") {
        throw "external-github-only issue_set items require plan_file to be external:none"
    } elseif ($issueCandidateFiles.Count -ne 0) {
        throw "external-github-only issue_set items must not include execution candidate files"
    }
}

try {
    $handoff = Read-JsonInput -Json $HandoffJson -Path $HandoffPath
    $required = @(
        "slug", "target_repo", "target_repo_root", "source_repo", "issue_source_policy", "title", "outcome", "issue_policy", "milestone_policy", "milestone_title",
        "full_roadmap", "full_roadmap_milestone_section", "project_policy", "plan_file",
        "required_checks_policy", "labels", "acceptance_criteria", "non_goals", "proof_oracle",
        "candidate_allowed_files", "canonical_issue_scope", "issue_count_policy", "decomposition_policy",
        "skills_used", "doc_grill_evidence", "decision_log", "question_log", "unresolved_decisions", "execution_boundary"
    )
    $missing = @()
    foreach ($field in $required) {
        if (-not (Has-Field $handoff $field) -or $null -eq $handoff.$field) { $missing += $field }
    }
    if ($missing.Count -gt 0) { throw "handoff missing required fields: $($missing -join ', ')" }

    $slug = [string]$handoff.slug
    if ($slug -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') { throw "slug must be kebab-case lowercase alphanumeric" }
    $targetRepo = [string]$handoff.target_repo
    if ($targetRepo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "target_repo must be GitHub owner/repo" }
    $sourceRepo = [string]$handoff.source_repo
    if ($sourceRepo -ne "external:none" -and $sourceRepo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "source_repo must be GitHub owner/repo or external:none" }
    $sourcePolicy = [string]$handoff.issue_source_policy
    if ($sourcePolicy -notin @("local-main-sync", "external-github-only")) { throw "issue_source_policy must be local-main-sync or external-github-only" }
    $targetRepoRoot = [string]$handoff.target_repo_root
    if ($sourcePolicy -eq "local-main-sync") {
        if ([string]::IsNullOrWhiteSpace($targetRepoRoot) -or $targetRepoRoot.Trim().ToLowerInvariant() -in @("none", "unknown", "tbd", "todo", "external:none")) {
            throw "target_repo_root must name the local target checkout used for docs and plan-file edits"
        }
        if (-not [IO.Path]::IsPathRooted($targetRepoRoot)) { throw "target_repo_root must be an absolute local path" }
        if ($sourceRepo -ne $targetRepo) { throw "local-main-sync requires source_repo to equal target_repo" }
    } elseif ($targetRepoRoot -ne "external:none") {
        throw "external-github-only requires target_repo_root to be external:none"
    }
    $planFile = Normalize-Path ([string]$handoff.plan_file)
    if ($sourcePolicy -eq "local-main-sync") {
        [void](Assert-SafePlanPath -Path ([string]$handoff.plan_file) -Name "plan_file")
        if (-not (Test-LocalIssueFilePath -Path $planFile -Slug $slug)) {
            throw "plan_file must be a local issue file: docs/issues/$slug.md or docs/milestones/<milestone-folder>/issues/$slug.md"
        }
    } elseif ($planFile -ne "external:none") {
        throw "external-github-only requires plan_file to be external:none"
    }

    foreach ($forbidden in @("branch_policy", "branch", "goal_board", "goal_activation_proof", "verification_ledger", "completion_ledger", "pr_url", "merge_confirmation")) {
        if (Has-Field $handoff $forbidden) { throw "planning handoff must not include execution-owned field: $forbidden" }
    }

    $boundary = $handoff.execution_boundary
    $boundaryMissing = @()
    foreach ($field in @("skill_scope", "approval_meaning", "implementation_skill", "allowed_after_approval", "forbidden_after_approval")) {
        if (-not (Has-Field $boundary $field) -or $null -eq $boundary.$field) { $boundaryMissing += $field }
    }
    if ($boundaryMissing.Count -gt 0) { throw "execution_boundary missing required fields: $($boundaryMissing -join ', ')" }
    if ([string]$boundary.skill_scope -ne "issue-and-plan-publication-only") { throw "execution_boundary skill_scope must be issue-and-plan-publication-only" }
    if ([string]$boundary.approval_meaning -ne "publish-issue-and-plan-only") { throw "execution_boundary approval_meaning must be publish-issue-and-plan-only" }
    if ([string]$boundary.implementation_skill -ne "resolve-issue-with-goal") { throw "execution_boundary implementation_skill must be resolve-issue-with-goal" }
    $allowedAfterApproval = @(As-Array $boundary.allowed_after_approval | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $forbiddenAfterApproval = @(As-Array $boundary.forbidden_after_approval | ForEach-Object { ([string]$_).ToLowerInvariant() })
    foreach ($requiredAllowed in @("repo-qualified github issue create/update", "durable local issue file writes", "default-branch commit/push for local issue docs only")) {
        if ($allowedAfterApproval -notcontains $requiredAllowed) { throw "execution_boundary allowed_after_approval missing: $requiredAllowed" }
    }
    foreach ($requiredForbidden in @("implementation branch creation", "implementation edits", "implementation commits", "implementation pushes", "pr creation", "merge", "goalbuddy board", "native goal activation")) {
        if ($forbiddenAfterApproval -notcontains $requiredForbidden) { throw "execution_boundary forbidden_after_approval missing: $requiredForbidden" }
    }

    if ([string]$handoff.issue_policy -ne "create" -and [string]$handoff.issue_policy -notmatch '^update:https://github\.com/[^/]+/[^/]+/issues/\d+(?:[?#].*)?$') {
        throw "issue_policy must be create or update:<GitHub issue URL>"
    }
    if ([string]$handoff.issue_policy -match '^update:https://github\.com/(?<repo>[^/]+/[^/]+)/issues/\d+(?:[?#].*)?$' -and $Matches.repo -ne $targetRepo) {
        throw "issue_policy update URL must belong to target_repo"
    }
    Assert-MilestonePlanningFields -Object $handoff -Name "handoff" -SourcePolicy $sourcePolicy -TargetRepoRoot $targetRepoRoot
    if ([string]$handoff.project_policy -ne "dashboard-only") { throw "project_policy must be dashboard-only" }
    if ([string]$handoff.required_checks_policy -notin @("require-existing", "allow-none-with-local-proof")) { throw "required_checks_policy must be require-existing or allow-none-with-local-proof" }
    if ([string]$handoff.issue_count_policy -notin @("single-issue", "approved-issue-set")) { throw "issue_count_policy must be single-issue or approved-issue-set" }
    if ([string]$handoff.decomposition_policy -notin @("single-issue", "approved-decompose")) { throw "decomposition_policy must be single-issue or approved-decompose" }

    foreach ($arrayField in @("labels", "acceptance_criteria", "non_goals", "proof_oracle", "skills_used")) {
        if ((As-Array $handoff.$arrayField).Count -eq 0) { throw "$arrayField must be non-empty" }
    }

    $canonicalScope = $handoff.canonical_issue_scope
    $canonicalMissing = @()
    foreach ($field in @("source", "selected_slice", "included_scope", "excluded_scope", "canonical_reason", "question_id")) {
        if (-not (Has-Field $canonicalScope $field) -or $null -eq $canonicalScope.$field) { $canonicalMissing += $field }
    }
    if ($canonicalMissing.Count -gt 0) { throw "canonical_issue_scope missing required fields: $($canonicalMissing -join ', ')" }
    foreach ($field in @("source", "selected_slice", "canonical_reason", "question_id")) {
        if (-not (Has-Text $canonicalScope.$field) -or (Test-WeakValue $canonicalScope.$field)) {
            throw "canonical_issue_scope.$field must be specific and non-empty"
        }
    }
    Assert-LocalIdeaSourcePath -Source ([string]$canonicalScope.source) -SourcePolicy $sourcePolicy
    foreach ($arrayField in @("included_scope", "excluded_scope")) {
        if ((As-Array $canonicalScope.$arrayField).Count -eq 0) { throw "canonical_issue_scope.$arrayField must be non-empty" }
    }

    $candidateAllowedFiles = @(As-Array $handoff.candidate_allowed_files)
    if ($sourcePolicy -eq "local-main-sync" -and $candidateAllowedFiles.Count -eq 0) {
        throw "candidate_allowed_files must be non-empty for local-main-sync"
    }
    if ($sourcePolicy -eq "external-github-only" -and $candidateAllowedFiles.Count -ne 0) {
        throw "external-github-only must not include execution candidate files"
    }

    $issueSet = if (Has-Field $handoff "issue_set") { @(As-Array $handoff.issue_set) } else { @() }
    if ([string]$handoff.issue_count_policy -eq "single-issue") {
        if ($issueSet.Count -ne 0) { throw "single-issue handoff must not include issue_set" }
    } else {
        if ([string]$handoff.decomposition_policy -ne "approved-decompose") {
            throw "approved-issue-set requires decomposition_policy approved-decompose"
        }
        if ($issueSet.Count -lt 2) { throw "approved-issue-set requires at least two issue_set items" }
        $seenSlugs = @{}
        $seenPlanFiles = @{}
        foreach ($issue in $issueSet) {
            Assert-IssueSpec -Issue $issue -TargetRepo $targetRepo -SourcePolicy $sourcePolicy -TargetRepoRoot $targetRepoRoot -SeenSlugs $seenSlugs -SeenPlanFiles $seenPlanFiles
        }
    }

    if ((As-Array $handoff.unresolved_decisions).Count -ne 0) {
        throw "material decisions remain unresolved; ask the next Plan Mode question with request_user_input"
    }

    $docEvidence = $handoff.doc_grill_evidence
    if (-not (Has-Field $docEvidence "docs_read") -or (As-Array $docEvidence.docs_read).Count -eq 0) {
        throw "doc_grill_evidence.docs_read must be non-empty"
    }
    if (-not (Has-Field $docEvidence "constraints_found") -or (As-Array $docEvidence.constraints_found).Count -eq 0) {
        throw "doc_grill_evidence.constraints_found must be non-empty"
    }
    if (-not (Has-Field $docEvidence "contradictions_found")) {
        throw "doc_grill_evidence.contradictions_found field is required"
    }
    if (-not (Has-Field $docEvidence "questions_derived") -or (As-Array $docEvidence.questions_derived).Count -eq 0) {
        throw "doc_grill_evidence.questions_derived must be non-empty"
    }

    $questions = @(As-Array $handoff.question_log)
    if ($questions.Count -eq 0) { throw "question_log must include request_user_input questions and answers" }
    $questionIds = @{}
    foreach ($question in $questions) {
        foreach ($field in @("id", "decision", "tool", "question", "answer", "source")) {
            if (-not (Has-Field $question $field) -or -not (Has-Text $question.$field)) {
                throw "question_log entries must include non-empty id, decision, tool, question, answer, and source"
            }
        }
        if ([string]$question.tool -ne "request_user_input") {
            throw "question_log entries must use request_user_input"
        }
        if ([string]$question.source -ne "user") {
            throw "question_log source must be user"
        }
        $questionIds[[string]$question.id] = $true
    }

    $canonicalQuestionId = [string]$canonicalScope.question_id
    if (-not $questionIds.ContainsKey($canonicalQuestionId)) {
        throw "canonical_issue_scope.question_id must match a request_user_input question_log entry"
    }
    $canonicalQuestion = @($questions | Where-Object { [string]$_.id -eq $canonicalQuestionId })[0]
    $canonicalQuestionText = (([string]$canonicalQuestion.question) + " " + ([string]$canonicalQuestion.decision)).ToLowerInvariant()
    if ($canonicalQuestionText -notmatch '(canonical|which part|selected slice|issue scope|idea slice|deferred|excluded)') {
        throw "canonical_issue_scope.question_id must reference the question that selected the canonical issue scope"
    }

    $decisions = @(As-Array $handoff.decision_log)
    if ($decisions.Count -eq 0) { throw "decision_log must be non-empty" }
    $decisionNames = @{}
    foreach ($decision in $decisions) {
        foreach ($field in @("decision", "status", "source")) {
            if (-not (Has-Field $decision $field) -or -not (Has-Text $decision.$field)) {
                throw "decision_log entries must include non-empty decision, status, and source"
            }
        }
        if ([string]$decision.source -match '^(agent default|default|assumption)$') {
            throw "decision_log source must not be agent default"
        }
        if ([string]$decision.status -notin @("locked", "discoverable")) {
            throw "decision_log status must be locked or discoverable"
        }
        $decisionNames[[string]$decision.decision] = $true
        $hasQuestionRef = (Has-Field $decision "question_id") -and (Has-Text $decision.question_id)
        $hasNoQuestionReason = (Has-Field $decision "no_question_needed_reason") -and (Has-Text $decision.no_question_needed_reason)
        if ($hasQuestionRef) {
            if ([string]$decision.status -ne "locked") {
                throw "decision_log entries with question_id must be locked"
            }
            if (-not $questionIds.ContainsKey([string]$decision.question_id)) {
                throw "decision_log question_id does not match question_log"
            }
        } elseif (-not $hasNoQuestionReason) {
            throw "decision_log entries must cite a request_user_input question_id or no_question_needed_reason"
        } elseif ([string]$decision.status -ne "discoverable") {
            throw "decision_log entries without question_id must be discoverable"
        }
    }
    foreach ($question in $questions) {
        if (-not $decisionNames.ContainsKey([string]$question.decision)) {
            throw "question_log decision does not match decision_log"
        }
    }
    $hasIssuePackagingQuestion = @($questions | Where-Object {
        $decisionText = ([string]$_.decision).ToLowerInvariant()
        $questionText = ([string]$_.question).ToLowerInvariant()
        ($decisionText -match '(issue|scope|decomposition).*(count|set|single|multiple|split|decompos)' -or
            $questionText -match '(one|single|multiple|several|split|decompos).*(issue|ticket)')
    }).Count -gt 0
    if (-not $hasIssuePackagingQuestion) {
        throw "question_log must include a request_user_input decision about single issue vs multiple issues"
    }
    if ([string]$handoff.issue_count_policy -eq "approved-issue-set") {
        $hasIssueSetMilestoneQuestion = @($questions | Where-Object {
            $decisionText = ([string]$_.decision).ToLowerInvariant()
            $questionText = ([string]$_.question).ToLowerInvariant()
            ($decisionText -match 'milestone' -or $questionText -match 'milestone')
        }).Count -gt 0
        if (-not $hasIssueSetMilestoneQuestion) {
            throw "approved-issue-set question_log must include milestone assignment or cross-milestone scope"
        }
    }

    foreach ($path in $candidateAllowedFiles) {
        $normalized = Normalize-Path ([string]$path)
        if ([IO.Path]::IsPathRooted([string]$path) -or $normalized -match '(^|/)\.\.(/|$)' -or [string]::IsNullOrWhiteSpace($normalized)) {
            throw "candidate_allowed_files must contain safe repo-relative paths or globs"
        }
    }

    $skillNames = @(As-Array $handoff.skills_used | ForEach-Object { [string]$_.skill })
    if (-not $AbstractStrategy -and $skillNames -notcontains "grill-with-docs") { throw "repo planning requires grill-with-docs evidence" }
    if ($AbstractStrategy -and $skillNames -notcontains "grill-me") { throw "abstract strategy requires grill-me evidence" }
    if ($VagueFeatureWork -and $skillNames -notcontains "superpowers:brainstorming") { throw "vague feature/design planning requires superpowers:brainstorming evidence" }
    if ($ArchitectureWork -and $skillNames -notcontains "improve-codebase-architecture") { throw "architecture/refactor planning requires improve-codebase-architecture evidence" }
    if ($BugOrFailureWork -and $skillNames -notcontains "diagnose") { throw "bug/failure planning requires diagnose evidence" }
    if ($LargeScope -and [string]$handoff.decomposition_policy -ne "approved-decompose") { throw "large scope requires explicit approved-decompose policy or a smaller single issue" }
    if ([string]$handoff.decomposition_policy -eq "approved-decompose" -and $skillNames -notcontains "to-issues") { throw "approved decomposition requires to-issues evidence" }

    Write-Result -Ok $true -Reason "planning handoff passed" -Evidence @{
        slug = $handoff.slug
        title = $handoff.title
        plan_file = $handoff.plan_file
        candidate_allowed_files = $handoff.candidate_allowed_files
        skills_used = $skillNames
        question_count = $questions.Count
        decision_count = $decisions.Count
    }
} catch {
    Write-Result -Ok $false -Reason $_.Exception.Message
}
