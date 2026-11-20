# https://code.claude.com/docs/en/memory#import-additional-files
# https://developers.openai.com/codex/guides/agents-md
BeforeAll {
    . "$PSScriptRoot/actions/text-check/TextCheck.ps1"
    $script:rules = [IO.File]::ReadAllText("$PSScriptRoot/../agents/rules.md")
    $script:example = [regex]::Match($script:rules, '(?s)```markdown\r?\n(.*?)\r?\n```').Groups[1].Value
    $script:title = [regex]::Match($script:rules, '(?m)^Title: `([^`]+)`').Groups[1].Value
}

Describe 'The shared rules every host gives its agents' {
    It 'show a PR title that passes the text check' {
        $script:title | Should -Not -BeNullOrEmpty
        @(Test-PrTitle $script:title 'HQ' 'dev') -join ' | ' | Should -BeNullOrEmpty
    }
    It 'show a PR description that passes the text check' {
        $script:example | Should -Not -BeNullOrEmpty
        @(Test-PrBody 'fix' $script:example) -join ' | ' | Should -BeNullOrEmpty
    }
    It 'name no person, machine or place' {
        $script:rules | Should -Not -Match '(?i)shiyuan|sushihome|IKSCP|lishiyua|tailscale|\b\d{1,3}(\.\d{1,3}){3}\b'
    }
}
