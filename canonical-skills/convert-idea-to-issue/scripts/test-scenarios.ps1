[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillDir = Split-Path $scriptRoot -Parent
$skillsRoot = Split-Path $skillDir -Parent
$userSkillsRoot = Join-Path $env:USERPROFILE ".agents\skills"
$validator = Join-Path $scriptRoot "validate-handoff.ps1"
$skillFile = Join-Path $skillDir "SKILL.md"

function Resolve-ExternalSkillFile {
    param([Parameter(Mandatory = $true)][string]$Name)
    foreach ($root in @($skillsRoot, $userSkillsRoot)) {
        $candidate = Join-Path $root "$Name\SKILL.md"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return (Join-Path $skillsRoot "$Name\SKILL.md")
}

$grillWithDocsFile = Resolve-ExternalSkillFile -Name "grill-with-docs"
$grillMeFile = Resolve-ExternalSkillFile -Name "grill-me"

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        [pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }
    } catch {
        [pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Run-Validator {
    param([hashtable]$Handoff, [string[]]$ExtraArgs = @())
    $json = ($Handoff | ConvertTo-Json -Depth 32 -Compress)
    $result = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -HandoffJson $json @ExtraArgs | ConvertFrom-Json
    $result
}

function Base-Handoff {
    @{
        slug = "solver-plan"
        target_repo = "example/repo"
        target_repo_root = "C:\work\repo"
        source_repo = "example/repo"
        issue_source_policy = "local-main-sync"
        title = "Plan solver behavior"
        outcome = "Solver behavior is specified and testable"
        issue_policy = "create"
        milestone_policy = "none"
        milestone_title = "none"
        full_roadmap = "none"
        full_roadmap_milestone_section = "none"
        project_policy = "dashboard-only"
        plan_file = "docs/issues/solver-plan.md"
        required_checks_policy = "require-existing"
        labels = @("type:feature")
        acceptance_criteria = @("- [ ] Solver behavior is documented")
        non_goals = @("No implementation in planning")
        proof_oracle = @("planned tests are named")
        candidate_allowed_files = @("src/solver/**", "tests/solver/**")
        issue_count_policy = "single-issue"
        decomposition_policy = "single-issue"
        doc_grill_evidence = @{
            docs_read = @("CONTEXT.md", "docs/adr/0001-solver-policy.md")
            constraints_found = @("Solver policy terms must match existing ADR language")
            contradictions_found = @()
            questions_derived = @("Should this become one issue or multiple issues?", "Which PR proof policy should this issue encode?")
        }
        decision_log = @(
            @{
                decision = "issue packaging"
                status = "locked"
                source = "user"
                question_id = "issue_packaging"
            },
            @{
                decision = "canonical issue scope"
                status = "locked"
                source = "user"
                question_id = "canonical_issue_scope"
            },
            @{
                decision = "default PR proof policy"
                status = "locked"
                source = "user"
                question_id = "pr_proof_policy"
            },
            @{
                decision = "candidate allowed files"
                status = "discoverable"
                source = "repo inspection"
                no_question_needed_reason = "The target files are named by the existing solver package and tests."
            }
        )
        question_log = @(
            @{
                id = "issue_packaging"
                decision = "issue packaging"
                tool = "request_user_input"
                question = "Should this be published as one issue or split into multiple issues?"
                answer = "Publish one issue."
                source = "user"
            },
            @{
                id = "canonical_issue_scope"
                decision = "canonical issue scope"
                tool = "request_user_input"
                question = "Which part of the idea should become the canonical GitHub issue now?"
                answer = "Publish the solver behavior planning slice and defer implementation cleanup."
                source = "user"
            },
            @{
                id = "pr_proof_policy"
                decision = "default PR proof policy"
                tool = "request_user_input"
                question = "What PR proof policy should this issue encode?"
                answer = "Require existing checks."
                source = "user"
            }
        )
        canonical_issue_scope = @{
            source = "docs/milestones/M0-governance/ideas/2026-06-01-solver-plan.md"
            selected_slice = "Solver behavior planning slice"
            included_scope = @("Document solver behavior requirements", "Name testable acceptance criteria")
            excluded_scope = @("Implementation cleanup is deferred", "Runtime solver changes are deferred")
            canonical_reason = "This is the smallest issue-sized slice that can be planned and verified independently."
            question_id = "canonical_issue_scope"
        }
        unresolved_decisions = @()
        execution_boundary = @{
            skill_scope = "issue-and-plan-publication-only"
            approval_meaning = "publish-issue-and-plan-only"
            implementation_skill = "resolve-issue-with-goal"
            allowed_after_approval = @(
                "repo-qualified GitHub issue create/update",
                "durable local issue file writes",
                "default-branch commit/push for local issue docs only"
            )
            forbidden_after_approval = @(
                "implementation branch creation",
                "implementation edits",
                "implementation commits",
                "implementation pushes",
                "PR creation",
                "merge",
                "GoalBuddy board",
                "native goal activation"
            )
        }
        skills_used = @(
            @{ skill = "grill-with-docs"; why = "repo terminology"; evidence = "CONTEXT.md and ADRs" }
        )
    }
}

$scenarios = @(
    Invoke-Scenario "happy path handoff passes" {
        $result = Run-Validator -Handoff (Base-Handoff)
        Assert-True $result.ok $result.reason
    }
    Invoke-Scenario "missing canonical issue scope blocks final plan" {
        $handoff = Base-Handoff
        $handoff.Remove("canonical_issue_scope")
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "canonical_issue_scope") "expected canonical_issue_scope missing failure"
    }
    Invoke-Scenario "canonical issue scope must reference request user input" {
        $handoff = Base-Handoff
        $handoff.canonical_issue_scope.question_id = "missing_question"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "canonical_issue_scope.question_id") "expected canonical question_id failure"
    }
    Invoke-Scenario "canonical issue scope question must select issue scope" {
        $handoff = Base-Handoff
        $handoff.canonical_issue_scope.question_id = "pr_proof_policy"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "canonical issue scope") "expected canonical scope question failure"
    }
    Invoke-Scenario "legacy docs ideas source blocks local sync" {
        $handoff = Base-Handoff
        $handoff.canonical_issue_scope.source = "docs/ideas/2026-06-01-solver-plan.md"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "legacy docs/ideas|docs/milestones") "expected legacy docs/ideas source failure"
    }
    Invoke-Scenario "non milestone idea source blocks local sync" {
        $handoff = Base-Handoff
        $handoff.canonical_issue_scope.source = "docs/roadmaps/solver-plan.md"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "source idea brief") "expected non milestone idea source failure"
    }
    Invoke-Scenario "missing grill-with-docs blocks repo planning" {
        $handoff = Base-Handoff
        $handoff.skills_used = @(@{ skill = "grill-me"; why = "abstract"; evidence = "conversation" })
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "grill-with-docs") "expected grill-with-docs failure"
    }
    Invoke-Scenario "architecture requires architecture skill" {
        $result = Run-Validator -Handoff (Base-Handoff) -ExtraArgs @("-ArchitectureWork")
        Assert-True (-not $result.ok -and $result.reason -match "improve-codebase-architecture") "expected architecture skill failure"
    }
    Invoke-Scenario "bug requires diagnose" {
        $result = Run-Validator -Handoff (Base-Handoff) -ExtraArgs @("-BugOrFailureWork")
        Assert-True (-not $result.ok -and $result.reason -match "diagnose") "expected diagnose failure"
    }
    Invoke-Scenario "large scope requires approved decomposition" {
        $result = Run-Validator -Handoff (Base-Handoff) -ExtraArgs @("-LargeScope")
        Assert-True (-not $result.ok -and $result.reason -match "approved-decompose") "expected decomposition failure"
    }
    Invoke-Scenario "approved decomposition requires to-issues" {
        $handoff = Base-Handoff
        $handoff.decomposition_policy = "approved-decompose"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "to-issues") "expected to-issues failure"
    }
    Invoke-Scenario "approved issue set can span milestones" {
        $handoff = Base-Handoff
        $handoff.issue_count_policy = "approved-issue-set"
        $handoff.decomposition_policy = "approved-decompose"
        $handoff.skills_used += @{ skill = "to-issues"; why = "approved issue set"; evidence = "user approved split across milestones" }
        $handoff.decision_log += @{
            decision = "issue set milestone assignment"
            status = "locked"
            source = "user"
            question_id = "issue_set_milestones"
        }
        $handoff.question_log[0].answer = "Split into multiple issues."
        $handoff.question_log += @{
            id = "issue_set_milestones"
            decision = "issue set milestone assignment"
            tool = "request_user_input"
            question = "Should the issue set stay in one milestone or span multiple milestones?"
            answer = "Span M0 - Governance and M1 - Packages."
            source = "user"
        }
        $handoff.issue_set = @(
            @{
                slug = "governance-gate"
                title = "Define governance gate"
                outcome = "Governance gate is documented and testable"
                issue_policy = "create"
                milestone_policy = "hard"
                milestone_title = "M0 - Governance"
                full_roadmap = "docs/roadmaps/FULL_ROADMAP.md"
                full_roadmap_milestone_section = "Milestones"
                plan_file = "docs/milestones/m0-governance/issues/governance-gate.md"
                required_checks_policy = "require-existing"
                labels = @("type:task")
                acceptance_criteria = @("- [ ] Governance gate is documented")
                non_goals = @("No package implementation")
                proof_oracle = @("docs gate reviewed")
                candidate_allowed_files = @("docs/**")
            },
            @{
                slug = "package-gate"
                title = "Define package gate"
                outcome = "Package gate is documented and testable"
                issue_policy = "create"
                milestone_policy = "hard"
                milestone_title = "M1 - Packages"
                full_roadmap = "docs/roadmaps/FULL_ROADMAP.md"
                full_roadmap_milestone_section = "Milestones"
                plan_file = "docs/milestones/m1-packages/issues/package-gate.md"
                required_checks_policy = "require-existing"
                labels = @("type:task")
                acceptance_criteria = @("- [ ] Package gate is documented")
                non_goals = @("No governance rewrite")
                proof_oracle = @("package gate reviewed")
                candidate_allowed_files = @("docs/**", "pyproject.toml")
            }
        )
        $result = Run-Validator -Handoff $handoff
        Assert-True $result.ok $result.reason
    }
    Invoke-Scenario "approved issue set requires issue_set items" {
        $handoff = Base-Handoff
        $handoff.issue_count_policy = "approved-issue-set"
        $handoff.decomposition_policy = "approved-decompose"
        $handoff.skills_used += @{ skill = "to-issues"; why = "approved issue set"; evidence = "user approved split" }
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "issue_set") "expected issue_set failure"
    }
    Invoke-Scenario "single milestone issue requires full roadmap" {
        $handoff = Base-Handoff
        $handoff.milestone_policy = "hard"
        $handoff.milestone_title = "M0 - Governance"
        $handoff.full_roadmap = "none"
        $handoff.full_roadmap_milestone_section = "Milestones"
        $handoff.plan_file = "docs/milestones/m0-governance/issues/solver-plan.md"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "full_roadmap is required") "expected top-level full_roadmap failure"
    }
    Invoke-Scenario "local milestone handoff rejects milestone heading as roadmap section" {
        $root = Join-Path ([IO.Path]::GetTempPath()) ("grill-plan-roadmap-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Path (Join-Path $root "docs\milestones") -Force | Out-Null
            @"
# Project Context

# 8. Required milestones

## M0 - Governance

Roadmap hygiene, tracker setup, labels, issue templates, completion rules, GoalBuddy/project discipline, and repo-wide process gates.

## M1 - Packages

Monorepo package layout, package ownership, test relocation, provider-only build proof, extension-native boundaries, and package CI/docs/release structure.
"@ | Set-Content -LiteralPath (Join-Path $root "docs\milestones\PROJECT_CONTEXT.md") -Encoding UTF8

            $handoff = Base-Handoff
            $handoff.target_repo_root = $root
            $handoff.milestone_policy = "hard"
            $handoff.milestone_title = "M0 - Governance"
            $handoff.full_roadmap = "docs/milestones/PROJECT_CONTEXT.md"
            $handoff.full_roadmap_milestone_section = "## M0 - Governance"
            $handoff.plan_file = "docs/milestones/m0-governance/issues/solver-plan.md"
            $result = Run-Validator -Handoff $handoff
            Assert-True (-not $result.ok -and $result.reason -match "not the milestone heading itself") "expected milestone heading section failure"

            $handoff.full_roadmap_milestone_section = "Required milestones"
            $result = Run-Validator -Handoff $handoff
            Assert-True $result.ok $result.reason
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    Invoke-Scenario "issue set milestone item requires full roadmap" {
        $handoff = Base-Handoff
        $handoff.issue_count_policy = "approved-issue-set"
        $handoff.decomposition_policy = "approved-decompose"
        $handoff.skills_used += @{ skill = "to-issues"; why = "approved issue set"; evidence = "user approved split across milestones" }
        $handoff.decision_log += @{
            decision = "issue set milestone assignment"
            status = "locked"
            source = "user"
            question_id = "issue_set_milestones"
        }
        $handoff.question_log[0].answer = "Split into multiple issues."
        $handoff.question_log += @{
            id = "issue_set_milestones"
            decision = "issue set milestone assignment"
            tool = "request_user_input"
            question = "Should the issue set stay in one milestone or span multiple milestones?"
            answer = "Span M0 - Governance and M1 - Packages."
            source = "user"
        }
        $handoff.issue_set = @(
            @{
                slug = "missing-roadmap"
                title = "Missing roadmap marker"
                outcome = "This should fail validation"
                issue_policy = "create"
                milestone_policy = "hard"
                milestone_title = "M0 - Governance"
                full_roadmap = "none"
                full_roadmap_milestone_section = "Milestones"
                plan_file = "docs/milestones/m0-governance/issues/missing-roadmap.md"
                required_checks_policy = "require-existing"
                labels = @("type:task")
                acceptance_criteria = @("- [ ] Roadmap is present")
                non_goals = @("No implementation")
                proof_oracle = @("docs reviewed")
                candidate_allowed_files = @("docs/**")
            },
            @{
                slug = "valid-roadmap"
                title = "Valid roadmap marker"
                outcome = "Second item keeps issue_set length valid"
                issue_policy = "create"
                milestone_policy = "hard"
                milestone_title = "M1 - Packages"
                full_roadmap = "docs/roadmaps/FULL_ROADMAP.md"
                full_roadmap_milestone_section = "Milestones"
                plan_file = "docs/milestones/m1-packages/issues/valid-roadmap.md"
                required_checks_policy = "require-existing"
                labels = @("type:task")
                acceptance_criteria = @("- [ ] Roadmap is present")
                non_goals = @("No implementation")
                proof_oracle = @("docs reviewed")
                candidate_allowed_files = @("docs/**")
            }
        )
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "issue_set full_roadmap is required") "expected issue_set full_roadmap failure"
    }
    Invoke-Scenario "approved issue set requires milestone question" {
        $handoff = Base-Handoff
        $handoff.issue_count_policy = "approved-issue-set"
        $handoff.decomposition_policy = "approved-decompose"
        $handoff.skills_used += @{ skill = "to-issues"; why = "approved issue set"; evidence = "user approved split" }
        $handoff.question_log[0].answer = "Split into multiple issues."
        $handoff.issue_set = @(
            @{
                slug = "first-slice"
                title = "First slice"
                outcome = "First slice planned"
                issue_policy = "create"
                milestone_policy = "none"
                milestone_title = "none"
                full_roadmap = "none"
                full_roadmap_milestone_section = "none"
                plan_file = "docs/issues/first-slice.md"
                required_checks_policy = "require-existing"
                labels = @("type:task")
                acceptance_criteria = @("- [ ] First slice planned")
                non_goals = @("No second slice")
                proof_oracle = @("first proof")
                candidate_allowed_files = @("src/first/**")
            },
            @{
                slug = "second-slice"
                title = "Second slice"
                outcome = "Second slice planned"
                issue_policy = "create"
                milestone_policy = "none"
                milestone_title = "none"
                full_roadmap = "none"
                full_roadmap_milestone_section = "none"
                plan_file = "docs/issues/second-slice.md"
                required_checks_policy = "require-existing"
                labels = @("type:task")
                acceptance_criteria = @("- [ ] Second slice planned")
                non_goals = @("No first slice")
                proof_oracle = @("second proof")
                candidate_allowed_files = @("src/second/**")
            }
        )
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "milestone assignment") "expected milestone question failure"
    }
    Invoke-Scenario "missing candidate files blocks fast execution marker" {
        $handoff = Base-Handoff
        $handoff.Remove("candidate_allowed_files")
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "candidate_allowed_files") "expected candidate_allowed_files failure"
    }
    Invoke-Scenario "branch policy in planning handoff blocks" {
        $handoff = Base-Handoff
        $handoff.branch_policy = "create"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "branch_policy") "expected branch_policy execution field failure"
    }
    Invoke-Scenario "external issue does not require local issue file" {
        $handoff = Base-Handoff
        $handoff.target_repo = "example/other"
        $handoff.source_repo = "example/repo"
        $handoff.issue_source_policy = "external-github-only"
        $handoff.target_repo_root = "external:none"
        $handoff.plan_file = "external:none"
        $handoff.candidate_allowed_files = @()
        $result = Run-Validator -Handoff $handoff
        Assert-True $result.ok $result.reason
    }
    Invoke-Scenario "external issue blocks local candidate files" {
        $handoff = Base-Handoff
        $handoff.target_repo = "example/other"
        $handoff.source_repo = "example/repo"
        $handoff.issue_source_policy = "external-github-only"
        $handoff.target_repo_root = "external:none"
        $handoff.plan_file = "external:none"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "candidate files") "expected external candidate file failure"
    }
    Invoke-Scenario "local sync requires own repo source" {
        $handoff = Base-Handoff
        $handoff.source_repo = "example/other"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "source_repo") "expected source_repo equality failure"
    }
    Invoke-Scenario "missing execution boundary blocks final plan" {
        $handoff = Base-Handoff
        $handoff.Remove("execution_boundary")
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "execution_boundary") "expected execution_boundary failure"
    }
    Invoke-Scenario "execution boundary must forbid implementation" {
        $handoff = Base-Handoff
        $handoff.execution_boundary.forbidden_after_approval = @("PR creation", "merge")
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "implementation branch creation") "expected implementation boundary failure"
    }
    Invoke-Scenario "missing doc grill evidence blocks final plan" {
        $handoff = Base-Handoff
        $handoff.Remove("doc_grill_evidence")
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "doc_grill_evidence") "expected doc_grill_evidence failure"
    }
    Invoke-Scenario "missing request user input question blocks final plan" {
        $handoff = Base-Handoff
        $handoff.question_log = @()
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "question_log") "expected question_log failure"
    }
    Invoke-Scenario "unresolved decisions block final plan" {
        $handoff = Base-Handoff
        $handoff.unresolved_decisions = @("default PR proof policy")
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "material decisions remain unresolved") "expected unresolved decision failure"
    }
    Invoke-Scenario "decision without question or discoverable reason blocks" {
        $handoff = Base-Handoff
        $handoff.decision_log = @(
            @{
                decision = "default PR proof policy"
                status = "locked"
                source = "repo inspection"
            }
        )
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "question_id or no_question_needed_reason") "expected decision proof failure"
    }
    Invoke-Scenario "agent default decision source blocks" {
        $handoff = Base-Handoff
        $handoff.decision_log = @(
            @{
                decision = "default PR proof policy"
                status = "discoverable"
                source = "agent default"
                no_question_needed_reason = "The agent guessed the default."
            }
        )
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "agent default") "expected agent default source failure"
    }
    Invoke-Scenario "question not tied to decision inventory blocks" {
        $handoff = Base-Handoff
        $handoff.question_log += @{
            id = "untracked_question"
            decision = "untracked decision"
            tool = "request_user_input"
            question = "What should happen?"
            answer = "Use the strict option."
            source = "user"
        }
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "decision_log") "expected question decision mismatch failure"
    }
    Invoke-Scenario "update issue URL must match target repo" {
        $handoff = Base-Handoff
        $handoff.issue_policy = "update:https://github.com/other/repo/issues/1"
        $result = Run-Validator -Handoff $handoff
        Assert-True (-not $result.ok -and $result.reason -match "target_repo") "expected target_repo mismatch failure"
    }
    Invoke-Scenario "skill text forbids execution ownership" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match "does not create branches") "missing branch prohibition"
        Assert-True ($text -match "Branch policy belongs to") "missing branch policy ownership rule"
        Assert-True ($text -match "local-main-sync") "missing local main sync policy"
        Assert-True ($text -match "external-github-only") "missing external issue source policy"
        Assert-True ($text -match "Externally sourced issue") "missing external source issue language"
        Assert-True ($text -match "commit and push") "missing local commit and push requirement"
        Assert-True ($text -match "Implement Plan") "missing Implement Plan boundary language"
        Assert-True ($text -match "issue-and-plan-publication-only") "missing issue-plan-only boundary"
        Assert-True ($text -match "Allowed mutations") "missing mutation allowlist"
        Assert-True ($text -notmatch '"branch_policy"') "planning skill must not include branch_policy in handoff or marker examples"
        Assert-True ($text -match "Do not run the execution skill") "missing execution handoff boundary"
        Assert-True ($text -match "resolve-issue-with-goal") "missing hidden execution marker"
        Assert-True ($text -match "target_repo") "missing explicit target repo contract"
        Assert-True ($text -match "--repo <target_repo>") "missing repo-qualified issue publication"
        Assert-True ($text -match "doc_grill_evidence") "missing doc grill evidence contract"
        Assert-True ($text -match "question_log") "missing question log contract"
        Assert-True ($text -match "unresolved_decisions") "missing unresolved decisions contract"
    }
    Invoke-Scenario "skill text supports default-mode canonical issue selection" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match "Fresh intake may run in Default mode or Plan mode") "missing Default mode intake contract"
        Assert-True ($text -match "Default mode is preferred") "missing Default mode preference for idea briefs"
        Assert-True ($text -match "canonical issue selection") "missing canonical issue selection contract"
        Assert-True ($text -match "canonical_issue_scope") "missing canonical_issue_scope handoff field"
        Assert-True ($text -match "final native approval question") "missing Default mode publish approval gate"
    }
    Invoke-Scenario "skill text requires bundled script resolution" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match [regex]::Escape("C:\Users\Tanner\.agents\skills\convert-idea-to-issue\scripts\")) "missing explicit bundled script directory"
        Assert-True ($text -match "Target repositories must not be required to contain") "missing repo-local script prohibition"
        Assert-True ($text -match [regex]::Escape('bundled `scripts\repo-gate.ps1 -RepoRoot <target-repo-root> -ExpectedRemoteSlug <target_repo>`')) "missing explicit repo-gate invocation"
    }
    Invoke-Scenario "nested grill skills allow batched questions" {
        foreach ($path in @($grillWithDocsFile, $grillMeFile)) {
            Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "missing nested grill skill: $path"
            $text = Get-Content -LiteralPath $path -Raw
            Assert-True ($text -notmatch "Ask the questions one at a time") "nested grill skill still forces one-at-a-time questions: $path"
            Assert-True ($text -match "Batch independent questions together") "nested grill skill does not require batched independent questions: $path"
            Assert-True ($text -match "request_user_input") "nested grill skill does not mention request_user_input: $path"
        }
    }
)

$failed = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
