[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [Parameter(Mandatory = $true)][string]$PacketPath
)

$ErrorActionPreference = "Stop"
$phase = "validate-worker-packets"

function Complete {
    param([bool]$Ok, [string]$Reason, [object]$Evidence = $null)
    [ordered]@{ ok = $Ok; phase = $phase; reason = $Reason; evidence = $Evidence } | ConvertTo-Json -Depth 32
    if ($Ok) { exit 0 }
    exit 1
}

function Has-Property {
    param($Object, [string]$Name)
    $null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name
}

function Get-StringArray {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    @($Value | ForEach-Object { [string]$_ })
}

function Assert-RequiredString {
    param($Packet, [string]$Field)
    if (-not (Has-Property -Object $Packet -Name $Field) -or [string]::IsNullOrWhiteSpace([string]$Packet.$Field)) {
        throw "$Field is required"
    }
}

function Assert-RequiredObject {
    param($Packet, [string]$Field)
    if (-not (Has-Property -Object $Packet -Name $Field) -or $Packet.$Field -is [string] -or $null -eq $Packet.$Field) {
        throw "$Field is required"
    }
}

function Assert-RepoFile {
    param([string]$RepoRoot, [string]$Path, [string]$Field, [bool]$AllowPlaceholders = $false)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "$Field is required" }
    if ($AllowPlaceholders -and $Path.Contains("<") -and $Path.Contains(">")) { return }
    $fullPath = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $RepoRoot $Path }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "$Field does not exist: $Path" }
}

function Assert-CommandList {
    param($Value, [string]$Field)
    $commands = Get-StringArray $Value
    if ($commands.Count -eq 0) { throw "$Field must include at least one command" }
}

function Assert-WorkerHandoffPacket {
    param([string]$RepoRoot, $Packet, [bool]$AllowPlaceholders = $false)
    foreach ($field in @("issue_mirror", "source_plan", "goal_command", "branch", "branch_worktree_policy", "reviewer_role")) {
        Assert-RequiredString -Packet $Packet -Field $field
    }
    Assert-RepoFile -RepoRoot $RepoRoot -Path ([string]$Packet.issue_mirror) -Field "issue_mirror" -AllowPlaceholders $AllowPlaceholders
    Assert-RepoFile -RepoRoot $RepoRoot -Path ([string]$Packet.source_plan) -Field "source_plan" -AllowPlaceholders $AllowPlaceholders
    Assert-CommandList -Value $Packet.proof_oracle -Field "proof_oracle"
    Assert-RequiredObject -Packet $Packet -Field "validation"
    if (-not (Has-Property -Object $Packet.validation -Name "required_commands")) { throw "validation.required_commands is required" }
    Assert-CommandList -Value $Packet.validation.required_commands -Field "validation.required_commands"
    Assert-RequiredObject -Packet $Packet -Field "merge_handoff"
    if ([string]$Packet.merge_handoff.merge_owner -ne "merge-changes") { throw "merge_handoff.merge_owner must be merge-changes" }
    if ($Packet.merge_handoff.worker_must_not_merge -ne $true) { throw "merge_handoff.worker_must_not_merge must be true" }
}

function Assert-PrReadyPacket {
    param([string]$RepoRoot, $Packet, [bool]$AllowPlaceholders = $false)
    foreach ($field in @("issue_mirror", "source_plan", "branch")) {
        Assert-RequiredString -Packet $Packet -Field $field
    }
    Assert-RepoFile -RepoRoot $RepoRoot -Path ([string]$Packet.issue_mirror) -Field "issue_mirror" -AllowPlaceholders $AllowPlaceholders
    Assert-RepoFile -RepoRoot $RepoRoot -Path ([string]$Packet.source_plan) -Field "source_plan" -AllowPlaceholders $AllowPlaceholders
    Assert-CommandList -Value $Packet.proof_oracle -Field "proof_oracle"
    Assert-RequiredObject -Packet $Packet -Field "diff_scope"
    if (-not (Has-Property -Object $Packet.diff_scope -Name "changed_files")) { throw "diff_scope.changed_files is required" }
    if ((Get-StringArray $Packet.diff_scope.changed_files).Count -eq 0) { throw "diff_scope.changed_files must include at least one path" }
    Assert-RequiredObject -Packet $Packet -Field "validation_receipt"
    if (-not (Has-Property -Object $Packet.validation_receipt -Name "commands") -or @($Packet.validation_receipt.commands).Count -eq 0) {
        throw "validation_receipt.commands must include at least one receipt"
    }
    foreach ($receipt in @($Packet.validation_receipt.commands)) {
        Assert-RequiredString -Packet $receipt -Field "command"
        if (-not (Has-Property -Object $receipt -Name "exit_code")) { throw "validation receipt exit_code is required" }
    }
    Assert-RequiredObject -Packet $Packet -Field "merge_handoff"
    if ([string]$Packet.merge_handoff.route -ne "merge-changes") { throw "merge_handoff.route must be merge-changes" }
    foreach ($field in @("pr_url", "closes_issue")) {
        Assert-RequiredString -Packet $Packet.merge_handoff -Field $field
    }
    if ($Packet.merge_handoff.worker_must_not_merge -ne $true) { throw "merge_handoff.worker_must_not_merge must be true" }
}

function Read-Packets {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw
    if ([IO.Path]::GetExtension($Path) -ieq ".md") {
        $matches = [regex]::Matches($text, '(?ims)```json\s*(?<json>.*?)\s*```')
        if ($matches.Count -eq 0) { throw "Markdown packet example must include fenced json packets" }
        return @($matches | ForEach-Object { $_.Groups["json"].Value | ConvertFrom-Json })
    }
    @($text | ConvertFrom-Json)
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    $path = if ([IO.Path]::IsPathRooted($PacketPath)) { $PacketPath } else { Join-Path $root $PacketPath }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "packet path is missing: $PacketPath" }
    $packets = @(Read-Packets -Path $path)
    $allowPlaceholders = [IO.Path]::GetExtension($path) -ieq ".md"
    if ($packets.Count -eq 0) { throw "no packets found" }
    $types = [System.Collections.Generic.List[string]]::new()
    foreach ($packet in $packets) {
        Assert-RequiredString -Packet $packet -Field "packet_type"
        $type = [string]$packet.packet_type
        $types.Add($type) | Out-Null
        switch ($type) {
            "worker_handoff" { Assert-WorkerHandoffPacket -RepoRoot $root -Packet $packet -AllowPlaceholders $allowPlaceholders }
            "pr_ready" { Assert-PrReadyPacket -RepoRoot $root -Packet $packet -AllowPlaceholders $allowPlaceholders }
            default { throw "unsupported packet_type: $type" }
        }
    }
    if ([IO.Path]::GetExtension($path) -ieq ".md") {
        foreach ($requiredType in @("worker_handoff", "pr_ready")) {
            if ($types -notcontains $requiredType) { throw "Markdown packet example missing $requiredType packet" }
        }
    }
    Complete -Ok $true -Reason "worker packet validation passed" -Evidence @{ packet_path = $PacketPath; packet_types = @($types) }
} catch {
    Complete -Ok $false -Reason $_.Exception.Message
}
