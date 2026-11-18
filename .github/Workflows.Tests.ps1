# https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes
# https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions
BeforeDiscovery {
    $workflows = @(Get-ChildItem "$PSScriptRoot/workflows" -Filter *.yml | ForEach-Object { @{ Name = $_.Name; Text = [IO.File]::ReadAllText($_.FullName) } })
}

Describe 'Workflow defaults' {
    It '<Name> says what its token may do' -ForEach $workflows {
        $Text | Should -Match '(?m)^permissions:'
    }
    It '<Name> gives every job a timeout' -ForEach $workflows {
        $jobs = [regex]::Split(($Text -split '(?m)^jobs:\s*$')[1], '(?m)^  (?=[a-z0-9_-]+:\s*$)') | Where-Object { $_.Trim() }
        @($jobs | Where-Object { $_ -notmatch '(?m)^    timeout-minutes: \d+' } | ForEach-Object { ($_ -split ':')[0] }) -join ', ' | Should -BeNullOrEmpty
    }
    It '<Name> pins every outside action to a full commit' -ForEach $workflows {
        @([regex]::Matches($Text, '(?m)uses: (?!\./)([^\s@]+)@(\S+)') | Where-Object { $_.Groups[2].Value -notmatch '^[0-9a-f]{40}$' } | ForEach-Object { $_.Value }) -join ', ' | Should -BeNullOrEmpty
    }
}

Describe 'check.yml' {
    It 'cancels a pull request''s older runs when it gets a new push' {
        $text = [IO.File]::ReadAllText("$PSScriptRoot/workflows/check.yml")
        $text | Should -Match "cancel-in-progress: \`$\{\{ github.event_name == 'pull_request' \}\}"
    }
}
