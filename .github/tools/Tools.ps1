# The exact tool versions ci's checks run with, from tools.psd1 (HQ-2).

function Read-ToolPin {
    Import-PowerShellDataFile (Join-Path $PSScriptRoot 'tools.psd1')
}

function Get-ToolProblem([string]$Name, [string]$Version, [string[]]$Installed) {
    if ($Installed -contains $Version) { return }
    $found = if ($Installed) { $Installed -join ', ' } else { 'none' }
    "$Name $Version isn't installed (found $found): Install-Module $Name -RequiredVersion $Version -Scope CurrentUser"
}
