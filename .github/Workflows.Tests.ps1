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

Describe 'The secret scan' {
    BeforeAll { $script:action = [IO.File]::ReadAllText("$PSScriptRoot/actions/secrets/action.yml") }
    It 'runs gitleaks at one version, checked against its published checksum' {
        $script:action | Should -Match 'GITLEAKS_VERSION: \d+\.\d+\.\d+'
        $script:action | Should -Match 'GITLEAKS_SHA256: [0-9a-f]{64}'
        $script:action | Should -Match 'sha256sum --check'
    }
    It 'scans only the PR''s own commits, prints no secret, and ignores inline allows' {
        $script:action | Should -Match '--log-opts'
        $script:action | Should -Match '--redact'
        $script:action | Should -Match '--ignore-gitleaks-allow'
    }
    It 'scans the diff of merge commits too, where a secret could hide' {
        $script:action | Should -Match '--diff-merges=first-parent'
    }
    It 'takes its rules only from the base branch, never from the PR itself' {
        $script:action | Should -Match 'BASE_SHA:\.gitleaks\.toml'
        $script:action | Should -Match '--config'
        $script:action | Should -Match '--gitleaks-ignore-path'
    }
    It 'looks inside encoded text and archives' {
        $script:action | Should -Match '--max-decode-depth=\d'
        $script:action | Should -Match '--max-archive-depth=\d'
    }
    It 'is in the core every repo calls, and in ci''s own checks' -ForEach @(@{ Name = 'core.yml' }, @{ Name = 'pr.yml' }) {
        [IO.File]::ReadAllText("$PSScriptRoot/workflows/$Name") | Should -Match '(?m)^  secrets:'
    }
}
