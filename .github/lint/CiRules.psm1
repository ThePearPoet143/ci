# https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/create-custom-rule
. "$PSScriptRoot\Traps.ps1"

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
