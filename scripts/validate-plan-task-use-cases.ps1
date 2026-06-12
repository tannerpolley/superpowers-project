[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$PlanPath
)

$ErrorActionPreference = "Stop"

function Normalize-RelativePath {
    param([string]$Path)
    ($Path -replace '\\', '/').TrimStart('.', '/')
}

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path)
    $rootFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $rootFull $Path)) }
    if (-not $candidate.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $candidate -ne $rootFull) {
        throw "plan path is outside repo root: $candidate"
    }
    $candidate
}

function Get-TaskBlocks {
    param([string[]]$Lines)

    $matches = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $match = [regex]::Match($Lines[$index], '^\s{0,3}#{2,4}\s+Task\s+(?<number>\d+)\s*[:.-]\s*(?<title>.+?)\s*$')
        if ($match.Success) {
            $matches.Add([pscustomobject]@{
                number = [int]$match.Groups["number"].Value
                title = $match.Groups["title"].Value.Trim()
                start = $index
            }) | Out-Null
        }
    }

    $blocks = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $matches.Count; $index++) {
        $current = $matches[$index]
        $nextStart = if ($index + 1 -lt $matches.Count) { $matches[$index + 1].start } else { $Lines.Count }
        $blocks.Add([pscustomobject]@{
            number = $current.number
            title = $current.title
            start = $current.start
            end = $nextStart
            lines = @($Lines[$current.start..($nextStart - 1)])
        }) | Out-Null
    }
    @($blocks)
}

function Test-TaskUseCases {
    param([Parameter(Mandatory = $true)]$Task)

    $useCaseIndex = -1
    for ($index = 0; $index -lt $Task.lines.Count; $index++) {
        if ($Task.lines[$index] -match '^\s*\*\*Use Cases:\*\*\s*$') {
            $useCaseIndex = $index
            break
        }
    }
    if ($useCaseIndex -lt 0) {
        return [pscustomobject]@{ ok = $false; reason = "Task $($Task.number) is missing **Use Cases:**" }
    }

    for ($index = 0; $index -lt $useCaseIndex; $index++) {
        $line = [string]$Task.lines[$index]
        if ($line -match '^\s*\*\*Files:\*\*\s*$' -or $line -match '^\s*-\s+\[[ xX]\]\s+\S') {
            return [pscustomobject]@{ ok = $false; reason = "Task $($Task.number) has **Use Cases:** after files or steps" }
        }
    }

    $caseLines = [System.Collections.Generic.List[string]]::new()
    for ($index = $useCaseIndex + 1; $index -lt $Task.lines.Count; $index++) {
        $line = [string]$Task.lines[$index]
        if ($line -match '^\s{0,3}#{1,6}\s+' -or $line -match '^\s*\*\*[^*]+:\*\*\s*$') {
            break
        }
        if ($line -match '^\s*[-*]\s+\S' -or $line -match '^\s*\d+\.\s+\S') {
            $caseLines.Add($line.Trim()) | Out-Null
        }
    }
    if ($caseLines.Count -eq 0) {
        return [pscustomobject]@{ ok = $false; reason = "Task $($Task.number) has **Use Cases:** but no use-case bullets" }
    }

    [pscustomobject]@{ ok = $true; reason = "passed"; use_case_count = $caseLines.Count }
}

try {
    $repoRootFull = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
    $planFull = Resolve-RepoPath -Root $repoRootFull -Path $PlanPath
    if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) {
        throw "plan does not exist: $PlanPath"
    }

    $relativePlan = Normalize-RelativePath ([IO.Path]::GetRelativePath($repoRootFull, $planFull))
    if (-not $relativePlan.StartsWith("docs/superpowers/plans/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "plan must be under docs/superpowers/plans: $relativePlan"
    }

    $lines = [string[]](Get-Content -LiteralPath $planFull)
    $tasks = @(Get-TaskBlocks -Lines $lines)
    if ($tasks.Count -eq 0) {
        throw "plan has no numbered Task # sections"
    }

    $taskResults = @($tasks | ForEach-Object {
        $result = Test-TaskUseCases -Task $_
        [pscustomobject]@{
            task = "Task $($_.number)"
            title = $_.title
            ok = $result.ok
            reason = $result.reason
            use_case_count = if ($result.PSObject.Properties.Name -contains "use_case_count") { $result.use_case_count } else { 0 }
        }
    })
    $failures = @($taskResults | Where-Object { $_.ok -ne $true })
    if ($failures.Count -gt 0) {
        [pscustomobject]@{
            ok = $false
            phase = "plan-task-use-cases"
            plan_path = $relativePlan
            task_count = $tasks.Count
            reason = ($failures.reason -join "; ")
            tasks = $taskResults
        } | ConvertTo-Json -Depth 8
        exit 1
    }

    [pscustomobject]@{
        ok = $true
        phase = "plan-task-use-cases"
        plan_path = $relativePlan
        task_count = $tasks.Count
        reason = "all numbered Task # sections include use cases"
        tasks = $taskResults
    } | ConvertTo-Json -Depth 8
} catch {
    [pscustomobject]@{
        ok = $false
        phase = "plan-task-use-cases"
        reason = $_.Exception.Message
    } | ConvertTo-Json -Depth 8
    exit 1
}
