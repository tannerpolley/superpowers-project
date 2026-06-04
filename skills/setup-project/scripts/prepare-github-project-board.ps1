[CmdletBinding()]
param(
    [ValidateSet("Plan", "ValidateConfig", "Create")][string]$Mode = "Plan",
    [string]$RepoRoot = (Get-Location).Path,
    [string]$BoardTitle = "Superpowers Project",
    [string]$BoardConfigJson,
    [string]$BoardConfigPath,
    [string]$NativeApprovalJson,
    [string[]]$IssueUrls = @()
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

function Invoke-GhJson {
    param([string[]]$Arguments)
    $output = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments -join ' ') failed: $(($output | Out-String).Trim())" }
    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    $text | ConvertFrom-Json
}

function Get-OwnerFromRepository {
    param([string]$Repository)
    if ($Repository -notmatch "^(?<owner>[^/]+)/(?<repo>[^/]+)$") { throw "repository must be owner/name: $Repository" }
    $Matches.owner
}

function Assert-NativeApproval {
    param([string]$Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { throw "NativeApprovalJson is required for Create mode" }
    $approval = $Json | ConvertFrom-Json
    foreach ($field in @("source", "question_id", "selected_action")) {
        if (-not (Has-Property -Object $approval -Name $field)) { throw "native approval missing $field" }
    }
    if ([string]$approval.source -ne "request_user_input") { throw "native approval source must be request_user_input" }
    if ([string]$approval.question_id -ne "project_setup_board_approval") { throw "native approval question_id mismatch" }
    if ([string]$approval.selected_action -ne "create") { throw "native approval selected_action must be create" }
    $approval
}

function Get-OrCreateProjectBoard {
    param([string]$Owner, [string]$Title)
    $list = Invoke-GhJson -Arguments @("project", "list", "--owner", $Owner, "--format", "json", "--limit", "100")
    $existing = @($list.projects | Where-Object { [string]$_.title -eq $Title } | Select-Object -First 1)
    if ($existing.Count -gt 0) {
        return [ordered]@{
            created = $false
            number = [int]$existing[0].number
            url = [string]$existing[0].url
            id = [string]$existing[0].id
        }
    }
    $created = Invoke-GhJson -Arguments @("project", "create", "--owner", $Owner, "--title", $Title, "--format", "json")
    [ordered]@{
        created = $true
        number = [int]$created.number
        url = [string]$created.url
        id = [string]$created.id
    }
}

function Ensure-ProjectFields {
    param([string]$Owner, [int]$ProjectNumber)
    $fieldList = Invoke-GhJson -Arguments @("project", "field-list", "$ProjectNumber", "--owner", $Owner, "--format", "json", "--limit", "100")
    $existingNames = @($fieldList.fields | ForEach-Object { [string]$_.name })
    $created = [System.Collections.Generic.List[object]]::new()
    if ($existingNames -notcontains "Status") {
        $created.Add((Invoke-GhJson -Arguments @("project", "field-create", "$ProjectNumber", "--owner", $Owner, "--name", "Status", "--data-type", "SINGLE_SELECT", "--single-select-options", "Todo,In Progress,Done", "--format", "json"))) | Out-Null
    }
    foreach ($field in @("Milestone", "Issue Type", "Agent State")) {
        if ($existingNames -notcontains $field) {
            $created.Add((Invoke-GhJson -Arguments @("project", "field-create", "$ProjectNumber", "--owner", $Owner, "--name", $field, "--data-type", "TEXT", "--format", "json"))) | Out-Null
        }
    }
    @{
        existing = $existingNames
        created = @($created)
        required = @("Status", "Milestone", "Issue Type", "Agent State")
    }
}

function Add-IssuesToProject {
    param([string]$Owner, [int]$ProjectNumber, [string[]]$Urls)
    $added = [System.Collections.Generic.List[object]]::new()
    foreach ($url in @($Urls | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $item = Invoke-GhJson -Arguments @("project", "item-add", "$ProjectNumber", "--owner", $Owner, "--url", $url, "--format", "json")
        $added.Add([ordered]@{
            id = [string]$item.id
            title = [string]$item.title
            type = [string]$item.type
            url = [string]$item.url
        }) | Out-Null
    }
    @($added)
}

function Save-RoadmapBoardConfig {
    param([string]$RoadmapPath, [object]$Roadmap, [object]$Config)
    $roadmap | Add-Member -NotePropertyName "github_project_board" -NotePropertyValue $Config -Force
    $roadmap | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $RoadmapPath -Encoding utf8NoBOM
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

    if ($Mode -eq "Create") {
        $approval = Assert-NativeApproval -Json $NativeApprovalJson
        $owner = Get-OwnerFromRepository -Repository ([string]$roadmap.repository)
        $board = Get-OrCreateProjectBoard -Owner $owner -Title $BoardTitle
        $fields = Ensure-ProjectFields -Owner $owner -ProjectNumber ([int]$board.number)
        $items = Add-IssuesToProject -Owner $owner -ProjectNumber ([int]$board.number) -Urls $IssueUrls
        $config = [ordered]@{
            status = "configured"
            native_approval_required = $true
            owner_skill = "setup-project"
            repository = [string]$roadmap.repository
            board_title = $BoardTitle
            project_number = [int]$board.number
            project_url = [string]$board.url
            project_id = [string]$board.id
            board_created = [bool]$board.created
            fields = @($fields.required)
            linked_issue_urls = @($IssueUrls)
            linked_items = @($items)
            native_approval = $approval
        }
        Save-RoadmapBoardConfig -RoadmapPath $roadmapPath -Roadmap $roadmap -Config $config
        Complete -Ok $true -Reason "GitHub Project board configured" -Evidence $config
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
