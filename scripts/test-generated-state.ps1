[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $PSScriptRoot "validate-generated-state.ps1"
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $results.Add([pscustomobject]@{ name = $Name; ok = $true; reason = "passed" }) | Out-Null
    } catch {
        $results.Add([pscustomobject]@{ name = $Name; ok = $false; reason = $_.Exception.Message }) | Out-Null
    }
}

function Write-TextFile {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Text -Encoding utf8NoBOM
}

function Invoke-Validator {
    param([string]$Root)
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RepoRoot $Root 2>&1
    $raw = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{ ok = $false; reason = "empty validator output" } }
    try { return ($raw | ConvertFrom-Json) } catch { return [pscustomobject]@{ ok = $false; reason = $raw } }
}

function New-FixtureRepo {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("generated-state-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    & git -C $root init --quiet
    & git -C $root config user.email "fixture@example.test"
    & git -C $root config user.name "Fixture"
    Write-TextFile -Path (Join-Path $root ".gitignore") -Text ".superpowers/`n"
    Write-TextFile -Path (Join-Path $root "docs\superpowers\PROJECT_CONTEXT.md") -Text "# Context`n"
    $root
}

Invoke-Scenario "repo has generated-state validator" {
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw "missing validate-generated-state.ps1" }
}

Invoke-Scenario "current repo generated state passes" {
    $result = Invoke-Validator -Root $repoRoot
    if (-not $result.ok) { throw $result.reason }
}

Invoke-Scenario ".superpowers ignore entry is required" {
    $root = New-FixtureRepo
    try {
        Write-TextFile -Path (Join-Path $root ".gitignore") -Text "logs/`n"
        $result = Invoke-Validator -Root $root
        $reasons = @($result.findings | ForEach-Object { [string]$_.reason })
        if ($result.ok -or ($reasons -notcontains ".superpowers/ ignore entry is required")) { throw "expected missing .superpowers ignore rejection" }
    } finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

Invoke-Scenario "tracked generated runtime state is rejected" {
    $root = New-FixtureRepo
    try {
        Write-TextFile -Path (Join-Path $root ".superpowers\runs\run.json") -Text "{}"
        & git -C $root add -f .superpowers/runs/run.json | Out-Null
        $result = Invoke-Validator -Root $root
        $reasons = @($result.findings | ForEach-Object { [string]$_.reason })
        if ($result.ok -or ($reasons -notcontains "tracked generated state")) { throw "expected tracked generated state rejection" }
    } finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

Invoke-Scenario "canonical docs claim is rejected" {
    $root = New-FixtureRepo
    try {
        Write-TextFile -Path (Join-Path $root "docs\superpowers\PROJECT_CONTEXT.md") -Text "# Context`n`n`.superpowers/runs/run.json` is canonical project documentation.`n"
        $result = Invoke-Validator -Root $root
        $reasons = @($result.findings | ForEach-Object { [string]$_.reason })
        if ($result.ok -or ($reasons -notcontains "canonical generated-state reference")) { throw "expected canonical generated-state reference rejection" }
    } finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

Invoke-Scenario "untracked local run ledgers are allowed" {
    $root = New-FixtureRepo
    try {
        Write-TextFile -Path (Join-Path $root ".superpowers\runs\run.json") -Text "{}"
        $result = Invoke-Validator -Root $root
        if (-not $result.ok) { throw $result.reason }
    } finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

$failed = @($results | Where-Object { -not $_.ok })
$results | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) { exit 1 }
