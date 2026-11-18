# https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes
# https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions
Describe '<Name>' -ForEach @(Get-ChildItem "$PSScriptRoot/workflows" -Filter *.yml | ForEach-Object { @{ Name = $_.Name; Text = [IO.File]::ReadAllText($_.FullName) } }) {
    It 'says what its token may do' {
        $Text | Should -Match '(?m)^permissions:'
    }
    It 'gives every job a timeout' {
        $jobs = [regex]::Split(($Text -split '(?m)^jobs:\s*$')[1], '(?m)^  (?=[a-z0-9_-]+:\s*$)') | Where-Object { $_.Trim() }
        @($jobs | Where-Object { $_ -notmatch '(?m)^    timeout-minutes: \d+' } | ForEach-Object { ($_ -split ':')[0] }) -join ', ' | Should -BeNullOrEmpty
    }
    It 'pins every outside action to a full commit' {
        @([regex]::Matches($Text, '(?m)uses: (?!\./)([^\s@]+)@(\S+)') | Where-Object { $_.Groups[2].Value -notmatch '^[0-9a-f]{40}$' } | ForEach-Object { $_.Value }) -join ', ' | Should -BeNullOrEmpty
    }
}

Describe 'check.yml' {
    It 'cancels a pull request''s older runs when it gets a new push' {
        $text = [IO.File]::ReadAllText("$PSScriptRoot/workflows/check.yml")
        $text | Should -Match "cancel-in-progress: \`$\{\{ github.event_name == 'pull_request' \}\}"
    }
}

Describe 'Reusable workflows' {
    It '<Name> runs ci''s actions from its own commit, the version the caller named' -ForEach @(@{ Name = 'core.yml' }, @{ Name = 'report.yml' }) {
        $text = [IO.File]::ReadAllText("$PSScriptRoot/workflows/$Name")
        $text | Should -Match '(?m)^  workflow_call:'
        $text | Should -Match 'ref: \$\{\{ job\.workflow_sha \}\}'
        $text | Should -Match 'repository: \$\{\{ job\.workflow_repository \}\}'
        $text | Should -Not -Match 'uses: \./\.github/actions/'
    }
    It 'core.yml takes each repo''s own settings' {
        $text = [IO.File]::ReadAllText("$PSScriptRoot/workflows/core.yml")
        $text | Should -Match '(?m)^      issue-prefix:'
        $text | Should -Match '(?m)^      size-ignored:'
    }
}

Describe 'rulesets.yml' {
    BeforeAll { $script:text = [IO.File]::ReadAllText("$PSScriptRoot/workflows/rulesets.yml") }
    It 'runs only when started by hand' {
        $script:text | Should -Match '(?m)^  workflow_dispatch:'
        $script:text | Should -Not -Match '(?m)^  (push|pull_request|pull_request_target|schedule|workflow_run|issue_comment):'
    }
    It 'gets the admin token only through the rulesets environment, which waits for approval' {
        $script:text | Should -Match '(?m)^    environment: rulesets'
        $script:text | Should -Match 'secrets\.RULESET_TOKEN'
    }
    It 'passes the repo it was given as data, not into the script' {
        $script:text | Should -Match 'REPO: \$\{\{ inputs\.repo \}\}'
        $script:text | Should -Not -Match 'run:.*inputs\.'
    }
}
