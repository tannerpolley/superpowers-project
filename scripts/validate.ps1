[CmdletBinding()]
param(
    [switch]$SkipScenarioTests,
    [ValidateRange(1, 3600)][int]$ScenarioTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$skillRoot = Join-Path $repoRoot "canonical-skills"
$pluginSkillRoot = Join-Path $repoRoot "skills"
$pluginRoot = $repoRoot
$quickValidate = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
$pluginValidate = Join-Path $env:USERPROFILE ".codex\skills\.system\plugin-creator\scripts\validate_plugin.py"

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
    @(
        "superpowers-project",
        "project-context",
        "project-brainstorm",
        "project-writing-plan",
        "plan-to-issue",
        "resolve-issue-with-goal",
        "project-doctor"
    )
}
function Test-PluginWrapperContracts {
    $activeNames = @(Get-ActiveSkillNames)
    $canonicalNames = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)
    $wrapperNames = @(Get-ChildItem -LiteralPath $pluginSkillRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)

    $missingCanonical = @($activeNames | Where-Object { $canonicalNames -notcontains $_ })
    $extraCanonical = @($canonicalNames | Where-Object { $activeNames -notcontains $_ })
    if ($missingCanonical.Count -gt 0) { throw "missing active canonical skill(s): $($missingCanonical -join ', ')" }
    if ($extraCanonical.Count -gt 0) { throw "unexpected canonical skill(s): $($extraCanonical -join ', ')" }

    $missingWrappers = @($activeNames | Where-Object { $wrapperNames -notcontains $_ })
    $extraWrappers = @($wrapperNames | Where-Object { $activeNames -notcontains $_ })
    if ($missingWrappers.Count -gt 0) { throw "missing plugin wrapper(s): $($missingWrappers -join ', ')" }
    if ($extraWrappers.Count -gt 0) { throw "unexpected plugin wrapper(s): $($extraWrappers -join ', ')" }

    foreach ($name in $activeNames) {
        $wrapperPath = Join-Path $pluginSkillRoot "$name\SKILL.md"
        if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
            throw "missing wrapper SKILL.md: $wrapperPath"
        }
        $text = Get-Content -LiteralPath $wrapperPath -Raw
        Assert-TextContains -Text $text -Needle "name: $name" -Path $wrapperPath -Reason "missing wrapper name"
        Assert-TextContains -Text $text -Needle "namespace wrapper" -Path $wrapperPath -Reason "missing namespace wrapper contract"
        Assert-TextContains -Text $text -Needle "C:\Users\Tanner\.agents\skills\$name\SKILL.md" -Path $wrapperPath -Reason "missing deployed user skill path"
        Assert-TextContains -Text $text -Needle 'Read the deployed user-level `SKILL.md` above.' -Path $wrapperPath -Reason "missing deployed read instruction"
        Assert-TextContains -Text $text -Needle "Follow that skill exactly." -Path $wrapperPath -Reason "missing follow instruction"
        Assert-TextContains -Text $text -Needle "do not invent separate behavior" -Path $wrapperPath -Reason "missing no separate behavior rule"
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
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
        throw "missing canonical-skills directory"
    }
    if (-not (Test-Path -LiteralPath $pluginSkillRoot -PathType Container)) {
        throw "missing plugin wrapper skills directory"
    }

    $results.Add((Invoke-Step "Plugin wrapper source contract" {
        Test-PluginWrapperContracts
    }))
    $results.Add((Invoke-Step "Superpowers project path contract" {
        Test-SuperpowersProjectPathContract
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
        $pluginSkillRoot,
        (Join-Path $repoRoot "docs"),
        (Join-Path $repoRoot ".codex-plugin"),
        (Join-Path $repoRoot "README.md"),
        (Join-Path $repoRoot "AGENTS.md"),
        (Join-Path $repoRoot "CHANGELOG.md")
    )
    $stale = @(rg -n "plan-goal-implement-merge|setup-project-roadmap|setup_project_roadmap_plan|grill-plan-to-issue|issue-goal-execute-merge|docs/ideas/<YYYY|docs/ideas/20|cross-milestone.*docs/ideas|docs/ideas.*cross-milestone" @scanRoots 2>$null)
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
