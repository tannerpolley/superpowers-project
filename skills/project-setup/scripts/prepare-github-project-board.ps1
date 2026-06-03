[CmdletBinding()]
param(
    [ValidateSet("Plan", "ValidateConfig")][string]$Mode = "Plan",
    [string]$RepoRoot = (Get-Location).Path,
    [string]$BoardTitle = "Superpowers Project",
    [string]$BoardConfigJson,
    [string]$BoardConfigPath
)

$ErrorActionPreference = "Stop"
$phase = "prepare-github-project-board"

function Complete {
    param([bool]$Ok, [string]$Reason, [object]$Evidence = $null)
    [ordered]@{ ok = $Ok; phase = $phase; reason = $Reason; evidence = $Evidence } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Read-JsonInput {
    param([string]$Json, [string]$Path, [string]$Name)
    $text = if (-not [string]::IsNullOrWhiteSpace($Json)) {
        $Json
    } elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name path not found" }
        Get-Content -LiteralPath $Path -Raw
    } else {
        throw "$Name is required"
    }
    $text | ConvertFrom-Json
}

function Has-Property {
    param($Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $roadmapPath = Join-Path $root "docs/agents/project-roadmap.json"
    if (-not (Test-Path -LiteralPath $roadmapPath -PathType Leaf)) { throw "project-roadmap.json is missing" }
    $roadmap = Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json
    if ([string]$roadmap.tracker -ne "github") { throw "GitHub Project board setup requires a GitHub tracker" }
    if ([string]::IsNullOrWhiteSpace([string]$roadmap.repository)) { throw "roadmap repository is required" }

    if ($Mode -eq "Plan") {
        $fields = @("Status", "Milestone", "Issue Type", "Agent State")
        $plan = [ordered]@{
            mutation_allowed_without_native_approval = $false
            native_question_id = "project_setup_board_approval"
            repository = [string]$roadmap.repository
            board_title = $BoardTitle
            project_policy = "optional-dashboard-evidence"
            fields = $fields
            issue_linking_scope = "link ready issue mirrors and milestone-owned GitHub issues after approval"
            dry_run_commands = @(
                "gh project create --owner <owner> --title `"$BoardTitle`"",
                "gh project field-create <project-number> --owner <owner> --name Status --data-type SINGLE_SELECT",
                "gh project item-add <project-number> --owner <owner> --url <issue-url>"
            )
        }
        Complete -Ok $true -Reason "approval-ready board plan prepared" -Evidence $plan
    }

    $config = Read-JsonInput -Json $BoardConfigJson -Path $BoardConfigPath -Name "board config"
    foreach ($field in @("repository", "board_title", "project_url", "fields", "native_approval")) {
        if (-not (Has-Property -Object $config -Name $field)) { throw "board config missing $field" }
    }
    if ([string]$config.repository -ne [string]$roadmap.repository) { throw "board config repository mismatch" }
    if ($config.native_approval -is [string]) { throw "native_approval must be structured" }
    if ([string]$config.native_approval.selected_action -notin @("create", "verify")) { throw "native approval selected_action must be create or verify" }
    $fields = @($config.fields | ForEach-Object { [string]$_ })
    foreach ($requiredField in @("Status", "Milestone")) {
        if ($fields -notcontains $requiredField) { throw "board config missing required field: $requiredField" }
    }
    Complete -Ok $true -Reason "board config evidence passed" -Evidence @{ repository = [string]$config.repository; project_url = [string]$config.project_url; fields = $fields }
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
