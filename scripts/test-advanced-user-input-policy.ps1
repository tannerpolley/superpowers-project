[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Ok,
        [string]$Reason = "passed"
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

$checks = [System.Collections.Generic.List[object]]::new()
$skillPath = Join-Path $RepoRoot "skills\advanced-user-input\SKILL.md"
$metadataPath = Join-Path $RepoRoot "skills\advanced-user-input\agents\openai.yaml"

$exists = Test-Path -LiteralPath $skillPath -PathType Leaf
Add-Check $checks "advanced-user-input exists in plugin source" $exists "missing $skillPath"
$metadataExists = Test-Path -LiteralPath $metadataPath -PathType Leaf
Add-Check $checks "advanced-user-input has plugin UI metadata" $metadataExists "missing $metadataPath"

if ($exists) {
    $text = Get-Content -LiteralPath $skillPath -Raw

    foreach ($needle in @(
        "Use the smallest native question shape that preserves the real decision tree",
        "For project workflow closeout gates, always ask the three-way trajectory question first",
        "Do not flatten closeout into a five-option or larger peer menu",
        "Use larger native prompts only inside a selected branch",
        "Observed Codex Desktop behavior",
        "current runtime-permissive behavior",
        "Sequential Branching",
        "Bulk Question Sets",
        "Large Option Sets",
        "request_agent_input",
        "Do not collapse real routes into fake categories",
        "Ask exactly three top-level options",
        "Ask the top-level closeout as Continue?",
        "Use Yes for the progress route",
        "Use Revisit as the standard go-back route label",
        "Use No for the stop route",
        "Do not put Continue children beside Revisit and No in the same top-level question",
        "Revisit is non-terminal",
        "the only Yes terminal exception is an explicit final Healthy -> Done gate",
        "Review First is not a terminal answer",
        "Only No / Stop / Done can end a continuation loop before that final Done gate",
        "reaches an explicit final Healthy -> Done gate",
        "If the active runtime rejects a large prompt, fail loudly",
        "Nested Yes-route menus must not include Stop / Done",
        "Nested Revisit-route menus must not include Stop / Done",
        "Recommend Yes when at least one safe forward route exists",
        "Recommend No / Stop / Done only for explicit terminal, blocker, or user-requested stop states",
        "Approval gates use domain-specific decline or cancel labels instead of Stop / Done"
    )) {
        Add-Check $checks "advanced-user-input contains $needle" ($text.Contains($needle)) "$skillPath must contain policy: $needle"
    }

    foreach ($forbidden in @(
        "Do not ask 4+ native options",
        "Do not ask 4+ native questions",
        "Do not pre-collapse to three choices",
        "Prefer the full peer set over a nested Down / Left / Right pre-question",
        "Show all peer options at once when that makes the workflow easier to understand",
        "Forcing all prompts into three options",
        "One call may ask 1-3 questions.",
        "Each question must define 2-3 mutually exclusive options."
    )) {
        Add-Check $checks "advanced-user-input omits stale limit $forbidden" (-not $text.Contains($forbidden)) "$skillPath must not contain stale native limit: $forbidden"
    }
}

if ($metadataExists) {
    $metadata = Get-Content -LiteralPath $metadataPath -Raw
    foreach ($needle in @(
        'display_name: "Advanced User Input"',
        'Use $project:advanced-user-input',
        'Use the smallest native question shape that preserves the real decision tree',
        'For project workflow closeout gates, always ask the three-way trajectory question first',
        'Nested branch questions and independent bulk gates may use as many native questions or options as the decision requires',
        'Nested Yes-route menus must not include Stop / Done',
        'Nested Revisit-route menus must not include Stop / Done',
        'Recommend Yes when at least one safe forward route exists',
        'Recommend No / Stop / Done only for explicit terminal, blocker, or user-requested stop states',
        'Approval gates use domain-specific decline or cancel labels instead of Stop / Done',
        'request_agent_input'
    )) {
        Add-Check $checks "advanced-user-input metadata contains $needle" ($metadata.Contains($needle)) "$metadataPath must contain policy: $needle"
    }
}

$failed = @($checks | Where-Object { -not $_.ok })
[pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "advanced-user-input-policy"
    checks = $checks
} | ConvertTo-Json -Depth 8

if ($failed.Count -gt 0) { exit 1 }
