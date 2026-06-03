[CmdletBinding()]
param(
    [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"
$phase = "validate-flat-artifact-roots"
$findings = [System.Collections.Generic.List[object]]::new()

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $milestonesRoot = Join-Path $root "docs\superpowers\milestones"
    $canonicalNames = @("specs", "plans", "issues")

    if (Test-Path -LiteralPath $milestonesRoot -PathType Container) {
        foreach ($name in $canonicalNames) {
            $nested = @(Get-ChildItem -LiteralPath $milestonesRoot -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -eq $name -and -not (Test-Path -LiteralPath (Join-Path $_.FullName ".generated-index-view") -PathType Leaf)
            })
            foreach ($folder in $nested) {
                $relative = [IO.Path]::GetRelativePath($root, $folder.FullName) -replace '\\', '/'
                $findings.Add([pscustomobject]@{
                    category = "blocking"
                    path = $relative
                    reason = "nested canonical milestone artifact folder"
                })
            }
        }
    }

    if ($findings.Count -gt 0) {
        [pscustomobject]@{
            ok = $false
            phase = $phase
            reason = "nested canonical milestone artifact folders are drift"
            findings = $findings
        } | ConvertTo-Json -Depth 8
        exit 1
    }

    [pscustomobject]@{
        ok = $true
        phase = $phase
        reason = "flat canonical artifact roots passed"
        findings = @()
    } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{
        ok = $false
        phase = $phase
        reason = $_.Exception.Message
        findings = $findings
    } | ConvertTo-Json -Depth 8
    exit 1
}
