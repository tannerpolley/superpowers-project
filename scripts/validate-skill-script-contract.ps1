[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [switch]$SkipFixtures
)

$ErrorActionPreference = "Stop"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Reason)
    $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; reason = $Reason })
}

function Complete {
    param([bool]$Ok, [string]$Reason, [object[]]$Failures = @())
    [pscustomobject]@{
        ok = $Ok
        phase = "skill-script-contract"
        reason = $Reason
        failures = $Failures
        checks = $checks
    } | ConvertTo-Json -Depth 12
    if ($Ok) { exit 0 }
    exit 1
}

function Normalize-ContractPath {
    param([string]$Path)
    ($Path -replace '\\', '/').TrimStart('.', '/')
}

function Test-ParameterIsMandatory {
    param([System.Management.Automation.Language.ParameterAst]$Parameter)
    foreach ($attribute in $Parameter.Attributes) {
        if ($attribute.TypeName.Name -notin @("Parameter", "ParameterAttribute", "System.Management.Automation.ParameterAttribute")) {
            continue
        }
        foreach ($argument in $attribute.NamedArguments) {
            if ($argument.ArgumentName -ne "Mandatory") { continue }
            if ($null -eq $argument.Argument) { return $true }
            $value = $argument.Argument.ToString().Trim()
            return ($value -notin @("$false", "false", "0"))
        }
    }
    $false
}

function Get-ScriptParameterContract {
    param([string]$ScriptPath)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "PowerShell parse failed for ${ScriptPath}: $($errors[0].Message)"
    }

    $parameters = [ordered]@{}
    if ($ast.ParamBlock) {
        foreach ($parameter in $ast.ParamBlock.Parameters) {
            $name = $parameter.Name.VariablePath.UserPath
            $parameters[$name] = [ordered]@{
                name = $name
                mandatory = Test-ParameterIsMandatory -Parameter $parameter
            }
        }
    }
    [pscustomobject]@{
        path = $ScriptPath
        parameters = $parameters
    }
}

function Get-SkillDocScriptReferences {
    param([string]$SkillDir)

    $skillPath = Join-Path $SkillDir "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { return @{} }

    $references = @{}
    $lines = Get-Content -LiteralPath $skillPath
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = [string]$lines[$index]
        $matches = [regex]::Matches($line, '(?<script>(?:\.?[\\/])?scripts[\\/][A-Za-z0-9._/-]+?\.ps1)')
        foreach ($match in $matches) {
            $script = Normalize-ContractPath $match.Groups["script"].Value
            if (-not $references.ContainsKey($script)) {
                $references[$script] = [ordered]@{
                    script = $script
                    params = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    lines = [System.Collections.Generic.List[int]]::new()
                }
            }
            $references[$script].lines.Add($index + 1)
            $afterScript = $line.Substring($match.Index + $match.Length)
            foreach ($paramMatch in [regex]::Matches($afterScript, '(?<![\w])-([A-Za-z][A-Za-z0-9_]*)')) {
                [void]$references[$script].params.Add($paramMatch.Groups[1].Value)
            }
        }
    }
    $references
}

function Test-SkillScriptContracts {
    param([string]$Root)

    $failures = [System.Collections.Generic.List[object]]::new()
    $skillsRoot = Join-Path $Root "skills"
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
        $failures.Add([pscustomobject]@{ skill = ""; script = ""; reason = "missing skills directory" })
        return @($failures)
    }

    $rootScriptContracts = @{}
    $rootScriptsDir = Join-Path $Root "scripts"
    if (Test-Path -LiteralPath $rootScriptsDir -PathType Container) {
        foreach ($scriptFile in @(Get-ChildItem -LiteralPath $rootScriptsDir -Filter "*.ps1" -File -Recurse)) {
            $relative = Normalize-ContractPath ([IO.Path]::GetRelativePath($Root, $scriptFile.FullName))
            $rootScriptContracts[$relative] = Get-ScriptParameterContract -ScriptPath $scriptFile.FullName
        }
    }

    foreach ($skillDir in @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name)) {
        $references = Get-SkillDocScriptReferences -SkillDir $skillDir.FullName
        if ($references.Count -eq 0) { continue }

        $scriptContracts = @{}
        $scriptsDir = Join-Path $skillDir.FullName "scripts"
        if (Test-Path -LiteralPath $scriptsDir -PathType Container) {
            foreach ($scriptFile in @(Get-ChildItem -LiteralPath $scriptsDir -Filter "*.ps1" -File -Recurse)) {
                $relative = Normalize-ContractPath ([IO.Path]::GetRelativePath($skillDir.FullName, $scriptFile.FullName))
                $scriptContracts[$relative] = Get-ScriptParameterContract -ScriptPath $scriptFile.FullName
            }
        }

        foreach ($script in @($references.Keys | Sort-Object)) {
            $contract = $null
            if ($scriptContracts.ContainsKey($script)) {
                $contract = $scriptContracts[$script]
            } elseif ($rootScriptContracts.ContainsKey($script)) {
                $contract = $rootScriptContracts[$script]
            }

            if ($null -eq $contract) {
                $failures.Add([pscustomobject]@{
                    skill = $skillDir.Name
                    script = $script
                    reason = "skill docs reference a script that does not exist"
                })
                continue
            }

            $declared = $contract.parameters
            $documentedParams = $references[$script].params
            foreach ($documented in @($documentedParams)) {
                if (-not $declared.Contains($documented)) {
                    $failures.Add([pscustomobject]@{
                        skill = $skillDir.Name
                        script = $script
                        parameter = $documented
                        reason = "skill docs mention a parameter not exposed by the script"
                    })
                }
            }

            foreach ($parameterName in @($declared.Keys | Sort-Object)) {
                if ($declared[$parameterName].mandatory -and -not $documentedParams.Contains($parameterName)) {
                    $failures.Add([pscustomobject]@{
                        skill = $skillDir.Name
                        script = $script
                        parameter = $parameterName
                        reason = "mandatory script parameter is not documented by the skill"
                    })
                }
            }
        }
    }
    @($failures)
}

function Write-FixtureFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

function Invoke-FixtureChecks {
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("skill-script-contract-fixture-" + [guid]::NewGuid().ToString("N"))
    try {
        Write-FixtureFile -Path (Join-Path $fixtureRoot "skills/demo/SKILL.md") -Content @'
---
name: demo
description: fixture
---

Run `scripts/check.ps1 -IssueFile docs/superpowers/issues/1-demo.md`.
'@
        Write-FixtureFile -Path (Join-Path $fixtureRoot "skills/demo/scripts/check.ps1") -Content @'
param(
    [Parameter(Mandatory = $true)][string]$IssueMirror
)
'@
        $renamed = @(Test-SkillScriptContracts -Root $fixtureRoot)
        if (-not @($renamed | Where-Object { $_.reason -match "not exposed" -and $_.parameter -eq "IssueFile" })) {
            throw "renamed-parameter fixture did not catch IssueFile versus IssueMirror drift"
        }
        Add-Check -Name "fixture catches renamed parameter" -Ok $true -Reason "passed"

        Write-FixtureFile -Path (Join-Path $fixtureRoot "skills/demo/SKILL.md") -Content @'
---
name: demo
description: fixture
---

Run `scripts/check.ps1`.
'@
        $missingMandatory = @(Test-SkillScriptContracts -Root $fixtureRoot)
        if (-not @($missingMandatory | Where-Object { $_.reason -match "mandatory" -and $_.parameter -eq "IssueMirror" })) {
            throw "mandatory-parameter fixture did not catch missing IssueMirror documentation"
        }
        Add-Check -Name "fixture catches missing mandatory parameter" -Ok $true -Reason "passed"

        Write-FixtureFile -Path (Join-Path $fixtureRoot "skills/demo/SKILL.md") -Content @'
---
name: demo
description: fixture
---

Run `scripts/check.ps1 -IssueMirror docs/superpowers/issues/1-demo.md`.
'@
        $passing = @(Test-SkillScriptContracts -Root $fixtureRoot)
        if ($passing.Count -ne 0) {
            throw "passing fixture unexpectedly failed: $($passing.reason -join '; ')"
        }
        Add-Check -Name "fixture accepts matching contract" -Ok $true -Reason "passed"
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) {
            $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
            $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            if ($resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
            }
        }
    }
}

try {
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    if (-not $SkipFixtures) {
        Invoke-FixtureChecks
    }

    $failures = @(Test-SkillScriptContracts -Root $root)
    if ($failures.Count -gt 0) {
        Add-Check -Name "repo skill script contracts" -Ok $false -Reason "$($failures.Count) failure(s)"
        Complete -Ok $false -Reason "skill script parameter contract failed" -Failures $failures
    }

    Add-Check -Name "repo skill script contracts" -Ok $true -Reason "passed"
    Complete -Ok $true -Reason "passed"
} catch {
    Add-Check -Name "fatal" -Ok $false -Reason $_.Exception.Message
    Complete -Ok $false -Reason $_.Exception.Message
}
