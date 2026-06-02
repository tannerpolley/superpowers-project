$ErrorActionPreference = "Stop"

function Get-GitHubCheckName {
    param($Check)
    if ($Check -is [System.Collections.IDictionary]) {
        foreach ($propertyName in @("name", "context", "workflowName", "checkName")) {
            if ($Check.Contains($propertyName)) {
                $value = [string]$Check[$propertyName]
                if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
            }
        }
    }
    foreach ($propertyName in @("name", "context", "workflowName", "checkName")) {
        if ($null -ne $Check -and $Check.PSObject.Properties.Name -contains $propertyName) {
            $value = [string]$Check.$propertyName
            if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        }
    }
    ""
}

function Get-GitHubCheckValue {
    param($Check, [string[]]$PropertyNames)
    if ($Check -is [System.Collections.IDictionary]) {
        foreach ($propertyName in $PropertyNames) {
            if ($Check.Contains($propertyName)) {
                $value = [string]$Check[$propertyName]
                if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
            }
        }
    }
    foreach ($propertyName in $PropertyNames) {
        if ($null -ne $Check -and $Check.PSObject.Properties.Name -contains $propertyName) {
            $value = [string]$Check.$propertyName
            if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        }
    }
    ""
}

function Normalize-GitHubCheckState {
    param(
        $Check,
        [string]$State,
        [string]$Conclusion,
        [string]$Status
    )

    if ($null -ne $Check) {
        if ([string]::IsNullOrWhiteSpace($Conclusion)) {
            $Conclusion = Get-GitHubCheckValue -Check $Check -PropertyNames @("conclusion")
        }
        if ([string]::IsNullOrWhiteSpace($Status)) {
            $Status = Get-GitHubCheckValue -Check $Check -PropertyNames @("status")
        }
        if ([string]::IsNullOrWhiteSpace($State)) {
            $State = Get-GitHubCheckValue -Check $Check -PropertyNames @("state")
        }
    }

    $conclusionValue = $Conclusion.Trim().ToUpperInvariant()
    $statusValue = $Status.Trim().ToUpperInvariant()
    $stateValue = $State.Trim().ToUpperInvariant()

    switch -Regex ($conclusionValue) {
        "^(SUCCESS|PASSED|PASS)$" { return "success" }
        "^(SKIPPED)$" { return "skipped" }
        "^(FAILURE|FAILED|ERROR|STARTUP_FAILURE|ACTION_REQUIRED|NEUTRAL)$" { return "failed" }
        "^(CANCELLED|CANCELED)$" { return "cancelled" }
        "^(TIMED_OUT|TIMEOUT|TIMEDOUT)$" { return "timed_out" }
    }

    switch -Regex ($stateValue) {
        "^(SUCCESS|PASSED|PASS)$" { return "success" }
        "^(SKIPPED)$" { return "skipped" }
        "^(FAILURE|FAILED|ERROR|ACTION_REQUIRED|NEUTRAL)$" { return "failed" }
        "^(CANCELLED|CANCELED)$" { return "cancelled" }
        "^(TIMED_OUT|TIMEOUT|TIMEDOUT)$" { return "timed_out" }
        "^(PENDING|QUEUED|IN_PROGRESS|REQUESTED|WAITING|EXPECTED)$" { return "pending" }
    }

    switch -Regex ($statusValue) {
        "^(PENDING|QUEUED|IN_PROGRESS|REQUESTED|WAITING|EXPECTED)$" { return "pending" }
        "^(COMPLETED)$" { return "failed" }
    }

    if ([string]::IsNullOrWhiteSpace($conclusionValue) -and [string]::IsNullOrWhiteSpace($stateValue) -and [string]::IsNullOrWhiteSpace($statusValue)) {
        return "missing"
    }

    "unknown"
}

function Test-GitHubCheckPassed {
    param(
        $Check,
        [switch]$Optional
    )

    $normalized = Normalize-GitHubCheckState -Check $Check
    if ($normalized -eq "success") { return $true }
    if ($Optional -and $normalized -eq "skipped") { return $true }
    $false
}

function Test-GitHubRequiredChecks {
    param(
        $Checks,
        [string]$Policy = "require-existing",
        [string[]]$RequiredCheckNames = @(),
        [string[]]$OptionalCheckNames = @()
    )

    $checkList = @($Checks)
    $requiredNames = @($RequiredCheckNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $optionalNames = @($OptionalCheckNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $checkNames = @($checkList | ForEach-Object { Get-GitHubCheckName -Check $_ })

    if ($Policy -eq "require-existing" -and $checkList.Count -eq 0) {
        return [pscustomobject]@{ ok = $false; reason = "required GitHub checks are missing"; checks = @() }
    }

    foreach ($requiredName in $requiredNames) {
        if ($checkNames -notcontains $requiredName) {
            return [pscustomobject]@{ ok = $false; reason = "required GitHub check is missing: $requiredName"; checks = $checkNames }
        }
    }

    foreach ($check in $checkList) {
        $name = Get-GitHubCheckName -Check $check
        $optional = $optionalNames -contains $name
        $requiredByName = $requiredNames.Count -eq 0 -or $requiredNames -contains $name
        if ($optional) { continue }
        if (-not $requiredByName) { continue }

        $state = Normalize-GitHubCheckState -Check $check
        if ($state -ne "success") {
            return [pscustomobject]@{
                ok = $false
                reason = "required GitHub check '$name' is $state"
                checks = $checkNames
            }
        }
    }

    [pscustomobject]@{ ok = $true; reason = "required GitHub checks passed"; checks = $checkNames }
}
