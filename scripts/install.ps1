[CmdletBinding()]
param(
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"

$syncArgs = @()
if (-not $SkipValidation) { $syncArgs += "-Validate" }

& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync-live.ps1") @syncArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
