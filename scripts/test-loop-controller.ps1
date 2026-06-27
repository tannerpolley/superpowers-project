[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = if ($Ok) { "passed" } else { $Reason } }) | Out-Null
}

function Assert-Contains {
    param([string]$Path, [string]$Needle, [string]$Name)
    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Add-Check -Name $Name -Ok $false -Reason "$Path is missing"
        return
    }
    $text = Get-Content -LiteralPath $full -Raw
    Add-Check -Name $Name -Ok $text.Contains($Needle) -Reason "$Path missing $Needle"
}

try {
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "name: loop-controller" -Name "skill frontmatter exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle 'Question id: `project_loop_next_step`' -Name "next-step question id exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle 'Question id: `project_loop_final_health_gate`' -Name "final health gate question id exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "Auto Mode is a route permission ledger" -Name "auto mode boundary exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "## Looping Mode Input" -Name "looping mode input boundary exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "selected_mode: looping" -Name "looping mode ledger marker exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "scripts/get-agent-plugin-version.ps1 -Banner -RequireCurrent" -Name "startup version check exists"
    Assert-Contains -Path "skills\loop-controller\SKILL.md" -Needle "validate-loop-state-machine.ps1" -Name "state machine validator is documented"
    Assert-Contains -Path "docs\superpowers\loop-mode-contract.yml" -Needle "one_candidate_per_iteration" -Name "loop mode contract exists"
    Assert-Contains -Path "skills\loop-controller\scripts\validate-loop-state-machine.ps1" -Needle "project_loop_next_step" -Name "state machine validator exists"
    Assert-Contains -Path "skills\loop-controller\agents\openai.yaml" -Needle "loop-controller" -Name "metadata exists"
    Assert-Contains -Path ".codex-plugin\plugin.json" -Needle '$superpowers-project:loop-controller' -Name "plugin prompt lists route"
    Assert-Contains -Path "README.md" -Needle '$superpowers-project:loop-controller' -Name "README lists route"
    Assert-Contains -Path "docs\superpowers\PROJECT_CONTEXT.md" -Needle "loop-controller" -Name "project context lists skill"
    Assert-Contains -Path "scripts\lib\project-skills.ps1" -Needle '"loop-controller"' -Name "final-capable list includes loop-controller"

    $failed = @($checks | Where-Object { -not $_.ok })
    [pscustomobject]@{ ok = ($failed.Count -eq 0); phase = "loop-controller-contract"; checks = $checks } | ConvertTo-Json -Depth 8
    if ($failed.Count -gt 0) { exit 1 }
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    [pscustomobject]@{ ok = $false; phase = "loop-controller-contract"; reason = $_.Exception.Message; checks = $checks } | ConvertTo-Json -Depth 8
    exit 1
}
