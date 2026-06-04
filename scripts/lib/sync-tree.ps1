$ErrorActionPreference = "Stop"

function Get-SkillDirectoryNames {
    param([Parameter(Mandatory = $true)][string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $Root -Directory | Sort-Object Name | Select-Object -ExpandProperty Name)
}

function Assert-ChildDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child
    )
    $resolvedParent = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $resolvedChild = [IO.Path]::GetFullPath($Child)
    if (-not $resolvedChild.StartsWith($resolvedParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to operate outside approved root: $resolvedChild"
    }
}

function Copy-SkillDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [string[]]$SkillNames = @()
    )
    New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    $sourceSkills = @(Get-ChildItem -LiteralPath $SourceRoot -Directory | Sort-Object Name)
    if ($SkillNames.Count -gt 0) {
        $sourceSkills = @($sourceSkills | Where-Object { $SkillNames -contains $_.Name })
        $missing = @($SkillNames | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SourceRoot $_) -PathType Container) })
        if ($missing.Count -gt 0) { throw "missing selected skill source(s): $($missing -join ', ')" }
    }
    foreach ($sourceSkill in $sourceSkills) {
        $target = Join-Path $TargetRoot $sourceSkill.Name
        Assert-ChildDirectory -Parent $TargetRoot -Child $target
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $sourceSkill.FullName -Destination $target -Recurse
    }
}

function Remove-StaleOwnedSkillDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string[]]$ActiveSkillNames,
        [string[]]$RetiredSkillNames = @()
    )
    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) { return @() }
    $ownedNames = @($ActiveSkillNames + $RetiredSkillNames | Sort-Object -Unique)
    $removed = [System.Collections.Generic.List[string]]::new()
    foreach ($targetSkill in (Get-ChildItem -LiteralPath $TargetRoot -Directory | Sort-Object Name)) {
        if ($ownedNames -contains $targetSkill.Name -and $ActiveSkillNames -notcontains $targetSkill.Name) {
            Assert-ChildDirectory -Parent $TargetRoot -Child $targetSkill.FullName
            Remove-Item -LiteralPath $targetSkill.FullName -Recurse -Force
            $removed.Add($targetSkill.Name)
        }
    }
    @($removed)
}

function Get-TreeHashes {
    param([Parameter(Mandatory = $true)][string]$Root)
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $hashes = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($resolvedRoot, $file.FullName).Replace('\', '/')
        $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    $hashes
}

function Compare-TreeHashes {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot
    )
    $source = Get-TreeHashes -Root $SourceRoot
    $target = Get-TreeHashes -Root $TargetRoot
    $keys = @($source.Keys + $target.Keys | Sort-Object -Unique)
    foreach ($key in $keys) {
        if (-not $source.ContainsKey($key)) {
            [pscustomobject]@{ path = $key; drift = "missing-in-source" }
        } elseif (-not $target.ContainsKey($key)) {
            [pscustomobject]@{ path = $key; drift = "missing-in-target" }
        } elseif ($source[$key] -ne $target[$key]) {
            [pscustomobject]@{ path = $key; drift = "content-diff" }
        }
    }
}

function Assert-NoTreeDrift {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $drift = @(Compare-TreeHashes -SourceRoot $SourceRoot -TargetRoot $TargetRoot)
    if ($drift.Count -gt 0) {
        throw "$Label drift detected: $($drift | ConvertTo-Json -Compress)"
    }
}
