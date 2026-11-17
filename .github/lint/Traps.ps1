# https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/create-custom-rule

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
    $preferences = @($Ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                ($n.Left.VariablePath.UserPath -replace '^(global|script|local|private):', '') -eq 'ErrorActionPreference'
            }, $true) | Sort-Object { $_.Extent.StartOffset })

    foreach ($array in $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ArrayExpressionAst] }, $true)) {
        $statements = @($array.SubExpression.Statements)
        if ($statements.Count -ne 1 -or $statements[0] -isnot [System.Management.Automation.Language.PipelineAst]) { continue }
        $last = $statements[0].PipelineElements[-1]
        if ($last -is [System.Management.Automation.Language.CommandAst] -and $last.GetCommandName() -eq 'ConvertFrom-Json') {
            ConvertTo-Trap 'JsonArrayInArray' $array.Extent '@(... | ConvertFrom-Json) holds a JSON array as one item in Windows PowerShell 5.1: wrap the pipeline, @((... | ConvertFrom-Json))'
        }
    }

    foreach ($pipeline in $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.PipelineAst] }, $true)) {
        $elements = @($pipeline.PipelineElements)
        for ($i = 0; $i -lt $elements.Count - 1; $i++) {
            if ($elements[$i] -is [System.Management.Automation.Language.CommandAst] -and $elements[$i].GetCommandName() -eq 'ConvertFrom-Json') {
                ConvertTo-Trap 'JsonArrayMidPipeline' $pipeline.Extent 'ConvertFrom-Json passes a JSON array on as one item in Windows PowerShell 5.1: end the pipeline there and wrap it, @((... | ConvertFrom-Json)) | ...'
            }
        }
    }

    foreach ($command in $commands) {
        $name = $command.GetCommandName()
        if ($name) { $name = $name -replace '\.exe$', '' }
        if ($name -eq 'git' -and $file -ne 'Git.ps1' -and $file -notlike '*.Tests.ps1') {
            ConvertTo-Trap 'GitWithoutInvokeGit' $command.Extent 'Call git through Invoke-Git (.github/actions/Git.ps1): a git that fails then fails the script, instead of reading as no output'
        }
        if (-not (Test-NativeCommand $name)) { continue }
        foreach ($argument in Get-StringArgument $command) {
            if ($argument.Value -eq '') {
                ConvertTo-Trap 'EmptyNativeArgument' $argument.Extent "Windows PowerShell 5.1 drops an empty argument to ${name}: pass '`"`"' instead of ''"
            } elseif ($name -ne 'cmd' -and $argument.Value -ne '""' -and $argument.Value.Contains('"')) {
                ConvertTo-Trap 'QuoteInNativeArgument' $argument.Extent "Windows PowerShell 5.1 drops double quotes inside an argument to ${name}: write it without them"
            }
        }
        $words = @(Get-StringArgument $command | ForEach-Object { $_.Value })
        $endpoint = @($words | Select-Object -Skip 1 | Where-Object { $_.StartsWith('/') })
        if ($name -eq 'gh' -and $words[0] -eq 'api' -and $endpoint) {
            ConvertTo-Trap 'GhApiLeadingSlash' $command.Extent "Git Bash turns gh api's leading / into a file path: write $($endpoint[0].TrimStart('/')), not $($endpoint[0])"
        }
        $setting = $preferences | Where-Object { $_.Extent.StartOffset -lt $command.Extent.StartOffset } | Select-Object -Last 1
        $stop = $setting -and $setting.Right.Extent.Text -match '^[''"]Stop[''"]$'
        if ($stop -and @($command.Redirections | Where-Object { "$($_.FromStream)" -in 'Error', 'All' }).Count) {
            ConvertTo-Trap 'NativeStderrUnderStop' $command.Extent "Under `$ErrorActionPreference = 'Stop', Windows PowerShell 5.1 stops on ${name}'s redirected stderr even when it succeeds: run it under 'Continue'"
        }
    }
}
