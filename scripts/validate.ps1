[CmdletBinding()]
param(
    [switch]$SkipScenarioTests,
    [ValidateRange(1, 3600)][int]$ScenarioTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$skillRoot = Join-Path $repoRoot "skills"
$retiredCanonicalSkillRoot = Join-Path $repoRoot "canonical-skills"
$pluginRoot = $repoRoot
$quickValidate = Join-Path $PSScriptRoot "quick-validate-skill.py"
$pluginValidate = Join-Path $PSScriptRoot "validate-plugin.py"
. (Join-Path $PSScriptRoot "lib\project-skills.ps1")

function Resolve-PythonForValidators {
    $candidates = @(
        @{ command = "py"; prefix = @("-3.12"); label = "py -3.12" },
        @{ command = "python"; prefix = @(); label = "python" }
    )
    foreach ($candidate in $candidates) {
        try {
            & $candidate.command @($candidate.prefix) -c "import yaml" 2>$null
            if ($LASTEXITCODE -eq 0) { return $candidate }
        } catch {
            continue
        }
    }
    throw "no Python interpreter with PyYAML found; expected py -3.12 or python to import yaml"
}

function Invoke-ValidatorPython {
    param(
        [Parameter(Mandatory = $true)]$Python,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    & $Python.command @($Python.prefix) @Arguments
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Body
    )
    & $Body
    [pscustomobject]@{ name = $Name; ok = $true }
}

function Invoke-PwshFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Arguments = @(),
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 600
    )

    $captureRoot = Join-Path ([IO.Path]::GetTempPath()) ("milestones-validate-" + [guid]::NewGuid().ToString("N"))
    $stdoutPath = Join-Path $captureRoot "stdout.txt"
    $stderrPath = Join-Path $captureRoot "stderr.txt"
    try {
        New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
        $process = Start-Process -FilePath "pwsh.exe" `
            -ArgumentList (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Path) + $Arguments) `
            -WorkingDirectory $repoRoot `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -PassThru `
            -WindowStyle Hidden

        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try {
                $process.Kill($true)
            } catch {
                if (-not $process.HasExited) { throw }
            }
            $process.WaitForExit()
            return [pscustomobject]@{
                ExitCode = 124
                Stdout = if (Test-Path -LiteralPath $stdoutPath) { (Get-Content -LiteralPath $stdoutPath -Raw) -replace "(\r?\n)+$", "" } else { "" }
                Stderr = "PowerShell script timed out after $TimeoutSeconds seconds: $Path"
                TimedOut = $true
            }
        }

        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = if (Test-Path -LiteralPath $stdoutPath) { (Get-Content -LiteralPath $stdoutPath -Raw) -replace "(\r?\n)+$", "" } else { "" }
            Stderr = if (Test-Path -LiteralPath $stderrPath) { (Get-Content -LiteralPath $stderrPath -Raw) -replace "(\r?\n)+$", "" } else { "" }
            TimedOut = $false
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        if ($process) { $process.Dispose() }
        if (Test-Path -LiteralPath $captureRoot) {
            $resolvedCapture = [IO.Path]::GetFullPath($captureRoot)
            $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            if ($resolvedCapture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedCapture -Recurse -Force
            }
        }
    }
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Reason
    )
    if (-not $Text.Contains($Needle)) {
        throw "$Reason in $Path"
    }
}

function Get-ActiveSkillNames {
    @(Get-ProjectActiveSkillNames -RepoRoot $repoRoot)
}
function Test-SkillSourceContracts {
    $activeNames = @(Get-ActiveSkillNames)
    $skillNames = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)

    $missingSkills = @($activeNames | Where-Object { $skillNames -notcontains $_ })
    $extraSkills = @($skillNames | Where-Object { $activeNames -notcontains $_ })
    if ($missingSkills.Count -gt 0) { throw "missing active skill(s): $($missingSkills -join ', ')" }
    if ($extraSkills.Count -gt 0) { throw "unexpected skill(s): $($extraSkills -join ', ')" }

    if (Test-Path -LiteralPath $retiredCanonicalSkillRoot -PathType Container) {
        throw "canonical-skills is retired; skills must be the single source root"
    }
    foreach ($name in $activeNames) {
        $skillPath = Join-Path $skillRoot "$name\SKILL.md"
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
            throw "missing skill SKILL.md: $skillPath"
        }
        $text = Get-Content -LiteralPath $skillPath -Raw
        Assert-TextContains -Text $text -Needle "name: $name" -Path $skillPath -Reason "missing skill name"
        if ($text.Contains("namespace wrapper") -or $text.Contains('Read the deployed user-level `SKILL.md` above.') -or $text.Contains("do not invent separate behavior")) {
            throw "skills must contain full implementations, not namespace wrappers: $skillPath"
        }
    }
}
function Test-SuperpowersProjectPathContract {
    $projectSkillNames = @(Get-ActiveSkillNames)
    $forbiddenPatterns = @(
        "docs/milestones/<milestone-folder>/ideas",
        "docs/milestones/<milestone-folder>/issues",
        "docs/plans",
        "docs/issues"
    )

    foreach ($name in $projectSkillNames) {
        $skillPath = Join-Path $skillRoot "$name\SKILL.md"
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { continue }
        $text = Get-Content -LiteralPath $skillPath -Raw
        foreach ($pattern in $forbiddenPatterns) {
            if ($text.Contains($pattern)) {
                throw "active Superpowers Project skill uses retired canonical path '$pattern': $skillPath"
            }
        }
    }
}

$results = [System.Collections.Generic.List[object]]::new()

try {
    $validatorPython = Resolve-PythonForValidators

    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot ".codex-plugin\plugin.json") -PathType Leaf)) {
        throw "missing .codex-plugin/plugin.json"
    }
    if (Test-Path -LiteralPath $retiredCanonicalSkillRoot -PathType Container) {
        throw "canonical-skills directory is retired"
    }
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
        throw "missing skills directory"
    }

    $results.Add((Invoke-Step "Skill source contract" {
        Test-SkillSourceContracts
    }))
    $results.Add((Invoke-Step "Superpowers project path contract" {
        Test-SuperpowersProjectPathContract
    }))

    $results.Add((Invoke-Step "Native Q&A SVG contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-native-qa-svg.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Native Q&A SVG contract failed" }
    }))

    $results.Add((Invoke-Step "Native continuation loop contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-native-continuation-loop.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Native continuation loop contract failed" }
    }))

    $results.Add((Invoke-Step "Global policy deduplication contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-global-policy-deduplication.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Global policy deduplication contract failed" }
    }))

    $results.Add((Invoke-Step "Advanced user input policy contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-advanced-user-input-policy.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Advanced user input policy contract failed" }
    }))

    $results.Add((Invoke-Step "Companion interface contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-companion-interface.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Companion interface contract failed" }
    }))

    $results.Add((Invoke-Step "Agent-Native companion preview" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-agent-native-companion-preview.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Agent-Native companion preview failed" }
    }))

    $results.Add((Invoke-Step "Skill metadata readability contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-skill-metadata-readability.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Skill metadata readability contract failed" }
    }))

    $results.Add((Invoke-Step "Skill metadata workflow contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-skill-metadata-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Skill metadata contract tests failed" }
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-skill-metadata-contract.ps1") -RepoRoot $repoRoot | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Skill metadata workflow contract failed" }
    }))

    $results.Add((Invoke-Step "Superpowers method contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-superpowers-method-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Superpowers method contract failed" }
    }))

    $results.Add((Invoke-Step "Auto Mode authorization contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-auto-mode-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Auto Mode authorization contract failed" }
    }))

    $results.Add((Invoke-Step "Loop Controller contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-loop-controller.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Loop Controller contract failed" }
    }))

    $results.Add((Invoke-Step "Active backlog candidate signal" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-active-backlog.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Active backlog tests failed" }
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-active-backlog.ps1") -RepoRoot $repoRoot | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Active backlog validator failed" }
    }))

    $results.Add((Invoke-Step "Workflow mode entry contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-initiate-workflow-mode-gate.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Workflow mode entry contract failed" }
    }))

    $results.Add((Invoke-Step "Workflow mode ledger validator" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-workflow-mode-ledger.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Workflow mode ledger validator failed" }
    }))

    $results.Add((Invoke-Step "Workflow contract registry" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-workflow-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Workflow contract registry failed" }
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-workflow-contract.ps1") -RepoRoot $repoRoot | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Workflow contract validator failed" }
    }))

    $results.Add((Invoke-Step "Outcome workflow summary generation" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-outcome-workflow-summary.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Outcome workflow summary generation failed" }
    }))

    $results.Add((Invoke-Step "Stale skill contract detector" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-stale-skill-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Stale skill contract detector failed" }
    }))

    $results.Add((Invoke-Step "Release preparation receipt" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-prepare-release.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Release preparation receipt failed" }
    }))

    $results.Add((Invoke-Step "Agent plugin version tracker" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-agent-plugin-version.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Agent plugin version tracker failed" }
    }))

    $results.Add((Invoke-Step "Plan task use cases" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-plan-task-use-cases.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Plan task use cases failed" }
    }))

    $results.Add((Invoke-Step "Plan outcome proof" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-plan-outcome-proof.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Plan outcome proof failed" }
    }))

    $results.Add((Invoke-Step "Decision Ledger contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-decision-ledger.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Decision Ledger contract failed" }
    }))

    $results.Add((Invoke-Step "Local project workflow smoke" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-e2e-project-workflow.ps1") -LocalOnly | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Local project workflow smoke failed" }
    }))

    $results.Add((Invoke-Step "PowerShell parser check" {
        $scripts = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter "*.ps1")
        foreach ($script in $scripts) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            if ($errors.Count -gt 0) {
                throw "PowerShell parse failed for $($script.FullName): $($errors[0].Message)"
            }
        }
    }))

    $results.Add((Invoke-Step "sync-live helper tests" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-sync-live.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "sync-live helper tests failed" }
    }))

    $results.Add((Invoke-Step "project namespace migration tests" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-project-namespace-migration.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "project namespace migration tests failed" }
    }))

    $results.Add((Invoke-Step "plugin-only live sync tests" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-plugin-only-live-sync.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "plugin-only live sync tests failed" }
    }))

    $results.Add((Invoke-Step "superpowers project dummy repo" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-superpowers-project-dummy-repo.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "superpowers project dummy repo failed" }
    }))

    $results.Add((Invoke-Step "superpowers project repo contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-superpowers-project-repo-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "superpowers project repo contract failed" }
    }))
    $results.Add((Invoke-Step "GitHub check normalization tests" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-github-checks.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "GitHub check normalization tests failed" }
    }))

    $results.Add((Invoke-Step "skill script parameter contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-skill-script-contract.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "skill script parameter contract failed" }
    }))

    $results.Add((Invoke-Step "flat artifact root contract" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-flat-artifact-roots.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "flat artifact root contract failed" }
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-flat-artifact-roots.ps1") -RepoRoot $repoRoot | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "flat artifact root validator failed" }
    }))

    $results.Add((Invoke-Step "generated runtime state guardrails" {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test-generated-state.ps1") | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "generated runtime state guardrails failed" }
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate-generated-state.ps1") -RepoRoot $repoRoot | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "generated runtime state validator failed" }
    }))

    $results.Add((Invoke-Step "Plugin manifest validation" {
        if (-not (Test-Path -LiteralPath $pluginValidate -PathType Leaf)) {
            throw "plugin validator not found: $pluginValidate"
        }
        Invoke-ValidatorPython -Python $validatorPython -Arguments @($pluginValidate, $pluginRoot) | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "plugin validation failed" }
    }))

    $skillDirs = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Sort-Object Name)
    foreach ($skill in $skillDirs) {
        $results.Add((Invoke-Step "quick_validate $($skill.Name)" {
            if (-not (Test-Path -LiteralPath $quickValidate -PathType Leaf)) {
                throw "skill validator not found: $quickValidate"
            }
            Invoke-ValidatorPython -Python $validatorPython -Arguments @($quickValidate, $skill.FullName) | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "quick_validate failed for $($skill.Name)" }
        }))
    }

    if (-not $SkipScenarioTests) {
        foreach ($skill in $skillDirs) {
            $scenarioScript = Join-Path $skill.FullName "scripts\test-scenarios.ps1"
            if (Test-Path -LiteralPath $scenarioScript -PathType Leaf) {
                $results.Add((Invoke-Step "scenario tests $($skill.Name)" {
                    $scenarioResult = Invoke-PwshFile -Path $scenarioScript -TimeoutSeconds $ScenarioTimeoutSeconds
                    if (-not [string]::IsNullOrWhiteSpace($scenarioResult.Stdout)) { $scenarioResult.Stdout | Out-Host }
                    if (-not [string]::IsNullOrWhiteSpace($scenarioResult.Stderr)) { $scenarioResult.Stderr | Out-Host }
                    if ($scenarioResult.TimedOut) { throw "scenario tests timed out for $($skill.Name)" }
                    if ($scenarioResult.ExitCode -ne 0) { throw "scenario tests failed for $($skill.Name)" }
                }))
            }
        }
    }

    $scanRoots = @(
        $skillRoot,
        (Join-Path $repoRoot "docs"),
        (Join-Path $repoRoot ".codex-plugin"),
        (Join-Path $repoRoot "README.md"),
        (Join-Path $repoRoot "AGENTS.md"),
        (Join-Path $repoRoot "CHANGELOG.md")
    )
    $stale = @(rg -n "plan-goal-implement-merge|setup-project-roadmap|setup_project_roadmap_plan|grill-create-issues|issue-goal-execute-merge|docs/ideas/<YYYY|docs/ideas/20|cross-milestone.*docs/ideas|docs/ideas.*cross-milestone" @scanRoots 2>$null)
    $allowedNegativeFixture = "skills\convert-idea-to-issue\scripts\test-scenarios.ps1"
    $unexpected = @($stale | Where-Object { $_ -notmatch [regex]::Escape($allowedNegativeFixture) })
    if ($unexpected.Count -gt 0) {
        throw "unexpected stale references: $($unexpected -join '; ')"
    }

    [pscustomobject]@{
        ok = $true
        repo_root = $repoRoot
        checks = $results
    } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{
        ok = $false
        repo_root = $repoRoot
        reason = $_.Exception.Message
        checks = $results
    } | ConvertTo-Json -Depth 8
    exit 1
}
