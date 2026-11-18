Describe 'HQ-4 proof' {
    It 'fails on purpose, so the report shows this test job as failed' {
        1 | Should -Be 2
    }
}
