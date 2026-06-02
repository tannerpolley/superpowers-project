[CmdletBinding()]
param(
    [switch]$SkipScenarioTests,
    [ValidateRange(1, 3600)][int]$ScenarioTimeoutSeconds = 240
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
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 240
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "pwsh.exe"
    $psi.WorkingDirectory = $repoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($arg in @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Path) + $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    try {
        [void]$process.Start()
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
            return [pscustomobject]@{
                ExitCode = 124
                Stdout = (($stdoutTask.Result) -replace "(\r?\n)+$", "")
                Stderr = "PowerShell script timed out after $TimeoutSeconds seconds: $Path"
                TimedOut = $true
            }
        }

        $process.WaitForExit()
        [void]$stdoutTask.Wait(1000)
        [void]$stderrTask.Wait(1000)
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = (($stdoutTask.Result) -replace "(\r?\n)+$", "")
            Stderr = (($stderrTask.Result) -replace "(\r?\n)+$", "")
            TimedOut = $false
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
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
