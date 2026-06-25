[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$Path
)

$ErrorActionPreference = "Stop"

function Get-SectionBody {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Text, "(?ims)^##\s+$escaped\s*\r?\n(?<body>.*?)(?=^##\s+|\z)")
    if (-not $match.Success) { return $null }
    $match.Groups["body"].Value.Trim()
}

function Get-Bullets {
    param([string]$Text)
    @($Text -split "`r?`n" | Where-Object { $_ -match '^\s*[-*]\s+' } | ForEach-Object { ($_ -replace '^\s*[-*]\s+', '').Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-ExactPathToken {
    param([string]$Text)
    $tokens = @([regex]::Matches($Text, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
    @($tokens | Where-Object {
        $_ -match '[/\\]' -or $_ -match '\.(md|ps1|ya?ml|json|txt|svg|png|jpg|jpeg|ts|tsx|js|py)$' -or $_ -match '^https?://'
    }).Count -gt 0
}

function Assert-ArtifactReviewCard {
    param([string]$Text, [string]$Label)
    if ($Text -notmatch '(?im)^#\s+Artifact Review Card\s*$') { throw "$Label must start with an Artifact Review Card heading" }
    foreach ($section in @("Created/changed", "Proof", "Decisions", "Risks", "Recommended next route")) {
        $body = Get-SectionBody -Text $Text -Name $section
        if ([string]::IsNullOrWhiteSpace($body)) { throw "$Label missing $section section" }
    }
    $created = Get-SectionBody -Text $Text -Name "Created/changed"
    if (-not (Test-ExactPathToken -Text $created)) { throw "$Label Created/changed must include at least one exact path or stable identifier" }
    $proof = Get-SectionBody -Text $Text -Name "Proof"
    if ((Get-Bullets -Text $proof).Count -eq 0) { throw "$Label Proof must include at least one proof item" }
    if ($proof -match '(?i)\b(todo|pending|not run|unverified)\b') { throw "$Label Proof must not contain pending or unverified proof" }
    $decisions = Get-SectionBody -Text $Text -Name "Decisions"
    if ((Get-Bullets -Text $decisions).Count -eq 0) { throw "$Label Decisions must include at least one decision item" }
    $risks = @(Get-Bullets -Text (Get-SectionBody -Text $Text -Name "Risks"))
    if ($risks.Count -eq 0) { throw "$Label Risks must include at least one risk item" }
    foreach ($risk in $risks) {
        if ($risk -notmatch '(?i)\b(risk owner|owner)\s*:') { throw "$Label risk item missing risk owner: $risk" }
        if ($risk -match '(?i)\b(tbd|unknown)\b') { throw "$Label risk owner must not be TBD or unknown" }
    }
    $next = Get-SectionBody -Text $Text -Name "Recommended next route"
    if ($next -notmatch '(?i)(setup-project|brainstorm-spec|write-plan|create-issues|implement-plan|resolve-issue|orchestrate-issues|merge-changes|audit-project|align-project|loop-controller|done|stop|hold)') {
        throw "$Label Recommended next route must name a workflow route or terminal gate"
    }
}

function Assert-RepoPolicy {
    param([string]$Root)
    $helperPath = Join-Path $Root "skills\advanced-user-input\SKILL.md"
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) { throw "missing advanced-user-input helper" }
    $helper = Get-Content -LiteralPath $helperPath -Raw
    foreach ($needle in @(
        '### Artifact Review Card Schema',
        'display-before-question',
        '`Gate`',
        '`Created/changed`',
        '`Proof`',
        '`Decisions`',
        '`Risks`',
        '`Recommended next route`',
        'Large artifact excerpt rule',
        'risk owner'
    )) {
        if (-not $helper.Contains($needle)) { throw "advanced-user-input missing Artifact Review Card policy: $needle" }
    }

    $skillRoot = Join-Path $Root "skills"
    foreach ($skill in @(Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object { $_.Name -ne "advanced-user-input" })) {
        $skillPath = Join-Path $skill.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { continue }
        $text = Get-Content -LiteralPath $skillPath -Raw
        if ($text.Contains('artifact review gate required by `skills/advanced-user-input/SKILL.md`')) {
            if (-not $text.Contains("Artifact Review Card schema")) { throw "$skillPath must reference the helper Artifact Review Card schema" }
            if (-not ($text.Contains("before asking") -or $text.Contains("before any"))) { throw "$skillPath must preserve display-before-question behavior" }
        }
    }
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Assert-RepoPolicy -Root $root
        [pscustomobject]@{ ok = $true; phase = "artifact-review-card"; mode = "repo-policy" } | ConvertTo-Json -Depth 8
        exit 0
    }
    $cardPath = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not (Test-Path -LiteralPath $cardPath -PathType Leaf)) { throw "card file does not exist: $Path" }
    Assert-ArtifactReviewCard -Text (Get-Content -LiteralPath $cardPath -Raw) -Label $Path
    [pscustomobject]@{ ok = $true; phase = "artifact-review-card"; mode = "card"; path = $Path } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{ ok = $false; phase = "artifact-review-card"; reason = $_.Exception.Message; path = $Path } | ConvertTo-Json -Depth 8
    exit 1
}
