[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [string]$AuthorizationJson,
    [string]$AuthorizationPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\auto-mode-contract.ps1")

function Complete {
    param(
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{}
    )

    [pscustomobject]@{
        ok = $Ok
        phase = "auto-mode-authorization"
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 16

    if ($Ok) { exit 0 }
    exit 1
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $hasJson = -not [string]::IsNullOrWhiteSpace($AuthorizationJson)
    $hasPath = -not [string]::IsNullOrWhiteSpace($AuthorizationPath)
    if ($hasJson -eq $hasPath) {
        throw "provide exactly one of AuthorizationJson or AuthorizationPath"
    }

    $authPath = ""
    if ($hasPath) {
        $authPath = (Resolve-Path -LiteralPath $AuthorizationPath).Path
        $raw = Get-Content -LiteralPath $authPath -Raw
    } else {
        $raw = $AuthorizationJson
    }

    $authorization = $raw | ConvertFrom-Json
    $result = Test-AutoModeAuthorization -Authorization $authorization -RepoRoot $root
    Complete -Ok ([bool]$result.ok) -Reason ([string]$result.reason) -Evidence @{
        repo_root = $root
        authorization_path = $authPath
    }
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
