function Get-IssueHierarchyField {
    param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Name)
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*\*\*$escaped\s*:\s*\*\*\s*(.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*:\s*(.+?)\s*$",
        "(?im)^\s*$escaped\s*:\s*(.+?)\s*$"
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    return $null
}

function ConvertTo-IssueHierarchyBool {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    switch -Regex ($Value.Trim()) {
        '^(?i:true|yes)$' { return $true }
        '^(?i:false|no)$' { return $false }
        default { throw "Executable must be true or false" }
    }
}

function ConvertTo-IssueHierarchyLinks {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Trim().Equals("None", [StringComparison]::OrdinalIgnoreCase)) {
        return @()
    }
    @($Value -split '\s*,\s*|\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "None" })
}

function Get-IssueNumberFromUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    $match = [regex]::Match($Url, '/issues/(?<number>\d+)(?:\b|$)')
    if ($match.Success) { return [int]$match.Groups["number"].Value }
    return $null
}

function Read-IssueHierarchyMirror {
    param([Parameter(Mandatory = $true)][string]$Text)

    $fieldNames = @(
        "Hierarchy Mode",
        "Sub-Issue Role",
        "Executable",
        "Parent Issue",
        "Parent Mirror",
        "Child Issues",
        "Rollup Policy",
        "Title Policy"
    )
    $fields = [ordered]@{}
    foreach ($name in $fieldNames) {
        $fields[$name] = Get-IssueHierarchyField -Text $Text -Name $name
    }

    $hasHierarchyFields = @($fields.Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0
    $mode = if ([string]::IsNullOrWhiteSpace($fields["Hierarchy Mode"])) { "flat" } else { $fields["Hierarchy Mode"].Trim().ToLowerInvariant() }
    $role = if ([string]::IsNullOrWhiteSpace($fields["Sub-Issue Role"])) { "none" } else { $fields["Sub-Issue Role"].Trim().ToLowerInvariant() }
    $executable = ConvertTo-IssueHierarchyBool -Value $fields["Executable"]
    $parentIssue = if ([string]::IsNullOrWhiteSpace($fields["Parent Issue"])) { "" } else { $fields["Parent Issue"].Trim() }
    $parentMirror = if ([string]::IsNullOrWhiteSpace($fields["Parent Mirror"])) { "" } else { $fields["Parent Mirror"].Trim() }
    $rollupPolicy = if ([string]::IsNullOrWhiteSpace($fields["Rollup Policy"])) { "" } else { $fields["Rollup Policy"].Trim().ToLowerInvariant() }
    $titlePolicy = if ([string]::IsNullOrWhiteSpace($fields["Title Policy"])) { "" } else { $fields["Title Policy"].Trim() }
    $issueUrl = Get-IssueHierarchyField -Text $Text -Name "GitHub Issue"

    [pscustomobject]@{
        has_hierarchy_fields = $hasHierarchyFields
        issue_url = $issueUrl
        mode = $mode
        role = $role
        executable = $executable
        parent_issue = $parentIssue
        parent_mirror = $parentMirror
        child_issues = @(ConvertTo-IssueHierarchyLinks -Value $fields["Child Issues"])
        rollup_policy = $rollupPolicy
        title_policy = $titlePolicy
        issue_number = Get-IssueNumberFromUrl -Url $issueUrl
        parent_number = Get-IssueNumberFromUrl -Url $parentIssue
    }
}

function Get-GitHubSubIssueNodes {
    param($Issue)
    if ($null -eq $Issue -or $Issue.PSObject.Properties.Name -notcontains "subIssues" -or $null -eq $Issue.subIssues) {
        return @()
    }
    if ($Issue.subIssues.PSObject.Properties.Name -contains "nodes") {
        return @($Issue.subIssues.nodes)
    }
    if ($Issue.subIssues -is [array]) {
        return @($Issue.subIssues)
    }
    return @()
}
