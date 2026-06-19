[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    }) | Out-Null
}

function Assert-Contains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    Add-Check -Name $Name -Ok $text.Contains($Needle) -Reason "$Path missing $Needle"
}

function Assert-NotContains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    Add-Check -Name $Name -Ok (-not $text.Contains($Needle)) -Reason "$Path still contains $Needle"
}

function Assert-MissingPath {
    param([string]$Path, [string]$Name)
    Add-Check -Name $Name -Ok (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Path))) -Reason "$Path should not exist"
}

try {
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "name: companion-interface" -Name "skill frontmatter exists"
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "Agent-Native visual-plan MDX" -Name "skill defines Agent-Native MDX surface"
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "plans/<slug>/plan.mdx" -Name "skill defines local plan source"
    Assert-Contains -Path "skills\companion-interface\SKILL.md" -Needle "must not record approval" -Name "skill preserves native approvals"
    Assert-Contains -Path "skills\companion-interface\agents\openai.yaml" -Needle "Agent-Native" -Name "metadata names Agent-Native"
    Assert-Contains -Path ".codex-plugin\plugin.json" -Needle '$superpowers-project:companion-interface' -Name "plugin prompt lists companion"
    Assert-Contains -Path ".codex-plugin\plugin.json" -Needle "Agent-Native visual-plan MDX" -Name "plugin prompt names MDX companion"
    Assert-Contains -Path "README.md" -Needle '$superpowers-project:companion-interface' -Name "README lists companion"
    Assert-Contains -Path "README.md" -Needle "Agent-Native visual-plan MDX" -Name "README names MDX companion"
    Assert-Contains -Path "docs\superpowers\PROJECT_CONTEXT.md" -Needle "companion-interface" -Name "project context lists companion"
    Assert-Contains -Path "docs\superpowers\PROJECT_CONTEXT.md" -Needle "Agent-Native review artifacts" -Name "project context documents visual-plan artifacts"
    Assert-Contains -Path "skills\brainstorm-spec\SKILL.md" -Needle "Agent-Native visual-plan" -Name "brainstorm uses visual-plan wording"
    Assert-Contains -Path "skills\brainstorm-spec\SKILL.md" -Needle "native approval" -Name "brainstorm preserves native approval"
    Assert-Contains -Path "skills\write-plan\SKILL.md" -Needle "Agent-Native visual-plan" -Name "write-plan uses visual-plan wording"
    Assert-Contains -Path "skills\write-plan\SKILL.md" -Needle "native continuation" -Name "write-plan preserves native continuation"
    Assert-Contains -Path "skills\brainstorm-spec\agents\openai.yaml" -Needle "Agent-Native visual-plan" -Name "brainstorm metadata mentions visual-plan"
    Assert-Contains -Path "skills\write-plan\agents\openai.yaml" -Needle "Agent-Native visual-plan" -Name "write-plan metadata mentions visual-plan"
    Assert-Contains -Path "skills\write-plan\SKILL.md" -Needle "issue creation, implementation, push, publish, merge, and final Done decisions" -Name "write-plan keeps governed decisions native"

    $activeFiles = @(
        "skills\companion-interface\SKILL.md",
        "skills\companion-interface\agents\openai.yaml",
        ".codex-plugin\plugin.json",
        "README.md",
        "skills\brainstorm-spec\SKILL.md",
        "skills\write-plan\SKILL.md"
    )
    foreach ($file in $activeFiles) {
        Assert-NotContains -Path $file -Needle "local HTML companion report" -Name "$file omits HTML companion report"
        Assert-NotContains -Path $file -Needle ".superpowers/reports" -Name "$file omits report sessions"
        Assert-NotContains -Path $file -Needle "manifest.json" -Name "$file omits manifest contract"
        Assert-NotContains -Path $file -Needle "events.jsonl" -Name "$file omits event log contract"
        Assert-NotContains -Path $file -Needle 'generated `index.html`' -Name "$file omits generated index contract"
    }
    Assert-NotContains -Path ".github\workflows\validate.yml" -Needle "pandoc --version" -Name "CI no longer verifies Pandoc"
    Assert-MissingPath -Path "scripts\serve-companion-report.ps1" -Name "HTML preview server is removed"
    Assert-MissingPath -Path "skills\companion-interface\scripts" -Name "HTML companion scripts are removed"
    Assert-MissingPath -Path "skills\companion-interface\templates" -Name "HTML companion templates are removed"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "companion-interface-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "companion-interface-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
