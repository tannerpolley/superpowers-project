[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path $scriptRoot -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$yamlFile = Join-Path $skillRoot "agents\openai.yaml"
. (Join-Path $scriptRoot "lib\contract.ps1")

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

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-FixtureRepo {
    $root = Join-Path ([IO.Path]::GetTempPath()) "implement-plan-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Force -Path (Join-Path $root "docs/superpowers/plans") | Out-Null
    Set-Content -LiteralPath (Join-Path $root "docs/superpowers/plans/plan.md") -Value "# Approved Plan" -Encoding utf8NoBOM
    $root
}

function New-HappyLedger {
    [pscustomobject]@{
        plan_path = "docs/superpowers/plans/plan.md"
        outcome_proof = [pscustomobject]@{
            intent = "Adopt outcome proofs"
            owner = "scripts/lib/outcome-proof.ps1"
            interface = "structured outcome_proof ledger object"
            cutover = "extend existing execution proof"
            replaced_path = "merge-ready proof without readiness review"
            acceptance_proof = "readiness review evidence is structured"
            stop_criteria = "block merge-ready when readiness review is missing"
            avoid = @("docs/goals route", "string-only contract proof")
        }
        readiness_review = [pscustomobject]@{
            plan_alignment = $true
            correctness = $true
            maintainability = $true
            reality_evidence = $true
        }
        native_goal = [pscustomobject]@{ activated = $true; command = "/goal Implement the approved plan." }
        branch = "codex/implement-approved-plan"
        topology = [pscustomobject]@{ question_id = "implement_plan_topology"; selected_mode = "inline" }
        verification = [pscustomobject]@{ passed = $true; commands = @("pwsh test") }
        push_permission = [pscustomobject]@{ question_id = "implement_plan_push_permission"; selected_action = "push-branch" }
        branch_push_proof = [pscustomobject]@{ source = "git push"; pushed = $true; remote = "origin"; branch = "codex/implement-approved-plan" }
        merge_ready = [pscustomobject]@{ ready = $true; route = "merge-changes"; mode = "local-branch" }
    }
}

$scenarios = @(
    Invoke-Scenario "skill frontmatter and metadata are valid" {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
        if (-not (Test-Path -LiteralPath $yamlFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        Assert-Contains $text "name: implement-plan" "missing skill name"
        Assert-Contains $text "# Implement Plan" "missing title"
        Assert-Contains $metadata "default_prompt:" "missing metadata default_prompt"
    }
    Invoke-Scenario "non-issue execution contract is present" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            'approved plan under `docs/superpowers/plans`',
            'does not create issue mirrors',
            'must not claim GitHub issue closure',
            'native `/goal` activation',
            'development branch',
            'request_user_input',
            'Auto Mode authorization ledger',
            'project_auto_mode_authorization',
            'the plugin-provided Auto Mode validator',
            'bounded-auto-merge',
            'recorded defaults',
            'preauthorized-after-clean-premerge',
            'stop outside policy',
            'implement_plan_topology',
            'superpowers:test-driven-development',
            'superpowers:executing-plans',
            'superpowers:verification-before-completion',
            'implement_plan_push_permission',
            'branch push proof',
            'merge-ready',
            'outcome proof',
            'readiness review',
            'local-branch',
            'open pull requests',
            'merge-changes'
        )) {
            Assert-Contains $text $needle "missing implement-plan contract: $needle"
            Assert-Contains $metadata $needle "missing implement-plan metadata: $needle"
        }
    }
    Invoke-Scenario "contract accepts happy ledger" {
        $repo = New-FixtureRepo
        $result = Test-ImplementPlanLedger -RepoRoot $repo -Ledger (New-HappyLedger)
        Assert-True ($result.ok -eq $true) "happy ledger should pass"
    }
    Invoke-Scenario "closeout artifact review and findings summary are explicit" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        foreach ($needle in @(
            "artifact review gate",
            "verification evidence",
            "broader project context",
            "recommended next route",
            "helper-required findings summary",
            "merge-ready drafts",
            "Do not ask for push approval first and explain later"
        )) {
            Assert-Contains $text $needle "missing implement-plan closeout contract: $needle"
        }
        foreach ($needle in @(
            "artifact review gate",
            "verification evidence",
            "broader project context",
            "recommended next route",
            "Do not ask for push approval first and explain later"
        )) {
            Assert-Contains $metadata $needle "missing implement-plan metadata closeout contract: $needle"
        }
    }
    Invoke-Scenario "native continuation policy avoids nested stop routes" {
        $text = Get-Content -LiteralPath $skillFile -Raw
        $metadata = Get-Content -LiteralPath $yamlFile -Raw
        $globalPolicyNeedles = @(
            "Nested Yes-route menus must not include terminal options",
            "Nested Revisit-route menus must not include terminal options",
            "Recommend Yes when at least one safe forward route exists",
            "Stop may be selectable at the top-level gate for user control, but the agent must not recommend Stop before verified final completion."
        )
        foreach ($needle in $globalPolicyNeedles) {
            if ($text.Contains($needle)) { throw "SKILL.md duplicates helper-owned global policy instead of compact contract reference: $needle" }
            if ($metadata.Contains($needle)) { throw "metadata duplicates native continuation policy instead of compact contract reference: $needle" }
        }
        foreach ($needle in @(
            "skills/advanced-user-input/SKILL.md",
            "global native question geometry",
            "route-specific question IDs",
            "selected answers are executable routing"
        )) {
            if (-not $text.Contains($needle)) { throw "missing compact native continuation helper reference: $needle" }
        }
        foreach ($needle in @(
            "implement_plan_topology",
            "implement_plan_push_permission"
        )) {
            if (-not $text.Contains($needle)) { throw "missing route-specific native continuation contract in SKILL.md: $needle" }
            if (-not $metadata.Contains($needle)) { throw "missing route-specific native continuation contract in metadata: $needle" }
        }
        foreach ($needle in @("Push And Open PR", "Hold")) {
            if (-not $metadata.Contains($needle)) { throw "missing route-specific native continuation contract in metadata: $needle" }
        }
        if (-not $metadata.Contains("docs/superpowers/workflow-contract.yml")) { throw "missing compact continuation metadata: docs/superpowers/workflow-contract.yml" }

        $questionIds = [regex]::Matches($text, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $text.Length }
            $block = $text.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: terminal option: break the continuation loop.')) {
                throw "nested question $questionId must not repeat stale terminal label"
            }
        }

        if ($metadata.Contains("Right terminal label")) { throw "metadata must not use old Right terminal label wording" }
    }
    Invoke-Scenario "contract rejects issue mirror and closure claims" {
        $repo = New-FixtureRepo
        $ledger = New-HappyLedger
        $ledger | Add-Member -NotePropertyName issue_mirror_path -NotePropertyValue "docs/superpowers/issues/1.md"
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "issue mirrors" }
        Assert-True $failed "issue mirror path should fail"

        $ledger = New-HappyLedger
        $ledger | Add-Member -NotePropertyName issue_closure_claim -NotePropertyValue $true
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "issue closure" }
        Assert-True $failed "issue closure claim should fail"
    }
    Invoke-Scenario "contract rejects missing outcome proof and review evidence" {
        $repo = New-FixtureRepo
        $ledger = New-HappyLedger
        $ledger.PSObject.Properties.Remove("outcome_proof")
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "outcome proof" }
        Assert-True $failed "missing outcome proof should fail"

        $ledger = New-HappyLedger
        $ledger.PSObject.Properties.Remove("readiness_review")
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "readiness review" }
        Assert-True $failed "missing readiness review should fail"

        $ledger = New-HappyLedger
        $ledger.readiness_review.reality_evidence = $false
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "reality_evidence" }
        Assert-True $failed "failed reality evidence review should fail"
    }
    Invoke-Scenario "contract rejects missing gates" {
        $repo = New-FixtureRepo
        $ledger = New-HappyLedger
        $ledger.native_goal.activated = $false
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "/goal" }
        Assert-True $failed "missing native goal proof should fail"

        $ledger = New-HappyLedger
        $ledger.branch = "main"
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "development branch" }
        Assert-True $failed "main branch should fail"

        $ledger = New-HappyLedger
        $ledger.verification.passed = $false
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "verification" }
        Assert-True $failed "failed verification should fail"

        $ledger = New-HappyLedger
        $ledger.PSObject.Properties.Remove("push_permission")
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "push permission" }
        Assert-True $failed "missing push permission should fail"

        $ledger = New-HappyLedger
        $ledger.branch_push_proof.pushed = $false
        $failed = $false
        try { Test-ImplementPlanLedger -RepoRoot $repo -Ledger $ledger | Out-Null } catch { $failed = $_.Exception.Message -match "branch push proof" }
        Assert-True $failed "branch push proof should fail when push is not confirmed"
    }
)

$failedScenarios = @($scenarios | Where-Object { -not $_.ok })
$scenarios | ConvertTo-Json -Depth 6
if ($failedScenarios.Count -gt 0) {
    throw "implement-plan scenario tests failed: $($failedScenarios.name -join ', ')"
}
