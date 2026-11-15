# https://learn.microsoft.com/powershell/scripting/developer/psscriptanalyzer/create-custom-rule
. "$PSScriptRoot\Traps.ps1"

<#
.SYNOPSIS
    ci's PowerShell traps (Traps.ps1) as PSScriptAnalyzer findings.
#>
function Measure-CiTrap {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )
    if ($ScriptBlockAst.Parent) { return }
    foreach ($trap in Find-Trap $ScriptBlockAst) {
        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
            Message  = $trap.Message
            Extent   = $trap.Extent
            RuleName = $trap.Rule
            Severity = 'Warning'
        }
    }
}

Export-ModuleMember -Function Measure-CiTrap
