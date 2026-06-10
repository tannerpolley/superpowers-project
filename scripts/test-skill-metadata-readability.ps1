[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [ValidateRange(80, 1000)][int]$MaxLineLength = 240
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

function Get-RelativePath {
    param([string]$Path)
    [IO.Path]::GetRelativePath($RepoRoot, $Path) -replace "\\", "/"
}

try {
    $metadataFiles = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot "skills") -Recurse -File -Filter "openai.yaml" | Sort-Object FullName)
    if ($metadataFiles.Count -eq 0) { throw "no skill metadata files found" }

    foreach ($file in $metadataFiles) {
        $relativePath = Get-RelativePath -Path $file.FullName
        $lines = [IO.File]::ReadAllLines($file.FullName)
        for ($index = 0; $index -lt $lines.Count; $index++) {
            $lineLength = $lines[$index].Length
            if ($lineLength -gt $MaxLineLength) {
                Add-Check -Name "$relativePath line $($index + 1) length" -Ok $false -Reason "${relativePath}:$($index + 1):$lineLength exceeds $MaxLineLength characters"
            }
        }

        $defaultPromptIndex = -1
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -match "^(\s*)default_prompt:\s*(.*)$") {
                $defaultPromptIndex = $index
                break
            }
        }
        if ($defaultPromptIndex -lt 0) {
            Add-Check -Name "$relativePath default_prompt exists" -Ok $false -Reason "$relativePath is missing default_prompt"
            continue
        }

        $defaultLine = $lines[$defaultPromptIndex]
        $match = [regex]::Match($defaultLine, "^(\s*)default_prompt:\s*(.*)$")
        $baseIndent = $match.Groups[1].Value.Length
        $inlineValue = $match.Groups[2].Value.Trim()
        $hasPromptText = $false
        if (-not [string]::IsNullOrWhiteSpace($inlineValue) -and $inlineValue -notin @(">", ">-", "|", "|-")) {
            $hasPromptText = $true
        } else {
            for ($childIndex = $defaultPromptIndex + 1; $childIndex -lt $lines.Count; $childIndex++) {
                $child = $lines[$childIndex]
                if ([string]::IsNullOrWhiteSpace($child)) { continue }
                $childIndent = ([regex]::Match($child, "^\s*")).Value.Length
                if ($childIndent -le $baseIndent) { break }
                if (-not [string]::IsNullOrWhiteSpace($child.Trim())) {
                    $hasPromptText = $true
                    break
                }
            }
        }
        Add-Check -Name "$relativePath default_prompt non-empty" -Ok $hasPromptText -Reason "$relativePath default_prompt must not be empty"
    }

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{
        ok = ($failed.Count -eq 0)
        phase = "skill-metadata-readability"
        max_line_length = $MaxLineLength
        checks = $checks
    } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{
        ok = $false
        phase = "skill-metadata-readability"
        max_line_length = $MaxLineLength
        reason = $_.Exception.Message
        checks = $checks
    } | ConvertTo-Json -Depth 8
    exit 1
}
