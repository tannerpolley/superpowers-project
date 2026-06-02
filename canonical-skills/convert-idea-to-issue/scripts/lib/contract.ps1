$ErrorActionPreference = "Stop"

function Write-ContractResult {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [Parameter(Mandatory = $true)][string]$Reason,
        [hashtable]$Evidence = @{}
    )
    [ordered]@{
        ok = $Ok
        phase = $Phase
        reason = $Reason
        evidence = $Evidence
    } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Stop-Contract {
    param([string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    Write-ContractResult -Phase $Phase -Ok $false -Reason $Reason -Evidence $Evidence
}

function Complete-Contract {
    param([string]$Phase, [string]$Reason, [hashtable]$Evidence = @{})
    Write-ContractResult -Phase $Phase -Ok $true -Reason $Reason -Evidence $Evidence
}

function Test-PlanIssueTestMode {
    [string]$env:GPTI_TEST_MODE -eq "1"
}

function Assert-TestModeSwitch {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Test-PlanIssueTestMode)) {
        throw "$Name is test-only and cannot be used in live runs"
    }
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 60
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    try {
        [void]$process.Start()
        $processId = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        $exited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            try {
                $process.Kill($true)
            } catch {
                if (-not $process.HasExited) { throw }
            }
            $process.WaitForExit()
            [void]$stdoutTask.Wait(1000)
            [void]$stderrTask.Wait(1000)
            [pscustomobject]@{
                ExitCode = 124
                Stdout = (($stdoutTask.Result) -replace "(\r?\n)+$", "")
                Stderr = "external command timed out after $TimeoutSeconds seconds: $FilePath $($Arguments -join ' ')"
                TimedOut = $true
                TimeoutSeconds = $TimeoutSeconds
                ProcessId = $processId
            }
            return
        }

        $process.WaitForExit()
        [void]$stdoutTask.Wait(1000)
        [void]$stderrTask.Wait(1000)
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = (($stdoutTask.Result) -replace "(\r?\n)+$", "")
            Stderr = (($stderrTask.Result) -replace "(\r?\n)+$", "")
            TimedOut = $false
            TimeoutSeconds = $TimeoutSeconds
            ProcessId = $processId
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

function Invoke-Git {
    param([string]$RepoRoot, [string[]]$Arguments)
    Invoke-External -FilePath "git" -Arguments (@("-C", $RepoRoot) + $Arguments) -WorkingDirectory $RepoRoot
}

function Invoke-Gh {
    param([string[]]$Arguments, [string]$WorkingDirectory = (Get-Location).Path)
    Invoke-External -FilePath "gh" -Arguments $Arguments -WorkingDirectory $WorkingDirectory
}

function Read-JsonInput {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Name path not found: $Path" }
    try { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { throw "Invalid $Name JSON: $($_.Exception.Message)" }
}

function Test-Property {
    param($Object, [string]$Name)
    $Object.PSObject.Properties.Name -contains $Name
}

function Get-OriginRemoteSlug {
    param([Parameter(Mandatory = $true)][string]$RemoteUrl)
    $value = $RemoteUrl.Trim()
    if ($value -match "^(?:git@)?github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") { return "$($Matches.owner)/$($Matches.repo)" }
    if ($value -match "^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") { return "$($Matches.owner)/$($Matches.repo)" }
    $null
}

function Get-CanonicalRepoRoot {
    param([string]$RepoRoot)
    $git = Invoke-Git -RepoRoot $RepoRoot -Arguments @("rev-parse", "--show-toplevel")
    if ($git.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($git.Stdout)) { throw "Not a git repository: $RepoRoot" }
    [IO.Path]::GetFullPath($git.Stdout)
}

function Get-BranchDefault {
    param([string]$RepoRoot)
    $ref = Invoke-Git -RepoRoot $RepoRoot -Arguments @("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if ($ref.ExitCode -eq 0 -and $ref.Stdout -match '^origin/(?<branch>.+)$') { return $Matches.branch }
    $branch = Invoke-Git -RepoRoot $RepoRoot -Arguments @("branch", "--show-current")
    if ($branch.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($branch.Stdout)) { throw "could not determine default branch" }
    $branch.Stdout.Trim()
}

function Get-BranchInventory {
    param([string]$RepoRoot)
    $local = Invoke-Git -RepoRoot $RepoRoot -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/heads")
    $remote = Invoke-Git -RepoRoot $RepoRoot -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin")
    [pscustomobject]@{
        local = @($local.Stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        remote = @($remote.Stdout -split '\r?\n' | ForEach-Object { $_ -replace '^origin/', '' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "HEAD" })
    }
}

function Get-GithubRepoContext {
    param([string]$RepoRoot, [switch]$SkipGhAuth)
    if ($SkipGhAuth.IsPresent) { Assert-TestModeSwitch -Name "-SkipGhAuth" }
    $root = Get-CanonicalRepoRoot -RepoRoot $RepoRoot
    $origin = Invoke-Git -RepoRoot $root -Arguments @("remote", "get-url", "origin")
    if ($origin.ExitCode -ne 0) { throw "missing GitHub origin remote" }
    $remoteSlug = Get-OriginRemoteSlug -RemoteUrl $origin.Stdout
    if ([string]::IsNullOrWhiteSpace($remoteSlug)) { throw "origin remote is not a GitHub repository" }

    if (-not $SkipGhAuth.IsPresent) {
        $auth = Invoke-Gh -Arguments @("auth", "status") -WorkingDirectory $root
        if ($auth.ExitCode -ne 0) { throw "gh auth is not valid for GitHub" }
    }

    $agentFile = @("AGENTS.md", "CLAUDE.md") | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($agentFile)) { throw "Matt Pocock setup marker missing: AGENTS.md or CLAUDE.md" }
    $agentText = Get-Content -LiteralPath $agentFile -Raw
    if ($agentText -notmatch '(?im)^##\s+Agent skills\s*$') { throw "Matt Pocock setup marker missing: ## Agent skills" }
    $issueTrackerPath = Join-Path $root "docs\agents\issue-tracker.md"
    if (-not (Test-Path -LiteralPath $issueTrackerPath -PathType Leaf)) { throw "docs/agents/issue-tracker.md is missing" }
    $issueTracker = Get-Content -LiteralPath $issueTrackerPath -Raw
    if ($issueTracker -notmatch '(?i)GitHub\s+Issues') { throw "issue tracker setup does not explicitly identify GitHub Issues" }
    if ($issueTracker -notmatch ([regex]::Escape($remoteSlug)) -and $issueTracker -notmatch '(?i)current\s+(git\s+)?remote|origin') {
        throw "issue tracker setup does not match the active GitHub remote"
    }

    [pscustomobject]@{
        repo_root = $root
        origin = $origin.Stdout
        remote_slug = $remoteSlug
        agent_file = $agentFile
        issue_tracker = $issueTrackerPath
        gh_auth_checked = -not $SkipGhAuth.IsPresent
        matt_pocock_setup = $true
    }
}

function Get-MilestoneList {
    param([string]$RepoRoot, [string]$RemoteSlug, [string]$FixturePath)
    $raw = if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        Read-JsonInput -Path $FixturePath -Name "milestones fixture"
    } else {
        $result = Invoke-Gh -Arguments @("api", "repos/$RemoteSlug/milestones?state=all&per_page=100") -WorkingDirectory $RepoRoot
        if ($result.ExitCode -ne 0) { throw "could not read GitHub milestones: $($result.Stderr)" }
        $result.Stdout | ConvertFrom-Json
    }
    if ($null -eq $raw) { return @() }
    if (Test-Property -Object $raw -Name "milestones") { return @($raw.milestones) }
    @($raw)
}

function Get-GithubProjectsSummary {
    param([string]$RepoRoot, [string]$RemoteSlug, [string]$FixturePath)
    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        $raw = Read-JsonInput -Path $FixturePath -Name "projects fixture"
        $projects = if (Test-Property -Object $raw -Name "projects") { @($raw.projects) } else { @($raw) }
        return [pscustomobject]@{ checked = $true; error = $null; projects = $projects }
    }
    $parts = $RemoteSlug -split "/", 2
    $query = @"
query(`$owner:String!, `$repo:String!) {
  repository(owner: `$owner, name: `$repo) {
    projectsV2(first: 20) { nodes { title url closed number } }
  }
}
"@
    $result = Invoke-Gh -Arguments @("api", "graphql", "-f", "query=$query", "-F", "owner=$($parts[0])", "-F", "repo=$($parts[1])") -WorkingDirectory $RepoRoot
    if ($result.ExitCode -ne 0) { return [pscustomobject]@{ checked = $false; error = $result.Stderr; projects = @() } }
    try {
        $object = $result.Stdout | ConvertFrom-Json
        [pscustomobject]@{ checked = $true; error = $null; projects = @($object.data.repository.projectsV2.nodes) }
    } catch {
        [pscustomobject]@{ checked = $false; error = $_.Exception.Message; projects = @() }
    }
}
