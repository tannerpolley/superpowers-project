# Validation Timeout Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make validation and skill helper processes fail loudly within bounded time instead of hanging.

**Architecture:** Keep `scripts/validate.ps1` as the top-level proof command and add bounded child-process execution where validation currently shells out. Replace the two shared skill helper implementations with a backward-compatible process result object that still exposes `ExitCode`, `Stdout`, and `Stderr`, and adds timeout evidence. Add scenario coverage that proves a hung helper is killed by owned process handle.

**Tech Stack:** PowerShell 7, .NET `System.Diagnostics.Process`, existing skill scenario scripts, Git.

---

## Issue Metadata

**GitHub Issue:** Create from this local issue file before execution and rename the file after GitHub assigns the issue number.
**Issue Type:** `type:task`
**Milestone:** `M0 - Governance` (`docs/milestones/M0-governance`)
**Source Spec:** `docs/superpowers/specs/2026-06-02-bootstrap-workflow-design.md`

**Acceptance Criteria:**

- `canonical-skills/project-resolve/scripts/lib/contract.ps1` external commands support `-TimeoutSeconds` and return structured timeout evidence.
- `canonical-skills/convert-idea-to-issue/scripts/lib/contract.ps1` external commands support the same timeout behavior.
- `scripts/validate.ps1` runs each scenario suite through a bounded helper and reports the timed-out skill name.
- A synthetic hung helper scenario proves the child process is stopped.
- `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests` passes.

**Non-Goals:**

- Do not change wrapper wording or wrapper source assertions in this issue.
- Do not add CI in this issue.
- Do not change live deployment behavior in this issue.

**Proof Oracle:** `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests` passes, and the new hung-helper scenario passes when run directly.

---

## File Map

- Modify: `canonical-skills/project-resolve/scripts/lib/contract.ps1`
  Owns bounded external process execution for `project-resolve`.
- Modify: `canonical-skills/project-resolve/scripts/test-scenarios.ps1`
  Adds the hung-helper regression scenario.
- Modify: `canonical-skills/convert-idea-to-issue/scripts/lib/contract.ps1`
  Owns the same bounded external process contract for `convert-idea-to-issue`.
- Modify: `canonical-skills/convert-idea-to-issue/scripts/test-scenarios.ps1`
  Adds the matching hung-helper regression scenario.
- Modify: `scripts/validate.ps1`
  Runs scenario suites through a bounded PowerShell child process and reports timeout evidence.

## Task 1: Add A Bounded Process Helper To Project Resolve

**Files:**

- Modify: `canonical-skills/project-resolve/scripts/lib/contract.ps1`
- Modify: `canonical-skills/project-resolve/scripts/test-scenarios.ps1`
- Test: `canonical-skills/project-resolve/scripts/test-scenarios.ps1`

- [ ] **Step 1: Add the failing timeout scenario**

In `canonical-skills/project-resolve/scripts/test-scenarios.ps1`, immediately after line 688, where the `try` block creates `$tempRoot`, insert:

```powershell
    $timeoutProbe = Invoke-External -FilePath "pwsh.exe" -Arguments @("-NoProfile", "-Command", "Start-Sleep -Seconds 5") -WorkingDirectory $tempRoot -TimeoutSeconds 1
    $timeoutProbeStillRunning = $false
    if ($timeoutProbe.ProcessId -gt 0) {
        Start-Sleep -Milliseconds 200
        $timeoutProbeStillRunning = [bool](Get-Process -Id $timeoutProbe.ProcessId -ErrorAction SilentlyContinue)
    }
    Add-TestResult -Name "external helper timeout is bounded" -Passed (
        $timeoutProbe.TimedOut -eq $true -and
        $timeoutProbe.ExitCode -eq 124 -and
        $timeoutProbe.Stderr -match "timed out" -and
        $timeoutProbeStillRunning -eq $false
    ) -Reason "timeout result should prove owned child process termination" -Details @{
        exit_code = $timeoutProbe.ExitCode
        timed_out = $timeoutProbe.TimedOut
        process_id = $timeoutProbe.ProcessId
        still_running = $timeoutProbeStillRunning
        stderr = $timeoutProbe.Stderr
    }
```

- [ ] **Step 2: Run the scenario and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\project-resolve\scripts\test-scenarios.ps1
```

Expected: exits nonzero and reports a parameter binding failure for `TimeoutSeconds`.

- [ ] **Step 3: Replace `Invoke-External` with a bounded implementation**

In `canonical-skills/project-resolve/scripts/lib/contract.ps1`, replace the current `Invoke-External` function with:

```powershell
function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 60
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }

    $stdoutBuilder = [System.Text.StringBuilder]::new()
    $stderrBuilder = [System.Text.StringBuilder]::new()
    $stdoutHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -ne $eventArgs.Data) { [void]$stdoutBuilder.AppendLine($eventArgs.Data) }
    }
    $stderrHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -ne $eventArgs.Data) { [void]$stderrBuilder.AppendLine($eventArgs.Data) }
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.add_OutputDataReceived($stdoutHandler)
    [void]$process.add_ErrorDataReceived($stderrHandler)

    try {
        [void]$process.Start()
        $processId = $process.Id
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        $exited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            try {
                $process.Kill($true)
            } catch {
                if (-not $process.HasExited) { throw }
            }
            $process.WaitForExit()
            [pscustomobject]@{
                ExitCode = 124
                Stdout = (($stdoutBuilder.ToString()) -replace "(\r?\n)+$", "")
                Stderr = "external command timed out after $TimeoutSeconds seconds: $FilePath $($Arguments -join ' ')"
                TimedOut = $true
                TimeoutSeconds = $TimeoutSeconds
                ProcessId = $processId
            }
            return
        }

        $process.WaitForExit()
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = (($stdoutBuilder.ToString()) -replace "(\r?\n)+$", "")
            Stderr = (($stderrBuilder.ToString()) -replace "(\r?\n)+$", "")
            TimedOut = $false
            TimeoutSeconds = $TimeoutSeconds
            ProcessId = $processId
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}
```

- [ ] **Step 4: Run the scenario and verify the timeout scenario passes**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\project-resolve\scripts\test-scenarios.ps1
```

Expected: the `external helper timeout is bounded` result has `passed: true`. If other pre-existing scenario failures remain, record them separately and continue with this issue only if they are unrelated to timeout behavior.

- [ ] **Step 5: Commit the resolve helper slice**

Run:

```powershell
git add canonical-skills/project-resolve/scripts/lib/contract.ps1 canonical-skills/project-resolve/scripts/test-scenarios.ps1
git commit -m "test: bound resolve issue helper processes"
```

## Task 2: Add The Same Timeout Contract To Convert Idea To Issue

**Files:**

- Modify: `canonical-skills/convert-idea-to-issue/scripts/lib/contract.ps1`
- Modify: `canonical-skills/convert-idea-to-issue/scripts/test-scenarios.ps1`
- Test: `canonical-skills/convert-idea-to-issue/scripts/test-scenarios.ps1`

- [ ] **Step 1: Dot-source the helper library in the scenario script**

In `canonical-skills/convert-idea-to-issue/scripts/test-scenarios.ps1`, after line 4, insert:

```powershell
. (Join-Path $PSScriptRoot "lib\contract.ps1")
```

- [ ] **Step 2: Add the failing timeout scenario**

Add this entry as the first item in `$scenarios = @(`:

```powershell
    Invoke-Scenario "external helper timeout is bounded" {
        $timeoutProbe = Invoke-External -FilePath "pwsh.exe" -Arguments @("-NoProfile", "-Command", "Start-Sleep -Seconds 5") -WorkingDirectory $env:TEMP -TimeoutSeconds 1
        $timeoutProbeStillRunning = $false
        if ($timeoutProbe.ProcessId -gt 0) {
            Start-Sleep -Milliseconds 200
            $timeoutProbeStillRunning = [bool](Get-Process -Id $timeoutProbe.ProcessId -ErrorAction SilentlyContinue)
        }
        Assert-True ($timeoutProbe.TimedOut -eq $true) "timeout result did not mark TimedOut"
        Assert-True ($timeoutProbe.ExitCode -eq 124) "timeout result did not use exit code 124"
        Assert-True ($timeoutProbe.Stderr -match "timed out") "timeout result did not explain timeout"
        Assert-True (-not $timeoutProbeStillRunning) "timed-out child process is still running"
    }
```

- [ ] **Step 3: Run the scenario and verify the expected failure**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\convert-idea-to-issue\scripts\test-scenarios.ps1
```

Expected: exits nonzero and reports a parameter binding failure for `TimeoutSeconds`.

- [ ] **Step 4: Replace the helper with the same bounded implementation**

In `canonical-skills/convert-idea-to-issue/scripts/lib/contract.ps1`, replace its current `Invoke-External` function with the same implementation from Task 1, Step 3.

- [ ] **Step 5: Run the scenario and verify it passes**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\canonical-skills\convert-idea-to-issue\scripts\test-scenarios.ps1
```

Expected: exits zero and includes `"external helper timeout is bounded"` with `"ok": true`.

- [ ] **Step 6: Commit the convert helper slice**

Run:

```powershell
git add canonical-skills/convert-idea-to-issue/scripts/lib/contract.ps1 canonical-skills/convert-idea-to-issue/scripts/test-scenarios.ps1
git commit -m "test: bound convert issue helper processes"
```

## Task 3: Bound Scenario Suite Execution In Validate

**Files:**

- Modify: `scripts/validate.ps1`
- Test: `scripts/validate.ps1`

- [ ] **Step 1: Add a bounded PowerShell script runner**

In `scripts/validate.ps1`, after `Invoke-Step`, add:

```powershell
function Invoke-PwshFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Arguments = @(),
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120
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

    $stdoutBuilder = [System.Text.StringBuilder]::new()
    $stderrBuilder = [System.Text.StringBuilder]::new()
    $stdoutHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -ne $eventArgs.Data) { [void]$stdoutBuilder.AppendLine($eventArgs.Data) }
    }
    $stderrHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -ne $eventArgs.Data) { [void]$stderrBuilder.AppendLine($eventArgs.Data) }
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.add_OutputDataReceived($stdoutHandler)
    [void]$process.add_ErrorDataReceived($stderrHandler)

    try {
        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        $exited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            try { $process.Kill($true) } catch { if (-not $process.HasExited) { throw } }
            $process.WaitForExit()
            return [pscustomobject]@{
                ExitCode = 124
                Stdout = (($stdoutBuilder.ToString()) -replace "(\r?\n)+$", "")
                Stderr = "PowerShell script timed out after $TimeoutSeconds seconds: $Path"
                TimedOut = $true
            }
        }

        $process.WaitForExit()
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = (($stdoutBuilder.ToString()) -replace "(\r?\n)+$", "")
            Stderr = (($stderrBuilder.ToString()) -replace "(\r?\n)+$", "")
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
```

- [ ] **Step 2: Use the bounded runner for scenario scripts**

Replace the scenario test invocation inside `scripts/validate.ps1` with:

```powershell
$scenarioResult = Invoke-PwshFile -Path $scenarioScript -TimeoutSeconds 120
if (-not [string]::IsNullOrWhiteSpace($scenarioResult.Stdout)) { $scenarioResult.Stdout | Out-Host }
if (-not [string]::IsNullOrWhiteSpace($scenarioResult.Stderr)) { $scenarioResult.Stderr | Out-Host }
if ($scenarioResult.TimedOut) { throw "scenario tests timed out for $($skill.Name)" }
if ($scenarioResult.ExitCode -ne 0) { throw "scenario tests failed for $($skill.Name)" }
```

- [ ] **Step 3: Run parser and structural validation**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero and reports `"ok": true`.

- [ ] **Step 4: Run full validation and record remaining source failures**

Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

Expected: exits within the validator timeout. A wrapper assertion failure may remain until the M1 plan is implemented.

- [ ] **Step 5: Commit the validator bounding slice**

Run:

```powershell
git add scripts/validate.ps1
git commit -m "test: bound scenario validation runs"
```

## Closeout

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -SkipScenarioTests
```

Expected: exits zero.

- [ ] Run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\hooks\codex-cleanup.ps1" -RepoRoot .
```

Expected: exits zero and reports no matching leftover repo processes.
