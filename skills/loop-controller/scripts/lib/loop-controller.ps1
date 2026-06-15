$ErrorActionPreference = "Stop"

function Test-LoopControllerProperty {
    param([object]$Object, [string]$Name)
    $null -ne $Object.PSObject.Properties[$Name]
}

function Resolve-LoopControllerRepoRoot {
    param([string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
    }
    (Resolve-Path -LiteralPath $RepoRoot).Path
}

function ConvertTo-LoopControllerRelativePath {
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string]$Path)
    $root = [IO.Path]::GetFullPath($RepoRoot)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $candidate -ne $root) {
        throw "path is outside repo root: $candidate"
    }
    ([IO.Path]::GetRelativePath($root, $candidate) -replace "\\", "/")
}

function Read-LoopControllerJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "json file does not exist: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function New-LoopControllerResult {
    param([bool]$Ok, [string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    $result = [ordered]@{ ok = $Ok; phase = $Phase; reason = $Reason }
    foreach ($key in $Evidence.Keys) { $result[$key] = $Evidence[$key] }
    [pscustomobject]$result
}

function Assert-LoopRequiredProperties {
    param([object]$Object, [string[]]$Names)
    foreach ($name in $Names) {
        if (-not (Test-LoopControllerProperty -Object $Object -Name $name)) { throw "$name is required" }
        $value = $Object.$name
        if ($null -eq $value) { throw "$name is required" }
        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) { throw "$name is required" }
    }
}

