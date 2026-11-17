function Read-ToolPin {
    Import-PowerShellDataFile (Join-Path $PSScriptRoot 'tools.psd1')
}

function Find-TestFile([string]$Root) {
    @(Get-ChildItem $Root -Recurse -Force -File -Filter *.Tests.ps1 | ForEach-Object { $_.FullName })
}

function Test-RunPassed($PesterResult, [int]$FindingCount) {
    [bool]($PesterResult -and $PesterResult.Result -eq 'Passed' -and $PesterResult.TotalCount -gt 0 -and $FindingCount -eq 0)
}

function Get-ToolProblem([string]$Name, [string]$Version, [string[]]$Installed) {
    if ($Installed -contains $Version) { return }
    $found = if ($Installed) { $Installed -join ', ' } else { 'none' }
    "$Name $Version isn't installed (found $found): Install-Module $Name -RequiredVersion $Version -Scope CurrentUser"
}
