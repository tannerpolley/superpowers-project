[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path (Split-Path $skillRoot -Parent) -Parent
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $skillRoot "agents\openai.yaml"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Name, [bool]$Ok, [string]$Reason) $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason }) }
function Assert-Contains { param([string]$Text, [string]$Needle, [string]$Reason) if (-not $Text.Contains($Needle)) { throw $Reason } }

try {
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "missing SKILL.md" }
    if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) { throw "missing agents/openai.yaml" }
    $skill = Get-Content -LiteralPath $skillFile -Raw
    $metadata = Get-Content -LiteralPath $metadataFile -Raw

    try {
        foreach ($needle in @('docs/superpowers/PROJECT_CONTEXT.md','docs/superpowers/milestones','request_user_input','Project Context Shape','Milestone page shape','GitHub tracker config','/goal','Superpowers Project')) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing setup contract: $needle"
        }
        Add-Result -Name "project setup contract present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "project setup contract present" -Ok $false -Reason $_.Exception.Message }

    try {
        foreach ($needle in @(
            'flat canonical roots',
            'spec -> plan -> issue',
            'docs/superpowers/specs',
            'docs/superpowers/plans',
            'docs/superpowers/issues',
            'Milestone pages are index views',
            'frontmatter plus milestone indexes',
            'nested canonical milestone artifact folders are drift'
        )) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing flat artifact root contract: $needle"
        }
        foreach ($needle in @(
            'flat canonical roots',
            'Milestone pages are index views',
            'frontmatter plus milestone indexes'
        )) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing flat artifact root contract: $needle"
        }
        Add-Result -Name "flat artifact root contract is present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "flat artifact root contract is present" -Ok $false -Reason $_.Exception.Message }

    try {
        Assert-Contains -Text $metadata -Needle 'setup' -Reason "metadata missing skill name"
        Assert-Contains -Text $metadata -Needle 'docs/superpowers/PROJECT_CONTEXT.md' -Reason "metadata missing project context path"
        foreach ($needle in @('summarize','project_setup_next_step','Brainstorm New Spec','Write Plan','Create Issues','Run Doctor','Stop','start the selected next skill')) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing continuation route: $needle"
        }
        Add-Result -Name "metadata present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "metadata present" -Ok $false -Reason $_.Exception.Message }

    try {
        foreach ($needle in @(
            '## Native Continuation Gate',
            'artifact review gate',
            'what the agent thinks those results mean',
            'machine-readable artifacts',
            'broader project context',
            'recommended next route',
            'Review Setup',
            'stop',
            'request_user_input',
            'start the selected next skill',
            'project_setup_next_step',
            'Brainstorm New Spec',
            'Write Plan',
            'Create Issues',
            'Run Doctor',
            'Stop'
        )) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing continuation gate text: $needle"
        }
        Add-Result -Name "native continuation gate is present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "native continuation gate is present" -Ok $false -Reason $_.Exception.Message }

    try {
        foreach ($needle in @(
            'artifact review gate',
            'what the agent thinks those results mean',
            'machine-readable artifacts',
            'broader project context',
            'recommended next route'
        )) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing closeout artifact-review contract: $needle"
        }
        Add-Result -Name "setup closeout artifact review contract is present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "setup closeout artifact review contract is present" -Ok $false -Reason $_.Exception.Message }

    try {
        if ($skill.Contains("Use Existing Artifact")) { throw "setup skill must not use 'Use Existing Artifact'" }
        if ($skill.Contains("project_setup_existing_artifact_route")) { throw "setup skill must not keep the existing-artifact route" }
        if ($metadata.Contains("existing-artifact")) { throw "setup metadata must not keep existing-artifact wording" }
        Add-Result -Name "setup workflow labels avoid artifact jargon" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "setup workflow labels avoid artifact jargon" -Ok $false -Reason $_.Exception.Message }

    try {
        foreach ($needle in @(
            'GitHub Project Board Setup',
            'project_setup_board_approval',
            'Create Board',
            'Verify Only',
            'docs/agents/project-roadmap.json',
            '-Mode Create',
            'NativeApprovalJson'
        )) {
            Assert-Contains -Text $skill -Needle $needle -Reason "missing board setup contract: $needle"
        }
        foreach ($needle in @('GitHub Project board setup','board creation','project_setup_next_step')) {
            Assert-Contains -Text $metadata -Needle $needle -Reason "metadata missing board setup contract: $needle"
        }
        Add-Result -Name "github project board setup contract is present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "github project board setup contract is present" -Ok $false -Reason $_.Exception.Message }

    try {
        $planRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "prepare-github-project-board.ps1") -RepoRoot $repoRoot -Mode Plan -BoardTitle "Milestones Plugin"
        if ($LASTEXITCODE -ne 0) { throw ($planRaw | Out-String) }
        $plan = ($planRaw | Out-String) | ConvertFrom-Json
        if (-not $plan.ok) { throw $plan.reason }
        if ($plan.evidence.native_question_id -ne "project_setup_board_approval") { throw "board plan missing native approval question" }
        if ($plan.evidence.mutation_allowed_without_native_approval -ne $false) { throw "board plan must block mutation without native approval" }
        if ($plan.evidence.PSObject.Properties.Name -notcontains "native_issue_types") { throw "board plan missing native issue type evidence" }
        $config = @{
            repository = "tannerpolley/superpowers-project"
            board_title = "Milestones Plugin"
            project_url = "https://github.com/orgs/tannerpolley/projects/1"
            fields = @("Status", "Milestone", "Issue Type")
            native_approval = @{ source = "request_user_input"; question_id = "project_setup_board_approval"; selected_action = "verify" }
        } | ConvertTo-Json -Depth 12 -Compress
        $validatedRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "prepare-github-project-board.ps1") -RepoRoot $repoRoot -Mode ValidateConfig -BoardConfigJson $config
        if ($LASTEXITCODE -ne 0) { throw ($validatedRaw | Out-String) }
        $validated = ($validatedRaw | Out-String) | ConvertFrom-Json
        if (-not $validated.ok) { throw $validated.reason }
        Add-Result -Name "github project board preparation script passes" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "github project board preparation script passes" -Ok $false -Reason $_.Exception.Message }

    try {
        $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("setup-native-issue-types-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        try {
            $enabledFixture = Join-Path $fixtureRoot "enabled-issue-types.json"
            @{
                issueTypes = @{
                    nodes = @(
                        @{ id = "IT_TASK"; name = "Task"; isEnabled = $true },
                        @{ id = "IT_BUG"; name = "Bug"; isEnabled = $true },
                        @{ id = "IT_FEATURE"; name = "Feature"; isEnabled = $true }
                    )
                }
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $enabledFixture -Encoding utf8NoBOM
            $enabledRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "prepare-github-project-board.ps1") -RepoRoot $repoRoot -Mode Plan -IssueTypeFixturePath $enabledFixture
            if ($LASTEXITCODE -ne 0) { throw ($enabledRaw | Out-String) }
            $enabled = ($enabledRaw | Out-String) | ConvertFrom-Json
            if (-not $enabled.ok) { throw $enabled.reason }
            if ($enabled.evidence.native_issue_types.available -ne $true) { throw "enabled native issue types were not detected" }
            $enabledNames = @($enabled.evidence.native_issue_types.names | ForEach-Object { [string]$_ })
            foreach ($name in @("Task", "Bug", "Feature")) {
                if ($enabledNames -notcontains $name) { throw "missing native issue type in plan evidence: $name" }
            }

            $disabledFixture = Join-Path $fixtureRoot "disabled-issue-types.json"
            @{ issueTypes = @{ nodes = @() } } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $disabledFixture -Encoding utf8NoBOM
            $disabledRaw = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "prepare-github-project-board.ps1") -RepoRoot $repoRoot -Mode Plan -IssueTypeFixturePath $disabledFixture
            if ($LASTEXITCODE -ne 0) { throw ($disabledRaw | Out-String) }
            $disabled = ($disabledRaw | Out-String) | ConvertFrom-Json
            if (-not $disabled.ok) { throw $disabled.reason }
            if ($disabled.evidence.native_issue_types.available -ne $false) { throw "disabled native issue types should report unavailable" }
            Assert-Contains -Text ([string]$disabled.evidence.native_issue_types.label_only_reason) -Needle "no enabled native issue types" -Reason "label-only reason missing"
        } finally {
            if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
        }
        Add-Result -Name "github native issue type planning contract passes" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "github native issue type planning contract passes" -Ok $false -Reason $_.Exception.Message }

    try {
        $scriptText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "prepare-github-project-board.ps1") -Raw
        foreach ($needle in @('ValidateSet("Plan", "ValidateConfig", "Create")', "NativeApprovalJson", "project_setup_board_approval", "project field-create", "project item-add", "github_project_board", "repository.issueTypes", "UpdateIssueInput.issueTypeId", "issueTypeId", "label-only")) {
            Assert-Contains -Text $scriptText -Needle $needle -Reason "board create script missing contract: $needle"
        }
        Add-Result -Name "github project board create mode contract is present" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "github project board create mode contract is present" -Ok $false -Reason $_.Exception.Message }

    
    try {
        foreach ($needle in @(
            "Nested Yes-route menus must not include Stop / Done",
            "Nested Revisit-route menus must not include Stop / Done",
            "Recommend Yes when at least one safe forward route exists",
            "Recommend Stop only for explicit mid-loop terminal or blocker states. Recommend Done only at a verified final Done gate."
        )) {
            if (-not $skill.Contains($needle)) { throw "missing native continuation policy in SKILL.md: $needle" }
            if (-not $metadata.Contains($needle)) { throw "missing native continuation policy in metadata: $needle" }
        }

        $questionIds = [regex]::Matches($skill, 'Question id:\s*`([^`]+)`')
        for ($index = 0; $index -lt $questionIds.Count; $index++) {
            $current = $questionIds[$index]
            $nextStart = if ($index + 1 -lt $questionIds.Count) { $questionIds[$index + 1].Index } else { $skill.Length }
            $block = $skill.Substring($current.Index, $nextStart - $current.Index)
            $questionId = $current.Groups[1].Value
            if ($questionId.EndsWith("_next_step")) { continue }
            if ($block.Contains('Right: `Stop / Done`: break the continuation loop.')) { throw "nested question $questionId must not repeat Stop / Done" }
        }
        if ($metadata.Contains("Right Stop / Done")) { throw "metadata must not use old Right Stop / Done wording" }
        Add-Result -Name "native continuation policy avoids nested stop routes" -Ok $true -Reason "passed"
    } catch { Add-Result -Name "native continuation policy avoids nested stop routes" -Ok $false -Reason $_.Exception.Message }
$failed = @($results | Where-Object { -not $_.ok })
    $results | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Result -Name "fatal" -Ok $false -Reason $_.Exception.Message
    $results | ConvertTo-Json -Depth 8
    exit 1
}

