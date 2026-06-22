[CmdletBinding()]
param(
    [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"
$phase = "validate-generated-state"
$findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param([string]$Path, [string]$Reason, [int]$Line = 0)
    $finding = [ordered]@{ path = $Path; reason = $Reason }
    if ($Line -gt 0) { $finding.line = $Line }
    $findings.Add([pscustomobject]$finding) | Out-Null
}

function Complete {
    param([bool]$Ok, [string]$Reason)
    [pscustomobject]@{
        ok = $Ok
        phase = $phase
        reason = $Reason
        findings = $findings
    } | ConvertTo-Json -Depth 8
    if ($Ok) { exit 0 }
    exit 1
}

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments)
    $output = & git -C $Root @Arguments 2>&1
    [pscustomobject]@{
        exit_code = $LASTEXITCODE
        output = ($output | Out-String).Trim()
    }
}

function Test-GeneratedStateCanonicalClaim {
    param([string]$Line)
    if ($Line -notmatch '\.superpowers(?:/|\\|\*\*)') { return $false }
    if ($Line -notmatch '(?i)\bcanonical\b.*\b(doc|docs|documentation|artifact|inventory|source|source-of-truth)\b') { return $false }
    if ($Line -match '(?i)\b(non-canonical|not canonical|do not|don''t|cannot|can not|stop treating|fails? if|fails? when|detected|ignored|generated|local|unless|avoid|remains|should stay|should not|scan|references that present)\b') { return $false }
    if ($Line -match '(?i)^\s*[-*]\s+Treat\s+') { return $false }
    $true
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $gitignorePath = Join-Path $root ".gitignore"
    if (-not (Test-Path -LiteralPath $gitignorePath -PathType Leaf)) {
        Add-Finding -Path ".gitignore" -Reason "missing .gitignore"
    } else {
        $ignoreLines = @(Get-Content -LiteralPath $gitignorePath | ForEach-Object { $_.Trim() })
        if ($ignoreLines -notcontains ".superpowers/") {
            Add-Finding -Path ".gitignore" -Reason ".superpowers/ ignore entry is required"
        }
    }

    $tracked = Invoke-Git -Root $root -Arguments @("ls-files", "--", ".superpowers")
    if ($tracked.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($tracked.output)) {
        foreach ($path in @($tracked.output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            Add-Finding -Path ($path -replace '\\', '/') -Reason "tracked generated state"
        }
    }

    $docsRoot = Join-Path $root "docs"
    if (Test-Path -LiteralPath $docsRoot -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Include "*.md" -ErrorAction SilentlyContinue)) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName) -replace '\\', '/'
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath $file.FullName) {
                $lineNumber += 1
                if (Test-GeneratedStateCanonicalClaim -Line $line) {
                    Add-Finding -Path $relative -Line $lineNumber -Reason "canonical generated-state reference"
                }
            }
        }
    }

    if ($findings.Count -gt 0) {
        Complete -Ok $false -Reason "generated-state guardrails failed"
    }
    Complete -Ok $true -Reason "generated-state guardrails passed"
} catch {
    Add-Finding -Path "" -Reason $_.Exception.Message
    Complete -Ok $false -Reason $_.Exception.Message
}
