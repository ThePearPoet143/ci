# https://learn.microsoft.com/powershell/scripting/developer/psscriptanalyzer/create-custom-rule
# https://linear.app/lishiyua/document/research-findings-from-building-guardrails-2026-11-12-to-14-38f20a1d9daf

$NativeCommands = 'git', 'gh', 'winget', 'tailscale', 't3', 'npm', 'npx', 'node', 'mise', 'chezmoi', 'schtasks',
'reg', 'icacls', 'jq', 'curl', 'cmd', 'powershell', 'pwsh'

function Test-NativeCommand([string]$Name) {
    $Name -and ($Name -match '\.exe$' -or $NativeCommands -contains $Name.ToLowerInvariant())
}

function ConvertTo-Trap([string]$Rule, $Extent, [string]$Message) {
    [pscustomobject]@{ Rule = $Rule; Extent = $Extent; Message = $Message }
}

function Get-StringArgument($Command) {
    @($Command.CommandElements | Select-Object -Skip 1 | Where-Object {
            $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $_ -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
        })
}

function Find-Trap([System.Management.Automation.Language.Ast]$Ast) {
    $file = ([string]$Ast.Extent.File -split '[\\/]')[-1]
    $commands = @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))
    $stop = $null -ne $Ast.Find({
            param($n)
            $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $n.Left.Extent.Text -eq '$ErrorActionPreference' -and $n.Right.Extent.Text -match '^[''"]Stop[''"]$'
        }, $true)

    foreach ($array in $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ArrayExpressionAst] }, $true)) {
        $statements = @($array.SubExpression.Statements)
        if ($statements.Count -ne 1 -or $statements[0] -isnot [System.Management.Automation.Language.PipelineAst]) { continue }
        $last = $statements[0].PipelineElements[-1]
        if ($last -is [System.Management.Automation.Language.CommandAst] -and $last.GetCommandName() -eq 'ConvertFrom-Json') {
            ConvertTo-Trap 'JsonArrayInArray' $array.Extent '@(... | ConvertFrom-Json) holds a JSON array as one item in Windows PowerShell 5.1: wrap the pipeline, @((... | ConvertFrom-Json))'
        }
    }

    foreach ($command in $commands) {
        $name = $command.GetCommandName()
        if ($name -eq 'git' -and $file -ne 'Git.ps1' -and $file -notlike '*.Tests.ps1') {
            ConvertTo-Trap 'GitWithoutInvokeGit' $command.Extent 'Call git through Invoke-Git (.github/actions/Git.ps1): a git that fails then fails the script, instead of reading as no output'
        }
        if (-not (Test-NativeCommand $name)) { continue }
        foreach ($argument in Get-StringArgument $command) {
            if ($argument.Value -eq '') {
                ConvertTo-Trap 'EmptyNativeArgument' $argument.Extent "Windows PowerShell 5.1 drops an empty argument to ${name}: pass '`"`"' instead of ''"
            } elseif ($argument.Value -ne '""' -and $argument.Value.Contains('"')) {
                ConvertTo-Trap 'QuoteInNativeArgument' $argument.Extent "Windows PowerShell 5.1 drops double quotes inside an argument to ${name}: write it without them"
            }
        }
        $words = @(Get-StringArgument $command | ForEach-Object { $_.Value })
        if ($name -eq 'gh' -and $words.Count -ge 2 -and $words[0] -eq 'api' -and $words[1].StartsWith('/')) {
            ConvertTo-Trap 'GhApiLeadingSlash' $command.Extent "Git Bash turns gh api's leading / into a file path: write $($words[1].TrimStart('/')), not $($words[1])"
        }
        if ($stop -and @($command.Redirections | Where-Object { $_.FromStream -eq 'Error' }).Count) {
            ConvertTo-Trap 'NativeStderrUnderStop' $command.Extent "Under `$ErrorActionPreference = 'Stop', Windows PowerShell 5.1 stops on ${name}'s redirected stderr even when it succeeds: run it under 'Continue'"
        }
    }
}
