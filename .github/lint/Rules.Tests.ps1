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
    }
}

Describe 'ci''s AGENTS.md' {
    It 'names a real enforcer for every rule' {
        $rows = @(Read-RuleTable ([IO.File]::ReadAllText((Join-Path $script:root 'AGENTS.md'))))
        $rows.Count | Should -BeGreaterThan 10
        $rows | ForEach-Object { Test-RuleEnforcer $_.Enforcer $script:root } | Should -BeNullOrEmpty
    }
}
