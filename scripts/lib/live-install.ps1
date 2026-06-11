$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "sync-tree.ps1")
. (Join-Path $PSScriptRoot "project-skills.ps1")

function New-LiveInstallDrift {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$Source,
        [string]$Target,
        [Parameter(Mandatory = $true)][string]$Drift,
        [string]$Path = ".",
        [hashtable]$Evidence = @{}
    )

    [pscustomobject]@{
        label = $Label
        source = $Source
        target = $Target
        drift = $Drift
        path = $Path
        evidence = $Evidence
    }
}

function Compare-LiveTree {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [switch]$OptionalSource
    )

    $sourceExists = Test-Path -LiteralPath $SourceRoot -PathType Container
    $targetExists = Test-Path -LiteralPath $TargetRoot -PathType Container

    if (-not $sourceExists -and -not $targetExists -and $OptionalSource) { return @() }
    if (-not $sourceExists -and $targetExists) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourceRoot -Target $TargetRoot -Drift "missing-in-source")
    }
    if ($sourceExists -and -not $targetExists) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourceRoot -Target $TargetRoot -Drift "missing-in-target")
    }
    if (-not $sourceExists -and -not $targetExists) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourceRoot -Target $TargetRoot -Drift "missing-source-and-target")
    }

    @(Compare-TreeHashes -SourceRoot $SourceRoot -TargetRoot $TargetRoot | ForEach-Object {
        New-LiveInstallDrift -Label $Label -Source $SourceRoot -Target $TargetRoot -Drift ([string]$_.drift) -Path ([string]$_.path)
    })
}

function Compare-LiveFile {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $sourceExists = Test-Path -LiteralPath $SourcePath -PathType Leaf
    $targetExists = Test-Path -LiteralPath $TargetPath -PathType Leaf
    if (-not $sourceExists -and -not $targetExists) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourcePath -Target $TargetPath -Drift "missing-source-and-target")
    }
    if (-not $sourceExists) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourcePath -Target $TargetPath -Drift "missing-in-source")
    }
    if (-not $targetExists) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourcePath -Target $TargetPath -Drift "missing-in-target")
    }
    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $TargetPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        return @(New-LiveInstallDrift -Label $Label -Source $SourcePath -Target $TargetPath -Drift "content-diff" -Path ([IO.Path]::GetFileName($SourcePath)) -Evidence @{ source_hash = $sourceHash; target_hash = $targetHash })
    }
    @()
}

function Compare-MarketplaceEntry {
    param(
        [Parameter(Mandatory = $true)][string]$MarketplacePath,
        [string]$ExpectedName = "superpowers-project",
        [string]$ExpectedSourcePath = "./plugins/superpowers-project"
    )

    if (-not (Test-Path -LiteralPath $MarketplacePath -PathType Leaf)) {
        return @(New-LiveInstallDrift -Label "marketplace entry" -Target $MarketplacePath -Drift "missing-in-target" -Path "marketplace.json")
    }

    $marketplace = Get-Content -LiteralPath $MarketplacePath -Raw | ConvertFrom-Json
    $entry = @($marketplace.plugins | Where-Object { [string]$_.name -eq $ExpectedName } | Select-Object -First 1)
    if ($entry.Count -eq 0) {
        return @(New-LiveInstallDrift -Label "marketplace entry" -Target $MarketplacePath -Drift "missing-entry" -Path "plugins" -Evidence @{ name = $ExpectedName })
    }

    $drift = [System.Collections.Generic.List[object]]::new()
    if ([string]$entry[0].source.path -ne $ExpectedSourcePath) {
        $drift.Add((New-LiveInstallDrift -Label "marketplace entry" -Target $MarketplacePath -Drift "content-diff" -Path "plugins.source.path" -Evidence @{ expected = $ExpectedSourcePath; actual = [string]$entry[0].source.path })) | Out-Null
    }
    if ([string]$entry[0].policy.installation -ne "AVAILABLE") {
        $drift.Add((New-LiveInstallDrift -Label "marketplace entry" -Target $MarketplacePath -Drift "content-diff" -Path "plugins.policy.installation" -Evidence @{ expected = "AVAILABLE"; actual = [string]$entry[0].policy.installation })) | Out-Null
    }
    @($drift)
}

function Compare-StaleOwnedSkillDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string[]]$ActiveSkillNames,
        [Parameter(Mandatory = $true)][string[]]$OwnedSkillNames
    )

    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) { return @() }
    @(Get-ChildItem -LiteralPath $TargetRoot -Directory | Sort-Object Name | Where-Object {
        $OwnedSkillNames -contains $_.Name -and $ActiveSkillNames -notcontains $_.Name
    } | ForEach-Object {
        New-LiveInstallDrift -Label $Label -Target $_.FullName -Drift "stale-owned-skill-directory" -Path $_.Name
    })
}

function Compare-SuperpowersProjectLiveInstall {
    param(
        [string]$SourceRoot = (Resolve-ProjectPluginRoot),
        [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\superpowers-project"),
        [string]$UserSkillsRoot = (Join-Path $env:USERPROFILE ".agents\skills"),
        [string]$MarketplacePath = (Join-Path $env:USERPROFILE ".agents\plugins\marketplace.json"),
        [string[]]$RetiredLivePluginRoots = @(
            (Join-Path $env:USERPROFILE "plugins\milestones"),
            (Join-Path $env:USERPROFILE "plugins\project")
        )
    )

    $sourceRootResolved = (Resolve-Path -LiteralPath $SourceRoot).Path
    $livePluginRootResolved = [IO.Path]::GetFullPath($LivePluginRoot)
    $userSkillsRootResolved = [IO.Path]::GetFullPath($UserSkillsRoot)
    $marketplacePathResolved = [IO.Path]::GetFullPath($MarketplacePath)

    $activeSkillNames = @(Get-ProjectActiveSkillNames -RepoRoot $sourceRootResolved)
    $userSkillNames = @(Get-ProjectUserSkillNames)
    $ownedPluginSkillNames = @(Get-ProjectOwnedSkillNames -RepoRoot $sourceRootResolved)
    $ownedUserSkillNames = @($userSkillNames + (Get-ProjectRetiredSkillNames) | Sort-Object -Unique)

    $drift = [System.Collections.Generic.List[object]]::new()

    foreach ($item in @(Compare-LiveTree -Label "plugin manifest" -SourceRoot (Join-Path $sourceRootResolved ".codex-plugin") -TargetRoot (Join-Path $livePluginRootResolved ".codex-plugin"))) {
        $drift.Add($item) | Out-Null
    }
    foreach ($item in @(Compare-LiveTree -Label "plugin assets" -SourceRoot (Join-Path $sourceRootResolved "assets") -TargetRoot (Join-Path $livePluginRootResolved "assets") -OptionalSource)) {
        $drift.Add($item) | Out-Null
    }
    foreach ($item in @(Compare-LiveTree -Label "plugin scripts lib" -SourceRoot (Join-Path $sourceRootResolved "scripts\lib") -TargetRoot (Join-Path $livePluginRootResolved "scripts\lib") -OptionalSource)) {
        $drift.Add($item) | Out-Null
    }
    foreach ($item in @(Compare-LiveFile -Label "plugin version checker" -SourcePath (Join-Path $sourceRootResolved "scripts\get-agent-plugin-version.ps1") -TargetPath (Join-Path $livePluginRootResolved "scripts\get-agent-plugin-version.ps1"))) {
        $drift.Add($item) | Out-Null
    }

    foreach ($skillName in $activeSkillNames) {
        foreach ($item in @(Compare-LiveTree -Label "plugin skill $skillName" -SourceRoot (Join-Path $sourceRootResolved "skills\$skillName") -TargetRoot (Join-Path $livePluginRootResolved "skills\$skillName"))) {
            $drift.Add($item) | Out-Null
        }
    }

    foreach ($skillName in $userSkillNames) {
        foreach ($item in @(Compare-LiveTree -Label "user skill $skillName" -SourceRoot (Join-Path $sourceRootResolved "skills\$skillName") -TargetRoot (Join-Path $userSkillsRootResolved $skillName))) {
            $drift.Add($item) | Out-Null
        }
    }

    foreach ($item in @(Compare-MarketplaceEntry -MarketplacePath $marketplacePathResolved)) {
        $drift.Add($item) | Out-Null
    }

    foreach ($retiredRoot in $RetiredLivePluginRoots) {
        $resolvedRetiredRoot = [IO.Path]::GetFullPath($retiredRoot)
        if (Test-Path -LiteralPath $resolvedRetiredRoot -PathType Container) {
            $drift.Add((New-LiveInstallDrift -Label "retired live plugin root" -Target $resolvedRetiredRoot -Drift "retired-root-exists" -Path $resolvedRetiredRoot)) | Out-Null
        }
    }

    foreach ($item in @(Compare-StaleOwnedSkillDirectories -Label "plugin stale owned skill" -TargetRoot (Join-Path $livePluginRootResolved "skills") -ActiveSkillNames $activeSkillNames -OwnedSkillNames $ownedPluginSkillNames)) {
        $drift.Add($item) | Out-Null
    }
    foreach ($item in @(Compare-StaleOwnedSkillDirectories -Label "user stale owned skill" -TargetRoot $userSkillsRootResolved -ActiveSkillNames $userSkillNames -OwnedSkillNames $ownedUserSkillNames)) {
        $drift.Add($item) | Out-Null
    }

    @($drift)
}

function Assert-SuperpowersProjectLiveInstallInSync {
    param(
        [string]$SourceRoot = (Resolve-ProjectPluginRoot),
        [string]$LivePluginRoot = (Join-Path $env:USERPROFILE "plugins\superpowers-project"),
        [string]$UserSkillsRoot = (Join-Path $env:USERPROFILE ".agents\skills"),
        [string]$MarketplacePath = (Join-Path $env:USERPROFILE ".agents\plugins\marketplace.json"),
        [string[]]$RetiredLivePluginRoots = @(
            (Join-Path $env:USERPROFILE "plugins\milestones"),
            (Join-Path $env:USERPROFILE "plugins\project")
        )
    )

    $drift = @(Compare-SuperpowersProjectLiveInstall -SourceRoot $SourceRoot -LivePluginRoot $LivePluginRoot -UserSkillsRoot $UserSkillsRoot -MarketplacePath $MarketplacePath -RetiredLivePluginRoots $RetiredLivePluginRoots)
    if ($drift.Count -gt 0) {
        throw "live install drift detected: $($drift | ConvertTo-Json -Depth 8 -Compress)"
    }
}
