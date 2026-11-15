# ci's checks on itself, the same command locally and in CI (HQ-2): the pinned tools, every test, and the analyzer.
# -Install installs a missing pinned tool; CI passes it, a person installs by hand.
# https://learn.microsoft.com/powershell/module/powershellget/install-module
param([switch]$Install)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\tools\Tools.ps1"

$pins = Read-ToolPin
$problems = foreach ($name in ($pins.Keys | Sort-Object)) {
    $installed = [string[]]@(Get-Module -ListAvailable $name | ForEach-Object { "$($_.Version)" })
    if ($Install -and $installed -notcontains $pins[$name]) {
        Install-Module $name -RequiredVersion $pins[$name] -Scope CurrentUser -Force -SkipPublisherCheck
        $installed += $pins[$name]
    }
    Get-ToolProblem $name $pins[$name] $installed
}
if ($problems) { $problems | ForEach-Object { Write-Output $_ }; exit 1 }

Import-Module Pester -RequiredVersion $pins.Pester
Import-Module PSScriptAnalyzer -RequiredVersion $pins.PSScriptAnalyzer

$configuration = New-PesterConfiguration
$configuration.Run.Path = $PSScriptRoot
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration

$findings = @(Invoke-ScriptAnalyzer -Path (Join-Path $PSScriptRoot '..') -Recurse -Severity Warning, Error)
$findings | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-String | Write-Output

Write-Output "Pester $($pins.Pester): $($result.PassedCount) passed, $($result.FailedCount) failed. PSScriptAnalyzer $($pins.PSScriptAnalyzer): $($findings.Count) findings."
if ($result.FailedCount -or $result.FailedContainers.Count -or $findings) { exit 1 }
