[CmdletBinding()]
param(
    [ValidateSet("Plan", "ValidateConfig", "Create")][string]$Mode = "Plan",
    [string]$RepoRoot = (Get-Location).Path,
    [string]$BoardTitle = "Superpowers Project",
    [string]$BoardConfigJson,
    [string]$BoardConfigPath,
    [string]$NativeApprovalJson,
    [string]$IssueTypeFixturePath,
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

function Get-RepositoryParts {
    param([string]$Repository)
    if ($Repository -notmatch "^(?<owner>[^/]+)/(?<repo>[^/]+)$") { throw "repository must be owner/name: $Repository" }
    [ordered]@{ owner = $Matches.owner; name = $Matches.repo }
}

function Get-OwnerFromRepository {
    param([string]$Repository)
    (Get-RepositoryParts -Repository $Repository).owner
}

function Invoke-GhGraphQL {
    param([string]$Query, [hashtable]$Fields)
    $arguments = @("api", "graphql")
    foreach ($key in $Fields.Keys) {
        $arguments += @("-f", "$key=$($Fields[$key])")
    }
    $arguments += @("-f", "query=$Query")
    Invoke-GhJson -Arguments $arguments
}

function Read-IssueTypeFixture {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "issue type fixture path not found" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-NativeIssueTypes {
    param([string]$Repository, [string]$FixturePath)
    $fixture = Read-IssueTypeFixture -Path $FixturePath
    if ($null -ne $fixture) {
        $nodes = if ($fixture.PSObject.Properties.Name -contains "issueTypes") {
            @($fixture.issueTypes.nodes)
        } elseif ($fixture.PSObject.Properties.Name -contains "issue_types") {
            @($fixture.issue_types)
        } else {
            @($fixture)
        }
        $enabled = @($nodes | Where-Object { $_ -and ($_.PSObject.Properties.Name -notcontains "isEnabled" -or $_.isEnabled -ne $false) })
        return [ordered]@{
            source = "fixture"
            checked = $true
            available = ($enabled.Count -gt 0)
            names = @($enabled | ForEach-Object { [string]$_.name })
            nodes = @($enabled)
            label_only_reason = if ($enabled.Count -eq 0) { "fixture reports no enabled native issue types" } else { "" }
        }
    }

    $parts = Get-RepositoryParts -Repository $Repository
    $query = @'
query($owner:String!, $name:String!) {
  repository(owner:$owner, name:$name) {
    issueTypes(first: 20) {
      nodes { id name isEnabled }
    }
  }
}
'@
    try {
        $graph = Invoke-GhGraphQL -Query $query -Fields @{ owner = $parts.owner; name = $parts.name }
        $issueTypes = $graph.data.repository.issueTypes
        if ($null -eq $issueTypes -or $null -eq $issueTypes.nodes) {
            return [ordered]@{
                source = "github-graphql"
                checked = $true
                available = $false
                names = @()
                nodes = @()
                label_only_reason = "repository exposes no native issue types through GraphQL"
            }
        }
        $enabled = @($issueTypes.nodes | Where-Object { $_ -and ($_.PSObject.Properties.Name -notcontains "isEnabled" -or $_.isEnabled -ne $false) })
        [ordered]@{
            source = "github-graphql"
            checked = $true
            available = ($enabled.Count -gt 0)
            names = @($enabled | ForEach-Object { [string]$_.name })
            nodes = @($enabled)
            label_only_reason = if ($enabled.Count -eq 0) { "repository has no enabled native issue types" } else { "" }
        }
    } catch {
        [ordered]@{
            source = "github-graphql"
            checked = $false
            available = $false
            names = @()
            nodes = @()
            label_only_reason = "GraphQL native issue type inspection failed: $($_.Exception.Message)"
        }
    }
}

function Normalize-IssueTypeName {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $clean = $Value.Trim()
    if ($clean.StartsWith("type:")) { $clean = $clean.Substring(5) }
    [regex]::Replace($clean.ToLowerInvariant(), "[^a-z0-9]+", "")
}

function Resolve-IssueTypeId {
    param($NativeIssueTypes, [string]$IssueTypeName)
    $expected = Normalize-IssueTypeName -Value $IssueTypeName
    if ([string]::IsNullOrWhiteSpace($expected)) { return $null }
    foreach ($node in @($NativeIssueTypes.nodes)) {
        if ((Normalize-IssueTypeName -Value ([string]$node.name)) -eq $expected) {
            return [ordered]@{ id = [string]$node.id; name = [string]$node.name }
        }
    }
    $null
}

function Get-HierarchyTrackerEvidence {
    param($Roadmap)
    $requiredLabels = @("type:issue-set", "type:sub-milestone", "type:plan-wrapper")
    $configuredLabels = @()
    if (Has-Property -Object $Roadmap -Name "labels") {
        $configuredLabels = @($Roadmap.labels | ForEach-Object { [string]$_ })
    }
    $missingLabels = @($requiredLabels | Where-Object { $configuredLabels -notcontains $_ })
    [ordered]@{
        source = "docs/agents/project-roadmap.json"
        checked = $true
        mode = "compatibility-labels"
        required_labels = $requiredLabels
        available = ($missingLabels.Count -eq 0)
        missing_labels = $missingLabels
    }
}

function Get-FieldValue {
    param([string]$Text, [string]$Name)
    $escaped = [regex]::Escape($Name)
    foreach ($pattern in @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    $null
}

function Get-IssueNumberFromUrl {
    param([string]$Url)
    if ($Url -match '/issues/(?<number>\d+)(?:$|[?#])') { return [int]$Matches.number }
    $null
}

function Get-LocalIssueTypeForIssueUrl {
    param([string]$Root, [string]$Url)
    $issueRoot = Join-Path $Root "docs/superpowers/issues"
    if (-not (Test-Path -LiteralPath $issueRoot -PathType Container)) { return "" }
    foreach ($file in @(Get-ChildItem -LiteralPath $issueRoot -Filter "*.md" -File)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ((Get-FieldValue -Text $text -Name "GitHub Issue") -eq $Url) {
            return [string](Get-FieldValue -Text $text -Name "Issue Type")
        }
    }
    ""
}

function Get-IssueNodeId {
    param([string]$Repository, [int]$IssueNumber)
    $parts = Get-RepositoryParts -Repository $Repository
    $query = @'
query($owner:String!, $name:String!, $number:Int!) {
  repository(owner:$owner, name:$name) {
    issue(number:$number) { id number title issueType { name } }
  }
}
'@
    $graph = Invoke-GhGraphQL -Query $query -Fields @{ owner = $parts.owner; name = $parts.name; number = $IssueNumber }
    if ($null -eq $graph.data.repository.issue) { throw "GitHub issue not found: $Repository#$IssueNumber" }
    [ordered]@{
        id = [string]$graph.data.repository.issue.id
        number = [int]$graph.data.repository.issue.number
        title = [string]$graph.data.repository.issue.title
        current_issue_type = if ($null -ne $graph.data.repository.issue.issueType) { [string]$graph.data.repository.issue.issueType.name } else { "" }
    }
}

function Set-NativeIssueTypeForIssue {
    param([string]$Repository, [string]$IssueUrl, [string]$IssueTypeName, $NativeIssueTypes)
    if (-not $NativeIssueTypes.checked) { throw "native issue type support was not checked; refusing to mutate issue type" }
    if (-not $NativeIssueTypes.available) {
        return [ordered]@{ issue_url = $IssueUrl; changed = $false; mode = "label-only"; reason = $NativeIssueTypes.label_only_reason }
    }
    $resolved = Resolve-IssueTypeId -NativeIssueTypes $NativeIssueTypes -IssueTypeName $IssueTypeName
    if ($null -eq $resolved) {
        return [ordered]@{ issue_url = $IssueUrl; changed = $false; mode = "unmatched"; requested_issue_type = $IssueTypeName; available_issue_types = @($NativeIssueTypes.names) }
    }
    $number = Get-IssueNumberFromUrl -Url $IssueUrl
    if ($null -eq $number) { throw "Issue URL must include /issues/<number>: $IssueUrl" }
    $issue = Get-IssueNodeId -Repository $Repository -IssueNumber $number
    if ((Normalize-IssueTypeName -Value $issue.current_issue_type) -eq (Normalize-IssueTypeName -Value $resolved.name)) {
        return [ordered]@{ issue_url = $IssueUrl; changed = $false; mode = "already-set"; issue_type = $resolved.name }
    }
    $query = @'
mutation($issueId: ID!, $typeId: ID!) {
  updateIssue(input: { id: $issueId, issueTypeId: $typeId }) {
    issue { number title issueType { name } }
  }
}
'@
    $updated = Invoke-GhGraphQL -Query $query -Fields @{ issueId = $issue.id; typeId = $resolved.id }
    [ordered]@{
        issue_url = $IssueUrl
        changed = $true
        mode = "graphql-updateIssue"
        issue_type = [string]$updated.data.updateIssue.issue.issueType.name
        issue_type_id = $resolved.id
    }
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
    param([string]$Owner, [int]$ProjectNumber, [string[]]$Urls, [string]$RepoRoot, [string]$Repository, $NativeIssueTypes)
    $added = [System.Collections.Generic.List[object]]::new()
    foreach ($url in @($Urls | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $item = Invoke-GhJson -Arguments @("project", "item-add", "$ProjectNumber", "--owner", $Owner, "--url", $url, "--format", "json")
        $mirrorIssueType = Get-LocalIssueTypeForIssueUrl -Root $RepoRoot -Url $url
        $nativeIssueType = Set-NativeIssueTypeForIssue -Repository $Repository -IssueUrl $url -IssueTypeName $mirrorIssueType -NativeIssueTypes $NativeIssueTypes
        $added.Add([ordered]@{
            id = [string]$item.id
            title = [string]$item.title
            type = [string]$item.type
            url = [string]$item.url
            local_issue_type = $mirrorIssueType
            native_issue_type = $nativeIssueType
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
    $nativeIssueTypes = Get-NativeIssueTypes -Repository ([string]$roadmap.repository) -FixturePath $IssueTypeFixturePath
    $hierarchyTracker = Get-HierarchyTrackerEvidence -Roadmap $roadmap

    if ($Mode -eq "Plan") {
        $fields = @("Status", "Milestone", "Issue Type", "Agent State")
        $plan = [ordered]@{
            mutation_allowed_without_native_approval = $false
            native_question_id = "project_setup_board_approval"
            repository = [string]$roadmap.repository
            board_title = $BoardTitle
            project_policy = "optional-dashboard-evidence"
            fields = $fields
            native_issue_types = $nativeIssueTypes
            hierarchy_tracker = $hierarchyTracker
            issue_linking_scope = "link ready issue mirrors and milestone-owned GitHub issues after approval"
            dry_run_commands = @(
                "gh api graphql -f query='repository.issueTypes(first:20) { nodes { id name isEnabled } }'",
                "GraphQL UpdateIssueInput.issueTypeId assigns native issue types when enabled",
                "gh api graphql -f query='updateIssue(input: { id: <issue-id>, issueTypeId: <type-id> })'",
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
        $items = Add-IssuesToProject -Owner $owner -ProjectNumber ([int]$board.number) -Urls $IssueUrls -RepoRoot $root -Repository ([string]$roadmap.repository) -NativeIssueTypes $nativeIssueTypes
        $config = [ordered]@{
            status = "configured"
            native_approval_required = $true
            owner_skill = "setup-project"
            repository = [string]$roadmap.repository
            native_issue_types = $nativeIssueTypes
            hierarchy_tracker = $hierarchyTracker
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
