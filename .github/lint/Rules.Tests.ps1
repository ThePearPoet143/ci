BeforeAll {
    . "$PSScriptRoot\Rules.ps1"
    $script:root = Join-Path $PSScriptRoot '../..'
}

Describe 'Read-RuleTable' {
    It 'reads each rule and its enforcer from the table' {
        $text = "# Rules`n`n| Rule | Enforced by |`n| ---- | ----------- |`n| Commits name their issue | ``.github/actions/branch`` |`n| Plain words | judgment |"
        $rows = @(Read-RuleTable $text)
        $rows.Count | Should -Be 2
        $rows[0].Rule | Should -Be 'Commits name their issue'
        $rows[0].Enforcer | Should -Be '`.github/actions/branch`'
    }
}

Describe 'Test-RuleEnforcer' {
    It 'passes a path that exists in ci' {
        Test-RuleEnforcer '`.github/actions/branch`' $script:root | Should -BeNullOrEmpty
    }
    It 'fails a path that doesn''t exist' {
        Test-RuleEnforcer '`.github/actions/missing-check`' $script:root | Should -Match 'missing-check'
    }
    It 'passes a setting, a planned issue, or judgment' {
        Test-RuleEnforcer 'GitHub: the agents'' app can''t approve' $script:root | Should -BeNullOrEmpty
        Test-RuleEnforcer 'planned: HQ-5' $script:root | Should -BeNullOrEmpty
        Test-RuleEnforcer 'judgment' $script:root | Should -BeNullOrEmpty
    }
    It 'fails an enforcer that names nothing checkable' {
        Test-RuleEnforcer 'we remember' $script:root | Should -Match 'we remember'
        Test-RuleEnforcer 'planned: soon' $script:root | Should -Match 'planned'
        Test-RuleEnforcer 'planned: HQ-5 or never' $script:root | Should -Match 'planned'
    }
    It 'fails a path outside ci, a wildcard, or a blank' {
        Test-RuleEnforcer '`../../Windows`' $script:root | Should -Match 'Windows'
        Test-RuleEnforcer '`.github/act*`' $script:root | Should -Match 'act'
        Test-RuleEnforcer '` `' $script:root | Should -Not -BeNullOrEmpty
        Test-RuleEnforcer '' $script:root | Should -Not -BeNullOrEmpty
    }
}

Describe 'Read-RuleTable, broken rows' {
    It 'keeps a row with no enforcer, so it fails instead of vanishing' {
        $rows = @(Read-RuleTable "| Rule | Enforced by |`n| ---- | ----------- |`n| lonely rule |")
        $rows.Count | Should -Be 1
        $rows[0].Enforcer | Should -Be ''
    }
    It 'reads only the rules table, not a table in a code block or after it' {
        $text = "| Rule | Enforced by |`n| :--- | --- |`n| A | judgment |`n`nText.`n`n``````n| B | x |`n```````n`n| C | y |"
        @(Read-RuleTable $text).Rule | Should -Be @('A')
    }
}

Describe 'ci''s AGENTS.md' {
    It 'names a real enforcer for every rule' {
        $rows = @(Read-RuleTable ([IO.File]::ReadAllText((Join-Path $script:root 'AGENTS.md'))))
        $rows.Count | Should -BeGreaterThan 10
        $rows | ForEach-Object { Test-RuleEnforcer $_.Enforcer $script:root } | Should -BeNullOrEmpty
    }
}
