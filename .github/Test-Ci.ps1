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
$configuration.Run.Path = Find-TestFile $PSScriptRoot
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration

$analyzer = @{
    Path                = Join-Path $PSScriptRoot '..'
    Recurse             = $true
    Severity            = 'Warning', 'Error'
    CustomRulePath      = Join-Path $PSScriptRoot 'lint/CiRules.psm1'
    IncludeDefaultRules = $true
}
$findings = @(Invoke-ScriptAnalyzer @analyzer)
$findings | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-String | Write-Output

. "$PSScriptRoot\lint\Comments.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$sources = Get-ChildItem (Join-Path $PSScriptRoot '..') -Recurse -Force -File -Include *.ps1, *.psm1, *.yml |
    Where-Object FullName -NotMatch '[\\/]\.git[\\/]'
$links = @(foreach ($file in $sources) { Get-SourceLink ([IO.File]::ReadAllText($file.FullName)) $file.Name })
$fetch = {
    param($Url)
    try {
        $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 30
        Write-Output "Read $Url`: HTTP $($response.StatusCode)" | Out-Host
    } catch {
        "$($_.Exception.Message)"
    }
}
$dead = @(Test-SourceLink $links $fetch)
$dead | ForEach-Object { Write-Output $_ }

Write-Output "Pester $($pins.Pester): $($result.PassedCount) passed, $($result.FailedCount) failed. PSScriptAnalyzer $($pins.PSScriptAnalyzer): $($findings.Count) findings. Source links: $(@($links | Sort-Object -Unique).Count) read, $($dead.Count) dead."
if (-not (Test-RunPassed $result ($findings.Count + $dead.Count))) { exit 1 }
