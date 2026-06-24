[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$Path = "docs/superpowers/backlog/ACTIVE.md"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\active-backlog.ps1")

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $backlogPath = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    $entries = @(Read-ActiveBacklog -RepoRoot $root -Path $backlogPath)
    Assert-ActiveBacklogEntries -Entries $entries
    $ready = @($entries | Where-Object { $_.status -eq "ready" })
    [pscustomobject]@{
        ok = $true
        phase = "active-backlog"
        path = $Path
        entry_count = $entries.Count
        ready_count = $ready.Count
        ready_ids = @($ready | Select-Object -ExpandProperty id)
    } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{
        ok = $false
        phase = "active-backlog"
        path = $Path
        reason = $_.Exception.Message
    } | ConvertTo-Json -Depth 8
    exit 1
}
