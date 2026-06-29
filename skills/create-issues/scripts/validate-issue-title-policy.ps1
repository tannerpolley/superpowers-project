[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Title,
    [string[]]$KnownMilestoneTitles = @(),
    [string[]]$KnownMilestoneNumbers = @(),
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$phase = "issue-title-policy"

function Complete {
    param([bool]$Ok, [string]$Reason)
    $result = [ordered]@{
        ok = $Ok
        phase = $phase
        title = $Title
        reason = $Reason
    }
    if ($Json) {
        $result | ConvertTo-Json -Depth 8
    } elseif ($Ok) {
        "passed"
    } else {
        $Reason
    }
    if ($Ok) { exit 0 }
    exit 1
}

function Get-MilestoneAliases {
    param([string[]]$Titles)
    $aliases = [System.Collections.Generic.List[string]]::new()
    foreach ($value in @($Titles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $trimmed = $value.Trim()
        $aliases.Add($trimmed) | Out-Null
        if ($trimmed -match '^\s*M\d+\s+-\s+(?<name>.+?)\s*$') {
            $aliases.Add($Matches.name.Trim()) | Out-Null
        }
    }
    @($aliases | Select-Object -Unique)
}

try {
    $clean = $Title.Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) {
        Complete -Ok $false -Reason "title is empty"
    }

    if ($clean -match '^\s*\[\s*M\d+\s*\]\s*' -or $clean -match '^\s*M\d+(?:\.\d+)*\b(?:\s+|[:.-])') {
        Complete -Ok $false -Reason "title encodes a milestone number"
    }

    foreach ($number in @($KnownMilestoneNumbers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $escaped = [regex]::Escape($number.Trim())
        if ($clean -match "^\s*\[\s*$escaped\s*\]\s*" -or $clean -match "^\s*$escaped(?:\.\d+)*\b(?:\s+|[:.-])") {
            Complete -Ok $false -Reason "title encodes known milestone number $($number.Trim())"
        }
    }

    foreach ($alias in @(Get-MilestoneAliases -Titles $KnownMilestoneTitles)) {
        $escaped = [regex]::Escape($alias)
        if ($clean -match "^\s*$escaped(?:\s*$|[\s:.-])") {
            Complete -Ok $false -Reason "title encodes known milestone name $alias"
        }
    }

    if ($clean -match '^\s*\d+(?:\.\d+)*[.)]\s+') {
        Complete -Ok $false -Reason "title encodes hierarchy ordering"
    }

    Complete -Ok $true -Reason "title passed clean-title policy"
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
